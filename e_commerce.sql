--
-- PostgreSQL database dump
--

-- Dumped from database version 17.2
-- Dumped by pg_dump version 17.2

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

--
-- Name: e_commerce; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA e_commerce;


ALTER SCHEMA e_commerce OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: t_clients; Type: TABLE; Schema: e_commerce; Owner: postgres
--

CREATE TABLE e_commerce.t_clients (
    id_client integer NOT NULL,
    nom character varying(100),
    email character varying(100),
    telephone character varying(20)
);


ALTER TABLE e_commerce.t_clients OWNER TO postgres;

--
-- Name: t_clients_id_client_seq; Type: SEQUENCE; Schema: e_commerce; Owner: postgres
--

CREATE SEQUENCE e_commerce.t_clients_id_client_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE e_commerce.t_clients_id_client_seq OWNER TO postgres;

--
-- Name: t_clients_id_client_seq; Type: SEQUENCE OWNED BY; Schema: e_commerce; Owner: postgres
--

ALTER SEQUENCE e_commerce.t_clients_id_client_seq OWNED BY e_commerce.t_clients.id_client;


--
-- Name: t_command_produit; Type: TABLE; Schema: e_commerce; Owner: postgres
--

CREATE TABLE e_commerce.t_command_produit (
    id_produit integer,
    id_commande integer,
    quantite integer
);


ALTER TABLE e_commerce.t_command_produit OWNER TO postgres;

--
-- Name: t_commandes; Type: TABLE; Schema: e_commerce; Owner: postgres
--

CREATE TABLE e_commerce.t_commandes (
    id_commande integer NOT NULL,
    id_client integer,
    date_commande date,
    status character varying(60)
);


ALTER TABLE e_commerce.t_commandes OWNER TO postgres;

--
-- Name: t_commandes_id_commande_seq; Type: SEQUENCE; Schema: e_commerce; Owner: postgres
--

CREATE SEQUENCE e_commerce.t_commandes_id_commande_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE e_commerce.t_commandes_id_commande_seq OWNER TO postgres;

--
-- Name: t_commandes_id_commande_seq; Type: SEQUENCE OWNED BY; Schema: e_commerce; Owner: postgres
--

ALTER SEQUENCE e_commerce.t_commandes_id_commande_seq OWNED BY e_commerce.t_commandes.id_commande;


--
-- Name: t_paiements; Type: TABLE; Schema: e_commerce; Owner: postgres
--

CREATE TABLE e_commerce.t_paiements (
    id_paiement integer NOT NULL,
    id_commande integer,
    montant numeric,
    date_paiement date,
    mode_paiement character varying(50)
);


ALTER TABLE e_commerce.t_paiements OWNER TO postgres;

--
-- Name: t_paiements_id_paiement_seq; Type: SEQUENCE; Schema: e_commerce; Owner: postgres
--

CREATE SEQUENCE e_commerce.t_paiements_id_paiement_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE e_commerce.t_paiements_id_paiement_seq OWNER TO postgres;

--
-- Name: t_paiements_id_paiement_seq; Type: SEQUENCE OWNED BY; Schema: e_commerce; Owner: postgres
--

ALTER SEQUENCE e_commerce.t_paiements_id_paiement_seq OWNED BY e_commerce.t_paiements.id_paiement;


--
-- Name: t_produits; Type: TABLE; Schema: e_commerce; Owner: postgres
--

CREATE TABLE e_commerce.t_produits (
    id_produit integer NOT NULL,
    id_vendeur integer,
    nom character varying(100),
    prix numeric
);


ALTER TABLE e_commerce.t_produits OWNER TO postgres;

--
-- Name: t_produits_id_produit_seq; Type: SEQUENCE; Schema: e_commerce; Owner: postgres
--

CREATE SEQUENCE e_commerce.t_produits_id_produit_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE e_commerce.t_produits_id_produit_seq OWNER TO postgres;

--
-- Name: t_produits_id_produit_seq; Type: SEQUENCE OWNED BY; Schema: e_commerce; Owner: postgres
--

ALTER SEQUENCE e_commerce.t_produits_id_produit_seq OWNED BY e_commerce.t_produits.id_produit;


--
-- Name: t_vendeurs; Type: TABLE; Schema: e_commerce; Owner: postgres
--

CREATE TABLE e_commerce.t_vendeurs (
    id_vendeur integer NOT NULL,
    nom character varying(100),
    boutique character varying(100),
    telephone character varying(20)
);


ALTER TABLE e_commerce.t_vendeurs OWNER TO postgres;

--
-- Name: t_vendeurs_id_vendeur_seq; Type: SEQUENCE; Schema: e_commerce; Owner: postgres
--

CREATE SEQUENCE e_commerce.t_vendeurs_id_vendeur_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE e_commerce.t_vendeurs_id_vendeur_seq OWNER TO postgres;

--
-- Name: t_vendeurs_id_vendeur_seq; Type: SEQUENCE OWNED BY; Schema: e_commerce; Owner: postgres
--

ALTER SEQUENCE e_commerce.t_vendeurs_id_vendeur_seq OWNED BY e_commerce.t_vendeurs.id_vendeur;


--
-- Name: v_commandesencours; Type: VIEW; Schema: e_commerce; Owner: postgres
--

CREATE VIEW e_commerce.v_commandesencours AS
 SELECT id_commande,
    id_client,
    date_commande,
    status
   FROM e_commerce.t_commandes
  WHERE ((status)::text = ' '::text);


ALTER VIEW e_commerce.v_commandesencours OWNER TO postgres;

--
-- Name: t_commandes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.t_commandes (
    id_commande integer NOT NULL,
    id_client integer,
    date_commande date,
    status character varying(60)
);


ALTER TABLE public.t_commandes OWNER TO postgres;

--
-- Name: t_commandes_id_commande_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.t_commandes_id_commande_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.t_commandes_id_commande_seq OWNER TO postgres;

--
-- Name: t_commandes_id_commande_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.t_commandes_id_commande_seq OWNED BY public.t_commandes.id_commande;


--
-- Name: v_commandesencours; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_commandesencours AS
 SELECT id_commande,
    id_client,
    date_commande,
    status
   FROM public.t_commandes
  WHERE ((status)::text = 'Non payé'::text);


ALTER VIEW public.v_commandesencours OWNER TO postgres;

--
-- Name: t_clients id_client; Type: DEFAULT; Schema: e_commerce; Owner: postgres
--

ALTER TABLE ONLY e_commerce.t_clients ALTER COLUMN id_client SET DEFAULT nextval('e_commerce.t_clients_id_client_seq'::regclass);


--
-- Name: t_commandes id_commande; Type: DEFAULT; Schema: e_commerce; Owner: postgres
--

ALTER TABLE ONLY e_commerce.t_commandes ALTER COLUMN id_commande SET DEFAULT nextval('e_commerce.t_commandes_id_commande_seq'::regclass);


--
-- Name: t_paiements id_paiement; Type: DEFAULT; Schema: e_commerce; Owner: postgres
--

ALTER TABLE ONLY e_commerce.t_paiements ALTER COLUMN id_paiement SET DEFAULT nextval('e_commerce.t_paiements_id_paiement_seq'::regclass);


--
-- Name: t_produits id_produit; Type: DEFAULT; Schema: e_commerce; Owner: postgres
--

ALTER TABLE ONLY e_commerce.t_produits ALTER COLUMN id_produit SET DEFAULT nextval('e_commerce.t_produits_id_produit_seq'::regclass);


--
-- Name: t_vendeurs id_vendeur; Type: DEFAULT; Schema: e_commerce; Owner: postgres
--

ALTER TABLE ONLY e_commerce.t_vendeurs ALTER COLUMN id_vendeur SET DEFAULT nextval('e_commerce.t_vendeurs_id_vendeur_seq'::regclass);


--
-- Name: t_commandes id_commande; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.t_commandes ALTER COLUMN id_commande SET DEFAULT nextval('public.t_commandes_id_commande_seq'::regclass);


--
-- Data for Name: t_clients; Type: TABLE DATA; Schema: e_commerce; Owner: postgres
--

COPY e_commerce.t_clients (id_client, nom, email, telephone) FROM stdin;
1	Mahomy JEAN EUGENE	jeaneugenemahomy49@gmail.com	624593906
2	DIALLO BOUBAAR	boubacar@gmail.com	628756344
\.


--
-- Data for Name: t_command_produit; Type: TABLE DATA; Schema: e_commerce; Owner: postgres
--

COPY e_commerce.t_command_produit (id_produit, id_commande, quantite) FROM stdin;
6	2	200
4	1	502
\.


--
-- Data for Name: t_commandes; Type: TABLE DATA; Schema: e_commerce; Owner: postgres
--

COPY e_commerce.t_commandes (id_commande, id_client, date_commande, status) FROM stdin;
1	1	2026-01-26	payé
2	2	2026-01-26	Non payé
\.


--
-- Data for Name: t_paiements; Type: TABLE DATA; Schema: e_commerce; Owner: postgres
--

COPY e_commerce.t_paiements (id_paiement, id_commande, montant, date_paiement, mode_paiement) FROM stdin;
1	1	500000	2025-01-26	Espèce
2	2	0	2025-01-26	En cours
\.


--
-- Data for Name: t_produits; Type: TABLE DATA; Schema: e_commerce; Owner: postgres
--

COPY e_commerce.t_produits (id_produit, id_vendeur, nom, prix) FROM stdin;
4	3	PAIN	5000
5	3	HUILE	35000
6	4	PAGNE	20000
\.


--
-- Data for Name: t_vendeurs; Type: TABLE DATA; Schema: e_commerce; Owner: postgres
--

COPY e_commerce.t_vendeurs (id_vendeur, nom, boutique, telephone) FROM stdin;
3	Safiatou iallo	B-1	624000000
4	Gomy Hélène	B-2	6240000021
\.


--
-- Data for Name: t_commandes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.t_commandes (id_commande, id_client, date_commande, status) FROM stdin;
\.


--
-- Name: t_clients_id_client_seq; Type: SEQUENCE SET; Schema: e_commerce; Owner: postgres
--

SELECT pg_catalog.setval('e_commerce.t_clients_id_client_seq', 2, true);


--
-- Name: t_commandes_id_commande_seq; Type: SEQUENCE SET; Schema: e_commerce; Owner: postgres
--

SELECT pg_catalog.setval('e_commerce.t_commandes_id_commande_seq', 2, true);


--
-- Name: t_paiements_id_paiement_seq; Type: SEQUENCE SET; Schema: e_commerce; Owner: postgres
--

SELECT pg_catalog.setval('e_commerce.t_paiements_id_paiement_seq', 2, true);


--
-- Name: t_produits_id_produit_seq; Type: SEQUENCE SET; Schema: e_commerce; Owner: postgres
--

SELECT pg_catalog.setval('e_commerce.t_produits_id_produit_seq', 6, true);


--
-- Name: t_vendeurs_id_vendeur_seq; Type: SEQUENCE SET; Schema: e_commerce; Owner: postgres
--

SELECT pg_catalog.setval('e_commerce.t_vendeurs_id_vendeur_seq', 4, true);


--
-- Name: t_commandes_id_commande_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.t_commandes_id_commande_seq', 1, false);


--
-- Name: t_clients t_clients_pkey; Type: CONSTRAINT; Schema: e_commerce; Owner: postgres
--

ALTER TABLE ONLY e_commerce.t_clients
    ADD CONSTRAINT t_clients_pkey PRIMARY KEY (id_client);


--
-- Name: t_commandes t_commandes_pkey; Type: CONSTRAINT; Schema: e_commerce; Owner: postgres
--

ALTER TABLE ONLY e_commerce.t_commandes
    ADD CONSTRAINT t_commandes_pkey PRIMARY KEY (id_commande);


--
-- Name: t_paiements t_paiements_pkey; Type: CONSTRAINT; Schema: e_commerce; Owner: postgres
--

ALTER TABLE ONLY e_commerce.t_paiements
    ADD CONSTRAINT t_paiements_pkey PRIMARY KEY (id_paiement);


--
-- Name: t_produits t_produits_pkey; Type: CONSTRAINT; Schema: e_commerce; Owner: postgres
--

ALTER TABLE ONLY e_commerce.t_produits
    ADD CONSTRAINT t_produits_pkey PRIMARY KEY (id_produit);


--
-- Name: t_vendeurs t_vendeurs_pkey; Type: CONSTRAINT; Schema: e_commerce; Owner: postgres
--

ALTER TABLE ONLY e_commerce.t_vendeurs
    ADD CONSTRAINT t_vendeurs_pkey PRIMARY KEY (id_vendeur);


--
-- Name: t_commandes t_commandes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.t_commandes
    ADD CONSTRAINT t_commandes_pkey PRIMARY KEY (id_commande);


--
-- Name: t_commandes pk_clientcommande; Type: FK CONSTRAINT; Schema: e_commerce; Owner: postgres
--

ALTER TABLE ONLY e_commerce.t_commandes
    ADD CONSTRAINT pk_clientcommande FOREIGN KEY (id_client) REFERENCES e_commerce.t_clients(id_client) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: t_command_produit pk_commandeproduit; Type: FK CONSTRAINT; Schema: e_commerce; Owner: postgres
--

ALTER TABLE ONLY e_commerce.t_command_produit
    ADD CONSTRAINT pk_commandeproduit FOREIGN KEY (id_produit) REFERENCES e_commerce.t_produits(id_produit) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: t_command_produit pk_commandeproduit_commande; Type: FK CONSTRAINT; Schema: e_commerce; Owner: postgres
--

ALTER TABLE ONLY e_commerce.t_command_produit
    ADD CONSTRAINT pk_commandeproduit_commande FOREIGN KEY (id_commande) REFERENCES e_commerce.t_commandes(id_commande) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: t_paiements pk_paiementcommande; Type: FK CONSTRAINT; Schema: e_commerce; Owner: postgres
--

ALTER TABLE ONLY e_commerce.t_paiements
    ADD CONSTRAINT pk_paiementcommande FOREIGN KEY (id_commande) REFERENCES e_commerce.t_commandes(id_commande) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: t_produits pk_vendeurproduit; Type: FK CONSTRAINT; Schema: e_commerce; Owner: postgres
--

ALTER TABLE ONLY e_commerce.t_produits
    ADD CONSTRAINT pk_vendeurproduit FOREIGN KEY (id_vendeur) REFERENCES e_commerce.t_vendeurs(id_vendeur) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

