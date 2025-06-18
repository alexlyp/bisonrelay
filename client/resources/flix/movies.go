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
	Genre        string   `json:"genre"`
	ReleaseDate  string   `json:"release_date"`
	PosterPath   string   `json:"poster_path"`
	PosterEmbed  string   `json:"poster_embed"`
}

type moviesFile struct {
	Movies []*Movie
}
