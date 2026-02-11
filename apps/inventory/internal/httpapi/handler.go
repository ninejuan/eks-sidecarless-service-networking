package httpapi

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/sunrint/eks-sidecarless/apps/inventory/internal/config"
	"github.com/sunrint/eks-sidecarless/apps/inventory/internal/domain"
	"github.com/sunrint/eks-sidecarless/apps/inventory/internal/service"
)

type Handler struct {
	service *service.InventoryService
	cfg     config.Config
}

type checkStockRequest struct {
	SKU      string `json:"sku"`
	Quantity int    `json:"quantity"`
}

type reserveRequest struct {
	OrderID  string `json:"orderId"`
	SKU      string `json:"sku"`
	Quantity int    `json:"quantity"`
}

func NewHandler(svc *service.InventoryService, cfg config.Config) *Handler {
	return &Handler{service: svc, cfg: cfg}
}

func (h *Handler) Register(router chi.Router) {
	router.Get("/health", h.health)
	router.Get("/health/liveness", h.liveness)
	router.Get("/health/readiness", h.readiness)

	router.Route("/v1/inventory", func(r chi.Router) {
		r.Post("/check", h.checkStock)
		r.Post("/reserve", h.reserve)
	})
}

func (h *Handler) health(writer http.ResponseWriter, _ *http.Request) {
	respondJSON(writer, http.StatusOK, map[string]any{"service": h.cfg.ServiceName, "status": "ok", "version": "v1"})
}

func (h *Handler) liveness(writer http.ResponseWriter, _ *http.Request) {
	respondJSON(writer, http.StatusOK, map[string]string{"status": "alive"})
}

func (h *Handler) readiness(writer http.ResponseWriter, request *http.Request) {
	if err := h.service.Readiness(request.Context()); err != nil {
		respondError(writer, http.StatusServiceUnavailable, "service is not ready")
		return
	}
	respondJSON(writer, http.StatusOK, map[string]string{"status": "ready"})
}

func (h *Handler) checkStock(writer http.ResponseWriter, request *http.Request) {
	var payload checkStockRequest
	if err := json.NewDecoder(request.Body).Decode(&payload); err != nil {
		respondError(writer, http.StatusBadRequest, "invalid request payload")
		return
	}

	stock, available, err := h.service.CheckStock(request.Context(), payload.SKU, payload.Quantity)
	if err != nil {
		if errors.Is(err, domain.ErrInvalidQuantity) {
			respondError(writer, http.StatusBadRequest, err.Error())
			return
		}
		respondError(writer, http.StatusInternalServerError, "failed to check stock")
		return
	}

	respondJSON(writer, http.StatusOK, map[string]any{
		"sku":               stock.SKU,
		"available":         available,
		"availableQuantity": stock.AvailableQuantity,
	})
}

func (h *Handler) reserve(writer http.ResponseWriter, request *http.Request) {
	var payload reserveRequest
	if err := json.NewDecoder(request.Body).Decode(&payload); err != nil {
		respondError(writer, http.StatusBadRequest, "invalid request payload")
		return
	}

	err := h.service.Reserve(request.Context(), domain.ReserveRequest{
		OrderID:  payload.OrderID,
		SKU:      payload.SKU,
		Quantity: payload.Quantity,
	})
	if err != nil {
		switch {
		case errors.Is(err, domain.ErrInvalidQuantity):
			respondError(writer, http.StatusBadRequest, err.Error())
		case errors.Is(err, domain.ErrInsufficientStock):
			respondError(writer, http.StatusConflict, err.Error())
		default:
			respondError(writer, http.StatusInternalServerError, "failed to reserve stock")
		}
		return
	}

	respondJSON(writer, http.StatusOK, map[string]string{"status": "reserved"})
}

func respondJSON(writer http.ResponseWriter, status int, payload any) {
	writer.Header().Set("Content-Type", "application/json")
	writer.WriteHeader(status)
	_ = json.NewEncoder(writer).Encode(payload)
}

func respondError(writer http.ResponseWriter, status int, message string) {
	respondJSON(writer, status, map[string]string{"error": message})
}
