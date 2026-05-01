# Replication Package

**"Intersecting Inequalities: Blackness, Immigrant Status, and the Prevalence of Neighborhood Amenities"**

---

## Contents

| File | Description |
|---|---|
| `01_main_analysis.R` | All main-text tables and figures: Table 1, Table 2, Table 3, and Figure 1 |
| `02_group_exposure.R` | P* exposure indices, Scheffé tests: Table 4, Figure 2 |
| `main_data.csv` | Analytic dataset |
| `raw_neighborhood_chars.csv` | Raw neighborhood characteristics — required by `01_main_analysis.R` for Table 2 only |

Outputs are written to an `outputs/` subdirectory that is created automatically.

---

## Data

The analytic dataset (`main_data.csv`) combines:

- **2013–2017 American Community Survey (ACS)** – racial composition and tract characteristics
- **National Neighborhood Data Archive (NaNDA)** – daily-life amenity counts (grocery stores, retail, restaurants, banks, civic/religious organisations, medical professionals, libraries, walkability, transit stops)
- **Child Opportunity Index** – early-childhood education quality, teacher experience
- **Opportunity Insights** – job density, job proximity, high-skill and high-paying jobs

The sample covers 6,532 census tracts in the principal cities of the 15 largest metropolitan statistical areas for Black immigrants in 2015.

## How to run

1. Place `main_data.csv` and `raw_neighborhood_chars.csv` in the same directory as the two R scripts (or update `DATA_PATH` / `CHARS_PATH` at the top of each script).
2. Install required packages (see below).
3. Run `01_main_analysis.R` to produce Tables 1–3, Figure 1, and the no-controls robustness table.
4. Run `02_group_exposure.R` to produce Table 4 and Figure 2.

The two scripts are independent and can be run in either order.

### Package installation

```r
install.packages(c(
  "tidyverse", "conflicted", "lme4", "spaMM", "spdep",
  "sp", "spatialreg", "tigris", "future.apply", "geosphere",
  "interactions", "patchwork", "cowplot",
  "DescTools", "emmeans"
))
```

Tested with R 4.3.x.

### Computational note

Building the inverse-distance spatial weights matrix (in `01_main_analysis.R`) requires constructing a dense ~6,500 × 6,500 matrix and is memory- and time-intensive. The matrix is automatically cached to `inverse_dist_matrix.rds` after the first run; subsequent runs load it directly.

---

## Output files

| File | Corresponds to | Produced by |
|---|---|---|
| `outputs/table1_group_shares.csv` | Table 1 (group share descriptives by city) | `01_main_analysis.R` |
| `outputs/table1_group_shares.html` | Table 1 (formatted for manuscript) | `01_main_analysis.R` |
| `outputs/table2_amenity_vars.csv` | Table 2 (amenity variable descriptives) | `01_main_analysis.R` |
| `outputs/table2_amenity_vars.html` | Table 2 (formatted for manuscript) | `01_main_analysis.R` |
| `outputs/table3.csv` | Table 3 (main model coefficients) | `01_main_analysis.R` |
| `outputs/figure1.pdf` | Figure 1 (poverty × non-Black immigrant share interaction) | `01_main_analysis.R` |
| `outputs/table4_scheffe.csv` | Table 4 (Scheffé post-hoc comparisons of group exposure) | `02_group_exposure.R` |
| `outputs/figure2.pdf` | Figure 2 (group exposure to neighborhood amenities) | `02_group_exposure.R` |

---

## Citation

If you use this replication package, please cite the original article:

> Dahir, Nima. "Intersecting Inequalities: Blackness, Immigrant Status, and the Prevalence of Neighborhood Amenities." *Social Problems*.
