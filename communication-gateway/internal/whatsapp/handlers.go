package whatsapp

import (
	"fmt"
	"log"

	"go.mau.fi/whatsmeow/types/events"
)

// MessageHandler processes incoming messages
type MessageHandler struct {
	onMessage func(phone string, message string, timestamp int64)
}

// NewMessageHandler creates a new message handler
func NewMessageHandler(onMessage func(phone string, message string, timestamp int64)) *MessageHandler {
	return &MessageHandler{
		onMessage: onMessage,
	}
}

// Handle processes WhatsApp events
func (h *MessageHandler) Handle(evt interface{}) {
	switch v := evt.(type) {
	case *events.Message:
		h.handleMessage(v)
	case *events.Connected:
		log.Println("WhatsApp connected successfully")
	case *events.Disconnected:
		log.Println("WhatsApp disconnected")
	case *events.LoggedOut:
		log.Println("WhatsApp logged out - session invalidated")
	case *events.PairSuccess:
		log.Println("WhatsApp pairing successful")
	}
}

// handleMessage processes incoming text messages
func (h *MessageHandler) handleMessage(msg *events.Message) {
	// Only process text messages for now
	if msg.Message.GetConversation() == "" && msg.Message.GetExtendedTextMessage() == nil {
		return
	}

	// Extract message text
	text := msg.Message.GetConversation()
	if text == "" && msg.Message.GetExtendedTextMessage() != nil {
		text = msg.Message.GetExtendedTextMessage().GetText()
	}

	// Extract sender phone number
	phone := msg.Info.Sender.User

	// Log the message
	log.Printf("Received message from %s: %s", phone, text)

	// Call the callback if provided
	if h.onMessage != nil {
		h.onMessage(phone, text, msg.Info.Timestamp.Unix())
	}
}

// DefaultMessageLogger creates a basic message handler that logs messages
func DefaultMessageLogger() EventHandler {
	handler := NewMessageHandler(func(phone string, message string, timestamp int64) {
		fmt.Printf("[%d] Message from %s: %s\n", timestamp, phone, message)
	})
	return handler.Handle
}
