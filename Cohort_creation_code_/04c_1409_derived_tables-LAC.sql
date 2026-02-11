-- =================================================================================================
-- Name:         LAC derived table for SAIL views relevent to project 1409
-- Data sources: 
-- Maintainers:  Sarah
-- Created:      2024/09/02
-- Description:  This script builds the LAC derived table used for project 1409

-- 		LAC derived table - 
-- 		EDUW derived table -
-- 		residency derived table - 
-- 		administrative stagin tables -


-- please note - please check if these tables have already been created and populated before running 
-- this script. It may take quite some time.
-- =================================================================================================

-- =================================================================================================
-- LAC tables
-- =================================================================================================

-- =============================================================================
-- Step 1: Setup main table
-- =============================================================================

CALL fnc.drop_if_exists('sailw1409v.sa_lac_episode');

CREATE TABLE sailw1409v.sa_lac_episode
(
	alf_pe              bigint		,
	alf_sts_cd          smallint	,
	alf_src             varchar(21)	,
	wob                 date		,
	sex                 varchar(1)	,
	ethnicity           varchar(5)	,
	la_cd				SMALLINT	,
	la_name             varchar(17)	,
	la_lsoa2011_cd      varchar(12)	,
	hybrid_id_pe        bigint		NOT NULL,
	disabled_flg        smallint	,
	asylum_flg          smallint	,
	uasc_end_date       date		,
	home_lsoa2011       varchar(12)	,
	period_of_care      smallint	,
	poc_start_dt        date		,
	fiscal_year         integer		,
	placement_seq       smallint	,
	placement_start_dt  date		,
	epi_seq             smallint	,
	epi_start_dt        date 		NOT NULL,
	epi_end_dt          date		,
	category_of_need_cd varchar(2)	,
	reason_start_cd     varchar(1)	,
	reason_start_nm     varchar(20)	,
	reason_end_cd       varchar(4)	,
	reason_end_nm       varchar(21)	,
	legal_status_cd     varchar(2)	,
	legal_status_nm     varchar(26)	,
	placement_cd        varchar(4)	,
	placement_nm        varchar(23)	,
	placement_lsoa2011  varchar(12)	,
	short_break_number  smallint	,
	PRIMARY KEY (hybrid_id_pe, epi_start_dt)
);

----------------------------------------------------------------------------------------------------
-- Step 2: Look up tables
----------------------------------------------------------------------------------------------------
CALL fnc.drop_if_exists('sailw1409v.lkp_lacw_la');

CREATE TABLE sailw1409v.lkp_lacw_la
(
    code    smallint,
    name    varchar(17),
    lad11cd varchar(12)
);

INSERT INTO sailw1409v.lkp_lacw_la
VALUES
(512,   'Isle of Anglesey',  'W06000001'),
(514,   'Gwynedd',           'W06000002'),
(516,   'Conwy',             'W06000003'),
(518,   'Denbighshire',      'W06000004'),
(520,   'Flintshire',        'W06000005'),
(522,   'Wrexham',           'W06000006'),
(524,   'Powys',             'W06000023'),
(526,   'Ceredigion',        'W06000008'),
(528,   'Pembrokeshire',     'W06000009'),
(530,   'Carmarthenshire',   'W06000010'),
(532,   'Swansea',           'W06000011'),
(534,   'Neath Port Talbot', 'W06000012'),
(536,   'Bridgend',          'W06000013'),
(538,   'Vale of Glamorgan', 'W06000014'),
(540,   'Rhondda Cynon Taf', 'W06000016'),
(542,   'Merthyr Tydfil',    'W06000024'),
(544,   'Caerphilly',        'W06000018'),
(545,   'Blaenau Gwent',     'W06000019'),
(546,   'Torfaen',           'W06000020'),
(548,   'Monmouthshire',     'W06000021'),
(550,   'Newport',           'W06000022'),
(552,   'Cardiff',           'W06000015');


CALL fnc.drop_if_exists('sailw1409v.lkp_reason_start');

CREATE TABLE sailw1409v.lkp_reason_start
(
    code    varchar(1),
    name    varchar(20)
);

INSERT INTO sailw1409v.lkp_reason_start
VALUES
('S', 'started'),
('L', 'legal_status_changed'),
('P', 'placement_changed'),
('B', 'both_changed');


CALL fnc.drop_if_exists('sailw1409v.lkp_reason_end');

CREATE TABLE sailw1409v.lkp_reason_end
(
    code    varchar(4),
    name    varchar(21),
    DESC    varchar(49)
);

INSERT INTO sailw1409v.lkp_reason_end
VALUES
('X1',   'remains_looked_after',  'Remains looked after'),
('E1',   'adopted',               'Adopted'),
('E11',  'adopted',               'Adopted - application unopposed'),
('E12',  'adopted',               'Adopted - consent dispensed with'),
('E2',   'died',                  'Died'),
('E3',   'transferred_to_new_la', 'Care taken over by another LA in UK'),
('E4',   'returned_home',         'Returned home'),
('E43',  'sgo_to_carer',          'SGO to foster carers'),
('E44',  'sgo_to_carer',          'SGO to other carers'),
('E5',   'independent_living',    'Moved into independent living w/ support'),
('E6',   'independent_living',    'Moved into independent living w/o support'),
('E7',   'adult_social_services', 'Transferred to care of adult social services'),
('E8',   'ceased_other',          'Ceased for any other reason'),
('E9',   'custody',               'Sentenced to custody'),
('E10',  'aged_18',               'Turned 18yo continuing to live with foster carers'),
('999',  'not_ended',             'Not ended'); -- my custom category for current on-going episodes


-- search guidance PDF for 'legal status code list'
CALL fnc.drop_if_exists('sailw1409v.lkp_legal_status');

CREATE TABLE sailw1409v.lkp_legal_status
(
    code    varchar(2),
    name    varchar(26)
);

INSERT INTO sailw1409v.lkp_legal_status
VALUES
('C1',   'interim_care_order'),
('C2',   'care_order'),
('D1',   'freeing_order'),
('E1',   'placement_order'),
('J1',   'youth_justice'),
('J2',   'youth_justice'),
('J3',   'youth_justice'),
('L1',   'police_protection'),
('L2',   'emergency_protection_order'),
('L3',   'child_assessment_order'),
('V1',   'agreed_short_term_breaks'),
('V2',   'voluntary_accommodation'),
('W1',   'wardship');


-- search guidance PDF for 'placement code list'
CALL fnc.drop_if_exists('sailw1409v.lkp_placement');

CREATE TABLE sailw1409v.lkp_placement
(
    code    varchar(3),
    name    varchar(23),
    DESC    varchar(102)
);

INSERT INTO sailw1409v.lkp_placement
VALUES
-- Foster placements
---- Carer lives inside LA Boundary
('F1',   'kinship_care',            'Foster placement with relative or friend'),
('F2',   'foster_care',             'Placement with other foster carers, provided by LA'),
('F3',   'foster_care',             'Placement with other foster carer, arranged through agency'),
---- Carer lives outside LA Boundary
('F4',   'kinship_care',            'Foster placement with relative or friend'),
('F5',   'foster_care',             'Placement with other foster carers, provided by LA'),
('F6',   'foster_care',             'Placement with other foster carer, arranged through agency'),
-- Placed for adoption
---- Undocumented old codes
('A1',   'placed_for_adoption',     'Placed for adoption not with current foster carer'),
('A2',   'placed_for_adoption',     'Placed for adoption with current foster carer'),
---- With consent
('A3',   'placed_for_adoption',     'Placed for adoption with current foster carer, with consent (s19 2002 Act)'),
('A4',   'placed_for_adoption',     'Placed for adoption not with current foster carer, with consent (s19 2002 Act)'),
---- With placement order
('A5',   'placed_for_adoption',     'Placed for adoption with current foster carer, with placement order (s21 2002 Act)'),
('A6',   'placed_for_adoption',     'Placed for adoption not with current foster carer, with placement order (s21 2002 Act)'),
---- With prospective adoptive parents
('A8',   'placed_for_adoption',     'Placed with prospective adoptive parents (s81(11) 2014 Act and r25 2015 Regulations)'),
-- Placed with own parents
('P1',   'parents',                 'Placed with own parents or other person with parental responsibility'),
-- Other placements in the community
('P2',   'independent_living',      'Independent living e.g. in flat, lodgings, bedsit, B&B or with friends, with or without formal support'),
('P3',   'independent_living',      'Residential employment including apprenticeships where accomodation is provided'),
-- Residential placements
---- Secure unit
('H1',   'secure_unit',             'Secure unit inside LA boundary'),
('H2',   'secure_unit',             'Secure unit outside LA (undocumented pre-2010 code)'),
('H21',  'secure_unit',             'Secure unit outside LA boundary within Wales'),
('H22',  'secure_unit',             'Secure unit outside Wales'),
---- Children's home / care homes for children
('H3',   'childrens_home',          'Homes inside LA boundary'),
('H4',   'childrens_home',          'Homes outside LA boundary'),
---- Hostels and supportive reidential settings other than children's homes
('H5',   'semi_independent_living', 'Residential accommodation not subject to the regulations covering children’s homes'),
---- Other residential placements
('R1',   'other_residential',       'Residential care home'),
('R2',   'medical_care',            'NHS/Health Trust or other establishment providing medical or nursing care'),
('R3',   'mother_baby_unit',        'Residential family centre or mother and baby unit'),
('R4',   'other_residential',       'Youth treatment centre'),
('R5',   'other_residential',       'Youth Offender Institution or prison'),
---- Residential schools
('S1',   'residential_school',      'Residential school, except where dual-registered as a school and a care home for children'),
-- Missing / absent more than 24 hours from agreed placement
('M1',   'absent',                  'In Refuge (s51 Children Act)'),
('M2',   'absent',                  'Whereabouts known (not in Refuge)'),
('M3',   'absent',                  'Whereabouts unknown'),
-- Other placements not listed above
('Z1',   'z1_other',                'Other placements not listed elsewhere');


-- ethnicity from LACW

CALL fnc.drop_if_exists('sailw1409v.lkp_ethn');

CREATE TABLE sailw1409v.lkp_ethn
(
	code  varchar(5)  NOT NULL,
	name  varchar(5)  NOT NULL,
	PRIMARY KEY (code)
);


INSERT INTO sailw1409v.lkp_ethn
VALUES
('A1',   'White'),
('A2',   'White'),
('A3',   'White'),
('B1',   'Mixed'),
('B2',   'Mixed'),
('B3',   'Mixed'),
('B4',   'Mixed'),
('C1',   'Asian'),
('C2',   'Asian'),
('C3',   'Asian'),
('C4',   'Asian'),
('D1',   'Black'),
('D2',   'Black'),
('D3',   'Black'),
('E2',   'Other'),
('E1',   'Asian'),
('ASAB', 'Asian'),
('BBAC', 'Black'),
('MIXD', 'Mixed'),
('OOTH', 'Other'),
('WHTE', 'White');

-- =============================================================================
-- Step 2: Create a child table using boosted linkage
-- =============================================================================

CALL fnc.drop_if_exists('sailw1409v.sa_lac_child');

CREATE TABLE sailw1409v.sa_lac_child
(
	hybrid_id_pe		bigint NOT NULL,
	la_cd               bigint,
	alf_pe              bigint,
	alf_sts_cd          smallint,
	alf_src             varchar(21),
	wob                 date,
	sex                 varchar(1),
	ethnicity           varchar(5),
	disabled_flg        smallint,
	asylum_flg          smallint,
	uasc_end_date       date,
	home_lsoa2011       varchar(9),
	PRIMARY KEY (hybrid_id_pe)
);

INSERT INTO sailw1409v.sa_lac_child
SELECT
	alf.hybrid_id_pe,
	alf.local_authority_code,
	alf.alf_pe,
	alf.alf_sts_cd,
	alf.alf_source,
	min(alf.wob) AS wob,
	min(
		CASE
			WHEN alf.GNDR_CD = 1 THEN 'M'
			WHEN alf.GNDR_CD = 2 THEN 'F'
		END
	) AS sex,
	max(LKP_ETHN.name) AS ETHNICITY,
	max(
		CASE
			WHEN lacw_child.disability_code = 2 THEN NULL
			ELSE lacw_child.disability_code
		END
	) AS disabled_flg,
	max(cast(lacw_child.asylum AS smallint)) AS asylum_flg,
	max(lacw_child.date_ceased_uasc) AS uasc_end_date,
	max(lacw_child.lsoa2011_home_postcode) AS home_lsoa2011
FROM sail1409v.LACW_LAC_ALF_DERIVED_20240626 AS alf
INNER JOIN sail1409v.LACW_CHILD_MAIN_20220329 AS lacw_child
	ON alf.hybrid_id_pe = lacw_child.hybrid_id_pe
LEFT JOIN sailw1409v.lkp_ethn AS lkp_ethn
	ON UPPER(lacw_child.ETHNICITY) = lkp_ethn.CODE
WHERE
	alf.hybrid_id_pe IS NOT NULL
GROUP BY
	alf.hybrid_id_pe,
	alf.local_authority_code,
	alf.alf_pe,
	alf.alf_sts_cd,
	alf.alf_source;

-- =============================================================================
-- Step 3: Create an initial episode table
-- =============================================================================

CALL fnc.drop_if_exists('sailw1409v.sa_lac_epi_prep');

CREATE TABLE sailw1409v.sa_lac_epi_prep
(
	hybrid_id_pe		bigint		NOT NULL,
	la_cd               smallint	,
	la_name             varchar(17)	,
	la_lsoa2011_cd      varchar(12)	,
	period_of_care      smallint	,
	poc_start_dt        date		,
	poc_end_dt          date		,
	fiscal_year         integer		,
	placement_seq       smallint	,
	placement_start_dt  date		,
	placement_end_dt    date		,
	epi_seq             smallint	,
	epi_start_dt        date		NOT NULL,
	epi_end_dt          date		,
	category_of_need_cd varchar(2)	,
	reason_start_cd     varchar(1)	,
	reason_start_nm     varchar(20)	,
	reason_end_cd       varchar(4)	,
	reason_end_nm       varchar(21)	,
	legal_status_cd     varchar(2)	,
	legal_status_nm     varchar(26)	,
	placement_cd        varchar(4)	,
	placement_nm        varchar(23)	,
	placement_lsoa2011  varchar(12)	,
	short_break_number  smallint	,
	PRIMARY KEY (hybrid_id_pe, epi_start_dt)
);

INSERT INTO sailw1409v.sa_lac_epi_prep
(
	hybrid_id_pe,
	la_cd,
	la_name,
	la_lsoa2011_cd,
	fiscal_year,
	epi_seq,
	epi_start_dt,
	epi_end_dt,
	reason_start_cd,
	reason_start_nm,
	reason_end_cd,
	reason_end_nm,
	category_of_need_cd,
	legal_status_cd,
	legal_status_nm,
	placement_cd,
	placement_nm,
	placement_lsoa2011,
	short_break_number
)
WITH
	-- make sure strings are upper case
	format_strings AS
	(
		SELECT
			hybrid_id_pe						AS hybrid_id_pe,
			local_authority_code                AS la_cd,
			year_code                           AS fiscal_year,
			episode_start_date                  AS epi_start_dt,
			episode_end_date                    AS epi_end_dt,
			upper(reason_episode_started_code)  AS reason_start_cd,
			upper(reason_episode_finished_code) AS reason_end_cd,
			upper(category_of_need_code)        AS category_of_need_cd,
			upper(legal_status_code)            AS legal_status_cd,
			upper(placement_type_code)          AS placement_cd,
			upper(lsoa2011_placement_postcode)  AS placement_lsoa2011,
			short_breaks                        AS short_break_number,
			row_number() OVER (PARTITION BY hybrid_id_pe, episode_start_date ORDER BY year_code DESC) AS episode_seq
		FROM sail1409v.LACW_EPISODE_MAIN_20220329 
		WHERE
			local_authority_code IS NOT NULL
			AND system_id_pe IS NOT NULL
			AND year_code IS NOT NULL
			AND episode_start_date IS NOT NULL
	),
	-- for a la-child with multiple records of the same episode use the latest record
	dedup AS
	(
		SELECT *
		FROM format_strings
		WHERE episode_seq = 1
	),
	-- add episode number and
	-- for on-going episodes, set end_date as 9999-01-01 and reason code as 999
	fix_ongoing AS
	(
		SELECT
			hybrid_id_pe,
			la_cd,
			fiscal_year,
			row_number() OVER (PARTITION BY hybrid_id_pe ORDER BY epi_start_dt) AS epi_seq,
			epi_start_dt,
			CASE
				WHEN row_number() OVER (PARTITION BY hybrid_id_pe ORDER BY epi_start_dt DESC) = 1 AND epi_end_dt IS NULL THEN '9999-01-01'
				ELSE epi_end_dt
			END AS epi_end_dt,
			reason_start_cd,
			CASE
				WHEN row_number() OVER (PARTITION BY hybrid_id_pe ORDER BY epi_start_dt DESC) = 1 AND reason_end_cd IS NULL THEN '999'
				ELSE reason_end_cd
			END AS reason_end_cd,
			category_of_need_cd,
			legal_status_cd,
			placement_cd,
			placement_lsoa2011,
			short_break_number
		FROM dedup
	)
SELECT
	fix_ongoing.hybrid_id_pe		AS hybrid_id_pe,
	fix_ongoing.la_cd               AS la_cd,
	lkp_la.name                     AS la_name,
	lkp_la.lad11cd                  AS la_lsoa2011_cd,
	fix_ongoing.fiscal_year         AS fiscal_year,
	fix_ongoing.epi_seq             AS epi_seq,
	fix_ongoing.epi_start_dt        AS epi_start_dt,
	fix_ongoing.epi_end_dt          AS epi_end_dt,
	fix_ongoing.reason_start_cd     AS reason_start_cd,
	lkp_reason_start.name           AS reason_start_nm,
	fix_ongoing.reason_end_cd       AS reason_end_cd,
	lkp_reason_end.name             AS reason_end_nm,
	fix_ongoing.category_of_need_cd AS category_of_need_cd,
	fix_ongoing.legal_status_cd     AS legal_status_cd,
	lkp_legal_status.name           AS legal_status_nm,
	fix_ongoing.placement_cd        AS placement_cd,
	lkp_placement.name              AS placement_nm,
	fix_ongoing.placement_lsoa2011  AS placement_lsoa2011,
	fix_ongoing.short_break_number  AS short_break_number
FROM fix_ongoing
LEFT JOIN sailw1409v.lkp_lacw_la AS lkp_la
	ON fix_ongoing.la_cd = lkp_la.code
LEFT JOIN sailw1409v.lkp_reason_start AS lkp_reason_start
	ON fix_ongoing.reason_start_cd = lkp_reason_start.code
LEFT JOIN sailw1409v.lkp_reason_end AS lkp_reason_end
	ON fix_ongoing.reason_end_cd = lkp_reason_end.code
LEFT JOIN sailw1409v.lkp_legal_status AS lkp_legal_status
	ON fix_ongoing.legal_status_cd = lkp_legal_status.code
LEFT JOIN sailw1409v.lkp_placement AS lkp_placement
	ON fix_ongoing.placement_cd = lkp_placement.code;


-- =================================================================================================
-- Step 4: Derive period of care number
-- =================================================================================================

-- a period of care starts:
--	* on the first ever episode for a child
--	* when an episode starts with reason_cd 'S'

CALL fnc.drop_if_exists('sailw1409v.sa_lac_poc');

CREATE TABLE sailw1409v.sa_lac_poc
(
	hybrid_id_pe		bigint		NOT NULL,
	la_cd               smallint	NOT NULL,
	period_of_care      smallint	NOT NULL,
	poc_start_dt        date		,
	poc_end_dt          date		,
	PRIMARY KEY (hybrid_id_pe, period_of_care)
);

INSERT INTO sailw1409v.sa_lac_poc
WITH
	poc_start AS
	(
		SELECT
			hybrid_id_pe,
			la_cd,
			epi_start_dt AS poc_start_dt,
			row_number() OVER (PARTITION BY hybrid_id_pe ORDER BY epi_start_dt) AS period_of_care
		FROM sailw1409v.sa_lac_epi_prep
		WHERE
			epi_seq = 1
			OR reason_start_cd = 'S'
	)
SELECT
	hybrid_id_pe,
	la_cd,
	period_of_care,
	poc_start_dt,
	coalesce(lead(poc_start_dt) OVER (PARTITION BY hybrid_id_pe ORDER BY poc_start_dt), '9999-01-01') AS poc_end_date
FROM poc_start;


MERGE INTO sailw1409v.sa_lac_epi_prep AS epi
USING sailw1409v.sa_lac_poc AS poc
ON  epi.hybrid_id_pe	=	poc.hybrid_id_pe
AND epi_start_dt		>=	poc.poc_start_dt
AND epi_start_dt		<	poc.poc_end_dt
WHEN matched THEN UPDATE SET
	epi.period_of_care = poc.period_of_care,
	epi.poc_start_dt   = poc.poc_start_dt;


-- =================================================================================================
-- Step 5: Derive placement number
-- =================================================================================================

-- placement number starts from one on first episode within a period of care
-- and increases each time they move placement within that period of care,
-- which is identified by the reason_start_cd

CALL fnc.drop_if_exists('sailw1409v.sa_lac_placement');

CREATE TABLE sailw1409v.sa_lac_placement
(
	hybrid_id_pe		bigint		NOT NULL,
	la_cd               smallint 	NOT NULL,
	period_of_care      smallint	NOT NULL,
	placement_seq       smallint	NOT NULL,
	placement_start_dt  date		,
	placement_end_dt    date		,
	PRIMARY KEY (hybrid_id_pe, period_of_care, placement_seq)
);

INSERT INTO sailw1409v.sa_lac_placement
WITH
	placement_start AS
	(
		SELECT
			hybrid_id_pe, 
			la_cd,
			period_of_care,
			row_number() OVER (PARTITION BY hybrid_id_pe, period_of_care ORDER BY epi_start_dt) AS placement_seq,
			epi_start_dt AS placement_start_dt
		FROM sailw1409v.sa_lac_epi_prep
		WHERE reason_start_cd IN ('S', 'P', 'B')
	)
SELECT
	hybrid_id_pe,
	la_cd,
	period_of_care,
	placement_seq,
	placement_start_dt,
	coalesce(lead(placement_start_dt) OVER (PARTITION BY hybrid_id_pe ORDER BY placement_start_dt), '9999-01-01') AS placement_end_dt
FROM placement_start;


MERGE INTO sailw1409v.sa_lac_epi_prep AS epi
USING sailw1409v.sa_lac_placement AS plc
ON  epi.hybrid_id_pe	= plc.hybrid_id_pe
AND epi.period_of_care  = plc.period_of_care
AND epi_start_dt       >= plc.placement_start_dt
AND epi_start_dt       <  plc.placement_end_dt
WHEN matched THEN UPDATE SET
	epi.placement_seq      = plc.placement_seq,
	epi.placement_start_dt = plc.placement_start_dt;


-- =================================================================================================
-- Step 6: Combine child info with episode info insert into final table
-- =================================================================================================

INSERT INTO sailw1409v.sa_lac_episode
SELECT
	child.alf_pe,
	child.alf_sts_cd,
	child.alf_src,
	child.wob,
	child.sex,
	child.ethnicity,
	child.la_cd,
	epi.la_name,
	epi.la_lsoa2011_cd,
	child.hybrid_id_pe,
	child.disabled_flg,
	child.asylum_flg,
	child.uasc_end_date,
	child.home_lsoa2011,
	epi.period_of_care,
	epi.poc_start_dt,
	epi.fiscal_year,
	epi.placement_seq,
	epi.placement_start_dt,
	epi.epi_seq,
	epi.epi_start_dt,
	epi.epi_end_dt,
	epi.category_of_need_cd,
	epi.reason_start_cd,
	epi.reason_start_nm,
	epi.reason_end_cd,
	epi.reason_end_nm,
	epi.legal_status_cd,
	epi.legal_status_nm,
	epi.placement_cd,
	epi.placement_nm,
	epi.placement_lsoa2011,
	epi.short_break_number
FROM sailw1409v.sa_lac_child AS child
INNER JOIN sailw1409v.sa_lac_epi_prep AS epi
	ON child.hybrid_id_pe = epi.hybrid_id_pe;

-- =================================================================================================
-- Step 7: Tidy up
-- =================================================================================================

CALL fnc.drop_if_exists('sailw1409v.lkp_lacw_la');
CALL fnc.drop_if_exists('sailw1409v.lkp_reason_start');
CALL fnc.drop_if_exists('sailw1409v.lkp_reason_end');
CALL fnc.drop_if_exists('sailw1409v.lkp_legal_status');
CALL fnc.drop_if_exists('sailw1409v.lkp_placement');
CALL fnc.drop_if_exists('sailw1409v.sb_lac_child');
CALL fnc.drop_if_exists('sailw1409v.sb_lac_epi_prep');
CALL fnc.drop_if_exists('sailw1409v.sb_lac_poc');
CALL fnc.drop_if_exists('sailw1409v.sb_lac_placement');


-- =================================================================================================
-- Step 8: Summarise
-- =================================================================================================

-- how many children are in care on 31st March each year?

WITH
	fye_dates AS
	(
		SELECT *
		FROM
		(
			VALUES
			(date('2001-03-31')),
			(date('2002-03-31')),
			(date('2003-03-31')),
			(date('2004-03-31')),
			(date('2005-03-31')),
			(date('2006-03-31')),
			(date('2007-03-31')),
			(date('2008-03-31')),
			(date('2009-03-31')),
			(date('2010-03-31')),
			(date('2011-03-31')),
			(date('2012-03-31')),
			(date('2013-03-31')),
			(date('2014-03-31')),
			(date('2015-03-31')),
			(date('2016-03-31')),
			(date('2017-03-31')),
			(date('2018-03-31')),
			(date('2019-03-31'))
		) AS fye(fye_dt)
	)
SELECT
	fye_dates.fye_dt AS fye,
	count(DISTINCT hybrid_id_pe) AS n_child,
	count(DISTINCT alf_pe) AS n_alf
FROM sailw1409v.sa_lac_episode
INNER JOIN fye_dates
	ON fye_dates.fye_dt BETWEEN epi_start_dt AND epi_end_dt
GROUP BY fye_dates.fye_dt
ORDER BY fye_dates.fye_dt;

