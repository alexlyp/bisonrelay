package flix

type Movie struct {
	Title        string   `json:"title"`
	SKU          string   `json:"sku"`
	Description  string   `json:"description"`
	Tags         []string `json:"tags"`
	Price        float64  `json:"price"`
	Disabled     bool     `json:"disabled,omitempty"`
	Shipping     bool     `json:"shipping"`
	SendFilename string   `json:"send_filename"`
}

type moviesFile struct {
	Movies []*Movie
}
