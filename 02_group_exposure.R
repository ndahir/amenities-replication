################################################################################
# Replication Code for:
#   "Intersecting Inequalities: Blackness, Immigrant Status, and the
#    Prevalence of Neighborhood Amenities"
#
# Script:  02_group_exposure.R
# Purpose: Compute population-weighted P* exposure indices for each group
#          (Table 4) and produce Figure 2.
#
# Input:   main_data.csv  (place in the same directory, or set DATA_PATH)
# Outputs: outputs/table4_scheffe.csv
#          outputs/figure2.pdf
################################################################################

# ── 0. User-configurable paths ─────────────────────────────────────────────────
DATA_PATH  <- "main_data.csv"
OUTPUT_DIR <- "outputs"

dir.create(OUTPUT_DIR, showWarnings = FALSE)

# ── 1. Libraries ───────────────────────────────────────────────────────────────
library(tidyverse)
library(DescTools)   # ScheffeTest()
library(emmeans)     # emmeans() for adjusted group means

# ── 2. Load and prepare data ───────────────────────────────────────────────────
# NOTE: Amenity scores are standardized within city (as in the main analysis).
#       Group-count variables (ntv_blk, fb_blk, fb_nonblk) must remain on their
#       original count scale for the P* exposure formula.

df_raw <- read_csv(DATA_PATH, show_col_types = FALSE)

df <- df_raw %>%
  ungroup() %>%
  group_by(city) %>%
  mutate(
    across(ends_with("_isolation"), ~ c(scale(.))),
    across(contains("score"),       ~ c(scale(.))),
    across(starts_with("lag_"),     ~ c(scale(.)))
  ) %>%
  ungroup()

cat("Analytic sample size:", nrow(df), "census tracts\n")

# ── 3. P* exposure function ────────────────────────────────────────────────────
# Computes the population-weighted mean amenity score experienced by a group
# within a single city:
#   P*_{g,A,c} = sum_i (n_{igc} / N_{gc}) * A_{ic}
#
# Arguments:
#   df_city        data.frame filtered to one city
#   group_count_var column name (string) holding group counts
#   amenity_var    column name (string) of the (z-scored) amenity index
compute_city_exposure <- function(df_city, group_count_var, amenity_var) {
  total_group <- sum(df_city[[group_count_var]], na.rm = TRUE)
  if (is.na(total_group) || total_group == 0) return(NA_real_)
  
  sum(
    (df_city[[group_count_var]] / total_group) * df_city[[amenity_var]],
    na.rm = TRUE
  )
}

# ── 4. Compute city-level P* for each group × amenity combination ──────────────
amenity_vars <- c("overall_score", "hc_score", "dl_score")

# Map group labels to the raw count columns in the dataset
group_map <- tibble(
  group_label = c("Native Black", "Black Immigrant", "Non-Black Immigrant"),
  count_var   = c("ntv_blk",      "fb_blk",          "fb_nonblk")
)

cities <- sort(unique(df$city))

city_exposure <- map_dfr(cities, function(cty) {
  df_city <- filter(df, city == cty)
  
  map_dfr(amenity_vars, function(av) {
    map_dfr(seq_len(nrow(group_map)), function(i) {
      tibble(
        city        = cty,
        group       = group_map$group_label[i],
        amenity_dim = av,
        Pstar       = compute_city_exposure(df_city, group_map$count_var[i], av),
        group_pop   = sum(df_city[[group_map$count_var[i]]], na.rm = TRUE)
      )
    })
  })
})

# ── 5. Population-weighted aggregate P* across cities ─────────────────────────
overall_exposure <- city_exposure %>%
  group_by(group, amenity_dim) %>%
  summarise(
    total_group_pop = sum(group_pop,              na.rm = TRUE),
    Pstar_weighted  = sum(Pstar * group_pop,      na.rm = TRUE) / total_group_pop,
    .groups = "drop"
  )

print(overall_exposure)

# ── 6. Long format for ANOVA / Scheffe tests ──────────────────────────────────
# One row per tract × group; group counts serve as weights.

exposure_long <- df %>%
  select(city, overall_score, hc_score, dl_score,
         ntv_blk, fb_blk, fb_nonblk) %>%
  pivot_longer(
    cols      = c(ntv_blk, fb_blk, fb_nonblk),
    names_to  = "group",
    values_to = "count"
  ) %>%
  filter(!is.na(count), count > 0) %>%
  mutate(
    group = recode(
      group,
      ntv_blk   = "Native Black",
      fb_blk    = "Black Immigrant",
      fb_nonblk = "Non-Black Immigrant"
    ),
    group = factor(
      group,
      levels = c("Native Black", "Black Immigrant", "Non-Black Immigrant")
    )
  )

# ── 7. One-way ANOVA with Scheffe post-hoc tests (Table 4) ────────────────────
run_scheffe <- function(outcome_var, label) {
  formula_str <- paste0(outcome_var, " ~ group + city")
  aov_fit     <- aov(as.formula(formula_str),
                     data    = exposure_long,
                     weights = count)
  scheffe_res <- ScheffeTest(aov_fit, which = "group")
  
  # Convert to a tidy data frame
  res_df <- as.data.frame(scheffe_res$group) %>%
    rownames_to_column("comparison") %>%
    mutate(amenity = label)
  
  list(aov = aov_fit, scheffe = scheffe_res, tidy = res_df)
}

res_overall <- run_scheffe("overall_score", "Overall")
res_hc      <- run_scheffe("hc_score",      "Education & Employment")
res_dl      <- run_scheffe("dl_score",      "Daily Life")

# Combine Scheffé results into Table 4
table4 <- bind_rows(
  res_overall$tidy,
  res_hc$tidy,
  res_dl$tidy
) %>%
  rename(
    difference = diff,
    lower_ci   = lwr.ci,
    upper_ci   = upr.ci,
    p_value    = pval
  ) %>%
  mutate(
    sig = case_when(
      p_value < 0.001 ~ "***",
      p_value < 0.01  ~ "**",
      p_value < 0.05  ~ "*",
      TRUE            ~ ""
    )
  ) %>%
  select(amenity, comparison, difference, lower_ci, upper_ci, p_value, sig)

write_csv(table4, file.path(OUTPUT_DIR, "table4_scheffe.csv"))
message("Table 4 saved to ", file.path(OUTPUT_DIR, "table4_scheffe.csv"))

# ── 8. Estimated marginal means for Figure 2 ──────────────────────────────────
get_emm <- function(aov_fit, label) {
  emmeans(aov_fit, ~ group) %>%
    as.data.frame() %>%
    rename(mean_exposure = emmean, lower_ci = lower.CL, upper_ci = upper.CL) %>%
    mutate(amenity_dim = label)
}

emm_all <- bind_rows(
  get_emm(res_overall$aov, "Overall"),
  get_emm(res_hc$aov,      "Education & Employment"),
  get_emm(res_dl$aov,      "Daily Life")
) %>%
  mutate(
    amenity_dim = factor(
      amenity_dim,
      levels = c("Overall", "Education & Employment", "Daily Life")
    ),
    group = factor(
      group,
      levels = c("Native Black", "Black Immigrant", "Non-Black Immigrant")
    )
  )

# ── 9. Figure 2 ────────────────────────────────────────────────────────────────
group_colors <- c(
  "Native Black"        = "#2a9d8f",   # teal
  "Black Immigrant"     = "#e76f51",   # orange
  "Non-Black Immigrant" = "#6c7fc4"    # blue-violet
)

p_exposure <- ggplot(
  emm_all,
  aes(x = group, y = mean_exposure, fill = group)
) +
  geom_col(width = 0.6) +
  geom_errorbar(aes(ymin = lower_ci, ymax = upper_ci), width = 0.2) +
  geom_hline(yintercept = 0, linetype = "dashed") +
  facet_wrap(~ amenity_dim, nrow = 1) +
  scale_fill_manual(values = group_colors, guide = "none") +
  labs(
    x       = "",
    y       = "Mean exposure (SD units)",
    caption = paste0(
      "FIGURE 2. EXPOSURE TO NEIGHBORHOOD AMENITIES BY GROUP\n",
      "Population-weighted, within-city exposure"
    )
  ) +
  theme_minimal(base_size = 13) +
  theme(
    strip.text   = element_text(face = "bold"),
    axis.text.x  = element_text(angle = 15, hjust = 1),
    plot.caption = element_text(hjust = 0, size = 14, face = "bold")
  )

fig2_path <- file.path(OUTPUT_DIR, "figure2.pdf")
ggsave(fig2_path, plot = p_exposure, width = 10, height = 9)
message("Figure 2 saved to ", fig2_path)
