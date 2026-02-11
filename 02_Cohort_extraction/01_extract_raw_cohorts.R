source("r_clear_and_load.r")

# Get clean child cohort ===============================================================
cat("Get clean child cohort\n")

con <- db2_open()

q_c_cohort <- "
select 
	cc.alf_pe,
	admin.sex,
	admin.wob,
	admin.death_dt,
	admin.ethn_grp,
	admin.child_cohort_flg,
	admin.birth_cohort_flg,
	admin.mother_cohort_flg,
	admin.wdsd_flg,
	admin.active_from,
	admin.active_to,
	admin.wlgp_flg,
	admin.non_sail_gp_flg,
	admin.sail_gp_flg,
	admin.first_record_wlgp,
	admin.adde_flg,
	admin.pedw_flg,
	admin.edds_flg,
	admin.icnc_flg,
	admin.ccds_flg,
	admin.opdw_flg,
	admin.wrrs_flg,
	admin.cars_flg,
	admin.lac_flg,
	admin.crcs_flg,
	admin.child_protection_register,
	admin.cinw_flg,
	admin.eduw_flg,
	admin.cafw_flg,
	admin.sen_flg,
	admin.fsm_flg
from sailw1409v.child_cohort cc
left join sailw1409v.ADMIN_TABLE admin
  ON cc.alf_pe = admin.alf_pe
  ;"

d_c_cohort <- db2_run(con, q_c_cohort) %>%
  arrange(alf_pe)


# Get raw birth cohort ===============================================================
cat("Get raw birth cohort\n")

q_b_cohort <- "
   select 
	bc.c_alf_pe,
	bc.c_alf_sts_cd,
	bc.c_stillbirth_flg,
	bc.c_birth_weight,
	bc.c_gestational_age,
	bc.c_preterm_birth_flg,
	bc.c_apgar_score,
	bc.c_labour_onset_nm,
	bc.c_delivery_nm,
	bc.c_welsh_birth_flg,
	bc.c_lsoa2011_cd,
	bc.c_wimd2014_decile,
	bc.c_wimd2019_decile,
	bc.C_WIMD2014_QUINTILE,
	bc.C_WIMD2019_QUINTILE,
	bc.C_TOWNSEND2011_QUINTILE,
	bc.C_DEATH_NEONATAL_FLG,
	bc.c_death_birth_asphyxia_flg,
	bc.c_death_short_gestation_flg,
	bc.c_death_sids_flg,
	bc.c_death_diag_cd,
	bc.m_alf_pe,
	bc.m_alf_sts_cd,
	bc.m_consistent_flg,
	bc.m_wob,
	bc.m_age,
	bc.m_sex,
	bc.m_prev_livebirths,
	bc.m_parity,
	bc.m_multiple_gestation_flg,
	bc.m_breast_feeding_intent_flg,
	bc.m_breast_feeding_birth_flg,
	bc.m_breast_feeding_8wks_flg,
	bc.m_lsoa2011_cd,
	bc.m_wimd2014_decile,
	bc.m_wimd2019_decile,
	bc.m_wimd2014_quintile,
	bc.m_wimd2019_quintile,
	bc.m_townsend2011_quintile,
	bc.m_smoking_cat,
	bc.m_marriage_cd,
	bc.m_birth_country_nm,
	bc.m_birth_region_nm,
	bc.m_socioeconomic_class_cd,
	bc.m_occ_class_cd,
	bc.m_ethnicity,
	bc.m_death_date,
	bc.m_death_diag_cd,
	bc.p_trimester1_start_date,
	bc.p_trimester2_start_date,
	bc.p_trimester3_start_date,
	bc.p_preterm_start_date,
	bc.p_preterm_end_date,
	bc.in_ncch,
	bc.in_mids,
	bc.in_adbe,
	bc.flg_wob_wlgp_mismatch,
	bc.flg_wob_wdsd_mismatch,
	bc.flg_incon_mat_alf,
	bc.flg_incon_child_alf,
	bc.flg_mwob_wlgp_mismatch,
	bc.flg_mwob_wdsd_mismatch,
	coalesce(admin.sex, bc.c_sex) sex,
	coalesce(admin.wob, bc.c_wob) wob,
	admin.death_dt,
	admin.ethn_grp,
	admin.child_cohort_flg,
	admin.birth_cohort_flg,
	admin.mother_cohort_flg,
	admin.wdsd_flg,
	admin.active_from,
	admin.active_to,
	admin.wlgp_flg,
	admin.non_sail_gp_flg,
	admin.sail_gp_flg,
	admin.first_record_wlgp,
	admin.adde_flg,
	admin.pedw_flg,
	admin.edds_flg,
	admin.icnc_flg,
	admin.ccds_flg,
	admin.opdw_flg,
	admin.wrrs_flg,
	admin.cars_flg,
	admin.lac_flg,
	admin.crcs_flg,
	admin.child_protection_register,
	admin.cinw_flg,
	admin.eduw_flg,
	admin.cafw_flg,
	admin.sen_flg,
	admin.fsm_flg	
from sailw1409v.birth_cohort bc
  left join sailw1409v.ADMIN_TABLE admin
  ON bc.c_alf_pe = admin.alf_pe
  ;"

d_b_cohort <- db2_run(con, q_b_cohort) %>%
  arrange(c_alf_pe)

# Get raw maternal cohort ======================================================
cat("Get raw maternal cohort\n")

q_m_cohort <- "
  select 
	mc.alf_pe,
	admin.sex,
	admin.wob,
	admin.death_dt,
	admin.ethn_grp,
	admin.child_cohort_flg,
	admin.birth_cohort_flg,
	admin.mother_cohort_flg,
	admin.wdsd_flg,
	admin.active_from,
	admin.active_to,
	admin.wlgp_flg,
	admin.non_sail_gp_flg,
	admin.sail_gp_flg,
	admin.first_record_wlgp,
	admin.adde_flg,
	admin.pedw_flg,
	admin.edds_flg,
	admin.icnc_flg,
	admin.ccds_flg,
	admin.opdw_flg,
	admin.wrrs_flg,
	admin.cars_flg,
	admin.lac_flg,
	admin.crcs_flg,
	admin.child_protection_register,
	admin.cinw_flg,
	admin.eduw_flg,
	admin.cafw_flg,
	admin.sen_flg,
	admin.fsm_flg	
from sailw1409v.mother_cohort mc
  left join sailw1409v.ADMIN_TABLE admin
  ON mc.alf_pe = admin.alf_pe
  ;"

d_m_cohort <- db2_run(con, q_m_cohort) %>% 
  arrange(alf_pe)

# check if alf is unique =======================================================
cat("Check if alfs are unique")

total_n <- d_c_cohort %>% unique() %>% nrow()
alf_n   <- d_c_cohort %>% select(alf_pe) %>% distinct() %>% nrow()
if (alf_n < total_n) {
  stop("ALF is not unique in d_c_cohort")
}

total_n <- d_m_cohort %>% unique() %>% nrow()
alf_n   <- d_m_cohort %>% select(alf_pe) %>% distinct() %>% nrow()
if (alf_n < total_n) {
  stop("ALF is not unique in d_m_cohort")
}

total_n <- d_b_cohort %>% unique() %>% nrow()
alf_n   <- d_b_cohort %>% select(c_alf_pe) %>% distinct() %>% nrow()
if (alf_n < total_n) {
  stop("ALF is not unique in d_b_cohort")
}

# Get consort information ======================================================
cat("Get consort values\n")

q_c_consort <- "
  SELECT * FROM
  sailw1409v.consort_values_child
  ;"

d_c_consort <- db2_run(con, q_c_consort) %>%
  arrange(step, description)

q_b_consort <- "
  SELECT * FROM
  sailw1409v.consort_values_birth
  ;"

d_b_consort <- db2_run(con, q_b_consort) %>%
  arrange(step, description)

q_m_consort <- "
  SELECT * FROM
  sailw1409v.consort_values_mothers
  ;"

d_m_consort <- db2_run(con, q_m_consort) %>%
  arrange(step, description)

# Save =========================================================================
cat("Save\n")

qsave(
  d_b_cohort,
  file = s_drive("d_b_cohort_raw.qs")
)

qsave(
  d_b_consort,
  file = s_drive("d_b_consort_raw.qs")
)

qsave(
  d_c_cohort,
  file = s_drive("d_c_cohort_raw.qs")
)

qsave(
  d_c_consort,
  file = s_drive("d_c_consort_raw.qs")
)

qsave(
  d_m_cohort,
  file = s_drive("d_m_cohort_raw.qs")
)

qsave(
  d_m_consort,
  file = s_drive("d_m_consort_raw.qs")
)

# Goodbye ======================================================================

db2_close(con)
beep()
