suppressPackageStartupMessages({
  library(dplyr)
  library(tibble)
})

fig2_fig3_vars <- tibble::tribble(
  ~var_key, ~stem, ~label, ~units,
  "sbp", "SBP", "SBP", "mmHg",
  "dbp", "DBP", "DBP", "mmHg",
  "mbp", "MBP", "MBP", "mmHg",
  "hr", "HR", "HR", "bpm",
  "mcav_mean", "MCAv mean", "MCAv mean", "cm/s",
  "cvci", "MCAv CVCi", "CVCi", "cm/s/mmHg",
  "mcav_gpi", "MCAv GPI", "MCAv pulsatility", "ratio",
  "etco2", "ET-CO2", "ET-CO2", "mmHg"
)

group_subset <- function(group_name) {
  force(group_name)
  function(row) {
    sex <- as.character(row[["1 Sex"]])
    match <- as.character(row[["Menstrual phase matched?"]])
    if (is.na(match)) {
      match <- ""
    }

    if (group_name == "Male") {
      return(identical(sex, "Male"))
    }
    if (group_name == "Female matched") {
      return(identical(sex, "Female") && !grepl("Un-matched", match, fixed = TRUE))
    }
    if (group_name == "Female unmatched") {
      return(identical(sex, "Female") && grepl("Un-matched", match, fixed = TRUE))
    }
    FALSE
  }
}

exclude_unmatched_females <- function(row) {
  sex <- as.character(row[["1 Sex"]])
  match <- as.character(row[["Menstrual phase matched?"]])
  if (is.na(match)) {
    match <- ""
  }
  !(identical(sex, "Female") && grepl("Un-matched", match, fixed = TRUE))
}

build_reliability_stats_for_vars_r <- function(df, vars, subset_fun = NULL) {
  rows <- list()
  j <- 1L

  for (i in seq_len(nrow(vars))) {
    var <- vars[i, ]
    for (epoch in epochs) {
      dp <- build_paired(df, var$var_key, var$stem, epoch, delta_baseline = FALSE, subset_fun = subset_fun)
      vals <- c(
        ba_stats(dp),
        icc_ccc(dp),
        list(Variable = var$label, Epoch = unname(epoch_label[[epoch]]))
      )
      rows[[j]] <- as.data.frame(vals, check.names = FALSE, stringsAsFactors = FALSE)
      j <- j + 1L
    }
  }

  out <- dplyr::bind_rows(rows)
  for (col in names(out)) {
    if (!col %in% c("LoA_type", "Variable", "Epoch")) {
      out[[col]] <- suppressWarnings(as.numeric(out[[col]]))
    }
  }
  out
}

build_sex_reliability_r <- function(df, vars = fig2_fig3_vars) {
  rows <- list()
  j <- 1L
  groups <- c("Male", "Female matched", "Female unmatched")

  for (group in groups) {
    subset_fun <- group_subset(group)
    for (i in seq_len(nrow(vars))) {
      var <- vars[i, ]
      for (epoch in epochs) {
        dp <- build_paired(df, var$var_key, var$stem, epoch, delta_baseline = FALSE, subset_fun = subset_fun)
        vals <- c(
          icc_ccc(dp),
          list(Group = group, Variable = var$label, Epoch = unname(epoch_label[[epoch]]), n = nrow(dp))
        )
        rows[[j]] <- as.data.frame(vals, check.names = FALSE, stringsAsFactors = FALSE)
        j <- j + 1L
      }
    }
  }

  out <- dplyr::bind_rows(rows)
  for (col in names(out)) {
    if (!col %in% c("Group", "Variable", "Epoch")) {
      out[[col]] <- suppressWarnings(as.numeric(out[[col]]))
    }
  }
  out
}

build_loo_influence_tables_r <- function(df, vars = fig2_fig3_vars) {
  groups <- c("All", "Female unmatched", "Exclude unmatched females")
  summary_rows <- list()
  loo_rows <- list()
  s_idx <- 1L
  l_idx <- 1L

  subset_for <- function(group) {
    if (group == "All") {
      return(NULL)
    }
    if (group == "Exclude unmatched females") {
      return(exclude_unmatched_females)
    }
    group_subset(group)
  }

  for (group in groups) {
    subset_fun <- subset_for(group)
    for (i in seq_len(nrow(vars))) {
      var <- vars[i, ]
      for (epoch in epochs) {
        dp <- build_paired(df, var$var_key, var$stem, epoch, delta_baseline = FALSE, subset_fun = subset_fun)
        full <- icc_ccc(dp)
        if (nrow(dp) < 5) {
          next
        }

        icc_vals <- c()
        ccc_vals <- c()
        for (pid in sort(unique(dp$pid))) {
          dp_loo <- dp[dp$pid != pid, , drop = FALSE]
          loo_val <- icc_ccc(dp_loo)
          d_icc <- full$ICC3k - loo_val$ICC3k
          d_ccc <- full$CCC - loo_val$CCC
          icc_vals <- c(icc_vals, loo_val$ICC3k)
          ccc_vals <- c(ccc_vals, loo_val$CCC)
          loo_rows[[l_idx]] <- data.frame(
            Group = group,
            Variable = var$label,
            Epoch = unname(epoch_label[[epoch]]),
            pid_left_out = pid,
            n_full = nrow(dp),
            ICC_full = full$ICC3k,
            CCC_full = full$CCC,
            ICC_leave_one_out = loo_val$ICC3k,
            CCC_leave_one_out = loo_val$CCC,
            delta_ICC_full_minus_LOO = d_icc,
            delta_CCC_full_minus_LOO = d_ccc,
            abs_delta_ICC = abs(d_icc),
            abs_delta_CCC = abs(d_ccc),
            stringsAsFactors = FALSE
          )
          l_idx <- l_idx + 1L
        }

        summary_rows[[s_idx]] <- data.frame(
          Group = group,
          Variable = var$label,
          Epoch = unname(epoch_label[[epoch]]),
          n = nrow(dp),
          ICC_full = full$ICC3k,
          CCC_full = full$CCC,
          ICC_LOO_min = min(icc_vals, na.rm = TRUE),
          ICC_LOO_max = max(icc_vals, na.rm = TRUE),
          CCC_LOO_min = min(ccc_vals, na.rm = TRUE),
          CCC_LOO_max = max(ccc_vals, na.rm = TRUE),
          max_abs_delta_ICC = max(abs(icc_vals - full$ICC3k), na.rm = TRUE),
          max_abs_delta_CCC = max(abs(ccc_vals - full$CCC), na.rm = TRUE),
          stringsAsFactors = FALSE
        )
        s_idx <- s_idx + 1L
      }
    }
  }

  summary <- dplyr::bind_rows(summary_rows)
  loo <- dplyr::bind_rows(loo_rows)

  max_icc <- loo %>%
    group_by(Group, Variable, Epoch) %>%
    arrange(desc(abs_delta_ICC), .by_group = TRUE) %>%
    slice_head(n = 1) %>%
    ungroup() %>%
    select(
      Group,
      Variable,
      Epoch,
      Most_influential_ID_ICC = pid_left_out,
      ICC_change_full_minus_leave_one_out = delta_ICC_full_minus_LOO,
      Max_abs_change_ICC = abs_delta_ICC,
      ICC_after_removing_most_influential_ID = ICC_leave_one_out
    )

  max_ccc <- loo %>%
    group_by(Group, Variable, Epoch) %>%
    arrange(desc(abs_delta_CCC), .by_group = TRUE) %>%
    slice_head(n = 1) %>%
    ungroup() %>%
    select(
      Group,
      Variable,
      Epoch,
      Most_influential_ID_CCC = pid_left_out,
      CCC_change_full_minus_leave_one_out = delta_CCC_full_minus_LOO,
      Max_abs_change_CCC = abs_delta_CCC,
      CCC_after_removing_most_influential_ID = CCC_leave_one_out
    )

  out <- summary %>%
    left_join(max_icc, by = c("Group", "Variable", "Epoch")) %>%
    left_join(max_ccc, by = c("Group", "Variable", "Epoch")) %>%
    mutate(
      ICC_sign_changes_in_LOO = ICC_LOO_min < 0 & ICC_LOO_max > 0,
      CCC_sign_changes_in_LOO = CCC_LOO_min < 0 & CCC_LOO_max > 0,
      High_influence_flag = Max_abs_change_ICC >= 0.30 | Max_abs_change_CCC >= 0.20
    )

  numeric_cols <- names(out)[vapply(out, is.numeric, logical(1))]
  round_cols <- setdiff(numeric_cols, c("n", "Most_influential_ID_ICC", "Most_influential_ID_CCC"))
  out[round_cols] <- lapply(out[round_cols], round, digits = 3)

  out <- out %>% arrange(Group, Variable, Epoch)
  flagged <- out[out$High_influence_flag, , drop = FALSE]

  list(out = out, flagged = flagged)
}
