package main

import (
	"log"
	"os"
	"os/signal"
	"syscall"

	"gobi/communication-gateway/internal/api"
	"gobi/communication-gateway/internal/config"
	"gobi/communication-gateway/internal/whatsapp"
)

func main() {
	// Load configuration
	cfg := config.Load()
	log.Printf("Starting Communication Gateway in %s mode", cfg.Server.Env)

	// Initialize WhatsApp client
	waClient, err := whatsapp.NewClient(cfg.WhatsApp.SessionDir, cfg.WhatsApp.LogLevel)
	if err != nil {
		log.Fatalf("Failed to create WhatsApp client: %v", err)
	}
	defer waClient.Close()

	// Add default message logger
	waClient.AddEventHandler(whatsapp.DefaultMessageLogger())

	// Try to connect if already authenticated
	if waClient.IsAuthenticated() {
		log.Println("Existing session found, connecting to WhatsApp...")
		if err := waClient.Connect(); err != nil {
			log.Printf("Failed to connect: %v", err)
			log.Println("You may need to re-authenticate. Call GET /api/v1/qr to get a new QR code")
		} else {
			log.Println("Connected to WhatsApp successfully")
		}
	} else {
		log.Println("No existing session found. Call GET /api/v1/qr to authenticate")
	}

	// Create and start API server
	server := api.NewServer(cfg, waClient)

	// Handle graceful shutdown
	go func() {
		sigChan := make(chan os.Signal, 1)
		signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)
		<-sigChan

		log.Println("Shutting down gracefully...")
		waClient.Disconnect()
		os.Exit(0)
	}()

	// Start server
	if err := server.Start(); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
