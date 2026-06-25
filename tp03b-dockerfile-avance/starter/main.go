// TP3b — petite API « Telemach Cloud » servie par un binaire Go autonome.
// Aucune dépendance externe (bibliothèque standard uniquement) : le but n'est
// pas d'apprendre Go, mais de COMPILER une appli puis de n'embarquer que le
// binaire dans une image minimale (multi-stage).
package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
)

// Injecté au build via -ldflags "-X main.version=..." (voir le Dockerfile).
// Vaut "dev" si on ne passe rien : c'est l'intérêt de l'ARG/ldflags.
var version = "dev"

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	mux := http.NewServeMux()

	// Page d'accueil : doit contenir le nom du produit (vérifié par verify.sh).
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			http.NotFound(w, r)
			return
		}
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		fmt.Fprintf(w, `<!doctype html>
<html lang="fr"><head><meta charset="utf-8"><title>Telemach Cloud</title></head>
<body>
  <h1>Telemach Cloud</h1>
  <p>API servie par un binaire Go autonome — version %s.</p>
</body></html>`, version)
	})

	// Sonde de santé : 200 = vivant. Utilisée par le HEALTHCHECK et verify.sh.
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintln(w, "ok")
	})

	// Expose la version compilée dans le binaire.
	mux.HandleFunc("/version", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintln(w, version)
	})

	addr := ":" + port
	log.Printf("Telemach Cloud %s — écoute sur %s", version, addr)
	if err := http.ListenAndServe(addr, mux); err != nil {
		log.Fatal(err)
	}
}
