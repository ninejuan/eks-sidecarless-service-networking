package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"

	"github.com/ninejuan/eks-sidecarless-service-networking/apps/inventory/internal/config"
	"github.com/ninejuan/eks-sidecarless-service-networking/apps/inventory/internal/httpapi"
	"github.com/ninejuan/eks-sidecarless-service-networking/apps/inventory/internal/logging"
	"github.com/ninejuan/eks-sidecarless-service-networking/apps/inventory/internal/repository"
	"github.com/ninejuan/eks-sidecarless-service-networking/apps/inventory/internal/service"
)

func main() {
	cfg := config.Load()

	repo, err := repository.NewDynamoRepository(cfg)
	if err != nil {
		log.Fatalf("failed to create repository: %v", err)
	}

	svc := service.NewInventoryService(repo)
	handler := httpapi.NewHandler(svc, cfg)

	router := chi.NewRouter()
	router.Use(middleware.Recoverer)
	router.Use(middleware.RequestID)
	router.Use(logging.AccessLogMiddleware(cfg))
	handler.Register(router)

	server := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           router,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      10 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	go func() {
		log.Printf("inventory service listening on :%s", cfg.Port)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("server failed: %v", err)
		}
	}()

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	<-sigCh

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := server.Shutdown(shutdownCtx); err != nil {
		log.Printf("graceful shutdown failed: %v", err)
	}
}
