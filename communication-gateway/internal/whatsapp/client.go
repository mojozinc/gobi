package whatsapp

import (
	"context"
	"fmt"
	"os"
	"sync"

	"go.mau.fi/whatsmeow"
	"go.mau.fi/whatsmeow/store/sqlstore"
	"go.mau.fi/whatsmeow/types"
	waLog "go.mau.fi/whatsmeow/util/log"
	waProto "go.mau.fi/whatsmeow/binary/proto"

	_ "github.com/mattn/go-sqlite3"
)

// Client wraps the whatsmeow client with additional functionality
type Client struct {
	WAClient   *whatsmeow.Client
	container  *sqlstore.Container
	eventHandlers []EventHandler
	mu         sync.RWMutex
}

// EventHandler is a function that processes incoming WhatsApp events
type EventHandler func(evt interface{})

// NewClient creates a new WhatsApp client
func NewClient(sessionDir string, logLevel string) (*Client, error) {
	// Ensure session directory exists
	if err := os.MkdirAll(sessionDir, 0700); err != nil {
		return nil, fmt.Errorf("failed to create session directory: %w", err)
	}

	// Initialize database container for session storage
	dbPath := fmt.Sprintf("%s/session.db", sessionDir)
	container, err := sqlstore.New(context.Background(), "sqlite3", fmt.Sprintf("file:%s?_foreign_keys=on", dbPath), waLog.Stdout(logLevel, "", false))
	if err != nil {
		return nil, fmt.Errorf("failed to create database container: %w", err)
	}

	// Get first device (or create new one)
	deviceStore, err := container.GetFirstDevice(context.Background())
	if err != nil {
		return nil, fmt.Errorf("failed to get device: %w", err)
	}

	// Create whatsmeow client
	waClient := whatsmeow.NewClient(deviceStore, waLog.Stdout(logLevel, "", false))

	client := &Client{
		WAClient:  waClient,
		container: container,
		eventHandlers: make([]EventHandler, 0),
	}

	// Register default event handler
	waClient.AddEventHandler(client.handleEvent)

	return client, nil
}

// Connect establishes connection to WhatsApp
func (c *Client) Connect() error {
	if c.WAClient.Store.ID == nil {
		// No existing session, need to pair
		return fmt.Errorf("not authenticated: please scan QR code first")
	}

	return c.WAClient.Connect()
}

// Disconnect closes the WhatsApp connection
func (c *Client) Disconnect() {
	if c.WAClient != nil {
		c.WAClient.Disconnect()
	}
}

// GetQRCode generates a QR code for pairing
func (c *Client) GetQRCode(ctx context.Context) (string, error) {
	if c.WAClient.Store.ID != nil {
		return "", fmt.Errorf("already authenticated")
	}

	// Check if already connected, disconnect first
	if c.WAClient.IsConnected() {
		c.WAClient.Disconnect()
	}

	qrChan, err := c.WAClient.GetQRChannel(ctx)
	if err != nil {
		return "", fmt.Errorf("failed to get QR channel: %w", err)
	}

	// Connect to start QR code generation
	if err := c.WAClient.Connect(); err != nil {
		return "", fmt.Errorf("failed to connect: %w", err)
	}

	// Wait for QR code
	for evt := range qrChan {
		if evt.Event == "code" {
			// Return the full URL - this is what needs to be encoded in the QR
			return evt.Code, nil
		} else if evt.Event == "success" {
			return "", fmt.Errorf("already authenticated")
		}
	}

	return "", fmt.Errorf("QR code channel closed without providing code")
}

// IsAuthenticated checks if the client has a valid session
func (c *Client) IsAuthenticated() bool {
	return c.WAClient.Store.ID != nil
}

// IsConnected checks if the client is currently connected
func (c *Client) IsConnected() bool {
	return c.WAClient.IsConnected()
}

// SendMessage sends a text message to a phone number
func (c *Client) SendMessage(phone string, message string) error {
	if !c.IsConnected() {
		return fmt.Errorf("not connected to WhatsApp")
	}

	// Parse phone number to JID (Jabber ID)
	jid, err := parsePhoneNumber(phone)
	if err != nil {
		return fmt.Errorf("invalid phone number: %w", err)
	}

	// Send message
	_, err = c.WAClient.SendMessage(context.Background(), jid, &waProto.Message{
		Conversation: &message,
	})

	return err
}

// AddEventHandler registers a new event handler
func (c *Client) AddEventHandler(handler EventHandler) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.eventHandlers = append(c.eventHandlers, handler)
}

// handleEvent processes incoming WhatsApp events
func (c *Client) handleEvent(evt interface{}) {
	c.mu.RLock()
	handlers := c.eventHandlers
	c.mu.RUnlock()

	for _, handler := range handlers {
		go handler(evt)
	}
}

// parsePhoneNumber converts a phone number string to WhatsApp JID
func parsePhoneNumber(phone string) (types.JID, error) {
	// Remove any non-digit characters
	cleaned := ""
	for _, char := range phone {
		if char >= '0' && char <= '9' {
			cleaned += string(char)
		}
	}

	if len(cleaned) == 0 {
		return types.JID{}, fmt.Errorf("invalid phone number: no digits found")
	}

	// Create JID (phone number @ s.whatsapp.net)
	return types.NewJID(cleaned, types.DefaultUserServer), nil
}

// Close cleans up resources
func (c *Client) Close() error {
	c.Disconnect()
	if c.container != nil {
		return c.container.Close()
	}
	return nil
}
