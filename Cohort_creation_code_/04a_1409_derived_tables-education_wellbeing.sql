-- =================================================================================================
-- Name:         Educational well-being measures
-- Data sources: EDUW, EDAD
-- Maintainer:   Sarah
-- Contributors: Stu and Emily
-- Created:      2024/18/12
-- Description:  For each academic year, summarise a pupil's attendance, exclusions,
--               special educational needs, free school meals entitlement, and school moves. I also
--               produce several school-level summaries: average class size at key stage 1, support
--               staff to pupil ratio. This script produces an overall summary table, as well as
--               separate detailed tables for attedance, exclusions, and school moves. If you want
--               the separate tables, you will need to stop them being dropped towards the end of
--               the script.
--
--               When processing the data, I make repeat use of the following logic:
--                 * deduplicate the table, derive and format columns e.g. 'academic_year'
--                 * prioritise records for ALFs that have a deterministic match
--                 * supplement with records for ALFs that have only probabilistic matches
--
--               I've only used EDUW as it has the coverage we need, and have actively avoided EDUC
--               because of the many-to-many relationships between ALF and IRN in the linkage table.
-- Credit:		 I've nicked the main body of this script from Stu and Emily, so please credit them!
-- =================================================================================================
-- =================================================================================================
-- Step 1: Setup the main table
-- =================================================================================================

CALL fnc.drop_if_exists('sailw1409v.sa_edu_wellbeing');

CREATE TABLE sailw1409v.sa_edu_wellbeing
(
	alf_pe                         bigint          NOT NULL, -- person ID
	alf_sts_cd                     smallint        NOT NULL, -- linkage status
	academic_year                  smallint        NOT NULL, -- year starting 1st September
	sen_flg                        smallint                , -- 0/1 flag for whether any special provisions have been made
	sen_cat                        varchar(45)             , -- category label for sen code
	free_school_meals_flg          smallint                , -- 0/1 flag for free school meals entitlement
	attendance_prop                decimal(31,19)          , -- absent sessions divided by possible sessions
	attendance_whole_year_flg      smallint                , -- 0/1 flag for if attendance stats are based on whole year
	exclusion_flg                  smallint                , -- 0/1 flag if has any recording of exclusion this year
	exclusion_fixed_n              smallint                , -- number of fixed exclusions this year
	exclusion_perm_n               smallint                , -- number of permenant exclusions this year
	school_type_cat                varchar(38)             , -- category label for type of school they were at on 1st Jan this academic YEAR
	school_supp_staff_fte          double                  , -- full-time equivalent (FTE) number of support staff at the school
	school_supp_staff_pupil_ratio  double                  , -- number of FTE support staff per pupil across the whole school. values between 0 and 1 typically
	pupil_school_move_flg          smallint                , -- 0/1 flag if is recorded as having an unexpected move to this school
	pupil_school_move_cat          varchar(22)             , -- category label for school move status, includes 'no move'
	PRIMARY KEY (alf_pe, academic_year)
);


-- =================================================================================================
-- Step 2: Deduplicate the IRN-to-ALF linkage table
-- =================================================================================================

-- Note that the relationship between IRN and ALF is many-to-one
-- When we have more than one IRN for an ALF, only keep those that match on WOB

CALL fnc.drop_if_exists('sailw1409v.sa_eduw_alf');

CREATE TABLE sailw1409v.sa_eduw_alf
(
	irn_pe        bigint    NOT NULL, -- irn - pupil number
	alf_pe        bigint    NOT NULL, -- alf
	alf_sts_cd    smallint  NOT NULL, -- match status code
	wob           date      NOT NULL, -- week of birth from edu
	wob_wds       date              , -- week of birth from wdsd
	rec_year      smallint          , -- academic year which they start reception
	yr3_year      smallint          , -- academic year which they start Year 3
	yr7_year      smallint          , -- academic year which they start Year 7
	yr12_year     smallint          , -- academic year which they start Year 12 / first year of sixth form
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
			wdsd.wob AS wob_wds
		FROM sail1409v.eduw_pupil_alf_20221017 AS pupil
		LEFT JOIN sail1409v.wdsd_single_clean_ar_pers_20240909 as wdsd
			ON pupil.alf_pe = wdsd.alf_pe
		WHERE alf_sts_cd IN (1, 4, 39)
		GROUP BY
			pupil.irn_pe,
			pupil.alf_pe,
			pupil.wob,
			wdsd.wob
	),
	-- find alfs with multiple irns
	alf_many_id AS
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
	CASE
		WHEN month(alf_dedup.wob) < 9 THEN year(alf_dedup.wob + 4 years)
		ELSE year(alf_dedup.wob + 5 years)
	END AS rec_year,
	CASE
		WHEN month(alf_dedup.wob) < 9 THEN year(alf_dedup.wob + 7 years)
		ELSE year(alf_dedup.wob + 8 years)
	END AS yr3_year,
	CASE
		WHEN month(alf_dedup.wob) < 9 THEN year(alf_dedup.wob + 11 years)
		ELSE year(alf_dedup.wob + 12 years)
	END AS yr7_year,
	CASE
		WHEN month(alf_dedup.wob) < 9 THEN year(alf_dedup.wob + 16 years)
		ELSE year(alf_dedup.wob + 17 years)
	END AS yr12_year
FROM alf_dedup
LEFT JOIN alf_many_id
	ON alf_dedup.alf_pe = alf_many_id.alf_pe
WHERE
	alf_many_id.alf_pe IS NULL
	OR alf_dedup.wob = alf_dedup.wob_wds;


-- =================================================================================================
-- Step 3: Extract special educational needs status and free school meals entitlement
-- =================================================================================================

-- setup table for final values

CALL fnc.drop_if_exists('sailw1409v.sa_edu_sen_fsm');

CREATE TABLE sailw1409v.sa_edu_sen_fsm
(
	alf_pe             bigint          NOT NULL, -- alf
	alf_sts_cd         smallint        NOT NULL, -- match status code
	academic_year      smallint        NOT NULL, -- school year starting 1st September
	sen_cd             varchar(1)              , -- original code for special educational needs
	sen_nm             varchar(45)             , -- name (i.e. label) for sen code
	fsm_flg            smallint                , -- 0/1 flag for free school meals
	return_date        date                    , -- date for which the data was returned to government
	PRIMARY KEY (alf_pe, academic_year)
);


-- make lookup table of labels for the special educational needs codes

CALL fnc.drop_if_exists('sailw1409v.sa_lkp_sen');

CREATE TABLE sailw1409v.sa_lkp_sen
(
	id     smallint,
	code   varchar(1),
	name   varchar(45)
);

INSERT INTO sailw1409v.sa_lkp_sen
VALUES
(1, 'N', 'No Special Provision'),
(2, 'A', 'School Action'),
(3, 'P', 'School Action Plus'),
(4, 'Q', 'School Action Plus and Statutory Assessment'),
(5, 'S', 'Statemented');


-- compare years
WITH
	pupil_return AS
	(
		SELECT
			pupil.irn_pe,
			left(pupil.year, 4) AS return_year,
			right(pupil.year, 2) AS return_month,
			date(timestamp_format(pupil.year, 'yyyymm')) AS return_date
		FROM sail1409v.eduw_pupil_20221017 AS pupil
	)
SELECT
	return_year,
	sum(CASE WHEN return_month = '01' THEN 1 ELSE 0 END) AS month_01,
	sum(CASE WHEN return_month = '06' THEN 1 ELSE 0 END) AS month_06,
	sum(CASE WHEN return_month = '09' THEN 1 ELSE 0 END) AS month_09
FROM pupil_return
GROUP BY return_year
ORDER BY return_year;


-- get sen and fsm values per school year
INSERT INTO sailw1409v.sa_edu_sen_fsm
WITH
	-- derive school year
	pupil AS
	(
		SELECT
			pupil.irn_pe,
			pupil.senprovision,
			pupil.fsmeligible,
			CASE
				WHEN right(pupil.year, 2) = '01' THEN cast(left(pupil.year, 4) AS smallint) - 1
				WHEN right(pupil.year, 2) = '06' THEN cast(left(pupil.year, 4) AS smallint) - 1
				WHEN right(pupil.year, 2) = '09' THEN cast(left(pupil.year, 4) AS smallint)
			END AS academic_year,
			date(timestamp_format(pupil.year, 'yyyymm')) AS return_date
		FROM sail1409v.eduw_pupil_20221017 AS pupil
	),
	-- deduplicate the pupil table
	-- use ID from SEN look-up table to prioritise all other statuses over 'no special provision'
	pupil_dedup AS
	(
		SELECT
			irn_pe,
			academic_year,
			max(lkp_sen.id) AS sen_id,
			max(fsmeligible) AS fsm_flg,
			max(return_date) AS return_date
		FROM pupil
		LEFT JOIN sailw1409v.sa_lkp_sen AS lkp_sen
			ON upper(pupil.senprovision) = lkp_sen.code
		GROUP BY irn_pe, academic_year
	),
	-- summary for alfs with deterministic matches
	alf_dt AS
	(
		SELECT
			alf.alf_pe,
			alf.alf_sts_cd,
			pupil_dedup.academic_year,
			max(pupil_dedup.sen_id)      AS sen_id,
			max(pupil_dedup.fsm_flg)     AS fsm_flg,
			max(pupil_dedup.return_date) AS return_date
		FROM sailw1409v.sa_eduw_alf AS alf
		INNER JOIN pupil_dedup
			ON alf.irn_pe = pupil_dedup.irn_pe
		WHERE alf.alf_sts_cd = 4
		GROUP BY
			alf.alf_pe,
			alf.alf_sts_cd,
			pupil_dedup.academic_year
	),
	-- summary for additional alfs with probabilistic matches
	alf_pr AS
	(
		SELECT
			alf.alf_pe,
			alf.alf_sts_cd,
			pupil_dedup.academic_year,
			max(pupil_dedup.sen_id)      AS sen_id,
			max(pupil_dedup.fsm_flg)     AS fsm_flg,
			max(pupil_dedup.return_date) AS return_date
		FROM sailw1409v.sa_eduw_alf AS alf
		INNER JOIN pupil_dedup
			ON alf.irn_pe = pupil_dedup.irn_pe
		LEFT JOIN alf_dt
			ON alf.alf_pe = alf_dt.alf_pe
		WHERE
			alf.alf_sts_cd = 39
			AND alf_dt.alf_pe IS NULL
		GROUP BY
			alf.alf_pe,
			alf.alf_sts_cd,
			pupil_dedup.academic_year
	)
-- combine by stacking the rows
SELECT
	alf_dt.alf_pe,
	alf_dt.alf_sts_cd,
	alf_dt.academic_year,
	lkp_sen.code AS sen_cd,
	lkp_sen.name AS sen_nm,
	alf_dt.fsm_flg,
	alf_dt.return_date
	FROM alf_dt
	LEFT JOIN sailw1409v.sa_lkp_sen AS lkp_sen
	ON alf_dt.sen_id = lkp_sen.id
UNION ALL
SELECT
	alf_pr.alf_pe,
	alf_pr.alf_sts_cd,
	alf_pr.academic_year,
	lkp_sen.code AS sen_cd,
	lkp_sen.name AS sen_nm,
	alf_pr.fsm_flg,
	alf_pr.return_date
	FROM alf_pr
	LEFT JOIN sailw1409v.sa_lkp_sen AS lkp_sen
	ON alf_pr.sen_id = lkp_sen.id;


-- =================================================================================================
-- Step 4: Extract attendance summaries per school year
-- =================================================================================================

CALL fnc.drop_if_exists('sailw1409v.sa_edu_atnd');

CREATE TABLE sailw1409v.sa_edu_atnd
(
	alf_pe             bigint          NOT NULL, -- alf
	alf_sts_cd         smallint        NOT NULL, -- match status code
	academic_year      smallint        NOT NULL, -- school year starting 1st September
	whole_year_flg     smallint        NOT NULL, -- 0/1 flag for if attendance stats are based on the whole year or where they reported early in July
	sessions_possible  integer         NOT NULL, -- total number of possible sessions for the term (a half day is one session)
	sessions_absent    integer         NOT NULL, -- total number of absent sessions, authorised and unauthorised
	attendance_prop    decimal(31,19)  NOT NULL, -- absent sessions divided by possible sessions
	return_date        date            NOT NULL, -- date for which the attendance records where returned to government
	PRIMARY KEY (alf_pe, academic_year)
);

INSERT INTO sailw1409v.sa_edu_atnd
WITH
	attnd_dedup AS
	(
		SELECT
			irn_pe,
			cast(left(YEAR, 4)         AS smallint) - 1 AS academic_year,
			cast(right(YEAR, 2) = '10' AS smallint)     AS whole_year_flg,
			sessionspossible                            AS sessions_possible,
			sessionsattended                            AS sessions_attended,
			date(timestamp_format(YEAR, 'yyyymm'))      AS return_date
		FROM sail1409v.eduw_attendance_20221017
		WHERE sessionspossible > 0
		GROUP BY irn_pe, YEAR, sessionspossible, sessionsattended
		ORDER BY irn_pe, YEAR
	),
	alf_dt AS
	(
		SELECT
			alf.alf_pe,
			alf.alf_sts_cd,
			attnd_dedup.academic_year,
			max(attnd_dedup.whole_year_flg)                                               AS whole_year_flg,
			sum(attnd_dedup.sessions_possible)                                             AS sessions_possible,
			sum(attnd_dedup.sessions_possible) - sum(attnd_dedup.sessions_attended)        AS sessions_absent,
			1.00 * sum(attnd_dedup.sessions_attended) / sum(attnd_dedup.sessions_possible) AS attedance_prop,
			max(attnd_dedup.return_date)                                                   AS return_date
		FROM sailw1409v.sa_eduw_alf AS alf
		INNER JOIN attnd_dedup
			ON alf.irn_pe = attnd_dedup.irn_pe
		WHERE
			alf.alf_sts_cd = 4
		GROUP BY
			alf.alf_pe,
			alf.alf_sts_cd,
			attnd_dedup.academic_year
	),
	alf_pr AS
	(
		SELECT
			alf.alf_pe,
			alf.alf_sts_cd,
			attnd_dedup.academic_year,
			max(attnd_dedup.whole_year_flg)                                               AS whole_year_flg,
			sum(attnd_dedup.sessions_possible)                                             AS sessions_possible,
			sum(attnd_dedup.sessions_possible) - sum(attnd_dedup.sessions_attended)        AS sessions_absent,
			1.00 * sum(attnd_dedup.sessions_attended) / sum(attnd_dedup.sessions_possible) AS attedance_prop,
			max(attnd_dedup.return_date)                                                   AS return_date
		FROM sailw1409v.sa_eduw_alf AS alf
		INNER JOIN attnd_dedup
			ON alf.irn_pe = attnd_dedup.irn_pe
		LEFT JOIN alf_dt
			ON alf.alf_pe = alf_dt.alf_pe
		WHERE
			alf.alf_sts_cd = 39
			AND alf_dt.alf_pe IS NULL
		GROUP BY
			alf.alf_pe,
			alf.alf_sts_cd,
			attnd_dedup.academic_year
	)
-- stack rows
SELECT * FROM alf_dt
UNION ALL
SELECT * FROM alf_pr
ORDER BY alf_pe, academic_year;


-- =================================================================================================
-- Step 5: Extract fixed and permanent exclusions
-- =================================================================================================

-- setup table for final values

CALL fnc.drop_if_exists('sailw1409v.sa_edu_excl');

CREATE TABLE sailw1409v.sa_edu_excl
(
	alf_pe           bigint       NOT NULL, -- alf
	alf_sts_cd       smallint     NOT NULL, -- match status code
	academic_year    smallint     NOT NULL, -- school year starting 1st September
	lea              smallint     NOT NULL, -- local education authority
	estab_pe         bigint       NOT NULL, -- school ID
	excl_cat         varchar(4)   NOT NULL, -- exclusion category: fixd or perm
	excl_reason_cd   varchar(2)           , -- original reason code for exclusion
	excl_reason_cat  varchar(45)          , -- category labels for reason code
	excl_sessions    smallint             , -- number of sessions excluded for
	return_date      date         NOT NULL  -- date data return to government
);


-- make lookup table of labels for the exclusion reason codes

CALL fnc.drop_if_exists('sailw1409v.sa_lkp_excl_reason');

CREATE TABLE sailw1409v.sa_lkp_excl_reason
(
	code   varchar(2),
	name   varchar(45)
);

INSERT INTO sailw1409v.sa_lkp_excl_reason
VALUES
('BU', 'Bullying'),
('DA', 'Drug and alcohol'),
('DB', 'Disruptive behaviour'),
('DM', 'Damage'),
('DR', 'Defiance of rules'),
('OT', 'Other'),
('PA', 'Physical assault against an adult'),
('PP', 'Physical assault against a pupil'),
('PW', 'Possession of a weapon'),
('RA', 'Racist abuse'),
('SM', 'Sexual misconduct'),
('TB', 'Threatening behaviour'),
('TH', 'Theft'),
('VA', 'Verbal abuse against an adult'),
('VP', 'Verbal abuse against a pupil');


-- get exclusions

INSERT INTO sailw1409v.sa_edu_excl
WITH
	excl AS
	(
		SELECT
			irn_pe,
			cast(left(year, 4) AS smallint) - 2    AS academic_year,
			lea,
			estab_pe,
			exclusioncategory                      AS excl_cat,
			reason                                 AS excl_reason_cd,
			lkp_reason.name                        AS excl_reason_name,
			sessionsmissed                         AS excl_sessions,
			date(timestamp_format(year, 'yyyymm')) AS return_date
		FROM sail1409v.eduw_exclusions_perm_and_fixed_20221017 AS excl
		LEFT JOIN sailw1409v.sa_lkp_excl_reason AS lkp_reason
			ON excl.reason = lkp_reason.code
		WHERE
			exclusioncategory != 'LNCH'
	),
	-- exclusions for alfs with deterministic matches
	alf_dt AS
	(
		SELECT
			alf.alf_pe,
			alf.alf_sts_cd,
			excl.academic_year,
			excl.lea,
			excl.estab_pe,
			excl.excl_cat,
			excl.excl_reason_cd,
			excl.excl_reason_name,
			excl.excl_sessions,
			excl.return_date
		FROM sailw1409v.sa_eduw_alf AS alf
		INNER JOIN excl
			ON alf.irn_pe = excl.irn_pe
		WHERE alf.alf_sts_cd = 4
	),
	-- exclusions for additional alfs with probabilistic matches
	alf_pr AS
	(
		SELECT
			alf.alf_pe,
			alf.alf_sts_cd,
			excl.academic_year,
			excl.lea,
			excl.estab_pe,
			excl.excl_cat,
			excl.excl_reason_cd,
			excl.excl_reason_name,
			excl.excl_sessions,
			excl.return_date
		FROM sailw1409v.sa_eduw_alf AS alf
		INNER JOIN excl
			ON alf.irn_pe = excl.irn_pe
		LEFT JOIN alf_dt
			ON alf.alf_pe = alf_dt.alf_pe
		WHERE
			alf.alf_sts_cd = 39
			AND alf_dt.alf_pe IS NULL
	)
-- combine by stacking the rows
SELECT * FROM alf_dt
UNION ALL
SELECT * FROM alf_pr;


-- =================================================================================================
-- Step 6: Summarise exclusions per alf school year
-- =================================================================================================

CALL fnc.drop_if_exists('sailw1409v.sa_edu_excl_summary');

CREATE TABLE sailw1409v.sa_edu_excl_summary
(
	alf_pe              bigint       NOT NULL, -- alf
	alf_sts_cd          smallint     NOT NULL, -- match status code
	academic_year       smallint     NOT NULL, -- school year starting 1st September
	excl_fixed_n        smallint             , -- number of fixed exclusions this year
	excl_perm_n         smallint             , -- number of permenant exclusions this year
	PRIMARY KEY (alf_pe, academic_year)
);

INSERT INTO sailw1409v.sa_edu_excl_summary
SELECT
	alf_pe,
	alf_sts_cd,
	academic_year,
	sum(cast(excl_cat = 'FIXD' AS smallint)) AS excl_fixd_n,
	sum(cast(excl_cat = 'PERM' AS smallint)) AS excl_perm_n
FROM sailw1409v.sa_edu_excl
GROUP BY
	alf_pe,
	alf_sts_cd,
	academic_year;


-- =================================================================================================
-- Step 7: Identify school moves
-- =================================================================================================

CALL fnc.drop_if_exists('sailw1409v.sa_edu_pupil_school_year');

CREATE TABLE sailw1409v.sa_edu_pupil_school_year
(
	alf_pe                          bigint       NOT NULL, -- alf
	alf_sts_cd                      smallint     NOT NULL, -- match status code
	academic_year                   smallint     NOT NULL, -- school year starting 1st September
	lea                             smallint     NOT NULL, -- local education authority
	estab_pe                        bigint       NOT NULL, -- school ID
	school_type_cd                  smallint             , -- new code for school type
	school_type_cat                 varchar(38)          , -- category label for school type code
	pupil_school_move_cat           varchar(22)          , -- category label for school move including 'no move'
	pupil_school_move_flg           smallint             , -- 0/1 flag if is recorded as having an unexpected school move
	school_supp_staff_n             smallint             , -- number of support staff at the school
	school_supp_staff_fte           double               , -- full-time equivalent (FTE) number of support staff at the school
	school_supp_staff_pupil_ratio   double               , -- number of FTE support staff per pupil across the whole school. values between 0 and 1 typically
	return_date                     date                 , -- date data returned to government
	PRIMARY KEY (alf_pe, academic_year, lea, estab_pe)
);


-- make lookup table of school types

CALL fnc.drop_if_exists('sailw1409v.sa_lkp_school_type');

CREATE TABLE sailw1409v.sa_lkp_school_type
(
	old_code  smallint,
	new_code  smallint,
	new_name  varchar(38)
);

INSERT INTO sailw1409v.sa_lkp_school_type
VALUES
(50,   10, 'Nursery'),
(16,   21, 'Infant school'),
(19,   21, 'Infant school'),
(17,   22, 'Junior school'),
(18,   20, 'Primary school'),
(20,   20, 'Primary school'),
(21,   41, 'Secondary school w/o post-16 provision'),
(22,   42, 'Secondary school w/ post-16 provision'),
(52,   51, 'Maintained special day school'),
(70,   52, 'Special school w/o post-16 provision'),
(71,   53, 'Special school w/ post-16 provision'),
(80,   60, 'Pupil referral unit'),
(51, NULL, NULL);


-- get values

INSERT INTO sailw1409v.sa_edu_pupil_school_year
(
	alf_pe,
	alf_sts_cd,
	academic_year,
	lea,
	estab_pe,
	school_type_cd,
	school_type_cat,
	pupil_school_move_cat,
	pupil_school_move_flg,
	return_date
)
WITH
	-- deduplicate, tidy values, and select the records we're interested in
	pupil_school AS
	(
		SELECT
			alf.alf_pe,
			alf.alf_sts_cd,
			alf.irn_pe,
			alf.wob,
			alf.rec_year AS alf_rec_year,
			alf.yr3_year AS alf_yr3_year,
			alf.yr7_year AS alf_yr7_year,
			alf.yr12_year AS alf_yr12_year,
			floor(pupil.year / 100) - 1 AS academic_year,
			date(to_timestamp(pupil.year, 'yyyymm')) AS return_date,
			pupil.lea,
			pupil.estab_pe,
			lkp_school_type.new_code AS school_type_cd,
			lkp_school_type.new_name AS school_type_nm
		FROM sailw1409v.sa_eduw_alf AS alf
		INNER JOIN sail1409v.eduw_pupil_20221017 AS pupil
			ON alf.irn_pe = pupil.irn_pe
		INNER JOIN sail1409v.eduw_school_20221017 AS school
			ON  pupil.lea      = school.lea
			AND pupil.estab_pe = school.estab_pe
			AND pupil.year     = school.year
		LEFT JOIN sailw1409v.sa_lkp_school_type AS lkp_school_type
			ON school.schooltype = lkp_school_type.old_code
		WHERE
			right(pupil.year, 2) = '01' -- January census ONLY please
		GROUP BY
			alf.alf_pe,
			alf.alf_sts_cd,
			alf.irn_pe,
			alf.wob,
			alf.rec_year,
			alf.yr3_year,
			alf.yr7_year,
			alf.yr12_year,
			pupil.year,
			pupil.lea,
			pupil.estab_pe,
			lkp_school_type.new_code,
			lkp_school_type.new_name
		ORDER BY
			alf.alf_pe,
			alf.irn_pe,
			pupil.year
	),
	-- derive first year they attended each school
	-- we will use this later to identify if a school move has really occurred
	school_first_year AS
	(
		SELECT alf_pe, irn_pe, lea, estab_pe,
			min(academic_year) AS school_first_year
		FROM pupil_school
		GROUP BY alf_pe, irn_pe, lea, estab_pe
	),
	-- get previous school and type
	-- and add first year they attended each school to the working table
	pupil_school_lag AS
	(
		SELECT
			pupil_school.*,
			school_first_year.school_first_year,
			lag(pupil_school.lea)            OVER (PARTITION BY pupil_school.irn_pe ORDER BY pupil_school.return_date) AS lag_lea,
			lag(pupil_school.estab_pe)       OVER (PARTITION BY pupil_school.irn_pe ORDER BY pupil_school.return_date) AS lag_estab_pe,
			lag(pupil_school.school_type_cd) OVER (PARTITION BY pupil_school.irn_pe ORDER BY pupil_school.return_date) AS lag_school_type_cd
		FROM pupil_school
		LEFT JOIN school_first_year
			ON  pupil_school.alf_pe   = school_first_year.alf_pe
			AND pupil_school.irn_pe   = school_first_year.irn_pe
			AND pupil_school.lea      = school_first_year.lea
			AND pupil_school.estab_pe = school_first_year.estab_pe
	),
	-- define whether there has been a school move
	school_move_cat AS
	(
		SELECT
			*,
			CASE
				WHEN lag_lea IS NULL AND lag_estab_pe IS NULL                                                                                   THEN '0_first_school'
				WHEN lea = lag_lea AND estab_pe = lag_estab_pe                                                                                  THEN '0_no_move'
				WHEN (lea != lag_lea OR estab_pe != lag_estab_pe) AND school_first_year < academic_year                                         THEN '0_no_move'
				WHEN (lea != lag_lea OR estab_pe != lag_estab_pe) AND alf_rec_year  = academic_year                                             THEN '1_start_rec'
				WHEN (lea != lag_lea OR estab_pe != lag_estab_pe) AND left(lag_school_type_cd, 1) = 1 AND left(school_type_cd, 1) = 2           THEN '1_start_rec'
				WHEN (lea != lag_lea OR estab_pe != lag_estab_pe) AND alf_yr3_year  = academic_year                                             THEN '1_start_yr3'
				WHEN (lea != lag_lea OR estab_pe != lag_estab_pe) AND lag_school_type_cd = 21 AND left(school_type_cd, 1) = 2                   THEN '1_start_yr3'
				WHEN (lea != lag_lea OR estab_pe != lag_estab_pe) AND alf_yr7_year  = academic_year                                             THEN '1_start_yr7'
				WHEN (lea != lag_lea OR estab_pe != lag_estab_pe) AND left(lag_school_type_cd, 1) = 2 AND left(school_type_cd, 1) = 4           THEN '1_start_yr7'
				WHEN (lea != lag_lea OR estab_pe != lag_estab_pe) AND alf_yr12_year = academic_year                                             THEN '1_start_yr12'
				WHEN (lea != lag_lea OR estab_pe != lag_estab_pe) AND lag_school_type_cd NOT IN (51, 52, 53) AND school_type_cd IN (51, 52, 53) THEN '2_start_special_school'
				WHEN (lea != lag_lea OR estab_pe != lag_estab_pe) AND lag_school_type_cd IN (51, 52, 53) AND school_type_cd NOT IN (51, 52, 53) THEN '2_end_special_school'
				WHEN (lea != lag_lea OR estab_pe != lag_estab_pe) AND lag_school_type_cd != 60 AND school_type_cd  = 60                         THEN '3_start_pru'
				WHEN (lea != lag_lea OR estab_pe != lag_estab_pe) AND lag_school_type_cd  = 60 AND school_type_cd != 60                         THEN '3_end_pru'
				WHEN (lea != lag_lea OR estab_pe != lag_estab_pe)                                                                               THEN '4_school_move'
				ELSE '99_try_again'
			END AS school_move_cat
		FROM
			pupil_school_lag
	),
	-- summary for alfs with deterministic matches
	-- add a row number to help detect when an alf has two records at the same school for the same year
	alf_dt AS
	(
		SELECT
			smc.alf_pe,
			smc.alf_sts_cd,
			smc.academic_year,
			smc.lea,
			smc.estab_pe,
			smc.school_type_cd,
			smc.school_type_nm,
			smc.school_move_cat,
			cast(left(smc.school_move_cat, 1) IN ('3', '4') AS smallint) AS school_move_flg,
			smc.return_date,
			row_number() OVER (PARTITION BY smc.alf_pe, smc.academic_year, smc.lea, smc.estab_pe ORDER BY smc.school_move_cat) AS dedup_seq
		FROM school_move_cat AS smc
		WHERE
			smc.alf_sts_cd = 4
	),
	-- summary for additional alfs with probabilistic matches
	alf_pr AS
	(
		SELECT
			smc.alf_pe,
			smc.alf_sts_cd,
			smc.academic_year,
			smc.lea,
			smc.estab_pe,
			smc.school_type_cd,
			smc.school_type_nm,
			smc.school_move_cat,
			cast(left(smc.school_move_cat, 1) IN ('3', '4') AS smallint) AS school_move_flg,
			smc.return_date,
			row_number() OVER (PARTITION BY smc.alf_pe, smc.academic_year, smc.lea, smc.estab_pe ORDER BY smc.school_move_cat) AS dedup_seq
		FROM school_move_cat AS smc
		LEFT JOIN alf_dt
			ON smc.alf_pe = alf_dt.alf_pe
		WHERE
			smc.alf_sts_cd = 39
			AND alf_dt.alf_pe IS NULL
	),
	-- stack rows from each type of matching
	alf_stack AS
	(
		SELECT * FROM alf_dt
		UNION ALL
		SELECT * FROM alf_pr
	)
-- final attempt at deduplicating as in a small number of cases
-- one ALF matched to more than one IRN
SELECT
	alf_pe,
	alf_sts_cd,
	academic_year,
	lea,
	estab_pe,
	school_type_cd,
	school_type_nm,
	school_move_cat,
	school_move_flg,
	return_date
FROM alf_stack
WHERE dedup_seq = 1;


-- add in the school staff measures
-- note: I dont like MERGE INTO, it be a slowpoke

MERGE INTO sailw1409v.sa_edu_pupil_school_year AS psy
USING
	(
		SELECT
			floor(year / 100) - 1 AS academic_year,
			lea,
			estab_pe,
			numberofsupportstaff AS supp_staff_n,
			numberofsupportstafffte AS supp_staff_fte,
			schoolsize AS school_size,
			1.0 * numberofsupportstafffte / schoolsize AS supp_staff_pupil_ratio,
			date(to_timestamp(year, 'yyyymm')) AS return_date
		FROM sail1409v.eduw_school_20221017
		WHERE
			right(year, 2) = '01' -- January census only
			AND schoolsize IS NOT NULL
			AND schoolsize > 0
	) As school_support_staff
ON  psy.academic_year = school_support_staff.academic_year
AND psy.lea           = school_support_staff.lea
AND psy.estab_pe      = school_support_staff.estab_pe
WHEN MATCHED THEN UPDATE SET
	psy.school_supp_staff_n           = school_support_staff.supp_staff_n,
	psy.school_supp_staff_fte         = school_support_staff.supp_staff_fte,
	psy.school_supp_staff_pupil_ratio = school_support_staff.supp_staff_pupil_ratio;


-- =================================================================================================
-- Step 8: Summarise for pupil-year for school moves, school type and support staff-pupil ratio
-- =================================================================================================

CALL fnc.drop_if_exists('sailw1409v.sa_edu_pupil_school_summary');

CREATE TABLE sailw1409v.sa_edu_pupil_school_summary
(
	alf_pe                          bigint           NOT NULL, -- alf
	alf_sts_cd                      smallint         NOT NULL, -- match status code
	academic_year                   smallint         NOT NULL, -- school year starting 1st September
	lea                             smallint         NOT NULL, -- local education authority
	estab_pe                        bigint           NOT NULL, -- school ID
	school_type_cat                 varchar(38)              , -- category label for school type code
	pupil_school_move_cat           varchar(22)              , -- category label for school move including 'no move'
 	pupil_school_move_flg           smallint                 , -- 0/1 flag if is recorded as having an unexpected school move
 	school_supp_staff_fte           double                   , -- fte number of support staff at the school
 	school_supp_staff_pupil_ratio   double                   , -- number of pupils per fte support staff across the whole school
	PRIMARY KEY (alf_pe, academic_year)
);

INSERT INTO sailw1409v.sa_edu_pupil_school_summary
WITH
	alf_year_seq AS
	(
		SELECT
			*,
			row_number() OVER (PARTITION BY alf_pe, academic_year ORDER BY pupil_school_move_flg DESC) AS alf_year_seq
		FROM sailw1409v.sa_edu_pupil_school_year
	)
SELECT
	alf_pe,
	alf_sts_cd,
	academic_year,
	lea,
	estab_pe,
	school_type_cat,
	pupil_school_move_cat,
	pupil_school_move_flg,
	school_supp_staff_fte,
	school_supp_staff_pupil_ratio
FROM alf_year_seq
WHERE alf_year_seq = 1;


-- =================================================================================================
-- Step 9: Gather everything together and insert into main summary table
-- =================================================================================================

-- use sen/fsm table as a spine, since its based only on the pupil table

INSERT INTO sailw1409v.sa_edu_wellbeing
SELECT
	pupil.alf_pe                               AS alf_pe,
	pupil.alf_sts_cd                           AS alf_sts_cd,
	pupil.academic_year                        AS academic_year,
	cast(pupil.sen_cd != 'N' AS smallint)      AS sen_flg,
	pupil.sen_nm                               AS sen_cat,
	pupil.fsm_flg                              AS free_school_meals_flg,
	atnd.attendance_prop                       AS attendance_prop,
	atnd.whole_year_flg                        AS attendance_whole_year_flg,
	cast(excl.alf_pe IS NOT NULL AS smallint)  AS exclusion_flg,
	excl.excl_fixed_n                          AS exclusion_fixed_n,
	excl.excl_perm_n                           AS exclusion_perm_n,
	schl.school_type_cat                       AS school_type_cat,
	schl.school_supp_staff_fte                 AS school_supp_staff_fte,
	schl.school_supp_staff_pupil_ratio         AS school_supp_staff_pupil_ratio,
	schl.pupil_school_move_flg                 AS pupil_school_move_flg,
	schl.pupil_school_move_cat                 AS pupil_school_move_cat
FROM sailw1409v.sa_edu_sen_fsm AS pupil
LEFT JOIN sailw1409v.sa_edu_atnd AS atnd
	ON  pupil.alf_pe        = atnd.alf_pe
	AND pupil.academic_year = atnd.academic_year
LEFT JOIN sailw1409v.sa_edu_excl_summary AS excl
	ON  pupil.alf_pe        = excl.alf_pe
	AND pupil.academic_year = excl.academic_year
LEFT JOIN sailw1409v.sa_edu_pupil_school_summary AS schl
	ON  pupil.alf_pe        = schl.alf_pe
	AND pupil.academic_year = schl.academic_year;


-- =================================================================================================
-- Step 10: Tidy up, BAU!
-- =================================================================================================

CALL fnc.drop_if_exists('sailw1409v.sa_eduw_alf');
CALL fnc.drop_if_exists('sailw1409v.sa_edu_sen_fsm');
CALL fnc.drop_if_exists('sailw1409v.sa_lkp_sen');
CALL fnc.drop_if_exists('sailw1409v.sa_edu_atnd');
CALL fnc.drop_if_exists('sailw1409v.sa_edu_excl');
CALL fnc.drop_if_exists('sailw1409v.sa_lkp_excl_reason');
CALL fnc.drop_if_exists('sailw1409v.sa_edu_excl_summary');
CALL fnc.drop_if_exists('sailw1409v.sa_edu_pupil_school_year');
CALL fnc.drop_if_exists('sailw1409v.sa_lkp_school_type');
CALL fnc.drop_if_exists('sailw1409v.sa_edu_pupil_school_summary');


-- =================================================================================================
-- Step 11: Give us something to look at!
-- =================================================================================================

SELECT * FROM sailw1409v.sa_edu_wellbeing ORDER BY alf_pe, academic_year;
SELECT * FROM sailw1409v.sa_edu_atnd;

-- per academic year, count number of pupils with SEN, FSM, have been excluded, moved school, and
-- calc overall average attendance

SELECT
	academic_year,
	count(*)                                                           AS alf_n,
	sum(sen_flg)                                                       AS has_sen,
	sum(free_school_meals_flg)                                         AS has_fsm,
	sum(CASE WHEN attendance_prop IS NOT NULL THEN 1 ELSE 0 END)       AS has_atnd,
	round(avg(attendance_prop), 3)                                     AS avg_atnd_prop,
	sum(exclusion_flg)                                                 AS has_exclusion,
	sum(pupil_school_move_flg)                                         AS has_school_move,
	sum(CASE WHEN school_supp_staff_fte IS NOT NULL THEN 1 ELSE 0 END) AS supp_staff_not_null,
	round(avg(school_supp_staff_pupil_ratio), 3)                       AS avg_supp_staff_ratio
FROM sailw1409v.sa_edu_wellbeing
GROUP BY academic_year
ORDER BY academic_year;

-- per school type, count number of pupils with SEN, FSM, have been excluded, moved school, and
-- calc overall average attendance

SELECT 
	school_type_cat,
	count(*)                                                           AS alf_n,
	sum(sen_flg)                                                       AS has_sen,
	sum(free_school_meals_flg)                                         AS has_fsm,
	sum(CASE WHEN attendance_prop IS NOT NULL THEN 1 ELSE 0 END)       AS has_atnd,
	round(avg(attendance_prop), 3)                                     AS avg_atnd_prop,
	sum(exclusion_flg)                                                 AS has_exclusion,
	sum(pupil_school_move_flg)                                         AS has_school_move,
	sum(CASE WHEN school_supp_staff_fte IS NOT NULL THEN 1 ELSE 0 END) AS supp_staff_not_null,
	round(avg(school_supp_staff_pupil_ratio), 3)                       AS avg_supp_staff_ratio
FROM sailw1409v.sa_edu_wellbeing 
GROUP BY school_type_cat 
ORDER BY school_type_cat;

