suppressPackageStartupMessages({
  library(dplyr)
  library(tibble)
})

pick_col <- function(df, candidates, required = TRUE) {
  hit <- candidates[candidates %in% names(df)]
  if (length(hit) > 0) {
    return(hit[[1]])
  }

  if (required) {
    stop(
      "Could not find any expected column: ",
      paste(candidates, collapse = ", "),
      call. = FALSE
    )
  }

  NULL
}

fmt_1 <- function(x) {
  sprintf("%.1f", as.numeric(x))
}

fmt_0 <- function(x) {
  sprintf("%.0f", as.numeric(x))
}

count_summary <- function(x, preferred_order = NULL) {
  vals <- x[!is.na(x) & x != ""]
  tab <- as.data.frame(table(vals), stringsAsFactors = FALSE)
  names(tab) <- c("value", "n")

  if (!is.null(preferred_order)) {
    tab$order <- match(tab$value, preferred_order)
    tab <- tab[order(is.na(tab$order), tab$order, -tab$n, tab$value), ]
  } else {
    tab <- tab[order(-tab$n), ]
  }

  paste(paste(tab$n, tab$value), collapse = ", ")
}

median_iqr_summary <- function(x) {
  x <- as.numeric(x)
  x <- x[!is.na(x)]
  paste0(
    fmt_1(stats::median(x)),
    " [",
    fmt_1(stats::IQR(x)),
    "] (",
    fmt_1(min(x)),
    " - ",
    fmt_1(max(x)),
    ")"
  )
}

mean_sd_summary <- function(x, digits = 1) {
  x <- as.numeric(x)
  x <- x[!is.na(x)]
  fmt <- if (digits == 0) fmt_0 else fmt_1
  paste0(
    fmt(mean(x)),
    " +/- ",
    fmt(stats::sd(x)),
    " (",
    fmt(min(x)),
    " - ",
    fmt(max(x)),
    ")"
  )
}

build_table1 <- function(df) {
  sex_col <- pick_col(df, c("1 Sex", "Sex"))
  age_col <- pick_col(df, c("1 Age", "Age"))
  height_col <- pick_col(df, c("1 Screening Height (cm)", "1 Height", "Height", "Height, cm"))
  mass_col <- pick_col(df, c("1 Screening Mass (kg)", "1 Weight", "1 Body mass", "Body mass", "Body mass, kg", "Weight"))
  bmi_col <- pick_col(df, c("1 Screening BMI", "1 BMI", "BMI", "BMI, kg/m2"))
  race_col <- pick_col(df, c("1 Race (AI/A/NHPI/BW/MR/Unknown)", "1 Race", "Race"))
  ethnicity_col <- pick_col(df, c("1 Ethnicity (H/NH/Unknown)", "1 Ethnicity", "Ethnicity"))

  analytic <- df %>%
    filter(!is.na(.data[[sex_col]]))

  race <- dplyr::recode(
    as.character(analytic[[race_col]]),
    "W" = "White",
    "A" = "Asian",
    "BW" = "Black or White (multi)",
    "MR" = "Multiracial",
    "AI" = "American Indian/Alaskan Native",
    "B" = "Black or African American",
    .default = as.character(analytic[[race_col]])
  )
  race[is.na(race) | race == "NA"] <- "Unknown"

  ethnicity <- dplyr::recode(
    as.character(analytic[[ethnicity_col]]),
    "NH" = "Not Hispanic/Latine",
    "H" = "Hispanic/Latine",
    "Not Hispanic or Latinx" = "Not Hispanic/Latine",
    .default = as.character(analytic[[ethnicity_col]])
  )

  tibble::tibble(
    Characteristic = c(
      "Sex",
      "Age, yrs",
      "Height, cm",
      "Body mass, kg",
      "BMI, kg/m2",
      "Race",
      "Ethnicity"
    ),
    Value = c(
      count_summary(as.character(analytic[[sex_col]]), preferred_order = c("Female", "Male")),
      median_iqr_summary(analytic[[age_col]]),
      mean_sd_summary(analytic[[height_col]], digits = 0),
      mean_sd_summary(analytic[[mass_col]], digits = 1),
      mean_sd_summary(analytic[[bmi_col]], digits = 1),
      count_summary(
        race,
        preferred_order = c(
          "White",
          "Asian",
          "Unknown",
          "Black or White (multi)",
          "Multiracial",
          "American Indian/Alaskan Native",
          "Black or African American"
        )
      ),
      count_summary(ethnicity)
    )
  )
}
