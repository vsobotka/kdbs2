INSERT INTO app_user (username, password_hash, balance) VALUES
  ('alice', crypt('alicepw', gen_salt('bf')), 100000),
  ('bob',   crypt('bobpw',   gen_salt('bf')), 50000)
ON CONFLICT (username) DO NOTHING;

INSERT INTO commodity (symbol, name, unit) VALUES
  ('WHEAT', 'Milling Wheat', 'tonne'),
  ('GOLD',  'Gold',          'oz'),
  ('OIL',   'Brent Crude',   'barrel')
ON CONFLICT (symbol) DO NOTHING;

INSERT INTO trade_order (commodity_id, user_id, side, quantity, price) VALUES
  (1, 1, 'buy', 10, 10),
  (1, 1, 'buy', 10, 11),
  (1, 1, 'buy', 10, 12),
  (1, 1, 'sell', 10, 14),
  (1, 1, 'sell', 10, 15),
  (1, 1, 'sell', 10, 16),

  (2, 1, 'buy', 10, 10),
  (2, 1, 'buy', 10, 11),
  (2, 1, 'buy', 10, 12),
  (2, 1, 'sell', 10, 14),
  (2, 1, 'sell', 10, 15),
  (2, 1, 'sell', 10, 16),

  (3, 1, 'buy', 10, 10),
  (3, 1, 'buy', 10, 11),
  (3, 1, 'buy', 10, 12),
  (3, 1, 'sell', 10, 14),
  (3, 1, 'sell', 10, 15),
  (3, 1, 'sell', 10, 16);

