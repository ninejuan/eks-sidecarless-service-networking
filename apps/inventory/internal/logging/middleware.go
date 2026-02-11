package logging

import (
	"encoding/json"
	"log"
	"net/http"
	"time"

	"github.com/google/uuid"

	"github.com/sunrint/eks-sidecarless/apps/inventory/internal/config"
)

type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (r *statusRecorder) WriteHeader(status int) {
	r.status = status
	r.ResponseWriter.WriteHeader(status)
}

func AccessLogMiddleware(cfg config.Config) func(next http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
			startedAt := time.Now()
			recorder := &statusRecorder{ResponseWriter: writer, status: http.StatusOK}

			requestID := request.Header.Get("X-Request-Id")
			if requestID == "" {
				requestID = uuid.NewString()
			}
			recorder.Header().Set("X-Request-Id", requestID)

			next.ServeHTTP(recorder, request)

			entry := map[string]any{
				"timestamp":  time.Now().UTC().Format(time.RFC3339Nano),
				"level":      "info",
				"msg":        "request completed",
				"service":    cfg.ServiceName,
				"env":        cfg.Environment,
				"requestId":  requestID,
				"userId":     request.Header.Get("X-User-Id"),
				"method":     request.Method,
				"path":       request.URL.Path,
				"status":     recorder.status,
				"latency_ms": time.Since(startedAt).Milliseconds(),
				"ip":         request.RemoteAddr,
				"userAgent":  request.UserAgent(),
			}

			encoded, err := json.Marshal(entry)
			if err != nil {
				log.Printf("{\"level\":\"error\",\"msg\":\"failed to encode log\"}")
				return
			}
			log.Println(string(encoded))
		})
	}
}
