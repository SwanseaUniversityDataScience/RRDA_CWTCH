source("r_clear_and_load.r")

# Load =========================================================================
cat("Load\n")

d_c_cohort_raw <- qread(s_drive("d_c_cohort_raw.qs"))
d_m_cohort_raw <- qread(s_drive("d_m_cohort_raw.qs"))
d_b_cohort_raw <- qread(s_drive("d_b_cohort_raw.qs"))

d_c_consort <- qread(s_drive("d_c_consort_raw.qs"))
d_m_consort <- qread(s_drive("d_m_consort_raw.qs"))
d_b_consort <- qread(s_drive("d_b_consort_raw.qs"))

# Select sample ================================================================
cat("Select cohort\n")

d_b_cohort_raw <- d_b_cohort_raw %>%
  mutate(
    valid_sts_cd_c = c_alf_sts_cd %in% c(1,4,39),
    valid_sts_cd_m = m_alf_sts_cd %in% c(1,4,21,22,23,24,39)
  )

# sample selection summary -----------------------------------------------------

t_c_cohort_selection <- tribble(
  ~step, ~criteria, ~n,
  0, "WDSD rows",
  (d_c_consort %>% filter(description == "all wdsd rows"))$n,
  0, "WDSD unique alfs",
  (d_c_consort %>% filter(description == "wdsd unique alf"))$n,
  1, "has valid alf - total rows",
  (d_c_consort %>% filter(description == "all child cohort rows - remove null alfs"))$n,
  1, "has valid alf - unique alf",
  (d_c_consort %>% filter(description == "child cohort unique alf - remove null alfs"))$n,
  2, "has valid sex",
  (d_c_consort %>% filter(description == "child cohort unique alf - remove null sex"))$n,
  3, "wob between 2000 and today",
  (d_c_consort %>% filter(description == "child cohort unique alf - 2000-01-01 <= wob <= today"))$n,
  4, "under 18 when joining the cohort", 
  (d_c_consort %>% filter(description == "child cohort unique alf - valid cohort entry"))$n
) %>%
  mutate(
    n_diff = n - lag(n),
    p_diff = round(n_diff / first(n), 3) * 100
  )

print(as.data.frame(t_c_cohort_selection))

t_m_cohort_selection <- tribble(
  ~step, ~criteria, ~n,
  0, "WDSD rows",
  (d_m_consort %>% filter(description == "all wdsd rows"))$n,
  0, "WDSD unique alfs",
  (d_m_consort %>% filter(description == "wdsd unique alf"))$n,
  1, "alf links to birth table",
  (d_m_consort %>% filter(description == "mother cohort unique alf"))$n
) %>%
  mutate(
    n_diff = n - lag(n),
    p_diff = round(n_diff / first(n), 3) * 100
  )

print(as.data.frame(t_m_cohort_selection))

t_b_cohort_selection <- tribble(
  ~step, ~criteria, ~src, ~n,
  0, "ADBE rows", "adbe",
  (d_b_consort %>% filter(description == "starting population - total rows" & src == "adbe"))$n,
  0, "ADBE unique alfs", "adbe",
  (d_b_consort %>% filter(description == "starting population - unique alf" & src == "adbe"))$n,
  0, "MIDS rows", "mids",
  (d_b_consort %>% filter(description == "starting population - total rows" & src == "mids"))$n,
  0, "MIDS unique alfs", "mids",
  (d_b_consort %>% filter(description == "starting population - unique alf" & src == "mids"))$n,
  0, "NCCH rows", "ncch",
  (d_b_consort %>% filter(description == "starting population - total rows" & src == "ncch"))$n,
  0, "NCCH unique alfs", "ncch",
  (d_b_consort %>% filter(description == "starting population - unique alf" & src == "ncch"))$n,
  1, "child alf links to birth table - total rows", "birth_cohort",
  (d_b_consort %>% filter(description == "combined tables - total rows" & src == "birth_cohort"))$n,
  1, "child alf links to birth table - distinct child alfs", "birth_cohort",
  (d_b_consort %>% filter(description == "combined tables - unique alf" & src == "birth_cohort"))$n,
  1, "mothers alf links to birth table",  "birth_cohort",
  (d_b_consort %>% filter(description == "combined tables - linked mothers" & src == "birth_cohort"))$n,
  2, "null alfs removed - total rows", "birth_cohort",
  (d_b_consort %>% filter(description == "birth cohort total rows - remove null alfs" & src == "birth_cohort"))$n,
  2, "null alfs removed - distinct child alfs", "birth_cohort",
  (d_b_consort %>% filter(description == "birth cohort unique alf - remove null alfs" & src == "birth_cohort"))$n,
  2, "null alfs removed - linked mothers",  "birth_cohort",
  (d_b_consort %>% filter(description == "birth cohort unique alf - remove null alfs - linked mothers" & src == "birth_cohort"))$n,
  3, "invalid sex removed - total rows", "birth_cohort",
  (d_b_consort %>% filter(description == "birth cohort total rows - remove invalid sex" & src == "birth_cohort"))$n,
  3, "invalid sex removed - distinct child alfs", "birth_cohort",
  (d_b_consort %>% filter(description == "birth cohort unique alf - remove invalid sex" & src == "birth_cohort"))$n,
  3, "invalid sex removed - linked mothers",  "birth_cohort",
  (d_b_consort %>% filter(description == "birth cohort unique alf - remove invalid sex - linked mothers" & src == "birth_cohort"))$n,
  4, "2000 <= wob < today - total rows", "birth_cohort",
  (d_b_consort %>% filter(description == "birth cohort total rows - valid wob" & src == "birth_cohort"))$n,
  4, "2000 <= wob < today - distinct child alfs", "birth_cohort",
  (d_b_consort %>% filter(description == "birth cohort unique alf - valid wob" & src == "birth_cohort"))$n,
  4, "2000 <= wob < today - linked mothers",  "birth_cohort",
  (d_b_consort %>% filter(description == "birth cohort unique alf - valid wob - linked mothers" & src == "birth_cohort"))$n,
  5, "child wob = wdsd wob - total rows", "birth_cohort",
  (d_b_consort %>% filter(description == "birth cohort total rows - child wob = wdsd wob" & src == "birth_cohort"))$n,
  5, "child wob = wdsd wob - distinct child alfs", "birth_cohort",
  (d_b_consort %>% filter(description == "birth cohort unique alf - child wob = wdsd wob" & src == "birth_cohort"))$n,
  5, "child wob = wdsd wob - linked mothers",  "birth_cohort",
  (d_b_consort %>% filter(description == "birth cohort unique alf - child wob = wdsd wob - linked mothers" & src == "birth_cohort"))$n,
  6, "child sex = wdsd sex - total rows", "birth_cohort",
  (d_b_consort %>% filter(description == "birth cohort total rows - child sex = wdsd sex" & src == "birth_cohort"))$n,
  6, "child sex = wdsd sex - distinct child alfs", "birth_cohort",
  (d_b_consort %>% filter(description == "birth cohort unique alf - child sex = wdsd sex" & src == "birth_cohort"))$n,
  6, "child sex = wdsd sex - linked mothers",  "birth_cohort",
  (d_b_consort %>% filter(description == "birth cohort unique alf - child sex = wdsd sex - linked mothers" & src == "birth_cohort"))$n,
  7, "child alf != mat alf - total rows", "birth_cohort",
  (d_b_consort %>% filter(description == "birth cohort total rows - consistent mat alf" & src == "birth_cohort"))$n,
  7, "child alf != mat alf - distinct child alfs", "birth_cohort",
  (d_b_consort %>% filter(description == "birth cohort unique alf - consistent mat alf" & src == "birth_cohort"))$n,
  7, "child alf != mat alf - linked mothers",  "birth_cohort",
  (d_b_consort %>% filter(description == "birth cohort unique alf - consistent mat alf - linked mothers" & src == "birth_cohort"))$n,
  8, "mother valid age - total rows", "birth_cohort",
  (d_b_consort %>% filter(description == "birth cohort total rows - mother valid age" & src == "birth_cohort"))$n,
  8, "mother valid age - distinct child alfs", "birth_cohort",
  (d_b_consort %>% filter(description == "birth cohort unique alf - mother valid age" & src == "birth_cohort"))$n,
  8, "mother valid age - linked mothers",  "birth_cohort",
  (d_b_consort %>% filter(description == "birth cohort unique alf - mother valid age - linked mothers" & src == "birth_cohort"))$n,
  9, "sts_cd in 1,4, 39 - total rows", "birth_cohort",
  (d_b_consort %>% filter(description == "birth cohort total rows - valid child sts_cd" & src == "birth_cohort"))$n,
  9, "sts_cd in 1,4, 39 - distinct child alfs", "birth_cohort",
  (d_b_consort %>% filter(description == "birth cohort unique alf - valid child sts_cd" & src == "birth_cohort"))$n,
  9, "sts_cd in 1,4, 39 - linked mothers",  "birth_cohort",
  (d_b_consort %>% filter(description == "birth cohort unique alf - valid child sts_cd - linked mothers" & src == "birth_cohort"))$n,
) %>% group_by(src) %>%
  mutate(
    n_diff = n - lag(n),
    p_diff = round(n_diff / first(n), 3) * 100
  )

print(as.data.frame(t_b_cohort_selection))

# d_b_cohort_raw$m_alf_sts_cd %>% unique()
# d_b_cohort_raw %>% filter(c_alf_sts_cd %in% c("1","4","39") & m_alf_sts_cd %in% c("1","4","21","22","23","24","39")) %>% nrow()
# d_b_cohort_raw %>% filter(c_alf_sts_cd %in% c("1","4","39") & m_alf_sts_cd %in% c("1","4","21","22","23","24","39")) %>% select(c_alf_pe) %>% unique() %>% nrow()
# d_b_cohort_raw %>% filter(c_alf_sts_cd %in% c("1","4","39") & m_alf_sts_cd %in% c("1","4","21","22","23","24","39")) %>% select(m_alf_pe) %>% unique() %>% nrow()
# d_b_cohort_raw %>% filter(valid_sts_cd_c) %>% group_by(m_alf_sts_cd, year(c_wob)) %>%count() %>% arrange(`year(c_wob)`)
# 
# print(as.data.frame(t_b_cohort_selection))
# 
# # apply criteria ---------------------------------------------------------------
# 
# d_m_cohort_raw <-
#   d_m_cohort_raw %>%
#   filter(
#     valid_sts_cd
#     ) %>%
#   arrange(alf_pe)
# 
# d_b_cohort_raw <-
#   d_b_cohort_raw %>%
#   filter(
#     valid_sts_cd_c,
#     valid_sts_cd_m
#     ) %>%
#   arrange(c_alf_pe)

# Cleaning =====================================================================
cat("Cleaning\n")

d_m_cohort_clean <-
  d_m_cohort_raw
d_b_cohort_clean <-
  d_b_cohort_raw
d_c_cohort_clean <-
  d_c_cohort_raw

# Save =========================================================================
cat("Save\n")

# child
qsave(
  t_c_cohort_selection,
  file = "results/t_c_cohort_selection.qs"
)

qsave(
  d_c_cohort_clean,
  file = s_drive("d_c_cohort_clean.qs")
)

# mother
qsave(
  t_m_cohort_selection,
  file = "results/t_m_cohort_selection.qs"
)

qsave(
  d_m_cohort_clean,
  file = s_drive("d_m_cohort_clean.qs")
)

# births
qsave(
  t_b_cohort_selection,
  file = "results/t_b_cohort_selection.qs"
)

qsave(
  d_b_cohort_clean,
  file = s_drive("d_b_cohort_clean.qs")
)

beep()
