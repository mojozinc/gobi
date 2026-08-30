package api

import (
	"context"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

// SendMessageRequest represents a message sending request
type SendMessageRequest struct {
	Phone   string `json:"phone" binding:"required"`
	Message string `json:"message" binding:"required"`
}

// SendMessageResponse represents the response after sending a message
type SendMessageResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
}

// StatusResponse represents the WhatsApp connection status
type StatusResponse struct {
	Connected     bool   `json:"connected"`
	Authenticated bool   `json:"authenticated"`
	Message       string `json:"message"`
}

// QRCodeResponse represents the QR code for pairing
type QRCodeResponse struct {
	QRCode     string `json:"qr_code"`
	QRCodeData string `json:"qr_code_data,omitempty"`
	Message    string `json:"message"`
}

// WebhookRequest represents an incoming message from WhatsApp
type WebhookRequest struct {
	Phone     string `json:"phone"`
	Message   string `json:"message"`
	Timestamp int64  `json:"timestamp"`
}

// healthCheck returns the health status of the service
func (s *Server) healthCheck(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"status":  "healthy",
		"service": "communication-gateway",
		"time":    time.Now().Unix(),
	})
}

// sendMessage sends a WhatsApp message
func (s *Server) sendMessage(c *gin.Context) {
	var req SendMessageRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, SendMessageResponse{
			Success: false,
			Message: "Invalid request: " + err.Error(),
		})
		return
	}

	// Check if connected
	if !s.waClient.IsConnected() {
		c.JSON(http.StatusServiceUnavailable, SendMessageResponse{
			Success: false,
			Message: "WhatsApp is not connected",
		})
		return
	}

	// Send message
	if err := s.waClient.SendMessage(req.Phone, req.Message); err != nil {
		c.JSON(http.StatusInternalServerError, SendMessageResponse{
			Success: false,
			Message: "Failed to send message: " + err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, SendMessageResponse{
		Success: true,
		Message: "Message sent successfully",
	})
}

// getStatus returns the current WhatsApp connection status
func (s *Server) getStatus(c *gin.Context) {
	connected := s.waClient.IsConnected()
	authenticated := s.waClient.IsAuthenticated()

	message := "Ready"
	if !authenticated {
		message = "Not authenticated - please scan QR code"
	} else if !connected {
		message = "Authenticated but not connected"
	}

	c.JSON(http.StatusOK, StatusResponse{
		Connected:     connected,
		Authenticated: authenticated,
		Message:       message,
	})
}

// getQRCode generates a QR code for WhatsApp authentication
func (s *Server) getQRCode(c *gin.Context) {
	if s.waClient.IsAuthenticated() {
		c.JSON(http.StatusOK, QRCodeResponse{
			QRCode:  "",
			Message: "Already authenticated",
		})
		return
	}

	// Create context with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Get QR code (returns full URL format)
	qrCodeURL, err := s.waClient.GetQRCode(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, QRCodeResponse{
			QRCode:  "",
			Message: "Failed to generate QR code: " + err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, QRCodeResponse{
		QRCode:     qrCodeURL,
		QRCodeData: qrCodeURL, // For backward compatibility
		Message:    "Use qrencode or visit the URL to generate QR code. Command: curl http://localhost:8080/api/v1/qr | jq -r '.qr_code' | qrencode -t ANSIUTF8",
	})
}

// webhook receives incoming messages and forwards them to registered handlers
func (s *Server) webhook(c *gin.Context) {
	var req WebhookRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid request: " + err.Error(),
		})
		return
	}

	// Log the incoming message
	// In a real implementation, this would forward to registered module webhooks
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Webhook received",
	})
}
