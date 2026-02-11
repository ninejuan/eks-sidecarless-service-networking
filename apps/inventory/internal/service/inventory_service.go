package service

import (
	"context"

	"github.com/ninejuan/eks-sidecarless-service-networking/apps/inventory/internal/domain"
)

type inventoryRepository interface {
	Ping(ctx context.Context) error
	GetStock(ctx context.Context, sku string) (domain.StockItem, error)
	Reserve(ctx context.Context, req domain.ReserveRequest) error
}

type InventoryService struct {
	repo inventoryRepository
}

func NewInventoryService(repo inventoryRepository) *InventoryService {
	return &InventoryService{repo: repo}
}

func (s *InventoryService) Readiness(ctx context.Context) error {
	return s.repo.Ping(ctx)
}

func (s *InventoryService) CheckStock(ctx context.Context, sku string, quantity int) (domain.StockItem, bool, error) {
	if quantity <= 0 {
		return domain.StockItem{}, false, domain.ErrInvalidQuantity
	}

	stock, err := s.repo.GetStock(ctx, sku)
	if err != nil {
		return domain.StockItem{}, false, err
	}

	return stock, stock.AvailableQuantity >= quantity, nil
}

func (s *InventoryService) Reserve(ctx context.Context, req domain.ReserveRequest) error {
	if req.Quantity <= 0 {
		return domain.ErrInvalidQuantity
	}

	return s.repo.Reserve(ctx, req)
}
