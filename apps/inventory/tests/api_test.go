package tests

import (
	"bytes"
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/go-chi/chi/v5"

	"github.com/sunrint/eks-sidecarless/apps/inventory/internal/config"
	"github.com/sunrint/eks-sidecarless/apps/inventory/internal/domain"
	"github.com/sunrint/eks-sidecarless/apps/inventory/internal/httpapi"
	"github.com/sunrint/eks-sidecarless/apps/inventory/internal/service"
)

type fakeRepo struct{}

func (f fakeRepo) Ping(_ context.Context) error { return nil }

func (f fakeRepo) GetStock(_ context.Context, sku string) (domain.StockItem, error) {
	return domain.StockItem{SKU: sku, AvailableQuantity: 10}, nil
}

func (f fakeRepo) Reserve(_ context.Context, _ domain.ReserveRequest) error { return nil }

func setupInventoryServer() *chi.Mux {
	cfg := config.Config{ServiceName: "inventory"}
	svc := service.NewInventoryService(fakeRepo{})
	handler := httpapi.NewHandler(svc, cfg)
	router := chi.NewRouter()
	handler.Register(router)
	return router
}

func TestInventoryHealth(t *testing.T) {
	server := setupInventoryServer()

	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	rec := httptest.NewRecorder()
	server.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
}

func TestInventoryCheckEndpoint(t *testing.T) {
	server := setupInventoryServer()

	payload := []byte(`{"sku":"coffee-bean","quantity":2}`)
	req := httptest.NewRequest(http.MethodPost, "/v1/inventory/check", bytes.NewReader(payload))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()
	server.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
}
