`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

script_path <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
if (is.na(script_path)) {
  script_path <- file.path("Analysis_R", "run_step_01_table1.R")
}
script_dir <- dirname(normalizePath(script_path, winslash = "/", mustWork = FALSE))

source(file.path(script_dir, "R", "00_config.R"))
source(file.path(script_dir, "R", "01_load_data.R"))
source(file.path(script_dir, "R", "02_table1_characteristics.R"))
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

table1 <- build_table1(df)
out_path <- file.path(config$output_dir, "Table1_Characteristics.csv")
write_csv_minimal(table1, out_path)
cat("Wrote: ", out_path, "\n", sep = "")

reference_path <- file.path(config$reference_dir, "Table1_Characteristics.csv")
if (file.exists(reference_path)) {
  comparison <- compare_csv_values(out_path, reference_path)
  print_csv_comparison("Table1 comparison against Python reference:", comparison)
  if (!comparison$same_values) {
    quit(status = 1)
  }
} else {
  cat("Reference not present; skipped comparison: ", reference_path, "\n", sep = "")
}
