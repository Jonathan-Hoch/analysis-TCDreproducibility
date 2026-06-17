suppressPackageStartupMessages({
  library(dplyr)
  library(readxl)
})

required_input_paths <- function(config) {
  c(
    master_xlsx = config$master_xlsx,
    etco2_xlsx = config$etco2_xlsx
  )
}

inputs_available <- function(config) {
  paths <- required_input_paths(config)
  all(file.exists(paths))
}

assert_inputs_available <- function(config) {
  paths <- required_input_paths(config)
  missing <- paths[!file.exists(paths)]
  if (length(missing) > 0) {
    msg <- paste(
      "Raw workbook input(s) not found:",
      paste(names(missing), missing, sep = " = ", collapse = "\n"),
      "Set TCD_MASTER_XLSX and TCD_ETCO2_XLSX, or place both workbooks in data/raw/.",
      sep = "\n"
    )
    stop(msg, call. = FALSE)
  }
}

load_tcd_data <- function(config = analysis_config()) {
  assert_inputs_available(config)

  df <- readxl::read_excel(
    config$master_xlsx,
    sheet = "Data",
    na = c("", "NaN", "nan")
  )
  df <- df[!is.na(df[[1]]), , drop = FALSE]

  patch_df <- readxl::read_excel(
    config$etco2_xlsx,
    sheet = "ETCO2_Resp_Comparison",
    na = c("", "NaN", "nan")
  )
  patch_df <- patch_df[!is.na(patch_df[[1]]), , drop = FALSE]

  patch_ids <- c("K22V1", "K27V1", "K32V1/F10V1", "K36V1")
  patched_n <- 0L

  for (i in seq_len(nrow(patch_df))) {
    sid <- as.character(patch_df[["Subject ID"]][i])
    if (!(sid %in% patch_ids)) {
      next
    }

    mask <- as.character(df[["1 Subject ID"]]) == sid
    if (!any(mask, na.rm = TRUE)) {
      next
    }

    patch_cols <- setdiff(names(patch_df), c("Subject ID", "Source"))
    for (col in patch_cols) {
      if (!(col %in% names(df))) {
        next
      }

      row_idx <- which(mask)[1]
      current <- df[[col]][row_idx]
      value <- patch_df[[col]][i]

      if (is.na(current) && !is.na(value)) {
        df[[col]][row_idx] <- value
        patched_n <- patched_n + 1L
      }
    }
  }

  attr(df, "patched_n") <- patched_n
  df
}
