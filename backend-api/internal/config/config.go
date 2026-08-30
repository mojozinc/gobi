package config

import (
	"fmt"
	"os"
	"strconv"

	"github.com/joho/godotenv"
)

type Config struct {
	Port     string
	Env      string
	Database DatabaseConfig
	JWT      JWTConfig
	CORS     CORSConfig
}

type DatabaseConfig struct {
	Host     string
	Port     string
	User     string
	Password string
	DBName   string
	SSLMode  string
}

type JWTConfig struct {
	Secret      string
	ExpiryHours int
}

type CORSConfig struct {
	Origins []string
}

func Load() (*Config, error) {
	// Load .env file if it exists
	_ = godotenv.Load()

	expiryHours := 72
	if exp := os.Getenv("JWT_EXPIRY_HOURS"); exp != "" {
		if parsed, err := strconv.Atoi(exp); err == nil {
			expiryHours = parsed
		}
	}

	config := &Config{
		Port: getEnv("PORT", "8000"),
		Env:  getEnv("ENV", "development"),
		Database: DatabaseConfig{
			Host:     getEnv("DB_HOST", "localhost"),
			Port:     getEnv("DB_PORT", "5432"),
			User:     getEnv("DB_USER", "gobi"),
			Password: getEnv("DB_PASSWORD", "gobi_password"),
			DBName:   getEnv("DB_NAME", "gobi_db"),
			SSLMode:  getEnv("DB_SSLMODE", "disable"),
		},
		JWT: JWTConfig{
			Secret:      getEnv("JWT_SECRET", "change-me-in-production"),
			ExpiryHours: expiryHours,
		},
		CORS: CORSConfig{
			Origins: []string{
				getEnv("CORS_ORIGINS", "http://localhost:3000"),
			},
		},
	}

	// Validate required fields
	if config.JWT.Secret == "change-me-in-production" && config.Env == "production" {
		return nil, fmt.Errorf("JWT_SECRET must be set in production")
	}

	return config, nil
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func (c *DatabaseConfig) ConnectionString() string {
	return fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
		c.Host, c.Port, c.User, c.Password, c.DBName, c.SSLMode,
	)
}
