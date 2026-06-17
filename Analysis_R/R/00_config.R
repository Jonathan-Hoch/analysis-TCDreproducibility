find_repo_root <- function(start = getwd()) {
  path <- normalizePath(start, winslash = "/", mustWork = TRUE)

  repeat {
    has_reference <- file.exists(file.path(path, "B_Revised_Figures", "build_minute_level_outputs.py"))
    has_readme <- file.exists(file.path(path, "README.md"))
    if (has_reference && has_readme) {
      return(path)
    }

    parent <- dirname(path)
    if (identical(parent, path)) {
      stop("Could not find repository root from: ", start, call. = FALSE)
    }
    path <- parent
  }
}

analysis_config <- function(start = getwd()) {
  root <- find_repo_root(start)
  analysis_dir <- file.path(root, "Analysis_R")
  output_dir <- Sys.getenv("TCD_R_OUTPUT_DIR", file.path(analysis_dir, "outputs"))
  data_dir <- Sys.getenv("TCD_DATA_DIR", file.path(root, "data", "raw"))

  list(
    root = root,
    analysis_dir = analysis_dir,
    output_dir = output_dir,
    reference_dir = file.path(root, "B_Revised_Figures"),
    data_dir = data_dir,
    master_xlsx    = Sys.getenv("TCD_MASTER_XLSX",    file.path(data_dir, "CPT Data_visit split.xlsx")),
    etco2_xlsx     = Sys.getenv("TCD_ETCO2_XLSX",     file.path(data_dir, "CPT_ETCO2_Resp_Comparison.xlsx")),
    cpt_side_xlsx  = Sys.getenv("TCD_CPT_SIDE_XLSX",  file.path(data_dir, "CPT Data.xlsx"))
  )
}

ensure_dir <- function(path) {
  if (!dir.exists(path)) {
    dir.create(path, recursive = TRUE, showWarnings = FALSE)
  }
  invisible(path)
}
