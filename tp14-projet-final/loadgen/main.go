// loadgen — simule les clients de la boutique Telemach Shop (TP14).
//
// WORKERS clients en boucle fermée : chacun envoie une requête, attend la
// réponse, patiente THINK_MS millisecondes, et recommence. Le mélange imite un
// vrai trafic :
//
//	60 %  GET  /products?category=cat-NN&page=P&_=<horodatage>   (navigation)
//	25 %  GET  /products/<id>                                     (fiche produit)
//	15 %  POST /orders                                            (achat)
//
// Le paramètre « _=<horodatage> » est celui qu'ajoute le front-end pour
// contourner le cache du navigateur. Retenez-le : il compte pour un incident.
//
// Configuration : TARGET (défaut http://traefik), HOST_HEADER (shop.localhost),
// WORKERS (8), THINK_MS (100), METRICS_PORT (9100).
// Métriques : loadgen_requests_total{code="200"|"500"|...|"erreur_reseau"}.
package main

import (
	"bytes"
	"fmt"
	"io"
	"log/slog"
	"math/rand/v2"
	"net/http"
	"os"
	"sort"
	"strconv"
	"sync"
	"time"
)

var (
	log    = slog.New(slog.NewJSONHandler(os.Stdout, nil))
	mu     sync.Mutex
	counts = map[string]uint64{}
)

func main() {
	target := env("TARGET", "http://traefik")
	host := env("HOST_HEADER", "shop.localhost")
	workers := envInt("WORKERS", 8)
	think := time.Duration(envInt("THINK_MS", 100)) * time.Millisecond

	http.HandleFunc("/metrics", metrics)
	go http.ListenAndServe(":"+env("METRICS_PORT", "9100"), nil)

	log.Info("ouverture de la boutique", "target", target, "workers", workers, "think_ms", think.Milliseconds())
	client := &http.Client{Timeout: 15 * time.Second}
	for i := 0; i < workers; i++ {
		go func() {
			for {
				hit(client, target, host)
				time.Sleep(think)
			}
		}()
	}

	// Bilan toutes les 10 s dans les logs.
	for range time.Tick(10 * time.Second) {
		mu.Lock()
		log.Info("bilan", "compteurs", fmt.Sprint(counts))
		mu.Unlock()
	}
}

func hit(c *http.Client, target, host string) {
	var req *http.Request
	switch r := rand.IntN(100); {
	case r < 60:
		url := fmt.Sprintf("%s/products?category=cat-%02d&page=%d&_=%d",
			target, rand.IntN(50)+1, rand.IntN(40), time.Now().UnixNano())
		req, _ = http.NewRequest(http.MethodGet, url, nil)
	case r < 85:
		req, _ = http.NewRequest(http.MethodGet, fmt.Sprintf("%s/products/%d", target, rand.IntN(1000000)+1), nil)
	default:
		body := fmt.Sprintf(`{"product_id": %d, "quantity": %d}`, rand.IntN(1000000)+1, rand.IntN(3)+1)
		req, _ = http.NewRequest(http.MethodPost, target+"/orders", bytes.NewBufferString(body))
		req.Header.Set("Content-Type", "application/json")
	}
	req.Host = host

	code := "erreur_reseau"
	if resp, err := c.Do(req); err == nil {
		io.Copy(io.Discard, resp.Body)
		resp.Body.Close()
		code = strconv.Itoa(resp.StatusCode)
	}
	mu.Lock()
	counts[code]++
	mu.Unlock()
}

func metrics(w http.ResponseWriter, _ *http.Request) {
	mu.Lock()
	defer mu.Unlock()
	keys := make([]string, 0, len(counts))
	for k := range counts {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	fmt.Fprintln(w, "# HELP loadgen_requests_total Requêtes envoyées par les clients simulés, par code de réponse.")
	fmt.Fprintln(w, "# TYPE loadgen_requests_total counter")
	for _, k := range keys {
		fmt.Fprintf(w, "loadgen_requests_total{code=%q} %d\n", k, counts[k])
	}
}

func env(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

func envInt(k string, def int) int {
	if v, err := strconv.Atoi(os.Getenv(k)); err == nil {
		return v
	}
	return def
}
