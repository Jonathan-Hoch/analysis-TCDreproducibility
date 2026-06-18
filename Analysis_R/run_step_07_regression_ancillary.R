`%||%` <- function(x, y) if (is.null(x)) y else x

script_path <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
if (is.na(script_path)) script_path <- file.path("Analysis_R", "run_step_07_regression_ancillary.R")
script_dir <- dirname(normalizePath(script_path, winslash = "/", mustWork = FALSE))

source(file.path(script_dir, "R", "00_config.R"))
source(file.path(script_dir, "R", "01_load_data.R"))
source(file.path(script_dir, "R", "03_reliability_tables.R"))
source(file.path(script_dir, "R", "99_validate_csv.R"))
source(file.path(script_dir, "R", "07_regression_ancillary.R"))

config <- analysis_config()
ensure_dir(config$output_dir)

if (!inputs_available(config)) {
  cat("SKIP: raw workbook inputs are not available.\n")
  quit(status = 0)
}

df <- load_tcd_data(config)
cat("Loaded rows: ", nrow(df), "\n", sep = "")

# ---- Mixed model regression (Table 4) ----
cat("\n=== Mixed-model regression: delta_CVCi ~ pain + delta_ET-CO2 + visit ===\n")
reg <- build_regression_table(df)

write_csv_minimal(reg$coef_df, file.path(config$output_dir, "Table4_Regression_LMM.csv"))
write_csv_minimal(reg$vif_df,  file.path(config$output_dir, "Table4_Regression_VIF.csv"))
cat("Wrote: Table4_Regression_LMM.csv\n")
cat("Wrote: Table4_Regression_VIF.csv\n")

cat("\nCoefficients:\n")
print(reg$coef_df[, c("Predictor","b","beta","SE","t","P","Marginal_R2","Conditional_R2","ICC_model")],
      row.names = FALSE, digits = 4)

cat("\nVIF:\n")
print(reg$vif_df, row.names = FALSE, digits = 4)

# ---- PPT and water temperature reliability ----
cat("\n=== PPT and water temperature: V1 vs V2 reliability ===\n")
rel <- build_ppt_water_reliability(df)
ppt_water <- dplyr::bind_rows(rel$ppt, rel$water_temp)
ppt_water_pain <- dplyr::bind_rows(rel$ppt, rel$water_temp, rel$pain)
write_csv_minimal(ppt_water, file.path(config$output_dir, "Table_PPT_WaterTemp_Reliability.csv"))
write_csv_minimal(ppt_water_pain, file.path(config$output_dir, "Table_PPT_WaterTemp_Pain_Reliability.csv"))
cat("Wrote: Table_PPT_WaterTemp_Reliability.csv\n")
cat("Wrote: Table_PPT_WaterTemp_Pain_Reliability.csv\n")

show_cols <- c("Variable","n","Visit_1","Visit_2","Fixed_Bias",
               "Comparison_P","Effect","Effect_type","MAE","MAPE_%",
               "ICC3k","ICC3k_lo","ICC3k_hi","ICC3k_p","CCC","CCC_p")

cat("\nPPT:\n")
print(rel$ppt[, show_cols], row.names = FALSE, digits = 4)

cat("\nWater temperature:\n")
print(rel$water_temp[, show_cols], row.names = FALSE, digits = 4)

cat("\nPerceived pain (VAS):\n")
print(rel$pain[, show_cols], row.names = FALSE, digits = 4)

# ---- CPT hand sensitivity (Table 4 supplement) ----
cat("\n=== CPT hand sensitivity: does CPT side (L vs R) change the model? ===\n")
hand_sens <- build_cpt_hand_sensitivity(df, config$cpt_side_xlsx)
if (!is.null(hand_sens)) {
  write_csv_minimal(hand_sens, file.path(config$output_dir, "Table4_CPThand_Sensitivity.csv"))
  cat("Wrote: Table4_CPThand_Sensitivity.csv\n")
  cat(sprintf("n=%d obs / %d participants with CPT side data\n",
              hand_sens$n_obs, hand_sens$n_participants))
  cat(sprintf("CPT hand (right=1): b=%.5f, SE=%.5f, t=%.3f, p=%.4f\n",
              hand_sens$cpt_right_b, hand_sens$cpt_right_SE,
              hand_sens$cpt_right_t, hand_sens$cpt_right_P))
  cat(sprintf("LRT vs. base model: chi2(%d)=%.3f, p=%.4f\n",
              hand_sens$LRT_df, hand_sens$LRT_Chisq, hand_sens$LRT_P))
  cat(sprintf("Base model: Marginal R2=%.4f, Conditional R2=%.4f\n",
              hand_sens$Base_Marginal_R2, hand_sens$Base_Conditional_R2))
  cat(sprintf("+hand model: Marginal R2=%.4f, Conditional R2=%.4f\n",
              hand_sens$Hand_Marginal_R2, hand_sens$Hand_Conditional_R2))
} else {
  cat("SKIP: CPT side workbook not available.\n")
}
