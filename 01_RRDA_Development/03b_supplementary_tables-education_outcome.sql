-- =================================================================================================
-- Name:         Results at Key Stage 1, 2, and 4
-- Data sources: EDUW
-- Maintainer:   Sarah
-- Contributors: Stu & Emily
-- Created:      2024/12/18
-- Description:  This script is adapted from the work of Stu B and Emily L
--				 This script creates a wide table of results for key stages 1, 2, and 4, with one
--               row pe ALF.
--
--               When processing the data, I make repeat use of the following logic:
--                 * deduplicate the table, derive and format columns e.g. 'academic_year'
--                 * prioritise records for ALFs that have a determinstic match
--                 * use probabilistic matches for ALFs that have no determinstic match
--
--               I've only used EDUW as it has the coverage we need, and have actively avoided EDUC
--               because of the many-to-many relationships between ALF and IRN in the linkage table.
--
--               From Sept 2011, the foundation phase assessment replaced key stage 1.
-- =================================================================================================
-- =================================================================================================
-- Step 1: Setup the main table
-- =================================================================================================

CALL fnc.drop_if_exists('sailw1409v.sa_edu_keystage_results');

CREATE TABLE sailw1409v.sa_edu_keystage_results
(
	alf_pe                 bigint      NOT NULL, -- person ID
	alf_sts_cd             smallint    NOT NULL, -- linkage status
	wob					   date,
	wob_wds				   date,
	ks1_academic_year      smallint,             -- year starting 1st September in which they completed their key stage 1 assessment
	ks1_cym                varchar(1),           -- result for welsh as a first language
	ks1_eng                varchar(1),           -- result for english as a first language
	ks1_mat                varchar(1),           -- result for maths
	ks1_sci                varchar(1),           -- result for science
	ks1_csi                varchar(1),           -- core subject indicator
	fp_academic_year       smallint,             -- year starting 1st September in which they completed their foundation phase assessment
	fp_cym                 varchar(1),           -- result for welsh language and communication
	fp_eng                 varchar(1),           -- result for english language and communication
	fp_mat                 varchar(1),           -- result for mathematical development
	fp_psd                 varchar(1),           -- result for personal and social development, well-being and culutral diversity
	fp_indicator_flg       smallint,             -- official Foundation Phase Indicator: outcome level of at least 5 in language and communcation, mathematical development, and PSD
	ks2_academic_year      smallint,             -- year starting 1st September in which they completed their key stage 2 assessment
	ks2_cym                varchar(1),           -- welsh as a first language
	ks2_wel                varchar(1),           -- welsh as a second language
	ks2_eng                varchar(1),           -- result for english, either as first or second language
	ks2_mat                varchar(1),           -- result for maths
	ks2_sci                varchar(1),           -- result for science
	ks2_csi                varchar(1),           -- core subject indicator
	ks4_academic_year      smallint,             -- year starting 1st September in which they completed their key stage 4 assessment
	ks4_qual_5g_flg        smallint,             -- 0/1 flag for whether they achieved at least 5 qualifications at grade G or above
	ks4_qual_5c_flg        smallint,             -- 0/1 flag for whether they achieved at least 5 qualifications at grade C or above
	ks4_qual_5c_ewm_flg    smallint,             -- 0/1 flag for whether they achieved at least 5 qualifications at grade C or above, includes English/Welsh first language and mathematics
	PRIMARY KEY (alf_pe)
);


-- =================================================================================================
-- Step 2: Deduplicate the IRN-to-ALF linkage tables
-- =================================================================================================

-- Note that an ALF may match to more than one IRN
-- When we have more than one IRN for an ALF, only keep those that match on WOB

CALL fnc.drop_if_exists('sailw1409v.sa_eduw_alf');

SELECT * FROM sail1409v.eduw_ks3_20221017

CREATE TABLE sailw1409v.sa_eduw_alf
(
	irn_pe        bigint    NOT NULL, -- irn - pupil number
	alf_pe        bigint    NOT NULL, -- alf
	alf_sts_cd    smallint  NOT NULL, -- match status code
	wob           date      NOT NULL, -- week of birth from edu
	wob_wds       date              , -- week of birth from wdsd
	exp_ks1_year  smallint  NOT NULL, -- expected academic year of key stage 1 assessment, typically may of the following year
	exp_ks2_year  smallint  NOT NULL, -- expected academic year of key stage 2 assessment, typically may of the following year
	exp_ks4_year  smallint  NOT NULL, -- expected academic year of key stage 4 assessment
	PRIMARY KEY (irn_pe)
);

INSERT INTO sailw1409v.sa_eduw_alf
WITH
	alf_dedup AS
	(
		SELECT
			pupil.irn_pe,
			pupil.alf_pe,
			min(pupil.alf_sts_cd) AS alf_sts_cd,
			pupil.wob,
			wdsd.wob AS wob_wds,
			CASE
				WHEN month(pupil.wob) < 9 THEN year(pupil.wob + 6 years)
				ELSE year(pupil.wob + 7 years)
			END AS exp_ks1_year,
			CASE
				WHEN month(pupil.wob) < 9 THEN year(pupil.wob + 10 years)
				ELSE year(pupil.wob + 11 years)
			END AS exp_ks2_year,
			CASE
				WHEN month(pupil.wob) < 9 THEN year(pupil.wob + 15 years)
				ELSE year(pupil.wob + 16 years)
			END AS exp_ks4_year
		FROM sail1409v.eduw_pupil_alf_20221017 as pupil
		left join sail1409v.wdsd_single_clean_ar_pers_20240909 as wdsd
			ON pupil.alf_pe = wdsd.alf_pe
		inner JOIN sailw1409v.CHILD_COHORT cohort
			ON pupil.alf_pe = cohort.alf_pe
		WHERE alf_sts_cd IN (1, 4, 39)
		GROUP BY
			pupil.irn_pe,
			pupil.alf_pe,
			pupil.wob,
			wdsd.wob
	),
	-- find alfs with multiple irns
	alf_multi_irn AS
	(
		SELECT alf_pe
		FROM alf_dedup
		GROUP BY alf_pe
		HAVING count(*) > 1
		ORDER BY alf_pe
	)
SELECT
	alf_dedup.irn_pe,
	alf_dedup.alf_pe,
	alf_dedup.alf_sts_cd,
	alf_dedup.wob,
	alf_dedup.wob_wds,
	alf_dedup.exp_ks1_year,
	alf_dedup.exp_ks2_year,
	alf_dedup.exp_ks4_year
FROM alf_dedup
LEFT JOIN alf_multi_irn
	ON alf_dedup.alf_pe = alf_multi_irn.alf_pe
WHERE
	alf_multi_irn.alf_pe IS NULL
	OR alf_dedup.wob = alf_dedup.wob_wds;

-- =================================================================================================
-- Step 3: Extract key stage 1 results
-- =================================================================================================

CALL fnc.drop_if_exists('sailw1409v.sa_edu_ks1');

CREATE TABLE sailw1409v.sa_edu_ks1
(
	alf_pe             bigint      NOT NULL,
	alf_sts_cd         smallint    NOT NULL,
	ks1_academic_year  smallint    NOT NULL,
	ks1_cym            varchar(1),
	ks1_eng            varchar(1),
	ks1_sci            varchar(1),
	ks1_mat            varchar(1),
	ks1_csi            varchar(1),
	PRIMARY KEY (alf_pe)
);


-- EDUW
INSERT INTO sailw1409v.sa_edu_ks1
WITH
	-- join dedup alf to the ks1 table
	-- and make wide
	ks1_alf AS
	(
		SELECT
			pupil.alf_pe,
			pupil.alf_sts_cd,
			pupil.wob,
			pupil.exp_ks1_year,
			floor(ks1.year / 100) - 1 AS ks1_academic_year,
			max(CASE WHEN ks1.kssubject = 'CYM' THEN ks1.result END) AS ks1_cym,
			max(CASE WHEN ks1.kssubject = 'ENG' THEN ks1.result END) AS ks1_eng,
			max(CASE WHEN ks1.kssubject = 'SCI' THEN ks1.result END) AS ks1_sci,
			max(CASE WHEN ks1.kssubject = 'MAT' THEN ks1.result END) AS ks1_mat,
			max(CASE WHEN ks1.kssubject = 'CSI' THEN ks1.result END) AS ks1_csi
		FROM sailw1409v.sa_eduw_alf AS pupil
		INNER JOIN sail1409v.eduw_ks1_20221017 AS ks1
			ON pupil.irn_pe = ks1.irn_pe
		GROUP BY
			pupil.alf_pe,
			pupil.alf_sts_cd,
			pupil.wob,
			pupil.exp_ks1_year,
			floor(ks1.year / 100)
	),
	-- find alfs with multiple recordings
	alf_mult AS
	(
		SELECT alf_pe
		FROM ks1_alf
		GROUP BY alf_pe
		HAVING count(*) > 1
		ORDER BY alf_pe
	),
	-- find deterministic matches
	-- and resolve any multiple records by taking expected year
	ks1_alf_d AS
	(
		SELECT
			ks1_alf.alf_pe,
			ks1_alf.alf_sts_cd,
			ks1_alf.ks1_academic_year,
			ks1_alf.ks1_cym,
			ks1_alf.ks1_eng,
			ks1_alf.ks1_sci,
			ks1_alf.ks1_mat,
			ks1_alf.ks1_csi
		FROM ks1_alf
		LEFT JOIN alf_mult
			ON ks1_alf.alf_pe = alf_mult.alf_pe
		WHERE
			ks1_alf.alf_sts_cd = 4
			AND (
				alf_mult.alf_pe IS NULL
				OR ks1_alf.exp_ks1_year = ks1_alf.ks1_academic_year
			)
	),
	-- find additional probabilistic matches
	-- and resolve any multiple records by taking expected year
	ks1_alf_p AS
	(
		SELECT
			ks1_alf.alf_pe,
			ks1_alf.alf_sts_cd,
			ks1_alf.ks1_academic_year,
			ks1_alf.ks1_cym,
			ks1_alf.ks1_eng,
			ks1_alf.ks1_sci,
			ks1_alf.ks1_mat,
			ks1_alf.ks1_csi
		FROM ks1_alf
		LEFT JOIN alf_mult
			ON ks1_alf.alf_pe = alf_mult.alf_pe
		LEFT JOIN ks1_alf_d
			ON ks1_alf.alf_pe = ks1_alf_d.alf_pe
		WHERE
			ks1_alf.alf_sts_cd = 39
			AND ks1_alf_d.alf_pe IS NULL
			AND (
				alf_mult.alf_pe IS NULL
				OR ks1_alf.exp_ks1_year = ks1_alf.ks1_academic_year
			)
	)
-- stack rows
SELECT * FROM ks1_alf_d
UNION ALL
SELECT * FROM ks1_alf_p;


-- =================================================================================================
-- Step 4: Extract foundation phase results
-- =================================================================================================

CALL fnc.drop_if_exists('sailw1409v.sa_edu_fp');

CREATE TABLE sailw1409v.sa_edu_fp
(
	alf_pe             bigint       NOT NULL,
	alf_sts_cd         smallint     NOT NULL,
	fp_academic_year   smallint     NOT NULL,
	fp_cym             varchar(1),
	fp_eng             varchar(1),
	fp_mat             varchar(1),
	fp_psd             varchar(1),
	fp_indicator_flg   smallint,
	PRIMARY KEY (alf_pe)
);

INSERT INTO sailw1409v.sa_edu_fp
WITH
	-- join dedup alf to the foundation phase table
	-- and make wide
	fp_alf AS
	(
		SELECT
			pupil.alf_pe,
			pupil.alf_sts_cd,
			pupil.wob,
			pupil.exp_ks1_year,
			floor(fp.year / 100) - 1 AS fp_academic_year,
			max(CASE WHEN fp.kssubject = 'LCW' THEN fp.result END) AS fp_cym,
			max(CASE WHEN fp.kssubject = 'LCE' THEN fp.result END) AS fp_eng,
			max(CASE WHEN fp.kssubject = 'MDT' THEN fp.result END) AS fp_mat,
			max(CASE WHEN fp.kssubject = 'PSD' THEN fp.result END) AS fp_psd,
			max(
				CASE
					WHEN fp.kssubject = 'FPI' AND fp.result = 'Y' THEN 1
					WHEN fp.kssubject = 'FPI' AND fp.result = 'N' THEN 0
				END
			) AS fp_indicator_flg
		FROM sailw1409v.sa_eduw_alf AS pupil
		INNER JOIN sail1409v.eduw_fp_y2_20221017 AS fp
			ON pupil.irn_pe = fp.irn_pe
		GROUP BY
			pupil.alf_pe,
			pupil.alf_sts_cd,
			pupil.wob,
			pupil.exp_ks1_year,
			floor(fp.year / 100)
	),
	-- find alfs with multiple recordings
	alf_mult AS
	(
		SELECT
			alf_pe,
			count(*) AS n
		FROM fp_alf
		GROUP BY alf_pe
		HAVING count(*) > 1
		ORDER BY alf_pe
	),
	-- find deterministic matches
	-- and resolve any multiple records by taking expected year
	fp_alf_d AS
	(
		SELECT
			fp_alf.alf_pe,
			fp_alf.alf_sts_cd,
			fp_alf.fp_academic_year,
			fp_alf.fp_cym,
			fp_alf.fp_eng,
			fp_alf.fp_mat,
			fp_alf.fp_psd,
			fp_alf.fp_indicator_flg
		FROM fp_alf
		LEFT JOIN alf_mult
			ON fp_alf.alf_pe = alf_mult.alf_pe
		WHERE
			fp_alf.alf_sts_cd = 4
			AND (
				alf_mult.alf_pe IS NULL
				OR fp_alf.exp_ks1_year = fp_alf.fp_academic_year
			)
	),
	-- find additional probabilistic matches
	-- and resolve any multiple records by taking expected year
	fp_alf_p AS
	(
		SELECT
			fp_alf.alf_pe,
			fp_alf.alf_sts_cd,
			fp_alf.fp_academic_year,
			fp_alf.fp_cym,
			fp_alf.fp_eng,
			fp_alf.fp_mat,
			fp_alf.fp_psd,
			fp_alf.fp_indicator_flg
		FROM fp_alf
		LEFT JOIN alf_mult
			ON fp_alf.alf_pe = alf_mult.alf_pe
		LEFT JOIN fp_alf_d
			ON fp_alf.alf_pe = fp_alf_d.alf_pe
		WHERE
			fp_alf.alf_sts_cd = 39
			AND fp_alf_d.alf_pe IS NULL
			AND (
				alf_mult.alf_pe IS NULL
				OR fp_alf.exp_ks1_year = fp_alf.fp_academic_year
			)
	)
-- stack rows
SELECT * FROM fp_alf_d
UNION ALL
SELECT * FROM fp_alf_p;


-- =================================================================================================
-- Step 5: Extract key stage 2 results
-- =================================================================================================

CALL fnc.drop_if_exists('sailw1409v.sa_edu_ks2');

CREATE TABLE sailw1409v.sa_edu_ks2
(
	alf_pe             bigint       NOT NULL,
	alf_sts_cd         smallint     NOT NULL,
	ks2_academic_year  smallint     NOT NULL,
	ks2_cym            varchar(1),
	ks2_wel            varchar(1),
	ks2_eng            varchar(1),
	ks2_sci            varchar(1),
	ks2_mat            varchar(1),
	ks2_csi            varchar(1),
	PRIMARY KEY (alf_pe)
);

INSERT INTO sailw1409v.sa_edu_ks2
WITH
	-- join dedup alf to the ks2 table
	-- and make wide
	ks2_alf AS
	(
		SELECT
			pupil.alf_pe,
			pupil.alf_sts_cd,
			pupil.wob,
			pupil.exp_ks2_year,
			floor(ks2.year / 100) - 1 AS ks2_academic_year,
			max(CASE WHEN ks2.kssubject = 'CYM' THEN ks2.result END) AS ks2_cym,
			max(CASE WHEN ks2.kssubject = 'WEL' THEN ks2.result END) AS ks2_wel,
			max(CASE WHEN ks2.kssubject = 'ENG' THEN ks2.result END) AS ks2_eng,
			max(CASE WHEN ks2.kssubject = 'SCI' THEN ks2.result END) AS ks2_sci,
			max(CASE WHEN ks2.kssubject = 'MAT' THEN ks2.result END) AS ks2_mat,
			max(CASE WHEN ks2.kssubject = 'CSI' THEN ks2.result END) AS ks2_csi
		FROM sailw1409v.sa_eduw_alf AS pupil
		INNER JOIN sail1409v.eduw_ks2_20221017 AS ks2
			ON pupil.irn_pe = ks2.irn_pe
		GROUP BY
			pupil.alf_pe,
			pupil.alf_sts_cd,
			pupil.wob,
			pupil.exp_ks2_year,
			floor(ks2.year / 100)
	),
	-- find alfs with multiple recordings
	alf_mult AS
	(
		SELECT
			alf_pe,
			count(*) AS n
		FROM ks2_alf
		GROUP BY alf_pe
		HAVING count(*) > 1
		ORDER BY alf_pe
	),
	-- find deterministic matches
	-- and resolve any multiple records by taking expected year
	ks2_alf_d AS
	(
		SELECT
			ks2_alf.alf_pe,
			ks2_alf.alf_sts_cd,
			ks2_alf.ks2_academic_year,
			ks2_alf.ks2_cym,
			ks2_alf.ks2_wel,
			ks2_alf.ks2_eng,
			ks2_alf.ks2_sci,
			ks2_alf.ks2_mat,
			ks2_alf.ks2_csi
		FROM ks2_alf
		LEFT JOIN alf_mult
			ON ks2_alf.alf_pe = alf_mult.alf_pe
		WHERE
			ks2_alf.alf_sts_cd = 4
			AND (
				alf_mult.alf_pe IS NULL
				OR ks2_alf.exp_ks2_year = ks2_alf.ks2_academic_year
			)
	),
	-- find additional probabilistic matches
	-- and resolve any multiple records by taking expected year
	ks2_alf_p AS
	(
		SELECT
			ks2_alf.alf_pe,
			ks2_alf.alf_sts_cd,
			ks2_alf.ks2_academic_year,
			ks2_alf.ks2_cym,
			ks2_alf.ks2_wel,
			ks2_alf.ks2_eng,
			ks2_alf.ks2_sci,
			ks2_alf.ks2_mat,
			ks2_alf.ks2_csi
		FROM ks2_alf
		LEFT JOIN alf_mult
			ON ks2_alf.alf_pe = alf_mult.alf_pe
		LEFT JOIN ks2_alf_d
			ON ks2_alf.alf_pe = ks2_alf_d.alf_pe
		WHERE
			ks2_alf.alf_sts_cd = 39
			AND ks2_alf_d.alf_pe IS NULL
			AND (
				alf_mult.alf_pe IS NULL
				OR ks2_alf.exp_ks2_year = ks2_alf.ks2_academic_year
			)
	)
-- stack rows
SELECT * FROM ks2_alf_d
UNION ALL
SELECT * FROM ks2_alf_p;


-- =================================================================================================
-- Step 6: Extract key stage 4 results
-- =================================================================================================

CALL fnc.drop_if_exists('sailw1409v.sa_edu_ks4');

CREATE TABLE sailw1409v.sa_edu_ks4
(
	alf_pe               bigint    NOT NULL,
	alf_sts_cd           smallint  NOT NULL,
	ks4_academic_year    smallint  NOT NULL,
	ks4_qual_5g_flg      smallint,
	ks4_qual_5c_flg      smallint,
	ks4_qual_5c_ewm_flg  smallint,
	PRIMARY KEY (alf_pe)
);

INSERT INTO sailw1409v.sa_edu_ks4
WITH
	-- join dedup alf to the ks4 table
	ks4_alf AS
	(
		SELECT
			pupil.alf_pe,
			pupil.alf_sts_cd,
			pupil.wob,
			pupil.exp_ks4_year,
			ks4.year - 1              AS ks4_academic_year,
			max(r_qach5l)             AS ks4_qual_5g_flg,
			max(r_qach5h)             AS ks4_qual_5c_flg,
			max(r_qach5ewm)           AS ks4_qual_5c_ewm_flg
		FROM sailw1409v.sa_eduw_alf AS pupil
		INNER JOIN sail1409v.eduw_wed_l1_20221017 AS ks4
			ON pupil.irn_pe = ks4.irn_pe
		GROUP BY
			pupil.alf_pe,
			pupil.alf_sts_cd,
			pupil.wob,
			pupil.exp_ks4_year,
			ks4.year
	),
	-- find alfs with multiple recordings
	alf_mult AS
	(
		SELECT alf_pe
		FROM ks4_alf
		GROUP BY alf_pe
		HAVING count(*) > 1
		ORDER BY alf_pe
	),
	-- find deterministic matches
	-- and resolve any multiple records by taking expected year
	ks4_alf_d AS
	(
		SELECT
			ks4_alf.alf_pe,
			ks4_alf.alf_sts_cd,
			ks4_alf.ks4_academic_year,
			ks4_alf.ks4_qual_5g_flg,
			ks4_alf.ks4_qual_5c_flg,
			ks4_alf.ks4_qual_5c_ewm_flg
		FROM ks4_alf
		LEFT JOIN alf_mult
			ON ks4_alf.alf_pe = alf_mult.alf_pe
		WHERE
			ks4_alf.alf_sts_cd = 4
			AND (
				alf_mult.alf_pe IS NULL
				OR ks4_alf.exp_ks4_year = ks4_alf.ks4_academic_year
			)
	),
	-- find additional probabilistic matches
	-- and resolve any multiple records by taking expected year
	ks4_alf_p AS
	(
		SELECT
			ks4_alf.alf_pe,
			ks4_alf.alf_sts_cd,
			ks4_alf.ks4_academic_year,
			ks4_alf.ks4_qual_5g_flg,
			ks4_alf.ks4_qual_5c_flg,
			ks4_alf.ks4_qual_5c_ewm_flg
		FROM ks4_alf
		LEFT JOIN alf_mult
			ON ks4_alf.alf_pe = alf_mult.alf_pe
		LEFT JOIN ks4_alf_d
			ON ks4_alf.alf_pe = ks4_alf_d.alf_pe
		WHERE
			ks4_alf.alf_sts_cd = 39
			AND ks4_alf_d.alf_pe IS NULL
			AND (
				alf_mult.alf_pe IS NULL
				OR ks4_alf.exp_ks4_year = ks4_alf.ks4_academic_year
			)
	)
-- stack rows
SELECT * FROM ks4_alf_d
UNION ALL
SELECT * FROM ks4_alf_p;


-- =============================================================================
-- Step 7: Collect everything together and insert into the main table
-- =============================================================================

INSERT INTO sailw1409v.sa_edu_keystage_results
WITH
	alf AS
	(
		SELECT
			alf_pe,
			min(alf_sts_cd) AS alf_sts_cd,
			wob,
			wob_wds
		FROM sailw1409v.sa_eduw_alf
		GROUP BY alf_pe, wob, wob_wds
	)
SELECT
	alf.alf_pe,
	alf.alf_sts_cd,
	alf.wob,
	alf.wob_wds,
	ks1.ks1_academic_year,
	ks1.ks1_cym,
	ks1.ks1_eng,
	ks1.ks1_mat,
	ks1.ks1_sci,
	ks1.ks1_csi,
	fp.fp_academic_year,
	fp.fp_cym,
	fp.fp_eng,
	fp.fp_mat,
	fp.fp_psd,
	fp.fp_indicator_flg,
	ks2.ks2_academic_year,
	ks2.ks2_cym,
	ks2.ks2_wel,
	ks2.ks2_eng,
	ks2.ks2_mat,
	ks2.ks2_sci,
	ks2.ks2_csi,
	ks4.ks4_academic_year,
	ks4.ks4_qual_5g_flg,
	ks4.ks4_qual_5c_flg,
	ks4.ks4_qual_5c_ewm_flg
FROM alf
LEFT JOIN sailw1409v.sa_edu_ks1 AS ks1
	ON alf.alf_pe = ks1.alf_pe
LEFT JOIN sailw1409v.sa_edu_fp AS fp
	ON alf.alf_pe = fp.alf_pe
LEFT JOIN sailw1409v.sa_edu_ks2 AS ks2
	ON alf.alf_pe = ks2.alf_pe
LEFT JOIN sailw1409v.sa_edu_ks4 AS ks4
	ON alf.alf_pe = ks4.alf_pe
	;


-- =================================================================================================
-- Step 8: Tidy up, BAU!
-- =================================================================================================

CALL fnc.drop_if_exists('sailw1409v.sa_eduw_alf');
CALL fnc.drop_if_exists('sailw1409v.sa_edu_ks1');
CALL fnc.drop_if_exists('sailw1409v.sa_edu_fp');
CALL fnc.drop_if_exists('sailw1409v.sa_edu_ks2');
CALL fnc.drop_if_exists('sailw1409v.sa_edu_ks4');


-- =================================================================================================
-- Step 9: Summarise key stage counts each year
-- =================================================================================================

WITH
	ks_year AS
	(
		SELECT *
		FROM
		(
			VALUES
			(2004),
			(2005),
			(2006),
			(2007),
			(2008),
			(2009),
			(2010),
			(2011),
			(2012),
			(2013),
			(2014),
			(2015),
			(2016),
			(2017),
			(2018),
			(2019),
			(2020)
		) AS ks_year(ks_year)
	),
	ks1_year AS
	(
		SELECT ks1_academic_year AS ks_year, count(*) AS ks1_alf
		FROM sailw1409v.sa_edu_keystage_results
		WHERE ks1_academic_year IS NOT NULL
		GROUP BY ks1_academic_year
		ORDER BY ks1_academic_year
	),
	fp_year AS
	(
		SELECT fp_academic_year AS ks_year, count(*) AS fp_alf
		FROM sailw1409v.sa_edu_keystage_results
		WHERE fp_academic_year IS NOT NULL
		GROUP BY fp_academic_year
		ORDER BY fp_academic_year
	),
	ks2_year AS
	(
		SELECT ks2_academic_year AS ks_year, count(*) AS ks2_alf
		FROM sailw1409v.sa_edu_keystage_results
		WHERE ks2_academic_year IS NOT NULL
		GROUP BY ks2_academic_year
		ORDER BY ks2_academic_year
	),
	ks4_year AS
	(
		SELECT ks4_academic_year AS ks_year, count(*) AS ks4_alf
		FROM sailw1409v.sa_edu_keystage_results
		WHERE ks4_academic_year IS NOT NULL
		GROUP BY ks4_academic_year
		ORDER BY ks4_academic_year
	)
SELECT
	ks_year.ks_year,
	ks1_year.ks1_alf,
	fp_year.fp_alf,
	ks2_year.ks2_alf,
	ks4_year.ks4_alf
FROM ks_year
LEFT JOIN ks1_year ON ks_year.ks_year = ks1_year.ks_year
LEFT JOIN fp_year  ON ks_year.ks_year = fp_year.ks_year
LEFT JOIN ks2_year ON ks_year.ks_year = ks2_year.ks_year
LEFT JOIN ks4_year ON ks_year.ks_year = ks4_year.ks_year
ORDER BY ks_year.ks_year;


