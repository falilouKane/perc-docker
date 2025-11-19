--
-- PostgreSQL database dump
--

\restrict kHF8b35gzCmyuciSkuM8Qb5U8dtaWN6YR4U8BSkX4Cf5KtHvP3DrI8eFvrRWeff

-- Dumped from database version 15.15
-- Dumped by pg_dump version 15.15

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

--
-- Name: calculer_solde_perc(integer); Type: FUNCTION; Schema: public; Owner: perc_user
--

CREATE FUNCTION public.calculer_solde_perc(p_account_id integer) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_solde DECIMAL(15, 2);
BEGIN
    SELECT COALESCE(SUM(montant), 0)
    INTO v_solde
    FROM perc_contributions
    WHERE account_id = p_account_id;
    
    RETURN v_solde;
END;
$$;


ALTER FUNCTION public.calculer_solde_perc(p_account_id integer) OWNER TO perc_user;

--
-- Name: update_modified_column(); Type: FUNCTION; Schema: public; Owner: perc_user
--

CREATE FUNCTION public.update_modified_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.date_modification = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_modified_column() OWNER TO perc_user;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: perc_accounts; Type: TABLE; Schema: public; Owner: perc_user
--

CREATE TABLE public.perc_accounts (
    id integer NOT NULL,
    participant_id integer,
    compte_cgf character varying(20) NOT NULL,
    solde_actuel numeric(15,2) DEFAULT 0.00,
    date_ouverture date,
    statut character varying(20) DEFAULT 'actif'::character varying,
    date_maj timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.perc_accounts OWNER TO perc_user;

--
-- Name: perc_accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: perc_user
--

CREATE SEQUENCE public.perc_accounts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.perc_accounts_id_seq OWNER TO perc_user;

--
-- Name: perc_accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: perc_user
--

ALTER SEQUENCE public.perc_accounts_id_seq OWNED BY public.perc_accounts.id;


--
-- Name: perc_contributions; Type: TABLE; Schema: public; Owner: perc_user
--

CREATE TABLE public.perc_contributions (
    id integer NOT NULL,
    account_id integer,
    participant_id integer,
    montant numeric(15,2) NOT NULL,
    type_contribution character varying(50) DEFAULT 'versement_cgf'::character varying,
    periode character varying(20),
    date_contribution timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    import_file_id integer,
    commentaire text
);


ALTER TABLE public.perc_contributions OWNER TO perc_user;

--
-- Name: perc_contributions_id_seq; Type: SEQUENCE; Schema: public; Owner: perc_user
--

CREATE SEQUENCE public.perc_contributions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.perc_contributions_id_seq OWNER TO perc_user;

--
-- Name: perc_contributions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: perc_user
--

ALTER SEQUENCE public.perc_contributions_id_seq OWNED BY public.perc_contributions.id;


--
-- Name: perc_import_files; Type: TABLE; Schema: public; Owner: perc_user
--

CREATE TABLE public.perc_import_files (
    id integer NOT NULL,
    nom_fichier character varying(255) NOT NULL,
    date_import timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    nombre_lignes integer,
    nombre_succes integer,
    nombre_erreurs integer,
    statut character varying(50),
    rapport_erreurs text,
    importe_par character varying(100)
);


ALTER TABLE public.perc_import_files OWNER TO perc_user;

--
-- Name: perc_import_files_id_seq; Type: SEQUENCE; Schema: public; Owner: perc_user
--

CREATE SEQUENCE public.perc_import_files_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.perc_import_files_id_seq OWNER TO perc_user;

--
-- Name: perc_import_files_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: perc_user
--

ALTER SEQUENCE public.perc_import_files_id_seq OWNED BY public.perc_import_files.id;


--
-- Name: perc_import_rows; Type: TABLE; Schema: public; Owner: perc_user
--

CREATE TABLE public.perc_import_rows (
    id integer NOT NULL,
    import_file_id integer,
    numero_ligne integer,
    matricule character varying(20),
    statut character varying(50),
    erreur text,
    donnees_brutes jsonb
);


ALTER TABLE public.perc_import_rows OWNER TO perc_user;

--
-- Name: perc_import_rows_id_seq; Type: SEQUENCE; Schema: public; Owner: perc_user
--

CREATE SEQUENCE public.perc_import_rows_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.perc_import_rows_id_seq OWNER TO perc_user;

--
-- Name: perc_import_rows_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: perc_user
--

ALTER SEQUENCE public.perc_import_rows_id_seq OWNED BY public.perc_import_rows.id;


--
-- Name: perc_movements; Type: TABLE; Schema: public; Owner: perc_user
--

CREATE TABLE public.perc_movements (
    id integer NOT NULL,
    account_id integer,
    type_mouvement character varying(50) NOT NULL,
    montant numeric(15,2) NOT NULL,
    solde_avant numeric(15,2),
    solde_apres numeric(15,2),
    description text,
    date_mouvement timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    reference character varying(100)
);


ALTER TABLE public.perc_movements OWNER TO perc_user;

--
-- Name: perc_movements_id_seq; Type: SEQUENCE; Schema: public; Owner: perc_user
--

CREATE SEQUENCE public.perc_movements_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.perc_movements_id_seq OWNER TO perc_user;

--
-- Name: perc_movements_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: perc_user
--

ALTER SEQUENCE public.perc_movements_id_seq OWNED BY public.perc_movements.id;


--
-- Name: perc_otp; Type: TABLE; Schema: public; Owner: perc_user
--

CREATE TABLE public.perc_otp (
    id integer NOT NULL,
    matricule character varying(20) NOT NULL,
    code character varying(6) NOT NULL,
    telephone character varying(20),
    date_generation timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    date_expiration timestamp without time zone NOT NULL,
    utilise boolean DEFAULT false,
    tentatives integer DEFAULT 0
);


ALTER TABLE public.perc_otp OWNER TO perc_user;

--
-- Name: perc_otp_id_seq; Type: SEQUENCE; Schema: public; Owner: perc_user
--

CREATE SEQUENCE public.perc_otp_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.perc_otp_id_seq OWNER TO perc_user;

--
-- Name: perc_otp_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: perc_user
--

ALTER SEQUENCE public.perc_otp_id_seq OWNED BY public.perc_otp.id;


--
-- Name: perc_participants; Type: TABLE; Schema: public; Owner: perc_user
--

CREATE TABLE public.perc_participants (
    id integer NOT NULL,
    matricule character varying(20) NOT NULL,
    compte_cgf character varying(20) NOT NULL,
    nom character varying(255) NOT NULL,
    direction text,
    email character varying(255),
    telephone character varying(20),
    date_creation timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    date_modification timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.perc_participants OWNER TO perc_user;

--
-- Name: perc_participants_id_seq; Type: SEQUENCE; Schema: public; Owner: perc_user
--

CREATE SEQUENCE public.perc_participants_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.perc_participants_id_seq OWNER TO perc_user;

--
-- Name: perc_participants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: perc_user
--

ALTER SEQUENCE public.perc_participants_id_seq OWNED BY public.perc_participants.id;


--
-- Name: perc_sessions; Type: TABLE; Schema: public; Owner: perc_user
--

CREATE TABLE public.perc_sessions (
    id integer NOT NULL,
    matricule character varying(20) NOT NULL,
    token character varying(255) NOT NULL,
    date_creation timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    date_expiration timestamp without time zone NOT NULL,
    ip_address character varying(50),
    user_agent text
);


ALTER TABLE public.perc_sessions OWNER TO perc_user;

--
-- Name: perc_sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: perc_user
--

CREATE SEQUENCE public.perc_sessions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.perc_sessions_id_seq OWNER TO perc_user;

--
-- Name: perc_sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: perc_user
--

ALTER SEQUENCE public.perc_sessions_id_seq OWNED BY public.perc_sessions.id;


--
-- Name: perc_sync_logs; Type: TABLE; Schema: public; Owner: perc_user
--

CREATE TABLE public.perc_sync_logs (
    id integer NOT NULL,
    type_sync character varying(50),
    date_sync timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    statut character varying(50),
    details text,
    nombre_enregistrements integer
);


ALTER TABLE public.perc_sync_logs OWNER TO perc_user;

--
-- Name: perc_sync_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: perc_user
--

CREATE SEQUENCE public.perc_sync_logs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.perc_sync_logs_id_seq OWNER TO perc_user;

--
-- Name: perc_sync_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: perc_user
--

ALTER SEQUENCE public.perc_sync_logs_id_seq OWNED BY public.perc_sync_logs.id;


--
-- Name: v_perc_comptes_actifs; Type: VIEW; Schema: public; Owner: perc_user
--

CREATE VIEW public.v_perc_comptes_actifs AS
 SELECT p.matricule,
    p.nom,
    p.email,
    p.telephone,
    p.direction,
    a.compte_cgf,
    a.solde_actuel,
    a.date_ouverture,
    a.statut,
    ( SELECT count(*) AS count
           FROM public.perc_contributions
          WHERE (perc_contributions.account_id = a.id)) AS nombre_contributions,
    ( SELECT max(perc_contributions.date_contribution) AS max
           FROM public.perc_contributions
          WHERE (perc_contributions.account_id = a.id)) AS derniere_contribution
   FROM (public.perc_participants p
     JOIN public.perc_accounts a ON ((p.id = a.participant_id)))
  WHERE ((a.statut)::text = 'actif'::text);


ALTER TABLE public.v_perc_comptes_actifs OWNER TO perc_user;

--
-- Name: perc_accounts id; Type: DEFAULT; Schema: public; Owner: perc_user
--

ALTER TABLE ONLY public.perc_accounts ALTER COLUMN id SET DEFAULT nextval('public.perc_accounts_id_seq'::regclass);


--
-- Name: perc_contributions id; Type: DEFAULT; Schema: public; Owner: perc_user
--

ALTER TABLE ONLY public.perc_contributions ALTER COLUMN id SET DEFAULT nextval('public.perc_contributions_id_seq'::regclass);


--
-- Name: perc_import_files id; Type: DEFAULT; Schema: public; Owner: perc_user
--

ALTER TABLE ONLY public.perc_import_files ALTER COLUMN id SET DEFAULT nextval('public.perc_import_files_id_seq'::regclass);


--
-- Name: perc_import_rows id; Type: DEFAULT; Schema: public; Owner: perc_user
--

ALTER TABLE ONLY public.perc_import_rows ALTER COLUMN id SET DEFAULT nextval('public.perc_import_rows_id_seq'::regclass);


--
-- Name: perc_movements id; Type: DEFAULT; Schema: public; Owner: perc_user
--

ALTER TABLE ONLY public.perc_movements ALTER COLUMN id SET DEFAULT nextval('public.perc_movements_id_seq'::regclass);


--
-- Name: perc_otp id; Type: DEFAULT; Schema: public; Owner: perc_user
--

ALTER TABLE ONLY public.perc_otp ALTER COLUMN id SET DEFAULT nextval('public.perc_otp_id_seq'::regclass);


--
-- Name: perc_participants id; Type: DEFAULT; Schema: public; Owner: perc_user
--

ALTER TABLE ONLY public.perc_participants ALTER COLUMN id SET DEFAULT nextval('public.perc_participants_id_seq'::regclass);


--
-- Name: perc_sessions id; Type: DEFAULT; Schema: public; Owner: perc_user
--

ALTER TABLE ONLY public.perc_sessions ALTER COLUMN id SET DEFAULT nextval('public.perc_sessions_id_seq'::regclass);


--
-- Name: perc_sync_logs id; Type: DEFAULT; Schema: public; Owner: perc_user
--

ALTER TABLE ONLY public.perc_sync_logs ALTER COLUMN id SET DEFAULT nextval('public.perc_sync_logs_id_seq'::regclass);


--
-- Data for Name: perc_accounts; Type: TABLE DATA; Schema: public; Owner: perc_user
--

COPY public.perc_accounts (id, participant_id, compte_cgf, solde_actuel, date_ouverture, statut, date_maj) FROM stdin;
1	1	0182000401	16265970.00	2023-11-18	actif	2025-11-18 12:47:51.38419
2	2	0224970401	15681321.00	2023-11-18	actif	2025-11-18 12:47:51.38419
3	3	0225810401	15718870.00	2023-11-18	actif	2025-11-18 12:47:51.38419
4	4	0226360401	17588349.00	2023-11-18	actif	2025-11-18 12:47:51.38419
5	5	0226700401	15681369.00	2023-11-18	actif	2025-11-18 12:47:51.38419
\.


--
-- Data for Name: perc_contributions; Type: TABLE DATA; Schema: public; Owner: perc_user
--

COPY public.perc_contributions (id, account_id, participant_id, montant, type_contribution, periode, date_contribution, import_file_id, commentaire) FROM stdin;
1	1	1	884751.00	versement_cgf	2025-11	2025-11-18 00:00:00	\N	\N
2	1	1	1690994.00	versement_cgf	2025-10	2025-10-18 00:00:00	\N	\N
3	1	1	1257305.00	versement_cgf	2025-09	2025-09-18 00:00:00	\N	\N
4	1	1	1763454.00	versement_cgf	2025-08	2025-08-18 00:00:00	\N	\N
5	1	1	1787430.00	versement_cgf	2025-07	2025-07-18 00:00:00	\N	\N
6	1	1	1618312.00	versement_cgf	2025-06	2025-06-18 00:00:00	\N	\N
7	1	1	831610.00	versement_cgf	2025-05	2025-05-18 00:00:00	\N	\N
8	1	1	1954177.00	versement_cgf	2025-04	2025-04-18 00:00:00	\N	\N
9	1	1	1358095.00	versement_cgf	2025-03	2025-03-18 00:00:00	\N	\N
10	1	1	1152737.00	versement_cgf	2025-02	2025-02-18 00:00:00	\N	\N
11	1	1	1288042.00	versement_cgf	2025-01	2025-01-18 00:00:00	\N	\N
12	1	1	679063.00	versement_cgf	2024-12	2024-12-18 00:00:00	\N	\N
13	2	2	1085331.00	versement_cgf	2025-11	2025-11-18 00:00:00	\N	\N
14	2	2	1396863.00	versement_cgf	2025-10	2025-10-18 00:00:00	\N	\N
15	2	2	925031.00	versement_cgf	2025-09	2025-09-18 00:00:00	\N	\N
16	2	2	1268835.00	versement_cgf	2025-08	2025-08-18 00:00:00	\N	\N
17	2	2	1829116.00	versement_cgf	2025-07	2025-07-18 00:00:00	\N	\N
18	2	2	1775827.00	versement_cgf	2025-06	2025-06-18 00:00:00	\N	\N
19	2	2	1522271.00	versement_cgf	2025-05	2025-05-18 00:00:00	\N	\N
20	2	2	1220655.00	versement_cgf	2025-04	2025-04-18 00:00:00	\N	\N
21	2	2	1707881.00	versement_cgf	2025-03	2025-03-18 00:00:00	\N	\N
22	2	2	531575.00	versement_cgf	2025-02	2025-02-18 00:00:00	\N	\N
23	2	2	793004.00	versement_cgf	2025-01	2025-01-18 00:00:00	\N	\N
24	2	2	1624932.00	versement_cgf	2024-12	2024-12-18 00:00:00	\N	\N
25	3	3	914103.00	versement_cgf	2025-11	2025-11-18 00:00:00	\N	\N
26	3	3	1571972.00	versement_cgf	2025-10	2025-10-18 00:00:00	\N	\N
27	3	3	969920.00	versement_cgf	2025-09	2025-09-18 00:00:00	\N	\N
28	3	3	1634940.00	versement_cgf	2025-08	2025-08-18 00:00:00	\N	\N
29	3	3	719275.00	versement_cgf	2025-07	2025-07-18 00:00:00	\N	\N
30	3	3	1864778.00	versement_cgf	2025-06	2025-06-18 00:00:00	\N	\N
31	3	3	1780795.00	versement_cgf	2025-05	2025-05-18 00:00:00	\N	\N
32	3	3	1574173.00	versement_cgf	2025-04	2025-04-18 00:00:00	\N	\N
33	3	3	1266293.00	versement_cgf	2025-03	2025-03-18 00:00:00	\N	\N
34	3	3	1102276.00	versement_cgf	2025-02	2025-02-18 00:00:00	\N	\N
35	3	3	1757276.00	versement_cgf	2025-01	2025-01-18 00:00:00	\N	\N
36	3	3	563069.00	versement_cgf	2024-12	2024-12-18 00:00:00	\N	\N
37	4	4	1309961.00	versement_cgf	2025-11	2025-11-18 00:00:00	\N	\N
38	4	4	1442438.00	versement_cgf	2025-10	2025-10-18 00:00:00	\N	\N
39	4	4	1168432.00	versement_cgf	2025-09	2025-09-18 00:00:00	\N	\N
40	4	4	1410381.00	versement_cgf	2025-08	2025-08-18 00:00:00	\N	\N
41	4	4	838445.00	versement_cgf	2025-07	2025-07-18 00:00:00	\N	\N
42	4	4	1888156.00	versement_cgf	2025-06	2025-06-18 00:00:00	\N	\N
43	4	4	1906530.00	versement_cgf	2025-05	2025-05-18 00:00:00	\N	\N
44	4	4	1321872.00	versement_cgf	2025-04	2025-04-18 00:00:00	\N	\N
45	4	4	1895866.00	versement_cgf	2025-03	2025-03-18 00:00:00	\N	\N
46	4	4	1590286.00	versement_cgf	2025-02	2025-02-18 00:00:00	\N	\N
47	4	4	1692240.00	versement_cgf	2025-01	2025-01-18 00:00:00	\N	\N
48	4	4	1123742.00	versement_cgf	2024-12	2024-12-18 00:00:00	\N	\N
49	5	5	1674398.00	versement_cgf	2025-11	2025-11-18 00:00:00	\N	\N
50	5	5	1175032.00	versement_cgf	2025-10	2025-10-18 00:00:00	\N	\N
51	5	5	1172736.00	versement_cgf	2025-09	2025-09-18 00:00:00	\N	\N
52	5	5	1632133.00	versement_cgf	2025-08	2025-08-18 00:00:00	\N	\N
53	5	5	1380410.00	versement_cgf	2025-07	2025-07-18 00:00:00	\N	\N
54	5	5	1387756.00	versement_cgf	2025-06	2025-06-18 00:00:00	\N	\N
55	5	5	1262718.00	versement_cgf	2025-05	2025-05-18 00:00:00	\N	\N
56	5	5	935804.00	versement_cgf	2025-04	2025-04-18 00:00:00	\N	\N
57	5	5	1450661.00	versement_cgf	2025-03	2025-03-18 00:00:00	\N	\N
58	5	5	973673.00	versement_cgf	2025-02	2025-02-18 00:00:00	\N	\N
59	5	5	926409.00	versement_cgf	2025-01	2025-01-18 00:00:00	\N	\N
60	5	5	1709639.00	versement_cgf	2024-12	2024-12-18 00:00:00	\N	\N
\.


--
-- Data for Name: perc_import_files; Type: TABLE DATA; Schema: public; Owner: perc_user
--

COPY public.perc_import_files (id, nom_fichier, date_import, nombre_lignes, nombre_succes, nombre_erreurs, statut, rapport_erreurs, importe_par) FROM stdin;
1	donnees_test_initiales.xlsx	2025-11-18 12:47:51.408654	5	5	0	complet	\N	system
\.


--
-- Data for Name: perc_import_rows; Type: TABLE DATA; Schema: public; Owner: perc_user
--

COPY public.perc_import_rows (id, import_file_id, numero_ligne, matricule, statut, erreur, donnees_brutes) FROM stdin;
\.


--
-- Data for Name: perc_movements; Type: TABLE DATA; Schema: public; Owner: perc_user
--

COPY public.perc_movements (id, account_id, type_mouvement, montant, solde_avant, solde_apres, description, date_mouvement, reference) FROM stdin;
1	1	contribution	884751.00	0.00	884751.00	Contribution mensuelle - Données de test	2025-11-18 00:00:00	\N
2	1	contribution	1690994.00	0.00	1690994.00	Contribution mensuelle - Données de test	2025-10-18 00:00:00	\N
3	1	contribution	1257305.00	0.00	1257305.00	Contribution mensuelle - Données de test	2025-09-18 00:00:00	\N
4	1	contribution	1763454.00	0.00	1763454.00	Contribution mensuelle - Données de test	2025-08-18 00:00:00	\N
5	1	contribution	1787430.00	0.00	1787430.00	Contribution mensuelle - Données de test	2025-07-18 00:00:00	\N
6	1	contribution	1618312.00	0.00	1618312.00	Contribution mensuelle - Données de test	2025-06-18 00:00:00	\N
7	1	contribution	831610.00	0.00	831610.00	Contribution mensuelle - Données de test	2025-05-18 00:00:00	\N
8	1	contribution	1954177.00	0.00	1954177.00	Contribution mensuelle - Données de test	2025-04-18 00:00:00	\N
9	1	contribution	1358095.00	0.00	1358095.00	Contribution mensuelle - Données de test	2025-03-18 00:00:00	\N
10	1	contribution	1152737.00	0.00	1152737.00	Contribution mensuelle - Données de test	2025-02-18 00:00:00	\N
11	1	contribution	1288042.00	0.00	1288042.00	Contribution mensuelle - Données de test	2025-01-18 00:00:00	\N
12	1	contribution	679063.00	0.00	679063.00	Contribution mensuelle - Données de test	2024-12-18 00:00:00	\N
13	2	contribution	1085331.00	0.00	1085331.00	Contribution mensuelle - Données de test	2025-11-18 00:00:00	\N
14	2	contribution	1396863.00	0.00	1396863.00	Contribution mensuelle - Données de test	2025-10-18 00:00:00	\N
15	2	contribution	925031.00	0.00	925031.00	Contribution mensuelle - Données de test	2025-09-18 00:00:00	\N
16	2	contribution	1268835.00	0.00	1268835.00	Contribution mensuelle - Données de test	2025-08-18 00:00:00	\N
17	2	contribution	1829116.00	0.00	1829116.00	Contribution mensuelle - Données de test	2025-07-18 00:00:00	\N
18	2	contribution	1775827.00	0.00	1775827.00	Contribution mensuelle - Données de test	2025-06-18 00:00:00	\N
19	2	contribution	1522271.00	0.00	1522271.00	Contribution mensuelle - Données de test	2025-05-18 00:00:00	\N
20	2	contribution	1220655.00	0.00	1220655.00	Contribution mensuelle - Données de test	2025-04-18 00:00:00	\N
21	2	contribution	1707881.00	0.00	1707881.00	Contribution mensuelle - Données de test	2025-03-18 00:00:00	\N
22	2	contribution	531575.00	0.00	531575.00	Contribution mensuelle - Données de test	2025-02-18 00:00:00	\N
23	2	contribution	793004.00	0.00	793004.00	Contribution mensuelle - Données de test	2025-01-18 00:00:00	\N
24	2	contribution	1624932.00	0.00	1624932.00	Contribution mensuelle - Données de test	2024-12-18 00:00:00	\N
25	3	contribution	914103.00	0.00	914103.00	Contribution mensuelle - Données de test	2025-11-18 00:00:00	\N
26	3	contribution	1571972.00	0.00	1571972.00	Contribution mensuelle - Données de test	2025-10-18 00:00:00	\N
27	3	contribution	969920.00	0.00	969920.00	Contribution mensuelle - Données de test	2025-09-18 00:00:00	\N
28	3	contribution	1634940.00	0.00	1634940.00	Contribution mensuelle - Données de test	2025-08-18 00:00:00	\N
29	3	contribution	719275.00	0.00	719275.00	Contribution mensuelle - Données de test	2025-07-18 00:00:00	\N
30	3	contribution	1864778.00	0.00	1864778.00	Contribution mensuelle - Données de test	2025-06-18 00:00:00	\N
31	3	contribution	1780795.00	0.00	1780795.00	Contribution mensuelle - Données de test	2025-05-18 00:00:00	\N
32	3	contribution	1574173.00	0.00	1574173.00	Contribution mensuelle - Données de test	2025-04-18 00:00:00	\N
33	3	contribution	1266293.00	0.00	1266293.00	Contribution mensuelle - Données de test	2025-03-18 00:00:00	\N
34	3	contribution	1102276.00	0.00	1102276.00	Contribution mensuelle - Données de test	2025-02-18 00:00:00	\N
35	3	contribution	1757276.00	0.00	1757276.00	Contribution mensuelle - Données de test	2025-01-18 00:00:00	\N
36	3	contribution	563069.00	0.00	563069.00	Contribution mensuelle - Données de test	2024-12-18 00:00:00	\N
37	4	contribution	1309961.00	0.00	1309961.00	Contribution mensuelle - Données de test	2025-11-18 00:00:00	\N
38	4	contribution	1442438.00	0.00	1442438.00	Contribution mensuelle - Données de test	2025-10-18 00:00:00	\N
39	4	contribution	1168432.00	0.00	1168432.00	Contribution mensuelle - Données de test	2025-09-18 00:00:00	\N
40	4	contribution	1410381.00	0.00	1410381.00	Contribution mensuelle - Données de test	2025-08-18 00:00:00	\N
41	4	contribution	838445.00	0.00	838445.00	Contribution mensuelle - Données de test	2025-07-18 00:00:00	\N
42	4	contribution	1888156.00	0.00	1888156.00	Contribution mensuelle - Données de test	2025-06-18 00:00:00	\N
43	4	contribution	1906530.00	0.00	1906530.00	Contribution mensuelle - Données de test	2025-05-18 00:00:00	\N
44	4	contribution	1321872.00	0.00	1321872.00	Contribution mensuelle - Données de test	2025-04-18 00:00:00	\N
45	4	contribution	1895866.00	0.00	1895866.00	Contribution mensuelle - Données de test	2025-03-18 00:00:00	\N
46	4	contribution	1590286.00	0.00	1590286.00	Contribution mensuelle - Données de test	2025-02-18 00:00:00	\N
47	4	contribution	1692240.00	0.00	1692240.00	Contribution mensuelle - Données de test	2025-01-18 00:00:00	\N
48	4	contribution	1123742.00	0.00	1123742.00	Contribution mensuelle - Données de test	2024-12-18 00:00:00	\N
49	5	contribution	1674398.00	0.00	1674398.00	Contribution mensuelle - Données de test	2025-11-18 00:00:00	\N
50	5	contribution	1175032.00	0.00	1175032.00	Contribution mensuelle - Données de test	2025-10-18 00:00:00	\N
51	5	contribution	1172736.00	0.00	1172736.00	Contribution mensuelle - Données de test	2025-09-18 00:00:00	\N
52	5	contribution	1632133.00	0.00	1632133.00	Contribution mensuelle - Données de test	2025-08-18 00:00:00	\N
53	5	contribution	1380410.00	0.00	1380410.00	Contribution mensuelle - Données de test	2025-07-18 00:00:00	\N
54	5	contribution	1387756.00	0.00	1387756.00	Contribution mensuelle - Données de test	2025-06-18 00:00:00	\N
55	5	contribution	1262718.00	0.00	1262718.00	Contribution mensuelle - Données de test	2025-05-18 00:00:00	\N
56	5	contribution	935804.00	0.00	935804.00	Contribution mensuelle - Données de test	2025-04-18 00:00:00	\N
57	5	contribution	1450661.00	0.00	1450661.00	Contribution mensuelle - Données de test	2025-03-18 00:00:00	\N
58	5	contribution	973673.00	0.00	973673.00	Contribution mensuelle - Données de test	2025-02-18 00:00:00	\N
59	5	contribution	926409.00	0.00	926409.00	Contribution mensuelle - Données de test	2025-01-18 00:00:00	\N
60	5	contribution	1709639.00	0.00	1709639.00	Contribution mensuelle - Données de test	2024-12-18 00:00:00	\N
\.


--
-- Data for Name: perc_otp; Type: TABLE DATA; Schema: public; Owner: perc_user
--

COPY public.perc_otp (id, matricule, code, telephone, date_generation, date_expiration, utilise, tentatives) FROM stdin;
1	508924B	848897	+221776459554	2025-11-18 13:18:36.020449	2025-11-18 13:23:36.019	t	0
2	679594H	608420	\N	2025-11-18 13:21:00.355094	2025-11-18 13:26:00.354	t	0
3	679783F	629008	\N	2025-11-18 13:21:36.414755	2025-11-18 13:26:36.414	t	0
4	508924B	251342	+221776459554	2025-11-18 13:25:41.25797	2025-11-18 13:30:41.257	t	0
5	508924B	539016	+221776459554	2025-11-18 13:31:51.403777	2025-11-18 13:36:51.403	t	0
6	508924B	705648	+221776459554	2025-11-18 13:33:02.101102	2025-11-18 13:38:02.1	t	0
7	508924B	445803	+221776459554	2025-11-18 14:59:51.625852	2025-11-18 15:04:51.625	t	2
8	508924B	454885	+221776459554	2025-11-18 15:02:05.89104	2025-11-18 15:07:05.89	t	1
9	508924B	725272	+221776459554	2025-11-18 22:12:29.981134	2025-11-18 22:17:29.98	t	0
\.


--
-- Data for Name: perc_participants; Type: TABLE DATA; Schema: public; Owner: perc_user
--

COPY public.perc_participants (id, matricule, compte_cgf, nom, direction, email, telephone, date_creation, date_modification) FROM stdin;
1	508924B	0182000401	M. ABABACAR DIOP	DOD/DRDP/BUREAU GUICHET UNIQUE VEHICULES	baba_diop36@yahoo.fr	+221776459554	2025-11-18 12:47:51.380347	2025-11-18 12:47:51.380347
2	679594H	0224970401	M. ABABACAR SADIKH BA	DOD/DRC/BUREAU KARANG	\N	\N	2025-11-18 12:47:51.380347	2025-11-18 12:47:51.380347
3	679686D	0225810401	M. ABASSE NDIAYE	DOD/DRDP/BUREAU DAKAR PORT NORD	\N	\N	2025-11-18 12:47:51.380347	2025-11-18 12:47:51.380347
4	679746A	0226360401	M. ABASSE NDIAYE	DSID/BIP/SECTION RESEAU PKI	\N	\N	2025-11-18 12:47:51.380347	2025-11-18 12:47:51.380347
5	679783F	0226700401	M. ABDALLAH KAMBE	DSID/BIP/SECTION RESEAU PKI	\N	\N	2025-11-18 12:47:51.380347	2025-11-18 12:47:51.380347
\.


--
-- Data for Name: perc_sessions; Type: TABLE DATA; Schema: public; Owner: perc_user
--

COPY public.perc_sessions (id, matricule, token, date_creation, date_expiration, ip_address, user_agent) FROM stdin;
1	508924B	da4600e439f261eb8f5c39d802e2ae37d833834548d1f4a9c95f31537ad8b667	2025-11-18 13:18:41.055506	2025-11-19 13:18:41.054	::ffff:172.18.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36
2	679594H	f1c23719704cc10594efbe19beaf8366fcfe439c928555d243f1572e2024ce2b	2025-11-18 13:21:01.881901	2025-11-19 13:21:01.881	::ffff:172.18.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36
3	679783F	0543b000550887926327ef529ce953c46851ebe6e9fd205a9caa8bc0baed211b	2025-11-18 13:21:38.447021	2025-11-19 13:21:38.446	::ffff:172.18.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36
4	508924B	49c062ab2f067344803686d27480e3ce3822957f4244e69f63babbda8a18ee42	2025-11-18 13:25:42.657709	2025-11-19 13:25:42.657	::ffff:172.18.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36
5	508924B	7657956f1bc515d91ba9dd4967abfdcc3ff97bb28035f1de6d2f0de4c6134e15	2025-11-18 13:31:53.360615	2025-11-19 13:31:53.36	::ffff:172.18.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36
6	508924B	a4f7019c5a5224bce40a4ff5139c8f33490290758a2f5466b8719ee273308869	2025-11-18 13:33:04.074114	2025-11-19 13:33:04.073	::ffff:172.18.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36
7	508924B	058772be6ad3546afe1399372b1a0c6ebd68f8779126cedea648b3a5af9108c7	2025-11-18 14:59:54.541592	2025-11-19 14:59:54.541	::ffff:172.18.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36
8	508924B	1e67e31cf7f6ab85353a65fcc6ce4a333191b28dcbd77a5a14ada2acf038ad41	2025-11-18 15:02:07.399441	2025-11-19 15:02:07.398	::ffff:172.18.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36
9	508924B	b533f00e3ef3c1769c35faf2e0383891bd6d73085da9f1bf80cf0213e4d5ab97	2025-11-18 22:12:31.316906	2025-11-19 22:12:31.315	::ffff:172.18.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36
\.


--
-- Data for Name: perc_sync_logs; Type: TABLE DATA; Schema: public; Owner: perc_user
--

COPY public.perc_sync_logs (id, type_sync, date_sync, statut, details, nombre_enregistrements) FROM stdin;
1	initialisation_docker	2025-11-18 12:47:51.411193	success	Données de test créées automatiquement au démarrage Docker	5
\.


--
-- Name: perc_accounts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: perc_user
--

SELECT pg_catalog.setval('public.perc_accounts_id_seq', 5, true);


--
-- Name: perc_contributions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: perc_user
--

SELECT pg_catalog.setval('public.perc_contributions_id_seq', 60, true);


--
-- Name: perc_import_files_id_seq; Type: SEQUENCE SET; Schema: public; Owner: perc_user
--

SELECT pg_catalog.setval('public.perc_import_files_id_seq', 1, true);


--
-- Name: perc_import_rows_id_seq; Type: SEQUENCE SET; Schema: public; Owner: perc_user
--

SELECT pg_catalog.setval('public.perc_import_rows_id_seq', 1, false);


--
-- Name: perc_movements_id_seq; Type: SEQUENCE SET; Schema: public; Owner: perc_user
--

SELECT pg_catalog.setval('public.perc_movements_id_seq', 60, true);


--
-- Name: perc_otp_id_seq; Type: SEQUENCE SET; Schema: public; Owner: perc_user
--

SELECT pg_catalog.setval('public.perc_otp_id_seq', 9, true);


--
-- Name: perc_participants_id_seq; Type: SEQUENCE SET; Schema: public; Owner: perc_user
--

SELECT pg_catalog.setval('public.perc_participants_id_seq', 5, true);


--
-- Name: perc_sessions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: perc_user
--

SELECT pg_catalog.setval('public.perc_sessions_id_seq', 9, true);


--
-- Name: perc_sync_logs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: perc_user
--

SELECT pg_catalog.setval('public.perc_sync_logs_id_seq', 1, true);


--
-- Name: perc_accounts perc_accounts_compte_cgf_key; Type: CONSTRAINT; Schema: public; Owner: perc_user
--

ALTER TABLE ONLY public.perc_accounts
    ADD CONSTRAINT perc_accounts_compte_cgf_key UNIQUE (compte_cgf);


--
-- Name: perc_accounts perc_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: perc_user
--

ALTER TABLE ONLY public.perc_accounts
    ADD CONSTRAINT perc_accounts_pkey PRIMARY KEY (id);


--
-- Name: perc_contributions perc_contributions_pkey; Type: CONSTRAINT; Schema: public; Owner: perc_user
--

ALTER TABLE ONLY public.perc_contributions
    ADD CONSTRAINT perc_contributions_pkey PRIMARY KEY (id);


--
-- Name: perc_import_files perc_import_files_pkey; Type: CONSTRAINT; Schema: public; Owner: perc_user
--

ALTER TABLE ONLY public.perc_import_files
    ADD CONSTRAINT perc_import_files_pkey PRIMARY KEY (id);


--
-- Name: perc_import_rows perc_import_rows_pkey; Type: CONSTRAINT; Schema: public; Owner: perc_user
--

ALTER TABLE ONLY public.perc_import_rows
    ADD CONSTRAINT perc_import_rows_pkey PRIMARY KEY (id);


--
-- Name: perc_movements perc_movements_pkey; Type: CONSTRAINT; Schema: public; Owner: perc_user
--

ALTER TABLE ONLY public.perc_movements
    ADD CONSTRAINT perc_movements_pkey PRIMARY KEY (id);


--
-- Name: perc_otp perc_otp_pkey; Type: CONSTRAINT; Schema: public; Owner: perc_user
--

ALTER TABLE ONLY public.perc_otp
    ADD CONSTRAINT perc_otp_pkey PRIMARY KEY (id);


--
-- Name: perc_participants perc_participants_compte_cgf_key; Type: CONSTRAINT; Schema: public; Owner: perc_user
--

ALTER TABLE ONLY public.perc_participants
    ADD CONSTRAINT perc_participants_compte_cgf_key UNIQUE (compte_cgf);


--
-- Name: perc_participants perc_participants_matricule_key; Type: CONSTRAINT; Schema: public; Owner: perc_user
--

ALTER TABLE ONLY public.perc_participants
    ADD CONSTRAINT perc_participants_matricule_key UNIQUE (matricule);


--
-- Name: perc_participants perc_participants_pkey; Type: CONSTRAINT; Schema: public; Owner: perc_user
--

ALTER TABLE ONLY public.perc_participants
    ADD CONSTRAINT perc_participants_pkey PRIMARY KEY (id);


--
-- Name: perc_sessions perc_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: perc_user
--

ALTER TABLE ONLY public.perc_sessions
    ADD CONSTRAINT perc_sessions_pkey PRIMARY KEY (id);


--
-- Name: perc_sessions perc_sessions_token_key; Type: CONSTRAINT; Schema: public; Owner: perc_user
--

ALTER TABLE ONLY public.perc_sessions
    ADD CONSTRAINT perc_sessions_token_key UNIQUE (token);


--
-- Name: perc_sync_logs perc_sync_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: perc_user
--

ALTER TABLE ONLY public.perc_sync_logs
    ADD CONSTRAINT perc_sync_logs_pkey PRIMARY KEY (id);


--
-- Name: idx_account_participant; Type: INDEX; Schema: public; Owner: perc_user
--

CREATE INDEX idx_account_participant ON public.perc_accounts USING btree (participant_id);


--
-- Name: idx_contributions_account; Type: INDEX; Schema: public; Owner: perc_user
--

CREATE INDEX idx_contributions_account ON public.perc_contributions USING btree (account_id);


--
-- Name: idx_contributions_date; Type: INDEX; Schema: public; Owner: perc_user
--

CREATE INDEX idx_contributions_date ON public.perc_contributions USING btree (date_contribution);


--
-- Name: idx_movements_account; Type: INDEX; Schema: public; Owner: perc_user
--

CREATE INDEX idx_movements_account ON public.perc_movements USING btree (account_id);


--
-- Name: idx_otp_matricule; Type: INDEX; Schema: public; Owner: perc_user
--

CREATE INDEX idx_otp_matricule ON public.perc_otp USING btree (matricule);


--
-- Name: idx_participant_matricule; Type: INDEX; Schema: public; Owner: perc_user
--

CREATE INDEX idx_participant_matricule ON public.perc_participants USING btree (matricule);


--
-- Name: idx_sessions_token; Type: INDEX; Schema: public; Owner: perc_user
--

CREATE INDEX idx_sessions_token ON public.perc_sessions USING btree (token);


--
-- Name: perc_participants update_participant_modtime; Type: TRIGGER; Schema: public; Owner: perc_user
--

CREATE TRIGGER update_participant_modtime BEFORE UPDATE ON public.perc_participants FOR EACH ROW EXECUTE FUNCTION public.update_modified_column();


--
-- Name: perc_accounts perc_accounts_participant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: perc_user
--

ALTER TABLE ONLY public.perc_accounts
    ADD CONSTRAINT perc_accounts_participant_id_fkey FOREIGN KEY (participant_id) REFERENCES public.perc_participants(id) ON DELETE CASCADE;


--
-- Name: perc_contributions perc_contributions_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: perc_user
--

ALTER TABLE ONLY public.perc_contributions
    ADD CONSTRAINT perc_contributions_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.perc_accounts(id) ON DELETE CASCADE;


--
-- Name: perc_contributions perc_contributions_participant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: perc_user
--

ALTER TABLE ONLY public.perc_contributions
    ADD CONSTRAINT perc_contributions_participant_id_fkey FOREIGN KEY (participant_id) REFERENCES public.perc_participants(id) ON DELETE CASCADE;


--
-- Name: perc_import_rows perc_import_rows_import_file_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: perc_user
--

ALTER TABLE ONLY public.perc_import_rows
    ADD CONSTRAINT perc_import_rows_import_file_id_fkey FOREIGN KEY (import_file_id) REFERENCES public.perc_import_files(id) ON DELETE CASCADE;


--
-- Name: perc_movements perc_movements_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: perc_user
--

ALTER TABLE ONLY public.perc_movements
    ADD CONSTRAINT perc_movements_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.perc_accounts(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict kHF8b35gzCmyuciSkuM8Qb5U8dtaWN6YR4U8BSkX4Cf5KtHvP3DrI8eFvrRWeff

