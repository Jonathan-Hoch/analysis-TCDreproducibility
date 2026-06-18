suppressPackageStartupMessages({
  library(dplyr)
  library(tibble)
})

fig1_vars <- tibble::tribble(
  ~var_key, ~stem, ~ylabel,
  "sbp", "SBP", "Delta SBP (mmHg)",
  "dbp", "DBP", "Delta DBP (mmHg)",
  "mbp", "MBP", "Delta MBP (mmHg)",
  "hr", "HR", "Delta HR (bpm)",
  "mcav_mean", "MCAv mean", "Delta MCAv mean (cm/s)",
  "cvci", "MCAv CVCi", "Delta CVCi (cm/s/mmHg)",
  "mcav_gpi", "MCAv GPI", "Delta MCAv pulsatility",
  "etco2", "ET-CO2", "Delta ET-CO2 (mmHg)"
)

fig1_var_label <- function(ylabel) {
  sub(" \\(.*$", "", sub("^Delta ", "", ylabel))
}

long_for_var <- function(df, var_key, stem, delta_baseline = TRUE, subset_fun = NULL) {
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
    for (visit in c(1, 2)) {
      for (epoch in epochs) {
        val <- value_from_row(row, visit, stem, epoch, delta_baseline = delta_baseline)
        if (!is.na(val)) {
          rows[[j]] <- data.frame(
            pid = pid,
            visit = paste0("V", visit),
            time = unname(epoch_label[[epoch]]),
            epoch = epoch,
            value = as.numeric(val),
            stringsAsFactors = FALSE
          )
          j <- j + 1L
        }
      }
    }
  }

  if (length(rows) == 0) {
    return(data.frame(pid = integer(), visit = character(), time = character(), epoch = character(), value = numeric()))
  }

  dplyr::bind_rows(rows)
}

build_fig1_timecourse_summary <- function(df) {
  rows <- list()
  j <- 1L

  for (i in seq_len(nrow(fig1_vars))) {
    var <- fig1_vars[i, ]
    long <- long_for_var(df, var$var_key, var$stem, delta_baseline = TRUE)
    variable <- fig1_var_label(var$ylabel)

    for (visit in c("V1", "V2")) {
      for (epoch in epochs) {
        y <- long$value[long$visit == visit & long$epoch == epoch]
        if (length(y) == 0) {
          center <- NA_real_
          err_lo <- 0
          err_hi <- 0
          kind <- ""
        } else {
          s <- summary_string(y)
          kind <- s$kind
          if (kind == "mean_sd") {
            center <- mean(y)
            err_lo <- stats::sd(y)
            err_hi <- err_lo
          } else {
            center <- stats::median(y)
            err_lo <- center - quantile_np(y, 0.25)
            err_hi <- quantile_np(y, 0.75) - center
          }
        }

        rows[[j]] <- data.frame(
          Variable = variable,
          Visit = visit,
          Epoch = unname(epoch_label[[epoch]]),
          Center = center,
          Err_lo = err_lo,
          Err_hi = err_hi,
          Summary = kind,
          stringsAsFactors = FALSE
        )
        j <- j + 1L
      }
    }
  }

  dplyr::bind_rows(rows)
}

rm_anova_two_by_three <- function(long) {
  visit_levels <- c("V1", "V2")
  time_levels <- c("Baseline", "Min 1", "Min 2")
  pids <- sort(unique(long$pid))
  y <- array(NA_real_, dim = c(length(pids), length(visit_levels), length(time_levels)))

  for (s in seq_along(pids)) {
    for (ia in seq_along(visit_levels)) {
      for (ib in seq_along(time_levels)) {
        vals <- long$value[
          long$pid == pids[s] &
            long$visit == visit_levels[ia] &
            long$time == time_levels[ib]
        ]
        if (length(vals) > 0) {
          y[s, ia, ib] <- mean(vals)
        }
      }
    }
  }

  complete <- apply(y, 1, function(x) all(!is.na(x)))
  y <- y[complete, , , drop = FALSE]
  n <- dim(y)[1]

  grand <- mean(y)
  mean_s <- apply(y, 1, mean)
  mean_a <- apply(y, 2, mean)
  mean_b <- apply(y, 3, mean)
  mean_ab <- apply(y, c(2, 3), mean)
  mean_sa <- apply(y, c(1, 2), mean)
  mean_sb <- apply(y, c(1, 3), mean)

  a <- 2
  b <- 3

  ss_a <- n * b * sum((mean_a - grand)^2)
  ss_b <- n * a * sum((mean_b - grand)^2)
  ss_ab <- n * sum((mean_ab - outer(mean_a, mean_b, "+") + grand)^2)

  ss_sa <- 0
  for (s in seq_len(n)) {
    for (ia in seq_len(a)) {
      ss_sa <- ss_sa + b * (mean_sa[s, ia] - mean_s[s] - mean_a[ia] + grand)^2
    }
  }

  ss_sb <- 0
  for (s in seq_len(n)) {
    for (ib in seq_len(b)) {
      ss_sb <- ss_sb + a * (mean_sb[s, ib] - mean_s[s] - mean_b[ib] + grand)^2
    }
  }

  ss_sab <- 0
  for (s in seq_len(n)) {
    for (ia in seq_len(a)) {
      for (ib in seq_len(b)) {
        resid <- y[s, ia, ib] -
          mean_sa[s, ia] -
          mean_sb[s, ib] -
          mean_ab[ia, ib] +
          mean_s[s] +
          mean_a[ia] +
          mean_b[ib] -
          grand
        ss_sab <- ss_sab + resid^2
      }
    }
  }

  effects <- data.frame(
    Effect = c("visit", "time", "visit:time"),
    ss = c(ss_a, ss_b, ss_ab),
    ss_error = c(ss_sa, ss_sb, ss_sab),
    df = c(a - 1, b - 1, (a - 1) * (b - 1)),
    df_error = c((n - 1) * (a - 1), (n - 1) * (b - 1), (n - 1) * (a - 1) * (b - 1)),
    stringsAsFactors = FALSE
  )
  effects$F <- (effects$ss / effects$df) / (effects$ss_error / effects$df_error)
  effects$P <- stats::pf(effects$F, effects$df, effects$df_error, lower.tail = FALSE)
  effects$partial_eta_sq <- (effects$F * effects$df) / ((effects$F * effects$df) + effects$df_error)
  effects$n_participants <- n
  effects$n_observations <- n * a * b
  effects
}

build_fig1_posthoc <- function(df, bonferroni_m = 3L) {
  time_levels <- c("Baseline", "Min 1", "Min 2")
  comparisons <- list(
    c("Baseline", "Min 1"),
    c("Baseline", "Min 2"),
    c("Min 1",    "Min 2")
  )
  rows <- list()
  j <- 1L

  for (i in seq_len(nrow(fig1_vars))) {
    var <- fig1_vars[i, ]
    long <- long_for_var(df, var$var_key, var$stem, delta_baseline = TRUE)
    long <- long[!is.na(long$value), , drop = FALSE]
    variable <- fig1_var_label(var$ylabel)

    # Pool visits (main effect of time, averaged over visit)
    pooled <- aggregate(value ~ pid + time, data = long, FUN = mean)

    for (comp in comparisons) {
      ta <- pooled$value[pooled$time == comp[1]]
      tb <- pooled$value[pooled$time == comp[2]]
      # Match on pid
      pid_a <- pooled$pid[pooled$time == comp[1]]
      pid_b <- pooled$pid[pooled$time == comp[2]]
      common <- intersect(pid_a, pid_b)
      ta <- ta[match(common, pid_a)]
      tb <- tb[match(common, pid_b)]
      diff_ab <- ta - tb
      n_comp <- length(common)

      norm_p <- if (n_comp >= 3) tryCatch(stats::shapiro.test(diff_ab)$p.value, error = function(e) NA_real_) else NA_real_

      if (!is.na(norm_p) && norm_p > 0.05) {
        test_res <- stats::t.test(ta, tb, paired = TRUE)
        p_raw <- as.numeric(test_res$p.value)
        effect <- if (stats::sd(diff_ab) > 0) mean(diff_ab) / stats::sd(diff_ab) else NA_real_
        test_name <- "paired t"
        effect_type <- "Cohen d"
      } else {
        p_raw <- tryCatch(
          stats::wilcox.test(ta, tb, paired = TRUE, exact = FALSE, correct = FALSE)$p.value,
          error = function(e) NA_real_
        )
        effect <- as.numeric(paired_rank_biserial(diff_ab))
        test_name <- "Wilcoxon"
        effect_type <- "rank biserial"
      }

      p_bonf <- min(p_raw * bonferroni_m, 1.0)

      rows[[j]] <- data.frame(
        Variable         = variable,
        Comparison       = paste0(comp[1], " vs ", comp[2]),
        Test             = test_name,
        n                = n_comp,
        P_raw            = p_raw,
        P_bonferroni     = p_bonf,
        Effect           = effect,
        Effect_type      = effect_type,
        stringsAsFactors = FALSE,
        check.names      = FALSE
      )
      j <- j + 1L
    }
  }

  dplyr::bind_rows(rows)
}

build_fig1_anova <- function(df) {
  rows <- list()
  j <- 1L

  for (i in seq_len(nrow(fig1_vars))) {
    var <- fig1_vars[i, ]
    long <- long_for_var(df, var$var_key, var$stem, delta_baseline = TRUE)
    long <- long[!is.na(long$value), , drop = FALSE]
    variable <- fig1_var_label(var$ylabel)
    n_all <- length(unique(long$pid))

    counts <- long %>%
      distinct(pid, visit, time) %>%
      count(pid, name = "n_cells")
    complete_pids <- counts$pid[counts$n_cells == 6]
    complete_long <- long[long$pid %in% complete_pids, , drop = FALSE]

    tab <- rm_anova_two_by_three(complete_long)
    for (r in seq_len(nrow(tab))) {
      rows[[j]] <- data.frame(
        Variable = variable,
        Test = "two-way repeated-measures ANOVA",
        Effect = tab$Effect[r],
        F = tab$F[r],
        `Num DF` = tab$df[r],
        `Den DF` = tab$df_error[r],
        P = tab$P[r],
        partial_eta_sq = tab$partial_eta_sq[r],
        n_participants = tab$n_participants[r],
        n_participants_available = n_all,
        n_observations = tab$n_observations[r],
        check.names = FALSE,
        stringsAsFactors = FALSE
      )
      j <- j + 1L
    }
  }

  dplyr::bind_rows(rows)
}
