`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

script_path <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
if (is.na(script_path)) {
  script_path <- file.path("Analysis_R", "run_step_06_render_figures.R")
}
script_dir <- dirname(normalizePath(script_path, winslash = "/", mustWork = FALSE))

source(file.path(script_dir, "R", "00_config.R"))
source(file.path(script_dir, "R", "01_load_data.R"))
source(file.path(script_dir, "R", "03_reliability_tables.R"))
source(file.path(script_dir, "R", "04_fig1_tables.R"))
source(file.path(script_dir, "R", "05_sensitivity_tables.R"))
source(file.path(script_dir, "R", "06_figures.R"))

config <- analysis_config()
ensure_dir(config$output_dir)

if (!inputs_available(config)) {
  cat("SKIP: raw workbook inputs are not available.\n")
  quit(status = 0)
}

required_csvs <- c(
  "BA_ICC_CCC_Statistics.csv",
  "Fig5_ICC_CCC_Sex_Menstrual_Stats.csv",
  "Fig6_ICC_CCC_Exclude_Unmatched_Females_Stats.csv"
)
missing_csvs <- required_csvs[!file.exists(file.path(config$output_dir, required_csvs))]
if (length(missing_csvs) > 0) {
  stop("Run steps 02 and 04 before rendering figures. Missing: ", paste(missing_csvs, collapse = ", "), call. = FALSE)
}

df <- load_tcd_data(config)
cat("Loaded rows: ", nrow(df), "\n", sep = "")
cat("Loaded columns: ", ncol(df), "\n", sep = "")
cat("Patched ET-CO2 cells: ", attr(df, "patched_n"), "\n", sep = "")

render_all_figures_r(df, config)

for (name in names(figure_dims)) {
  png_path <- file.path(config$output_dir, paste0(name, ".png"))
  pdf_path <- file.path(config$output_dir, paste0(name, ".pdf"))
  cat("Rendered: ", png_path, " (", file.info(png_path)$size, " bytes)\n", sep = "")
  cat("Rendered: ", pdf_path, " (", file.info(pdf_path)$size, " bytes)\n", sep = "")
}
