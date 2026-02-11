-- =================================================================================================
-- Name:         Adminsitrative table for SAIL views relevent to project 1409
-- Data sources: 
-- Maintainers:  Sarah
-- Created:      2024/09/02
-- Description:  This script builds the administrative derived table used for project 1409

-- 		administrative table -

-- please note - please check if these tables have already been created and populated before running 
-- this script. It may take quite some time.
-- =================================================================================================

-- =================================================================================================
-- create the admin table 
-- =================================================================================================
-- identify the demographic and administrative factors associated with children registerd in Wales who were born on or after 2000-01-01 and their mothers 
 
CALL fnc.drop_if_exists('sailw1409v.admin_table');

CREATE TABLE sailw1409v.admin_table
(
  alf_pe			bigint,
  sex				char(1),
  wob				date,
  ethn_grp			varchar(10),
  death_dt			date,
  child_cohort_flg	integer,
  birth_cohort_flg	integer,
  mother_cohort_flg	integer,
  wdsd_flg			integer,
  active_from		date,
  active_to			date,
  wlgp_flg			integer,
  non_sail_gp_flg	integer,
  sail_gp_flg		integer,
  first_record_wlgp	date,
--  cens_flg			integer,
--  cenw_flg			integer,
  adde_flg			integer,
  pedw_flg			integer,
  edds_flg			integer,
  icnc_flg			integer,
  ccds_flg			integer,
  opdw_flg			integer,
  wrrs_flg			integer,
  cars_flg			integer,
  lac_flg			integer,
  crcs_flg			integer,
  child_protection_register	integer,
  cinw_flg			integer,
  eduw_flg			integer,
  cafw_flg			integer,
  fsm_flg			integer,
  sen_flg			integer
);

-- insert demographic, cohort flags and wdsd and wlgp info first
INSERT INTO sailw1409v.admin_table (alf_pe, sex, wob, ethn_grp, death_dt, child_cohort_flg, birth_cohort_flg, 
									mother_cohort_flg, wdsd_flg, active_from, active_to, wlgp_flg, 
									non_sail_gp_flg, sail_gp_flg, first_record_wlgp, fsm_flg, sen_flg)
WITH 
	alfs AS 
		(
			SELECT DISTINCT * FROM (
			(SELECT c_alf_pe AS alf_pe FROM sailw1409v.birth_table)
			union 
			(SELECT alf_pe  FROM sailw1409v.child_cohort)
			union
			(SELECT alf_pe FROM sailw1409v.mother_cohort))
		 ),
	deaths AS
		(
			SELECT 
				alf_pe,
				cast(death_dt AS date) death_dt
			FROM 
				ALFS 
			INNER join
				 sail1409V.ADDE_DEATHS_20240201 
			using(alf_pe)
			WHERE DEATH_DT_VALID = 'Valid'
		),
	cohort_flags AS 
		(
			SELECT alf_pe, child_cohort_flg, birth_cohort_flg, mother_cohort_flg  FROM 
			alfs 
			LEFT join
				(SELECT alf_pe, 1 AS child_cohort_flg FROM alfs INNER JOIN sailw1409v.child_cohort using(alf_pe))
			using(alf_pe)
			LEFT JOIN 
				(SELECT c_alf_pe AS alf_pe, 1 AS birth_cohort_flg FROM alfs INNER JOIN sailw1409v.birth_table ON c_alf_pe = alf_pe)
			using(alf_pe)
			LEFT JOIN
				(SELECT alf_pe, 1 AS mother_cohort_flg FROM alfs INNER JOIN sailw1409v.mother_cohort using(alf_pe))
			using(alf_pe)
		),
	wdsd AS
		(
			SELECT 
				alf_pe, 
				wob, 
				gndr_cd sex,
				1 wdsd_flg, 
				min(activefrom) active_from, 
				max(COALESCE(ACTIVETO, CURRENT_DATE)) AS activeto
			FROM alfs INNER JOIN sail1409v.WDSD_PER_RESIDENCE_GPREG_20240812 USING(alf_pe)
			WHERE activefrom >= '1990-01-01'
			AND activeto <= CURRENT_DATE OR activeto is null
			GROUP BY alf_pe, wob, gndr_cd
			ORDER BY activeto desc
		),
	wlgp AS
		(
			SELECT alf_pe, wlgp_flg, non_sail_gp_flg, sail_gp_flg, first_record_wlgp FROM 
				(SELECT alf_pe, 1 wlgp_flg, min(gp_data_flag) non_sail_gp_flg, max(gp_data_flag) sail_gp_flg
				FROM sail1409v.WLGP_CLEAN_GP_REG_BY_PRAC_INCLNONSAIL_MEDIAN_20240101 INNER JOIN alfs USING(alf_pe)
				GROUP BY alf_pe )
				LEFT JOIN 
				(SELECT alf_pe, min(EVENT_DT) first_record_wlgp
				FROM sail1409v.WLGP_GP_EVENT_CLEANSED_20240101 INNER JOIN alfs USING(alf_pe)
				WHERE event_dt BETWEEN '1990-01-01' AND CURRENT DATE
				GROUP BY alf_pe)
			using(alf_pe)
		),
	education_wb AS 
		(
			SELECT distinct 
				alf_pe, 
				max(sen_flg) sen_flg,
				max(FREE_SCHOOL_MEALS_FLG) fsm_flg 
			FROM sailw1409v.SA_EDU_WELLBEING 
			GROUP BY alf_pe
		)
SELECT DISTINCT 
	alfs.alf_pe,
  	wdsd.sex,
  	wob,
  	ethn_c.ETHN_EC_ONS_DATE_LATEST_CODE ethn_grp,
	deaths.death_dt,
  	cohort_flags.child_cohort_flg,
  	cohort_flags.birth_cohort_flg,
  	cohort_flags.mother_cohort_flg,
  	wdsd.wdsd_flg,
  	wdsd.active_from,
 	wdsd.activeto,
 	wlgp.wlgp_flg,
 	wlgp.non_sail_gp_flg,
 	wlgp.sail_gp_flg,
 	wlgp.first_record_wlgp,
 	COALESCE(education_wb.sen_flg,0) sen_flg,
 	COALESCE(education_wb.fsm_flg,0) fms_flg
from
	ALFS 
LEFT JOIN wdsd
	using(alf_pe)
LEFT JOIN sailw1409v.rrda_ethn AS ethn_c
	using(alf_pe)
LEFT JOIN deaths
	using(alf_pe)
LEFT JOIN cohort_flags
	using(alf_pe)
LEFT JOIN wlgp
	using(alf_pe)
LEFT JOIN education_wb
	using(alf_pe)
;


-- these flags were too big to insert as one, so update each individually
-- adde
MERGE INTO sailw1409v.admin_table AS admin
USING (SELECT distinct alf_pe, 1 adde_flg FROM sail1409v.ADDE_DEATHS_20240201 INNER JOIN (
			SELECT DISTINCT * FROM (
			(SELECT c_alf_pe AS alf_pe, c_sex AS sex, c_wob AS wob FROM sailw1409v.birth_table)
			union 
			(SELECT alf_pe, sex, wob FROM sailw1409v.child_cohort)
			union
			(SELECT alf_pe, sex, wob FROM sailw1409v.mother_cohort))
		 ) USING(alf_pe)) flg
ON  admin.alf_pe	=	flg.alf_pe
WHEN matched THEN UPDATE SET
	admin.adde_flg = flg.adde_flg;

-- pedw
MERGE INTO sailw1409v.admin_table AS admin
USING (SELECT distinct alf_pe, 1 pedw_flg FROM sail1409v.PEDW_SPELL_20240909 INNER JOIN (
			SELECT DISTINCT * FROM (
			(SELECT c_alf_pe AS alf_pe, c_sex AS sex, c_wob AS wob FROM sailw1409v.birth_table)
			union 
			(SELECT alf_pe, sex, wob FROM sailw1409v.child_cohort)
			union
			(SELECT alf_pe, sex, wob FROM sailw1409v.mother_cohort))
		 ) USING(alf_pe)) flg
ON  admin.alf_pe	=	flg.alf_pe
WHEN matched THEN UPDATE SET
	admin.pedw_flg = flg.pedw_flg;

--edds
MERGE INTO sailw1409v.admin_table AS admin
USING (SELECT distinct alf_pe, 1 edds_flg FROM sail1409v.EDDS_EDDS_20240201 INNER JOIN (
			SELECT DISTINCT * FROM (
			(SELECT c_alf_pe AS alf_pe, c_sex AS sex, c_wob AS wob FROM sailw1409v.birth_table)
			union 
			(SELECT alf_pe, sex, wob FROM sailw1409v.child_cohort)
			union
			(SELECT alf_pe, sex, wob FROM sailw1409v.mother_cohort))
		 ) USING(alf_pe)) flg
ON  admin.alf_pe	=	flg.alf_pe
WHEN matched THEN UPDATE SET
	admin.edds_flg = flg.edds_flg;

-- icnc
MERGE INTO sailw1409v.admin_table AS admin
USING (SELECT distinct alf_pe, 1 icnc_flg FROM sail1409v.ICNC_ICNARC_LINKAGE_ALF_20250115 INNER JOIN (
			SELECT DISTINCT * FROM (
			(SELECT c_alf_pe AS alf_pe, c_sex AS sex, c_wob AS wob FROM sailw1409v.birth_table)
			union 
			(SELECT alf_pe, sex, wob FROM sailw1409v.child_cohort)
			union
			(SELECT alf_pe, sex, wob FROM sailw1409v.mother_cohort))
		 ) USING(alf_pe)) flg
ON  admin.alf_pe	=	flg.alf_pe
WHEN matched THEN UPDATE SET
	admin.icnc_flg = flg.icnc_flg;

-- ccds
MERGE INTO sailw1409v.admin_table AS admin
USING (SELECT distinct alf_pe, 1 ccds_flg FROM sail1409v.CCDS_CRITICAL_CARE_EPISODE_20240901 INNER JOIN (
			SELECT DISTINCT * FROM (
			(SELECT c_alf_pe AS alf_pe, c_sex AS sex, c_wob AS wob FROM sailw1409v.birth_table)
			union 
			(SELECT alf_pe, sex, wob FROM sailw1409v.child_cohort)
			union
			(SELECT alf_pe, sex, wob FROM sailw1409v.mother_cohort))
		 ) USING(alf_pe)) flg
ON  admin.alf_pe	=	flg.alf_pe
WHEN matched THEN UPDATE SET
	admin.ccds_flg = flg.ccds_flg;

-- opdw
MERGE INTO sailw1409v.admin_table AS admin
USING (SELECT distinct alf_pe, 1 opdw_flg FROM sail1409v.OPDW_OUTPATIENTS_20240901 INNER JOIN (
			SELECT DISTINCT * FROM (
			(SELECT c_alf_pe AS alf_pe, c_sex AS sex, c_wob AS wob FROM sailw1409v.birth_table)
			union 
			(SELECT alf_pe, sex, wob FROM sailw1409v.child_cohort)
			union
			(SELECT alf_pe, sex, wob FROM sailw1409v.mother_cohort))
		 ) USING(alf_pe)) flg
ON  admin.alf_pe	=	flg.alf_pe
WHEN matched THEN UPDATE SET
	admin.opdw_flg = flg.opdw_flg;

-- wrrs
MERGE INTO sailw1409v.admin_table AS admin
USING (SELECT distinct alf_pe, 1 wrrs_flg FROM sail1409v.WRRS_REPORT_20240306 INNER JOIN (
			SELECT DISTINCT * FROM (
			(SELECT c_alf_pe AS alf_pe, c_sex AS sex, c_wob AS wob FROM sailw1409v.birth_table)
			union 
			(SELECT alf_pe, sex, wob FROM sailw1409v.child_cohort)
			union
			(SELECT alf_pe, sex, wob FROM sailw1409v.mother_cohort))
		 ) USING(alf_pe)) flg
ON  admin.alf_pe	=	flg.alf_pe
WHEN matched THEN UPDATE SET
	admin.wrrs_flg = flg.wrrs_flg;

-- cars
MERGE INTO sailw1409v.admin_table AS admin
USING (SELECT distinct alf_pe, 1 cars_flg FROM sail1409v.CARS_BABY_FETUS_20220910 INNER JOIN (
			SELECT DISTINCT * FROM (
			(SELECT c_alf_pe AS alf_pe, c_sex AS sex, c_wob AS wob FROM sailw1409v.birth_table)
			union 
			(SELECT alf_pe, sex, wob FROM sailw1409v.child_cohort)
			union
			(SELECT alf_pe, sex, wob FROM sailw1409v.mother_cohort))
		 ) USING(alf_pe)) flg
ON  admin.alf_pe	=	flg.alf_pe
WHEN matched THEN UPDATE SET
	admin.cars_flg = flg.cars_flg;

-- lac
MERGE INTO sailw1409v.admin_table AS admin
USING (SELECT distinct alf_pe, 1 lac_flg FROM sailw1409v.sa_lac_episode INNER JOIN (
			SELECT DISTINCT * FROM (
			(SELECT c_alf_pe AS alf_pe, c_sex AS sex, c_wob AS wob FROM sailw1409v.birth_table)
			union 
			(SELECT alf_pe, sex, wob FROM sailw1409v.child_cohort)
			union
			(SELECT alf_pe, sex, wob FROM sailw1409v.mother_cohort))
		 ) USING(alf_pe)) flg
ON  admin.alf_pe	=	flg.alf_pe
WHEN matched THEN UPDATE SET
	admin.lac_flg = flg.lac_flg;

-- crcs 
MERGE INTO sailw1409v.admin_table AS admin
USING (SELECT distinct alf_pe, 1 crcs_flg, max(child_protection_register) child_protection_register FROM sail1409v.CRCS_PUPIL_ALF_20220329 pupil
		LEFT JOIN sail1409v.CRCS_MAIN_CRCS_20220329 main 
		ON pupil.CHILD_CODE_PE = main.CHILD_CODE_PE  
		INNER JOIN (
			SELECT DISTINCT * FROM (
			(SELECT c_alf_pe AS alf_pe, c_sex AS sex, c_wob AS wob FROM sailw1409v.birth_table)
			union 
			(SELECT alf_pe, sex, wob FROM sailw1409v.child_cohort)
			union
			(SELECT alf_pe, sex, wob FROM sailw1409v.mother_cohort))
		 ) USING(alf_pe) GROUP BY alf_pe) flg
ON  admin.alf_pe	=	flg.alf_pe
WHEN matched THEN UPDATE SET
	admin.crcs_flg = flg.crcs_flg,
	admin.child_protection_register = flg.child_protection_register;

-- cinw
MERGE INTO sailw1409v.admin_table AS admin
USING (SELECT distinct alf_pe, 1 cinw_flg FROM sail1409v.CINW_PUPIL_ALF_20220329 INNER JOIN (
			SELECT DISTINCT * FROM (
			(SELECT c_alf_pe AS alf_pe, c_sex AS sex, c_wob AS wob FROM sailw1409v.birth_table)
			union 
			(SELECT alf_pe, sex, wob FROM sailw1409v.child_cohort)
			union
			(SELECT alf_pe, sex, wob FROM sailw1409v.mother_cohort))
		 ) USING(alf_pe)) flg
ON  admin.alf_pe	=	flg.alf_pe
WHEN matched THEN UPDATE SET
	admin.cinw_flg = flg.cinw_flg;

-- eduw
MERGE INTO sailw1409v.admin_table AS admin
USING (SELECT distinct alf_pe, 1 eduw_flg FROM sail1409v.EDUW_PUPIL_ALF_20221017 INNER JOIN (
			SELECT DISTINCT * FROM (
			(SELECT c_alf_pe AS alf_pe, c_sex AS sex, c_wob AS wob FROM sailw1409v.birth_table)
			union 
			(SELECT alf_pe, sex, wob FROM sailw1409v.child_cohort)
			union
			(SELECT alf_pe, sex, wob FROM sailw1409v.mother_cohort))
		 ) USING(alf_pe)) flg
ON  admin.alf_pe	=	flg.alf_pe
WHEN matched THEN UPDATE SET
	admin.eduw_flg = flg.eduw_flg;

-- cafw
MERGE INTO sailw1409v.admin_table AS admin
USING (SELECT distinct alf_pe, 1 cafw_flg FROM sail1409v.CAFW_CAFCASS_ALF_20230622 INNER JOIN (
			SELECT DISTINCT * FROM (
			(SELECT c_alf_pe AS alf_pe, c_sex AS sex, c_wob AS wob FROM sailw1409v.birth_table)
			union 
			(SELECT alf_pe, sex, wob FROM sailw1409v.child_cohort)
			union
			(SELECT alf_pe, sex, wob FROM sailw1409v.mother_cohort))
		 ) USING(alf_pe)) flg
ON  admin.alf_pe	=	flg.alf_pe
WHEN matched THEN UPDATE SET
	admin.cafw_flg = flg.cafw_flg;



		 

  
  
