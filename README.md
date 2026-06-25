# Komoditní burza

Boilerplate: SvelteKit (TS) frontend + Node.js/Express (TS) backend + PostgreSQL.

## Layout

```
kdbs2/
├── backend/      Express + TypeScript + node-postgres (+ Dockerfile)
├── frontend/     SvelteKit + TypeScript (+ Dockerfile)
└── docker-compose.yml   Postgres + backend + frontend
```

## Run (everything in Docker)

```
docker compose up --build
```

That's it — this starts all three services:

- **postgres** — isolated container (db `kdbs2`, host port `55432` so it won't collide
  with any other Postgres). On first start it auto-creates schema + seed from `backend/db/`.
- **backend** — Express dev server, waits for Postgres to be healthy.
- **frontend** — SvelteKit dev server → **http://localhost:5173**

Open http://localhost:5173. All backend traffic (browser *and* the SvelteKit server)
flows through the Vite dev proxy on `:5173`, so a single `PUBLIC_BACKEND_URL` works in
both contexts; the backend itself is reached over the compose network and isn't published
to the host.

Stop with `docker compose down` (add `-v` to also wipe the database volume and re-seed
on the next start).

## Run (without Docker)

Keep Postgres in Docker but run the apps natively for faster edit loops:

1. **Postgres only:** `docker compose up -d postgres` (db rebuild later: `cd backend && npm run db:reset`).
2. **Backend:** `cd backend && cp .env.example .env && npm install && npm run dev` → http://localhost:3001
3. **Frontend:** `cd frontend && npm install && npm run dev` → http://localhost:5173

The Vite dev server proxies `/api/*` to the backend (default target `localhost:3001`,
overridable via `BACKEND_PROXY_TARGET`).
