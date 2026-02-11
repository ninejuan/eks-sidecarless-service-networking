package httpapi

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/ninejuan/eks-sidecarless-service-networking/apps/checkout/internal/config"
	"github.com/ninejuan/eks-sidecarless-service-networking/apps/checkout/internal/domain"
	"github.com/ninejuan/eks-sidecarless-service-networking/apps/checkout/internal/service"
)

type Handler struct {
	service *service.CheckoutService
	cfg     config.Config
}

func NewHandler(svc *service.CheckoutService, cfg config.Config) *Handler {
	return &Handler{service: svc, cfg: cfg}
}

func (h *Handler) Register(router chi.Router) {
	router.Get("/health", h.health)
	router.Get("/health/liveness", h.liveness)
	router.Get("/health/readiness", h.readiness)

	router.Route("/v1/checkout", func(r chi.Router) {
		r.Post("/orders", h.createOrder)
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

func (h *Handler) createOrder(writer http.ResponseWriter, request *http.Request) {
	var payload domain.CreateOrderRequest
	if err := json.NewDecoder(request.Body).Decode(&payload); err != nil {
		respondError(writer, http.StatusBadRequest, "invalid request payload")
		return
	}

	if payload.Currency == "" {
		payload.Currency = "KRW"
	}

	result, err := h.service.CreateOrder(request.Context(), payload)
	if err != nil {
		switch {
		case errors.Is(err, domain.ErrInvalidRequest):
			respondError(writer, http.StatusBadRequest, err.Error())
		case errors.Is(err, domain.ErrInventoryUnavailable):
			respondError(writer, http.StatusConflict, err.Error())
		case errors.Is(err, domain.ErrPaymentFailed), errors.Is(err, domain.ErrDeliveryFailed):
			respondError(writer, http.StatusBadGateway, err.Error())
		default:
			respondError(writer, http.StatusInternalServerError, "failed to create order")
		}
		return
	}

	respondJSON(writer, http.StatusOK, result)
}

func respondJSON(writer http.ResponseWriter, status int, payload any) {
	writer.Header().Set("Content-Type", "application/json")
	writer.WriteHeader(status)
	_ = json.NewEncoder(writer).Encode(payload)
}

func respondError(writer http.ResponseWriter, status int, message string) {
	respondJSON(writer, status, map[string]string{"error": message})
}
