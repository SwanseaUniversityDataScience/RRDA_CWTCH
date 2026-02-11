-- =================================================================================================
-- Name:         Residency derived table for SAIL views relevent to project 1409
-- Data sources: 
-- Maintainers:  Sarah
-- Created:      2024/09/02
-- Description:  This script builds the residency derived table used for project 1409

-- 		residency derived table - 

-- please note - please check if these tables have already been created and populated before running 
-- this script. It may take quite some time.
-- =================================================================================================

-- =================================================================================================
-- create consort table - residency
-- =================================================================================================

CALL fnc.drop_if_exists('sailw1409v.consort_values_res');

CREATE TABLE sailw1409v.consort_values_res
(
	description 	varchar(100),
	step			integer,
	n				integer
);

INSERT INTO sailw1409v.consort_values_res
SELECT * FROM (
	SELECT 'all wdsd rows' AS description, 0 AS step, count (*) AS n FROM SAIL1409V.WDSD_SINGLE_CLEAN_GEO_RALF_LSOA2011_20240909
	UNION
	SELECT 'wdsd unique alf' AS description, 0 AS step, count (DISTINCT alf_pe) AS n FROM SAIL1409V.WDSD_SINGLE_CLEAN_GEO_RALF_LSOA2011_20240909
	UNION
	SELECT 'wdsd unique alf ralf not null' AS description, 1 AS step, count (DISTINCT alf_pe) AS n FROM SAIL1409V.WDSD_SINGLE_CLEAN_GEO_RALF_LSOA2011_20240909 WHERE ralf_pe IS NOT null
	UNION
	SELECT 'wdsd unique ralf' AS description, 0 AS step, count (DISTINCT ralf_pe) AS n FROM SAIL1409V.WDSD_SINGLE_CLEAN_GEO_RALF_LSOA2011_20240909
	UNION
	SELECT 'all child cohort rows' AS description, 2 AS step, count(alf_pe) AS n FROM SAIL1409V.WDSD_SINGLE_CLEAN_GEO_RALF_LSOA2011_20240909 wscgrl INNER JOIN SAILW1409V.child_cohort USING(alf_pe)
	UNION
	SELECT 'child cohort unique alf' AS description, 2 AS step, count(DISTINCT alf_pe) AS n FROM SAIL1409V.WDSD_SINGLE_CLEAN_GEO_RALF_LSOA2011_20240909 wscgrl INNER JOIN SAILW1409V.child_cohort USING(alf_pe)
	UNION
	SELECT 'child cohort unique ralf' AS description, 2 AS step, count(DISTINCT ralf_pe) AS n FROM SAIL1409V.WDSD_SINGLE_CLEAN_GEO_RALF_LSOA2011_20240909 wscgrl INNER JOIN SAILW1409V.child_cohort USING(alf_pe)
	UNION
	SELECT 'child cohort unique ralf >= 2000' AS description, 3 AS step, count(DISTINCT ralf_pe) AS n FROM SAIL1409V.WDSD_SINGLE_CLEAN_GEO_RALF_LSOA2011_20240909 wscgrl INNER JOIN SAILW1409V.child_cohort USING(alf_pe)
	WHERE start_date >= '2000-01-01'
	)
ORDER BY step, description;


-- =================================================================================================
-- create the event table - household
-- =================================================================================================
-- identify the events associated with children registerd in Wales who were born on or after 2000-01-01  and their mothers 
 
CALL fnc.drop_if_exists('sailw1409v.residency_table');

CREATE TABLE sailw1409v.residency_table
(
    alf_pe					BIGINT,
    wob						date,
--    death_date				date,
    ralf_pe			 		BIGINT,
    start_date_ralf			DATE,
    end_date_ralf			DATE,
    LSOA2011_CD				VARCHAR(9),
    WIMD_2014_QUINTILE		INTEGER,
    days_in_res				INTEGER,
    days_between_res		INTEGER,
    child_cohort_flag		CHAR(1),
    birth_table_flag		CHAR(1),
    mother_cohort_flag		CHAR(1)
);

INSERT INTO sailw1409v.residency_table
WITH
	ralf AS (
				SELECT 
					c_alf_pe, 
					ralf_pe,
					--c_alf_pe AS alf_pe,
					ralf.START_DATE AS c_start_date_ralf, 
					COALESCE (ralf.END_DATE, '9999-01-01') as c_end_date_ralf
				FROM 
					SAIL1409V.WDSD_SINGLE_CLEAN_GEO_RALF_LSOA2011_20240205 ralf
				RIGHT JOIN (
					SELECT DISTINCT c_alf_pe FROM (
						SELECT c_alf_pe FROM sailw1409v.birth_table 
						UNION
						SELECT alf_pe AS c_alf_pe FROM sailw1409v.CHILD_COHORT 
						)
					)
				ON c_alf_pe = ralf.alf_pe
				ORDER BY C_ALF_PE, ralf.START_DATE
	),
	cohabitants AS (
		SELECT DISTINCT  ralf_pe, alf_pe, wob, start_date_ralf, end_date_ralf, LSOA2011_CD, WIMD_2014_QUINTILE
		FROM (						
			SELECT * FROM (
				SELECT 
					ralf_pe,
					wdsd.alf_pe,
					wob,
					c_start_date_ralf,
					c_end_date_ralf,
					wdsd.START_DATE AS start_date_ralf, 
					COALESCE (wdsd.END_DATE, '9999-01-01') AS end_date_ralf,
					wdsd.LSOA2011_CD,
					WIMD_2014_QUINTILE
				FROM 
					SAIL1409V.WDSD_SINGLE_CLEAN_GEO_RALF_LSOA2011_20240205 wdsd
				LEFT JOIN 
						sail1409v.WDSD_SINGLE_CLEAN_GEO_CHAR_LSOA2011_20250113 wimd
					ON wdsd.ALF_PE =wimd.alf_pe 
					AND wdsd.LSOA2011_CD = wimd.LSOA2011_CD 
				RIGHT JOIN 
					ralf
				using(ralf_pe)
				LEFT JOIN 
					SAIL1409V.WDSD_SINGLE_CLEAN_AR_PERS_20240205 wdsd2
				ON wdsd.alf_pe = wdsd2.alf_pe
				)
				WHERE (c_start_date_ralf, c_end_date_ralf) OVERLAPS (start_date_ralf, end_date_ralf) 
				)
	),
	flags as(
	SELECT alf_pe, max(birth_table_flag) birth_table_flag, max(child_cohort_flag) child_cohort_flag, max(mother_cohort_flag) mother_cohort_flag FROM (
		select c_alf_pe alf_pe, '1' birth_table_flag, NULL child_cohort_flag, NULL mother_cohort_flag FROM COHABITANTS co inner JOIN sailw1409v.BIRTH_TABLE b ON co.alf_pe = b.c_alf_pe
		UNION 
		select c.alf_pe, NULL birth_table_flag, '1' child_cohort_flag, NULL mother_cohort_flag FROM COHABITANTS co inner JOIN sailw1409v.CHILD_COHORT c ON co.alf_pe = c.alf_pe
		UNION 
		select m.alf_pe, NULL birth_table_flag, NULL child_cohort_flag ,'1' mother_cohort_flag FROM COHABITANTS co inner JOIN sailw1409v.MOTHER_COHORT m ON co.alf_pe = m.alf_pe
	)
	group by alf_pe
	)
SELECT 
	cohabitants.alf_pe,
	wob,
 --   DEATH_DT AS death_date,
    ralf_pe,
    start_date_ralf,
    end_date_ralf,
    LSOA2011_CD,  
    WIMD_2014_QUINTILE,
    CASE WHEN end_date_ralf = '9999-01-01' THEN NULL ELSE floor(DAYS(END_DATE_RALF) - days(START_DATE_RALF)) END AS days_in_res,
	DAYS(start_date_ralf) - DAYS(LAG(END_DATE_RALF) OVER (PARTITION BY cohabitants.alf_pe ORDER BY cohabitants.alf_pe, START_DATE_RALF)) -1 AS days_between_res,
    birth_table_flag,
	child_cohort_flag,
	mother_cohort_flag
FROM 
cohabitants
LEFT JOIN flags
ON COHABITANTS.alf_pe = flags.alf_pe
ORDER BY cohabitants.alf_pe, start_date_ralf;
