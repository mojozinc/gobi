package main

import (
	"log"

	"github.com/gobi/backend-api/internal/api"
	"github.com/gobi/backend-api/internal/config"
	"github.com/gobi/backend-api/internal/database"
)

func main() {
	// Load configuration
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	// Initialize database
	db, err := database.NewDatabase(&cfg.Database)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer db.Close()

	// Run migrations
	if err := db.RunMigrations(); err != nil {
		log.Fatalf("Failed to run migrations: %v", err)
	}

	// Create and start server
	server := api.NewServer(db, cfg)
	log.Printf("Starting server on port %s in %s mode...", cfg.Port, cfg.Env)
	if err := server.Start(); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
