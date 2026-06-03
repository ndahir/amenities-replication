t################################################################################
# Replication Code for:
#   "Intersecting Inequalities: Blackness, Immigrant Status, and the
#    Prevalence of Neighborhood Amenities"
#
# Script:  01_main_analysis.R
# Purpose: Produce all main-text tables and figures:
#            Table 1  – descriptive statistics of group shares by city
#            Table 2  – descriptive statistics of amenity variables
#            Table 3  – main spatial random-effects models
#            Figure 1 – poverty-interaction plot
#
# Inputs:  main_data.csv      – analytic dataset
#          raw_neighborhood_chars.csv   – raw neighborhood characteristics
#                                    (required for Table 2 only)
# Outputs: outputs/table1_group_shares.csv 
#          outputs/table2_amenity_vars.csv 
#          outputs/table3.csv
#          outputs/figure1.pdf
#
# Software: R >= 4.2
#
# Note on the spatial weights matrix:
#   Building the inverse-distance matrix is memory- and time-intensive.
#   The matrix is saved to disk after the first run so subsequent runs can
#   reload it directly.
################################################################################

# ── 0. User-configurable paths ─────────────────────────────────────────────────
DATA_PATH   <- "main_data.csv"        # path to analytic dataset
CHARS_PATH  <- "raw_neighborhood_chars.csv"   # raw neighborhood characteristics (Table 2)
OUTPUT_DIR  <- "outputs"                  # directory for saved results
MATRIX_FILE <- "inverse_dist_matrix.rds" # cached spatial weights

dir.create(OUTPUT_DIR, showWarnings = FALSE)

# ── 1. Libraries ───────────────────────────────────────────────────────────────
library(tidyverse)
library(conflicted)
library(knitr)
library(kableExtra)
library(lme4)
library(spaMM)
library(spdep)
library(sp)
library(spatialreg)
library(tigris)
library(future.apply)
library(geosphere)
library(interactions)
library(patchwork)
library(cowplot)

conflicts_prefer(dplyr::filter)

# ── 2. Load and prepare data ───────────────────────────────────────────────────
df_raw <- read_csv(DATA_PATH, show_col_types = FALSE)

# Scaling:
df <- df_raw %>%
  ungroup() %>%
  group_by(city) %>%
  mutate(
    across(ends_with("_isolation"), ~ c(scale(.))),
    across(contains("score"),       ~ c(scale(.))),
    across(starts_with("lag_"),     ~ c(scale(.))),
    # Standardise continuous predictors
    across(
      c("land_area_sqmiles", "pop_density", "pntv_nwnb", "ppov",
        "hinc", "pnhwht", "pop",
        "pntv_blk", "pfb_blk_percent", "pfb_nonblk", "cbsa_pntv_blk"),
      ~ c(scale(.))
    )
  ) %>%
  ungroup()

cat("Analytic sample size:", nrow(df), "census tracts\n")

# ── 3. Table 1: descriptive statistics of group shares by city ─────────────────
# Computed on the unscaled shares (df_raw filtered to analytic sample),
# before any standardisation.

city_summary <- df_raw %>%
  group_by(city) %>%
  summarise(
    N_tracts        = n(),
    mean_pntv_blk   = mean(pntv_blk,       na.rm = TRUE),
    sd_pntv_blk     = sd(pntv_blk,         na.rm = TRUE),
    mean_pfb_blk    = mean(pfb_blk_percent, na.rm = TRUE),
    sd_pfb_blk      = sd(pfb_blk_percent,   na.rm = TRUE),
    mean_pfb_nonblk = mean(pfb_nonblk,      na.rm = TRUE),
    sd_pfb_nonblk   = sd(pfb_nonblk,        na.rm = TRUE),
    .groups = "drop"
  )

overall_summary <- df_raw %>%
  summarise(
    city            = "Overall",
    N_tracts        = n(),
    mean_pntv_blk   = mean(pntv_blk,       na.rm = TRUE),
    sd_pntv_blk     = sd(pntv_blk,         na.rm = TRUE),
    mean_pfb_blk    = mean(pfb_blk_percent, na.rm = TRUE),
    sd_pfb_blk      = sd(pfb_blk_percent,   na.rm = TRUE),
    mean_pfb_nonblk = mean(pfb_nonblk,      na.rm = TRUE),
    sd_pfb_nonblk   = sd(pfb_nonblk,        na.rm = TRUE)
  )

table1_raw <- bind_rows(city_summary, overall_summary)
write_csv(table1_raw, file.path(OUTPUT_DIR, "table1_group_shares.csv"))

message("Table 1 saved to outputs/table1_group_shares.csv and .html")

# ── 4. Table 2: descriptive statistics of amenity variables ────────────────────
# Loaded from the raw characteristics file and restricted to analytic tracts.
# Variable transformations match index construction described in the paper:
#   ed_teachxp : originally % teachers in first 2 yrs , flipped to % beyond yr 2
#   he_green   : originally % impenetrable surface    , flipped to % permeable
#   se_jobprox : originally % commuting more than 1 hr, flipped to % < 1 hr

all_chars <- read_csv(CHARS_PATH, show_col_types = FALSE) %>%
  mutate(
    ed_teachxp = 100 - ed_teachxp,
    he_green   = 100 - he_green,
    se_jobprox = 100 - se_jobprox
  )

var_labels <- c(
  stores                = "Retail Stores (Count)",
  restaurants           = "Restaurants (Count)",
  bank_count            = "Banks (Count)",
  civsoc_orgs           = "Civic and Social Organizations (Count)",
  religious_orgs        = "Religious Organizations (Count)",
  doctors               = "Medical Professionals (Count)",
  grocery_stores        = "Grocery Stores (Count)",
  libraries             = "Libraries (Count)",
  he_green              = "Impenetrable Surface Areas (%)",
  he_walk               = "Walkability Index",
  stops_per_capita      = "Transit Stops (Per 1000 Residents)",
  ed_prxhqece           = "NAEYC Accredited Centers (Count)",
  ed_teachxp            = "Teacher Experience (%)",
  job_density_2013      = "Job Density (Jobs Per Square Mile)",
  se_jobprox            = "Job Proximity (%)",
  high_skill_jobs       = "High-Skill Jobs",
  jobs_highpay_5mi_2015 = "High Paying Jobs"
)

table2 <- all_chars %>%
  summarise(across(everything(), list(mean = mean, sd = sd), na.rm = TRUE)) %>%
  pivot_longer(
    cols          = everything(),
    names_to      = c("variable", ".value"),
    names_pattern = "(.+)_(mean|sd)"
  ) %>%
  mutate(
    label     = var_labels[variable],
    dimension = case_when(
      variable %in% c("stores", "restaurants", "bank_count", "civsoc_orgs",
                       "religious_orgs", "doctors", "grocery_stores",
                       "libraries", "he_green", "he_walk",
                       "stops_per_capita")              ~ "Daily Life Amenities",
      variable %in% c("ed_prxhqece", "ed_teachxp",
                       "job_density_2013", "se_jobprox",
                       "high_skill_jobs",
                       "jobs_highpay_5mi_2015")         ~ "Education/Employment"
    )
  ) %>%
  arrange(dimension, variable) %>%
  select(dimension, label, mean, sd)

write_csv(table2, file.path(OUTPUT_DIR, "table2_amenity_vars.csv"))


# ── 5. Download census-tract geometries and build spatial weights ───────────────
# 5a. Download tract shapefiles by state
states <- unique(df$fipsstatecode)

combined_data <- map_dfr(states, function(st) {
  tracts(state = st, year = 2010, progress_bar = FALSE)
})

# 5b. Merge with analytic data
polygon_data_sf <- combined_data %>%
  mutate(Geo_FIPS = GEOID10) %>%
  filter(Geo_FIPS %in% df$Geo_FIPS) %>%
  left_join(df, by = "Geo_FIPS", suffix = c("", ".remove_column")) %>%
  select(-ends_with(".remove_column"))

# 5c. Contiguity weights (used for spatial-lag variable in mediation)
nb    <- poly2nb(polygon_data_sf, queen = TRUE)
listw <- nb2listw(nb, style = "W", zero.policy = TRUE)

# 5d. Inverse-distance weights matrix (used in spaMM models)
#     Expensive to compute; cache to disk after first run.
if (file.exists(MATRIX_FILE)) {
  message("Loading cached inverse-distance matrix from ", MATRIX_FILE)
  inverse_dist_matrix <- readRDS(MATRIX_FILE)
} else {
  message("Computing inverse-distance matrix (this may take 10-30 minutes)...")
  
  polygon_data_sf$centroids <- st_centroid(polygon_data_sf$geometry)
  coords <- st_coordinates(polygon_data_sf$centroids)
  
  cutoff_distance <- 1000000  # 1,000 km cutoff (metres)
  
  plan(multisession)  # parallelise with future.apply
  inverse_dist_matrix <- future_apply(
    coords, 1,
    function(x) {
      dists        <- distm(x, coords)
      dists[dists == 0]              <- Inf
      dists[dists > cutoff_distance] <- Inf
      1 / dists
    },
    future.seed = TRUE
  )
  inverse_dist_matrix[is.infinite(inverse_dist_matrix)] <- 0
  plan(sequential)
  
  saveRDS(inverse_dist_matrix, MATRIX_FILE)
  message("Saved matrix to ", MATRIX_FILE)
}

# ── 6. Helper: extract results from a spaMM fitme object ──────────────────────
extract_fitme_results <- function(model, model_name) {
  smry    <- as.data.frame(summary(model)$beta_table)
  smry$variable <- row.names(smry)
  t_vals  <- smry$`t-value`
  n_obs   <- nobs(model)
  p_vals  <- 2 * pt(-abs(t_vals), df = n_obs - 1)
  
  data.frame(
    model      = model_name,
    variable   = smry$variable,
    estimate   = smry$Estimate,
    std_error  = smry$`Cond. SE`,
    t_value    = t_vals,
    p_value    = p_vals,
    sig        = case_when(
      p_vals < 0.001 ~ "***",
      p_vals < 0.01  ~ "**",
      p_vals < 0.05  ~ "*",
      TRUE           ~ ""
    )
  )
}

# ── 7. Main models (Table 3) ───────────────────────────────────────────────────


# Model 1: Overall amenities score
message("Fitting Model 1: Overall score...")
m_overall <- fitme(
  overall_score ~ pntv_blk + pfb_blk_percent + pfb_nonblk + pntv_nwnb +
    land_area_sqmiles + pop +
    (0 + pntv_blk + pfb_blk_percent + pfb_nonblk + pntv_nwnb +
       land_area_sqmiles + pop | city) - 1,
  data        = polygon_data_sf,
  family      = gaussian(),
  method      = "REML",
  distMatrix  = inverse_dist_matrix
)

# Model 2: Education & employment score (referred to as hc_score internally)
message("Fitting Model 2: Education & employment score...")
m_hc <- fitme(
  hc_score ~ pntv_blk + pfb_blk_percent + pfb_nonblk + pntv_nwnb +
    land_area_sqmiles + pop +
    (0 + pntv_blk + pfb_blk_percent + pfb_nonblk + pntv_nwnb +
       land_area_sqmiles + pop | city) - 1,
  data        = polygon_data_sf,
  family      = gaussian(),
  method      = "REML",
  distMatrix  = inverse_dist_matrix
)

# Model 3: Daily-life amenities score
message("Fitting Model 3: Daily-life score...")
m_dl <- fitme(
  dl_score ~ pntv_blk + pfb_blk_percent + pfb_nonblk + pntv_nwnb +
    land_area_sqmiles + pop +
    (0 + pntv_blk + pfb_blk_percent + pfb_nonblk + pntv_nwnb +
       land_area_sqmiles + pop | city) - 1,
  data        = polygon_data_sf,
  family      = gaussian(),
  method      = "REML",
  distMatrix  = inverse_dist_matrix
)

# Combine into Table 3
table3 <- bind_rows(
  extract_fitme_results(m_overall, "Model 1: Overall"),
  extract_fitme_results(m_hc,      "Model 2: Education & Employment"),
  extract_fitme_results(m_dl,      "Model 3: Daily Life")
)

write_csv(table3, file.path(OUTPUT_DIR, "table3.csv"))
message("Table 3 saved to ", file.path(OUTPUT_DIR, "table3.csv"))

# ── 8. Poverty-interaction model and Figure 1 ──────────────────────────────────
# NOTE: Only the non-Black immigrant interaction is statistically significant
# and shown in the paper (Figure 1 shows only the pfb_nonblk × ppov panel).
message("Fitting poverty-interaction model...")
m_overall_pov <- fitme(
  overall_score ~
    pntv_blk * ppov + pfb_blk_percent * ppov + pfb_nonblk * ppov +
    pntv_nwnb * ppov + land_area_sqmiles + pop +
    (0 + pntv_blk * ppov + pfb_blk_percent * ppov +
       pfb_nonblk * ppov + pntv_nwnb * ppov | city) - 1,
  data        = polygon_data_sf,
  family      = gaussian(),
  method      = "REML",
  distMatrix  = inverse_dist_matrix
)

# Figure 1: Predicted overall score by non-Black immigrant share × poverty
ov_plot_fb_nonblk <- interactions::interact_plot(
  m_overall_pov,
  pred        = "pfb_nonblk",
  modx        = "ppov",
  legend.main = "Poverty Rate",
  colors      = "Greys"
) +
  labs(
    x       = "Share Non-Black Immigrant (Z-Score)",
    y       = "Predicted Overall Score",
    caption = "FIGURE 1. POVERTY INTERACTION RESULTS"
  ) +
  theme(
    axis.text.y  = element_text(size = 15),
    axis.text.x  = element_text(size = 15),
    axis.title.y = element_text(size = 15),
    axis.title.x = element_text(size = 15),
    legend.title = element_text(size = 13),
    legend.text  = element_text(size = 10),
    plot.caption = element_text(hjust = 0, size = 16, face = "bold")
  )

fig1_path <- file.path(OUTPUT_DIR, "figure1.pdf")
ggsave(fig1_path, plot = ov_plot_fb_nonblk, width = 10, height = 9)
message("Figure 1 saved to ", fig1_path)