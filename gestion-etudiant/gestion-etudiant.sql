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
-- Name: gestion-etudiant; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA "gestion-etudiant";


ALTER SCHEMA "gestion-etudiant" OWNER TO postgres;

--
-- Name: moyenne_etudiant(integer); Type: FUNCTION; Schema: gestion-etudiant; Owner: postgres
--

CREATE FUNCTION "gestion-etudiant".moyenne_etudiant(p_id_etudiant integer) RETURNS TABLE(nom text, moyenne numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
	RETURN QUERY
	SELECT i.nom, i.prenom, AVG(n.note_matiere)
	FROM etudiants i
	JOIN notes n ON i.id_etudiant = n.id_etudiant
	WHERE i.id_etudiant = p.id_etudiant
	GROUP BY i.id_etudiant;
END;
$$;


ALTER FUNCTION "gestion-etudiant".moyenne_etudiant(p_id_etudiant integer) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: cours; Type: TABLE; Schema: gestion-etudiant; Owner: postgres
--

CREATE TABLE "gestion-etudiant".cours (
    id_cours integer NOT NULL,
    libelle character varying(100) NOT NULL,
    coefficient integer NOT NULL,
    id_etudiant integer NOT NULL
);


ALTER TABLE "gestion-etudiant".cours OWNER TO postgres;

--
-- Name: cours_id_cours_seq; Type: SEQUENCE; Schema: gestion-etudiant; Owner: postgres
--

CREATE SEQUENCE "gestion-etudiant".cours_id_cours_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "gestion-etudiant".cours_id_cours_seq OWNER TO postgres;

--
-- Name: cours_id_cours_seq; Type: SEQUENCE OWNED BY; Schema: gestion-etudiant; Owner: postgres
--

ALTER SEQUENCE "gestion-etudiant".cours_id_cours_seq OWNED BY "gestion-etudiant".cours.id_cours;


--
-- Name: cours_id_etudiant_seq; Type: SEQUENCE; Schema: gestion-etudiant; Owner: postgres
--

CREATE SEQUENCE "gestion-etudiant".cours_id_etudiant_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "gestion-etudiant".cours_id_etudiant_seq OWNER TO postgres;

--
-- Name: cours_id_etudiant_seq; Type: SEQUENCE OWNED BY; Schema: gestion-etudiant; Owner: postgres
--

ALTER SEQUENCE "gestion-etudiant".cours_id_etudiant_seq OWNED BY "gestion-etudiant".cours.id_etudiant;


--
-- Name: etudiants; Type: TABLE; Schema: gestion-etudiant; Owner: postgres
--

CREATE TABLE "gestion-etudiant".etudiants (
    id_etudiant integer NOT NULL,
    nom character varying(50) NOT NULL,
    prenom character varying(100) NOT NULL,
    age integer,
    filiere character varying(100) NOT NULL
);


ALTER TABLE "gestion-etudiant".etudiants OWNER TO postgres;

--
-- Name: etudiants_id_etudiant_seq; Type: SEQUENCE; Schema: gestion-etudiant; Owner: postgres
--

CREATE SEQUENCE "gestion-etudiant".etudiants_id_etudiant_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "gestion-etudiant".etudiants_id_etudiant_seq OWNER TO postgres;

--
-- Name: etudiants_id_etudiant_seq; Type: SEQUENCE OWNED BY; Schema: gestion-etudiant; Owner: postgres
--

ALTER SEQUENCE "gestion-etudiant".etudiants_id_etudiant_seq OWNED BY "gestion-etudiant".etudiants.id_etudiant;


--
-- Name: inscription; Type: TABLE; Schema: gestion-etudiant; Owner: postgres
--

CREATE TABLE "gestion-etudiant".inscription (
    id_inscription integer NOT NULL,
    id_etudiant integer NOT NULL,
    id_cours integer NOT NULL
);


ALTER TABLE "gestion-etudiant".inscription OWNER TO postgres;

--
-- Name: inscription_id_cours_seq; Type: SEQUENCE; Schema: gestion-etudiant; Owner: postgres
--

CREATE SEQUENCE "gestion-etudiant".inscription_id_cours_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "gestion-etudiant".inscription_id_cours_seq OWNER TO postgres;

--
-- Name: inscription_id_cours_seq; Type: SEQUENCE OWNED BY; Schema: gestion-etudiant; Owner: postgres
--

ALTER SEQUENCE "gestion-etudiant".inscription_id_cours_seq OWNED BY "gestion-etudiant".inscription.id_cours;


--
-- Name: inscription_id_etudiant_seq; Type: SEQUENCE; Schema: gestion-etudiant; Owner: postgres
--

CREATE SEQUENCE "gestion-etudiant".inscription_id_etudiant_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "gestion-etudiant".inscription_id_etudiant_seq OWNER TO postgres;

--
-- Name: inscription_id_etudiant_seq; Type: SEQUENCE OWNED BY; Schema: gestion-etudiant; Owner: postgres
--

ALTER SEQUENCE "gestion-etudiant".inscription_id_etudiant_seq OWNED BY "gestion-etudiant".inscription.id_etudiant;


--
-- Name: inscription_id_inscription_seq; Type: SEQUENCE; Schema: gestion-etudiant; Owner: postgres
--

CREATE SEQUENCE "gestion-etudiant".inscription_id_inscription_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "gestion-etudiant".inscription_id_inscription_seq OWNER TO postgres;

--
-- Name: inscription_id_inscription_seq; Type: SEQUENCE OWNED BY; Schema: gestion-etudiant; Owner: postgres
--

ALTER SEQUENCE "gestion-etudiant".inscription_id_inscription_seq OWNED BY "gestion-etudiant".inscription.id_inscription;


--
-- Name: moyenne; Type: VIEW; Schema: gestion-etudiant; Owner: postgres
--

CREATE VIEW "gestion-etudiant".moyenne AS
SELECT
    NULL::integer AS id_etudiant,
    NULL::character varying(50) AS nom,
    NULL::character varying(100) AS prenom,
    NULL::numeric AS moyenne_matiere,
    NULL::bigint AS rang;


ALTER VIEW "gestion-etudiant".moyenne OWNER TO postgres;

--
-- Name: notes; Type: TABLE; Schema: gestion-etudiant; Owner: postgres
--

CREATE TABLE "gestion-etudiant".notes (
    note_matiere numeric NOT NULL,
    id_etudiant integer NOT NULL,
    id_cours integer NOT NULL
);


ALTER TABLE "gestion-etudiant".notes OWNER TO postgres;

--
-- Name: notes_id_cours_seq; Type: SEQUENCE; Schema: gestion-etudiant; Owner: postgres
--

CREATE SEQUENCE "gestion-etudiant".notes_id_cours_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "gestion-etudiant".notes_id_cours_seq OWNER TO postgres;

--
-- Name: notes_id_cours_seq; Type: SEQUENCE OWNED BY; Schema: gestion-etudiant; Owner: postgres
--

ALTER SEQUENCE "gestion-etudiant".notes_id_cours_seq OWNED BY "gestion-etudiant".notes.id_cours;


--
-- Name: notes_id_etudiant_seq; Type: SEQUENCE; Schema: gestion-etudiant; Owner: postgres
--

CREATE SEQUENCE "gestion-etudiant".notes_id_etudiant_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "gestion-etudiant".notes_id_etudiant_seq OWNER TO postgres;

--
-- Name: notes_id_etudiant_seq; Type: SEQUENCE OWNED BY; Schema: gestion-etudiant; Owner: postgres
--

ALTER SEQUENCE "gestion-etudiant".notes_id_etudiant_seq OWNED BY "gestion-etudiant".notes.id_etudiant;


--
-- Name: cours id_cours; Type: DEFAULT; Schema: gestion-etudiant; Owner: postgres
--

ALTER TABLE ONLY "gestion-etudiant".cours ALTER COLUMN id_cours SET DEFAULT nextval('"gestion-etudiant".cours_id_cours_seq'::regclass);


--
-- Name: cours id_etudiant; Type: DEFAULT; Schema: gestion-etudiant; Owner: postgres
--

ALTER TABLE ONLY "gestion-etudiant".cours ALTER COLUMN id_etudiant SET DEFAULT nextval('"gestion-etudiant".cours_id_etudiant_seq'::regclass);


--
-- Name: etudiants id_etudiant; Type: DEFAULT; Schema: gestion-etudiant; Owner: postgres
--

ALTER TABLE ONLY "gestion-etudiant".etudiants ALTER COLUMN id_etudiant SET DEFAULT nextval('"gestion-etudiant".etudiants_id_etudiant_seq'::regclass);


--
-- Name: inscription id_inscription; Type: DEFAULT; Schema: gestion-etudiant; Owner: postgres
--

ALTER TABLE ONLY "gestion-etudiant".inscription ALTER COLUMN id_inscription SET DEFAULT nextval('"gestion-etudiant".inscription_id_inscription_seq'::regclass);


--
-- Name: inscription id_etudiant; Type: DEFAULT; Schema: gestion-etudiant; Owner: postgres
--

ALTER TABLE ONLY "gestion-etudiant".inscription ALTER COLUMN id_etudiant SET DEFAULT nextval('"gestion-etudiant".inscription_id_etudiant_seq'::regclass);


--
-- Name: inscription id_cours; Type: DEFAULT; Schema: gestion-etudiant; Owner: postgres
--

ALTER TABLE ONLY "gestion-etudiant".inscription ALTER COLUMN id_cours SET DEFAULT nextval('"gestion-etudiant".inscription_id_cours_seq'::regclass);


--
-- Name: notes id_etudiant; Type: DEFAULT; Schema: gestion-etudiant; Owner: postgres
--

ALTER TABLE ONLY "gestion-etudiant".notes ALTER COLUMN id_etudiant SET DEFAULT nextval('"gestion-etudiant".notes_id_etudiant_seq'::regclass);


--
-- Name: notes id_cours; Type: DEFAULT; Schema: gestion-etudiant; Owner: postgres
--

ALTER TABLE ONLY "gestion-etudiant".notes ALTER COLUMN id_cours SET DEFAULT nextval('"gestion-etudiant".notes_id_cours_seq'::regclass);


--
-- Data for Name: cours; Type: TABLE DATA; Schema: gestion-etudiant; Owner: postgres
--

COPY "gestion-etudiant".cours (id_cours, libelle, coefficient, id_etudiant) FROM stdin;
1	Histoire	1	1
3	Biologie	1	3
4	Mathématique	1	4
5	Droit	1	5
6	Français	2	6
\.


--
-- Data for Name: etudiants; Type: TABLE DATA; Schema: gestion-etudiant; Owner: postgres
--

COPY "gestion-etudiant".etudiants (id_etudiant, nom, prenom, age, filiere) FROM stdin;
1	Mahomy	Jean Eugene	25	Informatique
3	Barry	Ibrahime Sory	20	Genie Informatique
4	Gamy	Jean	19	Biologie
5	kourouma	Zenabou	23	Histoire
6	Diallo	Boubacar	24	Géographie
7	Sow	Mamadou	21	Genie Informatique
8	Gamy	Simon	20	IMP
9	Beimy	Simon Pièrre	25	IMP
\.


--
-- Data for Name: inscription; Type: TABLE DATA; Schema: gestion-etudiant; Owner: postgres
--

COPY "gestion-etudiant".inscription (id_inscription, id_etudiant, id_cours) FROM stdin;
1	1	1
\.


--
-- Data for Name: notes; Type: TABLE DATA; Schema: gestion-etudiant; Owner: postgres
--

COPY "gestion-etudiant".notes (note_matiere, id_etudiant, id_cours) FROM stdin;
10	3	1
11	3	3
11	7	1
14	7	3
14	8	1
15	8	3
10	9	1
10	9	3
\.


--
-- Name: cours_id_cours_seq; Type: SEQUENCE SET; Schema: gestion-etudiant; Owner: postgres
--

SELECT pg_catalog.setval('"gestion-etudiant".cours_id_cours_seq', 6, true);


--
-- Name: cours_id_etudiant_seq; Type: SEQUENCE SET; Schema: gestion-etudiant; Owner: postgres
--

SELECT pg_catalog.setval('"gestion-etudiant".cours_id_etudiant_seq', 33, true);


--
-- Name: etudiants_id_etudiant_seq; Type: SEQUENCE SET; Schema: gestion-etudiant; Owner: postgres
--

SELECT pg_catalog.setval('"gestion-etudiant".etudiants_id_etudiant_seq', 9, true);


--
-- Name: inscription_id_cours_seq; Type: SEQUENCE SET; Schema: gestion-etudiant; Owner: postgres
--

SELECT pg_catalog.setval('"gestion-etudiant".inscription_id_cours_seq', 1, false);


--
-- Name: inscription_id_etudiant_seq; Type: SEQUENCE SET; Schema: gestion-etudiant; Owner: postgres
--

SELECT pg_catalog.setval('"gestion-etudiant".inscription_id_etudiant_seq', 1, false);


--
-- Name: inscription_id_inscription_seq; Type: SEQUENCE SET; Schema: gestion-etudiant; Owner: postgres
--

SELECT pg_catalog.setval('"gestion-etudiant".inscription_id_inscription_seq', 1, true);


--
-- Name: notes_id_cours_seq; Type: SEQUENCE SET; Schema: gestion-etudiant; Owner: postgres
--

SELECT pg_catalog.setval('"gestion-etudiant".notes_id_cours_seq', 1, false);


--
-- Name: notes_id_etudiant_seq; Type: SEQUENCE SET; Schema: gestion-etudiant; Owner: postgres
--

SELECT pg_catalog.setval('"gestion-etudiant".notes_id_etudiant_seq', 1, false);


--
-- Name: cours cours_pkey; Type: CONSTRAINT; Schema: gestion-etudiant; Owner: postgres
--

ALTER TABLE ONLY "gestion-etudiant".cours
    ADD CONSTRAINT cours_pkey PRIMARY KEY (id_cours);


--
-- Name: etudiants etudiants_pkey; Type: CONSTRAINT; Schema: gestion-etudiant; Owner: postgres
--

ALTER TABLE ONLY "gestion-etudiant".etudiants
    ADD CONSTRAINT etudiants_pkey PRIMARY KEY (id_etudiant);


--
-- Name: inscription inscription_pkey; Type: CONSTRAINT; Schema: gestion-etudiant; Owner: postgres
--

ALTER TABLE ONLY "gestion-etudiant".inscription
    ADD CONSTRAINT inscription_pkey PRIMARY KEY (id_inscription);


--
-- Name: moyenne _RETURN; Type: RULE; Schema: gestion-etudiant; Owner: postgres
--

CREATE OR REPLACE VIEW "gestion-etudiant".moyenne AS
 SELECT i.id_etudiant,
    i.nom,
    i.prenom,
    avg(n.note_matiere) AS moyenne_matiere,
    rank() OVER (ORDER BY (avg(n.note_matiere)) DESC) AS rang
   FROM ("gestion-etudiant".etudiants i
     JOIN "gestion-etudiant".notes n ON ((i.id_etudiant = n.id_etudiant)))
  GROUP BY i.id_etudiant;


--
-- Name: cours ck_etudiant; Type: FK CONSTRAINT; Schema: gestion-etudiant; Owner: postgres
--

ALTER TABLE ONLY "gestion-etudiant".cours
    ADD CONSTRAINT ck_etudiant FOREIGN KEY (id_etudiant) REFERENCES "gestion-etudiant".etudiants(id_etudiant) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: notes ek_cours; Type: FK CONSTRAINT; Schema: gestion-etudiant; Owner: postgres
--

ALTER TABLE ONLY "gestion-etudiant".notes
    ADD CONSTRAINT ek_cours FOREIGN KEY (id_cours) REFERENCES "gestion-etudiant".cours(id_cours) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: notes ek_etudiant; Type: FK CONSTRAINT; Schema: gestion-etudiant; Owner: postgres
--

ALTER TABLE ONLY "gestion-etudiant".notes
    ADD CONSTRAINT ek_etudiant FOREIGN KEY (id_etudiant) REFERENCES "gestion-etudiant".etudiants(id_etudiant) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: inscription fk_cours; Type: FK CONSTRAINT; Schema: gestion-etudiant; Owner: postgres
--

ALTER TABLE ONLY "gestion-etudiant".inscription
    ADD CONSTRAINT fk_cours FOREIGN KEY (id_cours) REFERENCES "gestion-etudiant".cours(id_cours) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: inscription fk_etudiant; Type: FK CONSTRAINT; Schema: gestion-etudiant; Owner: postgres
--

ALTER TABLE ONLY "gestion-etudiant".inscription
    ADD CONSTRAINT fk_etudiant FOREIGN KEY (id_etudiant) REFERENCES "gestion-etudiant".etudiants(id_etudiant) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

