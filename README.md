# Komoditní burza

Boilerplate: SvelteKit (TS) frontend + Node.js/Express (TS) backend + PostgreSQL.

## Layout

```
kdbs2/
├── backend/      Express + TypeScript + node-postgres
├── frontend/     SvelteKit + TypeScript
└── docker-compose.yml   Postgres for local dev
```

## Run

1. **Postgres** — this repo ships its own isolated container (db `kdbs2`, host port
   `55432` so it won't collide with any other Postgres on your machine). On first start
   it auto-creates the schema and seed data from `backend/db/`:
   ```
   docker compose up -d
   ```
   To rebuild the database from scratch later: `cd backend && npm run db:reset`.
2. **Backend**:
   ```
   cd backend
   cp .env.example .env
   npm install
   npm run dev
   ```
   → http://localhost:3001/api/health
3. **Frontend**:
   ```
   cd frontend
   npm install
   npm run dev
   ```
   → http://localhost:5173

The Vite dev server proxies `/api/*` to the backend, so the frontend can call `/api/health` directly.
