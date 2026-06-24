INSERT INTO app_user (username, password_hash, balance, role) VALUES
  ('alice', crypt('alicepw', gen_salt('bf')), 100000, 'user'),
  ('bob',   crypt('bobpw',   gen_salt('bf')),  50000, 'user'),
  ('admin', crypt('adminpw', gen_salt('bf')),      0, 'admin')
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

INSERT INTO transaction_table (user_id, change, type, commodity_id, quantity, price) VALUES
  (1, 135000, 'deposit', null, null, null),
  (1, -25000, 'withdraw', null, null, null),
  (2, 50000, 'deposit', null, null, null),
  (1, -1200, 'buy', 1, 100, 12),
  (1, 300, 'sell', 1, 20, 15),
  (1, -9100, 'buy', 1, 910, 10);

