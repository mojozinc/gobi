package api

import (
	"fmt"
	"log"

	"github.com/gin-gonic/gin"
	"gobi/communication-gateway/internal/config"
	"gobi/communication-gateway/internal/whatsapp"
)

// Server represents the HTTP API server
type Server struct {
	router    *gin.Engine
	config    *config.Config
	waClient  *whatsapp.Client
}

// NewServer creates a new API server
func NewServer(cfg *config.Config, waClient *whatsapp.Client) *Server {
	// Set Gin mode based on environment
	if cfg.Server.Env == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	router := gin.Default()

	server := &Server{
		router:   router,
		config:   cfg,
		waClient: waClient,
	}

	server.setupRoutes()
	return server
}

// setupRoutes configures all API routes
func (s *Server) setupRoutes() {
	// Health check endpoint
	s.router.GET("/health", s.healthCheck)

	// API v1 routes
	v1 := s.router.Group("/api/v1")
	{
		// Authentication middleware for protected routes
		protected := v1.Group("")
		protected.Use(s.authMiddleware())

		// WhatsApp endpoints
		protected.POST("/send", s.sendMessage)
		protected.GET("/status", s.getStatus)

		// QR code endpoint (for initial pairing)
		v1.GET("/qr", s.getQRCode)
	}

	// Webhook endpoint for receiving messages (to be called by other services)
	s.router.POST("/webhook", s.webhook)
}

// Start starts the HTTP server
func (s *Server) Start() error {
	addr := fmt.Sprintf(":%s", s.config.Server.Port)
	log.Printf("Starting server on %s", addr)
	return s.router.Run(addr)
}

// GetRouter returns the Gin router (useful for testing)
func (s *Server) GetRouter() *gin.Engine {
	return s.router
}
