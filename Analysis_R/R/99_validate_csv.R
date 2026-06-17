csv_text_equal <- function(r_path, reference_path) {
  r_lines <- readLines(r_path, warn = FALSE)
  ref_lines <- readLines(reference_path, warn = FALSE)
  identical(r_lines, ref_lines)
}

quote_csv_field <- function(x) {
  x <- as.character(x)
  x[is.na(x)] <- ""
  needs_quote <- grepl('[,"\n\r]', x)
  x <- gsub('"', '""', x, fixed = TRUE)
  ifelse(needs_quote, paste0('"', x, '"'), x)
}

write_csv_minimal <- function(df, path) {
  header <- paste(quote_csv_field(names(df)), collapse = ",")
  rows <- vapply(seq_len(nrow(df)), function(i) {
    vals <- vapply(df, function(col) {
      val <- col[i]
      if (is.logical(val) && !is.na(val)) {
        return(if (isTRUE(val)) "True" else "False")
      }
      as.character(val)
    }, character(1))
    paste(quote_csv_field(vals), collapse = ",")
  }, character(1))
  writeLines(c(header, rows), path, useBytes = TRUE)
  invisible(path)
}

compare_csv_values <- function(r_path, reference_path) {
  r_df <- read.csv(r_path, check.names = FALSE, stringsAsFactors = FALSE)
  ref_df <- read.csv(reference_path, check.names = FALSE, stringsAsFactors = FALSE)

  same_shape <- identical(dim(r_df), dim(ref_df))
  same_names <- identical(names(r_df), names(ref_df))
  same_values <- isTRUE(all.equal(r_df, ref_df, check.attributes = FALSE))

  list(
    same_shape = same_shape,
    same_names = same_names,
    same_values = same_values,
    text_identical = csv_text_equal(r_path, reference_path),
    r_dim = dim(r_df),
    reference_dim = dim(ref_df)
  )
}

compare_csv_numeric <- function(r_path, reference_path, tolerance = 1e-8) {
  r_df <- read.csv(r_path, check.names = FALSE, stringsAsFactors = FALSE)
  ref_df <- read.csv(reference_path, check.names = FALSE, stringsAsFactors = FALSE)

  same_shape <- identical(dim(r_df), dim(ref_df))
  same_names <- identical(names(r_df), names(ref_df))
  same_values <- TRUE
  mismatches <- data.frame(
    row = integer(),
    column = character(),
    r_value = character(),
    reference_value = character(),
    stringsAsFactors = FALSE
  )

  if (same_shape && same_names) {
    for (col in names(r_df)) {
      for (i in seq_len(nrow(r_df))) {
        rv <- r_df[[col]][i]
        pv <- ref_df[[col]][i]
        r_num <- suppressWarnings(as.numeric(rv))
        p_num <- suppressWarnings(as.numeric(pv))

        both_num <- !is.na(r_num) && !is.na(p_num)
        both_blank <- (is.na(rv) || identical(rv, "")) && (is.na(pv) || identical(pv, ""))

        ok <- if (both_num) {
          isTRUE(all.equal(r_num, p_num, tolerance = tolerance, check.attributes = FALSE))
        } else if (both_blank) {
          TRUE
        } else {
          identical(as.character(rv), as.character(pv))
        }

        if (!ok) {
          same_values <- FALSE
          mismatches <- rbind(
            mismatches,
            data.frame(
              row = i,
              column = col,
              r_value = as.character(rv),
              reference_value = as.character(pv),
              stringsAsFactors = FALSE
            )
          )
        }
      }
    }
  } else {
    same_values <- FALSE
  }

  list(
    same_shape = same_shape,
    same_names = same_names,
    same_values = same_values,
    text_identical = csv_text_equal(r_path, reference_path),
    r_dim = dim(r_df),
    reference_dim = dim(ref_df),
    mismatches = mismatches
  )
}

print_csv_comparison <- function(label, comparison) {
  cat(label, "\n", sep = "")
  cat("  same_shape:    ", comparison$same_shape, "\n", sep = "")
  cat("  same_names:    ", comparison$same_names, "\n", sep = "")
  cat("  same_values:   ", comparison$same_values, "\n", sep = "")
  cat("  text_identical:", comparison$text_identical, "\n", sep = "")
}
