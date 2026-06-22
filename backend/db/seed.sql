INSERT INTO app_user (username, password_hash, balance) VALUES
  ('alice', crypt('alicepw', gen_salt('bf')), 100000),
  ('bob',   crypt('bobpw',   gen_salt('bf')), 50000)
ON CONFLICT (username) DO NOTHING;

INSERT INTO commodity (symbol, name, unit) VALUES
  ('WHEAT', 'Milling Wheat', 'tonne'),
  ('GOLD',  'Gold',          'oz'),
  ('OIL',   'Brent Crude',   'barrel')
ON CONFLICT (symbol) DO NOTHING;

