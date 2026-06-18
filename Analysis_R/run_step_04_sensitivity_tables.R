`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

script_path <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
if (is.na(script_path)) {
  script_path <- file.path("Analysis_R", "run_step_04_sensitivity_tables.R")
}
script_dir <- dirname(normalizePath(script_path, winslash = "/", mustWork = FALSE))

source(file.path(script_dir, "R", "00_config.R"))
source(file.path(script_dir, "R", "01_load_data.R"))
source(file.path(script_dir, "R", "03_reliability_tables.R"))
source(file.path(script_dir, "R", "05_sensitivity_tables.R"))
source(file.path(script_dir, "R", "99_validate_csv.R"))

config <- analysis_config()
ensure_dir(config$output_dir)

if (!inputs_available(config)) {
  cat("SKIP: raw workbook inputs are not available.\n")
  quit(status = 0)
}

df <- load_tcd_data(config)
cat("Loaded rows: ", nrow(df), "\n", sep = "")
cat("Loaded columns: ", ncol(df), "\n", sep = "")
cat("Patched ET-CO2 cells: ", attr(df, "patched_n"), "\n", sep = "")

outputs <- list(
  Fig5_ICC_CCC_Sex_Menstrual_Stats = build_sex_reliability_r(df),
  Fig6_ICC_CCC_Exclude_Unmatched_Females_Stats = build_reliability_stats_for_vars_r(
    df,
    fig2_fig3_vars,
    subset_fun = exclude_unmatched_females
  )
)

for (name in names(outputs)) {
  out_path <- file.path(config$output_dir, paste0(name, ".csv"))
  write_csv_minimal(outputs[[name]], out_path)
  reference_path <- file.path(config$reference_dir, paste0(name, ".csv"))
  if (file.exists(reference_path)) {
    comparison <- compare_csv_numeric(out_path, reference_path, tolerance = 1e-8)
    print_csv_comparison(paste0(name, " comparison against Python reference:"), comparison)
    if (!comparison$same_values) {
      cat("  first mismatches:\n")
      print(utils::head(comparison$mismatches, 15), row.names = FALSE)
    }
  } else {
    cat("Reference not present; skipped comparison: ", reference_path, "\n", sep = "")
  }
}

all_ok <- all(vapply(names(outputs), function(name) {
  out_path <- file.path(config$output_dir, paste0(name, ".csv"))
  reference_path <- file.path(config$reference_dir, paste0(name, ".csv"))
  if (!file.exists(reference_path)) return(TRUE)
  compare_csv_numeric(out_path, reference_path, tolerance = 1e-8)$same_values
}, logical(1)))

if (!all_ok) {
  quit(status = 1)
}
