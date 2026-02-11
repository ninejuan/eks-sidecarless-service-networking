package domain

type StockItem struct {
	SKU               string `json:"sku"`
	AvailableQuantity int    `json:"availableQuantity"`
}

type ReserveRequest struct {
	OrderID  string `json:"orderId"`
	SKU      string `json:"sku"`
	Quantity int    `json:"quantity"`
}
