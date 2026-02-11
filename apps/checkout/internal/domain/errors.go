package domain

import "errors"

var (
	ErrInvalidRequest       = errors.New("invalid request payload")
	ErrInventoryUnavailable = errors.New("inventory reservation failed")
	ErrPaymentFailed        = errors.New("payment failed")
	ErrDeliveryFailed       = errors.New("delivery failed")
)
