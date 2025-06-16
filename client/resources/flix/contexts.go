package flix

import (
	"time"

	"github.com/companyzero/bisonrelay/client/clientintf"
)

type indexContext struct {
	Shows   map[string]*Show
	Movies  map[string]*Movie
	IsAdmin bool
}

type addToCartContext struct {
	Show  *Show
	Movie *Movie
	Cart  *Cart
}

type orderContext struct {
	Order
}

type ordersContext struct {
	Orders []*Order
}

type adminOrderSummary struct {
	ID       OrderID
	User     clientintf.UserID
	UserNick string
	Status   OrderStatus
	PlacedTS time.Time
}

type adminOrdersContext struct {
	Orders []adminOrderSummary
}

type adminOrderContext struct {
	Order    Order
	UserNick string
}
