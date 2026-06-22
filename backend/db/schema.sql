CREATE EXTENSION IF NOT EXISTS pgcrypto;

DROP TABLE IF EXISTS trade_order CASCADE;
DROP TABLE IF EXISTS commodity CASCADE;
DROP TABLE IF EXISTS session CASCADE;
DROP TABLE IF EXISTS app_user CASCADE;

CREATE TABLE commodity (
  id      SERIAL PRIMARY KEY,
  symbol  TEXT NOT NULL UNIQUE,
  name    TEXT NOT NULL,
  unit    TEXT NOT NULL
);

CREATE TABLE trade_order (
  id            SERIAL PRIMARY KEY,
  commodity_id  INTEGER NOT NULL REFERENCES commodity(id),
  side          TEXT NOT NULL CHECK (side IN ('buy', 'sell')),
  quantity      NUMERIC NOT NULL CHECK (quantity > 0),
  price         NUMERIC NOT NULL CHECK (price > 0),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE app_user (
  id            SERIAL PRIMARY KEY,
  username      TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  balance       NUMERIC NOT NULL DEFAULT 0 CHECK (balance >= 0)
);

CREATE TABLE session (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     INTEGER NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at  TIMESTAMPTZ NOT NULL DEFAULT now() + interval '7 days'
);

