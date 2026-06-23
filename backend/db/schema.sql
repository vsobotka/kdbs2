CREATE EXTENSION IF NOT EXISTS pgcrypto;

DROP TABLE IF EXISTS trade_order CASCADE;
DROP TABLE IF EXISTS commodity CASCADE;
DROP TABLE IF EXISTS session CASCADE;
DROP TABLE IF EXISTS app_user CASCADE;
DROP TABLE IF EXISTS transaction_table CASCADE;

CREATE TABLE commodity (
  id      SERIAL PRIMARY KEY,
  symbol  TEXT NOT NULL UNIQUE,
  name    TEXT NOT NULL,
  unit    TEXT NOT NULL
);

CREATE TABLE app_user (
  id            SERIAL PRIMARY KEY,
  username      TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  balance       NUMERIC NOT NULL DEFAULT 0 CHECK (balance >= 0)
);

CREATE TABLE trade_order (
  id            SERIAL PRIMARY KEY,
  commodity_id  INTEGER NOT NULL REFERENCES commodity(id),
  user_id       INTEGER NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  side          TEXT NOT NULL CHECK (side IN ('buy', 'sell')),
  quantity      NUMERIC NOT NULL CHECK (quantity > 0),
  price         NUMERIC NOT NULL CHECK (price > 0),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE session (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     INTEGER NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at  TIMESTAMPTZ NOT NULL DEFAULT now() + interval '7 days'
);

CREATE TABLE transaction_table (
  id            SERIAL PRIMARY KEY,
  user_id       INTEGER NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  change        NUMERIC NOT NULL,
  type          TEXT NOT NULL CHECK (type IN ('withdraw', 'deposit', 'buy', 'sell')),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  commodity_id  INTEGER NULL REFERENCES commodity(id),
  quantity      NUMERIC NULL,
  price         NUMERIC NULL
)

