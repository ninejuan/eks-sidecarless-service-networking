package tests

import (
	"bytes"
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/go-chi/chi/v5"

	"github.com/ninejuan/eks-sidecarless-service-networking/apps/checkout/internal/config"
	"github.com/ninejuan/eks-sidecarless-service-networking/apps/checkout/internal/httpapi"
	"github.com/ninejuan/eks-sidecarless-service-networking/apps/checkout/internal/service"
)

type fakeDownstream struct{}

func (f fakeDownstream) CheckReadiness(_ context.Context) error { return nil }

func (f fakeDownstream) ReserveInventory(_ context.Context, _ string, _ string, _ int) error {
	return nil
}

func (f fakeDownstream) Pay(_ context.Context, _ string, _ int, _ string) error { return nil }

func (f fakeDownstream) Ship(_ context.Context, _ string, _ string) error { return nil }

func setupCheckoutServer() *chi.Mux {
	cfg := config.Config{ServiceName: "checkout"}
	svc := service.NewCheckoutService(fakeDownstream{})
	handler := httpapi.NewHandler(svc, cfg)
	router := chi.NewRouter()
	handler.Register(router)
	return router
}

func TestCheckoutHealth(t *testing.T) {
	server := setupCheckoutServer()

	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	rec := httptest.NewRecorder()
	server.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
}

func TestCreateOrder(t *testing.T) {
	server := setupCheckoutServer()

	payload := []byte(`{"orderId":"o-1","sku":"coffee-bean","quantity":1,"amount":10000,"currency":"KRW","address":"Seoul"}`)
	req := httptest.NewRequest(http.MethodPost, "/v1/checkout/orders", bytes.NewReader(payload))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()
	server.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
}

func TestCreateOrderValidation(t *testing.T) {
	server := setupCheckoutServer()

	payload := []byte(`{"orderId":"","sku":"coffee-bean","quantity":0,"amount":0,"address":""}`)
	req := httptest.NewRequest(http.MethodPost, "/v1/checkout/orders", bytes.NewReader(payload))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()
	server.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rec.Code)
	}
}
