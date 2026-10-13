-- Telemach Shop — schéma et jeu de données (exécuté au PREMIER démarrage de la base,
-- quand le volume est vide).
CREATE TABLE products (
  id          bigserial PRIMARY KEY,
  name        text           NOT NULL,
  category    text           NOT NULL,
  price       numeric(10, 2) NOT NULL,
  description text           NOT NULL
);

CREATE TABLE orders (
  id         bigserial PRIMARY KEY,
  product_id bigint      NOT NULL,
  quantity   int         NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- 1 000 000 de produits répartis sur 50 catégories (cat-01 … cat-50).
INSERT INTO products (name, category, price, description)
SELECT 'Produit ' || g,
       'cat-' || lpad(((g % 50) + 1)::text, 2, '0'),
       round((random() * 500 + 1)::numeric, 2),
       md5(g::text) || ' ' || md5((g * 7)::text) || ' ' || md5((g * 13)::text)
FROM generate_series(1, 1000000) AS g;

ANALYZE products;
