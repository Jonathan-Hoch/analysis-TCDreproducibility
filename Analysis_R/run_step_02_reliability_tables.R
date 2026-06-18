`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

script_path <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
if (is.na(script_path)) {
  script_path <- file.path("Analysis_R", "run_step_02_reliability_tables.R")
}
script_dir <- dirname(normalizePath(script_path, winslash = "/", mustWork = FALSE))

source(file.path(script_dir, "R", "00_config.R"))
source(file.path(script_dir, "R", "01_load_data.R"))
source(file.path(script_dir, "R", "03_reliability_tables.R"))
source(file.path(script_dir, "R", "99_validate_csv.R"))

config <- analysis_config()
ensure_dir(config$output_dir)

if (!inputs_available(config)) {
  cat("SKIP: raw workbook inputs are not available.\n")
  cat("Expected master workbook: ", config$master_xlsx, "\n", sep = "")
  cat("Expected ET-CO2 workbook: ", config$etco2_xlsx, "\n", sep = "")
  cat("Set TCD_MASTER_XLSX and TCD_ETCO2_XLSX, then rerun this step.\n")
  quit(status = 0)
}

df <- load_tcd_data(config)
cat("Loaded rows: ", nrow(df), "\n", sep = "")
cat("Loaded columns: ", ncol(df), "\n", sep = "")
cat("Patched ET-CO2 cells: ", attr(df, "patched_n"), "\n", sep = "")

tables <- build_tables_and_stats_r(df)

outputs <- list(
  Table2_Baseline_All15_Reliability = tables$table2,
  Table3_Min1_Min2_All15_Reliability = tables$table3,
  BA_ICC_CCC_Statistics = tables$stats,
  SupplementaryTable_BA_Statistics = tables$stats
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
      print(utils::head(comparison$mismatches, 12), row.names = FALSE)
    }
  } else {
    cat("Reference not present; skipped comparison: ", reference_path, "\n", sep = "")
  }
}

# Revision note: Phase 2 revisions (visit-summary consistency, fixed-bias
# formatting by paired differences, and CCC p-values) intentionally
# change outputs vs. the Python reference. Validation is informational only.
cat("Note: Phase 2 revisions diverge from Python reference — validation is informational.\n")
