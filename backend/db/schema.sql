CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'burza_app') THEN
    CREATE ROLE burza_app LOGIN PASSWORD 'burza_app_pw';
  END IF;
END $$;

DROP TABLE IF EXISTS trade_order CASCADE;
DROP TABLE IF EXISTS holding CASCADE;
DROP TABLE IF EXISTS commodity CASCADE;
DROP TABLE IF EXISTS session CASCADE;
DROP TABLE IF EXISTS app_user CASCADE;
DROP TABLE IF EXISTS transaction_table CASCADE;
DROP TABLE IF EXISTS order_side CASCADE;
DROP TABLE IF EXISTS transaction_type CASCADE;
DROP TABLE IF EXISTS user_role CASCADE;

CREATE TABLE order_side (
  code  TEXT PRIMARY KEY,
  label TEXT NOT NULL
);
INSERT INTO order_side (code, label) VALUES
  ('buy', 'Buy'), ('sell', 'Sell');

CREATE TABLE transaction_type (
  code  TEXT PRIMARY KEY,
  label TEXT NOT NULL
);
INSERT INTO transaction_type (code, label) VALUES
  ('deposit', 'Deposit'), ('withdraw', 'Withdrawal'),
  ('buy', 'Buy'), ('sell', 'Sell');

CREATE TABLE user_role (
  code  TEXT PRIMARY KEY,
  label TEXT NOT NULL
);
INSERT INTO user_role (code, label) VALUES
  ('user', 'User'), ('admin', 'Administrator');

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
  balance       NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (balance >= 0),
  role          TEXT NOT NULL DEFAULT 'user' REFERENCES user_role(code)
);

CREATE TABLE holding (
  user_id      INTEGER NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  commodity_id INTEGER NOT NULL REFERENCES commodity(id),
  quantity     NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (quantity >= 0),
  PRIMARY KEY (user_id, commodity_id)
);

CREATE TABLE trade_order (
  id            SERIAL PRIMARY KEY,
  commodity_id  INTEGER NOT NULL REFERENCES commodity(id),
  user_id       INTEGER NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  side          TEXT NOT NULL REFERENCES order_side(code),
  quantity      NUMERIC(14,2) NOT NULL CHECK (quantity > 0),
  price         NUMERIC(14,2) NOT NULL CHECK (price > 0),
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
  change        NUMERIC(14,2) NOT NULL,
  type          TEXT NOT NULL REFERENCES transaction_type(code),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  commodity_id  INTEGER NULL REFERENCES commodity(id),
  quantity      NUMERIC(14,2) NULL,
  price         NUMERIC(14,2) NULL
);

CREATE VIEW vw_order_book AS
SELECT o.id, c.symbol, c.name AS commodity, u.username,
       o.side, o.quantity, o.price, o.created_at
FROM trade_order o
JOIN commodity c ON c.id = o.commodity_id
JOIN app_user  u ON u.id = o.user_id;

-- Indexes on foreign-key / lookup columns (Postgres does not auto-index FKs).
CREATE INDEX idx_trade_order_book ON trade_order (commodity_id, price);  -- order-book query
CREATE INDEX idx_trade_order_user ON trade_order (user_id);
CREATE INDEX idx_transaction_user ON transaction_table (user_id);
CREATE INDEX idx_session_user     ON session (user_id);
CREATE INDEX idx_holding_commodity ON holding (commodity_id);

-- how much of a commodity a user currently owns (0 if none)
CREATE OR REPLACE FUNCTION fn_holding(p_user INTEGER, p_commodity INTEGER)
RETURNS NUMERIC LANGUAGE sql STABLE AS $$
  SELECT COALESCE(
    (SELECT quantity FROM holding WHERE user_id = p_user AND commodity_id = p_commodity),
    0);
$$;

-- reject an order the user can't back — no naked sells, no unaffordable buys
CREATE OR REPLACE FUNCTION trg_validate_order() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.side = 'sell' THEN
    IF fn_holding(NEW.user_id, NEW.commodity_id) < NEW.quantity THEN
      RAISE EXCEPTION 'Not enough holdings to sell';
    END IF;
  ELSIF NEW.side = 'buy' THEN
    IF (SELECT balance FROM app_user WHERE id = NEW.user_id) < NEW.quantity * NEW.price THEN
      RAISE EXCEPTION 'Insufficient balance';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validate_order
  BEFORE INSERT ON trade_order
  FOR EACH ROW EXECUTE FUNCTION trg_validate_order();

-- place an order, match it against the opposite side of the book, and
-- settle each fill (money + goods + ledger). Any unfilled remainder rests
CREATE OR REPLACE PROCEDURE sp_place_order(
  p_user INTEGER, p_commodity INTEGER, p_side TEXT, p_quantity NUMERIC, p_price NUMERIC
) LANGUAGE plpgsql AS $$
DECLARE
  v_remaining NUMERIC := p_quantity;
  v_fill NUMERIC;
  v_cost NUMERIC;
  r RECORD;
BEGIN
  IF p_side = 'buy' THEN
    FOR r IN
      SELECT * FROM trade_order
       WHERE commodity_id = p_commodity AND side = 'sell'
         AND price <= p_price AND user_id <> p_user
       ORDER BY price ASC, created_at ASC
    LOOP
      EXIT WHEN v_remaining <= 0;
      v_fill := LEAST(v_remaining, r.quantity);
      v_cost := v_fill * r.price;
      UPDATE app_user SET balance = balance - v_cost WHERE id = p_user;
      UPDATE app_user SET balance = balance + v_cost WHERE id = r.user_id;
      UPDATE holding SET quantity = quantity - v_fill
        WHERE user_id = r.user_id AND commodity_id = p_commodity;
      INSERT INTO holding (user_id, commodity_id, quantity)
        VALUES (p_user, p_commodity, v_fill)
        ON CONFLICT (user_id, commodity_id)
        DO UPDATE SET quantity = holding.quantity + EXCLUDED.quantity;
      INSERT INTO transaction_table (user_id, change, type, commodity_id, quantity, price)
        VALUES (p_user, -v_cost, 'buy',  p_commodity, v_fill, r.price),
               (r.user_id, v_cost, 'sell', p_commodity, v_fill, r.price);
      IF r.quantity > v_fill THEN
        UPDATE trade_order SET quantity = quantity - v_fill WHERE id = r.id;
      ELSE
        DELETE FROM trade_order WHERE id = r.id;
      END IF;
      v_remaining := v_remaining - v_fill;
    END LOOP;
    IF v_remaining > 0 THEN
      INSERT INTO trade_order (commodity_id, user_id, side, quantity, price)
        VALUES (p_commodity, p_user, 'buy', v_remaining, p_price);
    END IF;

  ELSIF p_side = 'sell' THEN
    FOR r IN
      SELECT * FROM trade_order
       WHERE commodity_id = p_commodity AND side = 'buy'
         AND price >= p_price AND user_id <> p_user
       ORDER BY price DESC, created_at ASC
    LOOP
      EXIT WHEN v_remaining <= 0;
      v_fill := LEAST(v_remaining, r.quantity);
      v_cost := v_fill * r.price;
      UPDATE app_user SET balance = balance - v_cost WHERE id = r.user_id;
      UPDATE app_user SET balance = balance + v_cost WHERE id = p_user;
      UPDATE holding SET quantity = quantity - v_fill
        WHERE user_id = p_user AND commodity_id = p_commodity;
      INSERT INTO holding (user_id, commodity_id, quantity)
        VALUES (r.user_id, p_commodity, v_fill)
        ON CONFLICT (user_id, commodity_id)
        DO UPDATE SET quantity = holding.quantity + EXCLUDED.quantity;
      INSERT INTO transaction_table (user_id, change, type, commodity_id, quantity, price)
        VALUES (p_user, v_cost, 'sell', p_commodity, v_fill, r.price),
               (r.user_id, -v_cost, 'buy', p_commodity, v_fill, r.price);
      IF r.quantity > v_fill THEN
        UPDATE trade_order SET quantity = quantity - v_fill WHERE id = r.id;
      ELSE
        DELETE FROM trade_order WHERE id = r.id;
      END IF;
      v_remaining := v_remaining - v_fill;
    END LOOP;
    IF v_remaining > 0 THEN
      INSERT INTO trade_order (commodity_id, user_id, side, quantity, price)
        VALUES (p_commodity, p_user, 'sell', v_remaining, p_price);
    END IF;
  END IF;
END;
$$;

GRANT CONNECT ON DATABASE kdbs2 TO burza_app;
GRANT USAGE ON SCHEMA public TO burza_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO burza_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO burza_app;

