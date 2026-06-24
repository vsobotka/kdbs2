--
-- PostgreSQL database dump
--

\restrict u9aeI7LJdLM2VPO5e9seEU8Hcfgker0sfSO06a9RxAQQVUfIigbeanBQKtyIfYN

-- Dumped from database version 16.14 (Debian 16.14-1.pgdg13+1)
-- Dumped by pg_dump version 16.14 (Debian 16.14-1.pgdg13+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

ALTER TABLE IF EXISTS ONLY public.transaction_table DROP CONSTRAINT IF EXISTS transaction_table_user_id_fkey;
ALTER TABLE IF EXISTS ONLY public.transaction_table DROP CONSTRAINT IF EXISTS transaction_table_type_fkey;
ALTER TABLE IF EXISTS ONLY public.transaction_table DROP CONSTRAINT IF EXISTS transaction_table_commodity_id_fkey;
ALTER TABLE IF EXISTS ONLY public.trade_order DROP CONSTRAINT IF EXISTS trade_order_user_id_fkey;
ALTER TABLE IF EXISTS ONLY public.trade_order DROP CONSTRAINT IF EXISTS trade_order_side_fkey;
ALTER TABLE IF EXISTS ONLY public.trade_order DROP CONSTRAINT IF EXISTS trade_order_commodity_id_fkey;
ALTER TABLE IF EXISTS ONLY public.session DROP CONSTRAINT IF EXISTS session_user_id_fkey;
ALTER TABLE IF EXISTS ONLY public.holding DROP CONSTRAINT IF EXISTS holding_user_id_fkey;
ALTER TABLE IF EXISTS ONLY public.holding DROP CONSTRAINT IF EXISTS holding_commodity_id_fkey;
ALTER TABLE IF EXISTS ONLY public.app_user DROP CONSTRAINT IF EXISTS app_user_role_fkey;
DROP TRIGGER IF EXISTS trg_validate_order ON public.trade_order;
ALTER TABLE IF EXISTS ONLY public.user_role DROP CONSTRAINT IF EXISTS user_role_pkey;
ALTER TABLE IF EXISTS ONLY public.transaction_type DROP CONSTRAINT IF EXISTS transaction_type_pkey;
ALTER TABLE IF EXISTS ONLY public.transaction_table DROP CONSTRAINT IF EXISTS transaction_table_pkey;
ALTER TABLE IF EXISTS ONLY public.trade_order DROP CONSTRAINT IF EXISTS trade_order_pkey;
ALTER TABLE IF EXISTS ONLY public.session DROP CONSTRAINT IF EXISTS session_pkey;
ALTER TABLE IF EXISTS ONLY public.order_side DROP CONSTRAINT IF EXISTS order_side_pkey;
ALTER TABLE IF EXISTS ONLY public.holding DROP CONSTRAINT IF EXISTS holding_pkey;
ALTER TABLE IF EXISTS ONLY public.commodity DROP CONSTRAINT IF EXISTS commodity_symbol_key;
ALTER TABLE IF EXISTS ONLY public.commodity DROP CONSTRAINT IF EXISTS commodity_pkey;
ALTER TABLE IF EXISTS ONLY public.app_user DROP CONSTRAINT IF EXISTS app_user_username_key;
ALTER TABLE IF EXISTS ONLY public.app_user DROP CONSTRAINT IF EXISTS app_user_pkey;
ALTER TABLE IF EXISTS public.transaction_table ALTER COLUMN id DROP DEFAULT;
ALTER TABLE IF EXISTS public.trade_order ALTER COLUMN id DROP DEFAULT;
ALTER TABLE IF EXISTS public.commodity ALTER COLUMN id DROP DEFAULT;
ALTER TABLE IF EXISTS public.app_user ALTER COLUMN id DROP DEFAULT;
DROP VIEW IF EXISTS public.vw_order_book;
DROP TABLE IF EXISTS public.user_role;
DROP TABLE IF EXISTS public.transaction_type;
DROP SEQUENCE IF EXISTS public.transaction_table_id_seq;
DROP TABLE IF EXISTS public.transaction_table;
DROP SEQUENCE IF EXISTS public.trade_order_id_seq;
DROP TABLE IF EXISTS public.trade_order;
DROP TABLE IF EXISTS public.session;
DROP TABLE IF EXISTS public.order_side;
DROP TABLE IF EXISTS public.holding;
DROP SEQUENCE IF EXISTS public.commodity_id_seq;
DROP TABLE IF EXISTS public.commodity;
DROP SEQUENCE IF EXISTS public.app_user_id_seq;
DROP TABLE IF EXISTS public.app_user;
DROP FUNCTION IF EXISTS public.trg_validate_order();
DROP PROCEDURE IF EXISTS public.sp_place_order(IN p_user integer, IN p_commodity integer, IN p_side text, IN p_quantity numeric, IN p_price numeric);
DROP FUNCTION IF EXISTS public.fn_holding(p_user integer, p_commodity integer);
DROP EXTENSION IF EXISTS pgcrypto;
--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: fn_holding(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_holding(p_user integer, p_commodity integer) RETURNS numeric
    LANGUAGE sql STABLE
    AS $$
  SELECT COALESCE(
    (SELECT quantity FROM holding WHERE user_id = p_user AND commodity_id = p_commodity),
    0);
$$;


ALTER FUNCTION public.fn_holding(p_user integer, p_commodity integer) OWNER TO postgres;

--
-- Name: sp_place_order(integer, integer, text, numeric, numeric); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_place_order(IN p_user integer, IN p_commodity integer, IN p_side text, IN p_quantity numeric, IN p_price numeric)
    LANGUAGE plpgsql
    AS $$
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


ALTER PROCEDURE public.sp_place_order(IN p_user integer, IN p_commodity integer, IN p_side text, IN p_quantity numeric, IN p_price numeric) OWNER TO postgres;

--
-- Name: trg_validate_order(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.trg_validate_order() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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


ALTER FUNCTION public.trg_validate_order() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: app_user; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.app_user (
    id integer NOT NULL,
    username text NOT NULL,
    password_hash text NOT NULL,
    balance numeric DEFAULT 0 NOT NULL,
    role text DEFAULT 'user'::text NOT NULL,
    CONSTRAINT app_user_balance_check CHECK ((balance >= (0)::numeric))
);


ALTER TABLE public.app_user OWNER TO postgres;

--
-- Name: app_user_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.app_user_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.app_user_id_seq OWNER TO postgres;

--
-- Name: app_user_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.app_user_id_seq OWNED BY public.app_user.id;


--
-- Name: commodity; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.commodity (
    id integer NOT NULL,
    symbol text NOT NULL,
    name text NOT NULL,
    unit text NOT NULL
);


ALTER TABLE public.commodity OWNER TO postgres;

--
-- Name: commodity_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.commodity_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.commodity_id_seq OWNER TO postgres;

--
-- Name: commodity_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.commodity_id_seq OWNED BY public.commodity.id;


--
-- Name: holding; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.holding (
    user_id integer NOT NULL,
    commodity_id integer NOT NULL,
    quantity numeric DEFAULT 0 NOT NULL,
    CONSTRAINT holding_quantity_check CHECK ((quantity >= (0)::numeric))
);


ALTER TABLE public.holding OWNER TO postgres;

--
-- Name: order_side; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.order_side (
    code text NOT NULL,
    label text NOT NULL
);


ALTER TABLE public.order_side OWNER TO postgres;

--
-- Name: session; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.session (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone DEFAULT (now() + '7 days'::interval) NOT NULL
);


ALTER TABLE public.session OWNER TO postgres;

--
-- Name: trade_order; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.trade_order (
    id integer NOT NULL,
    commodity_id integer NOT NULL,
    user_id integer NOT NULL,
    side text NOT NULL,
    quantity numeric NOT NULL,
    price numeric NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT trade_order_price_check CHECK ((price > (0)::numeric)),
    CONSTRAINT trade_order_quantity_check CHECK ((quantity > (0)::numeric))
);


ALTER TABLE public.trade_order OWNER TO postgres;

--
-- Name: trade_order_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.trade_order_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.trade_order_id_seq OWNER TO postgres;

--
-- Name: trade_order_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.trade_order_id_seq OWNED BY public.trade_order.id;


--
-- Name: transaction_table; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.transaction_table (
    id integer NOT NULL,
    user_id integer NOT NULL,
    change numeric NOT NULL,
    type text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    commodity_id integer,
    quantity numeric,
    price numeric
);


ALTER TABLE public.transaction_table OWNER TO postgres;

--
-- Name: transaction_table_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.transaction_table_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.transaction_table_id_seq OWNER TO postgres;

--
-- Name: transaction_table_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.transaction_table_id_seq OWNED BY public.transaction_table.id;


--
-- Name: transaction_type; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.transaction_type (
    code text NOT NULL,
    label text NOT NULL
);


ALTER TABLE public.transaction_type OWNER TO postgres;

--
-- Name: user_role; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_role (
    code text NOT NULL,
    label text NOT NULL
);


ALTER TABLE public.user_role OWNER TO postgres;

--
-- Name: vw_order_book; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_order_book AS
 SELECT o.id,
    c.symbol,
    c.name AS commodity,
    u.username,
    o.side,
    o.quantity,
    o.price,
    o.created_at
   FROM ((public.trade_order o
     JOIN public.commodity c ON ((c.id = o.commodity_id)))
     JOIN public.app_user u ON ((u.id = o.user_id)));


ALTER VIEW public.vw_order_book OWNER TO postgres;

--
-- Name: app_user id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.app_user ALTER COLUMN id SET DEFAULT nextval('public.app_user_id_seq'::regclass);


--
-- Name: commodity id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.commodity ALTER COLUMN id SET DEFAULT nextval('public.commodity_id_seq'::regclass);


--
-- Name: trade_order id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trade_order ALTER COLUMN id SET DEFAULT nextval('public.trade_order_id_seq'::regclass);


--
-- Name: transaction_table id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transaction_table ALTER COLUMN id SET DEFAULT nextval('public.transaction_table_id_seq'::regclass);


--
-- Data for Name: app_user; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.app_user (id, username, password_hash, balance, role) FROM stdin;
1	alice	$2a$06$flb21pyOJObocin6wtdozO.OiMSvDl6srtBqeQCVQ2hJ5MMtwOKHu	100000	user
2	bob	$2a$06$vAdXNHc9fri8.33L7nqtGuXpmS44g.s/VqNmTU7LvVNKXdl96LUou	50000	user
3	admin	$2a$06$RMAHca8rJEmUvuCqL60h3.8wSVMKXnxPFOSBkKhg9Dwd54d51725.	0	admin
\.


--
-- Data for Name: commodity; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.commodity (id, symbol, name, unit) FROM stdin;
1	WHEAT	Milling Wheat	tonne
2	GOLD	Gold	oz
3	OIL	Brent Crude	barrel
\.


--
-- Data for Name: holding; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.holding (user_id, commodity_id, quantity) FROM stdin;
1	1	1000
1	2	1000
1	3	1000
2	1	1000
2	2	1000
2	3	1000
\.


--
-- Data for Name: order_side; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.order_side (code, label) FROM stdin;
buy	Buy
sell	Sell
\.


--
-- Data for Name: session; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.session (id, user_id, created_at, expires_at) FROM stdin;
\.


--
-- Data for Name: trade_order; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.trade_order (id, commodity_id, user_id, side, quantity, price, created_at) FROM stdin;
1	1	1	buy	10	10	2026-06-24 08:35:16.835164+00
2	1	1	buy	10	11	2026-06-24 08:35:16.835164+00
3	1	1	buy	10	12	2026-06-24 08:35:16.835164+00
4	1	2	sell	10	14	2026-06-24 08:35:16.835164+00
5	1	2	sell	10	15	2026-06-24 08:35:16.835164+00
6	1	2	sell	10	16	2026-06-24 08:35:16.835164+00
7	2	1	buy	10	10	2026-06-24 08:35:16.835164+00
8	2	1	buy	10	11	2026-06-24 08:35:16.835164+00
9	2	1	buy	10	12	2026-06-24 08:35:16.835164+00
10	2	2	sell	10	14	2026-06-24 08:35:16.835164+00
11	2	2	sell	10	15	2026-06-24 08:35:16.835164+00
12	2	2	sell	10	16	2026-06-24 08:35:16.835164+00
13	3	1	buy	10	10	2026-06-24 08:35:16.835164+00
14	3	1	buy	10	11	2026-06-24 08:35:16.835164+00
15	3	1	buy	10	12	2026-06-24 08:35:16.835164+00
16	3	2	sell	10	14	2026-06-24 08:35:16.835164+00
17	3	2	sell	10	15	2026-06-24 08:35:16.835164+00
18	3	2	sell	10	16	2026-06-24 08:35:16.835164+00
\.


--
-- Data for Name: transaction_table; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.transaction_table (id, user_id, change, type, created_at, commodity_id, quantity, price) FROM stdin;
1	1	135000	deposit	2026-06-24 08:35:16.835164+00	\N	\N	\N
2	1	-25000	withdraw	2026-06-24 08:35:16.835164+00	\N	\N	\N
3	2	50000	deposit	2026-06-24 08:35:16.835164+00	\N	\N	\N
4	1	-1200	buy	2026-06-24 08:35:16.835164+00	1	100	12
5	1	300	sell	2026-06-24 08:35:16.835164+00	1	20	15
6	1	-9100	buy	2026-06-24 08:35:16.835164+00	1	910	10
\.


--
-- Data for Name: transaction_type; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.transaction_type (code, label) FROM stdin;
deposit	Deposit
withdraw	Withdrawal
buy	Buy
sell	Sell
\.


--
-- Data for Name: user_role; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_role (code, label) FROM stdin;
user	User
admin	Administrator
\.


--
-- Name: app_user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.app_user_id_seq', 3, true);


--
-- Name: commodity_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.commodity_id_seq', 3, true);


--
-- Name: trade_order_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.trade_order_id_seq', 18, true);


--
-- Name: transaction_table_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.transaction_table_id_seq', 6, true);


--
-- Name: app_user app_user_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.app_user
    ADD CONSTRAINT app_user_pkey PRIMARY KEY (id);


--
-- Name: app_user app_user_username_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.app_user
    ADD CONSTRAINT app_user_username_key UNIQUE (username);


--
-- Name: commodity commodity_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.commodity
    ADD CONSTRAINT commodity_pkey PRIMARY KEY (id);


--
-- Name: commodity commodity_symbol_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.commodity
    ADD CONSTRAINT commodity_symbol_key UNIQUE (symbol);


--
-- Name: holding holding_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.holding
    ADD CONSTRAINT holding_pkey PRIMARY KEY (user_id, commodity_id);


--
-- Name: order_side order_side_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.order_side
    ADD CONSTRAINT order_side_pkey PRIMARY KEY (code);


--
-- Name: session session_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.session
    ADD CONSTRAINT session_pkey PRIMARY KEY (id);


--
-- Name: trade_order trade_order_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trade_order
    ADD CONSTRAINT trade_order_pkey PRIMARY KEY (id);


--
-- Name: transaction_table transaction_table_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transaction_table
    ADD CONSTRAINT transaction_table_pkey PRIMARY KEY (id);


--
-- Name: transaction_type transaction_type_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transaction_type
    ADD CONSTRAINT transaction_type_pkey PRIMARY KEY (code);


--
-- Name: user_role user_role_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_role
    ADD CONSTRAINT user_role_pkey PRIMARY KEY (code);


--
-- Name: trade_order trg_validate_order; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_validate_order BEFORE INSERT ON public.trade_order FOR EACH ROW EXECUTE FUNCTION public.trg_validate_order();


--
-- Name: app_user app_user_role_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.app_user
    ADD CONSTRAINT app_user_role_fkey FOREIGN KEY (role) REFERENCES public.user_role(code);


--
-- Name: holding holding_commodity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.holding
    ADD CONSTRAINT holding_commodity_id_fkey FOREIGN KEY (commodity_id) REFERENCES public.commodity(id);


--
-- Name: holding holding_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.holding
    ADD CONSTRAINT holding_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.app_user(id) ON DELETE CASCADE;


--
-- Name: session session_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.session
    ADD CONSTRAINT session_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.app_user(id) ON DELETE CASCADE;


--
-- Name: trade_order trade_order_commodity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trade_order
    ADD CONSTRAINT trade_order_commodity_id_fkey FOREIGN KEY (commodity_id) REFERENCES public.commodity(id);


--
-- Name: trade_order trade_order_side_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trade_order
    ADD CONSTRAINT trade_order_side_fkey FOREIGN KEY (side) REFERENCES public.order_side(code);


--
-- Name: trade_order trade_order_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trade_order
    ADD CONSTRAINT trade_order_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.app_user(id) ON DELETE CASCADE;


--
-- Name: transaction_table transaction_table_commodity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transaction_table
    ADD CONSTRAINT transaction_table_commodity_id_fkey FOREIGN KEY (commodity_id) REFERENCES public.commodity(id);


--
-- Name: transaction_table transaction_table_type_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transaction_table
    ADD CONSTRAINT transaction_table_type_fkey FOREIGN KEY (type) REFERENCES public.transaction_type(code);


--
-- Name: transaction_table transaction_table_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transaction_table
    ADD CONSTRAINT transaction_table_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.app_user(id) ON DELETE CASCADE;


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: pg_database_owner
--

GRANT USAGE ON SCHEMA public TO burza_app;


--
-- Name: TABLE app_user; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.app_user TO burza_app;


--
-- Name: SEQUENCE app_user_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.app_user_id_seq TO burza_app;


--
-- Name: TABLE commodity; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.commodity TO burza_app;


--
-- Name: SEQUENCE commodity_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.commodity_id_seq TO burza_app;


--
-- Name: TABLE holding; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.holding TO burza_app;


--
-- Name: TABLE order_side; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.order_side TO burza_app;


--
-- Name: TABLE session; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.session TO burza_app;


--
-- Name: TABLE trade_order; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.trade_order TO burza_app;


--
-- Name: SEQUENCE trade_order_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.trade_order_id_seq TO burza_app;


--
-- Name: TABLE transaction_table; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.transaction_table TO burza_app;


--
-- Name: SEQUENCE transaction_table_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.transaction_table_id_seq TO burza_app;


--
-- Name: TABLE transaction_type; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.transaction_type TO burza_app;


--
-- Name: TABLE user_role; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.user_role TO burza_app;


--
-- Name: TABLE vw_order_book; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.vw_order_book TO burza_app;


--
-- PostgreSQL database dump complete
--

\unrestrict u9aeI7LJdLM2VPO5e9seEU8Hcfgker0sfSO06a9RxAQQVUfIigbeanBQKtyIfYN

