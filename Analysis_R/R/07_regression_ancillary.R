suppressPackageStartupMessages({
  library(dplyr)
  library(lme4)
  library(car)
  library(MuMIn)
  library(readxl)
})

# ============================================================
# Mixed-model regression: delta_CVCi ~ pain + delta_ET-CO2 + visit
# (mirrors Python regression_table in build_minute_level_outputs.py)
# Outputs: coefficients, standardised betas, Marginal R2, Conditional R2,
#          ICC for the model, VIF for fixed effects.
# ============================================================

build_regression_table <- function(df) {
  rows <- list()
  j <- 1L
  global_excl <- c(45L)
  visit_excl <- list(c(13L, 1L))  # K32V1 ET-CO2 artifact

  for (i in seq_len(nrow(df))) {
    row <- df[i, , drop = FALSE]
    pid <- as.integer(row[["1 Identifier"]])
    if (pid %in% global_excl) next

    for (visit in c(1L, 2L)) {
      skip <- any(vapply(visit_excl, function(ve) pid == ve[1] && visit == ve[2], logical(1)))
      if (skip) next

      delta_cvci  <- suppressWarnings(as.numeric(row[[paste(visit, "Delta MCAv CVCi CPT 2min")]]))
      pain        <- suppressWarnings(as.numeric(row[[paste(visit, "rating of discomfort")]]))
      delta_etco2 <- suppressWarnings(as.numeric(row[[paste(visit, "Delta ET-CO2 CPT 2min")]]))

      rows[[j]] <- data.frame(
        pid         = pid,
        visit       = visit,
        delta_cvci  = delta_cvci,
        pain        = pain,
        delta_etco2 = delta_etco2,
        stringsAsFactors = FALSE
      )
      j <- j + 1L
    }
  }

  lmm <- dplyr::bind_rows(rows)
  cc  <- lmm[complete.cases(lmm), ]

  fit <- lme4::lmer(delta_cvci ~ pain + delta_etco2 + visit + (1 | pid),
                    data = cc, REML = TRUE,
                    control = lme4::lmerControl(optimizer = "bobyqa"))

  r2_vals <- MuMIn::r.squaredGLMM(fit)
  marginal_r2    <- as.numeric(r2_vals[1, "R2m"])
  conditional_r2 <- as.numeric(r2_vals[1, "R2c"])

  var_fe  <- stats::var(lme4::fixef(fit)["(Intercept)"] +
                          cc$pain * lme4::fixef(fit)["pain"] +
                          cc$delta_etco2 * lme4::fixef(fit)["delta_etco2"] +
                          cc$visit * lme4::fixef(fit)["visit"])
  var_re  <- as.numeric(lme4::VarCorr(fit)$pid)
  var_res <- attr(lme4::VarCorr(fit), "sc")^2
  icc_model <- var_re / (var_re + var_res)

  cf   <- lme4::fixef(fit)
  se   <- sqrt(diag(as.matrix(lme4::vcov.merMod(fit))))
  tval <- cf / se
  df_resid <- nrow(cc) - length(cf) - 1L
  pval <- 2 * stats::pt(abs(tval), df = df_resid, lower.tail = FALSE)

  sd_y <- stats::sd(cc$delta_cvci)
  std_betas <- c(
    "(Intercept)"  = NA_real_,
    pain           = as.numeric(cf["pain"])        * stats::sd(cc$pain)        / sd_y,
    delta_etco2    = as.numeric(cf["delta_etco2"]) * stats::sd(cc$delta_etco2) / sd_y,
    visit          = NA_real_
  )

  predictor_labels <- c(
    "(Intercept)"  = "Intercept",
    pain           = "Perceived Pain (VAS)",
    delta_etco2    = "Delta ET-CO2 (mmHg)",
    visit          = "Visit Number"
  )

  coef_df <- data.frame(
    Predictor        = predictor_labels[names(cf)],
    b                = as.numeric(cf),
    beta             = std_betas[names(cf)],
    SE               = as.numeric(se),
    t                = as.numeric(tval),
    P                = as.numeric(pval),
    Marginal_R2      = c(marginal_r2, rep(NA_real_, length(cf) - 1)),
    Conditional_R2   = c(conditional_r2, rep(NA_real_, length(cf) - 1)),
    ICC_model        = c(icc_model, rep(NA_real_, length(cf) - 1)),
    n_participants   = c(length(unique(cc$pid)), rep(NA_integer_, length(cf) - 1)),
    n_observations   = c(nrow(cc), rep(NA_integer_, length(cf) - 1)),
    stringsAsFactors = FALSE,
    check.names      = FALSE
  )

  # VIF for fixed effects (uses auxiliary lm on complete data)
  vif_vals <- tryCatch({
    aux <- stats::lm(delta_cvci ~ pain + delta_etco2 + visit, data = cc)
    car::vif(aux)
  }, error = function(e) rep(NA_real_, 3))

  vif_df <- data.frame(
    Predictor    = c("Perceived Pain (VAS)", "Delta ET-CO2 (mmHg)", "Visit Number"),
    VIF          = as.numeric(vif_vals),
    stringsAsFactors = FALSE
  )

  list(
    coef_df  = coef_df,
    vif_df   = vif_df,
    fit      = fit,
    data     = cc
  )
}


# ============================================================
# PPT reliability: V1 vs V2 Baseline Algometer (ICC, CCC, paired test)
# Water-temperature reliability: V1 vs V2 water temperature
# ============================================================

build_ppt_water_reliability <- function(df) {
  global_excl <- c(45L)

  ppt_rows <- list(); wt_rows <- list(); pain_rows <- list()
  jp <- 1L; jw <- 1L; jpain <- 1L

  for (i in seq_len(nrow(df))) {
    row <- df[i, , drop = FALSE]
    pid <- as.integer(row[["1 Identifier"]])
    if (pid %in% global_excl) next

    v1_ppt <- suppressWarnings(as.numeric(row[["1 Baseline Algometer"]]))
    v2_ppt <- suppressWarnings(as.numeric(row[["2 Baseline Algometer"]]))
    if (!is.na(v1_ppt) && !is.na(v2_ppt)) {
      ppt_rows[[jp]] <- data.frame(pid = pid, v1 = v1_ppt, v2 = v2_ppt)
      jp <- jp + 1L
    }

    v1_wt <- suppressWarnings(as.numeric(row[["1 water temperature"]]))
    v2_wt <- suppressWarnings(as.numeric(row[["2 water temperature"]]))
    if (!is.na(v1_wt) && !is.na(v2_wt)) {
      wt_rows[[jw]] <- data.frame(pid = pid, v1 = v1_wt, v2 = v2_wt)
      jw <- jw + 1L
    }

    v1_pain <- suppressWarnings(as.numeric(row[["1 rating of discomfort"]]))
    v2_pain <- suppressWarnings(as.numeric(row[["2 rating of discomfort"]]))
    if (!is.na(v1_pain) && !is.na(v2_pain)) {
      pain_rows[[jpain]] <- data.frame(pid = pid, v1 = v1_pain, v2 = v2_pain)
      jpain <- jpain + 1L
    }
  }

  ppt_dp  <- dplyr::bind_rows(ppt_rows)
  wt_dp   <- dplyr::bind_rows(wt_rows)
  pain_dp <- dplyr::bind_rows(pain_rows)

  make_row <- function(dp, label, units) {
    b    <- ba_stats(dp)
    icc  <- icc_ccc(dp)
    comp <- paired_comparison(dp)
    v1s  <- summary_string(dp$v1)
    v2s  <- summary_string(dp$v2)
    diffs <- summary_string(dp$v1 - dp$v2)
    if (any(c(v1s$kind, v2s$kind, diffs$kind) == "median_iqr")) {
      iqr_fmt <- function(x) {
        x <- as.numeric(x[!is.na(x)])
        if (length(x) < 3) return(list(value = "", kind = "median_iqr"))
        list(value = paste0(fmt_sig3(stats::median(x)), " [",
                            fmt_sig3(quantile_np(x, 0.75) - quantile_np(x, 0.25)), "]"),
             kind = "median_iqr")
      }
      v1s   <- iqr_fmt(dp$v1)
      v2s   <- iqr_fmt(dp$v2)
      diffs <- iqr_fmt(dp$v1 - dp$v2)
    }
    mae  <- mean(abs(dp$v1 - dp$v2))
    denom <- abs((dp$v1 + dp$v2) / 2); denom[denom == 0] <- NA_real_
    mape <- mean(abs(dp$v1 - dp$v2) / denom, na.rm = TRUE) * 100

    data.frame(
      Variable         = label,
      Units            = units,
      n                = nrow(dp),
      Visit_1          = v1s$value,
      Visit_1_summary  = v1s$kind,
      Visit_2          = v2s$value,
      Visit_2_summary  = v2s$kind,
      Fixed_Bias       = diffs$value,
      Fixed_Bias_summary = diffs$kind,
      Comparison_Test  = comp$Test %||% "",
      Comparison_P     = comp$P %||% NA_real_,
      Effect           = comp$Effect %||% NA_real_,
      Effect_type      = comp$Effect_type %||% "",
      MAE              = mae,
      `MAPE_%`         = mape,
      Mean_diff        = b$Mean_diff,
      SD_diff          = b$SD_diff,
      ICC3k            = icc$ICC3k,
      ICC3k_lo         = icc$ICC3k_lo,
      ICC3k_hi         = icc$ICC3k_hi,
      ICC3k_p          = icc$ICC3k_p,
      CCC              = icc$CCC,
      CCC_p            = icc$CCC_p,
      stringsAsFactors = FALSE,
      check.names      = FALSE
    )
  }

  list(
    ppt        = make_row(ppt_dp,  "Pressure pain tolerance (algometer)", "kg/cm²"),
    water_temp = make_row(wt_dp,   "Water temperature",                   "°C"),
    pain       = make_row(pain_dp, "Perceived pain (VAS)",                "0–100")
  )
}


# ============================================================
# CPT hand sensitivity: does CPT side (L vs R) change the model?
# Loads CPT Data.xlsx (sheet "CPT side"), merges by pid+visit,
# fits base vs. +hand model on the same subset, returns LRT + coef row.
# ============================================================

build_cpt_hand_sensitivity <- function(df, cpt_side_xlsx) {
  if (!file.exists(cpt_side_xlsx)) {
    warning("CPT side workbook not found: ", cpt_side_xlsx)
    return(NULL)
  }

  raw <- readxl::read_excel(cpt_side_xlsx, sheet = "CPT side", col_names = FALSE)
  side_df <- raw[-1, c(8, 9, 10)]
  colnames(side_df) <- c("pid", "visit", "cpt_side")
  side_df <- side_df %>%
    dplyr::mutate(
      pid      = suppressWarnings(as.integer(pid)),
      visit    = suppressWarnings(as.integer(visit)),
      cpt_side = as.character(cpt_side)
    ) %>%
    dplyr::filter(!is.na(pid), !is.na(visit), cpt_side %in% c("Left", "Right"))

  global_excl <- c(45L)
  visit_excl  <- list(c(13L, 1L))

  rows <- list(); j <- 1L
  for (i in seq_len(nrow(df))) {
    row <- df[i, , drop = FALSE]
    pid <- as.integer(row[["1 Identifier"]])
    if (pid %in% global_excl) next
    for (visit in c(1L, 2L)) {
      skip <- any(vapply(visit_excl, function(ve) pid == ve[1] && visit == ve[2], logical(1)))
      if (skip) next
      rows[[j]] <- data.frame(
        pid         = pid,
        visit       = visit,
        delta_cvci  = suppressWarnings(as.numeric(row[[paste(visit, "Delta MCAv CVCi CPT 2min")]])),
        pain        = suppressWarnings(as.numeric(row[[paste(visit, "rating of discomfort")]])),
        delta_etco2 = suppressWarnings(as.numeric(row[[paste(visit, "Delta ET-CO2 CPT 2min")]])),
        stringsAsFactors = FALSE
      )
      j <- j + 1L
    }
  }

  lmm <- dplyr::bind_rows(rows) %>%
    dplyr::left_join(side_df, by = c("pid", "visit")) %>%
    dplyr::mutate(cpt_right = as.integer(cpt_side == "Right"))

  cc <- lmm[complete.cases(lmm[, c("delta_cvci", "pain", "delta_etco2", "visit", "cpt_right")]), ]

  ctrl <- lme4::lmerControl(optimizer = "bobyqa")
  fit_base <- lme4::lmer(delta_cvci ~ pain + delta_etco2 + visit + (1 | pid),
                         data = cc, REML = FALSE, control = ctrl)
  fit_hand <- lme4::lmer(delta_cvci ~ pain + delta_etco2 + visit + cpt_right + (1 | pid),
                         data = cc, REML = FALSE, control = ctrl)

  lrt     <- anova(fit_base, fit_hand)
  chi_sq  <- as.numeric(lrt[["Chisq"]][2])
  lrt_df  <- as.integer(lrt[["Df"]][2])
  lrt_p   <- as.numeric(lrt[["Pr(>Chisq)"]][2])

  cf   <- lme4::fixef(fit_hand)
  se   <- sqrt(diag(as.matrix(lme4::vcov.merMod(fit_hand))))
  tval <- cf / se
  df_r <- nrow(cc) - length(cf) - 1L
  pval <- 2 * stats::pt(abs(tval), df = df_r, lower.tail = FALSE)

  r2_base <- MuMIn::r.squaredGLMM(fit_base)
  r2_hand <- MuMIn::r.squaredGLMM(fit_hand)

  data.frame(
    n_obs            = nrow(cc),
    n_participants   = length(unique(cc$pid)),
    cpt_right_b      = as.numeric(cf["cpt_right"]),
    cpt_right_SE     = as.numeric(se["cpt_right"]),
    cpt_right_t      = as.numeric(tval["cpt_right"]),
    cpt_right_P      = as.numeric(pval["cpt_right"]),
    LRT_Chisq        = chi_sq,
    LRT_df           = lrt_df,
    LRT_P            = lrt_p,
    Base_Marginal_R2    = as.numeric(r2_base[1, "R2m"]),
    Base_Conditional_R2 = as.numeric(r2_base[1, "R2c"]),
    Hand_Marginal_R2    = as.numeric(r2_hand[1, "R2m"]),
    Hand_Conditional_R2 = as.numeric(r2_hand[1, "R2c"]),
    stringsAsFactors = FALSE,
    check.names      = FALSE
  )
}
