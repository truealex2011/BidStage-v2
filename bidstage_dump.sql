--
-- PostgreSQL database dump
--

\restrict ejSEQ2zkfxr2dZ9HwZuWZVSJVNmnp6wapAAYUdKdGbLyfWpmRULhaMV7F2Pz1At

-- Dumped from database version 18.4
-- Dumped by pg_dump version 18.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: balance_topups; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.balance_topups (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    amount_usd numeric(12,2) NOT NULL,
    provider text NOT NULL,
    status text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT balance_topups_amount_usd_check CHECK ((amount_usd > (0)::numeric)),
    CONSTRAINT balance_topups_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'paid'::text, 'failed'::text])))
);


ALTER TABLE public.balance_topups OWNER TO postgres;

--
-- Name: balance_topups_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.balance_topups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.balance_topups_id_seq OWNER TO postgres;

--
-- Name: balance_topups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.balance_topups_id_seq OWNED BY public.balance_topups.id;


--
-- Name: bid_otps; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bid_otps (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    lot_id bigint NOT NULL,
    otp_code text NOT NULL,
    amount_usd numeric(12,2) NOT NULL,
    share_url text NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    consumed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.bid_otps OWNER TO postgres;

--
-- Name: bid_otps_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.bid_otps_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.bid_otps_id_seq OWNER TO postgres;

--
-- Name: bid_otps_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.bid_otps_id_seq OWNED BY public.bid_otps.id;


--
-- Name: bids; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bids (
    id bigint NOT NULL,
    lot_id bigint NOT NULL,
    user_id bigint NOT NULL,
    amount_usd numeric(12,2) NOT NULL,
    share_url text NOT NULL,
    share_verified boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    max_amount_usd numeric(12,2),
    is_proxy boolean DEFAULT false NOT NULL,
    CONSTRAINT bids_amount_usd_check CHECK ((amount_usd > (0)::numeric))
);


ALTER TABLE public.bids OWNER TO postgres;

--
-- Name: bids_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.bids_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.bids_id_seq OWNER TO postgres;

--
-- Name: bids_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.bids_id_seq OWNED BY public.bids.id;


--
-- Name: lot_chats; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.lot_chats (
    id bigint NOT NULL,
    lot_id bigint NOT NULL,
    sender_id bigint NOT NULL,
    recipient_id bigint NOT NULL,
    message text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    read_at timestamp with time zone
);


ALTER TABLE public.lot_chats OWNER TO postgres;

--
-- Name: lot_chats_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.lot_chats_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.lot_chats_id_seq OWNER TO postgres;

--
-- Name: lot_chats_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.lot_chats_id_seq OWNED BY public.lot_chats.id;


--
-- Name: lot_events; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.lot_events (
    id bigint NOT NULL,
    lot_id bigint NOT NULL,
    event_type text NOT NULL,
    actor_username text,
    actor_user_id bigint,
    amount_usd numeric(12,2),
    payload jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.lot_events OWNER TO postgres;

--
-- Name: lot_events_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.lot_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.lot_events_id_seq OWNER TO postgres;

--
-- Name: lot_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.lot_events_id_seq OWNED BY public.lot_events.id;


--
-- Name: lots; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.lots (
    id bigint NOT NULL,
    title text NOT NULL,
    artist text NOT NULL,
    description text,
    concert_date timestamp with time zone NOT NULL,
    lot_type text NOT NULL,
    start_price_usd numeric(12,2) NOT NULL,
    bid_step_usd numeric(12,2) NOT NULL,
    end_time timestamp with time zone NOT NULL,
    status text NOT NULL,
    winner_id bigint,
    image_url text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    original_duration_seconds integer NOT NULL,
    seller_id bigint,
    featured boolean DEFAULT false NOT NULL,
    listing_fee_usd numeric(10,2) DEFAULT 0 NOT NULL,
    final_value_fee_pct numeric(5,2) DEFAULT 10 NOT NULL,
    payment_window_minutes integer DEFAULT 1440 NOT NULL,
    CONSTRAINT lots_bid_step_usd_check CHECK ((bid_step_usd > (0)::numeric)),
    CONSTRAINT lots_lot_type_check CHECK ((lot_type = ANY (ARRAY['tickets'::text, 'vip'::text, 'table'::text]))),
    CONSTRAINT lots_start_price_usd_check CHECK ((start_price_usd > (0)::numeric)),
    CONSTRAINT lots_status_check CHECK ((status = ANY (ARRAY['active'::text, 'ended'::text, 'cancelled'::text])))
);


ALTER TABLE public.lots OWNER TO postgres;

--
-- Name: lots_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.lots_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.lots_id_seq OWNER TO postgres;

--
-- Name: lots_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.lots_id_seq OWNED BY public.lots.id;


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.notifications (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    kind text NOT NULL,
    title text NOT NULL,
    body text NOT NULL,
    lot_id bigint,
    payment_id bigint,
    read_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.notifications OWNER TO postgres;

--
-- Name: notifications_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.notifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.notifications_id_seq OWNER TO postgres;

--
-- Name: notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.notifications_id_seq OWNED BY public.notifications.id;


--
-- Name: payment_methods; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.payment_methods (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    provider text NOT NULL,
    external_id text,
    brand text,
    last4 text,
    exp_month integer,
    exp_year integer,
    is_default boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT payment_methods_provider_check CHECK ((provider = ANY (ARRAY['stripe'::text, 'yookassa'::text, 'idram'::text, 'demo'::text])))
);


ALTER TABLE public.payment_methods OWNER TO postgres;

--
-- Name: payment_methods_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.payment_methods_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.payment_methods_id_seq OWNER TO postgres;

--
-- Name: payment_methods_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.payment_methods_id_seq OWNED BY public.payment_methods.id;


--
-- Name: payments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.payments (
    id bigint NOT NULL,
    bid_id bigint NOT NULL,
    user_id bigint NOT NULL,
    amount_usd numeric(12,2) NOT NULL,
    currency text NOT NULL,
    provider text NOT NULL,
    status text NOT NULL,
    payment_url text,
    expires_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    held_in_escrow boolean DEFAULT false NOT NULL,
    released_to_seller boolean DEFAULT false NOT NULL,
    ticket_delivered boolean DEFAULT false NOT NULL,
    ticket_code text,
    buyer_confirmed boolean DEFAULT false NOT NULL,
    dispute_open boolean DEFAULT false NOT NULL,
    CONSTRAINT payments_amount_usd_check CHECK ((amount_usd > (0)::numeric)),
    CONSTRAINT payments_currency_check CHECK ((currency = ANY (ARRAY['AMD'::text, 'RUB'::text, 'USD'::text]))),
    CONSTRAINT payments_provider_check CHECK ((provider = ANY (ARRAY['stripe'::text, 'yookassa'::text, 'idram'::text]))),
    CONSTRAINT payments_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'paid'::text, 'failed'::text, 'expired'::text])))
);


ALTER TABLE public.payments OWNER TO postgres;

--
-- Name: payments_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.payments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.payments_id_seq OWNER TO postgres;

--
-- Name: payments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.payments_id_seq OWNED BY public.payments.id;


--
-- Name: proxy_bids; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.proxy_bids (
    id bigint NOT NULL,
    lot_id bigint NOT NULL,
    user_id bigint NOT NULL,
    max_amount_usd numeric(12,2) NOT NULL,
    share_url text NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT proxy_bids_max_amount_usd_check CHECK ((max_amount_usd > (0)::numeric))
);


ALTER TABLE public.proxy_bids OWNER TO postgres;

--
-- Name: proxy_bids_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.proxy_bids_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.proxy_bids_id_seq OWNER TO postgres;

--
-- Name: proxy_bids_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.proxy_bids_id_seq OWNED BY public.proxy_bids.id;


--
-- Name: seller_reviews; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.seller_reviews (
    id bigint NOT NULL,
    seller_id bigint NOT NULL,
    buyer_id bigint NOT NULL,
    lot_id bigint NOT NULL,
    payment_id bigint,
    rating smallint NOT NULL,
    comment text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT seller_reviews_rating_check CHECK (((rating >= 1) AND (rating <= 5)))
);


ALTER TABLE public.seller_reviews OWNER TO postgres;

--
-- Name: seller_reviews_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.seller_reviews_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.seller_reviews_id_seq OWNER TO postgres;

--
-- Name: seller_reviews_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.seller_reviews_id_seq OWNED BY public.seller_reviews.id;


--
-- Name: translation_cache; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.translation_cache (
    id bigint NOT NULL,
    source_hash text NOT NULL,
    source_lang text NOT NULL,
    target_lang text NOT NULL,
    source_text text NOT NULL,
    translated_text text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.translation_cache OWNER TO postgres;

--
-- Name: translation_cache_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.translation_cache_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.translation_cache_id_seq OWNER TO postgres;

--
-- Name: translation_cache_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.translation_cache_id_seq OWNED BY public.translation_cache.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    username text NOT NULL,
    email text,
    country text NOT NULL,
    vk_id bigint,
    vk_token text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    balance_usd numeric(12,2) DEFAULT 0 NOT NULL,
    password_hash text,
    CONSTRAINT users_country_check CHECK ((country = ANY (ARRAY['AM'::text, 'RU'::text, 'OTHER'::text])))
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.users_id_seq OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: watchlist; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.watchlist (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    lot_id bigint NOT NULL,
    notify_outbid boolean DEFAULT true NOT NULL,
    notify_ending boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.watchlist OWNER TO postgres;

--
-- Name: watchlist_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.watchlist_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.watchlist_id_seq OWNER TO postgres;

--
-- Name: watchlist_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.watchlist_id_seq OWNED BY public.watchlist.id;


--
-- Name: balance_topups id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.balance_topups ALTER COLUMN id SET DEFAULT nextval('public.balance_topups_id_seq'::regclass);


--
-- Name: bid_otps id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bid_otps ALTER COLUMN id SET DEFAULT nextval('public.bid_otps_id_seq'::regclass);


--
-- Name: bids id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bids ALTER COLUMN id SET DEFAULT nextval('public.bids_id_seq'::regclass);


--
-- Name: lot_chats id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lot_chats ALTER COLUMN id SET DEFAULT nextval('public.lot_chats_id_seq'::regclass);


--
-- Name: lot_events id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lot_events ALTER COLUMN id SET DEFAULT nextval('public.lot_events_id_seq'::regclass);


--
-- Name: lots id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lots ALTER COLUMN id SET DEFAULT nextval('public.lots_id_seq'::regclass);


--
-- Name: notifications id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notifications ALTER COLUMN id SET DEFAULT nextval('public.notifications_id_seq'::regclass);


--
-- Name: payment_methods id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payment_methods ALTER COLUMN id SET DEFAULT nextval('public.payment_methods_id_seq'::regclass);


--
-- Name: payments id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payments ALTER COLUMN id SET DEFAULT nextval('public.payments_id_seq'::regclass);


--
-- Name: proxy_bids id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proxy_bids ALTER COLUMN id SET DEFAULT nextval('public.proxy_bids_id_seq'::regclass);


--
-- Name: seller_reviews id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.seller_reviews ALTER COLUMN id SET DEFAULT nextval('public.seller_reviews_id_seq'::regclass);


--
-- Name: translation_cache id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.translation_cache ALTER COLUMN id SET DEFAULT nextval('public.translation_cache_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: watchlist id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.watchlist ALTER COLUMN id SET DEFAULT nextval('public.watchlist_id_seq'::regclass);


--
-- Data for Name: balance_topups; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.balance_topups (id, user_id, amount_usd, provider, status, created_at) FROM stdin;
1	3	100.00	demo	paid	2026-05-15 21:54:40.690844+07
2	3	100.00	stripe	pending	2026-05-15 21:55:19.653069+07
3	3	200.00	idram	pending	2026-05-15 21:55:24.509656+07
4	3	200.00	demo	paid	2026-05-15 21:55:28.298149+07
5	3	100.00	idram	pending	2026-05-15 22:13:43.222805+07
6	3	100.00	idram	pending	2026-05-15 22:13:47.181709+07
7	9	1230.00	demo	paid	2026-05-17 16:45:52.946571+07
8	9	22222.00	yookassa	pending	2026-05-17 16:46:02.274604+07
9	9	2222.00	yookassa	pending	2026-05-17 16:46:10.425289+07
10	1	100000.00	demo	paid	2026-05-17 17:39:17.939782+07
11	1	99999.00	stripe	paid	2026-05-17 17:40:00.144805+07
12	9	100000.00	demo	paid	2026-05-17 17:45:42.074219+07
13	1	50.00	demo	paid	2026-05-17 18:57:25.266331+07
14	1	50.00	demo	paid	2026-05-17 18:58:06.108096+07
15	1	50.00	demo	paid	2026-05-17 19:09:39.985657+07
16	24	111.11	yookassa	paid	2026-05-18 19:17:13.252542+07
17	24	0.56	yookassa	paid	2026-05-18 19:17:20.272216+07
18	1	50.00	demo	paid	2026-05-18 19:38:10.73087+07
19	1	25.00	demo	paid	2026-05-18 19:38:36.260817+07
20	24	11.11	demo	paid	2026-05-18 20:49:04.208137+07
21	24	111111.11	yookassa	paid	2026-05-18 20:49:32.563459+07
22	23	111111.11	demo	paid	2026-05-18 20:50:11.691104+07
23	23	1370.37	demo	paid	2026-05-18 20:50:40.115429+07
24	13	1111.11	demo	paid	2026-05-18 21:34:00.237714+07
25	13	1.00	demo	paid	2026-05-18 21:34:16.585737+07
26	13	11.11	demo	paid	2026-05-19 19:23:43.216767+07
27	13	11111.11	demo	paid	2026-05-19 19:23:49.547014+07
28	13	11111.11	demo	paid	2026-05-19 19:23:56.788915+07
29	13	1111.11	demo	paid	2026-05-19 19:24:01.417251+07
30	13	111.11	demo	paid	2026-05-19 19:24:13.64998+07
31	13	111.11	yookassa	paid	2026-05-19 19:25:07.633745+07
32	1	200.00	demo	paid	2026-05-19 20:18:29.761439+07
33	2	5000.00	demo	paid	2026-05-19 20:18:29.79376+07
34	3	5000.00	demo	paid	2026-05-19 20:18:29.809137+07
35	1	200.00	demo	paid	2026-05-19 20:23:55.51076+07
36	2	5000.00	demo	paid	2026-05-19 20:23:55.517243+07
37	3	5000.00	demo	paid	2026-05-19 20:23:55.540989+07
38	1	200.00	demo	paid	2026-05-19 20:25:27.287324+07
39	2	5000.00	demo	paid	2026-05-19 20:25:27.293339+07
40	3	5000.00	demo	paid	2026-05-19 20:25:27.312931+07
41	1	200.00	demo	paid	2026-05-19 20:43:00.645787+07
42	2	5000.00	demo	paid	2026-05-19 20:43:00.676972+07
43	3	5000.00	demo	paid	2026-05-19 20:43:00.707922+07
44	25	11111.11	demo	paid	2026-05-19 20:48:30.833626+07
45	8	256410.26	demo	paid	2026-05-19 20:57:06.479391+07
46	1	1.00	demo	paid	2026-05-20 11:56:17.327687+07
47	1	0.50	demo	paid	2026-05-20 11:57:10.441505+07
48	1	0.50	demo	paid	2026-05-20 18:47:21.51028+07
49	1	0.50	demo	paid	2026-05-20 18:51:13.93221+07
50	25	111111.11	demo	paid	2026-05-20 20:06:17.951798+07
\.


--
-- Data for Name: bid_otps; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.bid_otps (id, user_id, lot_id, otp_code, amount_usd, share_url, expires_at, consumed_at, created_at) FROM stdin;
12	24	31	861877	850.00	https://t.me/bigstage123/2	2026-05-18 21:57:42.642883+07	2026-05-18 21:52:49.609829+07	2026-05-18 21:52:42.643027+07
13	24	31	113725	850.00	https://t.me/bigstage123/3	2026-05-18 21:59:43.008725+07	2026-05-18 21:54:45.829286+07	2026-05-18 21:54:43.008859+07
14	13	30	559602	2490.00	https://t.me/bigstage123/4	2026-05-19 19:31:12.972043+07	2026-05-19 19:26:16.99547+07	2026-05-19 19:26:12.972211+07
15	9	49	994500	224.44	https://t.me/bigstage123/5	2026-05-19 20:56:06.826676+07	2026-05-19 20:51:10.901326+07	2026-05-19 20:51:06.826808+07
16	9	49	764974	228.88	https://t.me/bigstage123/5	2026-05-19 20:57:07.472411+07	2026-05-19 20:52:10.746867+07	2026-05-19 20:52:07.47258+07
17	8	49	110653	255555.56	https://t.me/bigstage123/5	2026-05-19 21:02:33.455343+07	2026-05-19 20:57:39.993962+07	2026-05-19 20:57:33.455477+07
18	25	50	766498	566.68	https://t.me/bigstage123/6	2026-05-20 20:06:07.913761+07	2026-05-20 20:01:11.391654+07	2026-05-20 20:01:07.913905+07
19	25	50	455591	1111.12	https://t.me/bigstage123/6	2026-05-20 20:07:00.981437+07	2026-05-20 20:02:03.352018+07	2026-05-20 20:02:00.981588+07
20	24	50	686986	1133.34	https://t.me/bigstage123/6	2026-05-20 20:08:58.120422+07	2026-05-20 20:04:06.570719+07	2026-05-20 20:03:58.120561+07
21	25	50	069680	1144.46	https://t.me/bigstage123/6	2026-05-20 20:09:29.550734+07	2026-05-20 20:04:32.066874+07	2026-05-20 20:04:29.550887+07
22	25	50	163861	122216.67	https://t.me/bigstage123/6	2026-05-20 20:11:40.851843+07	2026-05-20 20:06:43.367709+07	2026-05-20 20:06:40.85198+07
\.


--
-- Data for Name: bids; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.bids (id, lot_id, user_id, amount_usd, share_url, share_verified, created_at, max_amount_usd, is_proxy) FROM stdin;
16	35	9	99.45	https://vk.com/feed	t	2026-05-17 16:51:38.5678+07	\N	f
17	35	9	349.45	https://vk.com/feed	t	2026-05-17 17:35:58.974027+07	\N	f
18	35	1	399.45	https://vk.com/какашка	t	2026-05-17 17:41:38.58077+07	\N	f
19	35	1	449.45	https://vk.com/какашка	t	2026-05-17 17:41:41.531162+07	\N	f
20	35	1	499.45	https://vk.com/feed	t	2026-05-17 17:41:46.061139+07	\N	f
21	35	1	549.45	https://vk.com/feed	t	2026-05-17 17:42:55.170157+07	\N	f
22	35	1	4358.98	https://vk.com/feed	t	2026-05-17 17:44:47.23852+07	\N	f
23	33	9	660.00	https://vk.com/feed	t	2026-05-17 20:11:54.15404+07	\N	f
42	46	3	110.00	https://vk.com/wall2_2	t	2026-05-19 20:23:58.601487+07	\N	f
43	47	2	100.00	https://vk.com/wall1_1	t	2026-05-19 20:25:27.343476+07	\N	f
44	47	3	110.00	https://vk.com/wall2_2	t	2026-05-19 20:25:30.353878+07	\N	f
36	31	24	850.00	https://t.me/bigstage123/3	t	2026-05-18 21:54:45.831513+07	\N	f
37	30	1	2360.00	https://t.me/bigstage123/4	t	2026-05-19 19:22:58.866884+07	\N	f
38	30	13	2490.00	https://t.me/bigstage123/4	t	2026-05-19 19:26:16.999213+07	\N	f
39	45	2	100.00	https://vk.com/wall1_1	t	2026-05-19 20:18:29.840523+07	\N	f
40	45	3	110.00	https://vk.com/wall2_2	t	2026-05-19 20:18:32.872609+07	\N	f
41	46	2	100.00	https://vk.com/wall1_1	t	2026-05-19 20:23:55.588137+07	\N	f
45	48	2	100.00	https://vk.com/wall1_1	t	2026-05-19 20:43:00.735501+07	\N	f
46	48	3	110.00	https://vk.com/wall2_2	t	2026-05-19 20:43:03.765257+07	\N	f
47	48	2	120.00	https://vk.com/wall1_1	t	2026-05-19 20:43:05.782553+07	\N	f
48	48	3	130.00	https://vk.com/wall2_2	t	2026-05-19 20:43:07.803851+07	\N	f
49	48	2	140.00	https://vk.com/wall1_1	t	2026-05-19 20:43:09.828906+07	\N	f
50	48	3	150.00	https://vk.com/wall2_2	t	2026-05-19 20:43:11.838532+07	\N	f
51	48	2	160.00	https://vk.com/wall1_1	t	2026-05-19 20:43:13.856853+07	\N	f
52	48	3	170.00	https://vk.com/wall2_2	t	2026-05-19 20:43:15.880624+07	\N	f
53	48	2	180.00	https://vk.com/wall1_1	t	2026-05-19 20:43:17.903069+07	\N	f
54	48	3	190.00	https://vk.com/wall2_2	t	2026-05-19 20:43:19.914807+07	\N	f
55	48	2	200.00	https://vk.com/wall1_1	t	2026-05-19 20:43:21.931845+07	\N	f
56	48	3	210.00	https://vk.com/wall2_2	t	2026-05-19 20:43:23.943507+07	\N	f
57	49	1	222.22	https://t.me/bigstage123/5	t	2026-05-19 20:50:43.704879+07	\N	f
58	49	9	224.44	https://t.me/bigstage123/5	t	2026-05-19 20:51:10.904588+07	\N	f
59	49	1	226.66	https://t.me/bigstage123/5	t	2026-05-19 20:51:12.917155+07	\N	f
60	49	9	228.88	https://t.me/bigstage123/5	t	2026-05-19 20:52:10.748887+07	\N	f
61	49	1	231.10	https://t.me/bigstage123/5	t	2026-05-19 20:52:12.762485+07	\N	f
62	49	9	233.32	https://t.me/bigstage123/5	t	2026-05-19 20:53:14.292135+07	\N	f
63	49	1	235.54	https://t.me/bigstage123/5	t	2026-05-19 20:53:16.300143+07	\N	f
64	49	9	237.76	https://t.me/bigstage123/5	t	2026-05-19 20:53:18.309443+07	\N	f
65	49	1	239.98	https://t.me/bigstage123/5	t	2026-05-19 20:53:20.31895+07	\N	f
66	49	9	242.20	https://t.me/bigstage123/5	t	2026-05-19 20:53:22.334332+07	\N	f
67	49	1	244.42	https://t.me/bigstage123/5	t	2026-05-19 20:53:24.35347+07	\N	f
68	49	9	246.64	https://t.me/bigstage123/5	t	2026-05-19 20:53:26.367939+07	\N	f
69	49	1	248.86	https://t.me/bigstage123/5	t	2026-05-19 20:53:28.392072+07	\N	f
70	49	9	251.08	https://t.me/bigstage123/5	t	2026-05-19 20:53:30.409141+07	\N	f
71	49	1	253.30	https://t.me/bigstage123/5	t	2026-05-19 20:53:32.425103+07	\N	f
72	49	9	255.52	https://t.me/bigstage123/5	t	2026-05-19 20:53:34.434832+07	\N	f
73	49	1	257.74	https://t.me/bigstage123/5	t	2026-05-19 20:53:36.452306+07	\N	f
74	49	9	259.96	https://t.me/bigstage123/5	t	2026-05-19 20:53:38.468653+07	\N	f
75	49	1	262.18	https://t.me/bigstage123/5	t	2026-05-19 20:53:40.477091+07	\N	f
76	49	9	264.40	https://t.me/bigstage123/5	t	2026-05-19 20:53:42.49331+07	\N	f
77	49	1	266.62	https://t.me/bigstage123/5	t	2026-05-19 20:53:44.511765+07	\N	f
78	49	9	268.84	https://t.me/bigstage123/5	t	2026-05-19 20:53:46.518734+07	\N	f
79	49	1	271.06	https://t.me/bigstage123/5	t	2026-05-19 20:53:48.535465+07	\N	f
80	49	9	273.28	https://t.me/bigstage123/5	t	2026-05-19 20:53:50.553197+07	\N	f
81	49	1	275.50	https://t.me/bigstage123/5	t	2026-05-19 20:53:52.569343+07	\N	f
82	49	9	277.72	https://t.me/bigstage123/5	t	2026-05-19 20:53:54.594755+07	\N	f
83	49	1	279.94	https://t.me/bigstage123/5	t	2026-05-19 20:53:56.611+07	\N	f
84	49	9	282.16	https://t.me/bigstage123/5	t	2026-05-19 20:53:58.626405+07	\N	f
85	49	1	284.38	https://t.me/bigstage123/5	t	2026-05-19 20:54:00.635147+07	\N	f
86	49	9	286.60	https://t.me/bigstage123/5	t	2026-05-19 20:54:02.645278+07	\N	f
87	49	1	288.82	https://t.me/bigstage123/5	t	2026-05-19 20:54:04.660701+07	\N	f
88	49	9	291.04	https://t.me/bigstage123/5	t	2026-05-19 20:54:06.669403+07	\N	f
89	49	1	293.26	https://t.me/bigstage123/5	t	2026-05-19 20:54:08.680089+07	\N	f
90	49	9	295.48	https://t.me/bigstage123/5	t	2026-05-19 20:54:10.71133+07	\N	f
91	49	1	297.70	https://t.me/bigstage123/5	t	2026-05-19 20:54:12.728791+07	\N	f
92	49	9	299.92	https://t.me/bigstage123/5	t	2026-05-19 20:54:14.745241+07	\N	f
93	49	1	302.14	https://t.me/bigstage123/5	t	2026-05-19 20:54:16.766203+07	\N	f
94	49	9	304.36	https://t.me/bigstage123/5	t	2026-05-19 20:54:18.779705+07	\N	f
95	49	1	306.58	https://t.me/bigstage123/5	t	2026-05-19 20:54:20.79632+07	\N	f
96	49	9	308.80	https://t.me/bigstage123/5	t	2026-05-19 20:54:22.807083+07	\N	f
97	49	1	311.02	https://t.me/bigstage123/5	t	2026-05-19 20:54:24.812609+07	\N	f
98	49	9	313.24	https://t.me/bigstage123/5	t	2026-05-19 20:54:26.821514+07	\N	f
99	49	1	315.46	https://t.me/bigstage123/5	t	2026-05-19 20:54:28.838932+07	\N	f
100	49	9	317.68	https://t.me/bigstage123/5	t	2026-05-19 20:54:30.856064+07	\N	f
101	49	1	319.90	https://t.me/bigstage123/5	t	2026-05-19 20:54:32.872043+07	\N	f
102	49	9	322.12	https://t.me/bigstage123/5	t	2026-05-19 20:54:34.890802+07	\N	f
103	49	1	324.34	https://t.me/bigstage123/5	t	2026-05-19 20:54:36.906107+07	\N	f
104	49	9	326.56	https://t.me/bigstage123/5	t	2026-05-19 20:54:38.918831+07	\N	f
105	49	1	328.78	https://t.me/bigstage123/5	t	2026-05-19 20:54:40.931492+07	\N	f
106	49	9	331.00	https://t.me/bigstage123/5	t	2026-05-19 20:54:42.946247+07	\N	f
107	49	1	333.22	https://t.me/bigstage123/5	t	2026-05-19 20:54:44.957174+07	\N	f
108	49	9	335.44	https://t.me/bigstage123/5	t	2026-05-19 20:54:46.96657+07	\N	f
109	49	1	337.66	https://t.me/bigstage123/5	t	2026-05-19 20:54:48.981026+07	\N	f
110	49	9	339.88	https://t.me/bigstage123/5	t	2026-05-19 20:54:50.997562+07	\N	f
111	49	1	342.10	https://t.me/bigstage123/5	t	2026-05-19 20:54:53.014956+07	\N	f
112	49	9	344.32	https://t.me/bigstage123/5	t	2026-05-19 20:54:55.030165+07	\N	f
113	49	1	346.54	https://t.me/bigstage123/5	t	2026-05-19 20:54:57.040225+07	\N	f
114	49	9	348.76	https://t.me/bigstage123/5	t	2026-05-19 20:54:59.051124+07	\N	f
115	49	1	350.98	https://t.me/bigstage123/5	t	2026-05-19 20:55:01.064643+07	\N	f
116	49	9	353.20	https://t.me/bigstage123/5	t	2026-05-19 20:55:03.080646+07	\N	f
117	49	1	355.42	https://t.me/bigstage123/5	t	2026-05-19 20:55:05.09061+07	\N	f
118	49	9	357.64	https://t.me/bigstage123/5	t	2026-05-19 20:55:07.106928+07	\N	f
119	49	1	359.86	https://t.me/bigstage123/5	t	2026-05-19 20:55:09.124872+07	\N	f
120	49	9	362.08	https://t.me/bigstage123/5	t	2026-05-19 20:55:11.143473+07	\N	f
121	49	1	364.30	https://t.me/bigstage123/5	t	2026-05-19 20:55:13.165346+07	\N	f
122	49	9	366.52	https://t.me/bigstage123/5	t	2026-05-19 20:55:15.179427+07	\N	f
123	49	1	368.74	https://t.me/bigstage123/5	t	2026-05-19 20:55:17.199615+07	\N	f
124	49	9	370.96	https://t.me/bigstage123/5	t	2026-05-19 20:55:19.215891+07	\N	f
125	49	1	373.18	https://t.me/bigstage123/5	t	2026-05-19 20:55:21.228127+07	\N	f
126	49	9	375.40	https://t.me/bigstage123/5	t	2026-05-19 20:55:23.246749+07	\N	f
127	49	1	377.62	https://t.me/bigstage123/5	t	2026-05-19 20:55:25.27366+07	\N	f
128	49	9	379.84	https://t.me/bigstage123/5	t	2026-05-19 20:55:27.28203+07	\N	f
129	49	1	382.06	https://t.me/bigstage123/5	t	2026-05-19 20:55:29.300412+07	\N	f
130	49	9	384.28	https://t.me/bigstage123/5	t	2026-05-19 20:55:31.315985+07	\N	f
131	49	1	386.50	https://t.me/bigstage123/5	t	2026-05-19 20:55:33.324277+07	\N	f
132	49	9	388.72	https://t.me/bigstage123/5	t	2026-05-19 20:55:35.343152+07	\N	f
133	49	1	390.94	https://t.me/bigstage123/5	t	2026-05-19 20:55:37.358403+07	\N	f
134	49	9	393.16	https://t.me/bigstage123/5	t	2026-05-19 20:55:39.37483+07	\N	f
135	49	1	395.38	https://t.me/bigstage123/5	t	2026-05-19 20:55:41.384806+07	\N	f
136	49	9	397.60	https://t.me/bigstage123/5	t	2026-05-19 20:55:43.409804+07	\N	f
137	49	1	399.82	https://t.me/bigstage123/5	t	2026-05-19 20:55:45.425687+07	\N	f
138	49	9	402.04	https://t.me/bigstage123/5	t	2026-05-19 20:55:47.434741+07	\N	f
139	49	1	404.26	https://t.me/bigstage123/5	t	2026-05-19 20:55:49.450151+07	\N	f
140	49	9	406.48	https://t.me/bigstage123/5	t	2026-05-19 20:55:51.460937+07	\N	f
141	49	1	408.70	https://t.me/bigstage123/5	t	2026-05-19 20:55:53.467388+07	\N	f
142	49	9	410.92	https://t.me/bigstage123/5	t	2026-05-19 20:55:55.477888+07	\N	f
143	49	1	413.14	https://t.me/bigstage123/5	t	2026-05-19 20:55:57.489649+07	\N	f
144	49	9	415.36	https://t.me/bigstage123/5	t	2026-05-19 20:55:59.502849+07	\N	f
145	49	1	417.58	https://t.me/bigstage123/5	t	2026-05-19 20:56:01.517681+07	\N	f
146	49	9	419.80	https://t.me/bigstage123/5	t	2026-05-19 20:56:03.526925+07	\N	f
147	49	1	422.02	https://t.me/bigstage123/5	t	2026-05-19 20:56:05.543012+07	\N	f
148	49	9	424.24	https://t.me/bigstage123/5	t	2026-05-19 20:56:07.553142+07	\N	f
149	49	1	426.46	https://t.me/bigstage123/5	t	2026-05-19 20:56:09.5765+07	\N	f
150	49	9	428.68	https://t.me/bigstage123/5	t	2026-05-19 20:56:11.609231+07	\N	f
151	49	1	430.90	https://t.me/bigstage123/5	t	2026-05-19 20:56:13.627593+07	\N	f
152	49	9	433.12	https://t.me/bigstage123/5	t	2026-05-19 20:56:15.65191+07	\N	f
153	49	1	435.34	https://t.me/bigstage123/5	t	2026-05-19 20:56:17.669187+07	\N	f
154	49	9	437.56	https://t.me/bigstage123/5	t	2026-05-19 20:56:19.686396+07	\N	f
155	49	1	439.78	https://t.me/bigstage123/5	t	2026-05-19 20:56:21.702372+07	\N	f
156	49	9	442.00	https://t.me/bigstage123/5	t	2026-05-19 20:56:23.719832+07	\N	f
157	49	1	444.22	https://t.me/bigstage123/5	t	2026-05-19 20:56:25.736367+07	\N	f
158	49	9	446.44	https://t.me/bigstage123/5	t	2026-05-19 20:56:27.753273+07	\N	f
159	49	1	448.66	https://t.me/bigstage123/5	t	2026-05-19 20:56:29.77026+07	\N	f
160	49	9	450.88	https://t.me/bigstage123/5	t	2026-05-19 20:56:31.791766+07	\N	f
161	49	1	453.10	https://t.me/bigstage123/5	t	2026-05-19 20:56:33.812309+07	\N	f
162	49	9	455.32	https://t.me/bigstage123/5	t	2026-05-19 20:56:35.829371+07	\N	f
163	49	1	457.54	https://t.me/bigstage123/5	t	2026-05-19 20:56:37.846287+07	\N	f
164	49	9	459.76	https://t.me/bigstage123/5	t	2026-05-19 20:56:39.855502+07	\N	f
165	49	1	461.98	https://t.me/bigstage123/5	t	2026-05-19 20:56:41.871959+07	\N	f
166	49	9	464.20	https://t.me/bigstage123/5	t	2026-05-19 20:56:44.037765+07	\N	f
167	49	1	466.42	https://t.me/bigstage123/5	t	2026-05-19 20:56:46.063933+07	\N	f
168	49	9	468.64	https://t.me/bigstage123/5	t	2026-05-19 20:56:48.07991+07	\N	f
169	49	1	470.86	https://t.me/bigstage123/5	t	2026-05-19 20:56:50.097163+07	\N	f
170	49	9	473.08	https://t.me/bigstage123/5	t	2026-05-19 20:56:52.110524+07	\N	f
171	49	1	475.30	https://t.me/bigstage123/5	t	2026-05-19 20:56:54.121322+07	\N	f
172	49	9	477.52	https://t.me/bigstage123/5	t	2026-05-19 20:56:56.138954+07	\N	f
173	49	1	479.74	https://t.me/bigstage123/5	t	2026-05-19 20:56:58.259726+07	\N	f
174	49	9	481.96	https://t.me/bigstage123/5	t	2026-05-19 20:57:00.272086+07	\N	f
175	49	1	484.18	https://t.me/bigstage123/5	t	2026-05-19 20:57:02.289025+07	\N	f
176	49	9	486.40	https://t.me/bigstage123/5	t	2026-05-19 20:57:04.30556+07	\N	f
177	49	1	488.62	https://t.me/bigstage123/5	t	2026-05-19 20:57:06.314904+07	\N	f
178	49	9	490.84	https://t.me/bigstage123/5	t	2026-05-19 20:57:08.330761+07	\N	f
179	49	1	493.06	https://t.me/bigstage123/5	t	2026-05-19 20:57:10.457772+07	\N	f
180	49	9	495.28	https://t.me/bigstage123/5	t	2026-05-19 20:57:12.474298+07	\N	f
181	49	1	497.50	https://t.me/bigstage123/5	t	2026-05-19 20:57:14.490272+07	\N	f
182	49	9	499.72	https://t.me/bigstage123/5	t	2026-05-19 20:57:16.509205+07	\N	f
183	49	1	501.94	https://t.me/bigstage123/5	t	2026-05-19 20:57:18.524741+07	\N	f
184	49	9	504.16	https://t.me/bigstage123/5	t	2026-05-19 20:57:20.53451+07	\N	f
185	49	1	506.38	https://t.me/bigstage123/5	t	2026-05-19 20:57:22.549237+07	\N	f
186	49	9	508.60	https://t.me/bigstage123/5	t	2026-05-19 20:57:24.566849+07	\N	f
187	49	1	510.82	https://t.me/bigstage123/5	t	2026-05-19 20:57:26.590743+07	\N	f
188	49	9	513.04	https://t.me/bigstage123/5	t	2026-05-19 20:57:28.615529+07	\N	f
189	49	1	515.26	https://t.me/bigstage123/5	t	2026-05-19 20:57:30.62808+07	\N	f
190	49	9	517.48	https://t.me/bigstage123/5	t	2026-05-19 20:57:32.640056+07	\N	f
191	49	1	519.70	https://t.me/bigstage123/5	t	2026-05-19 20:57:34.649633+07	\N	f
192	49	9	521.92	https://t.me/bigstage123/5	t	2026-05-19 20:57:36.662898+07	\N	f
193	49	1	524.14	https://t.me/bigstage123/5	t	2026-05-19 20:57:38.674564+07	\N	f
194	49	8	255555.56	https://t.me/bigstage123/5	t	2026-05-19 20:57:39.997349+07	\N	f
195	49	9	526.36	https://t.me/bigstage123/5	t	2026-05-19 20:57:40.690773+07	\N	f
196	49	9	255557.78	https://t.me/bigstage123/5	t	2026-05-19 20:57:42.028327+07	\N	f
197	49	1	255557.78	https://t.me/bigstage123/5	t	2026-05-19 20:57:42.703294+07	\N	f
198	49	1	255560.00	https://t.me/bigstage123/5	t	2026-05-19 20:57:44.041323+07	\N	f
199	49	9	255560.00	https://t.me/bigstage123/5	t	2026-05-19 20:57:44.713904+07	\N	f
200	49	9	255562.22	https://t.me/bigstage123/5	t	2026-05-19 20:57:46.050548+07	\N	f
201	49	1	255562.22	https://t.me/bigstage123/5	t	2026-05-19 20:57:46.724594+07	\N	f
202	49	1	255564.44	https://t.me/bigstage123/5	t	2026-05-19 20:57:48.062236+07	\N	f
203	49	9	255564.44	https://t.me/bigstage123/5	t	2026-05-19 20:57:48.734186+07	\N	f
204	49	9	255566.66	https://t.me/bigstage123/5	t	2026-05-19 20:57:50.07658+07	\N	f
205	49	1	255566.66	https://t.me/bigstage123/5	t	2026-05-19 20:57:50.74992+07	\N	f
206	49	1	255568.88	https://t.me/bigstage123/5	t	2026-05-19 20:57:52.101047+07	\N	f
207	49	9	255568.88	https://t.me/bigstage123/5	t	2026-05-19 20:57:52.761134+07	\N	f
208	49	9	255571.10	https://t.me/bigstage123/5	t	2026-05-19 20:57:54.118014+07	\N	f
209	49	1	255571.10	https://t.me/bigstage123/5	t	2026-05-19 20:57:54.785753+07	\N	f
210	49	1	255573.32	https://t.me/bigstage123/5	t	2026-05-19 20:57:56.129996+07	\N	f
211	49	9	255573.32	https://t.me/bigstage123/5	t	2026-05-19 20:57:56.797512+07	\N	f
212	49	9	255575.54	https://t.me/bigstage123/5	t	2026-05-19 20:57:58.141561+07	\N	f
213	49	1	255575.54	https://t.me/bigstage123/5	t	2026-05-19 20:57:58.810125+07	\N	f
214	49	1	255577.76	https://t.me/bigstage123/5	t	2026-05-19 20:58:00.151906+07	\N	f
215	49	9	255577.76	https://t.me/bigstage123/5	t	2026-05-19 20:58:00.825704+07	\N	f
216	49	9	255579.98	https://t.me/bigstage123/5	t	2026-05-19 20:58:02.168256+07	\N	f
217	49	1	255579.98	https://t.me/bigstage123/5	t	2026-05-19 20:58:02.842809+07	\N	f
218	49	1	255582.20	https://t.me/bigstage123/5	t	2026-05-19 20:58:04.186132+07	\N	f
219	49	9	255582.20	https://t.me/bigstage123/5	t	2026-05-19 20:58:04.852946+07	\N	f
220	49	9	255584.42	https://t.me/bigstage123/5	t	2026-05-19 20:58:06.200714+07	\N	f
221	49	1	255584.42	https://t.me/bigstage123/5	t	2026-05-19 20:58:06.868133+07	\N	f
222	49	1	255586.64	https://t.me/bigstage123/5	t	2026-05-19 20:58:08.209852+07	\N	f
223	49	9	255586.64	https://t.me/bigstage123/5	t	2026-05-19 20:58:08.886141+07	\N	f
224	49	9	255588.86	https://t.me/bigstage123/5	t	2026-05-19 20:58:10.22693+07	\N	f
225	49	1	255588.86	https://t.me/bigstage123/5	t	2026-05-19 20:58:10.899967+07	\N	f
226	49	1	255591.08	https://t.me/bigstage123/5	t	2026-05-19 20:58:12.240325+07	\N	f
227	49	9	255591.08	https://t.me/bigstage123/5	t	2026-05-19 20:58:12.909489+07	\N	f
229	49	1	255593.30	https://t.me/bigstage123/5	t	2026-05-19 20:58:14.926165+07	\N	f
228	49	9	255593.30	https://t.me/bigstage123/5	t	2026-05-19 20:58:14.260571+07	\N	f
230	49	1	255595.52	https://t.me/bigstage123/5	t	2026-05-19 20:58:16.276972+07	\N	f
231	49	9	255595.52	https://t.me/bigstage123/5	t	2026-05-19 20:58:16.943263+07	\N	f
232	49	9	255597.74	https://t.me/bigstage123/5	t	2026-05-19 20:58:18.289151+07	\N	f
233	49	1	255597.74	https://t.me/bigstage123/5	t	2026-05-19 20:58:18.967899+07	\N	f
234	49	1	255599.96	https://t.me/bigstage123/5	t	2026-05-19 20:58:20.299488+07	\N	f
235	49	9	255599.96	https://t.me/bigstage123/5	t	2026-05-19 20:58:20.977974+07	\N	f
236	49	9	255602.18	https://t.me/bigstage123/5	t	2026-05-19 20:58:22.310819+07	\N	f
237	49	1	255602.18	https://t.me/bigstage123/5	t	2026-05-19 20:58:22.994575+07	\N	f
238	49	1	255604.40	https://t.me/bigstage123/5	t	2026-05-19 20:58:24.322444+07	\N	f
239	49	9	255604.40	https://t.me/bigstage123/5	t	2026-05-19 20:58:25.012411+07	\N	f
240	49	9	255606.62	https://t.me/bigstage123/5	t	2026-05-19 20:58:26.335339+07	\N	f
241	49	1	255606.62	https://t.me/bigstage123/5	t	2026-05-19 20:58:27.023657+07	\N	f
242	49	1	255608.84	https://t.me/bigstage123/5	t	2026-05-19 20:58:28.360023+07	\N	f
243	49	9	255608.84	https://t.me/bigstage123/5	t	2026-05-19 20:58:29.035815+07	\N	f
244	49	9	255611.06	https://t.me/bigstage123/5	t	2026-05-19 20:58:30.371693+07	\N	f
245	49	1	255611.06	https://t.me/bigstage123/5	t	2026-05-19 20:58:31.046024+07	\N	f
246	49	1	255613.28	https://t.me/bigstage123/5	t	2026-05-19 20:58:32.382519+07	\N	f
247	49	9	255613.28	https://t.me/bigstage123/5	t	2026-05-19 20:58:33.056427+07	\N	f
248	49	9	255615.50	https://t.me/bigstage123/5	t	2026-05-19 20:58:34.401791+07	\N	f
249	49	1	255615.50	https://t.me/bigstage123/5	t	2026-05-19 20:58:35.069993+07	\N	f
250	49	1	255617.72	https://t.me/bigstage123/5	t	2026-05-19 20:58:36.41944+07	\N	f
251	49	9	255617.72	https://t.me/bigstage123/5	t	2026-05-19 20:58:37.086359+07	\N	f
252	49	9	255619.94	https://t.me/bigstage123/5	t	2026-05-19 20:58:38.434283+07	\N	f
253	49	1	255619.94	https://t.me/bigstage123/5	t	2026-05-19 20:58:39.104728+07	\N	f
254	49	1	255622.16	https://t.me/bigstage123/5	t	2026-05-19 20:58:40.445955+07	\N	f
255	49	9	255622.16	https://t.me/bigstage123/5	t	2026-05-19 20:58:41.120893+07	\N	f
256	49	9	255624.38	https://t.me/bigstage123/5	t	2026-05-19 20:58:42.453365+07	\N	f
257	49	1	255624.38	https://t.me/bigstage123/5	t	2026-05-19 20:58:43.139787+07	\N	f
258	49	1	255626.60	https://t.me/bigstage123/5	t	2026-05-19 20:58:44.478715+07	\N	f
259	49	9	255626.60	https://t.me/bigstage123/5	t	2026-05-19 20:58:45.154175+07	\N	f
260	49	9	255628.82	https://t.me/bigstage123/5	t	2026-05-19 20:58:46.495014+07	\N	f
261	49	1	255628.82	https://t.me/bigstage123/5	t	2026-05-19 20:58:47.170844+07	\N	f
262	49	1	255631.04	https://t.me/bigstage123/5	t	2026-05-19 20:58:48.507205+07	\N	f
263	49	9	255631.04	https://t.me/bigstage123/5	t	2026-05-19 20:58:49.185976+07	\N	f
264	49	9	255633.26	https://t.me/bigstage123/5	t	2026-05-19 20:58:50.521288+07	\N	f
265	49	1	255633.26	https://t.me/bigstage123/5	t	2026-05-19 20:58:51.206517+07	\N	f
266	49	1	255635.48	https://t.me/bigstage123/5	t	2026-05-19 20:58:52.545211+07	\N	f
267	49	9	255635.48	https://t.me/bigstage123/5	t	2026-05-19 20:58:53.218723+07	\N	f
268	49	9	255637.70	https://t.me/bigstage123/5	t	2026-05-19 20:58:54.562519+07	\N	f
269	49	1	255637.70	https://t.me/bigstage123/5	t	2026-05-19 20:58:55.230114+07	\N	f
270	49	1	255639.92	https://t.me/bigstage123/5	t	2026-05-19 20:58:56.577808+07	\N	f
271	49	9	255639.92	https://t.me/bigstage123/5	t	2026-05-19 20:58:57.247855+07	\N	f
272	49	9	255642.14	https://t.me/bigstage123/5	t	2026-05-19 20:58:58.589014+07	\N	f
273	49	1	255642.14	https://t.me/bigstage123/5	t	2026-05-19 20:58:59.263786+07	\N	f
274	49	1	255644.36	https://t.me/bigstage123/5	t	2026-05-19 20:59:00.614715+07	\N	f
275	49	9	255644.36	https://t.me/bigstage123/5	t	2026-05-19 20:59:01.278085+07	\N	f
276	49	9	255646.58	https://t.me/bigstage123/5	t	2026-05-19 20:59:02.62958+07	\N	f
277	49	1	255646.58	https://t.me/bigstage123/5	t	2026-05-19 20:59:03.288673+07	\N	f
278	49	1	255648.80	https://t.me/bigstage123/5	t	2026-05-19 20:59:04.646497+07	\N	f
279	49	9	255648.80	https://t.me/bigstage123/5	t	2026-05-19 20:59:05.304976+07	\N	f
280	49	9	255651.02	https://t.me/bigstage123/5	t	2026-05-19 20:59:06.655679+07	\N	f
281	49	1	255651.02	https://t.me/bigstage123/5	t	2026-05-19 20:59:07.322279+07	\N	f
282	49	1	255653.24	https://t.me/bigstage123/5	t	2026-05-19 20:59:08.664163+07	\N	f
283	49	9	255653.24	https://t.me/bigstage123/5	t	2026-05-19 20:59:09.33775+07	\N	f
284	49	9	255655.46	https://t.me/bigstage123/5	t	2026-05-19 20:59:10.679927+07	\N	f
285	49	1	255655.46	https://t.me/bigstage123/5	t	2026-05-19 20:59:11.362112+07	\N	f
286	49	1	255657.68	https://t.me/bigstage123/5	t	2026-05-19 20:59:12.697922+07	\N	f
287	49	9	255657.68	https://t.me/bigstage123/5	t	2026-05-19 20:59:13.376639+07	\N	f
288	49	9	255659.90	https://t.me/bigstage123/5	t	2026-05-19 20:59:14.721964+07	\N	f
289	49	1	255659.90	https://t.me/bigstage123/5	t	2026-05-19 20:59:15.39011+07	\N	f
290	49	1	255662.12	https://t.me/bigstage123/5	t	2026-05-19 20:59:16.732981+07	\N	f
291	49	9	255662.12	https://t.me/bigstage123/5	t	2026-05-19 20:59:17.400093+07	\N	f
292	49	9	255664.34	https://t.me/bigstage123/5	t	2026-05-19 20:59:18.757674+07	\N	f
293	49	1	255664.34	https://t.me/bigstage123/5	t	2026-05-19 20:59:19.415327+07	\N	f
294	49	1	255666.56	https://t.me/bigstage123/5	t	2026-05-19 20:59:20.774532+07	\N	f
296	49	9	255668.78	https://t.me/bigstage123/5	t	2026-05-19 20:59:22.797396+07	\N	f
295	49	9	255666.56	https://t.me/bigstage123/5	t	2026-05-19 20:59:21.431064+07	\N	f
297	49	1	255668.78	https://t.me/bigstage123/5	t	2026-05-19 20:59:23.440556+07	\N	f
298	49	1	255671.00	https://t.me/bigstage123/5	t	2026-05-19 20:59:24.809504+07	\N	f
299	49	9	255671.00	https://t.me/bigstage123/5	t	2026-05-19 20:59:25.455687+07	\N	f
300	49	9	255673.22	https://t.me/bigstage123/5	t	2026-05-19 20:59:26.824886+07	\N	f
301	49	1	255673.22	https://t.me/bigstage123/5	t	2026-05-19 20:59:27.465618+07	\N	f
302	49	1	255675.44	https://t.me/bigstage123/5	t	2026-05-19 20:59:28.838991+07	\N	f
303	49	9	255675.44	https://t.me/bigstage123/5	t	2026-05-19 20:59:29.480959+07	\N	f
304	49	9	255677.66	https://t.me/bigstage123/5	t	2026-05-19 20:59:30.84761+07	\N	f
305	49	1	255677.66	https://t.me/bigstage123/5	t	2026-05-19 20:59:31.489778+07	\N	f
306	49	1	255679.88	https://t.me/bigstage123/5	t	2026-05-19 20:59:32.856095+07	\N	f
307	49	9	255679.88	https://t.me/bigstage123/5	t	2026-05-19 20:59:33.501294+07	\N	f
308	49	9	255682.10	https://t.me/bigstage123/5	t	2026-05-19 20:59:34.867519+07	\N	f
309	49	1	255682.10	https://t.me/bigstage123/5	t	2026-05-19 20:59:35.515138+07	\N	f
310	49	1	255684.32	https://t.me/bigstage123/5	t	2026-05-19 20:59:36.878208+07	\N	f
311	49	9	255684.32	https://t.me/bigstage123/5	t	2026-05-19 20:59:37.534038+07	\N	f
312	49	9	255686.54	https://t.me/bigstage123/5	t	2026-05-19 20:59:38.890333+07	\N	f
313	49	1	255686.54	https://t.me/bigstage123/5	t	2026-05-19 20:59:39.556279+07	\N	f
314	49	1	255688.76	https://t.me/bigstage123/5	t	2026-05-19 20:59:40.904157+07	\N	f
315	49	9	255688.76	https://t.me/bigstage123/5	t	2026-05-19 20:59:41.564885+07	\N	f
316	49	9	255690.98	https://t.me/bigstage123/5	t	2026-05-19 20:59:42.915118+07	\N	f
317	49	1	255690.98	https://t.me/bigstage123/5	t	2026-05-19 20:59:43.577189+07	\N	f
318	49	1	255693.20	https://t.me/bigstage123/5	t	2026-05-19 20:59:44.936099+07	\N	f
319	49	9	255693.20	https://t.me/bigstage123/5	t	2026-05-19 20:59:45.589302+07	\N	f
320	49	9	255695.42	https://t.me/bigstage123/5	t	2026-05-19 20:59:46.950513+07	\N	f
321	49	1	255695.42	https://t.me/bigstage123/5	t	2026-05-19 20:59:47.600332+07	\N	f
322	49	1	255697.64	https://t.me/bigstage123/5	t	2026-05-19 20:59:48.961897+07	\N	f
323	49	9	255697.64	https://t.me/bigstage123/5	t	2026-05-19 20:59:49.61632+07	\N	f
324	49	9	255699.86	https://t.me/bigstage123/5	t	2026-05-19 20:59:50.975573+07	\N	f
325	49	1	255699.86	https://t.me/bigstage123/5	t	2026-05-19 20:59:51.625231+07	\N	f
326	49	1	255702.08	https://t.me/bigstage123/5	t	2026-05-19 20:59:52.99318+07	\N	f
327	49	9	255702.08	https://t.me/bigstage123/5	t	2026-05-19 20:59:53.641732+07	\N	f
328	49	9	255704.30	https://t.me/bigstage123/5	t	2026-05-19 20:59:55.009034+07	\N	f
329	49	1	255704.30	https://t.me/bigstage123/5	t	2026-05-19 20:59:55.659059+07	\N	f
330	49	1	255706.52	https://t.me/bigstage123/5	t	2026-05-19 20:59:57.122927+07	\N	f
331	49	9	255706.52	https://t.me/bigstage123/5	t	2026-05-19 20:59:57.695049+07	\N	f
332	49	9	255708.74	https://t.me/bigstage123/5	t	2026-05-19 20:59:59.141112+07	\N	f
333	49	1	255708.74	https://t.me/bigstage123/5	t	2026-05-19 20:59:59.718998+07	\N	f
334	49	1	255710.96	https://t.me/bigstage123/5	t	2026-05-19 21:00:01.158088+07	\N	f
335	49	9	255710.96	https://t.me/bigstage123/5	t	2026-05-19 21:00:01.733626+07	\N	f
336	49	9	255713.18	https://t.me/bigstage123/5	t	2026-05-19 21:00:03.176172+07	\N	f
337	49	1	255713.18	https://t.me/bigstage123/5	t	2026-05-19 21:00:03.750307+07	\N	f
338	49	1	255715.40	https://t.me/bigstage123/5	t	2026-05-19 21:00:05.192444+07	\N	f
339	49	9	255715.40	https://t.me/bigstage123/5	t	2026-05-19 21:00:05.758291+07	\N	f
340	49	9	255717.62	https://t.me/bigstage123/5	t	2026-05-19 21:00:07.208809+07	\N	f
341	49	1	255717.62	https://t.me/bigstage123/5	t	2026-05-19 21:00:07.766713+07	\N	f
342	49	1	255719.84	https://t.me/bigstage123/5	t	2026-05-19 21:00:09.224808+07	\N	f
343	49	9	255719.84	https://t.me/bigstage123/5	t	2026-05-19 21:00:09.777646+07	\N	f
344	49	9	255722.06	https://t.me/bigstage123/5	t	2026-05-19 21:00:11.245018+07	\N	f
345	49	1	255722.06	https://t.me/bigstage123/5	t	2026-05-19 21:00:11.793722+07	\N	f
346	49	1	255724.28	https://t.me/bigstage123/5	t	2026-05-19 21:00:13.259997+07	\N	f
347	49	9	255724.28	https://t.me/bigstage123/5	t	2026-05-19 21:00:13.80981+07	\N	f
348	49	9	255726.50	https://t.me/bigstage123/5	t	2026-05-19 21:00:15.276265+07	\N	f
349	49	1	255726.50	https://t.me/bigstage123/5	t	2026-05-19 21:00:15.825043+07	\N	f
350	49	1	255728.72	https://t.me/bigstage123/5	t	2026-05-19 21:00:17.284525+07	\N	f
351	49	9	255728.72	https://t.me/bigstage123/5	t	2026-05-19 21:00:17.826443+07	\N	f
352	49	9	255730.94	https://t.me/bigstage123/5	t	2026-05-19 21:00:19.309016+07	\N	f
353	49	1	255730.94	https://t.me/bigstage123/5	t	2026-05-19 21:00:19.844314+07	\N	f
354	49	1	255733.16	https://t.me/bigstage123/5	t	2026-05-19 21:00:21.329119+07	\N	f
355	49	9	255733.16	https://t.me/bigstage123/5	t	2026-05-19 21:00:21.856579+07	\N	f
356	49	9	255735.38	https://t.me/bigstage123/5	t	2026-05-19 21:00:23.346744+07	\N	f
357	49	1	255735.38	https://t.me/bigstage123/5	t	2026-05-19 21:00:23.872331+07	\N	f
358	49	1	255737.60	https://t.me/bigstage123/5	t	2026-05-19 21:00:25.360352+07	\N	f
359	49	9	255737.60	https://t.me/bigstage123/5	t	2026-05-19 21:00:25.8885+07	\N	f
360	49	9	255739.82	https://t.me/bigstage123/5	t	2026-05-19 21:00:27.370473+07	\N	f
361	49	1	255739.82	https://t.me/bigstage123/5	t	2026-05-19 21:00:27.902317+07	\N	f
363	49	9	255742.04	https://t.me/bigstage123/5	t	2026-05-19 21:00:29.918124+07	\N	f
362	49	1	255742.04	https://t.me/bigstage123/5	t	2026-05-19 21:00:29.378191+07	\N	f
364	49	9	255744.26	https://t.me/bigstage123/5	t	2026-05-19 21:00:31.393006+07	\N	f
365	49	1	255744.26	https://t.me/bigstage123/5	t	2026-05-19 21:00:31.926932+07	\N	f
366	49	1	255746.48	https://t.me/bigstage123/5	t	2026-05-19 21:00:33.405466+07	\N	f
367	49	9	255746.48	https://t.me/bigstage123/5	t	2026-05-19 21:00:33.943746+07	\N	f
368	49	9	255748.70	https://t.me/bigstage123/5	t	2026-05-19 21:00:35.420892+07	\N	f
369	49	1	255748.70	https://t.me/bigstage123/5	t	2026-05-19 21:00:35.960975+07	\N	f
370	49	1	255750.92	https://t.me/bigstage123/5	t	2026-05-19 21:00:37.436455+07	\N	f
371	49	9	255750.92	https://t.me/bigstage123/5	t	2026-05-19 21:00:37.979114+07	\N	f
372	49	9	255753.14	https://t.me/bigstage123/5	t	2026-05-19 21:00:39.45297+07	\N	f
373	49	1	255753.14	https://t.me/bigstage123/5	t	2026-05-19 21:00:39.995097+07	\N	f
374	49	1	255755.36	https://t.me/bigstage123/5	t	2026-05-19 21:00:41.461004+07	\N	f
375	49	9	255755.36	https://t.me/bigstage123/5	t	2026-05-19 21:00:42.002448+07	\N	f
376	49	9	255757.58	https://t.me/bigstage123/5	t	2026-05-19 21:00:43.470001+07	\N	f
377	50	24	555.56	https://t.me/bigstage123/6	t	2026-05-20 20:00:35.24051+07	\N	f
378	50	25	566.68	https://t.me/bigstage123/6	t	2026-05-20 20:01:11.39522+07	\N	f
379	50	24	577.79	https://t.me/bigstage123/6	t	2026-05-20 20:01:13.417158+07	\N	f
380	50	25	1111.12	https://t.me/bigstage123/6	t	2026-05-20 20:02:03.354212+07	\N	f
381	50	24	1122.23	https://t.me/bigstage123/6	t	2026-05-20 20:02:05.367681+07	\N	f
382	50	24	1133.34	https://t.me/bigstage123/6	t	2026-05-20 20:04:06.572837+07	\N	f
383	50	25	1144.46	https://t.me/bigstage123/6	t	2026-05-20 20:04:32.069156+07	\N	f
384	50	24	1155.57	https://t.me/bigstage123/6	t	2026-05-20 20:04:34.089854+07	\N	f
385	50	25	122216.67	https://t.me/bigstage123/6	t	2026-05-20 20:06:43.37136+07	\N	f
\.


--
-- Data for Name: lot_chats; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.lot_chats (id, lot_id, sender_id, recipient_id, message, created_at, read_at) FROM stdin;
106	31	23	24	🏆 Вы победили в аукционе «После заката»!\n\nПоздравляем! Ваша ставка $850.00 стала выигрышной.\n\nЧто делать сейчас:\n1. Перейдите в раздел «Профиль» (правый верхний угол)\n2. Найдите блок «Эскроу и платежи»\n3. Нажмите «Оплатить картой» или «Списать с баланса»\n\n⏱ Срок оплаты: 24 ч.\nЕсли не успеете — лот автоматически перейдёт следующему биддеру.\n\nПосле оплаты деньги уйдут в эскроу. Продавец отправит билет, вы получите уведомление и подтвердите получение — только после этого продавец получит деньги.	2026-05-20 21:08:56.890725+07	\N
108	31	23	2	🎉 Ваш лот «После заката» продан\n\nПобедитель: Prodavec_Alex. Сумма выигрыша: $850.00. Покупатель должен оплатить в течение 24 ч. Мы сообщим, как только оплата поступит.	2026-05-20 21:08:56.910005+07	\N
110	30	23	2	Лот «Полуночный оркестр»: новый победитель\n\nПредыдущий победитель не оплатил. Теперь лот за demo_anna по ставке $2360.00.	2026-05-20 21:08:56.934558+07	\N
3	33	9	2	123	2026-05-17 22:39:28.916654+07	2026-05-17 22:39:56.423318+07
2	33	8	2	213	2026-05-17 22:33:00.213657+07	2026-05-17 22:39:57.454728+07
1	30	8	2	.	2026-05-17 22:31:48.089537+07	2026-05-17 22:39:57.993543+07
18	43	23	24	🎉 Ваш лот «Верблюд на реактивной тяге» продан\n\nПобедитель: bidstage_support. Сумма выигрыша: $112.23. Покупатель должен оплатить в течение 5 ч. Мы сообщим, как только оплата поступит.	2026-05-18 21:03:28.92315+07	2026-05-18 21:05:47.532024+07
19	43	23	24	оке	2026-05-18 21:06:58.369622+07	2026-05-18 21:07:06.521489+07
21	31	23	13	❌ Ставка $850.00 отклонена\n\nЛот «После заката»\n\nВ посте по вашей ссылке не найдено упоминание этого лота. Опубликуйте пост, в тексте которого есть ссылка на /lot/31, и сделайте ставку заново.\n\nСтавка не учтена. Деньги не списаны. Сделайте новую ставку, опубликовав пост со ссылкой на лот.	2026-05-18 21:51:46.732424+07	\N
27	32	13	2	как дела?	2026-05-19 19:27:47.151909+07	2026-05-19 19:28:43.97561+07
28	32	2	13	норм всё!	2026-05-19 19:28:51.307058+07	2026-05-19 19:28:59.749373+07
16	35	23	9	Каскад по лоту «Швабра»: пользователь demo_anna не оплатил\n\nЛот перешёл к demo_anna. Если он также не оплатит, возможно лот достанется вам. Ожидаемое время до вашей очереди: до окончания текущего периода оплаты.	2026-05-18 18:35:41.78762+07	2026-05-19 20:45:12.701694+07
17	35	23	9	Лот «Швабра»: новый победитель\n\nПредыдущий победитель не оплатил. Теперь лот за demo_anna по ставке $549.45.	2026-05-18 18:35:41.791957+07	2026-05-19 20:45:12.701694+07
14	35	23	1	⏱️ Срок оплаты по лоту «Швабра» истёк\n\nВы не оплатили свою ставку $4358.98 в отведённое время. Лот передан следующему участнику.	2026-05-18 18:35:41.772635+07	2026-05-19 20:50:10.283836+07
15	35	23	1	🏆 Лот «Швабра» переходит к вам!\n\nПобедитель не оплатил выигрыш. По каскаду лот теперь ваш по ставке $549.45. Оплатите в течение 24 ч, иначе лот перейдёт следующему участнику.	2026-05-18 18:35:41.783194+07	2026-05-19 20:50:10.283836+07
23	35	23	1	⏱️ Срок оплаты по лоту «Швабра» истёк\n\nВы не оплатили свою ставку $549.45 в отведённое время. Лот передан следующему участнику.	2026-05-19 18:58:45.550536+07	2026-05-19 20:50:10.283836+07
4	33	2	8	123	2026-05-17 22:40:02.215668+07	2026-05-19 21:22:15.77139+07
5	33	2	8	123	2026-05-17 22:40:06.04158+07	2026-05-19 21:22:15.77139+07
6	33	2	8	123	2026-05-17 22:40:10.135564+07	2026-05-19 21:22:15.77139+07
22	31	23	24	❌ Ставка $850.00 отклонена\n\nЛот «После заката»\n\nВ посте по вашей ссылке не найдено упоминание этого лота. Опубликуйте пост, в тексте которого есть ссылка на /lot/31, и сделайте ставку заново.\n\nСтавка не учтена. Деньги не списаны. Сделайте новую ставку, опубликовав пост со ссылкой на лот.	2026-05-18 21:53:51.064024+07	2026-05-20 19:59:40.932349+07
25	35	23	9	Каскад по лоту «Швабра»: пользователь demo_anna не оплатил\n\nЛот перешёл к demo_anna. Если он также не оплатит, возможно лот достанется вам. Ожидаемое время до вашей очереди: до окончания текущего периода оплаты.	2026-05-19 18:58:45.565299+07	2026-05-19 20:45:12.701694+07
26	35	23	9	Лот «Швабра»: новый победитель\n\nПредыдущий победитель не оплатил. Теперь лот за demo_anna по ставке $499.45.	2026-05-19 18:58:45.571157+07	2026-05-19 20:45:12.701694+07
24	35	23	1	🏆 Лот «Швабра» переходит к вам!\n\nПобедитель не оплатил вовремя, и по правилам каскада лот теперь ваш.\n\nСумма к оплате: $499.45\n\nЧто делать:\n1. Откройте «Профиль» в правом верхнем углу\n2. В блоке «Эскроу и платежи» нажмите «Оплатить картой» или «Списать с баланса»\n\n⏱ У вас есть 24 ч на оплату. Если не успеете — лот достанется следующему биддеру.\n\nПосле оплаты деньги уйдут в эскроу до подтверждения получения билета.	2026-05-19 18:58:45.561626+07	2026-05-19 20:50:10.283836+07
107	30	23	13	⏱️ Срок оплаты по лоту «Полуночный оркестр» истёк\n\nВы не оплатили свою ставку $2490.00 в отведённое время. Лот передан следующему участнику.	2026-05-20 21:08:56.901768+07	\N
109	30	23	1	🏆 Лот «Полуночный оркестр» переходит к вам!\n\nПобедитель не оплатил вовремя, и по правилам каскада лот теперь ваш.\n\nСумма к оплате: $2360.00\n\nЧто делать:\n1. Откройте «Профиль» в правом верхнем углу\n2. В блоке «Эскроу и платежи» нажмите «Оплатить картой» или «Списать с баланса»\n\n⏱ У вас есть 24 ч на оплату. Если не успеете — лот достанется следующему биддеру.\n\nПосле оплаты деньги уйдут в эскроу до подтверждения получения билета.	2026-05-20 21:08:56.930302+07	\N
30	49	23	1	🏆 Вы победили в аукционе «Калькулятор»!\n\nПоздравляем! Ваша ставка $255755.36 стала выигрышной.\n\nЧто делать сейчас:\n1. Перейдите в раздел «Профиль» (правый верхний угол)\n2. Найдите блок «Эскроу и платежи»\n3. Нажмите «Оплатить картой» или «Списать с баланса»\n\n⏱ Срок оплаты: 5 мин.\nЕсли не успеете — лот автоматически перейдёт следующему биддеру.\n\nПосле оплаты деньги уйдут в эскроу. Продавец отправит билет, вы получите уведомление и подтвердите получение — только после этого продавец получит деньги.	2026-05-19 21:00:43.958012+07	2026-05-19 21:01:23.133105+07
40	30	23	13	🏆 Вы победили в аукционе «Полуночный оркестр»!\n\nПоздравляем! Ваша ставка $2490.00 стала выигрышной.\n\nЧто делать сейчас:\n1. Перейдите в раздел «Профиль» (правый верхний угол)\n2. Найдите блок «Эскроу и платежи»\n3. Нажмите «Оплатить картой» или «Списать с баланса»\n\n⏱ Срок оплаты: 24 ч.\nЕсли не успеете — лот автоматически перейдёт следующему биддеру.\n\nПосле оплаты деньги уйдут в эскроу. Продавец отправит билет, вы получите уведомление и подтвердите получение — только после этого продавец получит деньги.	2026-05-19 21:08:43.997586+07	\N
36	49	23	1	⏱️ Срок оплаты по лоту «Калькулятор» истёк\n\nВы не оплатили свою ставку $255755.36 в отведённое время. Лот передан следующему участнику.	2026-05-19 21:05:43.995021+07	2026-05-19 21:19:32.895031+07
31	49	23	9	🥈 Аукцион «Калькулятор» завершён. Вы заняли 2-е место\n\nПобедитель — пользователь demo_anna, ставка $255755.36. Если вышестоящие участники не оплатят свои выигрыши, лот может перейти к вам. Ожидаемое время до вашей очереди: 5 мин. Мы пришлём уведомление, как только это произойдёт.	2026-05-19 21:00:44.131277+07	2026-05-19 21:20:24.886836+07
35	35	23	9	💸 Покупатель оплатил лот «Швабра»\n\nПокупатель demo_anna оплатил $499.45.\n\nДеньги в эскроу — пока не у вас. Что делать:\n1. Откройте «Продать → Мои аукционы» (правый верхний угол)\n2. Найдите блок «🔒 Эскроу»\n3. Введите код билета и нажмите «Билет отправлен»\n\nПосле того как покупатель подтвердит получение — деньги поступят на ваш баланс.	2026-05-19 21:01:45.110347+07	2026-05-19 21:20:26.362353+07
32	49	23	8	🥈 Аукцион «Калькулятор» завершён. Вы заняли 3-е место\n\nПобедитель — пользователь demo_anna, ставка $255755.36. Если вышестоящие участники не оплатят свои выигрыши, лот может перейти к вам. Ожидаемое время до вашей очереди: 10 мин. Мы пришлём уведомление, как только это произойдёт.	2026-05-19 21:00:44.146913+07	2026-05-19 21:22:12.298613+07
38	49	23	8	Каскад по лоту «Калькулятор»: пользователь demo_anna не оплатил\n\nЛот перешёл к truealex2. Если он также не оплатит, возможно лот достанется вам. Ожидаемое время до вашей очереди: 5 мин.	2026-05-19 21:05:44.101598+07	2026-05-19 21:22:12.298613+07
33	49	23	25	🎉 Ваш лот «Калькулятор» продан\n\nПобедитель: demo_anna. Сумма выигрыша: $255755.36. Покупатель должен оплатить в течение 5 мин. Мы сообщим, как только оплата поступит.	2026-05-19 21:00:44.234094+07	2026-05-20 20:50:45.607562+07
39	49	23	25	Лот «Калькулятор»: новый победитель\n\nПредыдущий победитель не оплатил. Теперь лот за truealex2 по ставке $255757.58.	2026-05-19 21:05:44.106352+07	2026-05-20 20:50:45.607562+07
42	30	23	2	🎉 Ваш лот «Полуночный оркестр» продан\n\nПобедитель: functest_6142. Сумма выигрыша: $2490.00. Покупатель должен оплатить в течение 24 ч. Мы сообщим, как только оплата поступит.	2026-05-19 21:08:44.00857+07	\N
53	45	23	3	🏆 Вы победили в аукционе «Proxy test lot»!\n\nПоздравляем! Ваша ставка $110.00 стала выигрышной.\n\nЧто делать сейчас:\n1. Перейдите в раздел «Профиль» (правый верхний угол)\n2. Найдите блок «Эскроу и платежи»\n3. Нажмите «Оплатить картой» или «Списать с баланса»\n\n⏱ Срок оплаты: 1 ч.\nЕсли не успеете — лот автоматически перейдёт следующему биддеру.\n\nПосле оплаты деньги уйдут в эскроу. Продавец отправит билет, вы получите уведомление и подтвердите получение — только после этого продавец получит деньги.	2026-05-19 21:18:43.982863+07	\N
54	45	23	2	🥈 Аукцион «Proxy test lot» завершён. Вы заняли 2-е место\n\nПобедитель — пользователь demo_carl, ставка $110.00. Если вышестоящие участники не оплатят свои выигрыши, лот может перейти к вам. Ожидаемое время до вашей очереди: 1 ч. Мы пришлём уведомление, как только это произойдёт.	2026-05-19 21:18:43.989938+07	\N
55	45	23	1	🎉 Ваш лот «Proxy test lot» продан\n\nПобедитель: demo_carl. Сумма выигрыша: $110.00. Покупатель должен оплатить в течение 1 ч. Мы сообщим, как только оплата поступит.	2026-05-19 21:18:43.993719+07	2026-05-19 21:19:22.112593+07
45	49	23	1	Каскад по лоту «Калькулятор»: пользователь truealex2 не оплатил\n\nЛот перешёл к truealex2. Если он также не оплатит, возможно лот достанется вам. Ожидаемое время до вашей очереди: до окончания текущего периода оплаты.	2026-05-19 21:11:14.292234+07	2026-05-19 21:19:32.895031+07
41	30	23	1	🥈 Аукцион «Полуночный оркестр» завершён. Вы заняли 2-е место\n\nПобедитель — пользователь functest_6142, ставка $2490.00. Если вышестоящие участники не оплатят свои выигрыши, лот может перейти к вам. Ожидаемое время до вашей очереди: 24 ч. Мы пришлём уведомление, как только это произойдёт.	2026-05-19 21:08:44.004095+07	2026-05-19 21:19:53.408225+07
43	49	23	9	⏱️ Срок оплаты по лоту «Калькулятор» истёк\n\nВы не оплатили свою ставку $255757.58 в отведённое время. Лот передан следующему участнику.	2026-05-19 21:11:14.11071+07	2026-05-19 21:20:24.886836+07
44	49	23	9	🏆 Лот «Калькулятор» переходит к вам!\n\nПобедитель не оплатил вовремя, и по правилам каскада лот теперь ваш.\n\nСумма к оплате: $255755.36\n\nЧто делать:\n1. Откройте «Профиль» в правом верхнем углу\n2. В блоке «Эскроу и платежи» нажмите «Оплатить картой» или «Списать с баланса»\n\n⏱ У вас есть 5 мин на оплату. Если не успеете — лот достанется следующему биддеру.\n\nПосле оплаты деньги уйдут в эскроу до подтверждения получения билета.	2026-05-19 21:11:14.194843+07	2026-05-19 21:20:24.886836+07
46	49	23	8	Каскад по лоту «Калькулятор»: пользователь truealex2 не оплатил\n\nЛот перешёл к truealex2. Если он также не оплатит, возможно лот достанется вам. Ожидаемое время до вашей очереди: 5 мин.	2026-05-19 21:11:14.314927+07	2026-05-19 21:22:12.298613+07
51	49	23	8	Каскад по лоту «Калькулятор»: пользователь truealex2 не оплатил\n\nЛот перешёл к truealex2. Если он также не оплатит, возможно лот достанется вам. Ожидаемое время до вашей очереди: 5 мин.	2026-05-19 21:16:44.39848+07	2026-05-19 21:22:12.298613+07
47	49	23	25	Лот «Калькулятор»: новый победитель\n\nПредыдущий победитель не оплатил. Теперь лот за truealex2 по ставке $255755.36.	2026-05-19 21:11:14.526638+07	2026-05-20 20:50:45.607562+07
52	49	23	25	Лот «Калькулятор»: новый победитель\n\nПредыдущий победитель не оплатил. Теперь лот за truealex2 по ставке $255753.14.	2026-05-19 21:16:44.404147+07	2026-05-20 20:50:45.607562+07
50	49	23	1	Каскад по лоту «Калькулятор»: пользователь truealex2 не оплатил\n\nЛот перешёл к truealex2. Если он также не оплатит, возможно лот достанется вам. Ожидаемое время до вашей очереди: до окончания текущего периода оплаты.	2026-05-19 21:16:44.197297+07	2026-05-19 21:19:32.895031+07
34	35	23	1	✅ Оплата принята по лоту «Швабра»\n\nСумма $499.45 отправлена в эскроу. Ожидайте, пока продавец отправит билет, затем подтвердите получение в профиле.	2026-05-19 21:01:45.092416+07	2026-05-19 21:19:57.750171+07
37	49	23	9	🏆 Лот «Калькулятор» переходит к вам!\n\nПобедитель не оплатил вовремя, и по правилам каскада лот теперь ваш.\n\nСумма к оплате: $255757.58\n\nЧто делать:\n1. Откройте «Профиль» в правом верхнем углу\n2. В блоке «Эскроу и платежи» нажмите «Оплатить картой» или «Списать с баланса»\n\n⏱ У вас есть 5 мин на оплату. Если не успеете — лот достанется следующему биддеру.\n\nПосле оплаты деньги уйдут в эскроу до подтверждения получения билета.	2026-05-19 21:05:44.087714+07	2026-05-19 21:20:24.886836+07
48	49	23	9	⏱️ Срок оплаты по лоту «Калькулятор» истёк\n\nВы не оплатили свою ставку $255755.36 в отведённое время. Лот передан следующему участнику.	2026-05-19 21:16:43.973219+07	2026-05-19 21:20:24.886836+07
49	49	23	9	🏆 Лот «Калькулятор» переходит к вам!\n\nПобедитель не оплатил вовремя, и по правилам каскада лот теперь ваш.\n\nСумма к оплате: $255753.14\n\nЧто делать:\n1. Откройте «Профиль» в правом верхнем углу\n2. В блоке «Эскроу и платежи» нажмите «Оплатить картой» или «Списать с баланса»\n\n⏱ У вас есть 5 мин на оплату. Если не успеете — лот достанется следующему биддеру.\n\nПосле оплаты деньги уйдут в эскроу до подтверждения получения билета.	2026-05-19 21:16:44.074198+07	2026-05-19 21:20:24.886836+07
56	49	23	9	✅ Оплата принята по лоту «Калькулятор»\n\nСумма $255753.14 отправлена в эскроу. Ожидайте, пока продавец отправит билет, затем подтвердите получение в профиле.	2026-05-19 21:21:31.99163+07	\N
58	46	23	3	🏆 Вы победили в аукционе «Proxy test lot»!\n\nПоздравляем! Ваша ставка $110.00 стала выигрышной.\n\nЧто делать сейчас:\n1. Перейдите в раздел «Профиль» (правый верхний угол)\n2. Найдите блок «Эскроу и платежи»\n3. Нажмите «Оплатить картой» или «Списать с баланса»\n\n⏱ Срок оплаты: 1 ч.\nЕсли не успеете — лот автоматически перейдёт следующему биддеру.\n\nПосле оплаты деньги уйдут в эскроу. Продавец отправит билет, вы получите уведомление и подтвердите получение — только после этого продавец получит деньги.	2026-05-19 21:24:13.983122+07	\N
60	46	23	1	🎉 Ваш лот «Proxy test lot» продан\n\nПобедитель: demo_carl. Сумма выигрыша: $110.00. Покупатель должен оплатить в течение 1 ч. Мы сообщим, как только оплата поступит.	2026-05-19 21:24:13.993685+07	\N
61	47	23	3	🏆 Вы победили в аукционе «Proxy test lot»!\n\nПоздравляем! Ваша ставка $110.00 стала выигрышной.\n\nЧто делать сейчас:\n1. Перейдите в раздел «Профиль» (правый верхний угол)\n2. Найдите блок «Эскроу и платежи»\n3. Нажмите «Оплатить картой» или «Списать с баланса»\n\n⏱ Срок оплаты: 1 ч.\nЕсли не успеете — лот автоматически перейдёт следующему биддеру.\n\nПосле оплаты деньги уйдут в эскроу. Продавец отправит билет, вы получите уведомление и подтвердите получение — только после этого продавец получит деньги.	2026-05-19 21:25:44.008082+07	\N
62	47	23	2	🥈 Аукцион «Proxy test lot» завершён. Вы заняли 2-е место\n\nПобедитель — пользователь demo_carl, ставка $110.00. Если вышестоящие участники не оплатят свои выигрыши, лот может перейти к вам. Ожидаемое время до вашей очереди: 1 ч. Мы пришлём уведомление, как только это произойдёт.	2026-05-19 21:25:44.04171+07	\N
63	47	23	1	🎉 Ваш лот «Proxy test lot» продан\n\nПобедитель: demo_carl. Сумма выигрыша: $110.00. Покупатель должен оплатить в течение 1 ч. Мы сообщим, как только оплата поступит.	2026-05-19 21:25:44.047541+07	\N
64	49	23	9	🎫 Продавец отправил билет по лоту «Калькулятор»\n\nБилет: лови ссылку на него!\n\nПроверьте билет, подтвердите получение в профиле — после этого деньги поступят продавцу.	2026-05-19 21:35:36.058637+07	\N
57	49	23	25	💸 Покупатель оплатил лот «Калькулятор»\n\nПокупатель truealex2 оплатил $255753.14.\n\nДеньги в эскроу — пока не у вас. Что делать:\n1. Откройте «Продать → Мои аукционы» (правый верхний угол)\n2. Найдите блок «🔒 Эскроу»\n3. Введите код билета и нажмите «Билет отправлен»\n\nПосле того как покупатель подтвердит получение — деньги поступят на ваш баланс.	2026-05-19 21:21:32.007979+07	2026-05-20 20:50:45.607562+07
65	48	23	3	🏆 Вы победили в аукционе «Proxy test lot»!\n\nПоздравляем! Ваша ставка $210.00 стала выигрышной.\n\nЧто делать сейчас:\n1. Перейдите в раздел «Профиль» (правый верхний угол)\n2. Найдите блок «Эскроу и платежи»\n3. Нажмите «Оплатить картой» или «Списать с баланса»\n\n⏱ Срок оплаты: 1 ч.\nЕсли не успеете — лот автоматически перейдёт следующему биддеру.\n\nПосле оплаты деньги уйдут в эскроу. Продавец отправит билет, вы получите уведомление и подтвердите получение — только после этого продавец получит деньги.	2026-05-19 21:43:14.017361+07	\N
67	48	23	1	🎉 Ваш лот «Proxy test lot» продан\n\nПобедитель: demo_carl. Сумма выигрыша: $210.00. Покупатель должен оплатить в течение 1 ч. Мы сообщим, как только оплата поступит.	2026-05-19 21:43:14.044345+07	\N
68	45	23	3	⏱️ Срок оплаты по лоту «Proxy test lot» истёк\n\nВы не оплатили свою ставку $110.00 в отведённое время. Лот передан следующему участнику.	2026-05-20 11:15:51.49413+07	\N
69	45	23	2	🏆 Лот «Proxy test lot» переходит к вам!\n\nПобедитель не оплатил вовремя, и по правилам каскада лот теперь ваш.\n\nСумма к оплате: $100.00\n\nЧто делать:\n1. Откройте «Профиль» в правом верхнем углу\n2. В блоке «Эскроу и платежи» нажмите «Оплатить картой» или «Списать с баланса»\n\n⏱ У вас есть 1 ч на оплату. Если не успеете — лот достанется следующему биддеру.\n\nПосле оплаты деньги уйдут в эскроу до подтверждения получения билета.	2026-05-20 11:15:51.534186+07	\N
70	45	23	1	Лот «Proxy test lot»: новый победитель\n\nПредыдущий победитель не оплатил. Теперь лот за demo_boris по ставке $100.00.	2026-05-20 11:15:51.539106+07	\N
71	46	23	3	⏱️ Срок оплаты по лоту «Proxy test lot» истёк\n\nВы не оплатили свою ставку $110.00 в отведённое время. Лот передан следующему участнику.	2026-05-20 11:15:51.546768+07	\N
73	46	23	1	Лот «Proxy test lot»: новый победитель\n\nПредыдущий победитель не оплатил. Теперь лот за demo_boris по ставке $100.00.	2026-05-20 11:15:51.559339+07	\N
74	47	23	3	⏱️ Срок оплаты по лоту «Proxy test lot» истёк\n\nВы не оплатили свою ставку $110.00 в отведённое время. Лот передан следующему участнику.	2026-05-20 11:15:51.566322+07	\N
75	47	23	2	🏆 Лот «Proxy test lot» переходит к вам!\n\nПобедитель не оплатил вовремя, и по правилам каскада лот теперь ваш.\n\nСумма к оплате: $100.00\n\nЧто делать:\n1. Откройте «Профиль» в правом верхнем углу\n2. В блоке «Эскроу и платежи» нажмите «Оплатить картой» или «Списать с баланса»\n\n⏱ У вас есть 1 ч на оплату. Если не успеете — лот достанется следующему биддеру.\n\nПосле оплаты деньги уйдут в эскроу до подтверждения получения билета.	2026-05-20 11:15:51.573107+07	\N
76	47	23	1	Лот «Proxy test lot»: новый победитель\n\nПредыдущий победитель не оплатил. Теперь лот за demo_boris по ставке $100.00.	2026-05-20 11:15:51.576194+07	\N
77	48	23	3	⏱️ Срок оплаты по лоту «Proxy test lot» истёк\n\nВы не оплатили свою ставку $210.00 в отведённое время. Лот передан следующему участнику.	2026-05-20 11:15:51.582547+07	\N
79	48	23	1	Лот «Proxy test lot»: новый победитель\n\nПредыдущий победитель не оплатил. Теперь лот за demo_boris по ставке $200.00.	2026-05-20 11:15:51.591767+07	\N
80	45	23	2	⏱️ Срок оплаты по лоту «Proxy test lot» истёк\n\nВы не оплатили свою ставку $100.00 в отведённое время. Лот передан следующему участнику.	2026-05-20 18:45:56.950756+07	\N
81	45	23	1	Лот «Proxy test lot» снят с аукциона\n\nНикто из участников не оплатил выигрыш. Лот будет перевыставлен через 24 часа.	2026-05-20 18:45:57.004114+07	\N
72	46	23	2	🏆 Лот «Proxy test lot» переходит к вам!\n\nПобедитель не оплатил вовремя, и по правилам каскада лот теперь ваш.\n\nСумма к оплате: $100.00\n\nЧто делать:\n1. Откройте «Профиль» в правом верхнем углу\n2. В блоке «Эскроу и платежи» нажмите «Оплатить картой» или «Списать с баланса»\n\n⏱ У вас есть 1 ч на оплату. Если не успеете — лот достанется следующему биддеру.\n\nПосле оплаты деньги уйдут в эскроу до подтверждения получения билета.	2026-05-20 11:15:51.555518+07	2026-05-20 19:54:08.774282+07
82	45	23	3	Аукцион «Proxy test lot» окончательно закрыт\n\nНикто из участников каскада не оплатил выигрыш. Лот будет перевыставлен через 24 часа — следите за уведомлениями.	2026-05-20 18:45:57.009106+07	\N
84	46	23	1	Лот «Proxy test lot» снят с аукциона\n\nНикто из участников не оплатил выигрыш. Лот будет перевыставлен через 24 часа.	2026-05-20 18:45:57.026342+07	\N
85	46	23	3	Аукцион «Proxy test lot» окончательно закрыт\n\nНикто из участников каскада не оплатил выигрыш. Лот будет перевыставлен через 24 часа — следите за уведомлениями.	2026-05-20 18:45:57.031946+07	\N
86	47	23	2	⏱️ Срок оплаты по лоту «Proxy test lot» истёк\n\nВы не оплатили свою ставку $100.00 в отведённое время. Лот передан следующему участнику.	2026-05-20 18:45:57.04053+07	\N
87	47	23	1	Лот «Proxy test lot» снят с аукциона\n\nНикто из участников не оплатил выигрыш. Лот будет перевыставлен через 24 часа.	2026-05-20 18:45:57.047578+07	\N
88	47	23	3	Аукцион «Proxy test lot» окончательно закрыт\n\nНикто из участников каскада не оплатил выигрыш. Лот будет перевыставлен через 24 часа — следите за уведомлениями.	2026-05-20 18:45:57.051818+07	\N
90	48	23	3	🏆 Лот «Proxy test lot» переходит к вам!\n\nПобедитель не оплатил вовремя, и по правилам каскада лот теперь ваш.\n\nСумма к оплате: $190.00\n\nЧто делать:\n1. Откройте «Профиль» в правом верхнем углу\n2. В блоке «Эскроу и платежи» нажмите «Оплатить картой» или «Списать с баланса»\n\n⏱ У вас есть 1 ч на оплату. Если не успеете — лот достанется следующему биддеру.\n\nПосле оплаты деньги уйдут в эскроу до подтверждения получения билета.	2026-05-20 18:45:57.070499+07	\N
91	48	23	1	Лот «Proxy test lot»: новый победитель\n\nПредыдущий победитель не оплатил. Теперь лот за demo_carl по ставке $190.00.	2026-05-20 18:45:57.075206+07	\N
92	48	23	3	⏱️ Срок оплаты по лоту «Proxy test lot» истёк\n\nВы не оплатили свою ставку $190.00 в отведённое время. Лот передан следующему участнику.	2026-05-20 19:46:26.884446+07	\N
94	48	23	1	Лот «Proxy test lot»: новый победитель\n\nПредыдущий победитель не оплатил. Теперь лот за demo_boris по ставке $180.00.	2026-05-20 19:46:26.898296+07	\N
66	48	23	2	🥈 Аукцион «Proxy test lot» завершён. Вы заняли 2-е место\n\nПобедитель — пользователь demo_carl, ставка $210.00. Если вышестоящие участники не оплатят свои выигрыши, лот может перейти к вам. Ожидаемое время до вашей очереди: 1 ч. Мы пришлём уведомление, как только это произойдёт.	2026-05-19 21:43:14.039552+07	2026-05-20 19:54:04.880781+07
78	48	23	2	🏆 Лот «Proxy test lot» переходит к вам!\n\nПобедитель не оплатил вовремя, и по правилам каскада лот теперь ваш.\n\nСумма к оплате: $200.00\n\nЧто делать:\n1. Откройте «Профиль» в правом верхнем углу\n2. В блоке «Эскроу и платежи» нажмите «Оплатить картой» или «Списать с баланса»\n\n⏱ У вас есть 1 ч на оплату. Если не успеете — лот достанется следующему биддеру.\n\nПосле оплаты деньги уйдут в эскроу до подтверждения получения билета.	2026-05-20 11:15:51.588823+07	2026-05-20 19:54:04.880781+07
89	48	23	2	⏱️ Срок оплаты по лоту «Proxy test lot» истёк\n\nВы не оплатили свою ставку $200.00 в отведённое время. Лот передан следующему участнику.	2026-05-20 18:45:57.060226+07	2026-05-20 19:54:04.880781+07
93	48	23	2	🏆 Лот «Proxy test lot» переходит к вам!\n\nПобедитель не оплатил вовремя, и по правилам каскада лот теперь ваш.\n\nСумма к оплате: $180.00\n\nЧто делать:\n1. Откройте «Профиль» в правом верхнем углу\n2. В блоке «Эскроу и платежи» нажмите «Оплатить картой» или «Списать с баланса»\n\n⏱ У вас есть 1 ч на оплату. Если не успеете — лот достанется следующему биддеру.\n\nПосле оплаты деньги уйдут в эскроу до подтверждения получения билета.	2026-05-20 19:46:26.894357+07	2026-05-20 19:54:04.880781+07
59	46	23	2	🥈 Аукцион «Proxy test lot» завершён. Вы заняли 2-е место\n\nПобедитель — пользователь demo_carl, ставка $110.00. Если вышестоящие участники не оплатят свои выигрыши, лот может перейти к вам. Ожидаемое время до вашей очереди: 1 ч. Мы пришлём уведомление, как только это произойдёт.	2026-05-19 21:24:13.989071+07	2026-05-20 19:54:08.774282+07
83	46	23	2	⏱️ Срок оплаты по лоту «Proxy test lot» истёк\n\nВы не оплатили свою ставку $100.00 в отведённое время. Лот передан следующему участнику.	2026-05-20 18:45:57.019388+07	2026-05-20 19:54:08.774282+07
96	50	23	24	🥈 Аукцион «Щелкунчик» завершён. Вы заняли 2-е место\n\nПобедитель — пользователь Pro777, ставка $122216.67. Если вышестоящие участники не оплатят свои выигрыши, лот может перейти к вам. Ожидаемое время до вашей очереди: 10 мин. Мы пришлём уведомление, как только это произойдёт.	2026-05-20 20:09:56.937612+07	\N
97	50	23	8	🎉 Ваш лот «Щелкунчик» продан\n\nПобедитель: Pro777. Сумма выигрыша: $122216.67. Покупатель должен оплатить в течение 10 мин. Мы сообщим, как только оплата поступит.	2026-05-20 20:09:56.943624+07	\N
99	50	23	8	💸 Покупатель оплатил лот «Щелкунчик»\n\nПокупатель Pro777 оплатил $122216.67.\n\nДеньги в эскроу — пока не у вас. Что делать:\n1. Откройте «Продать → Мои аукционы» (правый верхний угол)\n2. Найдите блок «🔒 Эскроу»\n3. Введите код билета и нажмите «Билет отправлен»\n\nПосле того как покупатель подтвердит получение — деньги поступят на ваш баланс.	2026-05-20 20:12:23.734351+07	\N
101	50	23	8	💰 Сделка по лоту «Щелкунчик» закрыта\n\nПокупатель Pro777 подтвердил получение. На ваш баланс зачислено $109995.00 (за вычетом комиссии 10%).	2026-05-20 20:13:14.540479+07	\N
103	48	23	2	⏱️ Срок оплаты по лоту «Proxy test lot» истёк\n\nВы не оплатили свою ставку $180.00 в отведённое время. Лот передан следующему участнику.	2026-05-20 20:46:26.927717+07	\N
104	48	23	3	🏆 Лот «Proxy test lot» переходит к вам!\n\nПобедитель не оплатил вовремя, и по правилам каскада лот теперь ваш.\n\nСумма к оплате: $170.00\n\nЧто делать:\n1. Откройте «Профиль» в правом верхнем углу\n2. В блоке «Эскроу и платежи» нажмите «Оплатить картой» или «Списать с баланса»\n\n⏱ У вас есть 1 ч на оплату. Если не успеете — лот достанется следующему биддеру.\n\nПосле оплаты деньги уйдут в эскроу до подтверждения получения билета.	2026-05-20 20:46:26.953751+07	\N
105	48	23	1	Лот «Proxy test lot»: новый победитель\n\nПредыдущий победитель не оплатил. Теперь лот за demo_carl по ставке $170.00.	2026-05-20 20:46:26.958423+07	\N
95	50	23	25	🏆 Вы победили в аукционе «Щелкунчик»!\n\nПоздравляем! Ваша ставка $122216.67 стала выигрышной.\n\nЧто делать сейчас:\n1. Перейдите в раздел «Профиль» (правый верхний угол)\n2. Найдите блок «Эскроу и платежи»\n3. Нажмите «Оплатить картой» или «Списать с баланса»\n\n⏱ Срок оплаты: 10 мин.\nЕсли не успеете — лот автоматически перейдёт следующему биддеру.\n\nПосле оплаты деньги уйдут в эскроу. Продавец отправит билет, вы получите уведомление и подтвердите получение — только после этого продавец получит деньги.	2026-05-20 20:09:56.88188+07	2026-05-20 20:50:43.521653+07
98	50	23	25	✅ Оплата принята по лоту «Щелкунчик»\n\nСумма $122216.67 отправлена в эскроу. Ожидайте, пока продавец отправит билет, затем подтвердите получение в профиле.	2026-05-20 20:12:23.504927+07	2026-05-20 20:50:43.521653+07
100	50	23	25	🎫 Продавец отправил билет по лоту «Щелкунчик»\n\nБилет: https://chat.deepseek.com/a/chat/s/eed18367-4712-4c23-bace-5a1fc856c982\n\nПроверьте билет, подтвердите получение в профиле — после этого деньги поступят продавцу.	2026-05-20 20:13:03.22769+07	2026-05-20 20:50:43.521653+07
102	50	23	25	✅ Получение подтверждено по лоту «Щелкунчик»\n\nСпасибо! Сделка успешно закрыта. Не забудьте оставить отзыв о продавце в его профиле.	2026-05-20 20:13:14.545629+07	2026-05-20 20:50:43.521653+07
\.


--
-- Data for Name: lot_events; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.lot_events (id, lot_id, event_type, actor_username, actor_user_id, amount_usd, payload, created_at) FROM stdin;
1	31	new_bid	demo_carl	3	845.33	\N	2026-05-17 13:23:24.116296+07
2	31	bid_cancelled	demo_carl	3	845.33	{"reason": "invalid_share_url"}	2026-05-17 13:24:24.117738+07
3	35	new_bid	truealex2	9	99.45	\N	2026-05-17 16:51:38.571576+07
4	35	share_verified	truealex2	9	99.45	\N	2026-05-17 16:51:40.571337+07
5	35	new_bid	truealex2	9	349.45	\N	2026-05-17 17:35:58.978704+07
6	35	share_verified	truealex2	9	349.45	\N	2026-05-17 17:36:00.993714+07
7	35	share_verified	demo_anna	1	399.45	\N	2026-05-17 17:41:40.588022+07
8	35	share_verified	demo_anna	1	449.45	\N	2026-05-17 17:41:43.538064+07
9	35	share_verified	demo_anna	1	499.45	\N	2026-05-17 17:41:48.072558+07
10	35	share_verified	demo_anna	1	549.45	\N	2026-05-17 17:42:57.183307+07
11	35	new_bid	demo_anna	1	4358.98	\N	2026-05-17 17:44:47.241763+07
12	35	share_verified	demo_anna	1	4358.98	\N	2026-05-17 17:44:49.240977+07
13	35	auction_ended	demo_anna	1	4358.98	\N	2026-05-17 17:49:45.944028+07
14	33	new_bid	truealex2	9	660.00	\N	2026-05-17 20:11:54.157879+07
15	33	share_verified	truealex2	9	660.00	\N	2026-05-17 20:11:56.152526+07
16	33	auction_ended	truealex2	9	660.00	\N	2026-05-18 10:32:51.997629+07
17	43	share_verified	bidstage_support	23	111.11	\N	2026-05-18 20:58:04.098043+07
18	43	share_verified	bidstage_support	23	111.67	\N	2026-05-18 20:58:17.012646+07
19	43	share_verified	bidstage_support	23	112.23	\N	2026-05-18 21:02:17.190086+07
20	43	auction_ended	bidstage_support	23	112.23	\N	2026-05-18 21:03:28.905589+07
21	30	new_bid	bidstage_support	23	2360.00	\N	2026-05-18 21:05:36.565738+07
22	30	share_verified	bidstage_support	23	2360.00	\N	2026-05-18 21:05:38.56639+07
23	31	new_bid	bidstage_support	23	810.00	\N	2026-05-18 21:30:32.251493+07
24	31	share_verified	bidstage_support	23	810.00	\N	2026-05-18 21:30:34.252331+07
36	31	bid_cancelled	functest_6142	13	850.00	{"reason": "link_missing"}	2026-05-18 21:51:46.723425+07
37	31	new_bid	Prodavec_Alex	24	850.00	\N	2026-05-18 21:52:49.616249+07
38	31	bid_cancelled	Prodavec_Alex	24	850.00	{"reason": "link_missing"}	2026-05-18 21:53:51.056523+07
39	31	new_bid	Prodavec_Alex	24	850.00	\N	2026-05-18 21:54:45.834356+07
40	31	share_verified	Prodavec_Alex	24	850.00	\N	2026-05-18 21:55:47.162861+07
41	30	share_verified	demo_anna	1	2360.00	\N	2026-05-19 19:23:00.886107+07
42	30	new_bid	functest_6142	13	2490.00	\N	2026-05-19 19:26:17.002652+07
43	30	share_verified	functest_6142	13	2490.00	\N	2026-05-19 19:26:19.010123+07
44	45	share_verified	demo_boris	2	100.00	\N	2026-05-19 20:18:31.85174+07
45	45	share_verified	demo_carl	3	110.00	\N	2026-05-19 20:18:34.879432+07
46	46	share_verified	demo_boris	2	100.00	\N	2026-05-19 20:23:57.606805+07
47	46	share_verified	demo_carl	3	110.00	\N	2026-05-19 20:24:00.610373+07
48	47	share_verified	demo_boris	2	100.00	\N	2026-05-19 20:25:29.356701+07
49	47	share_verified	demo_carl	3	110.00	\N	2026-05-19 20:25:32.368119+07
50	48	share_verified	demo_boris	2	100.00	\N	2026-05-19 20:43:02.749592+07
51	48	share_verified	demo_carl	3	110.00	\N	2026-05-19 20:43:05.776765+07
52	48	new_bid	demo_boris	2	120.00	\N	2026-05-19 20:43:05.782553+07
53	48	share_verified	demo_boris	2	120.00	\N	2026-05-19 20:43:07.799766+07
54	48	new_bid	demo_carl	3	130.00	\N	2026-05-19 20:43:07.803851+07
55	48	share_verified	demo_carl	3	130.00	\N	2026-05-19 20:43:09.823391+07
56	48	new_bid	demo_boris	2	140.00	\N	2026-05-19 20:43:09.828906+07
57	48	share_verified	demo_boris	2	140.00	\N	2026-05-19 20:43:11.833315+07
58	48	new_bid	demo_carl	3	150.00	\N	2026-05-19 20:43:11.838532+07
59	48	share_verified	demo_carl	3	150.00	\N	2026-05-19 20:43:13.85252+07
60	48	new_bid	demo_boris	2	160.00	\N	2026-05-19 20:43:13.856853+07
61	48	share_verified	demo_boris	2	160.00	\N	2026-05-19 20:43:15.875781+07
62	48	new_bid	demo_carl	3	170.00	\N	2026-05-19 20:43:15.880624+07
63	48	share_verified	demo_carl	3	170.00	\N	2026-05-19 20:43:17.897884+07
64	48	new_bid	demo_boris	2	180.00	\N	2026-05-19 20:43:17.903069+07
65	48	share_verified	demo_boris	2	180.00	\N	2026-05-19 20:43:19.910388+07
66	48	new_bid	demo_carl	3	190.00	\N	2026-05-19 20:43:19.914807+07
67	48	share_verified	demo_carl	3	190.00	\N	2026-05-19 20:43:21.926518+07
68	48	new_bid	demo_boris	2	200.00	\N	2026-05-19 20:43:21.931845+07
69	48	share_verified	demo_boris	2	200.00	\N	2026-05-19 20:43:23.938653+07
70	48	new_bid	demo_carl	3	210.00	\N	2026-05-19 20:43:23.943507+07
71	48	share_verified	demo_carl	3	210.00	\N	2026-05-19 20:43:25.956405+07
72	49	share_verified	demo_anna	1	222.22	\N	2026-05-19 20:50:45.717458+07
73	49	new_bid	truealex2	9	224.44	\N	2026-05-19 20:51:10.907153+07
74	49	share_verified	truealex2	9	224.44	\N	2026-05-19 20:51:12.911817+07
75	49	new_bid	demo_anna	1	226.66	\N	2026-05-19 20:51:12.917155+07
76	49	share_verified	demo_anna	1	226.66	\N	2026-05-19 20:51:14.928595+07
77	49	new_bid	truealex2	9	228.88	\N	2026-05-19 20:52:10.751641+07
78	49	share_verified	truealex2	9	228.88	\N	2026-05-19 20:52:12.756764+07
79	49	new_bid	demo_anna	1	231.10	\N	2026-05-19 20:52:12.762485+07
80	49	share_verified	demo_anna	1	231.10	\N	2026-05-19 20:52:14.76649+07
81	49	share_verified	truealex2	9	233.32	\N	2026-05-19 20:53:16.295031+07
82	49	new_bid	demo_anna	1	235.54	\N	2026-05-19 20:53:16.300143+07
83	49	share_verified	demo_anna	1	235.54	\N	2026-05-19 20:53:18.304503+07
84	49	new_bid	truealex2	9	237.76	\N	2026-05-19 20:53:18.309443+07
85	49	share_verified	truealex2	9	237.76	\N	2026-05-19 20:53:20.314194+07
86	49	new_bid	demo_anna	1	239.98	\N	2026-05-19 20:53:20.31895+07
87	49	share_verified	demo_anna	1	239.98	\N	2026-05-19 20:53:22.328944+07
88	49	new_bid	truealex2	9	242.20	\N	2026-05-19 20:53:22.334332+07
89	49	share_verified	truealex2	9	242.20	\N	2026-05-19 20:53:24.345011+07
90	49	new_bid	demo_anna	1	244.42	\N	2026-05-19 20:53:24.35347+07
91	49	share_verified	demo_anna	1	244.42	\N	2026-05-19 20:53:26.362602+07
92	49	new_bid	truealex2	9	246.64	\N	2026-05-19 20:53:26.367939+07
93	49	share_verified	truealex2	9	246.64	\N	2026-05-19 20:53:28.386755+07
94	49	new_bid	demo_anna	1	248.86	\N	2026-05-19 20:53:28.392072+07
95	49	share_verified	demo_anna	1	248.86	\N	2026-05-19 20:53:30.404067+07
96	49	new_bid	truealex2	9	251.08	\N	2026-05-19 20:53:30.409141+07
97	49	share_verified	truealex2	9	251.08	\N	2026-05-19 20:53:32.420658+07
98	49	new_bid	demo_anna	1	253.30	\N	2026-05-19 20:53:32.425103+07
99	49	share_verified	demo_anna	1	253.30	\N	2026-05-19 20:53:34.42972+07
100	49	new_bid	truealex2	9	255.52	\N	2026-05-19 20:53:34.434832+07
101	49	share_verified	truealex2	9	255.52	\N	2026-05-19 20:53:36.446222+07
102	49	new_bid	demo_anna	1	257.74	\N	2026-05-19 20:53:36.452306+07
103	49	share_verified	demo_anna	1	257.74	\N	2026-05-19 20:53:38.462924+07
104	49	new_bid	truealex2	9	259.96	\N	2026-05-19 20:53:38.468653+07
105	49	share_verified	truealex2	9	259.96	\N	2026-05-19 20:53:40.471853+07
106	49	new_bid	demo_anna	1	262.18	\N	2026-05-19 20:53:40.477091+07
107	49	share_verified	demo_anna	1	262.18	\N	2026-05-19 20:53:42.488242+07
108	49	new_bid	truealex2	9	264.40	\N	2026-05-19 20:53:42.49331+07
109	49	share_verified	truealex2	9	264.40	\N	2026-05-19 20:53:44.505945+07
110	49	new_bid	demo_anna	1	266.62	\N	2026-05-19 20:53:44.511765+07
111	49	share_verified	demo_anna	1	266.62	\N	2026-05-19 20:53:46.514289+07
112	49	new_bid	truealex2	9	268.84	\N	2026-05-19 20:53:46.518734+07
113	49	share_verified	truealex2	9	268.84	\N	2026-05-19 20:53:48.530684+07
114	49	new_bid	demo_anna	1	271.06	\N	2026-05-19 20:53:48.535465+07
115	49	share_verified	demo_anna	1	271.06	\N	2026-05-19 20:53:50.546369+07
116	49	new_bid	truealex2	9	273.28	\N	2026-05-19 20:53:50.553197+07
117	49	share_verified	truealex2	9	273.28	\N	2026-05-19 20:53:52.564062+07
118	49	new_bid	demo_anna	1	275.50	\N	2026-05-19 20:53:52.569343+07
119	49	share_verified	demo_anna	1	275.50	\N	2026-05-19 20:53:54.58846+07
120	49	new_bid	truealex2	9	277.72	\N	2026-05-19 20:53:54.594755+07
121	49	share_verified	truealex2	9	277.72	\N	2026-05-19 20:53:56.60567+07
122	49	new_bid	demo_anna	1	279.94	\N	2026-05-19 20:53:56.611+07
123	49	share_verified	demo_anna	1	279.94	\N	2026-05-19 20:53:58.622195+07
124	49	new_bid	truealex2	9	282.16	\N	2026-05-19 20:53:58.626405+07
125	49	share_verified	truealex2	9	282.16	\N	2026-05-19 20:54:00.630616+07
126	49	new_bid	demo_anna	1	284.38	\N	2026-05-19 20:54:00.635147+07
127	49	share_verified	demo_anna	1	284.38	\N	2026-05-19 20:54:02.639697+07
128	49	new_bid	truealex2	9	286.60	\N	2026-05-19 20:54:02.645278+07
129	49	share_verified	truealex2	9	286.60	\N	2026-05-19 20:54:04.656361+07
130	49	new_bid	demo_anna	1	288.82	\N	2026-05-19 20:54:04.660701+07
131	49	share_verified	demo_anna	1	288.82	\N	2026-05-19 20:54:06.665239+07
132	49	new_bid	truealex2	9	291.04	\N	2026-05-19 20:54:06.669403+07
133	49	share_verified	truealex2	9	291.04	\N	2026-05-19 20:54:08.674011+07
134	49	new_bid	demo_anna	1	293.26	\N	2026-05-19 20:54:08.680089+07
135	49	share_verified	demo_anna	1	293.26	\N	2026-05-19 20:54:10.690649+07
136	49	new_bid	truealex2	9	295.48	\N	2026-05-19 20:54:10.71133+07
137	49	share_verified	truealex2	9	295.48	\N	2026-05-19 20:54:12.724167+07
138	49	new_bid	demo_anna	1	297.70	\N	2026-05-19 20:54:12.728791+07
139	49	share_verified	demo_anna	1	297.70	\N	2026-05-19 20:54:14.73983+07
140	49	new_bid	truealex2	9	299.92	\N	2026-05-19 20:54:14.745241+07
141	49	share_verified	truealex2	9	299.92	\N	2026-05-19 20:54:16.761456+07
142	49	new_bid	demo_anna	1	302.14	\N	2026-05-19 20:54:16.766203+07
143	49	share_verified	demo_anna	1	302.14	\N	2026-05-19 20:54:18.774671+07
144	49	new_bid	truealex2	9	304.36	\N	2026-05-19 20:54:18.779705+07
145	49	share_verified	truealex2	9	304.36	\N	2026-05-19 20:54:20.790772+07
146	49	new_bid	demo_anna	1	306.58	\N	2026-05-19 20:54:20.79632+07
147	49	share_verified	demo_anna	1	306.58	\N	2026-05-19 20:54:22.802061+07
148	49	new_bid	truealex2	9	308.80	\N	2026-05-19 20:54:22.807083+07
149	49	share_verified	truealex2	9	308.80	\N	2026-05-19 20:54:24.80854+07
150	49	new_bid	demo_anna	1	311.02	\N	2026-05-19 20:54:24.812609+07
151	49	share_verified	demo_anna	1	311.02	\N	2026-05-19 20:54:26.816556+07
152	49	new_bid	truealex2	9	313.24	\N	2026-05-19 20:54:26.821514+07
153	49	share_verified	truealex2	9	313.24	\N	2026-05-19 20:54:28.834327+07
154	49	new_bid	demo_anna	1	315.46	\N	2026-05-19 20:54:28.838932+07
155	49	share_verified	demo_anna	1	315.46	\N	2026-05-19 20:54:30.849769+07
156	49	new_bid	truealex2	9	317.68	\N	2026-05-19 20:54:30.856064+07
157	49	share_verified	truealex2	9	317.68	\N	2026-05-19 20:54:32.866615+07
158	49	new_bid	demo_anna	1	319.90	\N	2026-05-19 20:54:32.872043+07
159	49	share_verified	demo_anna	1	319.90	\N	2026-05-19 20:54:34.885184+07
160	49	new_bid	truealex2	9	322.12	\N	2026-05-19 20:54:34.890802+07
161	49	share_verified	truealex2	9	322.12	\N	2026-05-19 20:54:36.900766+07
162	49	new_bid	demo_anna	1	324.34	\N	2026-05-19 20:54:36.906107+07
163	49	share_verified	demo_anna	1	324.34	\N	2026-05-19 20:54:38.912458+07
164	49	new_bid	truealex2	9	326.56	\N	2026-05-19 20:54:38.918831+07
165	49	share_verified	truealex2	9	326.56	\N	2026-05-19 20:54:40.925789+07
166	49	new_bid	demo_anna	1	328.78	\N	2026-05-19 20:54:40.931492+07
167	49	share_verified	demo_anna	1	328.78	\N	2026-05-19 20:54:42.941698+07
168	49	new_bid	truealex2	9	331.00	\N	2026-05-19 20:54:42.946247+07
169	49	share_verified	truealex2	9	331.00	\N	2026-05-19 20:54:44.950804+07
170	49	new_bid	demo_anna	1	333.22	\N	2026-05-19 20:54:44.957174+07
171	49	share_verified	demo_anna	1	333.22	\N	2026-05-19 20:54:46.961272+07
172	49	new_bid	truealex2	9	335.44	\N	2026-05-19 20:54:46.96657+07
173	49	share_verified	truealex2	9	335.44	\N	2026-05-19 20:54:48.975301+07
174	49	new_bid	demo_anna	1	337.66	\N	2026-05-19 20:54:48.981026+07
175	49	share_verified	demo_anna	1	337.66	\N	2026-05-19 20:54:50.993029+07
176	49	new_bid	truealex2	9	339.88	\N	2026-05-19 20:54:50.997562+07
177	49	share_verified	truealex2	9	339.88	\N	2026-05-19 20:54:53.009634+07
178	49	new_bid	demo_anna	1	342.10	\N	2026-05-19 20:54:53.014956+07
179	49	share_verified	demo_anna	1	342.10	\N	2026-05-19 20:54:55.025944+07
180	49	new_bid	truealex2	9	344.32	\N	2026-05-19 20:54:55.030165+07
181	49	share_verified	truealex2	9	344.32	\N	2026-05-19 20:54:57.034894+07
182	49	new_bid	demo_anna	1	346.54	\N	2026-05-19 20:54:57.040225+07
183	49	share_verified	demo_anna	1	346.54	\N	2026-05-19 20:54:59.045821+07
184	49	new_bid	truealex2	9	348.76	\N	2026-05-19 20:54:59.051124+07
185	49	share_verified	truealex2	9	348.76	\N	2026-05-19 20:55:01.0596+07
186	49	new_bid	demo_anna	1	350.98	\N	2026-05-19 20:55:01.064643+07
187	49	share_verified	demo_anna	1	350.98	\N	2026-05-19 20:55:03.075997+07
188	49	new_bid	truealex2	9	353.20	\N	2026-05-19 20:55:03.080646+07
189	49	share_verified	truealex2	9	353.20	\N	2026-05-19 20:55:05.085308+07
190	49	new_bid	demo_anna	1	355.42	\N	2026-05-19 20:55:05.09061+07
191	49	share_verified	demo_anna	1	355.42	\N	2026-05-19 20:55:07.101915+07
192	49	new_bid	truealex2	9	357.64	\N	2026-05-19 20:55:07.106928+07
193	49	share_verified	truealex2	9	357.64	\N	2026-05-19 20:55:09.11901+07
194	49	new_bid	demo_anna	1	359.86	\N	2026-05-19 20:55:09.124872+07
195	49	share_verified	demo_anna	1	359.86	\N	2026-05-19 20:55:11.13592+07
196	49	new_bid	truealex2	9	362.08	\N	2026-05-19 20:55:11.143473+07
197	49	share_verified	truealex2	9	362.08	\N	2026-05-19 20:55:13.160127+07
198	49	new_bid	demo_anna	1	364.30	\N	2026-05-19 20:55:13.165346+07
199	49	share_verified	demo_anna	1	364.30	\N	2026-05-19 20:55:15.172862+07
200	49	new_bid	truealex2	9	366.52	\N	2026-05-19 20:55:15.179427+07
201	49	share_verified	truealex2	9	366.52	\N	2026-05-19 20:55:17.193741+07
202	49	new_bid	demo_anna	1	368.74	\N	2026-05-19 20:55:17.199615+07
203	49	share_verified	demo_anna	1	368.74	\N	2026-05-19 20:55:19.210622+07
204	49	new_bid	truealex2	9	370.96	\N	2026-05-19 20:55:19.215891+07
205	49	share_verified	truealex2	9	370.96	\N	2026-05-19 20:55:21.2235+07
206	49	new_bid	demo_anna	1	373.18	\N	2026-05-19 20:55:21.228127+07
207	49	share_verified	demo_anna	1	373.18	\N	2026-05-19 20:55:23.239812+07
208	49	new_bid	truealex2	9	375.40	\N	2026-05-19 20:55:23.246749+07
209	49	share_verified	truealex2	9	375.40	\N	2026-05-19 20:55:25.269125+07
210	49	new_bid	demo_anna	1	377.62	\N	2026-05-19 20:55:25.27366+07
211	49	share_verified	demo_anna	1	377.62	\N	2026-05-19 20:55:27.277579+07
212	49	new_bid	truealex2	9	379.84	\N	2026-05-19 20:55:27.28203+07
213	49	share_verified	truealex2	9	379.84	\N	2026-05-19 20:55:29.295145+07
214	49	new_bid	demo_anna	1	382.06	\N	2026-05-19 20:55:29.300412+07
215	49	share_verified	demo_anna	1	382.06	\N	2026-05-19 20:55:31.31161+07
216	49	new_bid	truealex2	9	384.28	\N	2026-05-19 20:55:31.315985+07
217	49	share_verified	truealex2	9	384.28	\N	2026-05-19 20:55:33.319899+07
218	49	new_bid	demo_anna	1	386.50	\N	2026-05-19 20:55:33.324277+07
219	49	share_verified	demo_anna	1	386.50	\N	2026-05-19 20:55:35.336658+07
220	49	new_bid	truealex2	9	388.72	\N	2026-05-19 20:55:35.343152+07
221	49	share_verified	truealex2	9	388.72	\N	2026-05-19 20:55:37.353626+07
222	49	new_bid	demo_anna	1	390.94	\N	2026-05-19 20:55:37.358403+07
223	49	share_verified	demo_anna	1	390.94	\N	2026-05-19 20:55:39.370474+07
224	49	new_bid	truealex2	9	393.16	\N	2026-05-19 20:55:39.37483+07
225	49	share_verified	truealex2	9	393.16	\N	2026-05-19 20:55:41.37975+07
226	49	new_bid	demo_anna	1	395.38	\N	2026-05-19 20:55:41.384806+07
227	49	share_verified	demo_anna	1	395.38	\N	2026-05-19 20:55:43.40369+07
228	49	new_bid	truealex2	9	397.60	\N	2026-05-19 20:55:43.409804+07
229	49	share_verified	truealex2	9	397.60	\N	2026-05-19 20:55:45.420634+07
230	49	new_bid	demo_anna	1	399.82	\N	2026-05-19 20:55:45.425687+07
231	49	share_verified	demo_anna	1	399.82	\N	2026-05-19 20:55:47.42982+07
232	49	new_bid	truealex2	9	402.04	\N	2026-05-19 20:55:47.434741+07
233	49	share_verified	truealex2	9	402.04	\N	2026-05-19 20:55:49.445896+07
234	49	new_bid	demo_anna	1	404.26	\N	2026-05-19 20:55:49.450151+07
235	49	share_verified	demo_anna	1	404.26	\N	2026-05-19 20:55:51.455431+07
236	49	new_bid	truealex2	9	406.48	\N	2026-05-19 20:55:51.460937+07
237	49	share_verified	truealex2	9	406.48	\N	2026-05-19 20:55:53.463304+07
238	49	new_bid	demo_anna	1	408.70	\N	2026-05-19 20:55:53.467388+07
239	49	share_verified	demo_anna	1	408.70	\N	2026-05-19 20:55:55.471922+07
240	49	new_bid	truealex2	9	410.92	\N	2026-05-19 20:55:55.477888+07
241	49	share_verified	truealex2	9	410.92	\N	2026-05-19 20:55:57.484685+07
242	49	new_bid	demo_anna	1	413.14	\N	2026-05-19 20:55:57.489649+07
243	49	share_verified	demo_anna	1	413.14	\N	2026-05-19 20:55:59.497477+07
244	49	new_bid	truealex2	9	415.36	\N	2026-05-19 20:55:59.502849+07
245	49	share_verified	truealex2	9	415.36	\N	2026-05-19 20:56:01.513383+07
246	49	new_bid	demo_anna	1	417.58	\N	2026-05-19 20:56:01.517681+07
247	49	share_verified	demo_anna	1	417.58	\N	2026-05-19 20:56:03.521686+07
248	49	new_bid	truealex2	9	419.80	\N	2026-05-19 20:56:03.526925+07
249	49	share_verified	truealex2	9	419.80	\N	2026-05-19 20:56:05.538714+07
250	49	new_bid	demo_anna	1	422.02	\N	2026-05-19 20:56:05.543012+07
251	49	share_verified	demo_anna	1	422.02	\N	2026-05-19 20:56:07.547517+07
252	49	new_bid	truealex2	9	424.24	\N	2026-05-19 20:56:07.553142+07
253	49	share_verified	truealex2	9	424.24	\N	2026-05-19 20:56:09.571849+07
254	49	new_bid	demo_anna	1	426.46	\N	2026-05-19 20:56:09.5765+07
255	49	share_verified	demo_anna	1	426.46	\N	2026-05-19 20:56:11.581512+07
256	49	new_bid	truealex2	9	428.68	\N	2026-05-19 20:56:11.609231+07
257	49	share_verified	truealex2	9	428.68	\N	2026-05-19 20:56:13.622282+07
258	49	new_bid	demo_anna	1	430.90	\N	2026-05-19 20:56:13.627593+07
259	49	share_verified	demo_anna	1	430.90	\N	2026-05-19 20:56:15.647317+07
260	49	new_bid	truealex2	9	433.12	\N	2026-05-19 20:56:15.65191+07
261	49	share_verified	truealex2	9	433.12	\N	2026-05-19 20:56:17.664204+07
262	49	new_bid	demo_anna	1	435.34	\N	2026-05-19 20:56:17.669187+07
263	49	share_verified	demo_anna	1	435.34	\N	2026-05-19 20:56:19.681119+07
264	49	new_bid	truealex2	9	437.56	\N	2026-05-19 20:56:19.686396+07
265	49	share_verified	truealex2	9	437.56	\N	2026-05-19 20:56:21.697655+07
266	49	new_bid	demo_anna	1	439.78	\N	2026-05-19 20:56:21.702372+07
267	49	share_verified	demo_anna	1	439.78	\N	2026-05-19 20:56:23.714755+07
268	49	new_bid	truealex2	9	442.00	\N	2026-05-19 20:56:23.719832+07
269	49	share_verified	truealex2	9	442.00	\N	2026-05-19 20:56:25.731417+07
270	49	new_bid	demo_anna	1	444.22	\N	2026-05-19 20:56:25.736367+07
271	49	share_verified	demo_anna	1	444.22	\N	2026-05-19 20:56:27.748154+07
272	49	new_bid	truealex2	9	446.44	\N	2026-05-19 20:56:27.753273+07
273	49	share_verified	truealex2	9	446.44	\N	2026-05-19 20:56:29.765033+07
274	49	new_bid	demo_anna	1	448.66	\N	2026-05-19 20:56:29.77026+07
275	49	share_verified	demo_anna	1	448.66	\N	2026-05-19 20:56:31.784337+07
276	49	new_bid	truealex2	9	450.88	\N	2026-05-19 20:56:31.791766+07
277	49	share_verified	truealex2	9	450.88	\N	2026-05-19 20:56:33.806895+07
278	49	new_bid	demo_anna	1	453.10	\N	2026-05-19 20:56:33.812309+07
279	49	share_verified	demo_anna	1	453.10	\N	2026-05-19 20:56:35.823689+07
280	49	new_bid	truealex2	9	455.32	\N	2026-05-19 20:56:35.829371+07
281	49	share_verified	truealex2	9	455.32	\N	2026-05-19 20:56:37.841728+07
282	49	new_bid	demo_anna	1	457.54	\N	2026-05-19 20:56:37.846287+07
283	49	share_verified	demo_anna	1	457.54	\N	2026-05-19 20:56:39.850895+07
284	49	new_bid	truealex2	9	459.76	\N	2026-05-19 20:56:39.855502+07
285	49	share_verified	truealex2	9	459.76	\N	2026-05-19 20:56:41.86629+07
286	49	new_bid	demo_anna	1	461.98	\N	2026-05-19 20:56:41.871959+07
287	49	share_verified	demo_anna	1	461.98	\N	2026-05-19 20:56:43.875296+07
288	49	new_bid	truealex2	9	464.20	\N	2026-05-19 20:56:44.037765+07
289	49	share_verified	truealex2	9	464.20	\N	2026-05-19 20:56:46.049665+07
290	49	new_bid	demo_anna	1	466.42	\N	2026-05-19 20:56:46.063933+07
291	49	share_verified	demo_anna	1	466.42	\N	2026-05-19 20:56:48.074396+07
292	49	new_bid	truealex2	9	468.64	\N	2026-05-19 20:56:48.07991+07
293	49	share_verified	truealex2	9	468.64	\N	2026-05-19 20:56:50.09104+07
294	49	new_bid	demo_anna	1	470.86	\N	2026-05-19 20:56:50.097163+07
295	49	share_verified	demo_anna	1	470.86	\N	2026-05-19 20:56:52.105657+07
296	49	new_bid	truealex2	9	473.08	\N	2026-05-19 20:56:52.110524+07
297	49	share_verified	truealex2	9	473.08	\N	2026-05-19 20:56:54.116655+07
298	49	new_bid	demo_anna	1	475.30	\N	2026-05-19 20:56:54.121322+07
299	49	share_verified	demo_anna	1	475.30	\N	2026-05-19 20:56:56.133579+07
300	49	new_bid	truealex2	9	477.52	\N	2026-05-19 20:56:56.138954+07
301	49	share_verified	truealex2	9	477.52	\N	2026-05-19 20:56:58.187075+07
302	49	new_bid	demo_anna	1	479.74	\N	2026-05-19 20:56:58.259726+07
303	49	share_verified	demo_anna	1	479.74	\N	2026-05-19 20:57:00.267701+07
304	49	new_bid	truealex2	9	481.96	\N	2026-05-19 20:57:00.272086+07
305	49	share_verified	truealex2	9	481.96	\N	2026-05-19 20:57:02.283715+07
306	49	new_bid	demo_anna	1	484.18	\N	2026-05-19 20:57:02.289025+07
307	49	share_verified	demo_anna	1	484.18	\N	2026-05-19 20:57:04.300568+07
308	49	new_bid	truealex2	9	486.40	\N	2026-05-19 20:57:04.30556+07
309	49	share_verified	truealex2	9	486.40	\N	2026-05-19 20:57:06.310047+07
310	49	new_bid	demo_anna	1	488.62	\N	2026-05-19 20:57:06.314904+07
311	49	share_verified	demo_anna	1	488.62	\N	2026-05-19 20:57:08.326059+07
312	49	new_bid	truealex2	9	490.84	\N	2026-05-19 20:57:08.330761+07
313	49	share_verified	truealex2	9	490.84	\N	2026-05-19 20:57:10.387381+07
314	49	new_bid	demo_anna	1	493.06	\N	2026-05-19 20:57:10.457772+07
315	49	share_verified	demo_anna	1	493.06	\N	2026-05-19 20:57:12.46764+07
316	49	new_bid	truealex2	9	495.28	\N	2026-05-19 20:57:12.474298+07
317	49	share_verified	truealex2	9	495.28	\N	2026-05-19 20:57:14.485219+07
318	49	new_bid	demo_anna	1	497.50	\N	2026-05-19 20:57:14.490272+07
319	49	share_verified	demo_anna	1	497.50	\N	2026-05-19 20:57:16.502094+07
320	49	new_bid	truealex2	9	499.72	\N	2026-05-19 20:57:16.509205+07
321	49	share_verified	truealex2	9	499.72	\N	2026-05-19 20:57:18.518958+07
322	49	new_bid	demo_anna	1	501.94	\N	2026-05-19 20:57:18.524741+07
323	49	share_verified	demo_anna	1	501.94	\N	2026-05-19 20:57:20.529101+07
324	49	new_bid	truealex2	9	504.16	\N	2026-05-19 20:57:20.53451+07
325	49	share_verified	truealex2	9	504.16	\N	2026-05-19 20:57:22.543894+07
326	49	new_bid	demo_anna	1	506.38	\N	2026-05-19 20:57:22.549237+07
327	49	share_verified	demo_anna	1	506.38	\N	2026-05-19 20:57:24.560349+07
328	49	new_bid	truealex2	9	508.60	\N	2026-05-19 20:57:24.566849+07
329	49	share_verified	truealex2	9	508.60	\N	2026-05-19 20:57:26.585064+07
330	49	new_bid	demo_anna	1	510.82	\N	2026-05-19 20:57:26.590743+07
331	49	share_verified	demo_anna	1	510.82	\N	2026-05-19 20:57:28.610543+07
332	49	new_bid	truealex2	9	513.04	\N	2026-05-19 20:57:28.615529+07
333	49	share_verified	truealex2	9	513.04	\N	2026-05-19 20:57:30.623363+07
334	49	new_bid	demo_anna	1	515.26	\N	2026-05-19 20:57:30.62808+07
335	49	share_verified	demo_anna	1	515.26	\N	2026-05-19 20:57:32.635604+07
336	49	new_bid	truealex2	9	517.48	\N	2026-05-19 20:57:32.640056+07
337	49	share_verified	truealex2	9	517.48	\N	2026-05-19 20:57:34.644074+07
338	49	new_bid	demo_anna	1	519.70	\N	2026-05-19 20:57:34.649633+07
339	49	share_verified	demo_anna	1	519.70	\N	2026-05-19 20:57:36.657763+07
340	49	new_bid	truealex2	9	521.92	\N	2026-05-19 20:57:36.662898+07
341	49	share_verified	truealex2	9	521.92	\N	2026-05-19 20:57:38.669491+07
342	49	new_bid	demo_anna	1	524.14	\N	2026-05-19 20:57:38.674564+07
343	49	new_bid	truealex	8	255555.56	\N	2026-05-19 20:57:40.014732+07
344	49	timer_extended	\N	\N	\N	{"new_end_time": "2026-05-19T21:00:39.997349+07:00", "extension_seconds": 180}	2026-05-19 20:57:40.014732+07
345	49	share_verified	demo_anna	1	524.14	\N	2026-05-19 20:57:40.686323+07
346	49	new_bid	truealex2	9	526.36	\N	2026-05-19 20:57:40.690773+07
347	49	share_verified	truealex	8	255555.56	\N	2026-05-19 20:57:42.022849+07
348	49	new_bid	truealex2	9	255557.78	\N	2026-05-19 20:57:42.028327+07
349	49	share_verified	truealex2	9	526.36	\N	2026-05-19 20:57:42.697724+07
350	49	new_bid	demo_anna	1	255557.78	\N	2026-05-19 20:57:42.703294+07
351	49	share_verified	truealex2	9	255557.78	\N	2026-05-19 20:57:44.036443+07
352	49	new_bid	demo_anna	1	255560.00	\N	2026-05-19 20:57:44.041323+07
353	49	share_verified	demo_anna	1	255557.78	\N	2026-05-19 20:57:44.707659+07
354	49	new_bid	truealex2	9	255560.00	\N	2026-05-19 20:57:44.713904+07
355	49	share_verified	demo_anna	1	255560.00	\N	2026-05-19 20:57:46.044909+07
356	49	new_bid	truealex2	9	255562.22	\N	2026-05-19 20:57:46.050548+07
357	49	share_verified	truealex2	9	255560.00	\N	2026-05-19 20:57:46.719991+07
358	49	new_bid	demo_anna	1	255562.22	\N	2026-05-19 20:57:46.724594+07
359	49	share_verified	truealex2	9	255562.22	\N	2026-05-19 20:57:48.057286+07
360	49	new_bid	demo_anna	1	255564.44	\N	2026-05-19 20:57:48.062236+07
361	49	share_verified	demo_anna	1	255562.22	\N	2026-05-19 20:57:48.728844+07
362	49	new_bid	truealex2	9	255564.44	\N	2026-05-19 20:57:48.734186+07
363	49	share_verified	demo_anna	1	255564.44	\N	2026-05-19 20:57:50.070814+07
364	49	new_bid	truealex2	9	255566.66	\N	2026-05-19 20:57:50.07658+07
365	49	share_verified	truealex2	9	255564.44	\N	2026-05-19 20:57:50.745446+07
366	49	new_bid	demo_anna	1	255566.66	\N	2026-05-19 20:57:50.74992+07
367	49	share_verified	truealex2	9	255566.66	\N	2026-05-19 20:57:52.09547+07
368	49	new_bid	demo_anna	1	255568.88	\N	2026-05-19 20:57:52.101047+07
369	49	share_verified	demo_anna	1	255566.66	\N	2026-05-19 20:57:52.7555+07
370	49	new_bid	truealex2	9	255568.88	\N	2026-05-19 20:57:52.761134+07
371	49	share_verified	demo_anna	1	255568.88	\N	2026-05-19 20:57:54.112807+07
372	49	new_bid	truealex2	9	255571.10	\N	2026-05-19 20:57:54.118014+07
373	49	share_verified	truealex2	9	255568.88	\N	2026-05-19 20:57:54.77895+07
374	49	new_bid	demo_anna	1	255571.10	\N	2026-05-19 20:57:54.785753+07
375	49	share_verified	truealex2	9	255571.10	\N	2026-05-19 20:57:56.125479+07
376	49	new_bid	demo_anna	1	255573.32	\N	2026-05-19 20:57:56.129996+07
377	49	share_verified	demo_anna	1	255571.10	\N	2026-05-19 20:57:56.792925+07
378	49	new_bid	truealex2	9	255573.32	\N	2026-05-19 20:57:56.797512+07
379	49	share_verified	demo_anna	1	255573.32	\N	2026-05-19 20:57:58.135459+07
380	49	new_bid	truealex2	9	255575.54	\N	2026-05-19 20:57:58.141561+07
381	49	share_verified	truealex2	9	255573.32	\N	2026-05-19 20:57:58.804644+07
382	49	new_bid	demo_anna	1	255575.54	\N	2026-05-19 20:57:58.810125+07
383	49	share_verified	truealex2	9	255575.54	\N	2026-05-19 20:58:00.145948+07
384	49	new_bid	demo_anna	1	255577.76	\N	2026-05-19 20:58:00.151906+07
385	49	share_verified	demo_anna	1	255575.54	\N	2026-05-19 20:58:00.820631+07
386	49	new_bid	truealex2	9	255577.76	\N	2026-05-19 20:58:00.825704+07
387	49	share_verified	demo_anna	1	255577.76	\N	2026-05-19 20:58:02.162818+07
388	49	new_bid	truealex2	9	255579.98	\N	2026-05-19 20:58:02.168256+07
389	49	share_verified	truealex2	9	255577.76	\N	2026-05-19 20:58:02.837992+07
390	49	new_bid	demo_anna	1	255579.98	\N	2026-05-19 20:58:02.842809+07
391	49	share_verified	truealex2	9	255579.98	\N	2026-05-19 20:58:04.179792+07
392	49	new_bid	demo_anna	1	255582.20	\N	2026-05-19 20:58:04.186132+07
393	49	share_verified	demo_anna	1	255579.98	\N	2026-05-19 20:58:04.847302+07
394	49	new_bid	truealex2	9	255582.20	\N	2026-05-19 20:58:04.852946+07
395	49	share_verified	demo_anna	1	255582.20	\N	2026-05-19 20:58:06.196198+07
396	49	new_bid	truealex2	9	255584.42	\N	2026-05-19 20:58:06.200714+07
397	49	share_verified	truealex2	9	255582.20	\N	2026-05-19 20:58:06.863745+07
398	49	new_bid	demo_anna	1	255584.42	\N	2026-05-19 20:58:06.868133+07
399	49	share_verified	truealex2	9	255584.42	\N	2026-05-19 20:58:08.205756+07
400	49	new_bid	demo_anna	1	255586.64	\N	2026-05-19 20:58:08.209852+07
401	49	share_verified	demo_anna	1	255584.42	\N	2026-05-19 20:58:08.879892+07
402	49	new_bid	truealex2	9	255586.64	\N	2026-05-19 20:58:08.886141+07
403	49	share_verified	demo_anna	1	255586.64	\N	2026-05-19 20:58:10.221557+07
404	49	new_bid	truealex2	9	255588.86	\N	2026-05-19 20:58:10.22693+07
405	49	share_verified	truealex2	9	255586.64	\N	2026-05-19 20:58:10.891562+07
406	49	new_bid	demo_anna	1	255588.86	\N	2026-05-19 20:58:10.899967+07
407	49	share_verified	truealex2	9	255588.86	\N	2026-05-19 20:58:12.234318+07
408	49	new_bid	demo_anna	1	255591.08	\N	2026-05-19 20:58:12.240325+07
409	49	share_verified	demo_anna	1	255588.86	\N	2026-05-19 20:58:12.904881+07
410	49	new_bid	truealex2	9	255591.08	\N	2026-05-19 20:58:12.909489+07
411	49	share_verified	demo_anna	1	255591.08	\N	2026-05-19 20:58:14.255762+07
412	49	new_bid	truealex2	9	255593.30	\N	2026-05-19 20:58:14.260571+07
413	49	share_verified	truealex2	9	255591.08	\N	2026-05-19 20:58:14.921526+07
414	49	new_bid	demo_anna	1	255593.30	\N	2026-05-19 20:58:14.926165+07
415	49	share_verified	truealex2	9	255593.30	\N	2026-05-19 20:58:16.272045+07
416	49	new_bid	demo_anna	1	255595.52	\N	2026-05-19 20:58:16.276972+07
417	49	share_verified	demo_anna	1	255593.30	\N	2026-05-19 20:58:16.939082+07
418	49	new_bid	truealex2	9	255595.52	\N	2026-05-19 20:58:16.943263+07
419	49	share_verified	demo_anna	1	255595.52	\N	2026-05-19 20:58:18.28453+07
420	49	new_bid	truealex2	9	255597.74	\N	2026-05-19 20:58:18.289151+07
421	49	share_verified	truealex2	9	255595.52	\N	2026-05-19 20:58:18.96248+07
422	49	new_bid	demo_anna	1	255597.74	\N	2026-05-19 20:58:18.967899+07
423	49	share_verified	truealex2	9	255597.74	\N	2026-05-19 20:58:20.292733+07
424	49	new_bid	demo_anna	1	255599.96	\N	2026-05-19 20:58:20.299488+07
425	49	share_verified	demo_anna	1	255597.74	\N	2026-05-19 20:58:20.972894+07
426	49	new_bid	truealex2	9	255599.96	\N	2026-05-19 20:58:20.977974+07
427	49	share_verified	demo_anna	1	255599.96	\N	2026-05-19 20:58:22.306212+07
428	49	new_bid	truealex2	9	255602.18	\N	2026-05-19 20:58:22.310819+07
429	49	share_verified	truealex2	9	255599.96	\N	2026-05-19 20:58:22.989842+07
430	49	new_bid	demo_anna	1	255602.18	\N	2026-05-19 20:58:22.994575+07
431	49	share_verified	truealex2	9	255602.18	\N	2026-05-19 20:58:24.317501+07
432	49	new_bid	demo_anna	1	255604.40	\N	2026-05-19 20:58:24.322444+07
433	49	share_verified	demo_anna	1	255602.18	\N	2026-05-19 20:58:25.005817+07
434	49	new_bid	truealex2	9	255604.40	\N	2026-05-19 20:58:25.012411+07
435	49	share_verified	demo_anna	1	255604.40	\N	2026-05-19 20:58:26.330512+07
436	49	new_bid	truealex2	9	255606.62	\N	2026-05-19 20:58:26.335339+07
437	49	share_verified	truealex2	9	255604.40	\N	2026-05-19 20:58:27.017131+07
438	49	new_bid	demo_anna	1	255606.62	\N	2026-05-19 20:58:27.023657+07
439	49	share_verified	truealex2	9	255606.62	\N	2026-05-19 20:58:28.355612+07
440	49	new_bid	demo_anna	1	255608.84	\N	2026-05-19 20:58:28.360023+07
441	49	share_verified	demo_anna	1	255606.62	\N	2026-05-19 20:58:29.031673+07
442	49	new_bid	truealex2	9	255608.84	\N	2026-05-19 20:58:29.035815+07
443	49	share_verified	demo_anna	1	255608.84	\N	2026-05-19 20:58:30.366963+07
444	49	new_bid	truealex2	9	255611.06	\N	2026-05-19 20:58:30.371693+07
445	49	share_verified	truealex2	9	255608.84	\N	2026-05-19 20:58:31.041986+07
446	49	new_bid	demo_anna	1	255611.06	\N	2026-05-19 20:58:31.046024+07
447	49	share_verified	truealex2	9	255611.06	\N	2026-05-19 20:58:32.377007+07
448	49	new_bid	demo_anna	1	255613.28	\N	2026-05-19 20:58:32.382519+07
449	49	share_verified	demo_anna	1	255611.06	\N	2026-05-19 20:58:33.051021+07
450	49	new_bid	truealex2	9	255613.28	\N	2026-05-19 20:58:33.056427+07
451	49	share_verified	demo_anna	1	255613.28	\N	2026-05-19 20:58:34.396601+07
452	49	new_bid	truealex2	9	255615.50	\N	2026-05-19 20:58:34.401791+07
453	49	share_verified	truealex2	9	255613.28	\N	2026-05-19 20:58:35.065263+07
454	49	new_bid	demo_anna	1	255615.50	\N	2026-05-19 20:58:35.069993+07
455	49	share_verified	truealex2	9	255615.50	\N	2026-05-19 20:58:36.414576+07
456	49	new_bid	demo_anna	1	255617.72	\N	2026-05-19 20:58:36.41944+07
457	49	share_verified	demo_anna	1	255615.50	\N	2026-05-19 20:58:37.082125+07
458	49	new_bid	truealex2	9	255617.72	\N	2026-05-19 20:58:37.086359+07
459	49	share_verified	demo_anna	1	255617.72	\N	2026-05-19 20:58:38.4287+07
460	49	new_bid	truealex2	9	255619.94	\N	2026-05-19 20:58:38.434283+07
461	49	share_verified	truealex2	9	255617.72	\N	2026-05-19 20:58:39.100082+07
462	49	new_bid	demo_anna	1	255619.94	\N	2026-05-19 20:58:39.104728+07
463	49	share_verified	truealex2	9	255619.94	\N	2026-05-19 20:58:40.440296+07
464	49	new_bid	demo_anna	1	255622.16	\N	2026-05-19 20:58:40.445955+07
465	49	share_verified	demo_anna	1	255619.94	\N	2026-05-19 20:58:41.115525+07
466	49	new_bid	truealex2	9	255622.16	\N	2026-05-19 20:58:41.120893+07
467	49	share_verified	demo_anna	1	255622.16	\N	2026-05-19 20:58:42.449002+07
468	49	new_bid	truealex2	9	255624.38	\N	2026-05-19 20:58:42.453365+07
469	49	share_verified	truealex2	9	255622.16	\N	2026-05-19 20:58:43.132845+07
470	49	new_bid	demo_anna	1	255624.38	\N	2026-05-19 20:58:43.139787+07
471	49	share_verified	truealex2	9	255624.38	\N	2026-05-19 20:58:44.47346+07
472	49	new_bid	demo_anna	1	255626.60	\N	2026-05-19 20:58:44.478715+07
473	49	share_verified	demo_anna	1	255624.38	\N	2026-05-19 20:58:45.14912+07
474	49	new_bid	truealex2	9	255626.60	\N	2026-05-19 20:58:45.154175+07
475	49	share_verified	demo_anna	1	255626.60	\N	2026-05-19 20:58:46.490949+07
476	49	new_bid	truealex2	9	255628.82	\N	2026-05-19 20:58:46.495014+07
477	49	share_verified	truealex2	9	255626.60	\N	2026-05-19 20:58:47.165245+07
478	49	new_bid	demo_anna	1	255628.82	\N	2026-05-19 20:58:47.170844+07
479	49	share_verified	truealex2	9	255628.82	\N	2026-05-19 20:58:48.502624+07
480	49	new_bid	demo_anna	1	255631.04	\N	2026-05-19 20:58:48.507205+07
481	49	share_verified	demo_anna	1	255628.82	\N	2026-05-19 20:58:49.178439+07
482	49	new_bid	truealex2	9	255631.04	\N	2026-05-19 20:58:49.185976+07
483	49	share_verified	demo_anna	1	255631.04	\N	2026-05-19 20:58:50.516414+07
484	49	new_bid	truealex2	9	255633.26	\N	2026-05-19 20:58:50.521288+07
485	49	share_verified	truealex2	9	255631.04	\N	2026-05-19 20:58:51.202067+07
486	49	new_bid	demo_anna	1	255633.26	\N	2026-05-19 20:58:51.206517+07
487	49	share_verified	truealex2	9	255633.26	\N	2026-05-19 20:58:52.540708+07
488	49	new_bid	demo_anna	1	255635.48	\N	2026-05-19 20:58:52.545211+07
489	49	share_verified	demo_anna	1	255633.26	\N	2026-05-19 20:58:53.214374+07
490	49	new_bid	truealex2	9	255635.48	\N	2026-05-19 20:58:53.218723+07
491	49	share_verified	demo_anna	1	255635.48	\N	2026-05-19 20:58:54.557876+07
492	49	new_bid	truealex2	9	255637.70	\N	2026-05-19 20:58:54.562519+07
493	49	share_verified	truealex2	9	255635.48	\N	2026-05-19 20:58:55.225092+07
494	49	new_bid	demo_anna	1	255637.70	\N	2026-05-19 20:58:55.230114+07
495	49	share_verified	truealex2	9	255637.70	\N	2026-05-19 20:58:56.571918+07
496	49	new_bid	demo_anna	1	255639.92	\N	2026-05-19 20:58:56.577808+07
497	49	share_verified	demo_anna	1	255637.70	\N	2026-05-19 20:58:57.24268+07
498	49	new_bid	truealex2	9	255639.92	\N	2026-05-19 20:58:57.247855+07
499	49	share_verified	demo_anna	1	255639.92	\N	2026-05-19 20:58:58.583757+07
500	49	new_bid	truealex2	9	255642.14	\N	2026-05-19 20:58:58.589014+07
501	49	share_verified	truealex2	9	255639.92	\N	2026-05-19 20:58:59.258275+07
502	49	new_bid	demo_anna	1	255642.14	\N	2026-05-19 20:58:59.263786+07
503	49	share_verified	truealex2	9	255642.14	\N	2026-05-19 20:59:00.60686+07
504	49	new_bid	demo_anna	1	255644.36	\N	2026-05-19 20:59:00.614715+07
505	49	share_verified	demo_anna	1	255642.14	\N	2026-05-19 20:59:01.270428+07
506	49	new_bid	truealex2	9	255644.36	\N	2026-05-19 20:59:01.278085+07
507	49	share_verified	demo_anna	1	255644.36	\N	2026-05-19 20:59:02.624551+07
508	49	new_bid	truealex2	9	255646.58	\N	2026-05-19 20:59:02.62958+07
509	49	share_verified	truealex2	9	255644.36	\N	2026-05-19 20:59:03.283539+07
510	49	new_bid	demo_anna	1	255646.58	\N	2026-05-19 20:59:03.288673+07
511	49	share_verified	truealex2	9	255646.58	\N	2026-05-19 20:59:04.641347+07
512	49	new_bid	demo_anna	1	255648.80	\N	2026-05-19 20:59:04.646497+07
513	49	share_verified	demo_anna	1	255646.58	\N	2026-05-19 20:59:05.300124+07
514	49	new_bid	truealex2	9	255648.80	\N	2026-05-19 20:59:05.304976+07
515	49	share_verified	demo_anna	1	255648.80	\N	2026-05-19 20:59:06.65096+07
516	49	new_bid	truealex2	9	255651.02	\N	2026-05-19 20:59:06.655679+07
517	49	share_verified	truealex2	9	255648.80	\N	2026-05-19 20:59:07.317176+07
518	49	new_bid	demo_anna	1	255651.02	\N	2026-05-19 20:59:07.322279+07
519	49	share_verified	truealex2	9	255651.02	\N	2026-05-19 20:59:08.658694+07
520	49	new_bid	demo_anna	1	255653.24	\N	2026-05-19 20:59:08.664163+07
521	49	share_verified	demo_anna	1	255651.02	\N	2026-05-19 20:59:09.332477+07
522	49	new_bid	truealex2	9	255653.24	\N	2026-05-19 20:59:09.33775+07
523	49	share_verified	demo_anna	1	255653.24	\N	2026-05-19 20:59:10.675688+07
524	49	new_bid	truealex2	9	255655.46	\N	2026-05-19 20:59:10.679927+07
525	49	share_verified	truealex2	9	255653.24	\N	2026-05-19 20:59:11.352993+07
526	49	new_bid	demo_anna	1	255655.46	\N	2026-05-19 20:59:11.362112+07
527	49	share_verified	truealex2	9	255655.46	\N	2026-05-19 20:59:12.69179+07
528	49	new_bid	demo_anna	1	255657.68	\N	2026-05-19 20:59:12.697922+07
529	49	share_verified	demo_anna	1	255655.46	\N	2026-05-19 20:59:13.371055+07
530	49	new_bid	truealex2	9	255657.68	\N	2026-05-19 20:59:13.376639+07
531	49	share_verified	demo_anna	1	255657.68	\N	2026-05-19 20:59:14.717751+07
532	49	new_bid	truealex2	9	255659.90	\N	2026-05-19 20:59:14.721964+07
533	49	share_verified	truealex2	9	255657.68	\N	2026-05-19 20:59:15.384542+07
534	49	new_bid	demo_anna	1	255659.90	\N	2026-05-19 20:59:15.39011+07
535	49	share_verified	truealex2	9	255659.90	\N	2026-05-19 20:59:16.726322+07
536	49	new_bid	demo_anna	1	255662.12	\N	2026-05-19 20:59:16.732981+07
537	49	share_verified	demo_anna	1	255659.90	\N	2026-05-19 20:59:17.395708+07
538	49	new_bid	truealex2	9	255662.12	\N	2026-05-19 20:59:17.400093+07
539	49	share_verified	demo_anna	1	255662.12	\N	2026-05-19 20:59:18.750537+07
540	49	new_bid	truealex2	9	255664.34	\N	2026-05-19 20:59:18.757674+07
541	49	share_verified	truealex2	9	255662.12	\N	2026-05-19 20:59:19.409351+07
542	49	new_bid	demo_anna	1	255664.34	\N	2026-05-19 20:59:19.415327+07
543	49	share_verified	truealex2	9	255664.34	\N	2026-05-19 20:59:20.768339+07
544	49	new_bid	demo_anna	1	255666.56	\N	2026-05-19 20:59:20.774532+07
545	49	share_verified	demo_anna	1	255664.34	\N	2026-05-19 20:59:21.426161+07
546	49	new_bid	truealex2	9	255666.56	\N	2026-05-19 20:59:21.431064+07
547	49	share_verified	demo_anna	1	255666.56	\N	2026-05-19 20:59:22.790093+07
548	49	new_bid	truealex2	9	255668.78	\N	2026-05-19 20:59:22.797396+07
549	49	share_verified	truealex2	9	255666.56	\N	2026-05-19 20:59:23.434845+07
550	49	new_bid	demo_anna	1	255668.78	\N	2026-05-19 20:59:23.440556+07
551	49	share_verified	truealex2	9	255668.78	\N	2026-05-19 20:59:24.803241+07
552	49	new_bid	demo_anna	1	255671.00	\N	2026-05-19 20:59:24.809504+07
553	49	share_verified	demo_anna	1	255668.78	\N	2026-05-19 20:59:25.45146+07
554	49	new_bid	truealex2	9	255671.00	\N	2026-05-19 20:59:25.455687+07
555	49	share_verified	demo_anna	1	255671.00	\N	2026-05-19 20:59:26.818693+07
556	49	new_bid	truealex2	9	255673.22	\N	2026-05-19 20:59:26.824886+07
557	49	share_verified	truealex2	9	255671.00	\N	2026-05-19 20:59:27.45989+07
558	49	new_bid	demo_anna	1	255673.22	\N	2026-05-19 20:59:27.465618+07
559	49	share_verified	truealex2	9	255673.22	\N	2026-05-19 20:59:28.83464+07
560	49	new_bid	demo_anna	1	255675.44	\N	2026-05-19 20:59:28.838991+07
561	49	share_verified	demo_anna	1	255673.22	\N	2026-05-19 20:59:29.47708+07
562	49	new_bid	truealex2	9	255675.44	\N	2026-05-19 20:59:29.480959+07
563	49	share_verified	demo_anna	1	255675.44	\N	2026-05-19 20:59:30.843135+07
564	49	new_bid	truealex2	9	255677.66	\N	2026-05-19 20:59:30.84761+07
565	49	share_verified	truealex2	9	255675.44	\N	2026-05-19 20:59:31.485043+07
566	49	new_bid	demo_anna	1	255677.66	\N	2026-05-19 20:59:31.489778+07
567	49	share_verified	truealex2	9	255677.66	\N	2026-05-19 20:59:32.85163+07
568	49	new_bid	demo_anna	1	255679.88	\N	2026-05-19 20:59:32.856095+07
569	49	share_verified	demo_anna	1	255677.66	\N	2026-05-19 20:59:33.497169+07
570	49	new_bid	truealex2	9	255679.88	\N	2026-05-19 20:59:33.501294+07
571	49	share_verified	demo_anna	1	255679.88	\N	2026-05-19 20:59:34.863338+07
572	49	new_bid	truealex2	9	255682.10	\N	2026-05-19 20:59:34.867519+07
573	49	share_verified	truealex2	9	255679.88	\N	2026-05-19 20:59:35.510091+07
574	49	new_bid	demo_anna	1	255682.10	\N	2026-05-19 20:59:35.515138+07
575	49	share_verified	truealex2	9	255682.10	\N	2026-05-19 20:59:36.872391+07
576	49	new_bid	demo_anna	1	255684.32	\N	2026-05-19 20:59:36.878208+07
577	49	share_verified	demo_anna	1	255682.10	\N	2026-05-19 20:59:37.529797+07
578	49	new_bid	truealex2	9	255684.32	\N	2026-05-19 20:59:37.534038+07
579	49	share_verified	demo_anna	1	255684.32	\N	2026-05-19 20:59:38.885977+07
580	49	new_bid	truealex2	9	255686.54	\N	2026-05-19 20:59:38.890333+07
581	49	share_verified	truealex2	9	255684.32	\N	2026-05-19 20:59:39.551865+07
582	49	new_bid	demo_anna	1	255686.54	\N	2026-05-19 20:59:39.556279+07
583	49	share_verified	truealex2	9	255686.54	\N	2026-05-19 20:59:40.898089+07
584	49	new_bid	demo_anna	1	255688.76	\N	2026-05-19 20:59:40.904157+07
585	49	share_verified	demo_anna	1	255686.54	\N	2026-05-19 20:59:41.560549+07
586	49	new_bid	truealex2	9	255688.76	\N	2026-05-19 20:59:41.564885+07
587	49	share_verified	demo_anna	1	255688.76	\N	2026-05-19 20:59:42.910617+07
588	49	new_bid	truealex2	9	255690.98	\N	2026-05-19 20:59:42.915118+07
589	49	share_verified	truealex2	9	255688.76	\N	2026-05-19 20:59:43.57028+07
590	49	new_bid	demo_anna	1	255690.98	\N	2026-05-19 20:59:43.577189+07
591	49	share_verified	truealex2	9	255690.98	\N	2026-05-19 20:59:44.929904+07
592	49	new_bid	demo_anna	1	255693.20	\N	2026-05-19 20:59:44.936099+07
593	49	share_verified	demo_anna	1	255690.98	\N	2026-05-19 20:59:45.582804+07
594	49	new_bid	truealex2	9	255693.20	\N	2026-05-19 20:59:45.589302+07
595	49	share_verified	demo_anna	1	255693.20	\N	2026-05-19 20:59:46.945025+07
596	49	new_bid	truealex2	9	255695.42	\N	2026-05-19 20:59:46.950513+07
597	49	share_verified	truealex2	9	255693.20	\N	2026-05-19 20:59:47.594292+07
598	49	new_bid	demo_anna	1	255695.42	\N	2026-05-19 20:59:47.600332+07
599	49	share_verified	truealex2	9	255695.42	\N	2026-05-19 20:59:48.956406+07
600	49	new_bid	demo_anna	1	255697.64	\N	2026-05-19 20:59:48.961897+07
601	49	share_verified	demo_anna	1	255695.42	\N	2026-05-19 20:59:49.610742+07
602	49	new_bid	truealex2	9	255697.64	\N	2026-05-19 20:59:49.61632+07
603	49	share_verified	demo_anna	1	255697.64	\N	2026-05-19 20:59:50.969632+07
604	49	new_bid	truealex2	9	255699.86	\N	2026-05-19 20:59:50.975573+07
605	49	share_verified	truealex2	9	255697.64	\N	2026-05-19 20:59:51.620202+07
606	49	new_bid	demo_anna	1	255699.86	\N	2026-05-19 20:59:51.625231+07
607	49	share_verified	truealex2	9	255699.86	\N	2026-05-19 20:59:52.987181+07
608	49	new_bid	demo_anna	1	255702.08	\N	2026-05-19 20:59:52.99318+07
609	49	share_verified	demo_anna	1	255699.86	\N	2026-05-19 20:59:53.636247+07
610	49	new_bid	truealex2	9	255702.08	\N	2026-05-19 20:59:53.641732+07
611	49	share_verified	demo_anna	1	255702.08	\N	2026-05-19 20:59:55.003228+07
612	49	new_bid	truealex2	9	255704.30	\N	2026-05-19 20:59:55.009034+07
613	49	share_verified	truealex2	9	255702.08	\N	2026-05-19 20:59:55.653416+07
614	49	new_bid	demo_anna	1	255704.30	\N	2026-05-19 20:59:55.659059+07
615	49	share_verified	truealex2	9	255704.30	\N	2026-05-19 20:59:57.050851+07
616	49	new_bid	demo_anna	1	255706.52	\N	2026-05-19 20:59:57.122927+07
617	49	share_verified	demo_anna	1	255704.30	\N	2026-05-19 20:59:57.670093+07
618	49	new_bid	truealex2	9	255706.52	\N	2026-05-19 20:59:57.695049+07
619	49	share_verified	demo_anna	1	255706.52	\N	2026-05-19 20:59:59.136398+07
620	49	new_bid	truealex2	9	255708.74	\N	2026-05-19 20:59:59.141112+07
621	49	share_verified	truealex2	9	255706.52	\N	2026-05-19 20:59:59.714767+07
622	49	new_bid	demo_anna	1	255708.74	\N	2026-05-19 20:59:59.718998+07
623	49	share_verified	truealex2	9	255708.74	\N	2026-05-19 21:00:01.153366+07
624	49	new_bid	demo_anna	1	255710.96	\N	2026-05-19 21:00:01.158088+07
625	49	share_verified	demo_anna	1	255708.74	\N	2026-05-19 21:00:01.728501+07
626	49	new_bid	truealex2	9	255710.96	\N	2026-05-19 21:00:01.733626+07
627	49	share_verified	demo_anna	1	255710.96	\N	2026-05-19 21:00:03.170122+07
628	49	new_bid	truealex2	9	255713.18	\N	2026-05-19 21:00:03.176172+07
629	49	share_verified	truealex2	9	255710.96	\N	2026-05-19 21:00:03.745418+07
630	49	new_bid	demo_anna	1	255713.18	\N	2026-05-19 21:00:03.750307+07
631	49	share_verified	truealex2	9	255713.18	\N	2026-05-19 21:00:05.186171+07
632	49	new_bid	demo_anna	1	255715.40	\N	2026-05-19 21:00:05.192444+07
633	49	share_verified	demo_anna	1	255713.18	\N	2026-05-19 21:00:05.754155+07
634	49	new_bid	truealex2	9	255715.40	\N	2026-05-19 21:00:05.758291+07
635	49	share_verified	demo_anna	1	255715.40	\N	2026-05-19 21:00:07.204487+07
636	49	new_bid	truealex2	9	255717.62	\N	2026-05-19 21:00:07.208809+07
637	49	share_verified	truealex2	9	255715.40	\N	2026-05-19 21:00:07.762302+07
638	49	new_bid	demo_anna	1	255717.62	\N	2026-05-19 21:00:07.766713+07
639	49	share_verified	truealex2	9	255717.62	\N	2026-05-19 21:00:09.21953+07
640	49	new_bid	demo_anna	1	255719.84	\N	2026-05-19 21:00:09.224808+07
641	49	share_verified	demo_anna	1	255717.62	\N	2026-05-19 21:00:09.771365+07
642	49	new_bid	truealex2	9	255719.84	\N	2026-05-19 21:00:09.777646+07
643	49	share_verified	demo_anna	1	255719.84	\N	2026-05-19 21:00:11.237443+07
644	49	new_bid	truealex2	9	255722.06	\N	2026-05-19 21:00:11.245018+07
645	49	share_verified	truealex2	9	255719.84	\N	2026-05-19 21:00:11.787659+07
646	49	new_bid	demo_anna	1	255722.06	\N	2026-05-19 21:00:11.793722+07
647	49	share_verified	truealex2	9	255722.06	\N	2026-05-19 21:00:13.254796+07
648	49	new_bid	demo_anna	1	255724.28	\N	2026-05-19 21:00:13.259997+07
649	49	share_verified	demo_anna	1	255722.06	\N	2026-05-19 21:00:13.805011+07
650	49	new_bid	truealex2	9	255724.28	\N	2026-05-19 21:00:13.80981+07
651	49	share_verified	demo_anna	1	255724.28	\N	2026-05-19 21:00:15.271182+07
652	49	new_bid	truealex2	9	255726.50	\N	2026-05-19 21:00:15.276265+07
653	49	share_verified	truealex2	9	255724.28	\N	2026-05-19 21:00:15.82099+07
654	49	new_bid	demo_anna	1	255726.50	\N	2026-05-19 21:00:15.825043+07
655	49	share_verified	truealex2	9	255726.50	\N	2026-05-19 21:00:17.280177+07
656	49	new_bid	demo_anna	1	255728.72	\N	2026-05-19 21:00:17.284525+07
657	49	share_verified	demo_anna	1	255726.50	\N	2026-05-19 21:00:17.821253+07
658	49	new_bid	truealex2	9	255728.72	\N	2026-05-19 21:00:17.826443+07
659	49	share_verified	demo_anna	1	255728.72	\N	2026-05-19 21:00:19.30436+07
660	49	new_bid	truealex2	9	255730.94	\N	2026-05-19 21:00:19.309016+07
661	49	share_verified	truealex2	9	255728.72	\N	2026-05-19 21:00:19.837823+07
662	49	new_bid	demo_anna	1	255730.94	\N	2026-05-19 21:00:19.844314+07
663	49	share_verified	truealex2	9	255730.94	\N	2026-05-19 21:00:21.323812+07
664	49	new_bid	demo_anna	1	255733.16	\N	2026-05-19 21:00:21.329119+07
665	49	share_verified	demo_anna	1	255730.94	\N	2026-05-19 21:00:21.850533+07
666	49	new_bid	truealex2	9	255733.16	\N	2026-05-19 21:00:21.856579+07
667	49	share_verified	demo_anna	1	255733.16	\N	2026-05-19 21:00:23.342186+07
668	49	new_bid	truealex2	9	255735.38	\N	2026-05-19 21:00:23.346744+07
669	49	share_verified	truealex2	9	255733.16	\N	2026-05-19 21:00:23.863497+07
670	49	new_bid	demo_anna	1	255735.38	\N	2026-05-19 21:00:23.872331+07
671	49	share_verified	truealex2	9	255735.38	\N	2026-05-19 21:00:25.355573+07
672	49	new_bid	demo_anna	1	255737.60	\N	2026-05-19 21:00:25.360352+07
673	49	share_verified	demo_anna	1	255735.38	\N	2026-05-19 21:00:25.883804+07
674	49	new_bid	truealex2	9	255737.60	\N	2026-05-19 21:00:25.8885+07
675	49	share_verified	demo_anna	1	255737.60	\N	2026-05-19 21:00:27.365453+07
676	49	new_bid	truealex2	9	255739.82	\N	2026-05-19 21:00:27.370473+07
677	49	share_verified	truealex2	9	255737.60	\N	2026-05-19 21:00:27.897208+07
678	49	new_bid	demo_anna	1	255739.82	\N	2026-05-19 21:00:27.902317+07
679	49	share_verified	truealex2	9	255739.82	\N	2026-05-19 21:00:29.372554+07
680	49	new_bid	demo_anna	1	255742.04	\N	2026-05-19 21:00:29.378191+07
681	49	share_verified	demo_anna	1	255739.82	\N	2026-05-19 21:00:29.913829+07
682	49	new_bid	truealex2	9	255742.04	\N	2026-05-19 21:00:29.918124+07
683	49	share_verified	demo_anna	1	255742.04	\N	2026-05-19 21:00:31.388345+07
684	49	new_bid	truealex2	9	255744.26	\N	2026-05-19 21:00:31.393006+07
685	49	share_verified	truealex2	9	255742.04	\N	2026-05-19 21:00:31.92278+07
686	49	new_bid	demo_anna	1	255744.26	\N	2026-05-19 21:00:31.926932+07
687	49	share_verified	truealex2	9	255744.26	\N	2026-05-19 21:00:33.401011+07
688	49	new_bid	demo_anna	1	255746.48	\N	2026-05-19 21:00:33.405466+07
689	49	share_verified	demo_anna	1	255744.26	\N	2026-05-19 21:00:33.936803+07
690	49	new_bid	truealex2	9	255746.48	\N	2026-05-19 21:00:33.943746+07
691	49	share_verified	demo_anna	1	255746.48	\N	2026-05-19 21:00:35.414431+07
692	49	new_bid	truealex2	9	255748.70	\N	2026-05-19 21:00:35.420892+07
693	49	share_verified	truealex2	9	255746.48	\N	2026-05-19 21:00:35.956059+07
694	49	new_bid	demo_anna	1	255748.70	\N	2026-05-19 21:00:35.960975+07
695	49	share_verified	truealex2	9	255748.70	\N	2026-05-19 21:00:37.431142+07
696	49	new_bid	demo_anna	1	255750.92	\N	2026-05-19 21:00:37.436455+07
697	49	share_verified	demo_anna	1	255748.70	\N	2026-05-19 21:00:37.973046+07
698	49	new_bid	truealex2	9	255750.92	\N	2026-05-19 21:00:37.979114+07
699	49	share_verified	demo_anna	1	255750.92	\N	2026-05-19 21:00:39.44823+07
700	49	new_bid	truealex2	9	255753.14	\N	2026-05-19 21:00:39.45297+07
701	49	share_verified	truealex2	9	255750.92	\N	2026-05-19 21:00:39.989561+07
702	49	new_bid	demo_anna	1	255753.14	\N	2026-05-19 21:00:39.995097+07
703	49	share_verified	truealex2	9	255753.14	\N	2026-05-19 21:00:41.45646+07
704	49	new_bid	demo_anna	1	255755.36	\N	2026-05-19 21:00:41.461004+07
705	49	share_verified	demo_anna	1	255753.14	\N	2026-05-19 21:00:41.998226+07
706	49	new_bid	truealex2	9	255755.36	\N	2026-05-19 21:00:42.002448+07
707	49	share_verified	demo_anna	1	255755.36	\N	2026-05-19 21:00:43.4651+07
708	49	new_bid	truealex2	9	255757.58	\N	2026-05-19 21:00:43.470001+07
709	49	auction_ended	demo_anna	1	255755.36	\N	2026-05-19 21:00:43.955405+07
710	49	share_verified	truealex2	9	255755.36	\N	2026-05-19 21:00:44.06126+07
711	49	share_verified	truealex2	9	255757.58	\N	2026-05-19 21:00:45.474306+07
712	30	auction_ended	functest_6142	13	2490.00	\N	2026-05-19 21:08:43.979228+07
713	45	auction_ended	demo_carl	3	110.00	\N	2026-05-19 21:18:43.975232+07
714	46	auction_ended	demo_carl	3	110.00	\N	2026-05-19 21:24:13.971521+07
715	47	auction_ended	demo_carl	3	110.00	\N	2026-05-19 21:25:43.991613+07
716	49	ticket_delivered	Pro777	25	\N	{"payment_id": 10}	2026-05-19 21:35:36.052118+07
717	48	auction_ended	demo_carl	3	210.00	\N	2026-05-19 21:43:13.98754+07
718	50	share_verified	Prodavec_Alex	24	555.56	\N	2026-05-20 20:00:37.273893+07
719	50	new_bid	Pro777	25	566.68	\N	2026-05-20 20:01:11.399191+07
720	50	share_verified	Pro777	25	566.68	\N	2026-05-20 20:01:13.411519+07
721	50	new_bid	Prodavec_Alex	24	577.79	\N	2026-05-20 20:01:13.417158+07
722	50	share_verified	Prodavec_Alex	24	577.79	\N	2026-05-20 20:01:15.430887+07
723	50	new_bid	Pro777	25	1111.12	\N	2026-05-20 20:02:03.357926+07
724	50	share_verified	Pro777	25	1111.12	\N	2026-05-20 20:02:05.362755+07
725	50	new_bid	Prodavec_Alex	24	1122.23	\N	2026-05-20 20:02:05.367681+07
726	50	share_verified	Prodavec_Alex	24	1122.23	\N	2026-05-20 20:02:07.389941+07
727	50	new_bid	Prodavec_Alex	24	1133.34	\N	2026-05-20 20:04:06.577548+07
728	50	timer_extended	\N	\N	\N	{"new_end_time": "2026-05-20T20:07:06.572837+07:00", "extension_seconds": 180}	2026-05-20 20:04:06.577548+07
729	50	share_verified	Prodavec_Alex	24	1133.34	\N	2026-05-20 20:04:08.578413+07
730	50	new_bid	Pro777	25	1144.46	\N	2026-05-20 20:04:32.075485+07
731	50	timer_extended	\N	\N	\N	{"new_end_time": "2026-05-20T20:07:32.069156+07:00", "extension_seconds": 180}	2026-05-20 20:04:32.075485+07
732	50	share_verified	Pro777	25	1144.46	\N	2026-05-20 20:04:34.084599+07
733	50	new_bid	Prodavec_Alex	24	1155.57	\N	2026-05-20 20:04:34.089854+07
734	50	share_verified	Prodavec_Alex	24	1155.57	\N	2026-05-20 20:04:36.112884+07
735	50	new_bid	Pro777	25	122216.67	\N	2026-05-20 20:06:43.375566+07
736	50	timer_extended	\N	\N	\N	{"new_end_time": "2026-05-20T20:09:43.371360+07:00", "extension_seconds": 180}	2026-05-20 20:06:43.375566+07
737	50	share_verified	Pro777	25	122216.67	\N	2026-05-20 20:06:45.375622+07
738	50	auction_ended	Pro777	25	122216.67	\N	2026-05-20 20:09:56.878892+07
739	50	ticket_delivered	truealex	8	\N	{"payment_id": 21}	2026-05-20 20:13:03.20818+07
740	50	escrow_released	Pro777	25	109995.00	{"fee_pct": 10.0, "gross_usd": 122216.67}	2026-05-20 20:13:14.533327+07
741	31	auction_ended	Prodavec_Alex	24	850.00	\N	2026-05-20 21:08:56.88842+07
\.


--
-- Data for Name: lots; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.lots (id, title, artist, description, concert_date, lot_type, start_price_usd, bid_step_usd, end_time, status, winner_id, image_url, created_at, original_duration_seconds, seller_id, featured, listing_fee_usd, final_value_fee_pct, payment_window_minutes) FROM stdin;
40	Бэха	Супер Бэха продается!	Вип Бэха!	2028-06-25 16:20:00+07	vip	100000.00	1000.00	2026-05-18 20:18:55.795163+07	cancelled	\N	/static/lot_images/lot_40_c6d7ef13b7e9.webp	2026-05-18 19:18:55.791344+07	3600	24	t	15.00	10.00	8
43	Верблюд на реактивной тяге	Летает!	Стол в наличии	2027-05-18 20:20:00+07	table	111.11	0.56	2026-05-18 21:03:13.061208+07	ended	23	/static/lot_images/lot_43_cb15f027f7cd.webp	2026-05-18 20:53:13.056466+07	600	24	t	15.00	10.00	300
29	Алый эхо-сейшн	Луна Вале · Ереванская Арена	2 VIP-билета и доступ в лаунж	2026-05-30 21:08:41.912208+07	vip	1245.00	65.00	2026-05-18 21:08:41.912208+07	cancelled	\N	\N	2026-05-16 21:08:41.90383+07	172800	2	t	0.00	10.00	1440
35	Швабра	frgthbnmj	ШВАБРА	2026-05-17 20:00:00+07	tickets	50.00	50.00	2026-05-17 17:49:20.512978+07	ended	1	\N	2026-05-17 16:49:20.507839+07	3600	9	t	15.00	10.00	1440
45	Proxy test lot	PA	d	2026-06-18 20:18:29.812989+07	tickets	100.00	10.00	2026-05-19 21:18:29.820286+07	cancelled	\N	\N	2026-05-19 20:18:29.815338+07	3600	1	f	5.00	10.00	60
46	Proxy test lot	PA	d	2026-06-18 20:23:55.544396+07	tickets	100.00	10.00	2026-05-19 21:23:55.55897+07	cancelled	\N	\N	2026-05-19 20:23:55.556068+07	3600	1	f	5.00	10.00	60
47	Proxy test lot	PA	d	2026-06-18 20:25:27.316625+07	tickets	100.00	10.00	2026-05-19 21:25:27.322349+07	cancelled	\N	\N	2026-05-19 20:25:27.319327+07	3600	1	f	5.00	10.00	60
64	Открытие сезона Большого театра · ВИП	Большой театр	VIP-фойе, шампанское, 4 ряд бенуар.	2026-07-04 20:28:27.32771+07	vip	600.00	30.00	2026-05-22 20:54:11.078452+07	active	\N	/static/lot_images/bolshoi_opening.jpg	2026-05-20 20:28:27.314193+07	174343	1	t	0.00	10.00	1440
31	После заката	Нарек Уэйвз · Open Air Stage	Партер на двоих с напитками	2026-06-08 21:08:41.912208+07	tickets	810.00	40.00	2026-05-20 21:08:41.912208+07	ended	24	\N	2026-05-16 21:08:41.90383+07	345600	2	t	0.00	10.00	1440
30	Полуночный оркестр	Арам Коллектив · Оперный зал	Приватный стол + встреча с артистом	2026-06-03 21:08:41.912208+07	table	2360.00	130.00	2026-05-19 21:08:41.912208+07	ended	1	\N	2026-05-16 21:08:41.90383+07	259200	2	t	0.00	10.00	1440
36	Картинка	Обычная Швабра	описание	2026-05-17 21:00:00+07	vip	1.00	0.11	2026-05-17 21:43:53.460721+07	cancelled	\N	\N	2026-05-17 20:43:53.456748+07	3600	9	t	15.00	10.00	1440
37	кпцфпмакфу	ацфуацу	fewfwwa	2028-02-27 23:14:00+07	tickets	12333.00	23.00	2026-05-17 22:16:24.575372+07	cancelled	\N	\N	2026-05-17 21:16:24.571391+07	3600	9	f	5.00	10.00	1440
38	dwadwasdwasdwa	sdwasdwasdwa	sdwasdwasdwasdwa	3222-02-23 23:22:00+07	tickets	2.47	0.24	2026-05-17 22:20:07.96405+07	cancelled	\N	/static/lot_images/lot_38_b50d3df1e565.jpg	2026-05-17 21:20:07.959527+07	3600	9	t	15.00	10.00	1440
33	Бархатный бис	Сона Рэй · Площадь Республики	Билет в первый сектор	2026-05-28 21:08:41.912208+07	tickets	660.00	30.00	2026-05-18 09:08:41.912208+07	ended	9	\N	2026-05-16 21:08:41.90383+07	129600	2	f	0.00	10.00	1440
34	Гало-секшн	DJ Артур · Клуб Wave	VIP-капсула на четверых	2026-06-05 21:08:41.912208+07	vip	980.00	50.00	2026-05-23 21:08:41.912208+07	active	\N	\N	2026-05-16 21:08:41.90383+07	604800	2	t	0.00	10.00	1440
32	Северное сияние LIVE	Маро Неон · Каскадная Терраса	VIP-платформа с видом	2026-06-20 21:08:41.912208+07	vip	1410.00	65.00	2026-05-21 21:08:41.912208+07	active	\N	\N	2026-05-16 21:08:41.90383+07	432000	2	t	0.00	10.00	1440
41	Тестовый лот высокая цена	Артист	Описание	2026-06-17 19:38:52.387494+07	tickets	50000.00	500.00	2026-05-18 20:38:52.394331+07	cancelled	\N	\N	2026-05-18 19:38:52.38977+07	3600	1	f	5.00	10.00	90
42	Премиум	Артист	опс	2026-06-17 19:39:04.807282+07	tickets	500000.00	1000.00	2026-05-18 20:39:04.82392+07	cancelled	\N	\N	2026-05-18 19:39:04.819572+07	3600	1	f	5.00	10.00	60
50	Щелкунчик	В москве щелкунчик!	Билеты на щелкунчика в мск!	2028-08-25 20:00:00+07	tickets	555.56	11.11	2026-05-20 20:09:43.37136+07	ended	25	/static/lot_images/lot_50_690aa6f20188.webp	2026-05-20 19:56:58.850638+07	600	8	t	15.00	10.00	10
48	Proxy test lot	PA	d	2026-06-18 20:43:00.71231+07	tickets	100.00	10.00	2026-05-19 21:43:00.727961+07	ended	3	\N	2026-05-19 20:43:00.724147+07	3600	1	f	5.00	10.00	60
51	Концерт Imagine Dragons · Москва	Imagine Dragons	Партер. 2 билета рядом. Концерт в Олимпийском.	2026-06-24 20:28:27.317861+07	tickets	180.00	10.00	2026-05-21 10:39:12.419797+07	active	\N	/static/lot_images/imagine_dragons.jpg	2026-05-20 20:28:27.314193+07	51045	1	t	0.00	10.00	1440
52	VIP-ложа на финал Лиги Чемпионов	UEFA	VIP-ложа на 4 персоны. Включён фуршет, паркинг.	2026-07-19 20:28:27.320236+07	vip	850.00	50.00	2026-05-21 11:06:17.06362+07	active	\N	/static/lot_images/champions_league.jpg	2026-05-20 20:28:27.314193+07	52669	1	t	0.00	10.00	1440
53	Stand-up Comedy Club · Москва	Comedy Club	Первые ряды. Резиденты Comedy Club. Шоу 18+.	2026-06-10 20:28:27.320917+07	tickets	70.00	5.00	2026-05-21 11:13:33.101461+07	active	\N	/static/lot_images/comedy_club.jpg	2026-05-20 20:28:27.314193+07	53105	1	t	0.00	10.00	1440
54	Метро 2033 · The ROXY Theatre	Артемий Лебедев	Премьерный показ. 5 ряд центр.	2026-06-17 20:28:27.321581+07	tickets	120.00	10.00	2026-05-21 10:33:57.879888+07	active	\N	/static/lot_images/metro_2033.jpg	2026-05-20 20:28:27.314193+07	50730	1	t	0.00	10.00	1440
55	Финал Что? Где? Когда? · Останкино	Первый канал	VIP-стол. Зимняя серия игр.	2026-07-14 20:28:27.322369+07	vip	350.00	20.00	2026-05-22 22:34:55.252219+07	active	\N	/static/lot_images/chgk_final.jpg	2026-05-20 20:28:27.314193+07	180387	1	t	0.00	10.00	1440
56	Концерт Linkin Park Tribute	Tribute LP	Партер, фан-зона у сцены.	2026-07-01 20:28:27.322998+07	tickets	95.00	5.00	2026-05-22 18:18:01.681228+07	active	\N	/static/lot_images/linkin_park_tribute.jpg	2026-05-20 20:28:27.314193+07	164974	1	t	0.00	10.00	1440
57	Балет «Лебединое озеро» · Большой театр	Большой театр	Историческая сцена. 7 ряд партер.	2026-07-29 20:28:27.323644+07	tickets	240.00	15.00	2026-05-23 02:06:36.216223+07	active	\N	/static/lot_images/swan_lake.jpg	2026-05-20 20:28:27.314193+07	193088	1	t	0.00	10.00	1440
58	Хоккей: СКА — ЦСКА · Ледовый	КХЛ	Места возле скамейки команд.	2026-06-07 20:28:27.324202+07	tickets	130.00	10.00	2026-05-23 15:32:23.320645+07	active	\N	/static/lot_images/hockey_ska.jpg	2026-05-20 20:28:27.314193+07	241435	1	t	0.00	10.00	1440
59	Стол на двоих · ресторан White Rabbit	White Rabbit	Окно с видом на Москву. Дегустационное меню.	2026-06-01 20:28:27.324849+07	table	200.00	15.00	2026-05-22 12:20:54.361404+07	active	\N	/static/lot_images/white_rabbit.jpg	2026-05-20 20:28:27.314193+07	143547	1	t	0.00	10.00	1440
60	VIP-проход на Comic Con Moscow	Comic Con	Все 3 дня. Без очереди. Закрытые автограф-сессии.	2026-08-18 20:28:27.325437+07	vip	160.00	10.00	2026-05-22 13:24:25.413341+07	active	\N	/static/lot_images/comic_con.jpg	2026-05-20 20:28:27.314193+07	147358	1	t	0.00	10.00	1440
61	Концерт The Hatters · Adrenaline	The Hatters	Танцпол. Закрытая встреча после концерта.	2026-06-22 20:28:27.326046+07	tickets	80.00	5.00	2026-05-23 13:34:44.047721+07	active	\N	/static/lot_images/the_hatters.jpg	2026-05-20 20:28:27.314193+07	234376	1	t	0.00	10.00	1440
62	Билет на премьеру Marvel · IMAX Каро	IMAX	IMAX 3D, премьерный показ в полночь.	2026-05-28 20:28:27.326611+07	tickets	60.00	5.00	2026-05-23 00:37:06.687975+07	active	\N	/static/lot_images/marvel_imax.jpg	2026-05-20 20:28:27.314193+07	187719	1	t	0.00	10.00	1440
63	Дегустация виски · Whisky Rooms	Whisky Rooms	Сет из 8 виски. Сомелье. На двоих.	2026-06-03 20:28:27.327142+07	table	150.00	10.00	2026-05-22 19:13:05.758862+07	active	\N	/static/lot_images/whisky_rooms.jpg	2026-05-20 20:28:27.314193+07	168278	1	t	0.00	10.00	1440
49	Калькулятор	кпаеуувкпае	рррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррррр	2028-08-25 18:00:00+07	vip	222.22	2.22	2026-05-19 21:00:39.997349+07	ended	9	/static/lot_images/lot_49_1991baefdb3a.jpeg	2026-05-19 20:49:37.408768+07	600	25	f	5.00	10.00	5
\.


--
-- Data for Name: notifications; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.notifications (id, user_id, kind, title, body, lot_id, payment_id, read_at, created_at) FROM stdin;
84	25	outbid	⚡ Вашу ставку перебили	По лоту #50 ваша ставка перебита. Новая ставка: 577.79 USD. Поставьте ставку выше, чтобы вернуть лидерство.	50	\N	2026-05-20 20:01:33.711515+07	2026-05-20 20:01:13.421264+07
86	25	outbid	⚡ Вашу ставку перебили	По лоту #50 ваша ставка перебита. Новая ставка: 1122.23 USD. Поставьте ставку выше, чтобы вернуть лидерство.	50	\N	2026-05-20 20:02:05.527871+07	2026-05-20 20:02:05.372131+07
6	24	lot_sold_pending_payment	🎉 Ваш лот «Верблюд на реактивной тяге» продан	Победитель: bidstage_support. Сумма выигрыша: $112.23. Покупатель должен оплатить в течение 5 ч. Мы сообщим, как только оплата поступит.	43	\N	2026-05-18 21:06:07.112802+07	2026-05-18 21:03:28.920896+07
5	23	auction_won	🏆 Вы победили в аукционе «Верблюд на реактивной тяге»!	Ваша ставка $112.23 оказалась выигрышной. Оплатите выигрыш в течение 5 ч, иначе лот перейдёт следующему биддеру.	43	4	2026-05-18 21:06:29.439564+07	2026-05-18 21:03:28.914986+07
85	24	outbid	⚡ Вашу ставку перебили	По лоту #50 ваша ставка перебита. Новая ставка: 1111.12 USD. Поставьте ставку выше, чтобы вернуть лидерство.	50	\N	2026-05-20 20:02:14.156386+07	2026-05-20 20:02:03.359615+07
7	24	chat_message	✉️ Новое сообщение от bidstage_support	Лот «Верблюд на реактивной тяге»\n\nоке	43	\N	2026-05-18 21:07:12.242878+07	2026-05-18 21:06:58.376491+07
83	24	outbid	⚡ Вашу ставку перебили	По лоту #50 ваша ставка перебита. Новая ставка: 566.68 USD. Поставьте ставку выше, чтобы вернуть лидерство.	50	\N	2026-05-20 20:03:12.560124+07	2026-05-20 20:01:11.400777+07
10	24	bid_rejected	❌ Ставка $850.00 отклонена	Лот «После заката»\n\nВ посте по вашей ссылке не найдено упоминание этого лота. Опубликуйте пост, в тексте которого есть ссылка на /lot/31, и сделайте ставку заново.\n\nСтавка не учтена. Деньги не списаны. Сделайте новую ставку, опубликовав пост со ссылкой на лот.	31	\N	2026-05-18 21:53:57.969305+07	2026-05-18 21:53:51.061358+07
88	25	outbid	⚡ Вашу ставку перебили	По лоту #50 ваша ставка перебита. Новая ставка: 1155.57 USD. Поставьте ставку выше, чтобы вернуть лидерство.	50	\N	2026-05-20 20:05:48.181031+07	2026-05-20 20:04:34.094478+07
9	13	bid_rejected	❌ Ставка $850.00 отклонена	Лот «После заката»\n\nВ посте по вашей ссылке не найдено упоминание этого лота. Опубликуйте пост, в тексте которого есть ссылка на /lot/31, и сделайте ставку заново.\n\nСтавка не учтена. Деньги не списаны. Сделайте новую ставку, опубликовав пост со ссылкой на лот.	31	\N	2026-05-19 19:03:07.243924+07	2026-05-18 21:51:46.728123+07
12	1	cascade_advanced	🏆 Лот «Швабра» переходит к вам!	Победитель не оплатил вовремя, и по правилам каскада лот теперь ваш.\n\nСумма к оплате: $499.45\n\nЧто делать:\n1. Откройте «Профиль» в правом верхнем углу\n2. В блоке «Эскроу и платежи» нажмите «Оплатить картой» или «Списать с баланса»\n\n⏱ У вас есть 24 ч на оплату. Если не успеете — лот достанется следующему биддеру.\n\nПосле оплаты деньги уйдут в эскроу до подтверждения получения билета.	35	5	2026-05-19 19:20:30.429735+07	2026-05-19 18:58:45.55958+07
11	1	payment_expired	⏱️ Срок оплаты по лоту «Швабра» истёк	Вы не оплатили свою ставку $549.45 в отведённое время. Лот передан следующему участнику.	35	3	2026-05-19 19:20:31.02282+07	2026-05-19 18:58:45.541372+07
2	1	cascade_advanced	🏆 Лот «Швабра» переходит к вам!	Победитель не оплатил выигрыш. По каскаду лот теперь ваш по ставке $549.45. Оплатите в течение 24 ч, иначе лот перейдёт следующему участнику.	35	3	2026-05-19 19:20:31.469656+07	2026-05-18 18:35:41.781044+07
1	1	payment_expired	⏱️ Срок оплаты по лоту «Швабра» истёк	Вы не оплатили свою ставку $4358.98 в отведённое время. Лот передан следующему участнику.	35	1	2026-05-19 19:20:31.841886+07	2026-05-18 18:35:41.765315+07
13	9	cascade_advanced	Каскад по лоту «Швабра»: пользователь demo_anna не оплатил	Лот перешёл к demo_anna. Если он также не оплатит, возможно лот достанется вам. Ожидаемое время до вашей очереди: до окончания текущего периода оплаты.	35	\N	2026-05-19 20:45:15.187461+07	2026-05-19 18:58:45.563517+07
4	9	cascade_advanced	Лот «Швабра»: новый победитель	Предыдущий победитель не оплатил. Теперь лот за demo_anna по ставке $549.45.	35	\N	2026-05-19 20:45:15.57699+07	2026-05-18 18:35:41.789884+07
3	9	cascade_advanced	Каскад по лоту «Швабра»: пользователь demo_anna не оплатил	Лот перешёл к demo_anna. Если он также не оплатит, возможно лот достанется вам. Ожидаемое время до вашей очереди: до окончания текущего периода оплаты.	35	\N	2026-05-19 20:45:15.934868+07	2026-05-18 18:35:41.785572+07
87	24	outbid	⚡ Вашу ставку перебили	По лоту #50 ваша ставка перебита. Новая ставка: 1144.46 USD. Поставьте ставку выше, чтобы вернуть лидерство.	50	\N	2026-05-20 20:05:16.035362+07	2026-05-20 20:04:32.077472+07
15	2	chat_message	✉️ Новое сообщение от functest_6142	Лот «Северное сияние LIVE»\n\nкак дела?	32	\N	2026-05-19 19:28:42.03858+07	2026-05-19 19:27:47.15716+07
89	24	outbid	⚡ Вашу ставку перебили	По лоту #50 ваша ставка перебита. Новая ставка: 122216.67 USD. Поставьте ставку выше, чтобы вернуть лидерство.	50	\N	2026-05-20 20:06:46.600121+07	2026-05-20 20:06:43.377706+07
16	13	chat_message	✉️ Новое сообщение от demo_boris	Лот «Северное сияние LIVE»\n\nнорм всё!	32	\N	2026-05-19 19:28:58.314249+07	2026-05-19 19:28:51.3132+07
98	2	payment_expired	⏱️ Срок оплаты по лоту «Proxy test lot» истёк	Вы не оплатили свою ставку $180.00 в отведённое время. Лот передан следующему участнику.	48	20	\N	2026-05-20 20:46:26.931481+07
14	9	cascade_advanced	Лот «Швабра»: новый победитель	Предыдущий победитель не оплатил. Теперь лот за demo_anna по ставке $499.45.	35	\N	2026-05-19 20:45:14.732485+07	2026-05-19 18:58:45.567832+07
102	13	payment_expired	⏱️ Срок оплаты по лоту «Полуночный оркестр» истёк	Вы не оплатили свою ставку $2490.00 в отведённое время. Лот передан следующему участнику.	30	8	\N	2026-05-20 21:08:56.910882+07
20	8	auction_runner_up	🥈 Аукцион «Калькулятор» завершён. Вы заняли 3-е место	Победитель — пользователь demo_anna, ставка $255755.36. Если вышестоящие участники не оплатят свои выигрыши, лот может перейти к вам. Ожидаемое время до вашей очереди: 10 мин. Мы пришлём уведомление, как только это произойдёт.	49	\N	2026-05-19 21:01:01.078305+07	2026-05-19 21:00:44.230419+07
19	9	auction_runner_up	🥈 Аукцион «Калькулятор» завершён. Вы заняли 2-е место	Победитель — пользователь demo_anna, ставка $255755.36. Если вышестоящие участники не оплатят свои выигрыши, лот может перейти к вам. Ожидаемое время до вашей очереди: 5 мин. Мы пришлём уведомление, как только это произойдёт.	49	\N	2026-05-19 21:01:08.163749+07	2026-05-19 21:00:44.145069+07
18	1	auction_won	🏆 Вы победили в аукционе «Калькулятор»!	Поздравляем! Ваша ставка $255755.36 стала выигрышной.\n\nЧто делать сейчас:\n1. Перейдите в раздел «Профиль» (правый верхний угол)\n2. Найдите блок «Эскроу и платежи»\n3. Нажмите «Оплатить картой» или «Списать с баланса»\n\n⏱ Срок оплаты: 5 мин.\nЕсли не успеете — лот автоматически перейдёт следующему биддеру.\n\nПосле оплаты деньги уйдут в эскроу. Продавец отправит билет, вы получите уведомление и подтвердите получение — только после этого продавец получит деньги.	49	6	2026-05-19 21:01:53.956505+07	2026-05-19 21:00:43.981324+07
22	1	payment_paid	✅ Оплата принята по лоту «Швабра»	Сумма $499.45 отправлена в эскроу. Ожидайте, пока продавец отправит билет, затем подтвердите получение в профиле.	35	5	2026-05-19 21:01:54.592558+07	2026-05-19 21:01:45.107206+07
28	13	auction_won	🏆 Вы победили в аукционе «Полуночный оркестр»!	Поздравляем! Ваша ставка $2490.00 стала выигрышной.\n\nЧто делать сейчас:\n1. Перейдите в раздел «Профиль» (правый верхний угол)\n2. Найдите блок «Эскроу и платежи»\n3. Нажмите «Оплатить картой» или «Списать с баланса»\n\n⏱ Срок оплаты: 24 ч.\nЕсли не успеете — лот автоматически перейдёт следующему биддеру.\n\nПосле оплаты деньги уйдут в эскроу. Продавец отправит билет, вы получите уведомление и подтвердите получение — только после этого продавец получит деньги.	30	8	\N	2026-05-19 21:08:44.000891+07
23	9	buyer_paid	💸 Покупатель оплатил лот «Швабра»	Покупатель demo_anna оплатил $499.45.\n\nДеньги в эскроу — пока не у вас. Что делать:\n1. Откройте «Продать → Мои аукционы» (правый верхний угол)\n2. Найдите блок «🔒 Эскроу»\n3. Введите код билета и нажмите «Билет отправлен»\n\nПосле того как покупатель подтвердит получение — деньги поступят на ваш баланс.	35	5	2026-05-19 21:20:20.686301+07	2026-05-19 21:01:45.181478+07
26	8	cascade_advanced	Каскад по лоту «Калькулятор»: пользователь demo_anna не оплатил	Лот перешёл к truealex2. Если он также не оплатит, возможно лот достанется вам. Ожидаемое время до вашей очереди: 5 мин.	49	\N	2026-05-19 21:22:21.627283+07	2026-05-19 21:05:44.104334+07
27	25	cascade_advanced	Лот «Калькулятор»: новый победитель	Предыдущий победитель не оплатил. Теперь лот за truealex2 по ставке $255757.58.	49	\N	2026-05-19 21:35:06.257087+07	2026-05-19 21:05:44.369795+07
21	25	lot_sold_pending_payment	🎉 Ваш лот «Калькулятор» продан	Победитель: demo_anna. Сумма выигрыша: $255755.36. Покупатель должен оплатить в течение 5 мин. Мы сообщим, как только оплата поступит.	49	\N	2026-05-19 21:35:06.597895+07	2026-05-19 21:00:44.322987+07
24	1	payment_expired	⏱️ Срок оплаты по лоту «Калькулятор» истёк	Вы не оплатили свою ставку $255755.36 в отведённое время. Лот передан следующему участнику.	49	6	2026-05-20 11:57:10.472647+07	2026-05-19 21:05:43.997699+07
91	24	auction_runner_up	🥈 Аукцион «Щелкунчик» завершён. Вы заняли 2-е место	Победитель — пользователь Pro777, ставка $122216.67. Если вышестоящие участники не оплатят свои выигрыши, лот может перейти к вам. Ожидаемое время до вашей очереди: 10 мин. Мы пришлём уведомление, как только это произойдёт.	50	\N	2026-05-20 20:25:35.474517+07	2026-05-20 20:09:56.940859+07
41	3	auction_won	🏆 Вы победили в аукционе «Proxy test lot»!	Поздравляем! Ваша ставка $110.00 стала выигрышной.\n\nЧто делать сейчас:\n1. Перейдите в раздел «Профиль» (правый верхний угол)\n2. Найдите блок «Эскроу и платежи»\n3. Нажмите «Оплатить картой» или «Списать с баланса»\n\n⏱ Срок оплаты: 1 ч.\nЕсли не успеете — лот автоматически перейдёт следующему биддеру.\n\nПосле оплаты деньги уйдут в эскроу. Продавец отправит билет, вы получите уведомление и подтвердите получение — только после этого продавец получит деньги.	45	11	\N	2026-05-19 21:18:43.986229+07
31	9	payment_expired	⏱️ Срок оплаты по лоту «Калькулятор» истёк	Вы не оплатили свою ставку $255757.58 в отведённое время. Лот передан следующему участнику.	49	7	2026-05-19 21:20:16.402097+07	2026-05-19 21:11:14.113193+07
37	9	cascade_advanced	🏆 Лот «Калькулятор» переходит к вам!	Победитель не оплатил вовремя, и по правилам каскада лот теперь ваш.\n\nСумма к оплате: $255753.14\n\nЧто делать:\n1. Откройте «Профиль» в правом верхнем углу\n2. В блоке «Эскроу и платежи» нажмите «Оплатить картой» или «Списать с баланса»\n\n⏱ У вас есть 5 мин на оплату. Если не успеете — лот достанется следующему биддеру.\n\nПосле оплаты деньги уйдут в эскроу до подтверждения получения билета.	49	10	2026-05-19 21:20:18.054178+07	2026-05-19 21:16:44.08311+07
36	9	payment_expired	⏱️ Срок оплаты по лоту «Калькулятор» истёк	Вы не оплатили свою ставку $255755.36 в отведённое время. Лот передан следующему участнику.	49	9	2026-05-19 21:20:18.605875+07	2026-05-19 21:16:43.976969+07
39	8	cascade_advanced	Каскад по лоту «Калькулятор»: пользователь truealex2 не оплатил	Лот перешёл к truealex2. Если он также не оплатит, возможно лот достанется вам. Ожидаемое время до вашей очереди: 5 мин.	49	\N	2026-05-19 21:22:20.873138+07	2026-05-19 21:16:44.401778+07
34	8	cascade_advanced	Каскад по лоту «Калькулятор»: пользователь truealex2 не оплатил	Лот перешёл к truealex2. Если он также не оплатит, возможно лот достанется вам. Ожидаемое время до вашей очереди: 5 мин.	49	\N	2026-05-19 21:22:21.341041+07	2026-05-19 21:11:14.409544+07
40	25	cascade_advanced	Лот «Калькулятор»: новый победитель	Предыдущий победитель не оплатил. Теперь лот за truealex2 по ставке $255753.14.	49	\N	2026-05-19 21:35:05.460559+07	2026-05-19 21:16:44.498241+07
35	25	cascade_advanced	Лот «Калькулятор»: новый победитель	Предыдущий победитель не оплатил. Теперь лот за truealex2 по ставке $255755.36.	49	\N	2026-05-19 21:35:05.902873+07	2026-05-19 21:11:14.541039+07
29	1	auction_runner_up	🥈 Аукцион «Полуночный оркестр» завершён. Вы заняли 2-е место	Победитель — пользователь functest_6142, ставка $2490.00. Если вышестоящие участники не оплатят свои выигрыши, лот может перейти к вам. Ожидаемое время до вашей очереди: 24 ч. Мы пришлём уведомление, как только это произойдёт.	30	\N	2026-05-20 11:57:10.472647+07	2026-05-19 21:08:44.006355+07
43	1	lot_sold_pending_payment	🎉 Ваш лот «Proxy test lot» продан	Победитель: demo_carl. Сумма выигрыша: $110.00. Покупатель должен оплатить в течение 1 ч. Мы сообщим, как только оплата поступит.	45	\N	2026-05-20 11:57:10.472647+07	2026-05-19 21:18:43.995762+07
42	2	auction_runner_up	🥈 Аукцион «Proxy test lot» завершён. Вы заняли 2-е место	Победитель — пользователь demo_carl, ставка $110.00. Если вышестоящие участники не оплатят свои выигрыши, лот может перейти к вам. Ожидаемое время до вашей очереди: 1 ч. Мы пришлём уведомление, как только это произойдёт.	45	\N	2026-05-20 19:53:12.766908+07	2026-05-19 21:18:43.991797+07
30	2	lot_sold_pending_payment	🎉 Ваш лот «Полуночный оркестр» продан	Победитель: functest_6142. Сумма выигрыша: $2490.00. Покупатель должен оплатить в течение 24 ч. Мы сообщим, как только оплата поступит.	30	\N	2026-05-20 19:53:13.007752+07	2026-05-19 21:08:44.010569+07
32	9	cascade_advanced	🏆 Лот «Калькулятор» переходит к вам!	Победитель не оплатил вовремя, и по правилам каскада лот теперь ваш.\n\nСумма к оплате: $255755.36\n\nЧто делать:\n1. Откройте «Профиль» в правом верхнем углу\n2. В блоке «Эскроу и платежи» нажмите «Оплатить картой» или «Списать с баланса»\n\n⏱ У вас есть 5 мин на оплату. Если не успеете — лот достанется следующему биддеру.\n\nПосле оплаты деньги уйдут в эскроу до подтверждения получения билета.	49	9	2026-05-19 21:20:15.531115+07	2026-05-19 21:11:14.198972+07
25	9	cascade_advanced	🏆 Лот «Калькулятор» переходит к вам!	Победитель не оплатил вовремя, и по правилам каскада лот теперь ваш.\n\nСумма к оплате: $255757.58\n\nЧто делать:\n1. Откройте «Профиль» в правом верхнем углу\n2. В блоке «Эскроу и платежи» нажмите «Оплатить картой» или «Списать с баланса»\n\n⏱ У вас есть 5 мин на оплату. Если не успеете — лот достанется следующему биддеру.\n\nПосле оплаты деньги уйдут в эскроу до подтверждения получения билета.	49	7	2026-05-19 21:20:19.652529+07	2026-05-19 21:05:44.093304+07
92	8	lot_sold_pending_payment	🎉 Ваш лот «Щелкунчик» продан	Победитель: Pro777. Сумма выигрыша: $122216.67. Покупатель должен оплатить в течение 10 мин. Мы сообщим, как только оплата поступит.	50	\N	2026-05-20 20:11:09.641698+07	2026-05-20 20:09:57.089963+07
44	9	payment_paid	✅ Оплата принята по лоту «Калькулятор»	Сумма $255753.14 отправлена в эскроу. Ожидайте, пока продавец отправит билет, затем подтвердите получение в профиле.	49	10	2026-05-19 21:22:04.291137+07	2026-05-19 21:21:32.00503+07
46	3	auction_won	🏆 Вы победили в аукционе «Proxy test lot»!	Поздравляем! Ваша ставка $110.00 стала выигрышной.\n\nЧто делать сейчас:\n1. Перейдите в раздел «Профиль» (правый верхний угол)\n2. Найдите блок «Эскроу и платежи»\n3. Нажмите «Оплатить картой» или «Списать с баланса»\n\n⏱ Срок оплаты: 1 ч.\nЕсли не успеете — лот автоматически перейдёт следующему биддеру.\n\nПосле оплаты деньги уйдут в эскроу. Продавец отправит билет, вы получите уведомление и подтвердите получение — только после этого продавец получит деньги.	46	12	\N	2026-05-19 21:24:13.986158+07
49	3	auction_won	🏆 Вы победили в аукционе «Proxy test lot»!	Поздравляем! Ваша ставка $110.00 стала выигрышной.\n\nЧто делать сейчас:\n1. Перейдите в раздел «Профиль» (правый верхний угол)\n2. Найдите блок «Эскроу и платежи»\n3. Нажмите «Оплатить картой» или «Списать с баланса»\n\n⏱ Срок оплаты: 1 ч.\nЕсли не успеете — лот автоматически перейдёт следующему биддеру.\n\nПосле оплаты деньги уйдут в эскроу. Продавец отправит билет, вы получите уведомление и подтвердите получение — только после этого продавец получит деньги.	47	13	\N	2026-05-19 21:25:44.023496+07
52	9	ticket_delivered	🎫 Продавец отправил билет по лоту «Калькулятор»	Билет: лови ссылку на него!\n\nПроверьте билет, подтвердите получение в профиле — после этого деньги поступят продавцу.	49	10	2026-05-19 21:36:11.093517+07	2026-05-19 21:35:36.073225+07
45	25	buyer_paid	💸 Покупатель оплатил лот «Калькулятор»	Покупатель truealex2 оплатил $255753.14.\n\nДеньги в эскроу — пока не у вас. Что делать:\n1. Откройте «Продать → Мои аукционы» (правый верхний угол)\n2. Найдите блок «🔒 Эскроу»\n3. Введите код билета и нажмите «Билет отправлен»\n\nПосле того как покупатель подтвердит получение — деньги поступят на ваш баланс.	49	10	2026-05-19 21:36:27.120308+07	2026-05-19 21:21:32.088276+07
53	3	auction_won	🏆 Вы победили в аукционе «Proxy test lot»!	Поздравляем! Ваша ставка $210.00 стала выигрышной.\n\nЧто делать сейчас:\n1. Перейдите в раздел «Профиль» (правый верхний угол)\n2. Найдите блок «Эскроу и платежи»\n3. Нажмите «Оплатить картой» или «Списать с баланса»\n\n⏱ Срок оплаты: 1 ч.\nЕсли не успеете — лот автоматически перейдёт следующему биддеру.\n\nПосле оплаты деньги уйдут в эскроу. Продавец отправит билет, вы получите уведомление и подтвердите получение — только после этого продавец получит деньги.	48	14	\N	2026-05-19 21:43:14.021169+07
50	2	auction_runner_up	🥈 Аукцион «Proxy test lot» завершён. Вы заняли 2-е место	Победитель — пользователь demo_carl, ставка $110.00. Если вышестоящие участники не оплатят свои выигрыши, лот может перейти к вам. Ожидаемое время до вашей очереди: 1 ч. Мы пришлём уведомление, как только это произойдёт.	47	\N	2026-05-20 19:53:12.290449+07	2026-05-19 21:25:44.044652+07
47	2	auction_runner_up	🥈 Аукцион «Proxy test lot» завершён. Вы заняли 2-е место	Победитель — пользователь demo_carl, ставка $110.00. Если вышестоящие участники не оплатят свои выигрыши, лот может перейти к вам. Ожидаемое время до вашей очереди: 1 ч. Мы пришлём уведомление, как только это произойдёт.	46	\N	2026-05-20 19:53:12.527325+07	2026-05-19 21:24:13.991718+07
90	25	auction_won	🏆 Вы победили в аукционе «Щелкунчик»!	Поздравляем! Ваша ставка $122216.67 стала выигрышной.\n\nЧто делать сейчас:\n1. Перейдите в раздел «Профиль» (правый верхний угол)\n2. Найдите блок «Эскроу и платежи»\n3. Нажмите «Оплатить картой» или «Списать с баланса»\n\n⏱ Срок оплаты: 10 мин.\nЕсли не успеете — лот автоматически перейдёт следующему биддеру.\n\nПосле оплаты деньги уйдут в эскроу. Продавец отправит билет, вы получите уведомление и подтвердите получение — только после этого продавец получит деньги.	50	21	2026-05-20 20:11:36.438658+07	2026-05-20 20:09:56.913703+07
56	3	payment_expired	⏱️ Срок оплаты по лоту «Proxy test lot» истёк	Вы не оплатили свою ставку $110.00 в отведённое время. Лот передан следующему участнику.	45	11	\N	2026-05-20 11:15:51.515857+07
59	3	payment_expired	⏱️ Срок оплаты по лоту «Proxy test lot» истёк	Вы не оплатили свою ставку $110.00 в отведённое время. Лот передан следующему участнику.	46	12	\N	2026-05-20 11:15:51.548876+07
62	3	payment_expired	⏱️ Срок оплаты по лоту «Proxy test lot» истёк	Вы не оплатили свою ставку $110.00 в отведённое время. Лот передан следующему участнику.	47	13	\N	2026-05-20 11:15:51.567855+07
65	3	payment_expired	⏱️ Срок оплаты по лоту «Proxy test lot» истёк	Вы не оплатили свою ставку $210.00 в отведённое время. Лот передан следующему участнику.	48	14	\N	2026-05-20 11:15:51.584101+07
33	1	cascade_advanced	Каскад по лоту «Калькулятор»: пользователь truealex2 не оплатил	Лот перешёл к truealex2. Если он также не оплатит, возможно лот достанется вам. Ожидаемое время до вашей очереди: до окончания текущего периода оплаты.	49	\N	2026-05-20 11:57:10.472647+07	2026-05-19 21:11:14.312049+07
38	1	cascade_advanced	Каскад по лоту «Калькулятор»: пользователь truealex2 не оплатил	Лот перешёл к truealex2. Если он также не оплатит, возможно лот достанется вам. Ожидаемое время до вашей очереди: до окончания текущего периода оплаты.	49	\N	2026-05-20 11:57:10.472647+07	2026-05-19 21:16:44.206458+07
48	1	lot_sold_pending_payment	🎉 Ваш лот «Proxy test lot» продан	Победитель: demo_carl. Сумма выигрыша: $110.00. Покупатель должен оплатить в течение 1 ч. Мы сообщим, как только оплата поступит.	46	\N	2026-05-20 11:57:10.472647+07	2026-05-19 21:24:13.99571+07
66	2	cascade_advanced	🏆 Лот «Proxy test lot» переходит к вам!	Победитель не оплатил вовремя, и по правилам каскада лот теперь ваш.\n\nСумма к оплате: $200.00\n\nЧто делать:\n1. Откройте «Профиль» в правом верхнем углу\n2. В блоке «Эскроу и платежи» нажмите «Оплатить картой» или «Списать с баланса»\n\n⏱ У вас есть 1 ч на оплату. Если не успеете — лот достанется следующему биддеру.\n\nПосле оплаты деньги уйдут в эскроу до подтверждения получения билета.	48	18	2026-05-20 19:53:02.517188+07	2026-05-20 11:15:51.590342+07
63	2	cascade_advanced	🏆 Лот «Proxy test lot» переходит к вам!	Победитель не оплатил вовремя, и по правилам каскада лот теперь ваш.\n\nСумма к оплате: $100.00\n\nЧто делать:\n1. Откройте «Профиль» в правом верхнем углу\n2. В блоке «Эскроу и платежи» нажмите «Оплатить картой» или «Списать с баланса»\n\n⏱ У вас есть 1 ч на оплату. Если не успеете — лот достанется следующему биддеру.\n\nПосле оплаты деньги уйдут в эскроу до подтверждения получения билета.	47	17	2026-05-20 19:53:02.756983+07	2026-05-20 11:15:51.574735+07
60	2	cascade_advanced	🏆 Лот «Proxy test lot» переходит к вам!	Победитель не оплатил вовремя, и по правилам каскада лот теперь ваш.\n\nСумма к оплате: $100.00\n\nЧто делать:\n1. Откройте «Профиль» в правом верхнем углу\n2. В блоке «Эскроу и платежи» нажмите «Оплатить картой» или «Списать с баланса»\n\n⏱ У вас есть 1 ч на оплату. Если не успеете — лот достанется следующему биддеру.\n\nПосле оплаты деньги уйдут в эскроу до подтверждения получения билета.	46	16	2026-05-20 19:53:03.00506+07	2026-05-20 11:15:51.557368+07
57	2	cascade_advanced	🏆 Лот «Proxy test lot» переходит к вам!	Победитель не оплатил вовремя, и по правилам каскада лот теперь ваш.\n\nСумма к оплате: $100.00\n\nЧто делать:\n1. Откройте «Профиль» в правом верхнем углу\n2. В блоке «Эскроу и платежи» нажмите «Оплатить картой» или «Списать с баланса»\n\n⏱ У вас есть 1 ч на оплату. Если не успеете — лот достанется следующему биддеру.\n\nПосле оплаты деньги уйдут в эскроу до подтверждения получения билета.	45	15	2026-05-20 19:53:03.550608+07	2026-05-20 11:15:51.536603+07
54	2	auction_runner_up	🥈 Аукцион «Proxy test lot» завершён. Вы заняли 2-е место	Победитель — пользователь demo_carl, ставка $210.00. Если вышестоящие участники не оплатят свои выигрыши, лот может перейти к вам. Ожидаемое время до вашей очереди: 1 ч. Мы пришлём уведомление, как только это произойдёт.	48	\N	2026-05-20 19:53:03.837304+07	2026-05-19 21:43:14.041944+07
51	1	lot_sold_pending_payment	🎉 Ваш лот «Proxy test lot» продан	Победитель: demo_carl. Сумма выигрыша: $110.00. Покупатель должен оплатить в течение 1 ч. Мы сообщим, как только оплата поступит.	47	\N	2026-05-20 11:57:10.472647+07	2026-05-19 21:25:44.050149+07
55	1	lot_sold_pending_payment	🎉 Ваш лот «Proxy test lot» продан	Победитель: demo_carl. Сумма выигрыша: $210.00. Покупатель должен оплатить в течение 1 ч. Мы сообщим, как только оплата поступит.	48	\N	2026-05-20 11:57:10.472647+07	2026-05-19 21:43:14.046542+07
58	1	cascade_advanced	Лот «Proxy test lot»: новый победитель	Предыдущий победитель не оплатил. Теперь лот за demo_boris по ставке $100.00.	45	\N	2026-05-20 11:57:10.472647+07	2026-05-20 11:15:51.541237+07
61	1	cascade_advanced	Лот «Proxy test lot»: новый победитель	Предыдущий победитель не оплатил. Теперь лот за demo_boris по ставке $100.00.	46	\N	2026-05-20 11:57:10.472647+07	2026-05-20 11:15:51.561468+07
64	1	cascade_advanced	Лот «Proxy test lot»: новый победитель	Предыдущий победитель не оплатил. Теперь лот за demo_boris по ставке $100.00.	47	\N	2026-05-20 11:57:10.472647+07	2026-05-20 11:15:51.577694+07
67	1	cascade_advanced	Лот «Proxy test lot»: новый победитель	Предыдущий победитель не оплатил. Теперь лот за demo_boris по ставке $200.00.	48	\N	2026-05-20 11:57:10.472647+07	2026-05-20 11:15:51.593218+07
70	3	lot_cascade_closed	Аукцион «Proxy test lot» окончательно закрыт	Никто из участников каскада не оплатил выигрыш. Лот будет перевыставлен через 24 часа — следите за уведомлениями.	45	\N	\N	2026-05-20 18:45:57.01278+07
93	25	payment_paid	✅ Оплата принята по лоту «Щелкунчик»	Сумма $122216.67 отправлена в эскроу. Ожидайте, пока продавец отправит билет, затем подтвердите получение в профиле.	50	21	2026-05-20 20:13:26.641064+07	2026-05-20 20:12:23.536576+07
73	3	lot_cascade_closed	Аукцион «Proxy test lot» окончательно закрыт	Никто из участников каскада не оплатил выигрыш. Лот будет перевыставлен через 24 часа — следите за уведомлениями.	46	\N	\N	2026-05-20 18:45:57.034229+07
76	3	lot_cascade_closed	Аукцион «Proxy test lot» окончательно закрыт	Никто из участников каскада не оплатил выигрыш. Лот будет перевыставлен через 24 часа — следите за уведомлениями.	47	\N	\N	2026-05-20 18:45:57.053899+07
78	3	cascade_advanced	🏆 Лот «Proxy test lot» переходит к вам!	Победитель не оплатил вовремя, и по правилам каскада лот теперь ваш.\n\nСумма к оплате: $190.00\n\nЧто делать:\n1. Откройте «Профиль» в правом верхнем углу\n2. В блоке «Эскроу и платежи» нажмите «Оплатить картой» или «Списать с баланса»\n\n⏱ У вас есть 1 ч на оплату. Если не успеете — лот достанется следующему биддеру.\n\nПосле оплаты деньги уйдут в эскроу до подтверждения получения билета.	48	19	\N	2026-05-20 18:45:57.073049+07
69	1	lot_relisted	Лот «Proxy test lot» снят с аукциона	Никто из участников не оплатил выигрыш. Лот будет перевыставлен через 24 часа.	45	\N	2026-05-20 18:47:21.540304+07	2026-05-20 18:45:57.006892+07
72	1	lot_relisted	Лот «Proxy test lot» снят с аукциона	Никто из участников не оплатил выигрыш. Лот будет перевыставлен через 24 часа.	46	\N	2026-05-20 18:47:21.540304+07	2026-05-20 18:45:57.0294+07
75	1	lot_relisted	Лот «Proxy test lot» снят с аукциона	Никто из участников не оплатил выигрыш. Лот будет перевыставлен через 24 часа.	47	\N	2026-05-20 18:47:21.540304+07	2026-05-20 18:45:57.049834+07
79	1	cascade_advanced	Лот «Proxy test lot»: новый победитель	Предыдущий победитель не оплатил. Теперь лот за demo_carl по ставке $190.00.	48	\N	2026-05-20 18:47:21.540304+07	2026-05-20 18:45:57.077211+07
80	3	payment_expired	⏱️ Срок оплаты по лоту «Proxy test lot» истёк	Вы не оплатили свою ставку $190.00 в отведённое время. Лот передан следующему участнику.	48	19	\N	2026-05-20 19:46:26.887226+07
82	1	cascade_advanced	Лот «Proxy test lot»: новый победитель	Предыдущий победитель не оплатил. Теперь лот за demo_boris по ставке $180.00.	48	\N	\N	2026-05-20 19:46:26.900271+07
77	2	payment_expired	⏱️ Срок оплаты по лоту «Proxy test lot» истёк	Вы не оплатили свою ставку $200.00 в отведённое время. Лот передан следующему участнику.	48	18	2026-05-20 19:53:01.477557+07	2026-05-20 18:45:57.062567+07
74	2	payment_expired	⏱️ Срок оплаты по лоту «Proxy test lot» истёк	Вы не оплатили свою ставку $100.00 в отведённое время. Лот передан следующему участнику.	47	17	2026-05-20 19:53:01.789282+07	2026-05-20 18:45:57.042564+07
71	2	payment_expired	⏱️ Срок оплаты по лоту «Proxy test lot» истёк	Вы не оплатили свою ставку $100.00 в отведённое время. Лот передан следующему участнику.	46	16	2026-05-20 19:53:02.02341+07	2026-05-20 18:45:57.02187+07
68	2	payment_expired	⏱️ Срок оплаты по лоту «Proxy test lot» истёк	Вы не оплатили свою ставку $100.00 в отведённое время. Лот передан следующему участнику.	45	15	2026-05-20 19:53:02.270789+07	2026-05-20 18:45:56.982857+07
81	2	cascade_advanced	🏆 Лот «Proxy test lot» переходит к вам!	Победитель не оплатил вовремя, и по правилам каскада лот теперь ваш.\n\nСумма к оплате: $180.00\n\nЧто делать:\n1. Откройте «Профиль» в правом верхнем углу\n2. В блоке «Эскроу и платежи» нажмите «Оплатить картой» или «Списать с баланса»\n\n⏱ У вас есть 1 ч на оплату. Если не успеете — лот достанется следующему биддеру.\n\nПосле оплаты деньги уйдут в эскроу до подтверждения получения билета.	48	20	2026-05-20 19:53:01.017219+07	2026-05-20 19:46:26.896411+07
95	25	ticket_delivered	🎫 Продавец отправил билет по лоту «Щелкунчик»	Билет: https://chat.deepseek.com/a/chat/s/eed18367-4712-4c23-bace-5a1fc856c982\n\nПроверьте билет, подтвердите получение в профиле — после этого деньги поступят продавцу.	50	21	2026-05-20 20:13:14.633121+07	2026-05-20 20:13:03.230482+07
96	8	seller_payment_received	💰 Сделка по лоту «Щелкунчик» закрыта	Покупатель Pro777 подтвердил получение. На ваш баланс зачислено $109995.00 (за вычетом комиссии 10%).	50	21	2026-05-20 20:13:23.272227+07	2026-05-20 20:13:14.543166+07
94	8	buyer_paid	💸 Покупатель оплатил лот «Щелкунчик»	Покупатель Pro777 оплатил $122216.67.\n\nДеньги в эскроу — пока не у вас. Что делать:\n1. Откройте «Продать → Мои аукционы» (правый верхний угол)\n2. Найдите блок «🔒 Эскроу»\n3. Введите код билета и нажмите «Билет отправлен»\n\nПосле того как покупатель подтвердит получение — деньги поступят на ваш баланс.	50	21	2026-05-20 20:13:23.765259+07	2026-05-20 20:12:23.737202+07
97	25	buyer_confirmed	✅ Получение подтверждено по лоту «Щелкунчик»	Спасибо! Сделка успешно закрыта. Не забудьте оставить отзыв о продавце в его профиле.	50	21	2026-05-20 20:13:26.004902+07	2026-05-20 20:13:14.548155+07
99	3	cascade_advanced	🏆 Лот «Proxy test lot» переходит к вам!	Победитель не оплатил вовремя, и по правилам каскада лот теперь ваш.\n\nСумма к оплате: $170.00\n\nЧто делать:\n1. Откройте «Профиль» в правом верхнем углу\n2. В блоке «Эскроу и платежи» нажмите «Оплатить картой» или «Списать с баланса»\n\n⏱ У вас есть 1 ч на оплату. Если не успеете — лот достанется следующему биддеру.\n\nПосле оплаты деньги уйдут в эскроу до подтверждения получения билета.	48	22	\N	2026-05-20 20:46:26.956176+07
100	1	cascade_advanced	Лот «Proxy test lot»: новый победитель	Предыдущий победитель не оплатил. Теперь лот за demo_carl по ставке $170.00.	48	\N	\N	2026-05-20 20:46:26.961155+07
101	24	auction_won	🏆 Вы победили в аукционе «После заката»!	Поздравляем! Ваша ставка $850.00 стала выигрышной.\n\nЧто делать сейчас:\n1. Перейдите в раздел «Профиль» (правый верхний угол)\n2. Найдите блок «Эскроу и платежи»\n3. Нажмите «Оплатить картой» или «Списать с баланса»\n\n⏱ Срок оплаты: 24 ч.\nЕсли не успеете — лот автоматически перейдёт следующему биддеру.\n\nПосле оплаты деньги уйдут в эскроу. Продавец отправит билет, вы получите уведомление и подтвердите получение — только после этого продавец получит деньги.	31	23	\N	2026-05-20 21:08:56.907931+07
103	2	lot_sold_pending_payment	🎉 Ваш лот «После заката» продан	Победитель: Prodavec_Alex. Сумма выигрыша: $850.00. Покупатель должен оплатить в течение 24 ч. Мы сообщим, как только оплата поступит.	31	\N	\N	2026-05-20 21:08:56.912302+07
104	1	cascade_advanced	🏆 Лот «Полуночный оркестр» переходит к вам!	Победитель не оплатил вовремя, и по правилам каскада лот теперь ваш.\n\nСумма к оплате: $2360.00\n\nЧто делать:\n1. Откройте «Профиль» в правом верхнем углу\n2. В блоке «Эскроу и платежи» нажмите «Оплатить картой» или «Списать с баланса»\n\n⏱ У вас есть 24 ч на оплату. Если не успеете — лот достанется следующему биддеру.\n\nПосле оплаты деньги уйдут в эскроу до подтверждения получения билета.	30	24	\N	2026-05-20 21:08:56.93268+07
105	2	cascade_advanced	Лот «Полуночный оркестр»: новый победитель	Предыдущий победитель не оплатил. Теперь лот за demo_anna по ставке $2360.00.	30	\N	\N	2026-05-20 21:08:56.93721+07
\.


--
-- Data for Name: payment_methods; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.payment_methods (id, user_id, provider, external_id, brand, last4, exp_month, exp_year, is_default, created_at) FROM stdin;
1	3	stripe	tok_local_stripe_7027	mc	7027	6	2030	t	2026-05-15 22:13:34.657292+07
2	9	yookassa	tok_local_yookassa_1119	mc	1119	12	2030	t	2026-05-18 10:43:39.454244+07
3	24	yookassa	tok_local_yookassa_1119	mc	1119	12	2030	t	2026-05-18 19:17:00.395958+07
4	13	yookassa	tok_local_yookassa_1119	mc	1119	12	2031	f	2026-05-19 19:25:02.426775+07
5	13	yookassa	tok_local_yookassa_1119	mc	1119	12	2028	t	2026-05-19 19:25:26.119414+07
\.


--
-- Data for Name: payments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.payments (id, bid_id, user_id, amount_usd, currency, provider, status, payment_url, expires_at, created_at, held_in_escrow, released_to_seller, ticket_delivered, ticket_code, buyer_confirmed, dispute_open) FROM stdin;
2	23	9	660.00	RUB	yookassa	paid	\N	2026-05-19 10:32:51.992403+07	2026-05-18 10:32:51.992607+07	t	f	f	\N	f	f
1	22	1	4358.98	AMD	idram	expired	\N	2026-05-18 17:49:45.940958+07	2026-05-17 17:49:45.941223+07	f	f	f	\N	f	f
3	21	1	549.45	AMD	idram	expired	\N	2026-05-19 18:35:41.77696+07	2026-05-18 18:35:41.777122+07	f	f	f	\N	f	f
5	20	1	499.45	AMD	idram	paid	\N	2026-05-20 18:58:45.555414+07	2026-05-19 18:58:45.555558+07	t	f	f	\N	f	f
6	374	1	255755.36	AMD	idram	expired	\N	2026-05-19 21:05:43.953366+07	2026-05-19 21:00:43.953511+07	f	f	f	\N	f	f
7	376	9	255757.58	RUB	yookassa	expired	\N	2026-05-19 21:10:44.000564+07	2026-05-19 21:05:44.000696+07	f	f	f	\N	f	f
9	375	9	255755.36	RUB	yookassa	expired	\N	2026-05-19 21:16:14.190896+07	2026-05-19 21:11:14.191148+07	f	f	f	\N	f	f
10	372	9	255753.14	RUB	yookassa	paid	\N	2026-05-19 21:21:43.980331+07	2026-05-19 21:16:43.980484+07	t	f	t	лови ссылку на него!	f	f
11	40	3	110.00	USD	stripe	expired	\N	2026-05-19 22:18:43.972606+07	2026-05-19 21:18:43.972849+07	f	f	f	\N	f	f
12	42	3	110.00	USD	stripe	expired	\N	2026-05-19 22:24:13.969548+07	2026-05-19 21:24:13.969791+07	f	f	f	\N	f	f
13	44	3	110.00	USD	stripe	expired	\N	2026-05-19 22:25:43.989532+07	2026-05-19 21:25:43.989774+07	f	f	f	\N	f	f
14	56	3	210.00	USD	stripe	expired	\N	2026-05-19 22:43:13.984705+07	2026-05-19 21:43:13.984871+07	f	f	f	\N	f	f
15	39	2	100.00	RUB	yookassa	expired	\N	2026-05-20 12:15:51.529129+07	2026-05-20 11:15:51.5294+07	f	f	f	\N	f	f
16	41	2	100.00	RUB	yookassa	expired	\N	2026-05-20 12:15:51.551561+07	2026-05-20 11:15:51.551822+07	f	f	f	\N	f	f
17	43	2	100.00	RUB	yookassa	expired	\N	2026-05-20 12:15:51.570191+07	2026-05-20 11:15:51.57042+07	f	f	f	\N	f	f
18	55	2	200.00	RUB	yookassa	expired	\N	2026-05-20 12:15:51.5863+07	2026-05-20 11:15:51.58652+07	f	f	f	\N	f	f
19	54	3	190.00	USD	stripe	expired	\N	2026-05-20 19:45:57.065512+07	2026-05-20 18:45:57.065682+07	f	f	f	\N	f	f
21	385	25	122216.67	RUB	yookassa	paid	\N	2026-05-20 20:19:56.877569+07	2026-05-20 20:09:56.877732+07	t	t	t	https://chat.deepseek.com/a/chat/s/eed18367-4712-4c23-bace-5a1fc856c982	t	f
20	53	2	180.00	RUB	yookassa	expired	\N	2026-05-20 20:46:26.890279+07	2026-05-20 19:46:26.890494+07	f	f	f	\N	f	f
22	52	3	170.00	USD	stripe	pending	\N	2026-05-20 21:46:26.948933+07	2026-05-20 20:46:26.949181+07	f	f	f	\N	f	f
23	36	24	850.00	RUB	yookassa	pending	\N	2026-05-21 21:08:56.887045+07	2026-05-20 21:08:56.887224+07	f	f	f	\N	f	f
8	38	13	2490.00	RUB	yookassa	expired	\N	2026-05-20 21:08:43.976577+07	2026-05-19 21:08:43.976766+07	f	f	f	\N	f	f
24	37	1	2360.00	AMD	idram	pending	\N	2026-05-21 21:08:56.927018+07	2026-05-20 21:08:56.92715+07	f	f	f	\N	f	f
\.


--
-- Data for Name: proxy_bids; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.proxy_bids (id, lot_id, user_id, max_amount_usd, share_url, active, created_at) FROM stdin;
1	33	1	304200.00	https://vk.com/share.php?url=http%3A%2F%2F127.0.0.1%3A5000%2Flot%2F33	t	2026-05-17 11:48:45.603267+07
19	35	1	15578600.00	https://vk.com/feed	t	2026-05-17 17:41:38.58077+07
24	43	23	101010.00	https://t.me/bigstage123/2	t	2026-05-18 20:58:02.085349+07
29	30	1	18000000.00	https://t.me/bigstage123/4	t	2026-05-19 19:22:58.866884+07
30	45	2	200.00	https://vk.com/wall1_1	t	2026-05-19 20:18:29.840523+07
31	45	3	300.00	https://vk.com/wall2_2	t	2026-05-19 20:18:32.872609+07
32	46	2	200.00	https://vk.com/wall1_1	t	2026-05-19 20:23:55.588137+07
33	46	3	300.00	https://vk.com/wall2_2	t	2026-05-19 20:23:58.601487+07
34	47	2	200.00	https://vk.com/wall1_1	t	2026-05-19 20:25:27.343476+07
35	47	3	300.00	https://vk.com/wall2_2	t	2026-05-19 20:25:30.353878+07
36	48	2	200.00	https://vk.com/wall1_1	t	2026-05-19 20:43:00.735501+07
37	48	3	300.00	https://vk.com/wall2_2	t	2026-05-19 20:43:03.765257+07
38	49	1	2000000.00	https://t.me/bigstage123/5	t	2026-05-19 20:50:43.704879+07
39	49	9	9000000.00	https://t.me/bigstage123/5	t	2026-05-19 20:53:14.292135+07
40	50	24	100000.00	https://t.me/bigstage123/6	f	2026-05-20 20:00:35.24051+07
28	31	13	100000.00	https://t.me/bigstage123/2	f	2026-05-18 21:50:45.418363+07
\.


--
-- Data for Name: seller_reviews; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.seller_reviews (id, seller_id, buyer_id, lot_id, payment_id, rating, comment, created_at) FROM stdin;
\.


--
-- Data for Name: translation_cache; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.translation_cache (id, source_hash, source_lang, target_lang, source_text, translated_text, created_at) FROM stdin;
1	434e31a72ec4eab722fbae7b81e6bb96cc758566	ru	hy	Швабра	Հատակմաքրիչ	2026-05-17 17:33:25.250474+07
2	40164731a85941005021aee9a6a0b736a4128bf2	ru	hy	Бархатный бис	Թավշյա ծածկոց	2026-05-17 17:33:31.24225+07
3	16c1de3c489ed88af5755a7c47b69e2bdb83e083	ru	hy	Сона Рэй · Площадь Республики	Սոնա Ռեյ · Հանրապետության հրապարակ	2026-05-17 17:33:32.563779+07
4	35cf1040ea23a8d3f4a7ac8c51ff052729709c37	ru	hy	Алый эхо-сейшн	Scarlet Echo - ի սեսիա	2026-05-17 17:33:33.898299+07
5	5907ec5ac668f16f8fcc628d6aea94c57a5b09cf	ru	hy	Луна Вале · Ереванская Арена	Լունա Վալե · Երևան Արենա	2026-05-17 17:33:35.298943+07
6	52b17bdf59fb80167d55382156657eec40498f5a	ru	hy	Полуночный оркестр	Կեսգիշերային նվագախումբ	2026-05-17 17:33:36.793794+07
7	1c40968c0def213c345b552b158f61a34d6ab8fe	ru	hy	Арам Коллектив · Оперный зал	Արամ կոլեկտիվ · Օպերայի դահլիճ	2026-05-17 17:33:38.174576+07
8	ac489bd5dce45599d21e04c9651f5aa539f6501b	ru	hy	После заката	Մայրամուտից հետո	2026-05-17 17:33:39.827928+07
9	53d4c44772dfcae4b75a5dae48f5fcdd4bbf6bd7	ru	hy	Нарек Уэйвз · Open Air Stage	Նարեկացի ալիքներ · Բացօթյա բեմ	2026-05-17 17:33:41.106057+07
10	c0c9c7bcc68058f08c2a0e0ca3e7eaf3cb8f16cf	ru	hy	Северное сияние LIVE	Հյուսիսային լույսերը ՈՒՂԻՂ ԵԹԵՐՈՒՄ	2026-05-17 17:33:42.498584+07
11	e8fbb6f51abf62429a41ba79cfee74ce7a260c91	ru	hy	Маро Неон · Каскадная Терраса	Մարո Նեոն · Կասկադ տեռաս	2026-05-17 17:33:43.786515+07
12	0651cd069ccd890d26588af6281572878ad3cd92	ru	hy	Гало-секшн	Հալոյի նստաշրջան	2026-05-17 17:33:45.190269+07
13	1d566759cb2ff421154e1dd1c6cf53be5a0e0e0d	ru	hy	DJ Артур · Клуб Wave	DJ Arthur · Wave Club	2026-05-17 17:33:46.410685+07
14	434e31a72ec4eab722fbae7b81e6bb96cc758566	ru	en	Швабра	Mop	2026-05-17 17:34:47.11531+07
15	6a741f14e0c2b83349f209313bfd00bdf16a768d	ru	hy	ШВАБРА	ՀԱՏԱԿՄԱՔՐԻՉ	2026-05-17 17:34:47.375893+07
16	6a741f14e0c2b83349f209313bfd00bdf16a768d	ru	en	ШВАБРА	MOP.	2026-05-17 17:34:48.279375+07
17	40164731a85941005021aee9a6a0b736a4128bf2	ru	en	Бархатный бис	Velvet encore	2026-05-17 17:34:52.899575+07
18	16c1de3c489ed88af5755a7c47b69e2bdb83e083	ru	en	Сона Рэй · Площадь Республики	Sona Ray · Republic Square	2026-05-17 17:34:54.206972+07
19	35cf1040ea23a8d3f4a7ac8c51ff052729709c37	ru	en	Алый эхо-сейшн	Scarlet Echo Session	2026-05-17 17:34:54.919894+07
20	5907ec5ac668f16f8fcc628d6aea94c57a5b09cf	ru	en	Луна Вале · Ереванская Арена	Luna Vale · Yerevan Arena	2026-05-17 17:34:55.436059+07
21	52b17bdf59fb80167d55382156657eec40498f5a	ru	en	Полуночный оркестр	Midnight Orchestra	2026-05-17 17:34:56.22501+07
22	1c40968c0def213c345b552b158f61a34d6ab8fe	ru	en	Арам Коллектив · Оперный зал	Aram Collective · Opera Hall	2026-05-17 17:34:56.696319+07
23	ac489bd5dce45599d21e04c9651f5aa539f6501b	ru	en	После заката	In the Evening	2026-05-17 17:34:57.702611+07
24	53d4c44772dfcae4b75a5dae48f5fcdd4bbf6bd7	ru	en	Нарек Уэйвз · Open Air Stage	Narek Waves · Open Air Stage	2026-05-17 17:34:58.020024+07
25	c0c9c7bcc68058f08c2a0e0ca3e7eaf3cb8f16cf	ru	en	Северное сияние LIVE	NORTHERN LIGHTS	2026-05-17 17:34:58.643376+07
26	e8fbb6f51abf62429a41ba79cfee74ce7a260c91	ru	en	Маро Неон · Каскадная Терраса	Maro Neon · Cascade Terrace	2026-05-17 17:34:58.963254+07
27	0651cd069ccd890d26588af6281572878ad3cd92	ru	en	Гало-секшн	Halo Session	2026-05-17 17:34:59.382884+07
28	1d566759cb2ff421154e1dd1c6cf53be5a0e0e0d	ru	en	DJ Артур · Клуб Wave	DJ Arthur · Wave Club	2026-05-17 17:34:59.539584+07
29	2805ae8e7e12f182135f92fb90843bb1080d3be8	ru	en	Привет	Hi there	2026-05-17 18:54:09.965222+07
30	69009242f115cade35fe6746647f02a1001feb38	ru	hy	Картинка	Նկար	2026-05-18 10:44:26.900431+07
31	66b2bdb521bb7bdbe118ae596a6c9d531bbbceb6	ru	hy	Обычная Швабра	Սովորական շվաբր	2026-05-18 10:44:28.640227+07
32	69009242f115cade35fe6746647f02a1001feb38	ru	en	Картинка	Picture	2026-05-18 10:44:32.91388+07
33	66b2bdb521bb7bdbe118ae596a6c9d531bbbceb6	ru	en	Обычная Швабра	Ordinary Mop	2026-05-18 10:44:34.472476+07
34	2f5e733d357f3a5dc085978bc175b54e1844298d	ru	en	укбю.	ukby.	2026-05-18 21:33:28.442174+07
35	2f5e733d357f3a5dc085978bc175b54e1844298d	ru	hy	укбю.	ukby.	2026-05-18 21:33:28.694361+07
36	0808bcff3019c599adbab60c3cdba3a9a7213980	ru	hy	упаекбюж.й	փաթեթավորման բյուրո	2026-05-18 21:33:31.235752+07
37	0808bcff3019c599adbab60c3cdba3a9a7213980	ru	en	упаекбюж.й	packing bureau	2026-05-18 21:33:31.334163+07
38	78b6b8ec9faf5393520c2a4b5289364b677706f6	ru	en	цупаекрьдлорпкуцй	tsupaekrdlorpkutsiy	2026-05-18 21:33:32.568011+07
39	78b6b8ec9faf5393520c2a4b5289364b677706f6	ru	hy	цупаекрьдлорпкуцй	tsupaekrdlorpkutsiy	2026-05-18 21:33:32.828614+07
40	c58ea3e13b49f6877ca43d16f57f6bc405c7cc0f	ru	en	ввввввввввввввввввввв	vvvvvvvvvvvvvvv	2026-05-18 21:33:33.415823+07
41	9277186e009047b88cae47d1724c85f90bf32fcd	ru	en	вввввввввввв	vvvvvvvvv	2026-05-18 21:33:34.696121+07
42	c58ea3e13b49f6877ca43d16f57f6bc405c7cc0f	ru	hy	ввввввввввввввввввввв	vvvvvvvvvvvvv	2026-05-19 19:18:56.062838+07
43	9277186e009047b88cae47d1724c85f90bf32fcd	ru	hy	вввввввввввв	vvvvvvvvv	2026-05-19 19:18:57.758975+07
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, username, email, country, vk_id, vk_token, created_at, balance_usd, password_hash) FROM stdin;
7	test_demo	test@demo.com	RU	\N	\N	2026-05-15 22:22:05.571778+07	0.00	pbkdf2$200000$2fa18b8773ff9f09dc88396e69491f02$820edee8b2c704d29b9e2d54708c8dd8ca2b98a8689b06aaeb0ba5a8ab374603
9	truealex2	truealex12011@gmail.com	RU	\N	\N	2026-05-15 22:25:48.129226+07	100505.00	pbkdf2$200000$a8916f5a20ac77a92552deb089cb5733$13535fd38a927b052b92f490a6be163c22ff045b48c9c23ac1f66c578b45c7c0
2	demo_boris	boris@demo.com	RU	1002	\N	2026-05-15 21:33:47.870026+07	20000.00	\N
3	demo_carl	carl@demo.com	OTHER	1003	\N	2026-05-15 21:33:47.870026+07	20300.00	\N
24	Prodavec_Alex	truealex2011231@gmail.com	RU	\N	\N	2026-05-18 19:11:31.315907+07	111203.89	pbkdf2$200000$55e49f69f4273c8e32e81e217cdbe349$c5725867dd6d270da9db1620d22d0f810a6437c9855ee74c776e619a8ba4377c
23	bidstage_support	support@bidstage.local	OTHER	-777000001	\N	2026-05-18 11:23:46.528185+07	112466.48	\N
1	demo_anna	anna@demo.com	AM	1001	\N	2026-05-15 21:33:47.870026+07	200497.05	\N
25	Pro777	alex123@mail.com	RU	\N	\N	2026-05-19 20:46:12.851449+07	0.55	pbkdf2$200000$ad6123d6944fb5e08dfd6aa7eb8ba8e1$eba712c8d5299686b992f649bcff4a787b447b984d3beecc6dd5d04a66c7f596
8	truealex	alexcursorr5@gmail.com	OTHER	\N	\N	2026-05-15 22:24:14.467678+07	366390.26	pbkdf2$200000$71531fa5bce0ccd546730dcc1588c6e4$bea70566b037b7f2a0d6f0a94e944e50818b61a6c4d022f00a930d283e318f76
13	functest_6142	\N	RU	\N	\N	2026-05-16 20:05:20.339298+07	24678.77	pbkdf2$200000$e1b5734fe66fc4ac827d81a2e8aa305d$617b290ede26d3b7fcf0cfb716e94a964623c0ac446bb20df8345285db948fb7
\.


--
-- Data for Name: watchlist; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.watchlist (id, user_id, lot_id, notify_outbid, notify_ending, created_at) FROM stdin;
2	1	33	t	t	2026-05-17 11:37:51.887333+07
3	9	33	t	t	2026-05-17 20:11:16.761023+07
4	9	36	t	t	2026-05-17 20:43:58.834157+07
5	24	40	t	t	2026-05-18 19:19:09.600725+07
6	23	43	t	t	2026-05-18 20:53:27.679498+07
\.


--
-- Name: balance_topups_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.balance_topups_id_seq', 50, true);


--
-- Name: bid_otps_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.bid_otps_id_seq', 22, true);


--
-- Name: bids_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.bids_id_seq', 385, true);


--
-- Name: lot_chats_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.lot_chats_id_seq', 110, true);


--
-- Name: lot_events_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.lot_events_id_seq', 741, true);


--
-- Name: lots_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.lots_id_seq', 64, true);


--
-- Name: notifications_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.notifications_id_seq', 105, true);


--
-- Name: payment_methods_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.payment_methods_id_seq', 5, true);


--
-- Name: payments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.payments_id_seq', 24, true);


--
-- Name: proxy_bids_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.proxy_bids_id_seq', 40, true);


--
-- Name: seller_reviews_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.seller_reviews_id_seq', 1, false);


--
-- Name: translation_cache_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.translation_cache_id_seq', 43, true);


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.users_id_seq', 25, true);


--
-- Name: watchlist_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.watchlist_id_seq', 10, true);


--
-- Name: balance_topups balance_topups_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.balance_topups
    ADD CONSTRAINT balance_topups_pkey PRIMARY KEY (id);


--
-- Name: bid_otps bid_otps_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bid_otps
    ADD CONSTRAINT bid_otps_pkey PRIMARY KEY (id);


--
-- Name: bids bids_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bids
    ADD CONSTRAINT bids_pkey PRIMARY KEY (id);


--
-- Name: lot_chats lot_chats_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lot_chats
    ADD CONSTRAINT lot_chats_pkey PRIMARY KEY (id);


--
-- Name: lot_events lot_events_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lot_events
    ADD CONSTRAINT lot_events_pkey PRIMARY KEY (id);


--
-- Name: lots lots_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lots
    ADD CONSTRAINT lots_pkey PRIMARY KEY (id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: payment_methods payment_methods_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payment_methods
    ADD CONSTRAINT payment_methods_pkey PRIMARY KEY (id);


--
-- Name: payments payments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_pkey PRIMARY KEY (id);


--
-- Name: proxy_bids proxy_bids_lot_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proxy_bids
    ADD CONSTRAINT proxy_bids_lot_id_user_id_key UNIQUE (lot_id, user_id);


--
-- Name: proxy_bids proxy_bids_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proxy_bids
    ADD CONSTRAINT proxy_bids_pkey PRIMARY KEY (id);


--
-- Name: seller_reviews seller_reviews_payment_id_buyer_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.seller_reviews
    ADD CONSTRAINT seller_reviews_payment_id_buyer_id_key UNIQUE (payment_id, buyer_id);


--
-- Name: seller_reviews seller_reviews_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.seller_reviews
    ADD CONSTRAINT seller_reviews_pkey PRIMARY KEY (id);


--
-- Name: translation_cache translation_cache_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.translation_cache
    ADD CONSTRAINT translation_cache_pkey PRIMARY KEY (id);


--
-- Name: translation_cache translation_cache_source_hash_source_lang_target_lang_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.translation_cache
    ADD CONSTRAINT translation_cache_source_hash_source_lang_target_lang_key UNIQUE (source_hash, source_lang, target_lang);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users users_vk_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_vk_id_key UNIQUE (vk_id);


--
-- Name: watchlist watchlist_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.watchlist
    ADD CONSTRAINT watchlist_pkey PRIMARY KEY (id);


--
-- Name: watchlist watchlist_user_id_lot_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.watchlist
    ADD CONSTRAINT watchlist_user_id_lot_id_key UNIQUE (user_id, lot_id);


--
-- Name: idx_bid_otps_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_bid_otps_user ON public.bid_otps USING btree (user_id, lot_id, consumed_at);


--
-- Name: idx_bids_lot_amount_desc; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_bids_lot_amount_desc ON public.bids USING btree (lot_id, amount_usd DESC);


--
-- Name: idx_bids_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_bids_user ON public.bids USING btree (user_id);


--
-- Name: idx_lot_chat_pair; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_lot_chat_pair ON public.lot_chats USING btree (lot_id, sender_id, recipient_id, created_at);


--
-- Name: idx_lot_chat_recipient; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_lot_chat_recipient ON public.lot_chats USING btree (recipient_id, read_at);


--
-- Name: idx_lot_events_lot; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_lot_events_lot ON public.lot_events USING btree (lot_id, created_at DESC);


--
-- Name: idx_lots_featured; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_lots_featured ON public.lots USING btree (featured) WHERE (featured = true);


--
-- Name: idx_lots_seller; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_lots_seller ON public.lots USING btree (seller_id);


--
-- Name: idx_lots_status_end_time; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_lots_status_end_time ON public.lots USING btree (status, end_time);


--
-- Name: idx_notifications_user_unread; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_notifications_user_unread ON public.notifications USING btree (user_id, read_at, created_at DESC);


--
-- Name: idx_payments_status_expires; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_payments_status_expires ON public.payments USING btree (status, expires_at);


--
-- Name: idx_pm_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_pm_user ON public.payment_methods USING btree (user_id, created_at DESC);


--
-- Name: idx_proxy_lot_active; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_proxy_lot_active ON public.proxy_bids USING btree (lot_id, active);


--
-- Name: idx_reviews_seller; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_reviews_seller ON public.seller_reviews USING btree (seller_id, created_at DESC);


--
-- Name: idx_topups_user_created; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_topups_user_created ON public.balance_topups USING btree (user_id, created_at DESC);


--
-- Name: idx_translation_lookup; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_translation_lookup ON public.translation_cache USING btree (source_hash, target_lang);


--
-- Name: idx_users_email_lower; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX idx_users_email_lower ON public.users USING btree (lower(email)) WHERE ((email IS NOT NULL) AND (email <> ''::text));


--
-- Name: idx_users_username_lower; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX idx_users_username_lower ON public.users USING btree (lower(username));


--
-- Name: idx_watchlist_lot; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_watchlist_lot ON public.watchlist USING btree (lot_id);


--
-- Name: balance_topups balance_topups_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.balance_topups
    ADD CONSTRAINT balance_topups_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: bid_otps bid_otps_lot_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bid_otps
    ADD CONSTRAINT bid_otps_lot_id_fkey FOREIGN KEY (lot_id) REFERENCES public.lots(id);


--
-- Name: bid_otps bid_otps_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bid_otps
    ADD CONSTRAINT bid_otps_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: bids bids_lot_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bids
    ADD CONSTRAINT bids_lot_id_fkey FOREIGN KEY (lot_id) REFERENCES public.lots(id) ON DELETE CASCADE;


--
-- Name: bids bids_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bids
    ADD CONSTRAINT bids_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: lot_chats lot_chats_lot_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lot_chats
    ADD CONSTRAINT lot_chats_lot_id_fkey FOREIGN KEY (lot_id) REFERENCES public.lots(id) ON DELETE CASCADE;


--
-- Name: lot_chats lot_chats_recipient_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lot_chats
    ADD CONSTRAINT lot_chats_recipient_id_fkey FOREIGN KEY (recipient_id) REFERENCES public.users(id);


--
-- Name: lot_chats lot_chats_sender_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lot_chats
    ADD CONSTRAINT lot_chats_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES public.users(id);


--
-- Name: lot_events lot_events_lot_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lot_events
    ADD CONSTRAINT lot_events_lot_id_fkey FOREIGN KEY (lot_id) REFERENCES public.lots(id) ON DELETE CASCADE;


--
-- Name: lots lots_seller_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lots
    ADD CONSTRAINT lots_seller_id_fkey FOREIGN KEY (seller_id) REFERENCES public.users(id);


--
-- Name: lots lots_winner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lots
    ADD CONSTRAINT lots_winner_id_fkey FOREIGN KEY (winner_id) REFERENCES public.users(id);


--
-- Name: notifications notifications_lot_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_lot_id_fkey FOREIGN KEY (lot_id) REFERENCES public.lots(id) ON DELETE SET NULL;


--
-- Name: notifications notifications_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: payment_methods payment_methods_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payment_methods
    ADD CONSTRAINT payment_methods_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: payments payments_bid_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_bid_id_fkey FOREIGN KEY (bid_id) REFERENCES public.bids(id);


--
-- Name: payments payments_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: proxy_bids proxy_bids_lot_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proxy_bids
    ADD CONSTRAINT proxy_bids_lot_id_fkey FOREIGN KEY (lot_id) REFERENCES public.lots(id) ON DELETE CASCADE;


--
-- Name: proxy_bids proxy_bids_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proxy_bids
    ADD CONSTRAINT proxy_bids_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: seller_reviews seller_reviews_buyer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.seller_reviews
    ADD CONSTRAINT seller_reviews_buyer_id_fkey FOREIGN KEY (buyer_id) REFERENCES public.users(id);


--
-- Name: seller_reviews seller_reviews_lot_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.seller_reviews
    ADD CONSTRAINT seller_reviews_lot_id_fkey FOREIGN KEY (lot_id) REFERENCES public.lots(id);


--
-- Name: seller_reviews seller_reviews_payment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.seller_reviews
    ADD CONSTRAINT seller_reviews_payment_id_fkey FOREIGN KEY (payment_id) REFERENCES public.payments(id);


--
-- Name: seller_reviews seller_reviews_seller_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.seller_reviews
    ADD CONSTRAINT seller_reviews_seller_id_fkey FOREIGN KEY (seller_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: watchlist watchlist_lot_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.watchlist
    ADD CONSTRAINT watchlist_lot_id_fkey FOREIGN KEY (lot_id) REFERENCES public.lots(id) ON DELETE CASCADE;


--
-- Name: watchlist watchlist_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.watchlist
    ADD CONSTRAINT watchlist_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict ejSEQ2zkfxr2dZ9HwZuWZVSJVNmnp6wapAAYUdKdGbLyfWpmRULhaMV7F2Pz1At

