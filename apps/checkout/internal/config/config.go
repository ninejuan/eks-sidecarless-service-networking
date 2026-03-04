package config

import (
	"os"
	"strconv"
)

type Config struct {
	ServiceName      string
	Environment      string
	Port             string
	RequestTimeoutMS int
	AWSRegion        string
	EnableSigV4      bool
	InventoryURL     string
	PaymentURL       string
	DeliveryURL      string
}

func Load() Config {
	return Config{
		ServiceName:      getEnv("SERVICE_NAME", "checkout"),
		Environment:      getEnv("APP_ENV", "dev"),
		Port:             getEnv("APP_PORT", "8080"),
		RequestTimeoutMS: getEnvAsInt("REQUEST_TIMEOUT_MS", 1500),
		AWSRegion:        getEnv("AWS_REGION", "ap-northeast-2"),
		EnableSigV4:      getEnvAsBool("ENABLE_SIGV4", true),
		InventoryURL:     getEnv("INVENTORY_BASE_URL", "http://localhost:8081"),
		PaymentURL:       getEnv("PAYMENT_BASE_URL", "http://localhost:8082"),
		DeliveryURL:      getEnv("DELIVERY_BASE_URL", "http://localhost:8083"),
	}
}

func getEnv(key string, fallback string) string {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}
	return value
}

func getEnvAsInt(key string, fallback int) int {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}

	parsed, err := strconv.Atoi(value)
	if err != nil {
		return fallback
	}
	return parsed
}

func getEnvAsBool(key string, fallback bool) bool {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}

	parsed, err := strconv.ParseBool(value)
	if err != nil {
		return fallback
	}

	return parsed
}
