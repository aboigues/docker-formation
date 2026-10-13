// Telemach Shop — l'API catalogue livrée par le prestataire (TP14).
//
// ⚠️ Ce code « marche sur le poste du développeur ». Il n'est PAS à réécrire :
// tous les incidents du TP se corrigent par l'image, le déploiement ou la
// configuration (variables d'environnement ci-dessous). Lisez-le comme un
// exploitant lit le code d'un autre : pour comprendre ce qu'il fait vraiment.
//
// Configuration (variables d'environnement) :
//
//	DB_HOST, DB_NAME, DB_USER, DB_PASSWORD  connexion PostgreSQL
//	DB_MAX_CONNS       taille MAX du pool de connexions PAR RÉPLICA (défaut : 10)
//	CACHE_MAX_ENTRIES  nb max d'entrées du cache de réponses (défaut : 0 = ILLIMITÉ)
//	WARMUP_SECONDS     durée du préchargement au démarrage (défaut : 8)
//	SHUTDOWN_DELAY     délai de vidange avant arrêt, en secondes (défaut : 5)
//	PORT               port d'écoute (défaut : 8080)
//
// Sous-commande : « shop-api healthcheck » interroge /health en local et sort
// en 0 (sain) ou 1 (pas prêt). Utile là où il n'y a ni curl ni wget dans l'image.
package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"math/rand/v2"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// Injectée au build : -ldflags "-X main.version=1.0.0"
var version = "dev"

var (
	log      = slog.New(slog.NewJSONHandler(os.Stdout, nil))
	hostname string
	ready    atomic.Bool // vrai une fois le préchargement terminé
	draining atomic.Bool // vrai dès la réception de SIGTERM
)

func main() {
	if len(os.Args) > 1 && os.Args[1] == "healthcheck" {
		os.Exit(healthcheck())
	}

	hostname, _ = os.Hostname()
	port := env("PORT", "8080")
	maxConns := envInt("DB_MAX_CONNS", 10)
	cacheMax := envInt("CACHE_MAX_ENTRIES", 0)
	warmup := time.Duration(envInt("WARMUP_SECONDS", 8)) * time.Second
	shutdownDelay := time.Duration(envInt("SHUTDOWN_DELAY", 5)) * time.Second

	log.Info("démarrage", "version", version, "db_max_conns", maxConns,
		"cache_max_entries", cacheMax, "warmup_s", warmup.Seconds())

	pool := connect(maxConns)
	app := &shop{db: pool, cache: newCache(cacheMax)}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", handleHealth)
	mux.HandleFunc("GET /version", handleVersion)
	mux.HandleFunc("GET /metrics", app.handleMetrics)
	mux.HandleFunc("GET /products", app.handleProducts)
	mux.HandleFunc("GET /products/{id}", app.handleProduct)
	mux.HandleFunc("POST /orders", app.handleOrder)

	srv := &http.Server{Addr: ":" + port, Handler: instrument(mux)}
	go func() {
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Error("serveur HTTP", "err", err)
			os.Exit(1)
		}
	}()
	log.Info("à l'écoute", "port", port)

	// Préchargement du catalogue : tant qu'il n'est pas fini, l'API répond 503.
	start := time.Now()
	var n int
	if err := pool.QueryRow(context.Background(), "SELECT count(*) FROM products").Scan(&n); err != nil {
		log.Error("préchargement", "err", err)
	}
	time.Sleep(warmup - time.Since(start))
	ready.Store(true)
	log.Info("prêt", "produits", n, "préchargement_ms", time.Since(start).Milliseconds())

	// Arrêt propre : on signale qu'on se retire (/health -> 503), on continue de
	// servir pendant SHUTDOWN_DELAY (le temps que le proxy nous oublie), puis on
	// termine les requêtes en cours.
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGTERM, syscall.SIGINT)
	<-stop
	draining.Store(true)
	log.Info("arrêt demandé, vidange", "delai_s", shutdownDelay.Seconds())
	time.Sleep(shutdownDelay)
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	_ = srv.Shutdown(ctx)
	pool.Close()
	log.Info("arrêté")
}

// connect ouvre le pool PostgreSQL, en réessayant tant que la base démarre.
func connect(maxConns int) *pgxpool.Pool {
	dsn := fmt.Sprintf("postgres://%s:%s@%s:5432/%s?sslmode=disable",
		env("DB_USER", "shop"), env("DB_PASSWORD", "shoppass"),
		env("DB_HOST", "db"), env("DB_NAME", "shop"))
	cfg, err := pgxpool.ParseConfig(dsn)
	if err != nil {
		log.Error("DSN invalide", "err", err)
		os.Exit(1)
	}
	cfg.MaxConns = int32(maxConns)

	for i := 0; ; i++ {
		pool, err := pgxpool.NewWithConfig(context.Background(), cfg)
		if err == nil {
			if err = pool.Ping(context.Background()); err == nil {
				return pool
			}
			pool.Close()
		}
		if i == 60 {
			log.Error("base injoignable", "err", err)
			os.Exit(1)
		}
		log.Warn("base pas encore prête, nouvel essai", "err", err)
		time.Sleep(2 * time.Second)
	}
}

// ---------------------------------------------------------------------------
// Handlers
// ---------------------------------------------------------------------------

type shop struct {
	db    *pgxpool.Pool
	cache *cache
}

type product struct {
	ID          int64   `json:"id"`
	Name        string  `json:"name"`
	Category    string  `json:"category"`
	Price       float64 `json:"price"`
	Description string  `json:"description"`
}

func handleHealth(w http.ResponseWriter, _ *http.Request) {
	if !ready.Load() || draining.Load() {
		http.Error(w, "pas prêt", http.StatusServiceUnavailable)
		return
	}
	fmt.Fprintln(w, "ok")
}

func handleVersion(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, map[string]string{"version": version, "hostname": hostname})
}

// GET /products?category=cat-07&page=3 — 100 produits d'une catégorie, du plus cher au moins cher.
func (s *shop) handleProducts(w http.ResponseWriter, r *http.Request) {
	if !servable(w) {
		return
	}
	// Cache de réponses, indexé par la query-string COMPLÈTE.
	key := r.URL.RawQuery
	if body, ok := s.cache.get(key); ok {
		w.Header().Set("X-Cache", "HIT")
		w.Header().Set("Content-Type", "application/json")
		w.Write(body)
		return
	}

	page, _ := strconv.Atoi(r.URL.Query().Get("page"))
	category := r.URL.Query().Get("category")
	query := `SELECT id, name, category, price, description FROM products
	          ORDER BY id LIMIT 100 OFFSET $1`
	args := []any{page * 100}
	if category != "" {
		query = `SELECT id, name, category, price, description FROM products
		         WHERE category = $1 ORDER BY price DESC LIMIT 100 OFFSET $2`
		args = []any{category, page * 100}
	}

	start := time.Now()
	rows, err := s.db.Query(r.Context(), query, args...)
	if err != nil {
		dbError(w, r, err)
		return
	}
	products := []product{}
	for rows.Next() {
		var p product
		if err := rows.Scan(&p.ID, &p.Name, &p.Category, &p.Price, &p.Description); err != nil {
			rows.Close()
			dbError(w, r, err)
			return
		}
		products = append(products, p)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		dbError(w, r, err)
		return
	}
	if d := time.Since(start); d > 100*time.Millisecond {
		log.Warn("requête SQL lente", "duree_ms", d.Milliseconds(), "category", category,
			"request_id", r.Header.Get("X-Request-Id"))
	}

	body, _ := json.Marshal(products)
	s.cache.put(key, body)
	w.Header().Set("X-Cache", "MISS")
	w.Header().Set("Content-Type", "application/json")
	w.Write(body)
}

// GET /products/{id}
func (s *shop) handleProduct(w http.ResponseWriter, r *http.Request) {
	if !servable(w) {
		return
	}
	var p product
	err := s.db.QueryRow(r.Context(),
		`SELECT id, name, category, price, description FROM products WHERE id = $1`,
		r.PathValue("id")).Scan(&p.ID, &p.Name, &p.Category, &p.Price, &p.Description)
	if err != nil {
		if strings.Contains(err.Error(), "no rows") {
			http.Error(w, "produit inconnu", http.StatusNotFound)
			return
		}
		dbError(w, r, err)
		return
	}
	writeJSON(w, p)
}

// POST /orders {"product_id": 42, "quantity": 1}
func (s *shop) handleOrder(w http.ResponseWriter, r *http.Request) {
	if !servable(w) {
		return
	}
	var in struct {
		ProductID int64 `json:"product_id"`
		Quantity  int   `json:"quantity"`
	}
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil || in.ProductID == 0 {
		http.Error(w, "commande invalide", http.StatusBadRequest)
		return
	}
	if in.Quantity <= 0 {
		in.Quantity = 1
	}

	tx, err := s.db.Begin(r.Context())
	if err != nil {
		dbError(w, r, err)
		return
	}
	defer tx.Rollback(r.Context())
	var id int64
	if err := tx.QueryRow(r.Context(),
		`INSERT INTO orders (product_id, quantity) VALUES ($1, $2) RETURNING id`,
		in.ProductID, in.Quantity).Scan(&id); err != nil {
		dbError(w, r, err)
		return
	}
	// Appel au prestataire de paiement (simulé : ~100 ms)... PENDANT que la
	// transaction, donc la connexion, reste ouverte.
	if _, err := tx.Exec(r.Context(), `SELECT pg_sleep(0.1)`); err != nil {
		dbError(w, r, err)
		return
	}
	if err := tx.Commit(r.Context()); err != nil {
		dbError(w, r, err)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(map[string]int64{"order_id": id})
}

// servable répond 503 tant que le préchargement n'est pas terminé.
func servable(w http.ResponseWriter) bool {
	if !ready.Load() {
		http.Error(w, "préchargement du catalogue en cours", http.StatusServiceUnavailable)
		return false
	}
	return true
}

func dbError(w http.ResponseWriter, r *http.Request, err error) {
	log.Error("erreur base de données", "err", err.Error(), "path", r.URL.Path,
		"request_id", r.Header.Get("X-Request-Id"))
	http.Error(w, "erreur interne", http.StatusInternalServerError)
}

func writeJSON(w http.ResponseWriter, v any) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(v)
}

// ---------------------------------------------------------------------------
// Cache de réponses en mémoire
// ---------------------------------------------------------------------------

type cache struct {
	mu      sync.Mutex
	max     int // 0 = illimité
	entries map[string][]byte
}

func newCache(max int) *cache { return &cache{max: max, entries: map[string][]byte{}} }

func (c *cache) get(k string) ([]byte, bool) {
	c.mu.Lock()
	defer c.mu.Unlock()
	v, ok := c.entries[k]
	if ok {
		cacheHits.Add(1)
	} else {
		cacheMisses.Add(1)
	}
	return v, ok
}

func (c *cache) put(k string, v []byte) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.max > 0 && len(c.entries) >= c.max {
		for old := range c.entries { // éviction d'une entrée quelconque
			delete(c.entries, old)
			break
		}
	}
	c.entries[k] = v
}

func (c *cache) len() int {
	c.mu.Lock()
	defer c.mu.Unlock()
	return len(c.entries)
}

// ---------------------------------------------------------------------------
// Divers
// ---------------------------------------------------------------------------

// healthcheck : sous-commande utilisée par HEALTHCHECK / healthcheck: (pas de curl dans l'image).
func healthcheck() int {
	c := http.Client{Timeout: 2 * time.Second}
	resp, err := c.Get("http://127.0.0.1:" + env("PORT", "8080") + "/health")
	if err != nil {
		return 1
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return 1
	}
	return 0
}

// instrument : journal JSON + métriques pour chaque requête, et un X-Request-Id
// pour corréler les logs d'une même requête.
func instrument(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("X-Request-Id") == "" {
			r.Header.Set("X-Request-Id", fmt.Sprintf("%016x", rand.Uint64()))
		}
		w.Header().Set("X-Request-Id", r.Header.Get("X-Request-Id"))
		w.Header().Set("X-Served-By", hostname)

		rec := &recorder{ResponseWriter: w, code: http.StatusOK}
		start := time.Now()
		next.ServeHTTP(rec, r)
		d := time.Since(start)

		route := r.Pattern
		if route == "" {
			route = "autre"
		}
		if route == "GET /metrics" || route == "GET /health" {
			return // ni log ni métrique pour le bruit de supervision
		}
		observe(route, rec.code, d)
		log.Info("requête", "method", r.Method, "path", r.URL.Path, "route", route,
			"code", rec.code, "duree_ms", d.Milliseconds(), "request_id", r.Header.Get("X-Request-Id"))
	})
}

type recorder struct {
	http.ResponseWriter
	code int
}

func (r *recorder) WriteHeader(code int) {
	r.code = code
	r.ResponseWriter.WriteHeader(code)
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
