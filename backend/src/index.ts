import express from 'express';
import cors from 'cors';
import { config } from './config.js';
import { pool } from './db.js';

const app = express();

app.use(cors({ origin: config.corsOrigin }));
app.use(express.json());

app.get('/api/commodities', async (_req, res) => {
  try {
    const { rows } = await pool.query(
      'SELECT id, symbol, name, unit FROM commodity ORDER BY symbol'
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ ok: false, error: (err as Error).message });
  }
});

app.post('/api/orders', async (req, res) => {
  const { commodityId, userId, side, quantity, price } = req.body;
  try {
    await pool.query('CALL sp_place_order($1, $2, $3, $4, $5)',
      [userId, commodityId, side, quantity, price]);
    res.status(201).json({ ok: true });
  } catch (err) {
    res.status(400).json({ error: (err as Error).message });
  }
});

app.post('/api/login', async (req, res) => {
  const { username, password } = req.body;
  try {
    const { rows } = await pool.query(
      `SELECT id FROM app_user
        WHERE username = $1
          AND password_hash = crypt($2, password_hash)`,
      [username, password]
    );
    if (rows.length === 0)
      return res.status(401).json({ error: 'Invalid credentials' });

    const { rows: s } = await pool.query(
      `INSERT INTO session (user_id) VALUES ($1) RETURNING id, expires_at`,
      [rows[0].id]
    );
    res.json({ token: s[0].id, expiresAt: s[0].expires_at });
  } catch (err) {
    res.status(500).json({ error: (err as Error).message });
  }
});

app.get('/api/me', async (req, res) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) return res.status(401).json({ error: 'no session' });
  try {
    const { rows } = await pool.query(
      `SELECT u.id, u.username, u.balance, u.role
         FROM session s
         JOIN app_user u ON u.id = s.user_id
        WHERE s.id = $1 AND s.expires_at > now()`,
      [token]
    );
    if (rows.length === 0) return res.status(401).json({ error: 'invalid session' });
    res.json(rows[0]);
  } catch (err) { res.status(500).json({ error: (err as Error).message }); }
});

app.post('/api/logout', async (req, res) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (token) await pool.query('DELETE FROM session WHERE id = $1', [token]);  // revoke
  res.json({ ok: true });
});

app.get('/api/commodities/:symbol', async (req, res) => {
  try {
    const { rows } = await pool.query(
      'SELECT id, symbol, name, unit FROM commodity WHERE symbol = $1',
      [req.params.symbol]
    );
    if (rows.length === 0) return res.status(404).json({ error: 'not found' });
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: (err as Error).message });
  }
});

app.get('/api/orders/:symbol', async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT id, side, quantity, price, created_at, username
         FROM vw_order_book
        WHERE symbol = $1
        ORDER BY price ASC`,
      [req.params.symbol]);
    res.json(rows);   // an empty order book is valid
  } catch (err) {
    res.status(500).json({ error: (err as Error).message });
  }
});

app.get('/api/transactions', async (req, res) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) return res.status(401).json({ error: 'not logged in' });

  try {
    const { rows } = await pool.query(
      `SELECT t.created_at, t.type, t.change
           FROM session s
          JOIN transaction_table t ON t.user_id = s.user_id
          WHERE s.id = $1 AND s.expires_at > now()
          ORDER BY t.created_at DESC`,
      [token]
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: (err as Error).message })
  }
});

app.post('/api/deposit', async (req, res) => {
  const { amount } = req.body;
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) return res.status(401).json({ error: 'not logged in' });

  if (amount <= 0) return res.status(400).json({ error: 'Deposit must be > 0' })

  try {
    const user = await pool.query(
      `SELECT s.user_id, u.role FROM session s
         JOIN app_user u ON u.id = s.user_id
        WHERE s.id = $1 AND s.expires_at > now() LIMIT 1`, [token])
    if (user.rows.length === 0) return res.status(401).json({ error: 'not logged in' });
    if (user.rows[0].role === 'admin') return res.status(403).json({ error: 'Admins cannot deposit' });
    const userId = user.rows[0].user_id;

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      await client.query(
        `INSERT INTO transaction_table (user_id, change, type) VALUES ($1, $2, 'deposit')`,
        [userId, amount]
      );
      const { rows } = await client.query(
        `UPDATE app_user SET balance = balance + $1 WHERE id = $2 RETURNING balance`,
        [amount, userId]
      );
      await client.query('COMMIT');
      res.status(201).json({ balance: rows[0].balance });
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
  } catch (err) {
    res.status(400).json({ error: (err as Error).message });
  }
});

app.post('/api/withdraw', async (req, res) => {
  const { amount } = req.body;
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) return res.status(401).json({ error: 'not logged in' });

  if (amount <= 0) return res.status(400).json({ error: 'Withdraw must be > 0' })

  try {
    const user = await pool.query(
      `SELECT s.user_id, u.role FROM session s
         JOIN app_user u ON u.id = s.user_id
        WHERE s.id = $1 AND s.expires_at > now() LIMIT 1`, [token])
    if (user.rows.length === 0) return res.status(401).json({ error: 'not logged in' });
    if (user.rows[0].role === 'admin') return res.status(403).json({ error: 'Admins cannot withdraw' });
    const userId = user.rows[0].user_id;

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      await client.query(
        `INSERT INTO transaction_table (user_id, change, type) VALUES ($1, $2, 'withdraw')`,
        [userId, -amount]
      );
      const { rows } = await client.query(
        `UPDATE app_user SET balance = balance + $1 WHERE id = $2 RETURNING balance`,
        [-amount, userId]
      );
      await client.query('COMMIT');
      res.status(201).json({ balance: rows[0].balance });
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
  } catch (err) {
    res.status(400).json({ error: (err as Error).message });
  }
});

// Admin only: create a new commodity
app.post('/api/commodities', async (req, res) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) return res.status(401).json({ error: 'not logged in' });
  const { symbol, name, unit } = req.body;
  try {
    const { rows: who } = await pool.query(
      `SELECT u.role FROM session s JOIN app_user u ON u.id = s.user_id
        WHERE s.id = $1 AND s.expires_at > now()`,
      [token]
    );
    if (who.length === 0) return res.status(401).json({ error: 'not logged in' });
    if (who[0].role !== 'admin') return res.status(403).json({ error: 'admin only' });

    const { rows } = await pool.query(
      `INSERT INTO commodity (symbol, name, unit) VALUES ($1, $2, $3) RETURNING *`,
      [symbol, name, unit]
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    res.status(400).json({ error: (err as Error).message });
  }
});

app.listen(config.port, () => {
  console.log(`backend listening on http://localhost:${config.port}`);
});
