-- =================================================================================================
-- Name:         All births in Wales from 1 January 2000
-- Data sources: ADBE, ADDE, MIDS, NCCH, WDSD
-- Maintainers:  Sarah
-- Created:      yyyy/mm/dd
-- Description:  This script builds 3 tables and consort tables 
-- 		The child cohort 	- 	a list of all children who have lived in Wales before they turned 18 
--							and who were born from Jan 1st 2000 onwards. This table pulls all records 
--							from WDSD with a wob between 01/01/2000 and 31/12/2024 and who's record 
-- 							is before they turned 18
-- 		The Birth cohort 	- 	a list of all babies born in Wales from Jan 1s 2000 onwards detailing 
-- 							things relevent to the mother and child at time OF birth
-- 							This is acheieved by stacking birth records from NCCH, MIDS, and ADBE. 
--							NCCH forms the primary source as it has the best combination of temporal 
--							coverage and detail, with records start from 1989, maternal ALF and 
--							maternal background and perinatal info. MIDS has the added benefit of
--  			            information from the midwife's initial assessment but records start from 
--							2015. ADBE is almost identical to NCCH in terms of temporal coverage, but 
--							lacks mother ID, though does provide info on occupation and individual 
--							socio-economic class not available elsewhere. We also import information 
--							from WDSD regarding WIMD and create a series of flags indicating data 
--							source and highlighing possible mismatches.
--               			Recorded values for birth weight, breast feeding are merged from all 
--							sources. Parity and number of previous live births, if missing, are derived 
--							from a rolling sum across existing records. Both child and mother area 
--							demographics are defined at closest to birth using WDSD. Child death info 
--							is based on ADDE, and flags are derived for common causes of infant 
--							mortality.
--               			Trimester and pre-term birth start and end dates are derived for 
--							convenience  and to enable consistency, when studying events during 
--							pregnancy. All intervals are calculated using wob and gestational age, if 
--							gestational age is unavailable, we assume a value of 40 weeks.
-- 		The mother cohort 	- 	a list of all the mothers linked to babies in the birth cohort born 
--							after 2000 living in wales. We link mothers from the 
 		

-- =================================================================================================
-- 1.0 create table to records counts for consort diagram
-- =================================================================================================

CALL fnc.drop_if_exists('sailw1409v.consort_values_child');

CREATE TABLE sailw1409v.consort_values_child
(
	description 	varchar(100),
	step			integer,
	cat				varchar(12),
	n				integer
);

-- =================================================================================================
-- 1.1 create the child cohort
-- =================================================================================================
-- identify all children to have registerd in Wales who were born on or after 2000-01-01

CALL fnc.drop_if_exists('sailw1409v.child_cohort');

CREATE TABLE sailw1409v.child_cohort
(
    alf_pe		BIGINT,
    wob 		DATE,
    dod 		DATE,
    sex			varchar(1),
    ethnicity  	varchar(15),
    cohort_entry_date DATE
);

INSERT INTO sailw1409v.child_cohort 
SELECT distinct
	wdsd.alf_pe,
	wdsd.wob,
	wdsd.dod,
	CAST(wdsd.gndr_cd AS varchar) AS sex,
	ethn.ETHN_EC_ONS_DATE_LATEST_DESC AS ethnicity,
	min(gp.activefrom) cohort_entry_date
FROM 
	SAIL1409V.WDSD_SINGLE_CLEAN_AR_PERS_20240812 wdsd
LEFT JOIN
	SAIL1409V.WDSD_PER_RESIDENCE_GPREG_20240205 gp
using(alf_pe)
LEFT JOIN 
	SAILW1409V.RRDA_ETHN ethn
using(alf_pe)
group BY wdsd.alf_pe, wdsd.wob, wdsd.dod, wdsd.gndr_cd, ethn.ETHN_EC_ONS_DATE_LATEST_DESC
;

GRANT ALL ON TABLE sailw1409v.child_cohort
TO ROLE nrdasail_sail_1409_analyst;

-- apply filters and population consort diagram
INSERT INTO sailw1409v.consort_values_child
SELECT * FROM (
	SELECT 'all wdsd rows' AS description, 0 AS step, 'all rows' as cat, count (*) AS n FROM SAIL1409V.WDSD_SINGLE_CLEAN_AR_PERS_20240812
	UNION
	SELECT 'wdsd unique alf' AS description, 0 AS step, 'distinct alf' AS cat, count (DISTINCT alf_pe) AS n FROM SAIL1409V.WDSD_SINGLE_CLEAN_AR_PERS_20240812
	UNION
	SELECT 'all child cohort rows' AS description, 1 AS step, 'all rows' as cat, count (*) AS n FROM SAILW1409V.child_cohort
	UNION
	SELECT 'child cohort unique alf' AS description, 1 AS step, 'distinct alf' AS cat, count (DISTINCT alf_pe) AS n FROM SAILW1409V.child_cohort
	);

DELETE FROM sailw1409v.child_cohort
WHERE alf_pe IS NULL;

INSERT INTO sailw1409v.consort_values_child
SELECT * FROM (
	SELECT 'all child cohort rows - remove null alfs' AS description, 2 AS step, 'all rows' as cat, count (*) AS n FROM SAILW1409V.child_cohort
	UNION
	SELECT 'child cohort unique alf - remove null alfs' AS description, 2 AS step, 'distinct alf' AS cat, count (DISTINCT alf_pe) AS n FROM SAILW1409V.child_cohort
	)
;

DELETE FROM sailw1409v.child_cohort
WHERE sex IS NULL;

INSERT INTO sailw1409v.consort_values_child
SELECT * FROM (
	SELECT 'all child cohort rows - remove null sex' AS description, 3 AS step, 'all rows' AS cat, count (*) AS n FROM SAILW1409V.child_cohort
	UNION
	SELECT 'child cohort unique alf - remove null sex' AS description, 3 AS step, 'distinct alf' AS cat, count (DISTINCT alf_pe) AS n FROM SAILW1409V.child_cohort
	)
;

DELETE FROM sailw1409v.child_cohort
WHERE 
	WOB < '2000-01-01'
OR 
	wob > CURRENT date
OR 
	wob IS NULL ;

INSERT INTO sailw1409v.consort_values_child
SELECT * FROM (
	SELECT 'all child cohort rows - 2000-01-01 <= wob <= today' AS description, 4 AS step, 'all rows' AS cat, count (*) AS n FROM SAILW1409V.child_cohort
	UNION
	SELECT 'child cohort unique alf - 2000-01-01 <= wob <= today' AS description, 4 AS step, 'distinct alf' AS cat, count (DISTINCT alf_pe) AS n FROM SAILW1409V.child_cohort
	)
;
-- remove cohort entry dates that are age 18+

DELETE FROM sailw1409v.child_cohort
WHERE 
	floor((days(date(cohort_entry_date)) - days(wob)) / 365.25) >= 18
OR 
	cohort_entry_date IS NULL ;

INSERT INTO sailw1409v.consort_values_child
SELECT * FROM (
	SELECT 'all child cohort rows - valid cohort entry' AS description, 5 AS step, 'all rows' AS cat, count (*) AS n FROM SAILW1409V.child_cohort
	UNION
	SELECT 'child cohort unique alf - valid cohort entry' AS description, 5 AS step, 'distinct alf' AS cat, count (DISTINCT alf_pe) AS n FROM SAILW1409V.child_cohort
	)
;

-- =================================================================================================
-- 2.0 create table to records counts for consort diagram
-- =================================================================================================

CALL fnc.drop_if_exists('sailw1409v.consort_values_birth');

CREATE TABLE sailw1409v.consort_values_birth
(
	description 	varchar(100),
	src				varchar(12),
	step			integer,
	cat 			varchar(15),
	n				integer
);

-- =================================================================================================
-- 2.1 create the birth table
-- =================================================================================================
-- link the birth details to the child cohort where possible

CALL fnc.drop_if_exists('sailw1409v.birth_cohort');

CREATE TABLE sailw1409v.birth_cohort
(
	-- child
    c_alf_pe                         bigint NOT NULL,     -- Child ALF
    c_alf_sts_cd                     varchar(2),          -- Child's matching status
    c_wob                            date,                -- Week of birth for child
    c_stillbirth_flg                 smallint,            -- 0/1 flag for whether baby was stillborn
    c_sex                            varchar(1),          -- Sex of child: 1/2
    c_ethnicity		                 varchar(60),         -- NCCH and MIDS labels, supplemented by latest recorded in either GP or hospital records
    c_birth_weight                   integer,             -- Birth weight in grams
    c_gestational_age                smallint,            -- Gestational age (weeks)
    c_preterm_birth_flg              smallint,            -- 0/1 flag for whether gestation age was under 37 weeks
    c_apgar_score                    smallint,            -- Total Apgar score at 5 minutes after birth, a measure of physical condition
    c_labour_onset_nm                varchar(60),         -- How labour began or delivery by caesarean section
    c_delivery_nm                    varchar(60),         -- Mode of birth
    c_welsh_birth_flg                smallint,            -- 0/1 flag for whether mother is a Welsh resident
    c_residence_start_date           date,                -- Start date of living in Wales
    c_residence_end_date             date,                -- End date of living in Wales
    c_lsoa2011_cd                    varchar(10),         -- LSOA 2011 code of child's first area of residence at week of birth
    c_wimd2014_decile                smallint,            -- WIMD 2014 decile for child's first LSOA: 1 = most, 10 = least
    c_wimd2019_decile                smallint,            -- WIMD 2019 decile for child's first LSOA: 1 = most, 10 = least
    c_wimd2014_quintile              smallint,            -- WIMD 2014 quintile for child's first LSOA: 1 = most, 5 = least
    c_wimd2019_quintile              smallint,            -- WIMD 2019 quintile for child's first LSOA: 1 = most, 5 = least
    c_townsend2011_quintile          smallint,            -- Townsend 2011 quintile for the LSOA: 1 = most, 5 = least
    c_death_date                     date,                -- Week of death for the child, from ADDE only
    c_death_neonatal_flg             smallint,            -- 0/1 flag for if death is in first 27 days of life
    c_death_birth_asphyxia_flg       smallint,            -- 0/1 flag for if any diag code is P21*
    c_death_short_gestation_flg      smallint,            -- 0/1 flag for if any diag code is P07*
    c_death_sids_flg                 smallint,            -- 0/1 flag for if any diag code is R95*
    c_death_diag_cd                  varchar(5),          -- Primary ICD-10 code for cause of death
    -- mother
    m_alf_pe                         bigint,              -- Mother ALF
    m_alf_sts_cd                     varchar(2),          -- Mother's matching status
    m_consistent_flg				 SMALLINT,			  -- Consistent maternal record - m_alf <> = alf and alf linked to max 1 m_alf			
    m_wob                            date,                -- Week of birth for mother
    m_age                            smallint,            -- Age of mother at week of birth
    m_sex                            varchar(1),          -- Sex of mother: m/f
    m_prev_livebirths                smallint,            -- Number of previous live births for mother
    m_parity                         smallint,            -- Number of previous live births and stillbirths
    m_multiple_gestation_flg         smallint,            -- 0/1 flag for multiple gestation e.g. twins
    m_breast_feeding_intent_flg      smallint,            -- 0/1 flag for whether mother intends to breast feed (MIDS only)
    m_breast_feeding_birth_flg       smallint,            -- 0/1 flag for whether mother is breast feeding from birth (NCCH only)
    m_breast_feeding_8wks_flg        smallint,            -- 0/1 flag for whether mother was breast feeding between weeks 6-8 (NCCH only)
    m_lsoa2011_cd                    varchar(10),         -- LSOA 2011 code of mother's last known welsh area of residence, up to 1 year before birth
    m_wimd2014_decile                smallint,            -- WIMD 2014 decile for mother's LSOA: 1 = most, 10 = least
    m_wimd2019_decile                smallint,            -- WIMD 2019 decile for mother's LSOA: 1 = most, 10 = least
    m_wimd2014_quintile              smallint,            -- WIMD 2014 quintile for child's first LSOA: 1 = most, 5 = least
    m_wimd2019_quintile              smallint,            -- WIMD 2019 quintile for child's first LSOA: 1 = most, 5 = least
    m_townsend2011_quintile          smallint,            -- Townsend 2011 quintile for mother's LSOA: 1 = most, 5 = least
    m_smoking_cat                    varchar(3),          -- smoking status: Non, Ex, Smk
    m_marriage_cd                    smallint,            -- ADBE code for marriage status at birth code
    m_birth_country_nm               varchar(26),         -- Name of mother's birth country
    m_birth_region_nm                varchar(13),         -- Name of mother's birth region: UK, EU, Not stated
    m_socioeconomic_class_cd         varchar(4),          -- ADBE code
    m_occ_class_cd                   varchar(4),          -- ADBE code
    m_ethnicity                   	 varchar(60),         -- MIDS labels, supplemented by latest recorded in either GP or hospital records
    m_death_date                     date,                -- Week of death for the mother, from ADDE only
    m_death_diag_cd                  varchar(5),          -- Primary ICD-10 code for cause of death
    p_trimester1_start_date          date,                -- Start date of trimester 1 during pregnancy: gestational age 0 weeks
    p_trimester2_start_date          date,                -- Start date of trimester 2 during pregnancy: gestational age 12 weeks
    p_trimester3_start_date          date,                -- Start date of trimester 3 during pregnancy: gestational age 24 weeks
    p_preterm_start_date             date,                -- Start date for pre-term birth interval: gestational age 28 weeks
    p_preterm_end_date               date,                -- End date for pre-term birth interval: gestational age 36 weeks and 6 days
    in_ncch                          smallint DEFAULT 0,  -- Is birth recorded in NCCH data source?
    in_mids                          smallint DEFAULT 0,  -- Is birth recorded in MIDS data source?
    in_adbe                          smallint DEFAULT 0,  -- Is birth recorded in ADBE data source?
    flg_wob_wlgp_mismatch			 smallint DEFAULT 0,  -- Is there a mismatch in wobs between birth table and wlgp?
	flg_wob_wdsd_mismatch 			 smallint DEFAULT 0,  -- Is there a mismatch in wobs between birth table and wdsd?
	flg_incon_mat_alf   			 smallint DEFAULT 0,  -- Are mat alfs inconsistent?
	flg_incon_child_alf				 SMALLINT DEFAULT 0,  -- Is the child and mat alf the same?
	flg_mwob_wlgp_mismatch			 smallint DEFAULT 0,  -- Is there a mismatch in m_wobs between birth table and wlgp?
	flg_mwob_wdsd_mismatch			 smallint DEFAULT 0,  -- Is there a mismatch in m_wobs between birth table and wdsd?
	
    PRIMARY KEY (c_alf_pe)

);

GRANT ALL ON TABLE sailw1409v.birth_cohort
TO ROLE nrdasail_sail_1409_analyst;

-- =================================================================================================
-- Step 2.2: Insert from NCCH birth table
-- =================================================================================================

INSERT INTO sailw1409v.birth_cohort
(
    c_alf_pe,
    c_alf_sts_cd,
    c_wob,
    c_stillbirth_flg,
    c_sex,
    c_ethnicity,
    c_birth_weight,
    c_gestational_age,
    c_preterm_birth_flg,
    c_apgar_score,
    c_labour_onset_nm,
    c_delivery_nm,
    c_welsh_birth_flg,
    m_alf_pe,
    m_alf_sts_cd,
    m_ethnicity,
    m_prev_livebirths,
    m_parity,
    m_multiple_gestation_flg,
    m_age,
    m_breast_feeding_birth_flg,
    m_breast_feeding_8wks_flg,
    m_smoking_cat
)
WITH
    ncch AS
    (
        SELECT
            ncch_birth.alf_pe                                                   AS alf_pe,
            ncch_birth.alf_sts_cd                                               AS c_alf_sts_cd,
            ncch_birth.wob                                                      AS c_wob,
            ncch_birth.stillbirth_flg                                           AS c_stillbirth_flg,
            CASE 
            	WHEN ncch_birth.gndr_cd = 'M' OR ncch_birth.gndr_cd = '1' THEN '1'
            	WHEN ncch_birth.gndr_cd = 'F' OR ncch_birth.gndr_cd = '2' THEN '2'
            END	  			                                                    AS c_sex,
            ethn_c.ethn_ec_ons_date_latest_desc                                 AS c_ethnicity,
            cast(ncch_birth.birth_weight * 1000 AS integer)                     AS c_birth_weight, -- Convert kilograms to grams
            cast(ncch_birth.gest_age AS smallint)                               AS c_gestational_age,
            CASE
                WHEN cast(ncch_birth.gest_age AS smallint) <  37 THEN 1
                WHEN cast(ncch_birth.gest_age AS smallint) >= 37 THEN 0
            END                                                                 AS c_preterm_birth_flg,
            lkp_onset.main_description_60_chars                                 AS c_labour_onset_nm,
            lkp_delivery.main_description_60_chars                              AS c_delivery_nm,
            ncch_birth.welsh_birth_flg                                          AS c_welsh_birth_flg,
            ncch_birth.apgar_2                                                  AS c_apgar_score,
            ncch_birth.mat_alf_pe                                               AS m_alf_pe,
            ncch_birth.mat_alf_sts_cd                                           AS m_alf_sts_cd,
            ethn_m.ethn_ec_ons_date_latest_desc                                 AS m_ethnicity,
            ncch_birth.prev_live_births                                         AS m_prev_livebirths,
            ncch_birth.prev_live_births + ncch_birth.prev_stillbirth            AS m_parity,
            CASE
                WHEN ncch_birth.tot_birth_num >= 2 THEN 1
                ELSE 0
            END                                                                 AS m_multiple_gestation_flg,
            ncch_birth.mat_age                                                  AS m_age,
            CASE
                WHEN ncch_birth.breastfeed_birth_flg      IS NOT NULL THEN ncch_birth.breastfeed_birth_flg
                WHEN ncch_child.age_breastfeed_ceased_wks >= 1        THEN 1
                WHEN ncch_child.age_breastfeed_ceased_wks IS NOT NULL THEN 0
            END                                                                 AS m_breast_feeding_birth_flg,
            CASE
                WHEN ncch_birth.breastfeed_8_wks_flg      IS NOT NULL THEN ncch_birth.breastfeed_8_wks_flg
                WHEN ncch_child.age_breastfeed_ceased_wks >= 8        THEN 1
                WHEN ncch_child.age_breastfeed_ceased_wks IS NOT NULL THEN 0
            END                                                                 AS m_breast_feeding_8wks_flg,
            CASE
                WHEN ncch_birth.mat_smoking_cd = '0' THEN 'Non'
                WHEN ncch_birth.mat_smoking_cd = '1' THEN 'Ex'
                WHEN ncch_birth.mat_smoking_cd IN ('2', '3', '4', '6') THEN 'Smk'
                ELSE ''
            END                                                                 AS m_smoking_cat,
            ROW_NUMBER () over (partition BY ncch_birth.alf_pe)                 AS alf_row_num
        FROM
            sail1409v.NCCH_CHILD_BIRTHS_20240201                AS ncch_birth
        LEFT JOIN
            sail1409v.ncch_child_trust_20240201                 AS ncch_child
            ON ncch_birth.alf_pe = ncch_child.alf_pe
        LEFT JOIN
           sailw1409v.rrda_ethn                        			AS ethn_c
            ON ncch_birth.alf_pe = ethn_c.alf_pe
        LEFT JOIN
           sailw1409v.rrda_ethn                        			AS ethn_m
            ON ncch_birth.mat_alf_pe = ethn_m.alf_pe
        LEFT JOIN
            sailukhdv.dd_wales_labour_delivery_onset_method_scd AS lkp_onset
            ON ncch_birth.labour_onset_cd = lkp_onset.main_code_text
        LEFT JOIN
            sailukhdv.dd_wales_delivery_method_scd              AS lkp_delivery
            ON ncch_birth.del_cd = lkp_delivery.main_code_text
        LEFT JOIN
             sailw1409v.birth_cohort                         	AS main
             ON ncch_birth.alf_pe = main.c_alf_pe
        WHERE
            ncch_birth.alf_pe IS NOT NULL
            AND main.c_alf_pe IS NULL
            AND ncch_birth.alf_sts_cd IN ('1', '4', '39', '21', '22', '23', '24')
    )
SELECT
    alf_pe,
    c_alf_sts_cd,
    c_wob,
    c_stillbirth_flg,
    c_sex,
    c_ethnicity,
    c_birth_weight,
    c_gestational_age,
    c_preterm_birth_flg,
    c_apgar_score,
    c_labour_onset_nm,
    c_delivery_nm,
    c_welsh_birth_flg,
    m_alf_pe,
    m_alf_sts_cd,
    m_ethnicity, 
    m_prev_livebirths,
    m_parity,
    m_multiple_gestation_flg,
    m_age,
    m_breast_feeding_birth_flg,
    m_breast_feeding_8wks_flg,
    m_smoking_cat
FROM
    ncch
WHERE
    alf_row_num = 1
;

-- =================================================================================================
-- Step 2.3: Insert from NCCH child trust table
-- =================================================================================================
INSERT INTO sailw1409v.birth_cohort
(
    c_alf_pe,
    c_alf_sts_cd,
    c_wob,
    c_stillbirth_flg,
    c_sex,
    c_ethnicity,
    c_birth_weight,
    c_gestational_age,
    c_preterm_birth_flg,
    c_apgar_score,
    c_labour_onset_nm,
    c_delivery_nm,
    c_welsh_birth_flg,
    m_alf_pe,
    m_alf_sts_cd,
    m_ethnicity,
    m_prev_livebirths,
    m_parity,
    m_multiple_gestation_flg,
    m_age,
    m_breast_feeding_birth_flg,
    m_breast_feeding_8wks_flg,
    m_smoking_cat
)
WITH
    ncch AS
    (
        SELECT
            ncch_child.alf_pe                                                       AS c_alf_pe,
            ncch_child.alf_sts_cd                                                   AS c_alf_sts_cd,
            date(ncch_child.wob)                                                    AS c_wob,
            0                                                                       AS c_stillbirth_flg,
            CASE 
            	WHEN ncch_child.gndr_cd = 'M' OR ncch_child.gndr_cd = '1' THEN '1'
            	WHEN ncch_child.gndr_cd = 'F' OR ncch_child.gndr_cd = '2' THEN '2'
            END	  			                                                    	AS c_sex,
            ethn_c.ethn_ec_ons_date_latest_desc                                     AS c_ethnicity,
            cast(ncch_child.birth_weight * 1000 AS integer)                         AS c_birth_weight, -- Convert kilograms to grams
            cast(ncch_child.gestation_age AS smallint)                              AS c_gestational_age,
            CASE
                WHEN cast(ncch_child.gestation_age AS smallint) <  37 THEN 1
                WHEN cast(ncch_child.gestation_age AS smallint) >= 37 THEN 0
            END                                                                     AS c_preterm_birth_flg,
            ncch_child.apgar_2                                                      AS c_apgar_score,
            lkp_onset.main_description_60_chars                                     AS c_labour_onset_nm,
            lkp_delivery.main_description_60_chars                                  AS c_delivery_nm,
            ncch_child.mat_alf_pe                                                   AS m_alf_pe,
            ncch_child.mat_alf_sts_cd                                               AS m_alf_sts_cd,
            ethn_m.ethn_ec_ons_date_latest_desc                                     AS m_ethnicity,
            ncch_child.prev_live_births                                             AS m_prev_livebirths,
            ncch_child.prev_live_births + ncch_child.prev_stillbirth                AS m_parity,
            1                                                                       AS c_welsh_birth_flg,
            CASE
                WHEN ncch_child.tot_birth_num >= 2 THEN 1
                ELSE 0
            END                                                                     AS m_multiple_gestation_flg,
            floor((days(date(ncch_child.wob)) - days(ncch_child.mat_wob)) / 365.25) AS m_age,
            CASE
                WHEN ncch_birth.breastfeed_birth_flg      IS NOT NULL THEN ncch_birth.breastfeed_birth_flg
                WHEN ncch_child.age_breastfeed_ceased_wks >= 1        THEN 1
                WHEN ncch_child.age_breastfeed_ceased_wks IS NOT NULL THEN 0
            END                                                                     AS m_breast_feeding_birth_flg,
            CASE
                WHEN ncch_birth.breastfeed_8_wks_flg      IS NOT NULL THEN ncch_birth.breastfeed_8_wks_flg
                WHEN ncch_child.age_breastfeed_ceased_wks >= 8        THEN 1
                WHEN ncch_child.age_breastfeed_ceased_wks IS NOT NULL THEN 0
            END                                                                     AS m_breast_feeding_8wks_flg,
            CASE
                WHEN ncch_child.mat_smoking_cd = '0' THEN 'Non'
                WHEN ncch_child.mat_smoking_cd = '1' THEN 'Ex'
                WHEN ncch_child.mat_smoking_cd IN ('2', '3', '4', '6') THEN 'Smk'
                ELSE ''
            END                                                                     AS m_smoking_cat,
            row_number () OVER (PARTITION BY ncch_child.alf_pe)                     AS alf_row_num
        FROM
            sail1409v.ncch_child_trust_20240201                                     AS ncch_child
        LEFT JOIN
            sail1409v.ncch_child_births_20240201                                    AS ncch_birth
            ON ncch_child.alf_pe = ncch_birth.alf_pe
        LEFT JOIN
            sailw1409v.rrda_ethn                              	        			AS ethn_c
            ON ncch_child.alf_pe = ethn_c.alf_pe
        LEFT JOIN
            sailw1409v.rrda_ethn                              	        			AS ethn_m
            ON ncch_child.mat_alf_pe = ethn_m.alf_pe
        LEFT JOIN
            sailukhdv.dd_wales_labour_delivery_onset_method_scd                     AS lkp_onset
            ON ncch_child.labour_onset_cd = lkp_onset.main_code_text
        LEFT JOIN
            sailukhdv.dd_wales_delivery_method_scd                                  AS lkp_delivery
            ON ncch_child.del_cd = lkp_delivery.main_code_text
        LEFT JOIN
            sailw1409v.birth_cohort                                              	AS main
            ON ncch_child.alf_pe = main.c_alf_pe
        WHERE
            ncch_child.alf_pe IS NOT NULL
            AND main.c_alf_pe IS NULL
            AND ncch_child.alf_sts_cd IN ('1', '4', '39', '21', '22', '23', '24')
)
SELECT
    c_alf_pe,
    c_alf_sts_cd,
    c_wob,
    c_stillbirth_flg,
    c_sex,
    c_ethnicity,
    c_birth_weight,
    c_gestational_age,
    c_preterm_birth_flg,
    c_apgar_score,
    c_labour_onset_nm,
    c_delivery_nm,
    c_welsh_birth_flg,
    m_alf_pe,
    m_alf_sts_cd,
    m_ethnicity,
    m_prev_livebirths,
    m_parity,
    m_multiple_gestation_flg,
    m_age,
    m_breast_feeding_birth_flg,
    m_breast_feeding_8wks_flg,
    m_smoking_cat
FROM
    ncch
WHERE
    alf_row_num = 1;

-- =================================================================================================
-- Step 2.4: Insert from MIDS tables
-- =================================================================================================

INSERT INTO sailw1409v.birth_cohort
(
   c_alf_pe,
   c_alf_sts_cd,
   c_wob,
   c_stillbirth_flg,
   c_sex,
   c_ethnicity,
   c_birth_weight,
   c_gestational_age,
   c_preterm_birth_flg,
   c_apgar_score,
   c_labour_onset_nm,
   c_delivery_nm,
   m_alf_pe,
   m_alf_sts_cd,
   m_ethnicity,
   m_parity,
   m_multiple_gestation_flg,
   m_age,
   m_breast_feeding_intent_flg
)
WITH
    -- only use initial assessment data if its at most 280 days prior to the birth
    init_ass AS
    (
        SELECT init_ass.*
        FROM
            sail1409v.mids_initial_assessment_20240201 AS init_ass
        INNER JOIN
            sail1409v.mids_birth_20240201                        AS birth
            ON  init_ass.mother_alf_pe = birth.mother_alf_pe
            AND init_ass.initial_ass_dt >= (birth.baby_birth_dt - 280 days)
            AND init_ass.initial_ass_dt <= (birth.baby_birth_dt)
    ),
    mids AS
    (
        SELECT
            birth.child_alf_pe                                   AS c_alf_pe,
            birth.child_alf_sts_cd                               AS c_alf_sts_cd,
            birth.baby_birth_dt                                  AS c_wob,
            CASE
                WHEN birth.birth_outcome_cd = 2 THEN 1
                WHEN birth.birth_outcome_cd = 1 THEN 0
            END                                                  AS c_stillbirth_flg,
            CASE 
            	WHEN birth.service_user_sex_cd = 'M' OR birth.service_user_sex_cd = '1' THEN '1'
            	WHEN birth.service_user_sex_cd = 'F' OR birth.service_user_sex_cd = '2' THEN '2'
            END	  			                                     AS c_sex,
            ethn_c.ethn_ec_ons_date_latest_desc                  AS c_ethnicity,
            cast(birth.service_user_weight_grams AS integer)     AS c_birth_weight,
            birth.labour_onset_gest_weeks                        AS c_gestational_age,
            CASE
                WHEN birth.labour_onset_gest_weeks  < 37 THEN 1
                WHEN birth.labour_onset_gest_weeks >= 37 THEN 0
            END                                                  AS c_preterm_birth_flg,
            birth.birth_apgar_score                              AS c_apgar_score,
            lkp_onset.main_description_60_chars                  AS c_labour_onset_nm,
            lkp_delivery.main_description_60_chars               AS c_delivery_nm,
            birth.mother_alf_pe                                  AS m_alf_pe,
            birth.mother_alf_sts_cd                              AS m_alf_sts_cd,
            ethn_m.ethn_ec_ons_date_latest_desc                  AS m_ethnicity,
            init_ass.service_user_parity_cd                      AS m_parity,
            CASE
                WHEN birth.labour_onset_foetus_num >= 2 THEN 1
                ELSE 0
            END                                                  AS m_multiple_gestation_flg,
            birth.mat_age                                        AS m_age,
            CASE
                WHEN birth.mat_intends_breast_feeding_cd = 1 THEN 1
                WHEN birth.mat_intends_breast_feeding_cd = 2 THEN 0
            END                                                  AS m_breast_feeding_intent_flg,
            row_number () OVER (PARTITION BY birth.child_alf_pe) AS alf_row_num
        FROM
            sail1409v.mids_birth_20240201                        AS birth
        LEFT JOIN
            init_ass
            ON init_ass.mother_alf_pe = birth.mother_alf_pe
        LEFT JOIN
            sailukhdv.dd_wales_mode_of_onset_of_labour_scd       AS lkp_onset
            ON birth.labour_onset_mode_cd = lkp_onset.main_code_text
        LEFT JOIN
            sailukhdv.dd_wales_mode_of_birth_scd                 AS lkp_delivery
            ON birth.birth_mode_cd = lkp_delivery.main_code_text
        LEFT JOIN
            sailw1409v.rrda_ethn                              	 AS ethn_c
            ON birth.child_alf_pe = ethn_c.alf_pe
        LEFT JOIN
            sailw1409v.rrda_ethn                              	 AS ethn_m
            ON birth.mother_alf_pe = ethn_m.alf_pe
        LEFT JOIN
            sailw1409v.birth_cohort                           	 AS main
            ON birth.child_alf_pe = main.c_alf_pe
        WHERE
            birth.child_alf_pe IS NOT NULL
            AND main.c_alf_pe IS NULL
            AND birth.child_alf_sts_cd IN ('1', '4', '39')
    )
SELECT
    c_alf_pe,
    c_alf_sts_cd,
    c_wob,
    c_stillbirth_flg,
    c_sex,
    c_ethnicity,
    c_birth_weight,
    c_gestational_age,
    c_preterm_birth_flg,
    c_apgar_score,
    c_labour_onset_nm,
    c_delivery_nm,
    m_alf_pe,
    m_alf_sts_cd,
    m_ethnicity,
    m_parity,
    m_multiple_gestation_flg,
    m_age,
    m_breast_feeding_intent_flg
FROM
    mids
WHERE
    alf_row_num = 1;


-- =================================================================================================
-- Step 2.5: Insert from ADBE table
-- =================================================================================================
select * FROM sail1409v.adbe_births_20240101;
INSERT INTO sailw1409v.birth_cohort
(
    c_alf_pe,
    c_alf_sts_cd,
    c_wob,
    c_stillbirth_flg,
    c_sex,
    c_ethnicity,
    c_birth_weight,
    m_multiple_gestation_flg
)

SELECT DISTINCT
    adbe.alf_pe                                              AS c_alf_pe,
    adbe.alf_sts_cd                                          AS c_alf_sts_cd,
    date(adbe.wob)                                           AS c_wob,
    coalesce(cast(adbe.stillbirth_ind AS smallint), 0)       AS c_stillbirth_flg,
    CASE 
    	WHEN adbe.nenonate_sex_cd = 'M' OR adbe.nenonate_sex_cd = '1' THEN '1'
        WHEN adbe.nenonate_sex_cd = 'F' OR adbe.nenonate_sex_cd = '2' THEN '2'
    END	  			                                     	 AS c_sex,
    ethn_c.ethn_ec_ons_date_latest_desc                  	 AS c_ethnicity,
    cast(adbe.birth_weight AS integer)                       AS c_birth_weight,
    coalesce(cast(adbe.multiplebirth_ind_cd AS smallint), 0) AS m_multiple_gestation_flg
FROM
    sail1409v.adbe_births_20240101    AS adbe
LEFT JOIN
    sailw1409v.birth_cohort        AS main
    ON adbe.alf_pe = main.c_alf_pe
LEFT JOIN
    sailw1409v.rrda_ethn                              	 AS ethn_c
    ON adbe.alf_pe = ethn_c.alf_pe
WHERE
    adbe.alf_pe IS NOT NULL
    AND main.c_alf_pe IS NULL
   	AND c_alf_pe IN ('1', '4', '39');

   -- =================================================================================================
-- Step : Flag consistency of mothers
-- =================================================================================================

-- Check for consistent maternal record i.e. m_alf <> = child_alf and alf linked to max 1 m_alf	

CALL fnc.drop_if_exists('sailw1409v.sa_m_consistent_flg');
CREATE TABLE sailw1409v.sa_m_consistent_flg
(
    c_alf_pe        	bigint  NOT NULL,
    m_consistent_flg 	integer ,
    PRIMARY KEY (c_alf_pe)
);

INSERT INTO sailw1409v.sa_m_consistent_flg
WITH
	ncch AS (
		SELECT
			alf_pe AS c_alf_pe,
			date(wob) AS c_wob,
			mat_alf_pe AS m_alf_pe
		FROM sail1409v.ncch_child_births_20240201
		WHERE alf_pe <> mat_alf_pe
		AND alf_sts_cd IN ('1', '4', '39', '21', '22', '23', '24')
		AND wob IS NOT null
	),
	mids AS (
		SELECT 
			child_alf_pe AS c_alf_pe,
			date(baby_birth_dt) AS c_wob,
			mother_alf_pe AS m_alf_pe
		FROM sail1409v.mids_birth_20240201
		WHERE child_alf_pe <> mother_alf_pe
		AND child_alf_sts_cd IN ('1', '4', '39')
		AND baby_birth_dt IS NOT null
	),
	bind_rows AS
    (
        SELECT c_alf_pe FROM ncch
        UNION 
        SELECT c_alf_pe FROM mids
        WHERE m_alf_pe IS NOT null
    ),
    all1 AS 
    (
		SELECT distinct
			bind_rows.c_alf_pe,
			CASE 
				WHEN ncch.m_alf_pe = mids.m_alf_pe THEN 1 -- ncch and mids alf match
				WHEN ncch.m_alf_pe IS NULL THEN 1 -- mat alf only avaiable in mids
				WHEN mids.m_alf_pe IS NULL THEN 1 -- mat alf only avaiable in ncch
				ELSE NULL 
				END AS m_consistent_flg
		FROM bind_rows
		LEFT JOIN ncch
			ON bind_rows.c_alf_pe = ncch.c_alf_pe
		LEFT JOIN mids
			ON bind_rows.c_alf_pe = mids.c_alf_pe
	)
SELECT * FROM 
all1
where m_consistent_flg IS NOT NULL
;

MERGE INTO sailw1409v.birth_cohort AS cohort
USING sailw1409v.sa_m_consistent_flg AS mc
ON  cohort.c_alf_pe = mc.c_alf_pe
WHEN MATCHED THEN UPDATE SET
    cohort.m_consistent_flg = mc.m_consistent_flg;


-- =================================================================================================
-- clean and populate consort table
-- =================================================================================================

 
INSERT INTO sailw1409v.consort_values_birth
SELECT * FROM (
	SELECT 'starting population - unique alf' AS description, 'ncch' AS src, 0 AS step, 'distinct alf' AS cat, count (DISTINCT alf_pe) AS n FROM SAIL1409V.NCCH_CHILD_BIRTHS_20240201 
	UNION
	SELECT 'starting population - unique alf' AS description, 'mids' AS src, 0 AS step, 'distinct alf' AS cat, count (DISTINCT child_alf_pe) AS n FROM SAIL1409V.MIDS_BIRTH_20240201 
	UNION
	SELECT 'starting population - unique alf' AS description, 'adbe' AS src, 0 AS step, 'distinct alf' AS cat, count (DISTINCT alf_pe) AS n FROM SAIL1409V.ADBE_BIRTHS_20240101
	UNION
	SELECT 'starting population - unique m alf' AS description, 'ncch' AS src, 0 AS step, 'distinct m alf' AS cat, count (DISTINCT mat_alf_pe) AS n FROM SAIL1409V.NCCH_CHILD_BIRTHS_20240201 
	UNION
	SELECT 'starting population - unique m alf' AS description, 'mids' AS src, 0 AS step, 'distinct m alf' AS cat, count (DISTINCT mother_alf_pe) AS n FROM SAIL1409V.MIDS_BIRTH_20240201 
	UNION
	SELECT 'combined tables - unique alf' AS description, 'birth_cohort' AS src, 1 AS step, 'distinct alf' AS cat, count (DISTINCT c_alf_pe) AS n FROM SAILW1409V.birth_cohort
	UNION 
	SELECT 'combined tables - linked mothers' AS description, 'birth_cohort' AS src, 1 AS step, 'distinct m alf' AS cat, count (DISTINCT m_alf_pe) AS n FROM SAILW1409V.birth_cohort
	UNION 
	SELECT 'starting population - total rows' AS description, 'ncch' AS src, 0 AS step, 'all rows' AS cat, count (*) AS n FROM SAIL1409V.NCCH_CHILD_BIRTHS_20240201
	UNION
	SELECT 'starting population - total rows' AS description, 'mids' AS src, 0 AS step, 'all rows' AS cat, count (*) AS n FROM SAIL1409V.MIDS_BIRTH_20240201 
	UNION
	SELECT 'starting population - total rows' AS description, 'adbe' AS src, 0 AS step, 'all rows' AS cat, count (*) AS n FROM SAIL1409V.ADBE_BIRTHS_20240101
	UNION
	SELECT 'combined tables - total rows' AS description, 'birth_cohort' AS src, 1 AS step, 'all rows' AS cat, count (*) AS n FROM SAILW1409V.birth_cohort
	)
;

DELETE FROM sailw1409v.birth_cohort
WHERE c_alf_pe IS NULL;

INSERT INTO sailw1409v.consort_values_birth
SELECT * FROM (
	SELECT 'birth cohort total rows - remove null alfs' AS description, 'birth_cohort' AS src, 2 AS step, 'all rows' AS cat, count (*) AS n FROM SAILW1409V.birth_cohort
	union
	SELECT 'birth cohort unique alf - remove null alfs' AS description, 'birth_cohort' AS src, 2 AS step, 'distinct alf' AS cat, count (DISTINCT c_alf_pe) AS n FROM SAILW1409V.birth_cohort
	union
	SELECT 'birth cohort unique alf - remove null alfs - linked mothers' AS description, 'birth_cohort' AS src,  2 AS step, 'distinct m alf' AS cat, count (DISTINCT m_alf_pe) AS n FROM SAILW1409V.birth_cohort
	)
;

DELETE FROM sailw1409v.birth_cohort
WHERE c_sex IS NULL;

INSERT INTO sailw1409v.consort_values_birth
SELECT * FROM (
	SELECT 'birth cohort total rows - remove invalid sex' AS description, 'birth_cohort' AS src, 3 AS step, 'all rows' AS cat, count (*) AS n FROM SAILW1409V.birth_cohort
	union
	SELECT 'birth cohort unique alf - remove invalid sex' AS description, 'birth_cohort' AS src, 3 AS step, 'distinct alf' AS cat, count (DISTINCT c_alf_pe) AS n FROM SAILW1409V.birth_cohort
	union
	SELECT 'birth cohort unique alf - remove invalid sex - linked mothers' AS description, 'birth_cohort' AS src, 3 AS step, 'distinct m alf' AS cat, count (DISTINCT m_alf_pe) AS n FROM SAILW1409V.birth_cohort
	)
;

-- valid wob
DELETE FROM sailw1409v.birth_cohort
WHERE c_wob < '2000-01-01'
OR c_wob > CURRENT date;

INSERT INTO sailw1409v.consort_values_birth
SELECT * FROM (
	SELECT 'birth cohort total rows - valid wob' AS description, 'birth_cohort' AS src, 4 AS step, 'all rows' AS cat, count (*) AS n FROM SAILW1409V.birth_cohort
	union
	SELECT 'birth cohort unique alf - valid wob' AS description, 'birth_cohort' AS src, 4 AS step, 'distinct alf' AS cat, count (DISTINCT c_alf_pe) AS n FROM SAILW1409V.birth_cohort
	union
	SELECT 'birth cohort unique alf - valid wob - linked mothers' AS description, 'birth_cohort' AS src, 4 AS step, 'distinct m alf' AS cat, count (DISTINCT m_alf_pe) AS n FROM SAILW1409V.birth_cohort
	)
;

-- child wob <> wdsd wob
DELETE FROM sailw1409v.birth_cohort
WHERE c_alf_pe in (SELECT alf_pe FROM sailw1409v.birth_cohort
LEFT JOIN sail1409v.WDSD_SINGLE_CLEAN_AR_PERS_20240812 
ON c_alf_pe = alf_pe
WHERE c_wob <> wob 
OR (wob IS NULL AND C_STILLBIRTH_FLG = 1));

INSERT INTO sailw1409v.consort_values_birth
SELECT * FROM (
	SELECT 'birth cohort total rows - child wob = wdsd wob' AS description, 'birth_cohort' AS src, 5 AS step,  'all rows' AS cat, count (*) AS n FROM SAILW1409V.birth_cohort
	union
	SELECT 'birth cohort unique alf - child wob = wdsd wob' AS description, 'birth_cohort' AS src, 5 AS step, 'distinct alf' AS cat, count (DISTINCT c_alf_pe) AS n FROM SAILW1409V.birth_cohort
	union
	SELECT 'birth cohort unique alf - child wob = wdsd wob - linked mothers' AS description, 'birth_cohort' AS src, 5 AS step, 'distinct m alf' AS cat, count (DISTINCT m_alf_pe) AS n FROM SAILW1409V.birth_cohort
	)
;

-- child sex <> wdsd sex
DELETE FROM sailw1409v.birth_cohort
WHERE c_alf_pe in (SELECT alf_pe FROM sailw1409v.birth_cohort
LEFT JOIN sail1409v.WDSD_SINGLE_CLEAN_AR_PERS_20240812 
ON c_alf_pe = alf_pe
WHERE (gndr_cd IS NULL AND c_sex is NULL) 
OR (GNDR_CD IS NULL AND C_STILLBIRTH_FLG = 0)
OR c_sex <> gndr_cd);

INSERT INTO sailw1409v.consort_values_birth
SELECT * FROM (
	SELECT 'birth cohort total rows - child sex = wdsd sex' AS description, 'birth_cohort' AS src, 6 AS step, 'all rows' AS cat, count (*) AS n FROM SAILW1409V.birth_cohort
	union
	SELECT 'birth cohort unique alf - child sex = wdsd sex' AS description, 'birth_cohort' AS src, 6 AS step, 'distinct alf' AS cat, count (DISTINCT c_alf_pe) AS n FROM SAILW1409V.birth_cohort
	union
	SELECT 'birth cohort unique alf - child sex = wdsd sex - linked mothers' AS description, 'birth_cohort' AS src, 6 AS step,  'distinct m alf' AS cat, count (DISTINCT m_alf_pe) AS n FROM SAILW1409V.birth_cohort
	)
;

-- mothers alf = childs alf
DELETE FROM sailw1409v.birth_cohort
WHERE m_alf_pe IS NOT NULL 
AND m_consistent_flg <> 1; -- remove inconsistent mothers, but not missing mothers

INSERT INTO sailw1409v.consort_values_birth
SELECT * FROM (
	SELECT 'birth cohort total rows - consistent mat alf' AS description, 'birth_cohort' AS src, 7 AS step, 'all rows' AS cat, count (*) AS n FROM SAILW1409V.birth_cohort
	union
	SELECT 'birth cohort unique alf - consistent mat alf' AS description, 'birth_cohort' AS src, 7 AS step, 'distinct alf' AS cat, count (DISTINCT c_alf_pe) AS n FROM SAILW1409V.birth_cohort
	union
	SELECT 'birth cohort unique alf - consistent mat alf - linked mothers' AS description, 'birth_cohort' AS src, 7 AS step, 'distinct m alf' AS cat, count (DISTINCT m_alf_pe) AS n FROM SAILW1409V.birth_cohort
	)
;

-- valid child sts_cd
DELETE FROM sailw1409v.birth_cohort
WHERE c_alf_sts_cd NOT IN ('1', '4', '39', '21', '22', '23', '24');

INSERT INTO sailw1409v.consort_values_birth
SELECT * FROM (
	SELECT 'birth cohort total rows - valid child sts_cd' AS description, 'birth_cohort' AS src, 8 AS step, 'all rows' AS cat, count (*) AS n FROM SAILW1409V.birth_cohort
	union
	SELECT 'birth cohort unique alf - valid child sts_cd' AS description, 'birth_cohort' AS src, 8 AS step, 'distinct alf' AS cat, count (DISTINCT c_alf_pe) AS n FROM SAILW1409V.birth_cohort
	union
	SELECT 'birth cohort unique alf - valid child sts_cd - linked mothers' AS description, 'birth_cohort' AS src, 8 AS step, 'distinct m alf' AS cat, count (DISTINCT m_alf_pe) AS n FROM SAILW1409V.birth_cohort
	)
;

-- =================================================================================================
-- Step 2.6: Use available birth weight info
-- =================================================================================================

-- Use available birth weight from any of the data sources. ADBE, MIDS and NCCH all have
-- birth weight as a column.

CALL fnc.drop_if_exists('sailw1409v.sa_birth_weight');

CREATE TABLE sailw1409v.sa_birth_weight
(
    c_alf_pe        bigint  NOT NULL,
    c_wob           date    NOT NULL,
    c_birth_weight  integer NOT NULL, -- Birth weight in grams
    PRIMARY KEY (c_alf_pe, c_wob)
);

INSERT INTO sailw1409v.sa_birth_weight
WITH
    ncch AS
    (
        SELECT
            alf_pe                               AS c_alf_pe,
            date(wob)                            AS c_wob,
            cast(birth_weight * 1000 AS integer) AS c_birth_weight -- Convert kilograms to grams
        FROM sail1409v.ncch_child_births_20240201
        WHERE
            alf_pe IS NOT NULL
            AND wob IS NOT NULL
            AND birth_weight IS NOT NULL
        GROUP BY
            alf_pe,
            wob,
            birth_weight
    ),
    mids AS
    (
        SELECT
            child_alf_pe                               AS c_alf_pe,
            date(baby_birth_dt)                        AS c_wob,
            cast(service_user_weight_grams AS integer) AS c_birth_weight
        FROM sail1409v.mids_birth_20240201
        WHERE
            child_alf_pe IS NOT NULL
            AND baby_birth_dt IS NOT NULL
            AND service_user_weight_grams IS NOT NULL
        GROUP BY
            child_alf_pe,
            baby_birth_dt,
            service_user_weight_grams
    ),
    adbe AS
    (
        SELECT
            alf_pe                        AS c_alf_pe,
            date(wob)                     AS c_wob,
            cast(birth_weight AS integer) AS c_birth_weight
        FROM sail1409v.adbe_births_20240101
        WHERE
            alf_pe IS NOT NULL
            AND wob IS NOT NULL
            AND birth_weight IS NOT NULL
        GROUP BY
            alf_pe,
            wob,
            birth_weight
    ),
    bind_rows AS
    (
        SELECT * FROM ncch
        UNION ALL
        SELECT * FROM mids
        UNION ALL
        SELECT * FROM adbe
    )
SELECT
	c_alf_pe,
	c_wob,
	cast(floor(median(c_birth_weight)) AS integer) AS c_birth_weight
FROM bind_rows
GROUP BY c_alf_pe, c_wob;

MERGE INTO sailw1409v.birth_cohort AS cohort
USING sailw1409v.sa_birth_weight AS bw
ON  cohort.c_alf_pe = bw.c_alf_pe
AND cohort.c_wob = bw.c_wob
AND cohort.c_birth_weight IS NULL
WHEN MATCHED THEN UPDATE SET
    cohort.c_birth_weight = bw.c_birth_weight;


-- =================================================================================================
-- Step 2.7: Use available breast feeding info
-- =================================================================================================

-- use stand-alone NCCH breast feeding table
-- see lookup tables in Step 2 for meaning of collection time IDs and outcome IDs

CALL fnc.drop_if_exists('sailw1409v.sa_breast_feeding');

CREATE TABLE sailw1409v.sa_breast_feeding
(
    c_alf_pe                    bigint    NOT NULL,
    m_breast_feeding_birth_flg  smallint          ,
    m_breast_feeding_8wks_flg   smallint          ,
    PRIMARY KEY (c_alf_pe)
);

INSERT INTO sailw1409v.sa_breast_feeding
SELECT
    trust.alf_pe,
    max(
        CASE
            WHEN bf.collection_time_id IN (1, 2) AND bf.outcome_id <= 3 THEN 1
            WHEN bf.collection_time_id IN (1, 2) AND bf.outcome_id  = 4 THEN 0
        END
    ) AS m_breast_feeding_birth_flg,
    max(
        CASE
            WHEN bf.collection_time_id IN (4, 5) AND bf.outcome_id <= 3 THEN 1
            WHEN bf.collection_time_id IN (4, 5) AND bf.outcome_id  = 4 THEN 0
        END
    ) AS m_breast_feeding_8wks_flg
FROM sail1409v.ncch_child_trust_20240201 AS trust
INNER JOIN sail1409v.ncch_child_births_20240201 AS birth
    ON  trust.child_id_pe = birth.child_id_pe
    AND trust.alf_pe      = birth.alf_pe
    AND trust.wob         = birth.wob
INNER JOIN sail1409v.ncch_breast_feeding_20240201 AS bf
    ON trust.child_id_pe = bf.child_id_pe
WHERE
    trust.alf_pe IS NOT NULL
    AND trust.alf_sts_cd IN (1, 4, 39)
    AND bf.collection_time_id IS NOT NULL
    AND bf.outcome_id IS NOT NULL
GROUP BY
    trust.alf_pe,
    trust.wob;

MERGE INTO sailw1409v.birth_cohort AS cohort
USING sailw1409v.sa_breast_feeding AS bf
ON  cohort.c_alf_pe = bf.c_alf_pe
AND cohort.m_breast_feeding_birth_flg IS NULL
WHEN MATCHED THEN UPDATE SET
    cohort.m_breast_feeding_birth_flg = bf.m_breast_feeding_birth_flg;

MERGE INTO sailw1409v.birth_cohort AS cohort
USING sailw1409v.sa_breast_feeding AS bf
ON  cohort.c_alf_pe = bf.c_alf_pe
AND cohort.m_breast_feeding_8wks_flg IS NULL
WHEN MATCHED THEN UPDATE SET
    cohort.m_breast_feeding_8wks_flg = bf.m_breast_feeding_8wks_flg;


-- supplement using intent to breast feed from MIDS, as MIDS overlaps with NCCH
-- rather than adding a lot of new records

CALL fnc.drop_if_exists('sailw1409v.sa_bf_intent');

CREATE TABLE sailw1409v.sa_bf_intent
(
    c_alf_pe                    bigint    NOT NULL,
    m_breast_feeding_intent_flg smallint  NOT NULL,
    PRIMARY KEY (c_alf_pe)
);

INSERT INTO sailw1409v.sa_bf_intent
SELECT
    child_alf_pe AS c_alf_pe,
    max(
    	CASE
	        WHEN mat_intends_breast_feeding_cd = 1 THEN 1
	        WHEN mat_intends_breast_feeding_cd = 2 THEN 0
    	END
    ) AS m_breast_feeding_intent_flg
FROM sail1409v.mids_birth_20240201
WHERE
	child_alf_pe IS NOT NULL
	AND mat_intends_breast_feeding_cd IN (1, 2)
GROUP BY child_alf_pe;

MERGE INTO sailw1409v.birth_cohort AS cohort
USING sailw1409v.sa_bf_intent AS bf
ON  cohort.c_alf_pe = bf.c_alf_pe
AND cohort.m_breast_feeding_intent_flg IS NULL
WHEN MATCHED THEN UPDATE SET
    cohort.m_breast_feeding_intent_flg = bf.m_breast_feeding_intent_flg;

-- =================================================================================================
-- Step 2.8: Replace missing parity info
-- =================================================================================================

-- Use rolling sum based on available birth records
-- Sources: NCCH and MIDS

CALL fnc.drop_if_exists('sailw1409v.sa_mother_parity');

CREATE TABLE sailw1409v.sa_mother_parity
(
    m_alf_pe bigint   NOT NULL,
    wob      date     NOT NULL,
    m_parity smallint NOT NULL,
    multiple_gest_flg SMALLINT, 
    PRIMARY KEY (m_alf_pe, wob)
);

INSERT INTO sailw1409v.sa_mother_parity  
WITH 
	ranked_parity AS (
		SELECT distinct
			m_alf_pe,
			c_alf_pe,
			c_wob,
			m_parity, 
			row_number() OVER (PARTITION BY m_alf_pe ORDER BY c_wob) AS rn
		FROM sailw1409v.birth_cohort
		WHERE m_alf_pe IS NOT NULL
		),
	first_non_null AS (
		SELECT 
			m_alf_pe, 
			first_non_null,
			c_wob
		FROM (
			SELECT 
				m_alf_pe, 
				m_parity AS first_non_null,
				c_wob,
				row_number() OVER (PARTITION BY m_alf_pe ORDER BY c_wob) AS rn
			FROM ranked_parity 
			WHERE m_parity IS NOT NULL	
		)		
		WHERE rn = 1		
	),
	-- fill nulls for mothers with only null values against their alf
	fill_nulls_only AS (
		SELECT
			m_alf_pe, 
			a.c_alf_pe,
			a.c_wob, 
			a.m_parity, 
			rn, 
			first_non_null,
			rn -1 AS m_parity_nr
		FROM 
		ranked_parity a
		LEFT JOIN
		first_non_null b
		USING(m_alf_pe)
		WHERE first_non_null IS null
		ORDER BY a.m_alf_pe, a.c_wob		
	),
	-- combine original and null-filled
	filled_nulls_only AS (
		SELECT 
		distinct
			a.m_alf_pe, 
			a.c_alf_pe,
			a.c_wob, 
--			a.m_parity, 
			m_parity_nr,
			CASE 
				WHEN a.m_parity IS NULL THEN m_parity_nr ELSE a.m_parity
		END AS m_parity
		FROM 
		ranked_parity a
		LEFT JOIN
		fill_nulls_only b
		ON a.m_alf_pe = b.m_alf_pe
		AND a.c_wob = b.c_wob
		AND a.c_alf_pe = b.c_alf_pe
		ORDER BY a.m_alf_pe, a.c_wob		
	),	
	-- flag multiple gestations
	flag_mg AS (
		SELECT distinct
			m_alf_pe, 
			c_wob,
			rn1 multiple_gest_ind,
			1 AS multiple_gest_flg
			FROM (
			SELECT *, row_number() OVER (PARTITION BY m_alf_pe, rn ORDER BY rn) rn1
			FROM (
				SELECT 
					m_alf_pe, 
					c_alf_pe, 
					c_wob,
					rank() OVER (PARTITION BY m_alf_pe ORDER BY c_wob) rn
				FROM filled_nulls_only
				ORDER BY m_alf_pe, c_wob
			)
		)
		WHERE rn1 > 1			
	),
	flag_dups as (
		SELECT 
			m_alf_pe,
			max(dup_flg) AS dup_flg
		FROM (
			SELECT distinct
				m_alf_pe, 
				c_alf_pe,
				c_wob,
				m_parity,
				CASE 
					WHEN rank() OVER (PARTITION BY m_alf_pe, m_parity ORDER BY c_wob) > 1 THEN 1 
					ELSE NULL 
				END AS dup_flg
			FROM filled_nulls_only
			LEFT JOIN flag_mg
			using(m_alf_pe, c_wob)
			WHERE m_parity IS NOT null
			ORDER BY m_alf_pe, c_wob	
		)
		GROUP BY M_ALF_PE 			
	),
	identify_mins AS (
	-- identify minimum prev births and their position
		SELECT 
			m_alf_pe, 
			min_parity, 
			min_rn
		FROM (
			SELECT DISTINCT 
				m_alf_pe, 
				min_parity, 
				rn min_rn,
				CASE WHEN c_wob = min(c_wob) OVER (PARTITION BY m_alf_pe) THEN 1 ELSE NULL END AS min_parity_flg
			FROM (
				SELECT 
					m_alf_pe, 
					m_parity,
					c_wob,
					CASE WHEN m_parity = min(m_parity) OVER (PARTITION BY m_alf_pe) THEN 1 ELSE NULL END AS min_parity_flg,
					min(m_parity) OVER (PARTITION BY m_alf_pe) min_parity,
					rank() OVER (PARTITION BY m_alf_pe ORDER BY c_wob) AS rn
				FROM filled_nulls_only a				
			)			
			WHERE min_parity_flg = 1	
		)
		WHERE min_parity_flg = 1			
	), 
	flag_incorrect AS (
		SELECT DISTINCT 
			m_alf_pe, 
			incorrect_flg
		FROM (
			SELECT 	
				m_alf_pe,
				rank() OVER (PARTITION BY m_alf_pe ORDER BY c_wob) rn1,
				min_rn,
				min_parity,
				CASE WHEN rank() OVER (PARTITION BY m_alf_pe ORDER BY c_wob) - min_rn + min_parity < 0 THEN 1 ELSE NULL END AS incorrect_flg
			FROM filled_nulls_only
			LEFT JOIN identify_mins
			using(m_alf_pe)			
			)
		WHERE incorrect_flg = 1				
	),
	mother_parity AS (
		SELECT 
			m_alf_pe, 
			c_alf_pe,
			a.c_wob,
			multiple_gest_flg,
			CASE 
			-- when flagged as incorrect, number by rank
				WHEN incorrect_flg = 1
					THEN dense_rank() OVER (PARTITION BY m_alf_pe ORDER BY a.c_wob) -1
			-- when null fill using minimum prev_births value
				WHEN m_parity IS NULL 
					THEN dense_rank() OVER (PARTITION BY m_alf_pe ORDER BY a.c_wob)  - min_rn + min_parity 
			-- when not null but rank is higher than value, update using minimum prev births value and rank
				WHEN m_parity IS NOT NULL AND rank() OVER (PARTITION BY m_alf_pe ORDER BY a.c_wob) - min_rn + min_parity < 1 
					THEN dense_rank() OVER (PARTITION BY m_alf_pe ORDER BY a.c_wob) -1
			-- correct multiple gestations
				WHEN m_parity IS NOT NULL AND (multiple_gest_flg = 1)
					THEN dense_rank() OVER (PARTITION BY m_alf_pe ORDER BY a.c_wob) - min_rn + min_parity 
			-- correct repeat values
				WHEN m_parity IS NOT NULL AND (multiple_gest_flg = 1 OR dup_flg = 1)
					THEN dense_rank() OVER (PARTITION BY m_alf_pe ORDER BY a.c_wob) - min_rn + min_parity 		
				ELSE m_parity
			END AS m_parity
		FROM filled_nulls_only a		
		LEFT JOIN identify_mins b 
		using(m_alf_pe) 
		LEFT JOIN (SELECT DISTINCT m_alf_pe, multiple_gest_flg FROM flag_mg) c
		using(m_alf_pe)
		LEFT JOIN (SELECT DISTINCT m_alf_pe, dup_flg FROM flag_dups) d
		using(m_alf_pe)
		LEFT JOIN flag_incorrect e
		using(m_alf_pe)
		ORDER BY m_alf_pe, c_wob		
	)
SELECT distinct
    m_alf_pe,
    c_wob AS wob,
    m_parity,
    multiple_gest_flg
FROM
    mother_parity
ORDER BY m_alf_pe, c_wob;

CALL sysproc.admin_cmd('runstats on table sailw1409v.sa_mother_parity with distribution and detailed indexes all');

MERGE INTO sailw1409v.birth_cohort AS birth
USING sailw1409v.sa_mother_parity AS mp
ON  birth.m_alf_pe = mp.m_alf_pe
AND birth.c_wob = mp.wob
--AND birth.m_parity IS NULL
WHEN MATCHED THEN UPDATE SET
    birth.m_parity = mp.m_parity;
   
   
-- =================================================================================================
-- Step 2.9: Replace missing number of previous live births
-- =================================================================================================

CALL fnc.drop_if_exists('sailw1409v.sa_mother_prev_livebirths');

CREATE TABLE sailw1409v.sa_mother_prev_livebirths
(
    m_alf_pe          bigint   NOT NULL,
    wob               date     NOT NULL,
    m_prev_livebirths smallint NOT NULL,
    multiple_gest_flg SMALLINT,
    PRIMARY KEY (m_alf_pe, wob)
);

INSERT INTO sailw1409v.sa_mother_prev_livebirths
WITH 
	ranked_births AS (
		SELECT distinct
			m_alf_pe,
			c_alf_pe,
			c_wob,
			m_prev_livebirths, 
			rank() OVER (PARTITION BY m_alf_pe ORDER BY c_wob) AS rn
		FROM sailw1409v.birth_cohort
		WHERE m_alf_pe IS NOT null
		),
	first_non_null AS (
		SELECT 
			m_alf_pe, 
			first_non_null,
			c_wob
		FROM (
			SELECT 
				m_alf_pe, 
				m_prev_livebirths AS first_non_null,
				c_wob,
				row_number() OVER (PARTITION BY m_alf_pe ORDER BY c_wob) AS rn
			FROM ranked_births 
			WHERE m_prev_livebirths IS NOT NULL
		)
		WHERE rn = 1		
	),
	-- fill nulls for mothers with only null values against their alf
	fill_nulls_only AS (
		SELECT
			a.m_alf_pe, 
			a.c_alf_pe,
			a.c_wob, 
			a.m_prev_livebirths, 
			rn,  
			first_non_null,
			rn -1 AS m_prev_livebirths_nr
		FROM 
		ranked_births a
		LEFT JOIN
		first_non_null b
		ON a.m_alf_pe = b.m_alf_pe
		WHERE first_non_null IS null
		ORDER BY a.m_alf_pe, a.c_wob		
	),
	-- combine original and null-filled
	filled_nulls_only AS (
		SELECT 
		distinct
			a.m_alf_pe, 
			a.c_alf_pe,
			a.c_wob, 
--			a.m_prev_livebirths, 
			m_prev_livebirths_nr,
			CASE 
				WHEN a.m_prev_livebirths IS NULL THEN m_prev_livebirths_nr ELSE a.m_prev_livebirths
		END AS m_prev_livebirths
		FROM 
		ranked_births a
		LEFT JOIN
		fill_nulls_only b
		ON a.m_alf_pe = b.m_alf_pe
		AND a.c_wob = b.c_wob
		AND a.c_alf_pe = b.c_alf_pe
		ORDER BY a.m_alf_pe, a.c_wob		
	),	
	-- flag multiple gestations
	flag_mg AS (
		SELECT distinct
			m_alf_pe, 
			c_wob,
			rn1 multiple_gest_ind,
			1 AS multiple_gest_flg
			FROM (
			SELECT *, row_number() OVER (PARTITION BY m_alf_pe, rn ORDER BY rn) rn1
			FROM (
				SELECT 
					m_alf_pe, 
					c_alf_pe, 
					c_wob,
					rank() OVER (PARTITION BY m_alf_pe ORDER BY c_wob) rn
				FROM filled_nulls_only
				ORDER BY m_alf_pe, c_wob
			)
		)
		WHERE rn1 > 1		
	),
	flag_dups as (
		SELECT 
			m_alf_pe,
			max(dup_flg) AS dup_flg
		FROM (
			SELECT distinct
				m_alf_pe, 
				c_alf_pe,
				c_wob,
				m_prev_livebirths,
				CASE 
					WHEN rank() OVER (PARTITION BY m_alf_pe, m_prev_livebirths ORDER BY c_wob) > 1 THEN 1 
					ELSE NULL 
				END AS dup_flg
			FROM filled_nulls_only
			LEFT JOIN flag_mg
			using(m_alf_pe, c_wob)
			WHERE m_prev_livebirths IS NOT null
			ORDER BY m_alf_pe, c_wob	
		)
		GROUP BY M_ALF_PE 		
	),
	identify_mins AS (
	-- identify minimum prev births and their position
		SELECT 
			m_alf_pe, 
			min_prev, 
			min_rn
		FROM (
			SELECT DISTINCT 
				m_alf_pe, 
				min_prev, 
				rn min_rn,
				CASE WHEN c_wob = min(c_wob) OVER (PARTITION BY m_alf_pe) THEN 1 ELSE NULL END AS min_prev_flg
			FROM (
				SELECT 
					m_alf_pe, 
					m_prev_livebirths,
					c_wob,
					CASE WHEN m_prev_livebirths = min(m_prev_livebirths) OVER (PARTITION BY m_alf_pe) THEN 1 ELSE NULL END AS min_prev_flg,
					min(m_prev_livebirths) OVER (PARTITION BY m_alf_pe) min_prev,
					rank() OVER (PARTITION BY m_alf_pe ORDER BY c_wob) AS rn
				FROM filled_nulls_only a				
			)			
			WHERE min_prev_flg = 1	
		)
		WHERE min_prev_flg = 1			
	), 
	flag_incorrect AS (
		SELECT DISTINCT 
			m_alf_pe, 
			incorrect_flg
		FROM (
			SELECT 	
				m_alf_pe,
				rank() OVER (PARTITION BY m_alf_pe ORDER BY c_wob) rn1,
				min_rn,
				min_prev,
				CASE WHEN rank() OVER (PARTITION BY m_alf_pe ORDER BY c_wob) - min_rn + min_prev < 0 THEN 1 ELSE NULL END AS incorrect_flg
			FROM filled_nulls_only
			LEFT JOIN identify_mins
			using(m_alf_pe)			
			)
		WHERE incorrect_flg = 1		
	),
	mother_livebirths AS (
		SELECT 
			m_alf_pe, 
			c_alf_pe,
			a.c_wob,
			multiple_gest_flg,
			CASE 
			-- when flagged as incorrect, number by rank
				WHEN incorrect_flg = 1
					THEN rank() OVER (PARTITION BY m_alf_pe ORDER BY a.c_wob) -1
			-- when null fill using minimum prev_births value
				WHEN m_prev_livebirths IS NULL 
					THEN rank() OVER (PARTITION BY m_alf_pe ORDER BY a.c_wob)  - min_rn + min_prev 
			-- when not null but rank is higher than value, update using minimum prev births value and rank
				WHEN m_prev_livebirths IS NOT NULL AND rank() OVER (PARTITION BY m_alf_pe ORDER BY a.c_wob) - min_rn + min_prev < 1 
					THEN rank() OVER (PARTITION BY m_alf_pe ORDER BY a.c_wob) -1
			-- corect multiple gestations and repeat values
				WHEN m_prev_livebirths IS NOT NULL AND (multiple_gest_flg = 1 OR dup_flg = 1)
					THEN rank() OVER (PARTITION BY m_alf_pe ORDER BY a.c_wob) - min_rn + min_prev 
				ELSE m_prev_livebirths
			END AS m_prev_livebirths
		FROM filled_nulls_only a		
		LEFT JOIN identify_mins b 
		using(m_alf_pe) 
		LEFT JOIN (SELECT DISTINCT m_alf_pe, multiple_gest_flg FROM flag_mg) c
		using(m_alf_pe)
		LEFT JOIN (SELECT DISTINCT m_alf_pe, dup_flg FROM flag_dups) d
		using(m_alf_pe)
		LEFT JOIN flag_incorrect e
		using(m_alf_pe)
		ORDER BY m_alf_pe, c_wob
	)
SELECT distinct
    m_alf_pe,
    c_wob AS wob,
    m_prev_livebirths,
    multiple_gest_flg
FROM
    mother_livebirths
  ORDER BY m_alf_pe, c_wob;
 
 -- this will also update for all multple births so they are uniformally logged (e.g. 0 for first birth or twins, 2 for second set)
MERGE INTO sailw1409v.birth_cohort AS birth
USING sailw1409v.sa_mother_prev_livebirths AS mplb
ON  birth.m_alf_pe = mplb.m_alf_pe
AND birth.c_wob    = mplb.wob
WHEN MATCHED 
 THEN UPDATE SET
    birth.m_prev_livebirths = mplb.m_prev_livebirths; 

   
-- =================================================================================================
-- Step 2.10: Update mother Demographics from WDSD
-- =================================================================================================

CALL fnc.drop_if_exists('sailw1409v.sa_mother_demographics');

CREATE TABLE sailw1409v.sa_mother_demographics
(
    c_alf_pe  bigint NOT NULL,
    m_alf_pe  bigint NOT NULL,
    m_wob     date,
    m_age     smallint,
    m_sex     varchar(1),
    PRIMARY KEY (c_alf_pe, m_alf_pe)
);

INSERT INTO sailw1409v.sa_mother_demographics
SELECT
    birth.c_alf_pe,
    birth.m_alf_pe,
    pers.wob,
    floor((days(birth.c_wob) - days(pers.wob)) / 365.25) AS age,
    CASE
        WHEN pers.gndr_cd = 1 THEN 'M'
        WHEN pers.gndr_cd = 2 THEN 'F'
    END AS sex
FROM
    sailw1409v.birth_cohort AS birth
INNER JOIN
    sail1409v.WDSD_SINGLE_CLEAN_AR_PERS_20240812 AS pers
    ON birth.m_alf_pe = pers.alf_pe
WHERE
    birth.c_alf_pe IS NOT NULL
    AND birth.m_alf_pe IS NOT NULL;

MERGE INTO sailw1409v.birth_cohort AS birth
USING sailw1409v.sa_mother_demographics AS md
ON  birth.m_alf_pe = md.m_alf_pe
AND birth.c_alf_pe = md.c_alf_pe
WHEN MATCHED THEN UPDATE SET
    birth.m_wob = md.m_wob,
    birth.m_age = md.m_age,
    birth.m_sex = md.m_sex;


-- =================================================================================================
-- Step 2.11: Update mother marriage, SES, birth country from ADBE
-- =================================================================================================

MERGE INTO sailw1409v.birth_cohort AS birth
USING
(
    SELECT
        adbe.alf_pe,
        birth_marriage_ind_cd,
        -- mother columns
        CASE
            WHEN year(adbe.wob) <= 2006 THEN lkp_m_country_93.country
            WHEN year(adbe.wob) >= 2007 THEN lkp_m_country_07.country
        END AS mother_birthcountry_nm,
        CASE
            WHEN year(adbe.wob) <= 2006 THEN lkp_m_country_93.region
            WHEN year(adbe.wob) >= 2007 THEN lkp_m_country_07.region
        END AS mother_birthregion_nm,
        adbe.mother_socioeconomic_class_cd,
        adbe.mother_occ_class_cd
    FROM
        sail1409v.adbe_births_20240101 AS adbe
    -- mother lookups
    LEFT JOIN
        sailw1409v.lkp_ons_country_1993 AS lkp_m_country_93
        ON adbe.mother_birthcountry_cd = lkp_m_country_93.code
    LEFT JOIN
        sailw1409v.lkp_ons_country_2007 AS lkp_m_country_07
        ON adbe.mother_birthcountry_cd = lkp_m_country_07.code
    WHERE
        adbe.alf_sts_cd IN (1, 4, 39)
) AS adbe
ON birth.c_alf_pe = adbe.alf_pe
WHEN MATCHED THEN UPDATE SET
    birth.m_marriage_cd            = adbe.birth_marriage_ind_cd,
    birth.m_birth_country_nm       = adbe.mother_birthcountry_nm,
    birth.m_birth_region_nm        = adbe.mother_birthregion_nm,
    birth.m_socioeconomic_class_cd = adbe.mother_socioeconomic_class_cd,
    birth.m_occ_class_cd           = adbe.mother_occ_class_cd;

 -- =================================================================================================
 -- Step 2.12: Area info for mother based on last known address up to one year before birth
 -- =================================================================================================

 CALL fnc.drop_if_exists('sailw1409v.sa_mother_address');

 CREATE TABLE sailw1409v.sa_mother_address
 (
     c_alf_pe              bigint NOT NULL,
     m_alf_pe              bigint NOT NULL,
     start_date            date,
     end_date              date,
     lsoa2011_cd           varchar(10),
     wimd2014_decile       smallint,
     wimd2019_decile       smallint,
     wimd2014_quintile     smallint,
     wimd2019_quintile     smallint,
     townsend2011_quintile smallint,
     PRIMARY KEY (m_alf_pe, c_alf_pe)
 );

 -- WDS: at week of birth
 
 INSERT INTO sailw1409v.sa_mother_address
 SELECT
     birth.c_alf_pe,
     birth.m_alf_pe,
     addr.start_date,
     addr.end_date,
     addr.lsoa2011_cd,
     addr.wimd_2014_decile,
     addr.wimd_2019_decile,
     addr.wimd_2014_quintile,
     addr.wimd_2019_quintile,
     addr.townsend_2011_quintile
 FROM
     sailw1409v.birth_cohort AS birth
 INNER JOIN
     sail1409v.wdsd_single_clean_geo_char_lsoa2011_20240205 AS addr
     ON  birth.m_alf_pe = addr.alf_pe
     AND birth.c_wob BETWEEN addr.start_date AND addr.end_date
 ORDER BY
     addr.alf_pe,
     addr.start_date;

-- WDS: last known address up to one year before birth
INSERT INTO sailw1409v.sa_mother_address
WITH
    birth_addr AS
    (
    SELECT
         birth.c_alf_pe,
         birth.m_alf_pe,
         addr.start_date,
         addr.end_date,
         addr.lsoa2011_cd,
         addr.wimd_2014_decile,
         addr.wimd_2019_decile,
         addr.wimd_2014_quintile,
         addr.wimd_2019_quintile,
         addr.townsend_2011_quintile,
         row_number() over (partition BY birth.c_alf_pe, birth.m_alf_pe ORDER BY addr.end_date DESC) AS addr_seq
     FROM
         sailw1409v.birth_cohort AS birth
     INNER JOIN
         sail1409v.wdsd_single_clean_geo_char_lsoa2011_20240205 AS addr
         ON  birth.m_alf_pe = addr.alf_pe
         AND addr.end_date BETWEEN birth.c_wob - 1 YEAR AND birth.c_wob
     LEFT JOIN
        sailw1409v.sa_mother_address AS mother_addr
        ON  birth.c_alf_pe = mother_addr.c_alf_pe
        AND birth.m_alf_pe = mother_addr.m_alf_pe
    WHERE
        mother_addr.c_alf_pe IS NULL
        AND mother_addr.m_alf_pe IS NULL
     ORDER BY
         addr.alf_pe,
         addr.start_date
   )
SELECT
     c_alf_pe,
     m_alf_pe,
     start_date,
     end_date,
     lsoa2011_cd,
     wimd_2014_decile,
     wimd_2019_decile,
     wimd_2014_quintile,
     wimd_2019_quintile,
     townsend_2011_quintile
FROM birth_addr
WHERE addr_seq = 1;

-- Merge into main table

MERGE INTO sailw1409v.birth_cohort AS birth
USING sailw1409v.sa_mother_address AS ma
ON  birth.m_alf_pe = ma.m_alf_pe
AND birth.c_alf_pe = ma.c_alf_pe
WHEN MATCHED THEN UPDATE SET
     birth.m_lsoa2011_cd           = ma.lsoa2011_cd,
     birth.m_wimd2014_decile       = ma.wimd2014_decile,
     birth.m_wimd2019_decile       = ma.wimd2019_decile,
     birth.m_wimd2014_quintile     = ma.wimd2014_quintile,
     birth.m_wimd2019_quintile     = ma.wimd2019_quintile,
     birth.m_townsend2011_quintile = ma.townsend2011_quintile;

-- =================================================================================================
-- Step 2.13: Add info on mother death
-- =================================================================================================

CALL fnc.drop_if_exists('sailw1409v.sa_mother_death');

CREATE TABLE sailw1409v.sa_mother_death
(
    alf_pe        	bigint NOT NULL,
    death_date    	date,
    death_diag_cd 	varchar(5),
    PRIMARY KEY 	(alf_pe)
);

INSERT INTO sailw1409v.sa_mother_death
WITH
    mum AS
    (
        SELECT m_alf_pe
        FROM sailw1409v.birth_cohort
        GROUP BY m_alf_pe
    )
SELECT
    death.alf_pe               AS alf_pe,
    date(death.death_dt)       AS death_date,
    death.deathcause_diag_1_cd AS death_diag_cd
FROM mum
INNER JOIN sail1409v.adde_deaths_20240201 AS death
    ON mum.m_alf_pe = death.alf_pe
    AND death.alf_sts_cd IN (1, 4, 39);

MERGE INTO sailw1409v.birth_cohort AS birth
USING sailw1409v.sa_mother_death AS md
ON birth.m_alf_pe = md.alf_pe
WHEN MATCHED THEN UPDATE SET
    birth.m_death_date    = md.death_date,
    birth.m_death_diag_cd = md.death_diag_cd;


-- =================================================================================================
-- Step 2.14: Add info on child death
-- =================================================================================================

CALL fnc.drop_if_exists('sailw1409v.sa_child_death');

CREATE TABLE sailw1409v.sa_child_death
(
    alf_pe                    bigint NOT NULL,
    death_date                date,
    death_neonatal_flg        smallint,
    death_birth_asphyxia_flg  smallint,
    death_short_gestation_flg smallint,
    death_sids_flg            smallint,
    death_diag_1_cd           varchar(5),
    PRIMARY KEY (alf_pe)
);

INSERT INTO sailw1409v.sa_child_death
SELECT
    death.alf_pe,
    date(death.death_dt) AS death_date,
    death.neonatal_ind_flg AS death_neonatal_flg,
    CASE
        WHEN death.deathcause_diag_1_cd LIKE 'P21' THEN 1
        WHEN death.deathcause_diag_2_cd LIKE 'P21' THEN 1
        WHEN death.deathcause_diag_3_cd LIKE 'P21' THEN 1
        WHEN death.deathcause_diag_4_cd LIKE 'P21' THEN 1
        WHEN death.deathcause_diag_5_cd LIKE 'P21' THEN 1
        WHEN death.deathcause_diag_6_cd LIKE 'P21' THEN 1
        WHEN death.deathcause_diag_7_cd LIKE 'P21' THEN 1
        WHEN death.deathcause_diag_8_cd LIKE 'P21' THEN 1
        ELSE 0
    END AS death_birth_asphyxia_flg,
    CASE
        WHEN death.deathcause_diag_1_cd LIKE 'P07' THEN 1
        WHEN death.deathcause_diag_2_cd LIKE 'P07' THEN 1
        WHEN death.deathcause_diag_3_cd LIKE 'P07' THEN 1
        WHEN death.deathcause_diag_4_cd LIKE 'P07' THEN 1
        WHEN death.deathcause_diag_5_cd LIKE 'P07' THEN 1
        WHEN death.deathcause_diag_6_cd LIKE 'P07' THEN 1
        WHEN death.deathcause_diag_7_cd LIKE 'P07' THEN 1
        WHEN death.deathcause_diag_8_cd LIKE 'P07' THEN 1
        ELSE 0
    END AS death_short_gestation_flg,
    CASE
        WHEN death.deathcause_diag_1_cd LIKE 'R95' THEN 1
        WHEN death.deathcause_diag_2_cd LIKE 'R95' THEN 1
        WHEN death.deathcause_diag_3_cd LIKE 'R95' THEN 1
        WHEN death.deathcause_diag_4_cd LIKE 'R95' THEN 1
        WHEN death.deathcause_diag_5_cd LIKE 'R95' THEN 1
        WHEN death.deathcause_diag_6_cd LIKE 'R95' THEN 1
        WHEN death.deathcause_diag_7_cd LIKE 'R95' THEN 1
        WHEN death.deathcause_diag_8_cd LIKE 'R95' THEN 1
        ELSE 0
    END AS death_sids_flg,
    death.deathcause_diag_1_cd AS death_diag_1_cd
FROM
    sailw1409v.birth_cohort AS child_birth
INNER JOIN
    sail1409v.adde_deaths_20240201 AS death
    ON child_birth.c_alf_pe = death.alf_pe
    AND death.alf_sts_cd IN (1, 4, 39);

MERGE INTO sailw1409v.birth_cohort AS birth
USING sailw1409v.sa_child_death AS cd
ON birth.c_alf_pe = cd.alf_pe
WHEN MATCHED THEN UPDATE SET
    birth.c_death_date                = cd.death_date,
    birth.c_death_neonatal_flg        = cd.death_neonatal_flg,
    birth.c_death_birth_asphyxia_flg  = cd.death_birth_asphyxia_flg,
    birth.c_death_short_gestation_flg = cd.death_short_gestation_flg,
    birth.c_death_sids_flg            = cd.death_sids_flg,
    birth.c_death_diag_cd             = cd.death_diag_1_cd;


-- =================================================================================================
-- Step 2.15: Child residence summary
-- =================================================================================================

CALL fnc.drop_if_exists('sailw1409v.sa_child_residence');

CREATE TABLE sailw1409v.sa_child_residence
(
    alf_pe                bigint      NOT NULL,
    start_date            date        NOT NULL,
    end_date              date        NOT NULL,
    lsoa2011_cd           varchar(10),
    wimd2014_decile       smallint,
    wimd2019_decile       smallint,
    wimd2014_quintile     smallint,
    wimd2019_quintile     smallint,
    townsend2011_quintile smallint,
    PRIMARY KEY (alf_pe)
);

INSERT INTO sailw1409v.sa_child_residence
WITH
    addr_history AS
    -- identify all addresses
    (
        SELECT
            addr.alf_pe,
            addr.start_date,
            addr.end_date,
            addr.lsoa2011_cd,
            DAYS(addr.end_date) - days(addr.start_date) AS days_in_residency,
            row_number() over (partition BY alf_pe ORDER BY start_date, end_date) AS addr_seq,
            lead(addr.lsoa2011_cd) OVER (PARTITION BY alf_pe ORDER BY start_date, end_date) AS next_lsoa,
            lead(addr.start_date) OVER (PARTITION BY alf_pe ORDER BY start_date, end_date) AS next_start_date,
            lead(addr.end_date) OVER (PARTITION BY alf_pe ORDER BY start_date, end_date) AS next_end_date
        FROM sailw1409v.birth_cohort AS birth
        INNER JOIN sail1409v.wdsd_single_clean_geo_char_lsoa2011_20240205 AS addr
            ON birth.c_alf_pe = addr.alf_pe
        WHERE addr.welsh_address = 1
        ORDER BY
            addr.alf_pe,
            addr.start_date
    ),
    addr_temp_pre_reg AS 
    -- identify date of first address 
    (
    	SELECT 
    		addr_history.alf_pe,
            addr_history.start_date AS cohort_join_date,
            addr_history.end_date,
            addr_history.lsoa2011_cd AS first_real_lsoa,
            1 pre_reg_flg
        FROM addr_history 
		WHERE 
			addr_seq = 1
		AND addr_history.lsoa2011_cd = 'W01000062' -- the lsoa of fertility
		AND addr_history.days_in_residency <= 42
		AND addr_history.next_lsoa IS NOT NULL 
		AND addr_history.next_lsoa <> 'W01000062' 
		ORDER BY
            addr_history.alf_pe,
            addr_history.start_date
    ),
    addr_clean AS (
	    SELECT 
	    	addr_history.alf_pe,
	        addr_history.start_date,
	        addr_history.next_end_date AS end_date,
	        addr_history.next_lsoa AS lsoa2011_cd
	    FROM addr_history
	    INNER JOIN addr_temp_pre_reg ON addr_history.alf_pe = addr_temp_pre_reg.alf_pe
	    WHERE addr_seq = 1
	    UNION ALL 
	    SELECT 
	    	addr_history.alf_pe,
	        addr_history.start_date,
	        addr_history.end_date,
	        addr_history.lsoa2011_cd
	    FROM addr_history
	    FULL JOIN addr_temp_pre_reg ON addr_history.alf_pe = addr_temp_pre_reg.alf_pe
	    WHERE addr_seq = 1
    	AND pre_reg_flg IS null
    	ORDER BY alf_pe
	)
SELECT 
	addr_clean.alf_pe,
	addr_clean.start_date,
	addr_clean.end_date,
	addr_clean.lsoa2011_cd,
	wds_addr.wimd_2014_decile,
	wds_addr.wimd_2019_decile,
	wds_addr.wimd_2014_quintile,
	wds_addr.wimd_2019_quintile,
	wds_addr.townsend_2011_quintile
FROM addr_clean    
    LEFT JOIN (
		SELECT DISTINCT 
			lsoa2011_cd, 
			wimd_2014_decile, 
			wimd_2019_decile, 
			wimd_2014_quintile, 
			wimd_2019_quintile, 
			townsend_2011_quintile 
		FROM sail1409v.wdsd_single_clean_geo_char_lsoa2011_20240205) AS wds_addr
    ON addr_clean.lsoa2011_cd = wds_addr.lsoa2011_cd
    ;

MERGE INTO sailw1409v.birth_cohort AS birth
USING sailw1409v.sa_child_residence AS c_rsd
ON birth.c_alf_pe = c_rsd.alf_pe
WHEN MATCHED THEN UPDATE SET
    birth.c_residence_start_date  = c_rsd.start_date,
    birth.c_residence_end_date    = c_rsd.end_date,
    birth.c_lsoa2011_cd           = c_rsd.lsoa2011_cd,
    birth.c_wimd2014_decile       = c_rsd.wimd2014_decile,
    birth.c_wimd2019_decile       = c_rsd.wimd2019_decile,
    birth.c_wimd2014_quintile     = c_rsd.wimd2014_quintile,
    birth.c_wimd2019_quintile     = c_rsd.wimd2019_quintile,
    birth.c_townsend2011_quintile = c_rsd.townsend2011_quintile;


-- =================================================================================================
-- Step 2.16: Derive trimester and preterm pregnancy intervals
-- =================================================================================================

CALL fnc.drop_if_exists('sailw1409v.sa_pregnancy_interval');

CREATE TABLE sailw1409v.sa_pregnancy_interval
(
    c_alf_pe                bigint      NOT NULL,
    p_trimester1_start_date date,
    p_trimester2_start_date date,
    p_trimester3_start_date date,
    p_preterm_start_date    date,
    p_preterm_end_date      date,
    PRIMARY KEY (c_alf_pe)
);

INSERT INTO sailw1409v.sa_pregnancy_interval
WITH
    birth AS
    (
        SELECT
            c_alf_pe,
            c_wob,
            CASE
                WHEN c_gestational_age IS NOT NULL THEN c_gestational_age
                ELSE 40
            END AS c_gestational_age
        FROM sailw1409v.birth_cohort
    )
SELECT
    c_alf_pe,
    c_wob - (c_gestational_age*7) days                   AS p_trimester1_start_date,
    c_wob - (c_gestational_age*7) days + (12*7) days     AS p_trimester2_start_date,
    c_wob - (c_gestational_age*7) days + (24*7) days     AS p_trimester3_start_date,
    c_wob - (c_gestational_age*7) days + (28*7 + 6) days AS p_preterm_start_date,
    c_wob - (c_gestational_age*7) days + (36*7 + 6) days AS p_preterm_end_date
FROM birth;

MERGE INTO sailw1409v.birth_cohort AS cohort
USING sailw1409v.sa_pregnancy_interval AS preg_interval
ON cohort.c_alf_pe = preg_interval.c_alf_pe
WHEN MATCHED THEN UPDATE SET
    cohort.p_trimester1_start_date = preg_interval.p_trimester1_start_date,
    cohort.p_trimester2_start_date = preg_interval.p_trimester2_start_date,
    cohort.p_trimester3_start_date = preg_interval.p_trimester3_start_date,
    cohort.p_preterm_start_date    = preg_interval.p_preterm_start_date,
    cohort.p_preterm_end_date      = preg_interval.p_preterm_end_date;


-- =================================================================================================
-- Step 2.17: Set data source and inconsistency flags
-- =================================================================================================

-- NCCH

MERGE INTO sailw1409v.birth_cohort AS birth
USING
(
    SELECT DISTINCT alf_pe
    FROM sail1409v.ncch_child_births_20240201
    WHERE wob >= '2000-01-01'
) AS src
ON birth.c_alf_pe = src.alf_pe
WHEN MATCHED THEN UPDATE SET
    birth.in_ncch = 1;

MERGE INTO sailw1409v.birth_cohort AS birth
USING
(
    SELECT DISTINCT alf_pe
    FROM sail1409v.ncch_child_trust_20240201
    WHERE wob >= '2000-01-01'
) AS src
ON birth.c_alf_pe = src.alf_pe
WHEN MATCHED THEN UPDATE SET
    birth.in_ncch = 1;

-- MIDS

MERGE INTO sailw1409v.birth_cohort AS birth
USING
(
    SELECT DISTINCT child_alf_pe
    FROM sail1409v.mids_birth_20240201
    WHERE baby_birth_dt >= '2000-01-01'
) AS src
ON birth.c_alf_pe = src.child_alf_pe
WHEN MATCHED THEN UPDATE SET
    birth.in_mids = 1;

-- ADBE

MERGE INTO sailw1409v.birth_cohort AS birth
USING
(
    SELECT DISTINCT alf_pe
    FROM sail1409v.adbe_births_20240101
    WHERE wob >= '2000-01-01'
) AS src
ON birth.c_alf_pe = src.alf_pe
WHEN MATCHED THEN UPDATE SET
    birth.in_adbe = 1;
   
 -- mismatch flag - wdsd
-------------------------------------------
MERGE INTO sailw1409v.birth_cohort AS birth
USING
(	
	SELECT distinct alf_pe
	FROM 
	sailw1409v.birth_cohort
	LEFT JOIN
	SAIL1409V.WDSD_SINGLE_CLEAN_AR_PERS_20240812 wdsd
	ON c_alf_pe = wdsd.alf_pe
	WHERE c_wob <> wdsd.wob
    ) AS flg
ON birth.c_alf_pe = flg.alf_pe
WHEN MATCHED THEN UPDATE SET
    birth.flg_wob_wlgp_mismatch = 1;
   
-- mismatch flag - wdsd

MERGE INTO sailw1409v.birth_cohort AS birth
USING
(	
	SELECT distinct alf_pe
	FROM 
	sailw1409v.birth_cohort
	LEFT JOIN
	SAIL1409V.WLGP_PATIENT_ALF_CLEANSED_20240101 wlgp
	ON c_alf_pe = wlgp.alf_pe
	WHERE c_wob <> wlgp.wob
    ) AS flg
ON birth.c_alf_pe = flg.alf_pe
WHEN MATCHED THEN UPDATE SET
    birth.flg_wob_wdsd_mismatch = 1;

  -- maternal alfs in nnch and mids are different

MERGE INTO sailw1409v.birth_cohort AS birth
USING
(
	Select DISTINCT alf_pe
	FROM sailw1409v.birth_cohort 
	LEFT JOIN 
	SAIL1409V.MIDS_BIRTH_20240201 mids
	ON child_alf_pe = c_alf_pe
	LEFT JOIN 
	SAIL1409V.NCCH_CHILD_BIRTHS_20240201 ncch
	ON ncch.alf_pe = c_alf_pe
	WHERE mother_alf_pe <> mat_alf_pe
	) AS flg
ON birth.c_alf_pe = flg.alf_pe
WHEN MATCHED THEN UPDATE SET
    birth.flg_incon_mat_alf = 1;
   
    -- maternal alf is same as childs

MERGE INTO sailw1409v.birth_cohort AS birth
USING
(
	SELECT distinct alf_pe
	FROM sailw1409v.birth_cohort c
	LEFT JOIN 
	SAIL1409V.MIDS_BIRTH_20240201 mids
	ON child_alf_pe = c_alf_pe
	LEFT JOIN 
	SAIL1409V.NCCH_CHILD_BIRTHS_20240201 ncch
	ON ncch.alf_pe = c_alf_pe
	WHERE mother_alf_pe = alf_pe
	) AS flg
ON birth.c_alf_pe = flg.alf_pe
WHEN MATCHED THEN UPDATE SET
    birth.flg_incon_child_alf = 1;

    -- mismatch mat wob flag - wdsd

MERGE INTO sailw1409v.birth_cohort AS birth
USING
(	
	SELECT distinct alf_pe
	FROM 
	sailw1409v.birth_cohort
	LEFT JOIN
	SAIL1409V.WDSD_SINGLE_CLEAN_AR_PERS_20240812 wdsd
	ON m_alf_pe = wdsd.alf_pe
	WHERE m_wob <> wdsd.wob
    ) AS flg
ON birth.c_alf_pe = flg.alf_pe
WHEN MATCHED THEN UPDATE SET
    birth.flg_mwob_wlgp_mismatch = 1;

-- mismatch mat wob flag - wdsd

MERGE INTO sailw1409v.birth_cohort AS birth
USING
(	
	SELECT distinct alf_pe
	FROM 
	sailw1409v.birth_cohort
	LEFT JOIN
	SAIL1409V.WLGP_PATIENT_ALF_CLEANSED_20240101 wlgp
	ON m_alf_pe = wlgp.alf_pe
	WHERE m_wob <> wlgp.wob
    ) AS flg
ON birth.c_alf_pe = flg.alf_pe
WHEN MATCHED THEN UPDATE SET
    birth.flg_mwob_wdsd_mismatch = 1;
   
-- =================================================================================================
-- Step 2.18: More cleaning and populating consort table
-- =================================================================================================


-- mothers sts_cd is valid
UPDATE sailw1409v.birth_cohort SET 
	m_alf_pe = NULL,
    m_alf_sts_cd = NULL,
    m_consistent_flg  = NULL,
    m_wob = NULL,
    m_age = NULL,
    m_sex = NULL,
    m_parity = NULL,
    m_multiple_gestation_flg = NULL,
    m_breast_feeding_intent_flg = NULL,
    m_ethnicity = NULL,
    m_prev_livebirths = NULL,
    m_breast_feeding_birth_flg = NULL,
    m_breast_feeding_8wks_flg = NULL,
    m_smoking_cat = NULL
WHERE m_alf_sts_cd NOT IN ('1', '4', '21', '22', '23', '24', '39');

INSERT INTO sailw1409v.consort_values_birth
SELECT * FROM (
	SELECT 'birth cohort total rows - valid mother sts_cd' AS description, 'birth_cohort' AS src, 9 AS step, 'all rows' AS cat, count (*) AS n FROM SAILW1409V.birth_cohort
	union
	SELECT 'birth cohort unique alf - valid mother sts_cd' AS description, 'birth_cohort' AS src, 9 AS step, 'distinct alf' AS cat, count (DISTINCT c_alf_pe) AS n FROM SAILW1409V.birth_cohort
	union
	SELECT 'birth cohort unique alf - valid mother sts_cd - linked mothers' AS description, 'birth_cohort' AS src, 9 AS step, 'distinct m alf' AS cat, count (DISTINCT m_alf_pe) AS n FROM SAILW1409V.birth_cohort
	)
;
   
   -- mothers are too young/ too old
UPDATE sailw1409v.birth_cohort SET 
	m_alf_pe = NULL,
    m_alf_sts_cd = NULL,
    m_consistent_flg  = NULL,
    m_wob = NULL,
    m_age = NULL,
    m_sex = NULL,
    m_parity = NULL,
    m_multiple_gestation_flg = NULL,
    m_breast_feeding_intent_flg = NULL,
    m_ethnicity = NULL,
    m_prev_livebirths = NULL,
    m_breast_feeding_birth_flg = NULL,
    m_breast_feeding_8wks_flg = NULL,
    m_smoking_cat = NULL
WHERE floor((days(c_wob) - days(m_wob)) / 365.25) < 12
OR floor((days(c_wob) - days(m_wob)) / 365.25) > 66;

INSERT INTO sailw1409v.consort_values_birth
SELECT * FROM (
	SELECT 'birth cohort total rows - mother valid age' AS description, 'birth_cohort' AS src, 10 AS step, 'all rows' AS cat, count (*) AS n FROM SAILW1409V.birth_cohort
	union
	SELECT 'birth cohort unique alf - mother valid age' AS description, 'birth_cohort' AS src, 10 AS step, 'distinct alf' AS cat, count (DISTINCT c_alf_pe) AS n FROM SAILW1409V.birth_cohort
	union
	SELECT 'birth cohort unique alf - mother valid age - linked mothers' AS description, 'birth_cohort' AS src, 10 AS step, 'distinct m alf' AS cat, count (DISTINCT m_alf_pe) AS n FROM SAILW1409V.birth_cohort
	)
;

-- =================================================================================================
-- Step 2.18: Tidy up time!
-- =================================================================================================

CALL fnc.drop_if_exists('sailw1409v.lkp_ncch_bf_collection');
CALL fnc.drop_if_exists('sailw1409v.lkp_ncch_bf_outcome');
CALL fnc.drop_if_exists('sailw1409v.lkp_ons_country_1993');
CALL fnc.drop_if_exists('sailw1409v.lkp_ons_country_2007');
CALL fnc.drop_if_exists('sailw1409v.sa_birth_weight');
CALL fnc.drop_if_exists('sailw1409v.sa_breast_feeding');
CALL fnc.drop_if_exists('sailw1409v.sa_bf_intent');
CALL fnc.drop_if_exists('sailw1409v.sa_mother_parity');
CALL fnc.drop_if_exists('sailw1409v.sa_mother_prev_livebirths');
CALL fnc.drop_if_exists('sailw1409v.sa_mother_demographics');
CALL fnc.drop_if_exists('sailw1409v.sa_mother_address');
CALL fnc.drop_if_exists('sailw1409v.sa_mother_death');
CALL fnc.drop_if_exists('sailw1409v.sa_child_death');
CALL fnc.drop_if_exists('sailw1409v.sa_child_residence');
CALL fnc.drop_if_exists('sailw1409v.sa_pregnancy_interval');


-- =================================================================================================
-- Step 2.19: Summarise birth cohort
-- =================================================================================================

SELECT ALF_PE, WOB, C_WOB, M_WOB FROM sailw1409v.CHILD_COHORT
LEFT join
sailw1409v.birth_cohort
ON alf_pe = c_alf_pe;

SELECT * FROM sailw1409v.birth_cohort; -- 953,148
SELECT * FROM sailw1409v.CHILD_COHORT; -- 4,818,918

WITH
    total AS
    (
        SELECT year(c_wob) AS x_year, count(*) AS n
        FROM sailw1409v.birth_cohort
        GROUP BY year(c_wob)
        ORDER BY year(c_wob)
    ),
    has_mother AS
    (
        SELECT year(c_wob) AS x_year, count(*) AS n
        FROM sailw1409v.birth_cohort
        WHERE m_alf_pe IS NOT NULL
        GROUP BY year(c_wob)
        ORDER BY year(c_wob)
    ),
    has_resid AS
    (
        SELECT year(c_wob) AS x_year, count(*) AS n
        FROM sailw1409v.birth_cohort
        WHERE c_residence_start_date IS NOT NULL
        GROUP BY year(c_wob)
        ORDER BY year(c_wob)
    )
SELECT
    total.x_year,
    total.n AS total_n,
    has_mother.n AS has_mother_alf,
    has_resid.n AS has_welsh_resid
FROM total
LEFT JOIN has_mother
    ON total.x_year = has_mother.x_year
LEFT JOIN has_resid
    ON total.x_year = has_resid.x_year;
   
-- =================================================================================================
-- 3.0 create table to records counts for consort diagram
-- =================================================================================================

CALL fnc.drop_if_exists('sailw1409v.consort_values_mothers');

CREATE TABLE sailw1409v.consort_values_mothers
(
	description 	varchar(100),
	step			integer,
	cat				varchar(12),
	n				integer
);
		
-- =================================================================================================
-- 3.1 create the mother cohort
-- =================================================================================================
-- identify the mothers of children registerd in Wales who were born on or after 2000-01-01
 
CALL fnc.drop_if_exists('sailw1409v.mother_cohort');

CREATE TABLE sailw1409v.mother_cohort
(
    alf_pe		BIGINT,
    wob 		DATE,
    dod 		DATE,
    sex			varchar(1),
    ethnicity	varchar(15)
);

INSERT INTO sailw1409v.mother_cohort
	SELECT distinct
		bt.m_alf_pe AS alf_pe, 
		wdsd.wob, 
		wdsd.dod, 
		CASE 
			WHEN wdsd.gndr_cd = '1' OR wdsd.gndr_cd = 'M' THEN '1'
			WHEN wdsd.gndr_cd = '2' OR wdsd.gndr_cd = 'F' THEN '2'
		END AS sex,
		ETHN_EC_ONS_DATE_LATEST_DESC AS ethnicity
	FROM 
		SAIL1409V.WDSD_SINGLE_CLEAN_AR_PERS_20240812 wdsd
	INNER JOIN 
		sailw1409v.birth_cohort bt
	ON m_alf_pe = alf_pe
	LEFT JOIN 
		SAILW1409V.RRDA_ETHN
	using(alf_pe);

-- population consort diagram
INSERT INTO sailw1409v.consort_values_mothers
SELECT * FROM (
	SELECT 'all wdsd rows' AS description, 0 AS step, 'all rows' AS cat, count (*) AS n FROM SAIL1409V.WDSD_SINGLE_CLEAN_AR_PERS_20240812
	UNION
	SELECT 'wdsd unique alf' AS description, 0 AS step, 'distinct alf' AS cat, count (DISTINCT alf_pe) AS n FROM SAIL1409V.WDSD_SINGLE_CLEAN_AR_PERS_20240812 
	UNION
	SELECT 'all mothers cohort rows' AS description, 1 AS step, 'all rows' AS cat, count (*) AS n FROM SAILW1409V.mother_cohort
	UNION
	SELECT 'mother cohort unique alf' AS description, 1 AS step, 'distinct alf' AS cat, count (DISTINCT alf_pe) AS n FROM SAILW1409V.mother_cohort
	) ORDER BY step;


