# Codebook

**"Intersecting Inequalities: Blackness, Immigrant Status, and the Prevalence of Neighborhood Amenities"**

All data are measured at the **census-tract level** for the year **2015**. 
The analytic sample covers 6,532 census tracts in the principal cities of the 15 largest metropolitan statistical areas for Black immigrants.

---

## File 1: `main_data.csv`

### Identifiers

| Variable | Type | Description |
|---|---|---|
| `Geo_FIPS` | string (11-char) | Census tract FIPS code (zero-padded). |
| `city` | string | Principal city name |
| `fipsstatecode` | string (2-char) | State FIPS code (zero-padded) |
| `cbsa10` | integer | Core-based statistical area (CBSA) code, 2010 definitions |
| `cbsaname10` | string | CBSA name |
| `year` | integer | Reference year (2015 throughout) |

### Outcome indices

All three indices are **z-scored within city** in the analysis scripts. Raw scores are stored here.

| Variable | Description |
|---|---|
| `overall_score` | Overall neighborhood amenities index — average of all z-scored amenity variables |
| `hc_score` | Education and employment amenities sub-index |
| `dl_score` | Daily-life amenities sub-index |
| `lag_overall` | Spatially lagged overall score (inverse-distance weighted mean of neighboring tracts) |
| `lag_hc` | Spatially lagged education and employment score |
| `lag_dl` | Spatially lagged daily-life score |

### Main predictors — group shares

Tract-level proportions derived from the 2013–2017 ACS 5-year estimates.

| Variable | Description |
|---|---|
| `pntv_blk` | Share of tract population that is native-born Black |
| `pfb_blk_percent` | Share of tract population that is foreign-born Black |
| `pfb_nonblk` | Share of tract population that is non-Black immigrant (foreign-born, non-Black) |
| `pntv_nwnb` | Share of tract population that is native-born, non-White, non-Black (i.e., native-born Hispanic, Asian) |

### Group counts

Raw counts used to compute population-weighted P* exposure indices in `02_group_exposure.R`.

| Variable | Description |
|---|---|
| `ntv_blk` | Count of native-born Black residents |
| `fb_blk` | Count of foreign-born Black residents |
| `fb_nonblk` | Count of non-Black immigrant residents |

### Demographic counts

| Variable | Description |
|---|---|
| `pop` | Total tract population |
| `nhwht` | Count of non-Hispanic White residents |
| `nhblk` | Count of non-Hispanic Black residents |
| `hisp` | Count of Hispanic residents (any race) |
| `asian` | Count of Asian residents |

### Tract-level controls

| Variable | Description |
|---|---|
| `ppov` | Tract poverty rate (%) |
| `hinc` | Median household income ($) |
| `pnhwht` | Share non-Hispanic White |
| `land_area_sqmiles` | Tract land area in square miles |
| `pop_density` | Population per square mile |

### CBSA-level predictor

| Variable | Description |
|---|---|
| `cbsa_pntv_blk` | Share of CBSA population that is native-born Black (used in supplemental city-level moderator models) |

### Isolation indices

Exposure/isolation indices. Used in supplemental and robustness analyses.

| Variable | Description |
|---|---|
| `bw_isolation` | Native-born Black isolation from native-born White residents |
| `fbw_isolation` | Foreign-born Black isolation from native-born White residents |
| `nbbw_isolation` | Non-Black (all) isolation from native-born White residents |
| `fbbw_isolation` | Foreign-born Black isolation from Black (all) residents |
| `nbfbw_isolation` | Non-Black foreign-born isolation from native-born White residents |

---

## File 2: `raw_neighborhood_chars.csv`

Restricted to tracts in the analytic sample. All variables are measured in 2015.

**Note on variable direction:** Three variables are stored here in their *original* direction (before the sign flip applied in the analysis scripts):
- `he_green` — originally % impenetrable surface; scripts compute `100 - he_green` to get % permeable/green
- `ed_teachxp` — originally % teachers in their first two years; scripts compute `100 - ed_teachxp` to get % beyond year 2
- `se_jobprox` — originally % commuting more than 1 hour; scripts compute `100 - se_jobprox` to get % commuting < 1 hour

### Identifier

| Variable | Type | Description |
|---|---|---|
| `tract_fips10` | string (11-char) | Census tract FIPS code. Joins to `Geo_FIPS` in `analytic_df10_clean.csv`. |
| `msaid15` | integer | MSA identifier, 2015 definitions |

### Daily-life amenities

| Variable | Description | Source |
|---|---|---|
| `stores` | Count of retail stores (excludes grocery, liquor, and dollar stores) | NaNDA |
| `restaurants` | Count of restaurants (excludes fast food) | NaNDA |
| `bank_count` | Count of banks | NaNDA |
| `civsoc_orgs` | Count of civic and social organizations | NaNDA |
| `religious_orgs` | Count of religious organizations | NaNDA |
| `doctors` | Count of medical professionals (doctors, dentists, mental health) | NaNDA |
| `grocery_stores` | Count of grocery stores | NaNDA |
| `libraries` | Count of public libraries | NaNDA |
| `he_green` | Impenetrable surface area (%) — see direction note above | NaNDA |
| `he_walk` | EPA Walkability Index (higher = more walkable) | NaNDA |
| `stops_per_capita` | Public transit stops per 1,000 residents | NaNDA |

### Education and employment amenities

| Variable | Description | Source |
|---|---|---|
| `ed_prxhqece` | Count of NAEYC-accredited early childhood education centers | Child Opportunity Index |
| `ed_teachxp` | % of teachers in their first two years — see direction note above | Child Opportunity Index |
| `job_density_2013` | Jobs per square mile | Opportunity Insights |
| `se_jobprox` | % of workers commuting moer than 1 hour one way — see direction note above | Opportunity Insights |
| `high_skill_jobs` | Count of jobs in high-skill industries (information, finance, professional services, health care, education, real estate, corporate management) | Opportunity Insights |
| `jobs_highpay_5mi_2015` | Count of jobs with earnings > $3,333/month in own and neighboring tracts | Opportunity Insights |

---
