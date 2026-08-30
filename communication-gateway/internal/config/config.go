package config

import (
	"log"
	"os"

	"github.com/joho/godotenv"
)

type Config struct {
	Server   ServerConfig
	WhatsApp WhatsAppConfig
	API      APIConfig
}

type ServerConfig struct {
	Port string
	Env  string
}

type WhatsAppConfig struct {
	SessionDir string
	LogLevel   string
}

type APIConfig struct {
	Key string
}

// Load loads configuration from environment variables
func Load() *Config {
	// Load .env file if it exists (for local development)
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found, using environment variables")
	}

	return &Config{
		Server: ServerConfig{
			Port: getEnv("PORT", "8080"),
			Env:  getEnv("ENV", "development"),
		},
		WhatsApp: WhatsAppConfig{
			SessionDir: getEnv("WHATSAPP_SESSION_DIR", "./sessions"),
			LogLevel:   getEnv("WHATSAPP_LOG_LEVEL", "INFO"),
		},
		API: APIConfig{
			Key: getEnv("API_KEY", ""),
		},
	}
}

// getEnv retrieves an environment variable or returns a default value
func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
