# R Analysis Port

This folder contains the staged R port of the Python analysis in `B_Revised_Figures/`.

The port is being built step by step against the existing Python-generated CSV/figure outputs. The current reference outputs remain in `B_Revised_Figures/`; R-generated outputs are written to `Analysis_R/outputs/` so the Python results are not overwritten during validation.

## Current Steps

| Step | File | Purpose | Reference |
|---|---|---|---|
| 01 | `run_step_01_table1.R` | Load workbooks and reproduce participant characteristics | `B_Revised_Figures/Table1_Characteristics.csv` |
| 02 | `run_step_02_reliability_tables.R` | Reproduce Tables 2/3 and BA/ICC/CCC statistics | `B_Revised_Figures/Table2_*`, `Table3_*`, `BA_ICC_CCC_Statistics.csv` |
| 03 | `run_step_03_fig1_tables.R` | Reproduce Figure 1 time-course summary and ANOVA table | `B_Revised_Figures/Fig1_*csv` |
| 04 | `run_step_04_sensitivity_tables.R` | Reproduce Figure 5/6 reliability support tables | `B_Revised_Figures/Fig5_*Stats.csv`, `Fig6_*Stats.csv` |
| 05 | `run_step_05_loo_tables.R` | Reproduce leave-one-out influence tables | `B_Revised_Figures/SupplementaryTable_Reliability_Influence_LOO*.csv` |
| 06 | `run_step_06_render_figures.R` | Render R PNG/PDF figure outputs | `B_Revised_Figures/*.png`, `B_Revised_Figures/*.pdf` |

## Data Inputs

Raw Excel workbooks are not committed to Git. Set these paths before running if the workbooks are not in `data/raw/`:

```powershell
$env:TCD_MASTER_XLSX = "C:\path\to\CPT Data_visit split.xlsx"
$env:TCD_ETCO2_XLSX = "C:\path\to\CPT_ETCO2_Resp_Comparison.xlsx"
```

Or place both files in `data/raw/`.

## Run Validations

```powershell
& "C:\Program Files\R\R-4.6.0\bin\Rscript.exe" Analysis_R\run_step_01_table1.R
& "C:\Program Files\R\R-4.6.0\bin\Rscript.exe" Analysis_R\run_step_02_reliability_tables.R
& "C:\Program Files\R\R-4.6.0\bin\Rscript.exe" Analysis_R\run_step_03_fig1_tables.R
& "C:\Program Files\R\R-4.6.0\bin\Rscript.exe" Analysis_R\run_step_04_sensitivity_tables.R
& "C:\Program Files\R\R-4.6.0\bin\Rscript.exe" Analysis_R\run_step_05_loo_tables.R
& "C:\Program Files\R\R-4.6.0\bin\Rscript.exe" Analysis_R\run_step_06_render_figures.R
```

The scripts write CSVs to `Analysis_R/outputs/` and compare them to the Python references.

## Notebook

Open notebooks in `Analysis_R/notebooks/` in Jupyter and run top to bottom. They use the same R scripts as the command-line runners.
