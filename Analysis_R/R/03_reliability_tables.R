suppressPackageStartupMessages({
  library(dplyr)
  library(tibble)
})

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

global_excl_ids <- c(45L)

var_excl <- list(
  etco2 = c("F02V1", "M24V1", "K32V1/F10V1", "K05V1"),
  mcav_peak = c("K10V1", "F02V1", "M24V1"),
  mcav_min = c("K10V1", "F02V1", "M24V1"),
  mcav_mean = c("K10V1", "F02V1", "M24V1"),
  mcav_pulse = c("K10V1", "F02V1", "M24V1"),
  mcav_gpi = c("K10V1", "F02V1", "M24V1"),
  cvci = c("K10V1", "F02V1", "M24V1"),
  cvri = c("M26V1", "F17V1", "F15V1", "M02V1", "F27V1/M16", "K05V1", "F26V2", "M21V1"),
  smo2 = c("K05V1"),
  q = character(),
  tpr = c("F05V1"),
  sbp = character(),
  dbp = character(),
  mbp = character(),
  hr = character()
)

epochs <- c("Base", "1min", "2min")
epoch_label <- c(Base = "Baseline", `1min` = "Min 1", `2min` = "Min 2")

all15 <- tibble::tribble(
  ~var_key, ~stem, ~label, ~units,
  "sbp", "SBP", "SBP", "mmHg",
  "dbp", "DBP", "DBP", "mmHg",
  "mbp", "MBP", "MBP", "mmHg",
  "hr", "HR", "HR", "bpm",
  "q", "Q", "Q (cardiac)", "L/min",
  "tpr", "TPR", "TPR", "dynes*s/cm5",
  "etco2", "ET-CO2", "ET-CO2", "mmHg",
  "mcav_peak", "MCAv peak", "MCAv peak", "cm/s",
  "mcav_min", "MCAv minimum", "MCAv min", "cm/s",
  "mcav_mean", "MCAv mean", "MCAv mean", "cm/s",
  "mcav_pulse", "MCAv pulse", "MCAv pulse", "cm/s",
  "mcav_gpi", "MCAv GPI", "MCAv pulsatility", "ratio",
  "cvci", "MCAv CVCi", "CVCi", "cm/s/mmHg",
  "cvri", "MCAv Resis", "CVRi", "mmHg*s/cm",
  "smo2", "SmO2", "SmO2", "%"
)

to_num <- function(x) {
  suppressWarnings(as.numeric(x))
}

value_from_row <- function(row, visit, stem, epoch, delta_baseline = FALSE) {
  if (epoch == "Base") {
    if (isTRUE(delta_baseline)) {
      return(0)
    }
    return(to_num(row[[paste(visit, stem, "Base")]]))
  }
  to_num(row[[paste(visit, "Delta", stem, "CPT", epoch)]])
}

include_subject <- function(row, var_key) {
  pid <- as.integer(row[["1 Identifier"]])
  sid <- as.character(row[["1 Subject ID"]])
  !(pid %in% global_excl_ids) && !(sid %in% var_excl[[var_key]])
}

build_paired <- function(df, var_key, stem, epoch, delta_baseline = FALSE, subset_fun = NULL) {
  rows <- list()
  j <- 1L

  for (i in seq_len(nrow(df))) {
    row <- df[i, , drop = FALSE]
    if (!include_subject(row, var_key)) {
      next
    }
    if (!is.null(subset_fun) && !isTRUE(subset_fun(row))) {
      next
    }

    pid <- as.integer(row[["1 Identifier"]])
    sid <- as.character(row[["1 Subject ID"]])
    v1 <- value_from_row(row, 1, stem, epoch, delta_baseline = delta_baseline)
    v2 <- value_from_row(row, 2, stem, epoch, delta_baseline = delta_baseline)

    if (!is.na(v1) && !is.na(v2)) {
      rows[[j]] <- data.frame(pid = pid, sid = sid, v1 = as.numeric(v1), v2 = as.numeric(v2))
      j <- j + 1L
    }
  }

  if (length(rows) == 0) {
    return(data.frame(pid = integer(), sid = character(), v1 = numeric(), v2 = numeric()))
  }

  dplyr::bind_rows(rows)
}

lin_ccc <- function(x, y) {
  x <- as.numeric(x)
  y <- as.numeric(y)
  mx <- mean(x)
  my <- mean(y)
  vx <- mean((x - mx)^2)
  vy <- mean((y - my)^2)
  cov_xy <- mean((x - mx) * (y - my))
  denom <- vx + vy + (mx - my)^2
  if (denom == 0) NA_real_ else (2 * cov_xy) / denom
}

icc_ccc <- function(dp) {
  n <- nrow(dp)
  if (n < 4) {
    return(list(ICC3k = NA_real_, ICC3k_lo = NA_real_, ICC3k_hi = NA_real_, ICC3k_p = NA_real_, CCC = NA_real_))
  }

  k <- 2
  y <- as.matrix(dp[, c("v1", "v2")])
  grand <- mean(y)
  row_means <- rowMeans(y)
  col_means <- colMeans(y)

  ss_targets <- k * sum((row_means - grand)^2)
  ss_raters <- n * sum((col_means - grand)^2)
  ss_total <- sum((y - grand)^2)
  ss_error <- ss_total - ss_targets - ss_raters

  df1 <- n - 1
  df2kd <- (n - 1) * (k - 1)
  msb <- ss_targets / df1
  mse <- ss_error / df2kd

  f3k <- msb / mse
  icc3k <- (msb - mse) / msb
  pval <- stats::pf(f3k, df1, df2kd, lower.tail = FALSE)

  alpha <- 0.05
  f3l <- f3k / stats::qf(1 - alpha / 2, df1, df2kd)
  f3u <- f3k * stats::qf(1 - alpha / 2, df2kd, df1)
  ci_lo <- round(1 - 1 / f3l, 2)
  ci_hi <- round(1 - 1 / f3u, 2)

  ccc_val <- as.numeric(lin_ccc(dp$v1, dp$v2))
  ccc_p <- if (!is.na(ccc_val) && n >= 4) {
    z <- atanh(ccc_val) * sqrt(n - 3)
    as.numeric(2 * stats::pnorm(abs(z), lower.tail = FALSE))
  } else {
    NA_real_
  }

  list(
    ICC3k = as.numeric(icc3k),
    ICC3k_lo = as.numeric(ci_lo),
    ICC3k_hi = as.numeric(ci_hi),
    ICC3k_p = as.numeric(pval),
    CCC = ccc_val,
    CCC_p = ccc_p
  )
}

linregress <- function(x, y) {
  x <- as.numeric(x)
  y <- as.numeric(y)
  ok <- is.finite(x) & is.finite(y)
  x <- x[ok]
  y <- y[ok]
  n <- length(x)
  if (n < 3 || stats::sd(x) == 0 || stats::sd(y) == 0) {
    return(list(slope = NA_real_, intercept = NA_real_, r = NA_real_, p = NA_real_))
  }
  slope <- sum((x - mean(x)) * (y - mean(y))) / sum((x - mean(x))^2)
  intercept <- mean(y) - slope * mean(x)
  r <- stats::cor(x, y)
  t_val <- r * sqrt((n - 2) / (1 - r^2))
  p <- 2 * stats::pt(abs(t_val), df = n - 2, lower.tail = FALSE)
  list(slope = as.numeric(slope), intercept = as.numeric(intercept), r = as.numeric(r), p = as.numeric(p))
}

spearman_scipy <- function(x, y) {
  x <- as.numeric(x)
  y <- as.numeric(y)
  ok <- is.finite(x) & is.finite(y)
  x <- x[ok]
  y <- y[ok]
  n <- length(x)
  if (n < 3 || stats::sd(x) == 0 || stats::sd(y) == 0) {
    return(list(rho = NA_real_, p = NA_real_))
  }
  rx <- rank(x, ties.method = "average")
  ry <- rank(y, ties.method = "average")
  rho <- stats::cor(rx, ry)
  t_val <- rho * sqrt((n - 2) / ((1 + rho) * (1 - rho)))
  p <- 2 * stats::pt(abs(t_val), df = n - 2, lower.tail = FALSE)
  list(rho = as.numeric(rho), p = as.numeric(p))
}

ba_stats <- function(dp) {
  n <- nrow(dp)
  if (n < 4) {
    return(list(n = n))
  }

  mean_val <- (dp$v1 + dp$v2) / 2
  diff_val <- dp$v1 - dp$v2
  md <- mean(diff_val)
  sd_diff <- stats::sd(diff_val)
  pb <- linregress(mean_val, diff_val)
  use_pb <- !is.na(pb$p) && pb$p < 0.05
  fitted <- if (use_pb) pb$intercept + pb$slope * mean_val else rep(md, n)
  resid <- diff_val - fitted
  hs <- spearman_scipy(mean_val, abs(resid))
  use_hs <- !is.na(hs$p) && hs$p < 0.05
  x_mid <- mean(mean_val)
  mid <- if (use_pb) pb$intercept + pb$slope * x_mid else md

  if (use_hs) {
    sd_fit <- linregress(mean_val, abs(resid))
    floor_val <- max(mean(abs(resid)) * 0.25, 1e-6)
    sd_mid <- max(sd_fit$intercept + sd_fit$slope * x_mid, floor_val)
    loa_lo <- mid - 1.96 * sd_mid
    loa_hi <- mid + 1.96 * sd_mid
    loa_type <- if (use_pb) "regression+fan" else "fan"
  } else if (use_pb) {
    sdr <- stats::sd(resid) * sqrt((n - 1) / (n - 2))
    loa_lo <- mid - 1.96 * sdr
    loa_hi <- mid + 1.96 * sdr
    loa_type <- "regression"
  } else {
    loa_lo <- md - 1.96 * sd_diff
    loa_hi <- md + 1.96 * sd_diff
    loa_type <- "standard"
  }

  list(
    n = n,
    Mean_diff = as.numeric(md),
    SD_diff = as.numeric(sd_diff),
    LoA_type = loa_type,
    LoA_lo = as.numeric(loa_lo),
    LoA_hi = as.numeric(loa_hi),
    Prop_bias_r = as.numeric(pb$r),
    Prop_bias_P = as.numeric(pb$p),
    Hetero_rho = as.numeric(hs$rho),
    Hetero_P = as.numeric(hs$p)
  )
}

fmt_sig3 <- function(x) {
  if (is.na(x)) {
    return("")
  }
  s <- sprintf("%.3g", x)
  s
}

quantile_np <- function(x, prob) {
  as.numeric(stats::quantile(x, probs = prob, type = 7, names = FALSE))
}

summary_string <- function(x) {
  x <- as.numeric(x)
  x <- x[!is.na(x)]
  if (length(x) < 3) {
    return(list(value = "", kind = ""))
  }
  if (stats::sd(x) == 0) {
    return(list(value = paste0(fmt_sig3(mean(x)), " +/- ", fmt_sig3(stats::sd(x))), kind = "mean_sd"))
  }
  p_norm <- tryCatch(stats::shapiro.test(x)$p.value, error = function(e) NA_real_)
  if (!is.na(p_norm) && p_norm >= 0.05) {
    return(list(value = paste0(fmt_sig3(mean(x)), " +/- ", fmt_sig3(stats::sd(x))), kind = "mean_sd"))
  }
  iqr <- quantile_np(x, 0.75) - quantile_np(x, 0.25)
  list(value = paste0(fmt_sig3(stats::median(x)), " [", fmt_sig3(iqr), "]"), kind = "median_iqr")
}

paired_rank_biserial <- function(diff) {
  diff <- as.numeric(diff)
  diff <- diff[!is.na(diff) & diff != 0]
  if (length(diff) == 0) {
    return(NA_real_)
  }
  ranks <- rank(abs(diff), ties.method = "average")
  pos <- sum(ranks[diff > 0])
  neg <- sum(ranks[diff < 0])
  total <- pos + neg
  if (total == 0) NA_real_ else (pos - neg) / total
}

paired_comparison <- function(dp) {
  if (nrow(dp) < 4) {
    return(list())
  }

  diff <- dp$v1 - dp$v2
  norm_p <- tryCatch(stats::shapiro.test(diff)$p.value, error = function(e) NA_real_)

  if (!is.na(norm_p) && norm_p >= 0.05) {
    test <- stats::t.test(dp$v1, dp$v2, paired = TRUE)
    effect <- if (stats::sd(diff) == 0) NA_real_ else mean(diff) / stats::sd(diff)
    return(list(Test = "paired t", P = as.numeric(test$p.value), Effect = as.numeric(effect), Effect_type = "paired d"))
  }

  p <- tryCatch(
    stats::wilcox.test(dp$v1, dp$v2, paired = TRUE, exact = TRUE, correct = FALSE)$p.value,
    error = function(e) {
      tryCatch(stats::wilcox.test(dp$v1, dp$v2, paired = TRUE, exact = FALSE, correct = FALSE)$p.value, error = function(e2) NA_real_)
    }
  )
  list(Test = "Wilcoxon", P = as.numeric(p), Effect = as.numeric(paired_rank_biserial(diff)), Effect_type = "rank biserial")
}

agreement_row <- function(df, var_key, stem, label, epoch) {
  dp <- build_paired(df, var_key, stem, epoch, delta_baseline = FALSE)
  b <- ba_stats(dp)
  icc <- icc_ccc(dp)
  comp <- paired_comparison(dp)

  if (nrow(dp) > 0) {
    v1s   <- summary_string(dp$v1)
    v2s   <- summary_string(dp$v2)
    diffs <- summary_string(dp$v1 - dp$v2)
    # Enforce IQR consistency: if any of the three is non-normal, all use median [IQR]
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
    mae <- mean(abs(dp$v1 - dp$v2))
    denom <- abs((dp$v1 + dp$v2) / 2)
    denom[denom == 0] <- NA_real_
    mape <- mean(abs(dp$v1 - dp$v2) / denom, na.rm = TRUE) * 100
    cv <- stats::sd(dp$v1 - dp$v2) / mean((dp$v1 + dp$v2) / 2) * 100
  } else {
    v1s <- v2s <- diffs <- list(value = "", kind = "")
    mae <- mape <- cv <- NA_real_
  }

  b_no_n <- b[setdiff(names(b), "n")]

  c(
    list(
      Variable = label,
      Epoch = unname(epoch_label[[epoch]]),
      n = nrow(dp),
      Visit_1 = v1s$value,
      Visit_1_summary = v1s$kind,
      Visit_2 = v2s$value,
      Visit_2_summary = v2s$kind,
      Fixed_Bias = diffs$value,
      Fixed_Bias_summary = diffs$kind,
      Comparison_Test = comp$Test %||% "",
      Comparison_P = comp$P %||% NA_real_,
      Effect = comp$Effect %||% NA_real_,
      Effect_type = comp$Effect_type %||% "",
      MAE = as.numeric(mae),
      `MAPE_%` = as.numeric(mape),
      `CV_%` = as.numeric(cv)
    ),
    b_no_n,
    icc
  )
}

build_tables_and_stats_r <- function(df) {
  rel_rows <- list()
  stats_rows <- list()
  j <- 1L

  for (i in seq_len(nrow(all15))) {
    var <- all15[i, ]
    for (epoch in epochs) {
      row <- agreement_row(df, var$var_key, var$stem, var$label, epoch)
      rel_rows[[j]] <- as.data.frame(row, check.names = FALSE, stringsAsFactors = FALSE)
      stats_rows[[j]] <- as.data.frame(row[c(
        "Variable", "Epoch", "n", "Mean_diff", "SD_diff", "LoA_type", "LoA_lo", "LoA_hi",
        "Prop_bias_r", "Prop_bias_P", "Hetero_rho", "Hetero_P",
        "ICC3k", "ICC3k_lo", "ICC3k_hi", "ICC3k_p", "CCC", "CCC_p"
      )], check.names = FALSE, stringsAsFactors = FALSE)
      j <- j + 1L
    }
  }

  rel <- dplyr::bind_rows(rel_rows)
  stats_df <- dplyr::bind_rows(stats_rows)

  for (col in names(rel)) {
    if (!col %in% c("Variable", "Epoch", "Visit_1", "Visit_1_summary", "Visit_2", "Visit_2_summary", "Fixed_Bias", "Fixed_Bias_summary", "Comparison_Test", "Effect_type", "LoA_type")) {
      rel[[col]] <- suppressWarnings(as.numeric(rel[[col]]))
    }
  }

  for (col in names(stats_df)) {
    if (!col %in% c("Variable", "Epoch", "LoA_type")) {
      stats_df[[col]] <- suppressWarnings(as.numeric(stats_df[[col]]))
    }
  }

  list(
    rel = rel,
    table2 = rel[rel$Epoch == "Baseline", , drop = FALSE],
    table3 = rel[rel$Epoch %in% c("Min 1", "Min 2"), , drop = FALSE],
    stats = stats_df
  )
}
