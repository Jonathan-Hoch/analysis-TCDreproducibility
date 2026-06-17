`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

script_path <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
if (is.na(script_path)) {
  script_path <- file.path("Analysis_R", "run_step_03_fig1_tables.R")
}
script_dir <- dirname(normalizePath(script_path, winslash = "/", mustWork = FALSE))

source(file.path(script_dir, "R", "00_config.R"))
source(file.path(script_dir, "R", "01_load_data.R"))
source(file.path(script_dir, "R", "03_reliability_tables.R"))
source(file.path(script_dir, "R", "04_fig1_tables.R"))
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
  Fig1_TimeCourse_Summary       = build_fig1_timecourse_summary(df),
  Fig1_ANOVA_Time_Visit_Results = build_fig1_anova(df)
)

# Post-hoc is new (no Python reference), write separately outside validation loop
posthoc <- build_fig1_posthoc(df)
posthoc_path <- file.path(config$output_dir, "Fig1_Posthoc_Bonferroni.csv")
write_csv_minimal(posthoc, posthoc_path)
cat("Wrote post-hoc table:", posthoc_path, "\n")

for (name in names(outputs)) {
  out_path <- file.path(config$output_dir, paste0(name, ".csv"))
  write_csv_minimal(outputs[[name]], out_path)
  reference_path <- file.path(config$reference_dir, paste0(name, ".csv"))
  comparison <- compare_csv_numeric(out_path, reference_path, tolerance = 1e-8)
  print_csv_comparison(paste0(name, " comparison against Python reference:"), comparison)
  if (!comparison$same_values) {
    cat("  first mismatches:\n")
    print(utils::head(comparison$mismatches, 15), row.names = FALSE)
  }
}

all_ok <- all(vapply(names(outputs), function(name) {
  out_path <- file.path(config$output_dir, paste0(name, ".csv"))
  reference_path <- file.path(config$reference_dir, paste0(name, ".csv"))
  compare_csv_numeric(out_path, reference_path, tolerance = 1e-8)$same_values
}, logical(1)))

if (!all_ok) {
  quit(status = 1)
}
