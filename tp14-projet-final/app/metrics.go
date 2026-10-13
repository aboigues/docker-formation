package main

// Métriques Prometheus écrites à la main (format texte), sans dépendance.

import (
	"fmt"
	"net/http"
	"runtime"
	"sort"
	"strconv"
	"sync"
	"sync/atomic"
	"time"
)

var buckets = []float64{0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5}

type histo struct {
	counts []uint64 // une case par bucket, cumul calculé à l'affichage
	sum    float64
	total  uint64
}

var (
	mu          sync.Mutex
	requests    = map[string]uint64{} // clé "route|code"
	durations   = map[string]*histo{} // clé route
	cacheHits   atomic.Uint64
	cacheMisses atomic.Uint64
)

func observe(route string, code int, d time.Duration) {
	mu.Lock()
	defer mu.Unlock()
	requests[route+"|"+strconv.Itoa(code)]++
	h := durations[route]
	if h == nil {
		h = &histo{counts: make([]uint64, len(buckets))}
		durations[route] = h
	}
	s := d.Seconds()
	for i, b := range buckets {
		if s <= b {
			h.counts[i]++
			break
		}
	}
	h.sum += s
	h.total++
}

func (s *shop) handleMetrics(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "text/plain; version=0.0.4")
	mu.Lock()
	defer mu.Unlock()

	fmt.Fprintln(w, "# HELP shop_http_requests_total Requêtes servies, par route et code HTTP.")
	fmt.Fprintln(w, "# TYPE shop_http_requests_total counter")
	for _, k := range sortedKeys(requests) {
		var route, code string
		for i := len(k) - 1; i >= 0; i-- {
			if k[i] == '|' {
				route, code = k[:i], k[i+1:]
				break
			}
		}
		fmt.Fprintf(w, "shop_http_requests_total{route=%q,code=%q} %d\n", route, code, requests[k])
	}

	fmt.Fprintln(w, "# HELP shop_http_request_duration_seconds Durée des requêtes, par route.")
	fmt.Fprintln(w, "# TYPE shop_http_request_duration_seconds histogram")
	for _, route := range sortedKeys(durations) {
		h := durations[route]
		var cum uint64
		for i, b := range buckets {
			cum += h.counts[i]
			fmt.Fprintf(w, "shop_http_request_duration_seconds_bucket{route=%q,le=%q} %d\n",
				route, strconv.FormatFloat(b, 'f', -1, 64), cum)
		}
		fmt.Fprintf(w, "shop_http_request_duration_seconds_bucket{route=%q,le=\"+Inf\"} %d\n", route, h.total)
		fmt.Fprintf(w, "shop_http_request_duration_seconds_sum{route=%q} %g\n", route, h.sum)
		fmt.Fprintf(w, "shop_http_request_duration_seconds_count{route=%q} %d\n", route, h.total)
	}

	st := s.db.Stat()
	var m runtime.MemStats
	runtime.ReadMemStats(&m)
	gauges := []struct {
		name, help string
		value      float64
	}{
		{"shop_cache_entries", "Entrées dans le cache de réponses.", float64(s.cache.len())},
		{"shop_cache_hits_total", "Réponses servies depuis le cache.", float64(cacheHits.Load())},
		{"shop_cache_misses_total", "Réponses calculées (absentes du cache).", float64(cacheMisses.Load())},
		{"shop_db_pool_max_conns", "Taille maximale du pool de connexions.", float64(st.MaxConns())},
		{"shop_db_pool_total_conns", "Connexions ouvertes vers PostgreSQL.", float64(st.TotalConns())},
		{"shop_db_pool_acquired_conns", "Connexions en cours d'utilisation.", float64(st.AcquiredConns())},
		{"shop_go_heap_bytes", "Mémoire du tas Go.", float64(m.HeapAlloc)},
		{"shop_ready", "1 si le préchargement est terminé.", b2f(ready.Load())},
	}
	for _, g := range gauges {
		fmt.Fprintf(w, "# HELP %s %s\n# TYPE %s gauge\n%s %g\n", g.name, g.help, g.name, g.name, g.value)
	}
	fmt.Fprintf(w, "# HELP shop_build_info Version déployée.\n# TYPE shop_build_info gauge\nshop_build_info{version=%q} 1\n", version)
}

func sortedKeys[V any](m map[string]V) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}

func b2f(b bool) float64 {
	if b {
		return 1
	}
	return 0
}
