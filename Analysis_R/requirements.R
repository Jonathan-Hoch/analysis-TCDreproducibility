required_packages <- c(
  "readxl",
  "dplyr",
  "tidyr",
  "ggplot2",
  "stringr",
  "purrr",
  "tibble",
  "patchwork",
  "IRkernel"
)

installed <- rownames(installed.packages())
missing <- setdiff(required_packages, installed)

if (length(missing) > 0) {
  install.packages(missing, repos = "https://cloud.r-project.org")
}

if ("IRkernel" %in% rownames(installed.packages()) || "IRkernel" %in% missing) {
  IRkernel::installspec(user = TRUE)
}
