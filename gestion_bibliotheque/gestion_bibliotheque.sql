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
-- Name: g_bibliotheque; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA g_bibliotheque;


ALTER SCHEMA g_bibliotheque OWNER TO postgres;

--
-- Name: pg_stat_statements; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA g_bibliotheque;


--
-- Name: EXTENSION pg_stat_statements; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pg_stat_statements IS 'track planning and execution statistics of all SQL statements executed';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA g_bibliotheque;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: audit_trigger_function(); Type: FUNCTION; Schema: g_bibliotheque; Owner: postgres
--

CREATE FUNCTION g_bibliotheque.audit_trigger_function() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO audit_log (table_name, action, new_data, changed_by)
        VALUES (TG_TABLE_NAME, 'INSERT', row_to_json(NEW), current_user);
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_log (table_name, action, old_data, new_data, changed_by)
        VALUES (TG_TABLE_NAME, 'UPDATE', row_to_json(OLD), row_to_json(NEW), current_user);
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO audit_log (table_name, action, old_data, changed_by)
        VALUES (TG_TABLE_NAME, 'DELETE', row_to_json(OLD), current_user);
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$;


ALTER FUNCTION g_bibliotheque.audit_trigger_function() OWNER TO postgres;

--
-- Name: calculer_age(date); Type: FUNCTION; Schema: g_bibliotheque; Owner: postgres
--

CREATE FUNCTION g_bibliotheque.calculer_age(date_naissance date) RETURNS integer
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN EXTRACT(YEAR FROM AGE(CURRENT_DATE, date_naissance));
END;
$$;


ALTER FUNCTION g_bibliotheque.calculer_age(date_naissance date) OWNER TO postgres;

--
-- Name: calculer_amende(date, date, numeric); Type: FUNCTION; Schema: g_bibliotheque; Owner: postgres
--

CREATE FUNCTION g_bibliotheque.calculer_amende(p_date_retour_prevue date, p_date_retour_effectif date DEFAULT NULL::date, p_taux_journalier numeric DEFAULT 0.50) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_jours_retard INT;
BEGIN
    IF p_date_retour_effectif IS NULL THEN
        v_jours_retard := GREATEST(0, CURRENT_DATE - p_date_retour_prevue);
    ELSE
        v_jours_retard := GREATEST(0, p_date_retour_effectif - p_date_retour_prevue);
    END IF;
    
    RETURN v_jours_retard * p_taux_journalier;
END;
$$;


ALTER FUNCTION g_bibliotheque.calculer_amende(p_date_retour_prevue date, p_date_retour_effectif date, p_taux_journalier numeric) OWNER TO postgres;

--
-- Name: check_user_expiration(); Type: FUNCTION; Schema: g_bibliotheque; Owner: postgres
--

CREATE FUNCTION g_bibliotheque.check_user_expiration() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.date_expiration IS NOT NULL AND NEW.date_expiration <= NEW.date_inscription THEN
        RAISE EXCEPTION 'La date d''expiration doit être postérieure à la date d''inscription';
    END IF;
    
    -- Si pas de date d'expiration, mettre 1 an par défaut
    IF NEW.date_expiration IS NULL THEN
        NEW.date_expiration := NEW.date_inscription + INTERVAL '1 year';
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION g_bibliotheque.check_user_expiration() OWNER TO postgres;

--
-- Name: decrypt_data(bytea, text); Type: FUNCTION; Schema: g_bibliotheque; Owner: postgres
--

CREATE FUNCTION g_bibliotheque.decrypt_data(data bytea, key text) RETURNS text
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN pgp_sym_decrypt(data, key);
END;
$$;


ALTER FUNCTION g_bibliotheque.decrypt_data(data bytea, key text) OWNER TO postgres;

--
-- Name: encrypt_data(text, text); Type: FUNCTION; Schema: g_bibliotheque; Owner: postgres
--

CREATE FUNCTION g_bibliotheque.encrypt_data(data text, key text) RETURNS bytea
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN pgp_sym_encrypt(data, key);
END;
$$;


ALTER FUNCTION g_bibliotheque.encrypt_data(data text, key text) OWNER TO postgres;

--
-- Name: exemplaires_disponibles(integer); Type: FUNCTION; Schema: g_bibliotheque; Owner: postgres
--

CREATE FUNCTION g_bibliotheque.exemplaires_disponibles(p_id_livre integer) RETURNS TABLE(exemplaire_id integer, code_barre character varying, etat character varying, editeur character varying, date_acquisition date)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ex.id_exemplaire,
        ex.code_barre,
        ex.etat,
        ed.nom_editeur,
        ex.date_acquisition
    FROM Exemplaire ex
    JOIN Edition ed ON ex.id_edition = ed.id_edition
    WHERE ex.id_livre = p_id_livre
    AND NOT EXISTS (
        SELECT 1 FROM Emprunte e
        WHERE e.id_exemplaire = ex.id_exemplaire
        AND e.date_retour_effectif IS NULL
    );
END;
$$;


ALTER FUNCTION g_bibliotheque.exemplaires_disponibles(p_id_livre integer) OWNER TO postgres;

--
-- Name: generer_rapport_mensuel_v2(integer, integer); Type: PROCEDURE; Schema: g_bibliotheque; Owner: postgres
--

CREATE PROCEDURE g_bibliotheque.generer_rapport_mensuel_v2(IN p_mois integer DEFAULT EXTRACT(month FROM CURRENT_DATE), IN p_annee integer DEFAULT EXTRACT(year FROM CURRENT_DATE))
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_date_debut DATE;
    v_date_fin DATE;
    v_titre_livre VARCHAR(255);
    v_nb_emprunts_livre BIGINT;
    v_cursor REFCURSOR;
BEGIN
    -- Calcul des dates
    v_date_debut := TO_DATE(p_annee::TEXT || '-' || LPAD(p_mois::TEXT, 2, '0') || '-01', 'YYYY-MM-DD');
    v_date_fin := v_date_debut + INTERVAL '1 month' - INTERVAL '1 day';
    
    RAISE NOTICE '=== RAPPORT MENSUEL : %/% ===', LPAD(p_mois::TEXT, 2, '0'), p_annee;
    RAISE NOTICE 'Période: % à %', v_date_debut, v_date_fin;
    RAISE NOTICE '';
    
    -- Statistiques de base
    RAISE NOTICE 'Emprunts totaux: %', (
        SELECT COUNT(*) FROM emprunte 
        WHERE date_emprunt BETWEEN v_date_debut AND v_date_fin
    );
    
    RAISE NOTICE 'Retours effectués: %', (
        SELECT COUNT(*) FROM emprunte 
        WHERE date_retour_effectif BETWEEN v_date_debut AND v_date_fin
    );
    
    RAISE NOTICE 'Emprunts en retard: %', (
        SELECT COUNT(*) FROM emprunte 
        WHERE date_retour_prevue < CURRENT_DATE 
        AND date_retour_effectif IS NULL
    );
    
    RAISE NOTICE 'Nouveaux utilisateurs: %', (
        SELECT COUNT(*) FROM utilisateur 
        WHERE date_inscription BETWEEN v_date_debut AND v_date_fin
    );
    
    RAISE NOTICE '';
    RAISE NOTICE '--- Top 5 livres les plus empruntés ---';
    
    -- Version avec curseur explicite
    OPEN v_cursor FOR
        SELECT 
            l.titre,
            COUNT(*) AS nb_emprunts
        FROM emprunte e
        JOIN exemplaire ex ON e.id_exemplaire = ex.id_exemplaire
        JOIN livre l ON ex.id_livre = l.id_livre
        WHERE e.date_emprunt BETWEEN v_date_debut AND v_date_fin
        GROUP BY l.id_livre, l.titre
        ORDER BY nb_emprunts DESC
        LIMIT 5;
    
    LOOP
        FETCH v_cursor INTO v_titre_livre, v_nb_emprunts_livre;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE '  - % : % emprunt(s)', v_titre_livre, v_nb_emprunts_livre;
    END LOOP;
    
    CLOSE v_cursor;
    
    RAISE NOTICE '';
    RAISE NOTICE '=== FIN DU RAPPORT ===';
    
END;
$$;


ALTER PROCEDURE g_bibliotheque.generer_rapport_mensuel_v2(IN p_mois integer, IN p_annee integer) OWNER TO postgres;

--
-- Name: hash_password(text); Type: FUNCTION; Schema: g_bibliotheque; Owner: postgres
--

CREATE FUNCTION g_bibliotheque.hash_password(password text) RETURNS text
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN crypt(password, gen_salt('bf', 10));
END;
$$;


ALTER FUNCTION g_bibliotheque.hash_password(password text) OWNER TO postgres;

--
-- Name: mettre_a_jour_etat_exemplaire(integer, character varying); Type: PROCEDURE; Schema: g_bibliotheque; Owner: postgres
--

CREATE PROCEDURE g_bibliotheque.mettre_a_jour_etat_exemplaire(IN p_id_exemplaire integer, IN p_nouvel_etat character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF p_nouvel_etat NOT IN ('Neuf', 'Bon', 'Moyen', 'Mauvais') THEN
        RAISE EXCEPTION 'État invalide. Doit être: Neuf, Bon, Moyen, Mauvais';
    END IF;
    
    UPDATE Exemplaire
    SET etat = p_nouvel_etat
    WHERE id_exemplaire = p_id_exemplaire;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Exemplaire non trouvé';
    END IF;
    
    COMMIT;
END;
$$;


ALTER PROCEDURE g_bibliotheque.mettre_a_jour_etat_exemplaire(IN p_id_exemplaire integer, IN p_nouvel_etat character varying) OWNER TO postgres;

--
-- Name: nouvel_emprunt(integer, integer); Type: PROCEDURE; Schema: g_bibliotheque; Owner: postgres
--

CREATE PROCEDURE g_bibliotheque.nouvel_emprunt(IN p_id_exemplaire integer, IN p_id_usager integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_peut_emprunter BOOLEAN;
    v_exemplaire_disponible BOOLEAN;
BEGIN
    -- Vérifier si l'usager peut emprunter
    v_peut_emprunter := peut_emprunter(p_id_usager);
    
    IF NOT v_peut_emprunter THEN
        RAISE EXCEPTION 'L''usager ne peut pas effectuer d''emprunt';
    END IF;
    
    -- Vérifier si l'exemplaire est disponible
    SELECT NOT EXISTS (
        SELECT 1 FROM Emprunte
        WHERE id_exemplaire = p_id_exemplaire
        AND date_retour_effectif IS NULL
    ) INTO v_exemplaire_disponible;
    
    IF NOT v_exemplaire_disponible THEN
        RAISE EXCEPTION 'L''exemplaire n''est pas disponible';
    END IF;
    
    -- Enregistrer l'emprunt
    INSERT INTO Emprunte (id_exemplaire, id_usager, date_emprunt)
    VALUES (p_id_exemplaire, p_id_usager, CURRENT_DATE);
    
    -- Mettre à jour la dernière visite de l'usager
    UPDATE utilisateur 
    SET date_derniere_visite = CURRENT_DATE
    WHERE id_user = p_id_usager;
    
    COMMIT;
END;
$$;


ALTER PROCEDURE g_bibliotheque.nouvel_emprunt(IN p_id_exemplaire integer, IN p_id_usager integer) OWNER TO postgres;

--
-- Name: peut_emprunter(integer, integer); Type: FUNCTION; Schema: g_bibliotheque; Owner: postgres
--

CREATE FUNCTION g_bibliotheque.peut_emprunter(p_id_user integer, p_max_emprunts integer DEFAULT 5) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_nb_emprunts_en_cours INT;
    v_statut VARCHAR(15);
    v_date_expiration DATE;
BEGIN
    -- Vérifier le statut
    SELECT statut, date_expiration INTO v_statut, v_date_expiration
    FROM utilisateur WHERE id_user = p_id_user;
    
    IF v_statut != 'Actif' THEN
        RETURN FALSE;
    END IF;
    
    -- Vérifier la date d'expiration
    IF v_date_expiration IS NOT NULL AND v_date_expiration < CURRENT_DATE THEN
        RETURN FALSE;
    END IF;
    
    -- Vérifier le nombre d'emprunts en cours
    SELECT COUNT(*) INTO v_nb_emprunts_en_cours
    FROM Emprunte 
    WHERE id_usager = p_id_user AND date_retour_effectif IS NULL;
    
    RETURN v_nb_emprunts_en_cours < p_max_emprunts;
END;
$$;


ALTER FUNCTION g_bibliotheque.peut_emprunter(p_id_user integer, p_max_emprunts integer) OWNER TO postgres;

--
-- Name: rechercher_livres(character varying, character varying, character varying, integer, integer); Type: FUNCTION; Schema: g_bibliotheque; Owner: postgres
--

CREATE FUNCTION g_bibliotheque.rechercher_livres(p_titre character varying DEFAULT NULL::character varying, p_auteur character varying DEFAULT NULL::character varying, p_genre character varying DEFAULT NULL::character varying, p_annee_min integer DEFAULT NULL::integer, p_annee_max integer DEFAULT NULL::integer) RETURNS TABLE(livre_id integer, titre character varying, auteur character varying, genre character varying, annee_parution integer, exemplaires_disponibles integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        l.id_livre,
        l.titre,
        STRING_AGG(DISTINCT a.nom || ' ' || COALESCE(a.prenom, ''), ', ') AS auteur,
        t.nom_type AS genre,
        l.annee_parution,
        COUNT(DISTINCT ex.id_exemplaire) FILTER (
            WHERE NOT EXISTS (
                SELECT 1 FROM Emprunte e
                WHERE e.id_exemplaire = ex.id_exemplaire
                AND e.date_retour_effectif IS NULL
            )
        ) AS exemplaires_disponibles
    FROM Livre l
    JOIN Typelivre t ON l.id_type = t.id_type
    LEFT JOIN Redige r ON l.id_livre = r.id_livre
    LEFT JOIN Auteurs a ON r.id_auteur = a.id_auteur
    LEFT JOIN Exemplaire ex ON l.id_livre = ex.id_livre
    WHERE (p_titre IS NULL OR l.titre ILIKE '%' || p_titre || '%')
    AND (p_auteur IS NULL OR a.nom ILIKE '%' || p_auteur || '%' OR a.prenom ILIKE '%' || p_auteur || '%')
    AND (p_genre IS NULL OR t.nom_type ILIKE '%' || p_genre || '%')
    AND (p_annee_min IS NULL OR l.annee_parution >= p_annee_min)
    AND (p_annee_max IS NULL OR l.annee_parution <= p_annee_max)
    GROUP BY l.id_livre, l.titre, t.nom_type, l.annee_parution
    ORDER BY l.titre;
END;
$$;


ALTER FUNCTION g_bibliotheque.rechercher_livres(p_titre character varying, p_auteur character varying, p_genre character varying, p_annee_min integer, p_annee_max integer) OWNER TO postgres;

--
-- Name: retour_emprunt(integer, date); Type: PROCEDURE; Schema: g_bibliotheque; Owner: postgres
--

CREATE PROCEDURE g_bibliotheque.retour_emprunt(IN p_id_emprunt integer, IN p_date_retour date DEFAULT NULL::date)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_amende NUMERIC;
BEGIN
    IF p_date_retour IS NULL THEN
        p_date_retour := CURRENT_DATE;
    END IF;
    
    -- Calculer l'amende
    SELECT calculer_amende(date_retour_prevue, p_date_retour)
    INTO v_amende
    FROM Emprunte
    WHERE id_emprunt = p_id_emprunt;
    
    -- Mettre à jour la date de retour
    UPDATE Emprunte 
    SET date_retour_effectif = p_date_retour
    WHERE id_emprunt = p_id_emprunt;
    
    -- Si amende, enregistrer dans un log (à créer si nécessaire)
    IF v_amende > 0 THEN
        RAISE NOTICE 'Amende à payer: % euros', v_amende;
        -- Ici vous pourriez insérer dans une table Amendes
    END IF;
    
    COMMIT;
END;
$$;


ALTER PROCEDURE g_bibliotheque.retour_emprunt(IN p_id_emprunt integer, IN p_date_retour date) OWNER TO postgres;

--
-- Name: update_user_status(); Type: FUNCTION; Schema: g_bibliotheque; Owner: postgres
--

CREATE FUNCTION g_bibliotheque.update_user_status() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Si la date d'expiration est dépassée, mettre à jour le statut
    IF NEW.date_expiration < CURRENT_DATE AND NEW.statut = 'Actif' THEN
        NEW.statut := 'Inactif';
    END IF;
    
    -- Si l'utilisateur a trop de retards, le suspendre
    IF (
        SELECT COUNT(*) FROM Emprunte 
        WHERE id_usager = NEW.id_user 
        AND date_retour_prevue < CURRENT_DATE - INTERVAL '30 days'
        AND date_retour_effectif IS NULL
    ) > 3 THEN
        NEW.statut := 'Suspendu';
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION g_bibliotheque.update_user_status() OWNER TO postgres;

--
-- Name: verify_password(text, text); Type: FUNCTION; Schema: g_bibliotheque; Owner: postgres
--

CREATE FUNCTION g_bibliotheque.verify_password(stored_hash text, password text) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN stored_hash = crypt(password, stored_hash);
END;
$$;


ALTER FUNCTION g_bibliotheque.verify_password(stored_hash text, password text) OWNER TO postgres;

--
-- Name: retour_emprunt(integer, date); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.retour_emprunt(IN p_id_emprunt integer, IN p_date_retour date DEFAULT NULL::date)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_amende NUMERIC;
BEGIN
    IF p_date_retour IS NULL THEN
        p_date_retour := CURRENT_DATE;
    END IF;
    
    -- Calculer l'amende
    SELECT calculer_amende(date_retour_prevue, p_date_retour)
    INTO v_amende
    FROM Emprunte
    WHERE id_emprunt = p_id_emprunt;
    
    -- Mettre à jour la date de retour
    UPDATE Emprunte 
    SET date_retour_effectif = p_date_retour
    WHERE id_emprunt = p_id_emprunt;
    
    -- Si amende, enregistrer dans un log (à créer si nécessaire)
    IF v_amende > 0 THEN
        RAISE NOTICE 'Amende à payer: % euros', v_amende;
        -- Ici vous pourriez insérer dans une table Amendes
    END IF;
    
    COMMIT;
END;
$$;


ALTER PROCEDURE public.retour_emprunt(IN p_id_emprunt integer, IN p_date_retour date) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: audit_log; Type: TABLE; Schema: g_bibliotheque; Owner: postgres
--

CREATE TABLE g_bibliotheque.audit_log (
    audit_id integer NOT NULL,
    table_name character varying(100),
    action character varying(10),
    old_data jsonb,
    new_data jsonb,
    changed_by character varying(100),
    changed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    ip_address inet,
    user_agent text
);


ALTER TABLE g_bibliotheque.audit_log OWNER TO postgres;

--
-- Name: audit_log_audit_id_seq; Type: SEQUENCE; Schema: g_bibliotheque; Owner: postgres
--

CREATE SEQUENCE g_bibliotheque.audit_log_audit_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE g_bibliotheque.audit_log_audit_id_seq OWNER TO postgres;

--
-- Name: audit_log_audit_id_seq; Type: SEQUENCE OWNED BY; Schema: g_bibliotheque; Owner: postgres
--

ALTER SEQUENCE g_bibliotheque.audit_log_audit_id_seq OWNED BY g_bibliotheque.audit_log.audit_id;


--
-- Name: auteurs; Type: TABLE; Schema: g_bibliotheque; Owner: postgres
--

CREATE TABLE g_bibliotheque.auteurs (
    id_auteur integer NOT NULL,
    nom character varying(100) NOT NULL,
    prenom character varying(100),
    date_naissance date,
    nationalite character varying(50)
);


ALTER TABLE g_bibliotheque.auteurs OWNER TO postgres;

--
-- Name: auteurs_id_auteur_seq; Type: SEQUENCE; Schema: g_bibliotheque; Owner: postgres
--

CREATE SEQUENCE g_bibliotheque.auteurs_id_auteur_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE g_bibliotheque.auteurs_id_auteur_seq OWNER TO postgres;

--
-- Name: auteurs_id_auteur_seq; Type: SEQUENCE OWNED BY; Schema: g_bibliotheque; Owner: postgres
--

ALTER SEQUENCE g_bibliotheque.auteurs_id_auteur_seq OWNED BY g_bibliotheque.auteurs.id_auteur;


--
-- Name: edition; Type: TABLE; Schema: g_bibliotheque; Owner: postgres
--

CREATE TABLE g_bibliotheque.edition (
    id_edition integer NOT NULL,
    nom_editeur character varying(150) NOT NULL,
    id_pays integer,
    date_edition date,
    isbn character varying(20)
);


ALTER TABLE g_bibliotheque.edition OWNER TO postgres;

--
-- Name: edition_id_edition_seq; Type: SEQUENCE; Schema: g_bibliotheque; Owner: postgres
--

CREATE SEQUENCE g_bibliotheque.edition_id_edition_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE g_bibliotheque.edition_id_edition_seq OWNER TO postgres;

--
-- Name: edition_id_edition_seq; Type: SEQUENCE OWNED BY; Schema: g_bibliotheque; Owner: postgres
--

ALTER SEQUENCE g_bibliotheque.edition_id_edition_seq OWNED BY g_bibliotheque.edition.id_edition;


--
-- Name: emprunte; Type: TABLE; Schema: g_bibliotheque; Owner: postgres
--

CREATE TABLE g_bibliotheque.emprunte (
    id_emprunt integer NOT NULL,
    id_exemplaire integer,
    id_user integer,
    date_emprunt date DEFAULT CURRENT_DATE,
    date_retour_prevue date GENERATED ALWAYS AS ((date_emprunt + '21 days'::interval)) STORED,
    date_retour_effectif date,
    CONSTRAINT emprunte_check CHECK (((date_retour_effectif IS NULL) OR (date_retour_effectif >= date_emprunt)))
);


ALTER TABLE g_bibliotheque.emprunte OWNER TO postgres;

--
-- Name: emprunte_id_emprunt_seq; Type: SEQUENCE; Schema: g_bibliotheque; Owner: postgres
--

CREATE SEQUENCE g_bibliotheque.emprunte_id_emprunt_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE g_bibliotheque.emprunte_id_emprunt_seq OWNER TO postgres;

--
-- Name: emprunte_id_emprunt_seq; Type: SEQUENCE OWNED BY; Schema: g_bibliotheque; Owner: postgres
--

ALTER SEQUENCE g_bibliotheque.emprunte_id_emprunt_seq OWNED BY g_bibliotheque.emprunte.id_emprunt;


--
-- Name: exemplaire; Type: TABLE; Schema: g_bibliotheque; Owner: postgres
--

CREATE TABLE g_bibliotheque.exemplaire (
    id_exemplaire integer NOT NULL,
    id_livre integer,
    id_edition integer,
    code_barre character varying(50),
    etat character varying(20),
    date_acquisition date DEFAULT CURRENT_DATE,
    CONSTRAINT exemplaire_etat_check CHECK (((etat)::text = ANY ((ARRAY['Neuf'::character varying, 'Bon'::character varying, 'Moyen'::character varying, 'Mauvais'::character varying])::text[])))
);


ALTER TABLE g_bibliotheque.exemplaire OWNER TO postgres;

--
-- Name: exemplaire_id_exemplaire_seq; Type: SEQUENCE; Schema: g_bibliotheque; Owner: postgres
--

CREATE SEQUENCE g_bibliotheque.exemplaire_id_exemplaire_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE g_bibliotheque.exemplaire_id_exemplaire_seq OWNER TO postgres;

--
-- Name: exemplaire_id_exemplaire_seq; Type: SEQUENCE OWNED BY; Schema: g_bibliotheque; Owner: postgres
--

ALTER SEQUENCE g_bibliotheque.exemplaire_id_exemplaire_seq OWNED BY g_bibliotheque.exemplaire.id_exemplaire;


--
-- Name: inscription; Type: TABLE; Schema: g_bibliotheque; Owner: postgres
--

CREATE TABLE g_bibliotheque.inscription (
    id_inscription integer NOT NULL,
    id_user integer,
    date_inscription date DEFAULT CURRENT_DATE,
    date_expiration date
);


ALTER TABLE g_bibliotheque.inscription OWNER TO postgres;

--
-- Name: inscription_id_inscription_seq; Type: SEQUENCE; Schema: g_bibliotheque; Owner: postgres
--

CREATE SEQUENCE g_bibliotheque.inscription_id_inscription_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE g_bibliotheque.inscription_id_inscription_seq OWNER TO postgres;

--
-- Name: inscription_id_inscription_seq; Type: SEQUENCE OWNED BY; Schema: g_bibliotheque; Owner: postgres
--

ALTER SEQUENCE g_bibliotheque.inscription_id_inscription_seq OWNED BY g_bibliotheque.inscription.id_inscription;


--
-- Name: livre; Type: TABLE; Schema: g_bibliotheque; Owner: postgres
--

CREATE TABLE g_bibliotheque.livre (
    id_livre integer NOT NULL,
    titre character varying(255) NOT NULL,
    id_type integer,
    annee_parution integer,
    resume text
);


ALTER TABLE g_bibliotheque.livre OWNER TO postgres;

--
-- Name: livre_id_livre_seq; Type: SEQUENCE; Schema: g_bibliotheque; Owner: postgres
--

CREATE SEQUENCE g_bibliotheque.livre_id_livre_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE g_bibliotheque.livre_id_livre_seq OWNER TO postgres;

--
-- Name: livre_id_livre_seq; Type: SEQUENCE OWNED BY; Schema: g_bibliotheque; Owner: postgres
--

ALTER SEQUENCE g_bibliotheque.livre_id_livre_seq OWNED BY g_bibliotheque.livre.id_livre;


--
-- Name: pays; Type: TABLE; Schema: g_bibliotheque; Owner: postgres
--

CREATE TABLE g_bibliotheque.pays (
    id_pays integer NOT NULL,
    nom_pays character varying(100) NOT NULL,
    code_pays character(2)
);


ALTER TABLE g_bibliotheque.pays OWNER TO postgres;

--
-- Name: pays_id_pays_seq; Type: SEQUENCE; Schema: g_bibliotheque; Owner: postgres
--

CREATE SEQUENCE g_bibliotheque.pays_id_pays_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE g_bibliotheque.pays_id_pays_seq OWNER TO postgres;

--
-- Name: pays_id_pays_seq; Type: SEQUENCE OWNED BY; Schema: g_bibliotheque; Owner: postgres
--

ALTER SEQUENCE g_bibliotheque.pays_id_pays_seq OWNED BY g_bibliotheque.pays.id_pays;


--
-- Name: redige; Type: TABLE; Schema: g_bibliotheque; Owner: postgres
--

CREATE TABLE g_bibliotheque.redige (
    id_auteur integer NOT NULL,
    id_livre integer NOT NULL
);


ALTER TABLE g_bibliotheque.redige OWNER TO postgres;

--
-- Name: utilisateurs; Type: TABLE; Schema: g_bibliotheque; Owner: postgres
--

CREATE TABLE g_bibliotheque.utilisateurs (
    id_user integer NOT NULL,
    numero_carte character varying(20) NOT NULL,
    nom character varying(100) NOT NULL,
    prenom character varying(100) NOT NULL,
    date_naissance date,
    adresse_email character varying(255),
    telephone character varying(20),
    adresse text,
    code_postal character varying(10),
    ville character varying(100),
    pays character varying(50) DEFAULT 'Guinee'::character varying,
    type_user character varying(20),
    statut character varying(15) DEFAULT 'Actif'::character varying,
    date_inscription date DEFAULT CURRENT_DATE,
    date_expiration date,
    date_derniere_visite date,
    CONSTRAINT date_expiration_check CHECK (((date_expiration IS NULL) OR (date_expiration > date_inscription))),
    CONSTRAINT email_format CHECK (((adresse_email)::text ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'::text)),
    CONSTRAINT utilisateurs_statut_check CHECK (((statut)::text = ANY ((ARRAY['Actif'::character varying, 'Suspendu'::character varying, 'Radie'::character varying, 'Inactif'::character varying])::text[]))),
    CONSTRAINT utilisateurs_type_user_check CHECK (((type_user)::text = ANY ((ARRAY['Etudiant'::character varying, 'Enseignant'::character varying, 'Personnel'::character varying, 'Externe'::character varying, 'Senior'::character varying, 'Enfant'::character varying])::text[])))
);


ALTER TABLE g_bibliotheque.utilisateurs OWNER TO postgres;

--
-- Name: statistiques_anonymes; Type: VIEW; Schema: g_bibliotheque; Owner: postgres
--

CREATE VIEW g_bibliotheque.statistiques_anonymes AS
 SELECT type_user,
    count(*) AS total,
    EXTRACT(year FROM date_inscription) AS annee_inscription
   FROM g_bibliotheque.utilisateurs
  WHERE ((statut)::text = 'Actif'::text)
  GROUP BY type_user, (EXTRACT(year FROM date_inscription));


ALTER VIEW g_bibliotheque.statistiques_anonymes OWNER TO postgres;

--
-- Name: typelivre; Type: TABLE; Schema: g_bibliotheque; Owner: postgres
--

CREATE TABLE g_bibliotheque.typelivre (
    id_type integer NOT NULL,
    nom_type character varying(50) NOT NULL
);


ALTER TABLE g_bibliotheque.typelivre OWNER TO postgres;

--
-- Name: typelivre_id_type_seq; Type: SEQUENCE; Schema: g_bibliotheque; Owner: postgres
--

CREATE SEQUENCE g_bibliotheque.typelivre_id_type_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE g_bibliotheque.typelivre_id_type_seq OWNER TO postgres;

--
-- Name: typelivre_id_type_seq; Type: SEQUENCE OWNED BY; Schema: g_bibliotheque; Owner: postgres
--

ALTER SEQUENCE g_bibliotheque.typelivre_id_type_seq OWNED BY g_bibliotheque.typelivre.id_type;


--
-- Name: utilisateur_secure; Type: TABLE; Schema: g_bibliotheque; Owner: postgres
--

CREATE TABLE g_bibliotheque.utilisateur_secure (
    id_user integer NOT NULL,
    email_encrypted bytea,
    telephone_encrypted bytea,
    adresse_encrypted bytea
);


ALTER TABLE g_bibliotheque.utilisateur_secure OWNER TO postgres;

--
-- Name: utilisateurs_id_user_seq; Type: SEQUENCE; Schema: g_bibliotheque; Owner: postgres
--

CREATE SEQUENCE g_bibliotheque.utilisateurs_id_user_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE g_bibliotheque.utilisateurs_id_user_seq OWNER TO postgres;

--
-- Name: utilisateurs_id_user_seq; Type: SEQUENCE OWNED BY; Schema: g_bibliotheque; Owner: postgres
--

ALTER SEQUENCE g_bibliotheque.utilisateurs_id_user_seq OWNED BY g_bibliotheque.utilisateurs.id_user;


--
-- Name: vue_auteurs_livres; Type: VIEW; Schema: g_bibliotheque; Owner: postgres
--

CREATE VIEW g_bibliotheque.vue_auteurs_livres AS
 SELECT a.id_auteur,
    (((a.nom)::text || ' '::text) || (COALESCE(a.prenom, ''::character varying))::text) AS auteur_complet,
    a.nationalite,
    count(DISTINCT r.id_livre) AS nombre_livres,
    string_agg((l.titre)::text, ', '::text ORDER BY l.annee_parution) AS liste_livres
   FROM ((g_bibliotheque.auteurs a
     LEFT JOIN g_bibliotheque.redige r ON ((a.id_auteur = r.id_auteur)))
     LEFT JOIN g_bibliotheque.livre l ON ((r.id_livre = l.id_livre)))
  GROUP BY a.id_auteur, a.nom, a.prenom, a.nationalite;


ALTER VIEW g_bibliotheque.vue_auteurs_livres OWNER TO postgres;

--
-- Name: vue_emprunts_en_cours; Type: VIEW; Schema: g_bibliotheque; Owner: postgres
--

CREATE VIEW g_bibliotheque.vue_emprunts_en_cours AS
 SELECT e.id_emprunt,
    (((u.nom)::text || ' '::text) || (u.prenom)::text) AS usager,
    l.titre AS livre,
    ex.code_barre,
    e.date_emprunt,
    e.date_retour_prevue,
    (CURRENT_DATE - e.date_retour_prevue) AS jours_retard
   FROM (((g_bibliotheque.emprunte e
     JOIN g_bibliotheque.utilisateurs u ON ((e.id_user = u.id_user)))
     JOIN g_bibliotheque.exemplaire ex ON ((e.id_exemplaire = ex.id_exemplaire)))
     JOIN g_bibliotheque.livre l ON ((ex.id_livre = l.id_livre)))
  WHERE (e.date_retour_effectif IS NULL);


ALTER VIEW g_bibliotheque.vue_emprunts_en_cours OWNER TO postgres;

--
-- Name: vue_livres_disponibles; Type: VIEW; Schema: g_bibliotheque; Owner: postgres
--

CREATE VIEW g_bibliotheque.vue_livres_disponibles AS
 SELECT l.id_livre,
    l.titre,
    t.nom_type,
    ex.code_barre,
    ed.nom_editeur,
    ex.etat,
    count(*) FILTER (WHERE ((em.date_retour_effectif IS NOT NULL) OR (em.id_emprunt IS NULL))) AS exemplaires_disponibles
   FROM ((((g_bibliotheque.livre l
     JOIN g_bibliotheque.typelivre t ON ((l.id_type = t.id_type)))
     JOIN g_bibliotheque.exemplaire ex ON ((l.id_livre = ex.id_livre)))
     JOIN g_bibliotheque.edition ed ON ((ex.id_edition = ed.id_edition)))
     LEFT JOIN g_bibliotheque.emprunte em ON (((ex.id_exemplaire = em.id_exemplaire) AND (em.date_retour_effectif IS NULL))))
  GROUP BY l.id_livre, l.titre, t.nom_type, ex.code_barre, ed.nom_editeur, ex.etat;


ALTER VIEW g_bibliotheque.vue_livres_disponibles OWNER TO postgres;

--
-- Name: vue_livres_populaires; Type: VIEW; Schema: g_bibliotheque; Owner: postgres
--

CREATE VIEW g_bibliotheque.vue_livres_populaires AS
 SELECT l.id_livre,
    l.titre,
    t.nom_type AS genre,
    count(DISTINCT e.id_emprunt) AS nombre_emprunts,
    count(DISTINCT ex.id_exemplaire) AS nombre_exemplaires,
    count(DISTINCT r.id_auteur) AS nombre_auteurs
   FROM ((((g_bibliotheque.livre l
     JOIN g_bibliotheque.typelivre t ON ((l.id_type = t.id_type)))
     JOIN g_bibliotheque.exemplaire ex ON ((l.id_livre = ex.id_livre)))
     JOIN g_bibliotheque.emprunte e ON ((ex.id_exemplaire = e.id_exemplaire)))
     JOIN g_bibliotheque.redige r ON ((l.id_livre = r.id_livre)))
  GROUP BY l.id_livre, l.titre, t.nom_type
  ORDER BY (count(DISTINCT e.id_emprunt)) DESC;


ALTER VIEW g_bibliotheque.vue_livres_populaires OWNER TO postgres;

--
-- Name: vue_statistiques_usagers; Type: VIEW; Schema: g_bibliotheque; Owner: postgres
--

CREATE VIEW g_bibliotheque.vue_statistiques_usagers AS
 SELECT u.id_user,
    (((u.nom)::text || ' '::text) || (u.prenom)::text) AS usager,
    u.type_user,
    count(e.id_emprunt) AS total_emprunts,
    count(e.id_emprunt) FILTER (WHERE (e.date_retour_effectif IS NULL)) AS emprunts_en_cours,
    count(e.id_emprunt) FILTER (WHERE (e.date_retour_effectif > e.date_retour_prevue)) AS retards_total,
    min(e.date_emprunt) AS premier_emprunt,
    max(e.date_emprunt) AS dernier_emprunt
   FROM (g_bibliotheque.utilisateurs u
     LEFT JOIN g_bibliotheque.emprunte e ON ((u.id_user = e.id_user)))
  GROUP BY u.id_user, u.nom, u.prenom, u.type_user;


ALTER VIEW g_bibliotheque.vue_statistiques_usagers OWNER TO postgres;

--
-- Name: audit_log audit_id; Type: DEFAULT; Schema: g_bibliotheque; Owner: postgres
--

ALTER TABLE ONLY g_bibliotheque.audit_log ALTER COLUMN audit_id SET DEFAULT nextval('g_bibliotheque.audit_log_audit_id_seq'::regclass);


--
-- Name: auteurs id_auteur; Type: DEFAULT; Schema: g_bibliotheque; Owner: postgres
--

ALTER TABLE ONLY g_bibliotheque.auteurs ALTER COLUMN id_auteur SET DEFAULT nextval('g_bibliotheque.auteurs_id_auteur_seq'::regclass);


--
-- Name: edition id_edition; Type: DEFAULT; Schema: g_bibliotheque; Owner: postgres
--

ALTER TABLE ONLY g_bibliotheque.edition ALTER COLUMN id_edition SET DEFAULT nextval('g_bibliotheque.edition_id_edition_seq'::regclass);


--
-- Name: emprunte id_emprunt; Type: DEFAULT; Schema: g_bibliotheque; Owner: postgres
--

ALTER TABLE ONLY g_bibliotheque.emprunte ALTER COLUMN id_emprunt SET DEFAULT nextval('g_bibliotheque.emprunte_id_emprunt_seq'::regclass);


--
-- Name: exemplaire id_exemplaire; Type: DEFAULT; Schema: g_bibliotheque; Owner: postgres
--

ALTER TABLE ONLY g_bibliotheque.exemplaire ALTER COLUMN id_exemplaire SET DEFAULT nextval('g_bibliotheque.exemplaire_id_exemplaire_seq'::regclass);


--
-- Name: inscription id_inscription; Type: DEFAULT; Schema: g_bibliotheque; Owner: postgres
--

ALTER TABLE ONLY g_bibliotheque.inscription ALTER COLUMN id_inscription SET DEFAULT nextval('g_bibliotheque.inscription_id_inscription_seq'::regclass);


--
-- Name: livre id_livre; Type: DEFAULT; Schema: g_bibliotheque; Owner: postgres
--

ALTER TABLE ONLY g_bibliotheque.livre ALTER COLUMN id_livre SET DEFAULT nextval('g_bibliotheque.livre_id_livre_seq'::regclass);


--
-- Name: pays id_pays; Type: DEFAULT; Schema: g_bibliotheque; Owner: postgres
--

ALTER TABLE ONLY g_bibliotheque.pays ALTER COLUMN id_pays SET DEFAULT nextval('g_bibliotheque.pays_id_pays_seq'::regclass);


--
-- Name: typelivre id_type; Type: DEFAULT; Schema: g_bibliotheque; Owner: postgres
--

ALTER TABLE ONLY g_bibliotheque.typelivre ALTER COLUMN id_type SET DEFAULT nextval('g_bibliotheque.typelivre_id_type_seq'::regclass);


--
-- Name: utilisateurs id_user; Type: DEFAULT; Schema: g_bibliotheque; Owner: postgres
--

ALTER TABLE ONLY g_bibliotheque.utilisateurs ALTER COLUMN id_user SET DEFAULT nextval('g_bibliotheque.utilisateurs_id_user_seq'::regclass);


--
-- Data for Name: audit_log; Type: TABLE DATA; Schema: g_bibliotheque; Owner: postgres
--

COPY g_bibliotheque.audit_log (audit_id, table_name, action, old_data, new_data, changed_by, changed_at, ip_address, user_agent) FROM stdin;
\.


--
-- Data for Name: auteurs; Type: TABLE DATA; Schema: g_bibliotheque; Owner: postgres
--

COPY g_bibliotheque.auteurs (id_auteur, nom, prenom, date_naissance, nationalite) FROM stdin;
5	Mahomy	Eugene	1913-11-08	Fran‡aise
6	Beimy	Piere	1913-11-08	Fran‡aise
3	Mahomy	Jean Eugene	1913-11-07	Française
4	Camus	Albert	1913-11-08	Guinéenne
\.


--
-- Data for Name: edition; Type: TABLE DATA; Schema: g_bibliotheque; Owner: postgres
--

COPY g_bibliotheque.edition (id_edition, nom_editeur, id_pays, date_edition, isbn) FROM stdin;
3	Gallimard	1	1942-06-01	978-2-07-036822-4
4	Gallimard	2	1942-06-02	978-2-07-036822-5
\.


--
-- Data for Name: emprunte; Type: TABLE DATA; Schema: g_bibliotheque; Owner: postgres
--

COPY g_bibliotheque.emprunte (id_emprunt, id_exemplaire, id_user, date_emprunt, date_retour_effectif) FROM stdin;
1	1	2	1929-09-23	1929-09-23
\.


--
-- Data for Name: exemplaire; Type: TABLE DATA; Schema: g_bibliotheque; Owner: postgres
--

COPY g_bibliotheque.exemplaire (id_exemplaire, id_livre, id_edition, code_barre, etat, date_acquisition) FROM stdin;
1	1	3	9782070368224-001	Bon	1929-09-23
2	1	4	9782070368224-002	Mauvais	1929-09-23
\.


--
-- Data for Name: inscription; Type: TABLE DATA; Schema: g_bibliotheque; Owner: postgres
--

COPY g_bibliotheque.inscription (id_inscription, id_user, date_inscription, date_expiration) FROM stdin;
2	2	1929-09-23	1930-09-23
\.


--
-- Data for Name: livre; Type: TABLE DATA; Schema: g_bibliotheque; Owner: postgres
--

COPY g_bibliotheque.livre (id_livre, titre, id_type, annee_parution, resume) FROM stdin;
1	L'Étranger	1	1942	Un roman sur l'absurdité de la vie
2	Enfant Noir	2	1943	Un roman sur camara Laye enfant noir
\.


--
-- Data for Name: pays; Type: TABLE DATA; Schema: g_bibliotheque; Owner: postgres
--

COPY g_bibliotheque.pays (id_pays, nom_pays, code_pays) FROM stdin;
1	Guinée	GN
2	France	FR
3	Benin	BN
4	TOGO	TG
\.


--
-- Data for Name: redige; Type: TABLE DATA; Schema: g_bibliotheque; Owner: postgres
--

COPY g_bibliotheque.redige (id_auteur, id_livre) FROM stdin;
3	1
4	2
\.


--
-- Data for Name: typelivre; Type: TABLE DATA; Schema: g_bibliotheque; Owner: postgres
--

COPY g_bibliotheque.typelivre (id_type, nom_type) FROM stdin;
1	Philosophie
2	Histoire
3	Roma
4	Science-fiction
5	Fantastique
6	Policier
7	Biographie
8	Science
9	Poésie
10	Théatre
11	Bande dessinée
\.


--
-- Data for Name: utilisateur_secure; Type: TABLE DATA; Schema: g_bibliotheque; Owner: postgres
--

COPY g_bibliotheque.utilisateur_secure (id_user, email_encrypted, telephone_encrypted, adresse_encrypted) FROM stdin;
\.


--
-- Data for Name: utilisateurs; Type: TABLE DATA; Schema: g_bibliotheque; Owner: postgres
--

COPY g_bibliotheque.utilisateurs (id_user, numero_carte, nom, prenom, date_naissance, adresse_email, telephone, adresse, code_postal, ville, pays, type_user, statut, date_inscription, date_expiration, date_derniere_visite) FROM stdin;
2	USER001	Yaboigui	Fomoro Prière	1990-05-15	yaboiguiprierre@gmail.com	+224 621 00 00 00	Rue 123	001	Conakry	Guinee	Etudiant	Actif	1929-09-23	1930-09-23	\N
\.


--
-- Name: audit_log_audit_id_seq; Type: SEQUENCE SET; Schema: g_bibliotheque; Owner: postgres
--

SELECT pg_catalog.setval('g_bibliotheque.audit_log_audit_id_seq', 1, false);


--
-- Name: auteurs_id_auteur_seq; Type: SEQUENCE SET; Schema: g_bibliotheque; Owner: postgres
--

SELECT pg_catalog.setval('g_bibliotheque.auteurs_id_auteur_seq', 37, true);


--
-- Name: edition_id_edition_seq; Type: SEQUENCE SET; Schema: g_bibliotheque; Owner: postgres
--

SELECT pg_catalog.setval('g_bibliotheque.edition_id_edition_seq', 4, true);


--
-- Name: emprunte_id_emprunt_seq; Type: SEQUENCE SET; Schema: g_bibliotheque; Owner: postgres
--

SELECT pg_catalog.setval('g_bibliotheque.emprunte_id_emprunt_seq', 1, true);


--
-- Name: exemplaire_id_exemplaire_seq; Type: SEQUENCE SET; Schema: g_bibliotheque; Owner: postgres
--

SELECT pg_catalog.setval('g_bibliotheque.exemplaire_id_exemplaire_seq', 2, true);


--
-- Name: inscription_id_inscription_seq; Type: SEQUENCE SET; Schema: g_bibliotheque; Owner: postgres
--

SELECT pg_catalog.setval('g_bibliotheque.inscription_id_inscription_seq', 2, true);


--
-- Name: livre_id_livre_seq; Type: SEQUENCE SET; Schema: g_bibliotheque; Owner: postgres
--

SELECT pg_catalog.setval('g_bibliotheque.livre_id_livre_seq', 2, true);


--
-- Name: pays_id_pays_seq; Type: SEQUENCE SET; Schema: g_bibliotheque; Owner: postgres
--

SELECT pg_catalog.setval('g_bibliotheque.pays_id_pays_seq', 35, true);


--
-- Name: typelivre_id_type_seq; Type: SEQUENCE SET; Schema: g_bibliotheque; Owner: postgres
--

SELECT pg_catalog.setval('g_bibliotheque.typelivre_id_type_seq', 11, true);


--
-- Name: utilisateurs_id_user_seq; Type: SEQUENCE SET; Schema: g_bibliotheque; Owner: postgres
--

SELECT pg_catalog.setval('g_bibliotheque.utilisateurs_id_user_seq', 2, true);


--
-- Name: audit_log audit_log_pkey; Type: CONSTRAINT; Schema: g_bibliotheque; Owner: postgres
--

ALTER TABLE ONLY g_bibliotheque.audit_log
    ADD CONSTRAINT audit_log_pkey PRIMARY KEY (audit_id);


--
-- Name: auteurs auteurs_pkey; Type: CONSTRAINT; Schema: g_bibliotheque; Owner: postgres
--

ALTER TABLE ONLY g_bibliotheque.auteurs
    ADD CONSTRAINT auteurs_pkey PRIMARY KEY (id_auteur);


--
-- Name: edition edition_isbn_key; Type: CONSTRAINT; Schema: g_bibliotheque; Owner: postgres
--

ALTER TABLE ONLY g_bibliotheque.edition
    ADD CONSTRAINT edition_isbn_key UNIQUE (isbn);


--
-- Name: edition edition_pkey; Type: CONSTRAINT; Schema: g_bibliotheque; Owner: postgres
--

ALTER TABLE ONLY g_bibliotheque.edition
    ADD CONSTRAINT edition_pkey PRIMARY KEY (id_edition);


--
-- Name: emprunte emprunte_pkey; Type: CONSTRAINT; Schema: g_bibliotheque; Owner: postgres
--

ALTER TABLE ONLY g_bibliotheque.emprunte
    ADD CONSTRAINT emprunte_pkey PRIMARY KEY (id_emprunt);


--
-- Name: exemplaire exemplaire_code_barre_key; Type: CONSTRAINT; Schema: g_bibliotheque; Owner: postgres
--

ALTER TABLE ONLY g_bibliotheque.exemplaire
    ADD CONSTRAINT exemplaire_code_barre_key UNIQUE (code_barre);


--
-- Name: exemplaire exemplaire_pkey; Type: CONSTRAINT; Schema: g_bibliotheque; Owner: postgres
--

ALTER TABLE ONLY g_bibliotheque.exemplaire
    ADD CONSTRAINT exemplaire_pkey PRIMARY KEY (id_exemplaire);


--
-- Name: inscription inscription_pkey; Type: CONSTRAINT; Schema: g_bibliotheque; Owner: postgres
--

ALTER TABLE ONLY g_bibliotheque.inscription
    ADD CONSTRAINT inscription_pkey PRIMARY KEY (id_inscription);


--
-- Name: livre livre_pkey; Type: CONSTRAINT; Schema: g_bibliotheque; Owner: postgres
--

ALTER TABLE ONLY g_bibliotheque.livre
    ADD CONSTRAINT livre_pkey PRIMARY KEY (id_livre);


--
-- Name: pays pays_nom_pays_key; Type: CONSTRAINT; Schema: g_bibliotheque; Owner: postgres
--

ALTER TABLE ONLY g_bibliotheque.pays
    ADD CONSTRAINT pays_nom_pays_key UNIQUE (nom_pays);


--
-- Name: pays pays_pkey; Type: CONSTRAINT; Schema: g_bibliotheque; Owner: postgres
--

ALTER TABLE ONLY g_bibliotheque.pays
    ADD CONSTRAINT pays_pkey PRIMARY KEY (id_pays);


--
-- Name: redige redige_pkey; Type: CONSTRAINT; Schema: g_bibliotheque; Owner: postgres
--

ALTER TABLE ONLY g_bibliotheque.redige
    ADD CONSTRAINT redige_pkey PRIMARY KEY (id_auteur, id_livre);


--
-- Name: typelivre typelivre_nom_type_key; Type: CONSTRAINT; Schema: g_bibliotheque; Owner: postgres
--

ALTER TABLE ONLY g_bibliotheque.typelivre
    ADD CONSTRAINT typelivre_nom_type_key UNIQUE (nom_type);


--
-- Name: typelivre typelivre_pkey; Type: CONSTRAINT; Schema: g_bibliotheque; Owner: postgres
--

ALTER TABLE ONLY g_bibliotheque.typelivre
    ADD CONSTRAINT typelivre_pkey PRIMARY KEY (id_type);


--
-- Name: utilisateur_secure utilisateur_secure_pkey; Type: CONSTRAINT; Schema: g_bibliotheque; Owner: postgres
--

ALTER TABLE ONLY g_bibliotheque.utilisateur_secure
    ADD CONSTRAINT utilisateur_secure_pkey PRIMARY KEY (id_user);


--
-- Name: utilisateurs utilisateurs_adresse_email_key; Type: CONSTRAINT; Schema: g_bibliotheque; Owner: postgres
--

ALTER TABLE ONLY g_bibliotheque.utilisateurs
    ADD CONSTRAINT utilisateurs_adresse_email_key UNIQUE (adresse_email);


--
-- Name: utilisateurs utilisateurs_numero_carte_key; Type: CONSTRAINT; Schema: g_bibliotheque; Owner: postgres
--

ALTER TABLE ONLY g_bibliotheque.utilisateurs
    ADD CONSTRAINT utilisateurs_numero_carte_key UNIQUE (numero_carte);


--
-- Name: utilisateurs utilisateurs_pkey; Type: CONSTRAINT; Schema: g_bibliotheque; Owner: postgres
--

ALTER TABLE ONLY g_bibliotheque.utilisateurs
    ADD CONSTRAINT utilisateurs_pkey PRIMARY KEY (id_user);


--
-- Name: idx_auteur_nationalite; Type: INDEX; Schema: g_bibliotheque; Owner: postgres
--

CREATE INDEX idx_auteur_nationalite ON g_bibliotheque.auteurs USING btree (nationalite);


--
-- Name: idx_auteur_nom; Type: INDEX; Schema: g_bibliotheque; Owner: postgres
--

CREATE INDEX idx_auteur_nom ON g_bibliotheque.auteurs USING btree (nom);


--
-- Name: idx_edition_isbn; Type: INDEX; Schema: g_bibliotheque; Owner: postgres
--

CREATE INDEX idx_edition_isbn ON g_bibliotheque.edition USING btree (isbn);


--
-- Name: idx_edition_nom; Type: INDEX; Schema: g_bibliotheque; Owner: postgres
--

CREATE INDEX idx_edition_nom ON g_bibliotheque.edition USING btree (nom_editeur);


--
-- Name: idx_emprunte_dates; Type: INDEX; Schema: g_bibliotheque; Owner: postgres
--

CREATE INDEX idx_emprunte_dates ON g_bibliotheque.emprunte USING btree (date_emprunt, date_retour_prevue);


--
-- Name: idx_emprunte_exemplaire; Type: INDEX; Schema: g_bibliotheque; Owner: postgres
--

CREATE INDEX idx_emprunte_exemplaire ON g_bibliotheque.emprunte USING btree (id_exemplaire);


--
-- Name: idx_emprunte_retard; Type: INDEX; Schema: g_bibliotheque; Owner: postgres
--

CREATE INDEX idx_emprunte_retard ON g_bibliotheque.emprunte USING btree (date_retour_prevue) WHERE (date_retour_effectif IS NULL);


--
-- Name: idx_emprunte_usager; Type: INDEX; Schema: g_bibliotheque; Owner: postgres
--

CREATE INDEX idx_emprunte_usager ON g_bibliotheque.emprunte USING btree (id_user);


--
-- Name: idx_exemplaire_codebarre; Type: INDEX; Schema: g_bibliotheque; Owner: postgres
--

CREATE INDEX idx_exemplaire_codebarre ON g_bibliotheque.exemplaire USING btree (code_barre);


--
-- Name: idx_exemplaire_etat; Type: INDEX; Schema: g_bibliotheque; Owner: postgres
--

CREATE INDEX idx_exemplaire_etat ON g_bibliotheque.exemplaire USING btree (etat);


--
-- Name: idx_exemplaire_livre; Type: INDEX; Schema: g_bibliotheque; Owner: postgres
--

CREATE INDEX idx_exemplaire_livre ON g_bibliotheque.exemplaire USING btree (id_livre);


--
-- Name: idx_inscription_expiration; Type: INDEX; Schema: g_bibliotheque; Owner: postgres
--

CREATE INDEX idx_inscription_expiration ON g_bibliotheque.inscription USING btree (date_expiration);


--
-- Name: idx_inscription_user; Type: INDEX; Schema: g_bibliotheque; Owner: postgres
--

CREATE INDEX idx_inscription_user ON g_bibliotheque.inscription USING btree (id_user);


--
-- Name: idx_livre_annee; Type: INDEX; Schema: g_bibliotheque; Owner: postgres
--

CREATE INDEX idx_livre_annee ON g_bibliotheque.livre USING btree (annee_parution);


--
-- Name: idx_livre_titre; Type: INDEX; Schema: g_bibliotheque; Owner: postgres
--

CREATE INDEX idx_livre_titre ON g_bibliotheque.livre USING btree (titre);


--
-- Name: idx_livre_type; Type: INDEX; Schema: g_bibliotheque; Owner: postgres
--

CREATE INDEX idx_livre_type ON g_bibliotheque.livre USING btree (id_type);


--
-- Name: idx_redige_auteur; Type: INDEX; Schema: g_bibliotheque; Owner: postgres
--

CREATE INDEX idx_redige_auteur ON g_bibliotheque.redige USING btree (id_auteur);


--
-- Name: idx_redige_livre; Type: INDEX; Schema: g_bibliotheque; Owner: postgres
--

CREATE INDEX idx_redige_livre ON g_bibliotheque.redige USING btree (id_livre);


--
-- Name: idx_user_expiration; Type: INDEX; Schema: g_bibliotheque; Owner: postgres
--

CREATE INDEX idx_user_expiration ON g_bibliotheque.utilisateurs USING btree (date_expiration);


--
-- Name: idx_user_nom_prenom; Type: INDEX; Schema: g_bibliotheque; Owner: postgres
--

CREATE INDEX idx_user_nom_prenom ON g_bibliotheque.utilisateurs USING btree (nom, prenom);


--
-- Name: idx_user_statut; Type: INDEX; Schema: g_bibliotheque; Owner: postgres
--

CREATE INDEX idx_user_statut ON g_bibliotheque.utilisateurs USING btree (statut);


--
-- Name: emprunte audit_emprunte; Type: TRIGGER; Schema: g_bibliotheque; Owner: postgres
--

CREATE TRIGGER audit_emprunte AFTER INSERT OR DELETE OR UPDATE ON g_bibliotheque.emprunte FOR EACH ROW EXECUTE FUNCTION g_bibliotheque.audit_trigger_function();


--
-- Name: utilisateurs audit_utilisateur; Type: TRIGGER; Schema: g_bibliotheque; Owner: postgres
--

CREATE TRIGGER audit_utilisateur AFTER INSERT OR DELETE OR UPDATE ON g_bibliotheque.utilisateurs FOR EACH ROW EXECUTE FUNCTION g_bibliotheque.audit_trigger_function();


--
-- Name: utilisateurs trigger_check_user_expiration; Type: TRIGGER; Schema: g_bibliotheque; Owner: postgres
--

CREATE TRIGGER trigger_check_user_expiration BEFORE INSERT OR UPDATE ON g_bibliotheque.utilisateurs FOR EACH ROW EXECUTE FUNCTION g_bibliotheque.check_user_expiration();


--
-- Name: utilisateurs trigger_update_user_status; Type: TRIGGER; Schema: g_bibliotheque; Owner: postgres
--

CREATE TRIGGER trigger_update_user_status BEFORE UPDATE ON g_bibliotheque.utilisateurs FOR EACH ROW EXECUTE FUNCTION g_bibliotheque.update_user_status();


--
-- Name: edition edition_id_pays_fkey; Type: FK CONSTRAINT; Schema: g_bibliotheque; Owner: postgres
--

ALTER TABLE ONLY g_bibliotheque.edition
    ADD CONSTRAINT edition_id_pays_fkey FOREIGN KEY (id_pays) REFERENCES g_bibliotheque.pays(id_pays);


--
-- Name: emprunte emprunte_id_exemplaire_fkey; Type: FK CONSTRAINT; Schema: g_bibliotheque; Owner: postgres
--

ALTER TABLE ONLY g_bibliotheque.emprunte
    ADD CONSTRAINT emprunte_id_exemplaire_fkey FOREIGN KEY (id_exemplaire) REFERENCES g_bibliotheque.exemplaire(id_exemplaire);


--
-- Name: emprunte emprunte_id_user_fkey; Type: FK CONSTRAINT; Schema: g_bibliotheque; Owner: postgres
--

ALTER TABLE ONLY g_bibliotheque.emprunte
    ADD CONSTRAINT emprunte_id_user_fkey FOREIGN KEY (id_user) REFERENCES g_bibliotheque.utilisateurs(id_user);


--
-- Name: exemplaire exemplaire_id_edition_fkey; Type: FK CONSTRAINT; Schema: g_bibliotheque; Owner: postgres
--

ALTER TABLE ONLY g_bibliotheque.exemplaire
    ADD CONSTRAINT exemplaire_id_edition_fkey FOREIGN KEY (id_edition) REFERENCES g_bibliotheque.edition(id_edition);


--
-- Name: exemplaire exemplaire_id_livre_fkey; Type: FK CONSTRAINT; Schema: g_bibliotheque; Owner: postgres
--

ALTER TABLE ONLY g_bibliotheque.exemplaire
    ADD CONSTRAINT exemplaire_id_livre_fkey FOREIGN KEY (id_livre) REFERENCES g_bibliotheque.livre(id_livre);


--
-- Name: inscription inscription_id_user_fkey; Type: FK CONSTRAINT; Schema: g_bibliotheque; Owner: postgres
--

ALTER TABLE ONLY g_bibliotheque.inscription
    ADD CONSTRAINT inscription_id_user_fkey FOREIGN KEY (id_user) REFERENCES g_bibliotheque.utilisateurs(id_user);


--
-- Name: livre livre_id_type_fkey; Type: FK CONSTRAINT; Schema: g_bibliotheque; Owner: postgres
--

ALTER TABLE ONLY g_bibliotheque.livre
    ADD CONSTRAINT livre_id_type_fkey FOREIGN KEY (id_type) REFERENCES g_bibliotheque.typelivre(id_type);


--
-- Name: redige redige_id_auteur_fkey; Type: FK CONSTRAINT; Schema: g_bibliotheque; Owner: postgres
--

ALTER TABLE ONLY g_bibliotheque.redige
    ADD CONSTRAINT redige_id_auteur_fkey FOREIGN KEY (id_auteur) REFERENCES g_bibliotheque.auteurs(id_auteur);


--
-- Name: redige redige_id_livre_fkey; Type: FK CONSTRAINT; Schema: g_bibliotheque; Owner: postgres
--

ALTER TABLE ONLY g_bibliotheque.redige
    ADD CONSTRAINT redige_id_livre_fkey FOREIGN KEY (id_livre) REFERENCES g_bibliotheque.livre(id_livre);


--
-- Name: utilisateur_secure utilisateur_secure_id_user_fkey; Type: FK CONSTRAINT; Schema: g_bibliotheque; Owner: postgres
--

ALTER TABLE ONLY g_bibliotheque.utilisateur_secure
    ADD CONSTRAINT utilisateur_secure_id_user_fkey FOREIGN KEY (id_user) REFERENCES g_bibliotheque.utilisateurs(id_user);


--
-- Name: emprunte; Type: ROW SECURITY; Schema: g_bibliotheque; Owner: postgres
--

ALTER TABLE g_bibliotheque.emprunte ENABLE ROW LEVEL SECURITY;

--
-- Name: exemplaire; Type: ROW SECURITY; Schema: g_bibliotheque; Owner: postgres
--

ALTER TABLE g_bibliotheque.exemplaire ENABLE ROW LEVEL SECURITY;

--
-- Name: utilisateurs staff_full_access; Type: POLICY; Schema: g_bibliotheque; Owner: postgres
--

CREATE POLICY staff_full_access ON g_bibliotheque.utilisateurs TO bibliotheque_admin USING (true) WITH CHECK (true);


--
-- Name: utilisateurs user_own_data; Type: POLICY; Schema: g_bibliotheque; Owner: postgres
--

CREATE POLICY user_own_data ON g_bibliotheque.utilisateurs USING ((id_user = (current_setting('app.user_id'::text))::integer));


--
-- Name: emprunte user_own_loans; Type: POLICY; Schema: g_bibliotheque; Owner: postgres
--

CREATE POLICY user_own_loans ON g_bibliotheque.emprunte FOR SELECT USING ((id_user = (current_setting('app.user_id'::text))::integer));


--
-- Name: utilisateurs; Type: ROW SECURITY; Schema: g_bibliotheque; Owner: postgres
--

ALTER TABLE g_bibliotheque.utilisateurs ENABLE ROW LEVEL SECURITY;

--
-- Name: SCHEMA g_bibliotheque; Type: ACL; Schema: -; Owner: postgres
--

GRANT ALL ON SCHEMA g_bibliotheque TO bibliotheque_admin;


--
-- Name: FUNCTION calculer_age(date_naissance date); Type: ACL; Schema: g_bibliotheque; Owner: postgres
--

GRANT ALL ON FUNCTION g_bibliotheque.calculer_age(date_naissance date) TO bibliotheque_lecture;


--
-- Name: FUNCTION calculer_amende(p_date_retour_prevue date, p_date_retour_effectif date, p_taux_journalier numeric); Type: ACL; Schema: g_bibliotheque; Owner: postgres
--

GRANT ALL ON FUNCTION g_bibliotheque.calculer_amende(p_date_retour_prevue date, p_date_retour_effectif date, p_taux_journalier numeric) TO bibliotheque_lecture;


--
-- Name: FUNCTION check_user_expiration(); Type: ACL; Schema: g_bibliotheque; Owner: postgres
--

GRANT ALL ON FUNCTION g_bibliotheque.check_user_expiration() TO bibliotheque_lecture;


--
-- Name: FUNCTION exemplaires_disponibles(p_id_livre integer); Type: ACL; Schema: g_bibliotheque; Owner: postgres
--

GRANT ALL ON FUNCTION g_bibliotheque.exemplaires_disponibles(p_id_livre integer) TO bibliotheque_lecture;


--
-- Name: FUNCTION peut_emprunter(p_id_user integer, p_max_emprunts integer); Type: ACL; Schema: g_bibliotheque; Owner: postgres
--

GRANT ALL ON FUNCTION g_bibliotheque.peut_emprunter(p_id_user integer, p_max_emprunts integer) TO bibliotheque_lecture;


--
-- Name: FUNCTION rechercher_livres(p_titre character varying, p_auteur character varying, p_genre character varying, p_annee_min integer, p_annee_max integer); Type: ACL; Schema: g_bibliotheque; Owner: postgres
--

GRANT ALL ON FUNCTION g_bibliotheque.rechercher_livres(p_titre character varying, p_auteur character varying, p_genre character varying, p_annee_min integer, p_annee_max integer) TO bibliotheque_lecture;


--
-- Name: FUNCTION update_user_status(); Type: ACL; Schema: g_bibliotheque; Owner: postgres
--

GRANT ALL ON FUNCTION g_bibliotheque.update_user_status() TO bibliotheque_lecture;


--
-- Name: TABLE auteurs; Type: ACL; Schema: g_bibliotheque; Owner: postgres
--

GRANT SELECT ON TABLE g_bibliotheque.auteurs TO bibliotheque_lecture;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE g_bibliotheque.auteurs TO bibliotheque_ecriture;
GRANT ALL ON TABLE g_bibliotheque.auteurs TO bibliotheque_admin;
GRANT SELECT ON TABLE g_bibliotheque.auteurs TO surviuser;
GRANT SELECT ON TABLE g_bibliotheque.auteurs TO controler;


--
-- Name: SEQUENCE auteurs_id_auteur_seq; Type: ACL; Schema: g_bibliotheque; Owner: postgres
--

GRANT SELECT ON SEQUENCE g_bibliotheque.auteurs_id_auteur_seq TO bibliotheque_lecture;
GRANT USAGE ON SEQUENCE g_bibliotheque.auteurs_id_auteur_seq TO bibliotheque_ecriture;


--
-- Name: TABLE edition; Type: ACL; Schema: g_bibliotheque; Owner: postgres
--

GRANT SELECT ON TABLE g_bibliotheque.edition TO bibliotheque_lecture;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE g_bibliotheque.edition TO bibliotheque_ecriture;
GRANT ALL ON TABLE g_bibliotheque.edition TO bibliotheque_admin;
GRANT SELECT ON TABLE g_bibliotheque.edition TO surviuser;
GRANT SELECT ON TABLE g_bibliotheque.edition TO controler;


--
-- Name: SEQUENCE edition_id_edition_seq; Type: ACL; Schema: g_bibliotheque; Owner: postgres
--

GRANT SELECT ON SEQUENCE g_bibliotheque.edition_id_edition_seq TO bibliotheque_lecture;
GRANT USAGE ON SEQUENCE g_bibliotheque.edition_id_edition_seq TO bibliotheque_ecriture;


--
-- Name: TABLE emprunte; Type: ACL; Schema: g_bibliotheque; Owner: postgres
--

GRANT SELECT ON TABLE g_bibliotheque.emprunte TO bibliotheque_lecture;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE g_bibliotheque.emprunte TO bibliotheque_ecriture;
GRANT ALL ON TABLE g_bibliotheque.emprunte TO bibliotheque_admin;
GRANT SELECT,INSERT,UPDATE ON TABLE g_bibliotheque.emprunte TO eugene;
GRANT SELECT ON TABLE g_bibliotheque.emprunte TO controler;


--
-- Name: SEQUENCE emprunte_id_emprunt_seq; Type: ACL; Schema: g_bibliotheque; Owner: postgres
--

GRANT SELECT ON SEQUENCE g_bibliotheque.emprunte_id_emprunt_seq TO bibliotheque_lecture;
GRANT USAGE ON SEQUENCE g_bibliotheque.emprunte_id_emprunt_seq TO bibliotheque_ecriture;
GRANT USAGE ON SEQUENCE g_bibliotheque.emprunte_id_emprunt_seq TO eugene;


--
-- Name: TABLE exemplaire; Type: ACL; Schema: g_bibliotheque; Owner: postgres
--

GRANT SELECT ON TABLE g_bibliotheque.exemplaire TO bibliotheque_lecture;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE g_bibliotheque.exemplaire TO bibliotheque_ecriture;
GRANT ALL ON TABLE g_bibliotheque.exemplaire TO bibliotheque_admin;
GRANT SELECT,INSERT,UPDATE ON TABLE g_bibliotheque.exemplaire TO eugene;
GRANT SELECT ON TABLE g_bibliotheque.exemplaire TO controler;


--
-- Name: SEQUENCE exemplaire_id_exemplaire_seq; Type: ACL; Schema: g_bibliotheque; Owner: postgres
--

GRANT SELECT ON SEQUENCE g_bibliotheque.exemplaire_id_exemplaire_seq TO bibliotheque_lecture;
GRANT USAGE ON SEQUENCE g_bibliotheque.exemplaire_id_exemplaire_seq TO bibliotheque_ecriture;


--
-- Name: TABLE inscription; Type: ACL; Schema: g_bibliotheque; Owner: postgres
--

GRANT SELECT ON TABLE g_bibliotheque.inscription TO bibliotheque_lecture;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE g_bibliotheque.inscription TO bibliotheque_ecriture;
GRANT ALL ON TABLE g_bibliotheque.inscription TO bibliotheque_admin;
GRANT SELECT ON TABLE g_bibliotheque.inscription TO controler;


--
-- Name: SEQUENCE inscription_id_inscription_seq; Type: ACL; Schema: g_bibliotheque; Owner: postgres
--

GRANT SELECT ON SEQUENCE g_bibliotheque.inscription_id_inscription_seq TO bibliotheque_lecture;
GRANT USAGE ON SEQUENCE g_bibliotheque.inscription_id_inscription_seq TO bibliotheque_ecriture;


--
-- Name: TABLE livre; Type: ACL; Schema: g_bibliotheque; Owner: postgres
--

GRANT SELECT ON TABLE g_bibliotheque.livre TO bibliotheque_lecture;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE g_bibliotheque.livre TO bibliotheque_ecriture;
GRANT ALL ON TABLE g_bibliotheque.livre TO bibliotheque_admin;
GRANT SELECT ON TABLE g_bibliotheque.livre TO surviuser;
GRANT SELECT ON TABLE g_bibliotheque.livre TO controler;


--
-- Name: SEQUENCE livre_id_livre_seq; Type: ACL; Schema: g_bibliotheque; Owner: postgres
--

GRANT SELECT ON SEQUENCE g_bibliotheque.livre_id_livre_seq TO bibliotheque_lecture;
GRANT USAGE ON SEQUENCE g_bibliotheque.livre_id_livre_seq TO bibliotheque_ecriture;


--
-- Name: TABLE pays; Type: ACL; Schema: g_bibliotheque; Owner: postgres
--

GRANT SELECT ON TABLE g_bibliotheque.pays TO bibliotheque_lecture;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE g_bibliotheque.pays TO bibliotheque_ecriture;
GRANT ALL ON TABLE g_bibliotheque.pays TO bibliotheque_admin;
GRANT SELECT ON TABLE g_bibliotheque.pays TO controler;


--
-- Name: SEQUENCE pays_id_pays_seq; Type: ACL; Schema: g_bibliotheque; Owner: postgres
--

GRANT SELECT ON SEQUENCE g_bibliotheque.pays_id_pays_seq TO bibliotheque_lecture;
GRANT USAGE ON SEQUENCE g_bibliotheque.pays_id_pays_seq TO bibliotheque_ecriture;


--
-- Name: TABLE redige; Type: ACL; Schema: g_bibliotheque; Owner: postgres
--

GRANT SELECT ON TABLE g_bibliotheque.redige TO bibliotheque_lecture;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE g_bibliotheque.redige TO bibliotheque_ecriture;
GRANT ALL ON TABLE g_bibliotheque.redige TO bibliotheque_admin;
GRANT SELECT ON TABLE g_bibliotheque.redige TO controler;


--
-- Name: TABLE utilisateurs; Type: ACL; Schema: g_bibliotheque; Owner: postgres
--

GRANT SELECT ON TABLE g_bibliotheque.utilisateurs TO bibliotheque_lecture;
GRANT SELECT,INSERT,UPDATE ON TABLE g_bibliotheque.utilisateurs TO bibliotheque_ecriture;
GRANT ALL ON TABLE g_bibliotheque.utilisateurs TO bibliotheque_admin;
GRANT SELECT ON TABLE g_bibliotheque.utilisateurs TO eugene;


--
-- Name: COLUMN utilisateurs.id_user; Type: ACL; Schema: g_bibliotheque; Owner: postgres
--

GRANT SELECT(id_user) ON TABLE g_bibliotheque.utilisateurs TO surviuser;
GRANT SELECT(id_user) ON TABLE g_bibliotheque.utilisateurs TO eugene;


--
-- Name: COLUMN utilisateurs.nom; Type: ACL; Schema: g_bibliotheque; Owner: postgres
--

GRANT SELECT(nom) ON TABLE g_bibliotheque.utilisateurs TO surviuser;
GRANT SELECT(nom) ON TABLE g_bibliotheque.utilisateurs TO eugene;


--
-- Name: COLUMN utilisateurs.prenom; Type: ACL; Schema: g_bibliotheque; Owner: postgres
--

GRANT SELECT(prenom) ON TABLE g_bibliotheque.utilisateurs TO surviuser;
GRANT SELECT(prenom) ON TABLE g_bibliotheque.utilisateurs TO eugene;


--
-- Name: COLUMN utilisateurs.adresse_email; Type: ACL; Schema: g_bibliotheque; Owner: postgres
--

GRANT UPDATE(adresse_email) ON TABLE g_bibliotheque.utilisateurs TO surviuser;
GRANT UPDATE(adresse_email) ON TABLE g_bibliotheque.utilisateurs TO eugene;


--
-- Name: COLUMN utilisateurs.telephone; Type: ACL; Schema: g_bibliotheque; Owner: postgres
--

GRANT UPDATE(telephone) ON TABLE g_bibliotheque.utilisateurs TO surviuser;
GRANT UPDATE(telephone) ON TABLE g_bibliotheque.utilisateurs TO eugene;


--
-- Name: COLUMN utilisateurs.type_user; Type: ACL; Schema: g_bibliotheque; Owner: postgres
--

GRANT SELECT(type_user) ON TABLE g_bibliotheque.utilisateurs TO surviuser;
GRANT SELECT(type_user) ON TABLE g_bibliotheque.utilisateurs TO eugene;


--
-- Name: TABLE statistiques_anonymes; Type: ACL; Schema: g_bibliotheque; Owner: postgres
--

GRANT SELECT ON TABLE g_bibliotheque.statistiques_anonymes TO PUBLIC;


--
-- Name: TABLE typelivre; Type: ACL; Schema: g_bibliotheque; Owner: postgres
--

GRANT SELECT ON TABLE g_bibliotheque.typelivre TO bibliotheque_lecture;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE g_bibliotheque.typelivre TO bibliotheque_ecriture;
GRANT ALL ON TABLE g_bibliotheque.typelivre TO bibliotheque_admin;
GRANT SELECT ON TABLE g_bibliotheque.typelivre TO surviuser;
GRANT SELECT ON TABLE g_bibliotheque.typelivre TO controler;


--
-- Name: SEQUENCE typelivre_id_type_seq; Type: ACL; Schema: g_bibliotheque; Owner: postgres
--

GRANT SELECT ON SEQUENCE g_bibliotheque.typelivre_id_type_seq TO bibliotheque_lecture;
GRANT USAGE ON SEQUENCE g_bibliotheque.typelivre_id_type_seq TO bibliotheque_ecriture;


--
-- Name: SEQUENCE utilisateurs_id_user_seq; Type: ACL; Schema: g_bibliotheque; Owner: postgres
--

GRANT SELECT ON SEQUENCE g_bibliotheque.utilisateurs_id_user_seq TO bibliotheque_lecture;
GRANT USAGE ON SEQUENCE g_bibliotheque.utilisateurs_id_user_seq TO bibliotheque_ecriture;


--
-- Name: TABLE vue_auteurs_livres; Type: ACL; Schema: g_bibliotheque; Owner: postgres
--

GRANT SELECT ON TABLE g_bibliotheque.vue_auteurs_livres TO bibliotheque_lecture;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE g_bibliotheque.vue_auteurs_livres TO bibliotheque_ecriture;
GRANT ALL ON TABLE g_bibliotheque.vue_auteurs_livres TO bibliotheque_admin;


--
-- Name: TABLE vue_emprunts_en_cours; Type: ACL; Schema: g_bibliotheque; Owner: postgres
--

GRANT SELECT ON TABLE g_bibliotheque.vue_emprunts_en_cours TO bibliotheque_lecture;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE g_bibliotheque.vue_emprunts_en_cours TO bibliotheque_ecriture;
GRANT ALL ON TABLE g_bibliotheque.vue_emprunts_en_cours TO bibliotheque_admin;


--
-- Name: TABLE vue_livres_disponibles; Type: ACL; Schema: g_bibliotheque; Owner: postgres
--

GRANT SELECT ON TABLE g_bibliotheque.vue_livres_disponibles TO bibliotheque_lecture;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE g_bibliotheque.vue_livres_disponibles TO bibliotheque_ecriture;
GRANT ALL ON TABLE g_bibliotheque.vue_livres_disponibles TO bibliotheque_admin;


--
-- Name: TABLE vue_livres_populaires; Type: ACL; Schema: g_bibliotheque; Owner: postgres
--

GRANT SELECT ON TABLE g_bibliotheque.vue_livres_populaires TO bibliotheque_lecture;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE g_bibliotheque.vue_livres_populaires TO bibliotheque_ecriture;
GRANT ALL ON TABLE g_bibliotheque.vue_livres_populaires TO bibliotheque_admin;


--
-- Name: TABLE vue_statistiques_usagers; Type: ACL; Schema: g_bibliotheque; Owner: postgres
--

GRANT SELECT ON TABLE g_bibliotheque.vue_statistiques_usagers TO bibliotheque_lecture;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE g_bibliotheque.vue_statistiques_usagers TO bibliotheque_ecriture;
GRANT ALL ON TABLE g_bibliotheque.vue_statistiques_usagers TO bibliotheque_admin;


--
-- PostgreSQL database dump complete
--

