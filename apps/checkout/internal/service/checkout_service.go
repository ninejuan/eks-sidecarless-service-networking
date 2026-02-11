package service

import (
	"context"

	"github.com/sunrint/eks-sidecarless/apps/checkout/internal/domain"
)

type downstream interface {
	CheckReadiness(ctx context.Context) error
	ReserveInventory(ctx context.Context, orderID string, sku string, quantity int) error
	Pay(ctx context.Context, orderID string, amount int, currency string) error
	Ship(ctx context.Context, orderID string, address string) error
}

type CheckoutService struct {
	clients downstream
}

func NewCheckoutService(clients downstream) *CheckoutService {
	return &CheckoutService{clients: clients}
}

func (s *CheckoutService) Readiness(ctx context.Context) error {
	return s.clients.CheckReadiness(ctx)
}

func (s *CheckoutService) CreateOrder(ctx context.Context, req domain.CreateOrderRequest) (domain.CreateOrderResponse, error) {
	if req.OrderID == "" || req.SKU == "" || req.Address == "" || req.Quantity <= 0 || req.Amount <= 0 {
		return domain.CreateOrderResponse{}, domain.ErrInvalidRequest
	}

	if err := s.clients.ReserveInventory(ctx, req.OrderID, req.SKU, req.Quantity); err != nil {
		return domain.CreateOrderResponse{}, domain.ErrInventoryUnavailable
	}

	if err := s.clients.Pay(ctx, req.OrderID, req.Amount, req.Currency); err != nil {
		return domain.CreateOrderResponse{}, domain.ErrPaymentFailed
	}

	if err := s.clients.Ship(ctx, req.OrderID, req.Address); err != nil {
		return domain.CreateOrderResponse{}, domain.ErrDeliveryFailed
	}

	return domain.CreateOrderResponse{
		Status:         "accepted",
		OrderID:        req.OrderID,
		PaymentStatus:  "paid",
		DeliveryStatus: "shipped",
	}, nil
}
