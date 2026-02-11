package config

import "os"

type Config struct {
	ServiceName   string
	Environment   string
	Port          string
	AWSRegion     string
	DynamoDBTable string
}

func Load() Config {
	return Config{
		ServiceName:   getEnv("SERVICE_NAME", "inventory"),
		Environment:   getEnv("APP_ENV", "dev"),
		Port:          getEnv("APP_PORT", "8081"),
		AWSRegion:     getEnv("AWS_REGION", "ap-northeast-2"),
		DynamoDBTable: getEnv("DYNAMODB_TABLE", "inventory_items"),
	}
}

func getEnv(key string, fallback string) string {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}
	return value
}
