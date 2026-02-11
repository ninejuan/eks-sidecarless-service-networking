package domain

type CreateOrderRequest struct {
	OrderID  string `json:"orderId"`
	SKU      string `json:"sku"`
	Quantity int    `json:"quantity"`
	Amount   int    `json:"amount"`
	Currency string `json:"currency"`
	Address  string `json:"address"`
}

type CreateOrderResponse struct {
	Status         string `json:"status"`
	OrderID        string `json:"orderId"`
	PaymentStatus  string `json:"paymentStatus"`
	DeliveryStatus string `json:"deliveryStatus"`
}
