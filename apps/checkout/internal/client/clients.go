package client

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"time"

	"github.com/ninejuan/eks-sidecarless-service-networking/apps/checkout/internal/config"
)

type HTTPClients struct {
	httpClient   *http.Client
	inventoryURL string
	paymentURL   string
	deliveryURL  string
}

func NewHTTPClients(cfg config.Config) *HTTPClients {
	transport := http.DefaultTransport

	if cfg.EnableSigV4 {
		sigV4Transport, err := NewSigV4Transport(context.Background(), cfg.AWSRegion, transport)
		if err != nil {
			log.Printf("warning: SigV4 transport initialization failed, falling back to plain HTTP: %v", err)
		} else {
			transport = sigV4Transport
		}
	}

	return &HTTPClients{
		httpClient:   &http.Client{Timeout: time.Duration(cfg.RequestTimeoutMS) * time.Millisecond, Transport: transport},
		inventoryURL: cfg.InventoryURL,
		paymentURL:   cfg.PaymentURL,
		deliveryURL:  cfg.DeliveryURL,
	}
}

func (c *HTTPClients) CheckReadiness(ctx context.Context) error {
	urls := []string{
		c.inventoryURL + "/health/readiness",
		c.paymentURL + "/health/readiness",
		c.deliveryURL + "/health/readiness",
	}

	for _, target := range urls {
		request, err := http.NewRequestWithContext(ctx, http.MethodGet, target, nil)
		if err != nil {
			return err
		}

		response, err := c.httpClient.Do(request)
		if err != nil {
			return err
		}
		_ = response.Body.Close()

		if response.StatusCode != http.StatusOK {
			return fmt.Errorf("dependency readiness check failed: %s", target)
		}
	}

	return nil
}

func (c *HTTPClients) ReserveInventory(ctx context.Context, orderID string, sku string, quantity int) error {
	payload := map[string]any{"orderId": orderID, "sku": sku, "quantity": quantity}
	status, err := c.postJSON(ctx, c.inventoryURL+"/v1/inventory/reserve", payload)
	if err != nil {
		return err
	}
	if status != http.StatusOK {
		return errors.New("inventory reservation failed")
	}
	return nil
}

func (c *HTTPClients) Pay(ctx context.Context, orderID string, amount int, currency string) error {
	payload := map[string]any{"orderId": orderID, "amount": amount, "currency": currency}
	status, err := c.postJSON(ctx, c.paymentURL+"/v1/payment/pay", payload)
	if err != nil {
		return err
	}
	if status != http.StatusOK {
		return errors.New("payment failed")
	}
	return nil
}

func (c *HTTPClients) Ship(ctx context.Context, orderID string, address string) error {
	payload := map[string]any{"orderId": orderID, "address": address}
	status, err := c.postJSON(ctx, c.deliveryURL+"/v1/delivery/ship", payload)
	if err != nil {
		return err
	}
	if status != http.StatusOK {
		return errors.New("delivery failed")
	}
	return nil
}

func (c *HTTPClients) postJSON(ctx context.Context, url string, payload any) (int, error) {
	encoded, err := json.Marshal(payload)
	if err != nil {
		return 0, err
	}

	request, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(encoded))
	if err != nil {
		return 0, err
	}
	request.Header.Set("Content-Type", "application/json")

	response, err := c.httpClient.Do(request)
	if err != nil {
		return 0, err
	}
	defer response.Body.Close()

	return response.StatusCode, nil
}
