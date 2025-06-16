package main

import (
	"github.com/companyzero/bisonrelay/client/resources/simplestore"
)

func handleCompletedSimpleStoreOrder(as *appState, order *simplestore.Order, msg string) {
	if order.User == as.c.PublicID() {
		as.diagMsg("Order #%d placed by the local client", order.ID)
		as.diagMsg("Sample message that would be sent:")
		as.diagMsg(msg)
		return
	}

	ru, err := as.c.UserByID(order.User)
	if err != nil {
		as.diagMsg("Order #%d placed by unknown user %s",
			order.ID, order.User)
		return
	}

	cw := as.findOrNewChatWindow(ru.ID(), ru.Nick())
	as.pm(cw, msg)
}

func handleSimpleStoreOrderStatusChanged(as *appState, order *simplestore.Order, msg string) {
	ru, err := as.c.UserByID(order.User)
	if err != nil {
		as.diagMsg("Order #%d placed by unknown user %s",
			order.ID, order.User)
		return
	}

	cw := as.findOrNewChatWindow(ru.ID(), ru.Nick())
	as.pm(cw, msg)
}
