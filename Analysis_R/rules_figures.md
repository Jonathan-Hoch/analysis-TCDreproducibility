# Figure Rules

These rules standardize analysis and poster figures across projects. Branding can be project-specific, but the visual QC rules should remain stable.

## Figure Output Pairing

- Every final figure should have a matching statistics or QC CSV when the figure contains inferential claims, thresholds, exclusions, or derived values.
- Figure filenames should be stable and ordered: `Fig1_*`, `Fig2_*`, `Fig7A_*`, etc.
- QC/stat filenames should name the figure topic and decision type, such as `*_method_decisions.csv`, `*_mixed_model_p.csv`, `*_threshold_summary.csv`, `*_p_values.csv`, or `*_qc.csv`.
- Save poster figures at 500 DPI with `bg = "white"` unless a different outlet requires another format.

## Axis Rules

- Comparable figures must use the same axis limits and breaks when the viewer is expected to compare magnitudes.
- Shared-axis specs should be computed from the pooled data across all comparable panels, including error bars, labels, reference lines, and annotation space.
- Poster axes should start and end on explicit numeric ticks. The first tick equals the lower limit and the last tick equals the upper limit.
- Use human-friendly break intervals that produce 4-6 ticks whenever possible.
- Do not rely on automatic ggplot breaks for final poster figures.
- Use `expand = expansion(add = c(0, 0))` for final poster axes that need endpoints aligned with the axis line.
- Use `coord_cartesian(clip = "off")` when annotations, points, or error bars sit near the plotting boundary.

## Axis Titles and Text

- Axis titles should use sentence case: capitalize the first word and proper nouns/standard abbreviations only.
- Use consistent capitalization for the same variable across figures.
- Put units in parentheses in axis titles, not in captions.
- Use the same variable name and unit text across all panels that show the same measure.
- Avoid title-case axis labels unless a venue specifically requires them.
- For physiological notation, preserve conventional abbreviations such as SBP, HR, RPP, VO2, MET, DXA, VAT, and TPR.

## Visual QC

- Check that all data points, error bars, p-value labels, threshold labels, and reference lines fit inside the saved figure.
- If p-value brackets or labels are added, include their y positions when choosing the y-axis range.
- For grouped bar/point plots, show individual points plus group summary; do not rely on bars alone.
- Use the same group order, colors, and shapes across all related figures.
- No legend is needed when group identity is clear from axis labels, captions, or repeated encoding.
- For reference-threshold plots, label the threshold directly on the plot and export the threshold counts used to support it.

## Statistical Labels

- In-figure labels should include the selected test or statistic when ambiguity is possible.
- Correlation figures should report Pearson `r` or Spearman `rho` based on the pair-specific normality screen.
- Group comparison labels should show P values and sample size when space allows.
- If a sensitivity exclusion is shown, state the excluded participant ID in the label or matching CSV.
- Use one consistent P-value style within a figure set.

## Figure Construction

- Build shared helper functions for repeated figure types instead of hand-tuning each panel.
- Centralize color, shape, theme, axis-selection, and P-value-formatting helpers.
- Align grob widths/heights before saving a row of related plots so axes and panels line up.
- Keep analysis figures readable and diagnostic; keep poster figures cleaner and publication-ready.
- Do not hide QC visuals because they are not poster-ready. QC visuals are working tools and should live beside the outputs they validate.

## Panel vs. Single Figure Text Sizing

These are different coding problems and must not share the same size constants.

### Why they differ

A `facet_wrap` figure renders each panel at a fraction of the full figure width/height. Text that looks correct on a single-figure canvas becomes too small when the same sizes are applied inside a panel. The fix is to use a **separate, larger size constant set** for any figure that uses faceting.

### Named constant pattern (define once, use everywhere in the notebook)

```r
# Shared base — used to derive all sizes
FIG_AXIS_TEXT_SIZE  <- 14          # base reference
FIG_AXIS_TITLE_SIZE <- FIG_AXIS_TEXT_SIZE
FIG_INSET_TEXT_SIZE <- FIG_AXIS_TEXT_SIZE * 1.25   # 17.5 pt — actual axis text on single figs
FIG_TITLE_SIZE      <- FIG_AXIS_TEXT_SIZE * 1.25   # 17.5 pt — figure title on single figs
FIG_ANNOT_SIZE      <- FIG_AXIS_TEXT_SIZE  / .pt   # ≈ 4.92 — geom_text/annotate inside panels
FIG_INSET_SIZE      <- FIG_INSET_TEXT_SIZE / .pt   # ≈ 6.15 — geom_text/annotate on single figs

# Panel-specific override (6-panel facet or any multi-panel layout)
FIG1_AXIS_TEXT_SIZE   <- 18
FIG1_AXIS_TITLE_SIZE  <- 20
FIG1_PANEL_TITLE_SIZE <- 24    # strip.text — label on each facet panel
FIG1_TITLE_SIZE       <- 26   # overall figure title
```

The `FIG1_*` constants must be set **per figure type** when panel count, layout, or save dimensions change.

### Single-figure theme rule: let axis.title inherit — do NOT override it explicitly

```r
theme_single <- theme_classic(base_size = FIG_INSET_TEXT_SIZE) +   # base = 17.5
  theme(
    axis.text  = element_text(size = FIG_INSET_TEXT_SIZE, color = COL_TEXT),
    # Do NOT add axis.title here — it inherits base_size and will match axis.text
    plot.title = element_text(size = FIG_TITLE_SIZE, face = "bold", hjust = 0.5),
    ...
  )
```

Explicitly setting `axis.title` to a different size from `axis.text` is the most common cause of visual mismatches. If both should look the same, omit the `axis.title` override and let base_size do the work.

### Panel-figure theme rule: always set both explicitly

```r
fig1_theme <- theme_classic(base_size = 11) +   # low base; everything overridden below
  theme(
    axis.title  = element_text(size = FIG1_AXIS_TITLE_SIZE),   # 20
    axis.text   = element_text(size = FIG1_AXIS_TEXT_SIZE, color = COL_TEXT),  # 18
    strip.text  = element_text(size = FIG1_PANEL_TITLE_SIZE, face = "bold"),   # 24
    plot.title  = element_text(size = FIG1_TITLE_SIZE, face = "bold", hjust = 0.5),  # 26
    panel.spacing.x = unit(3.4, "lines"),
    panel.spacing.y = unit(1.2, "lines"),
    ...
  )
```

Use a low `base_size` (e.g., 11) on panel themes so nothing inherits an unexpectedly large default — then set every relevant element explicitly.

## geom_text / annotate() Size Units

`element_text(size = X)` uses **points (pt)**. `geom_text(size = X)` and `annotate("text", size = X)` use **ggplot mm units**. They are NOT the same.

To make annotated text the same visual size as a given `element_text`:

```r
size_for_annotate <- pt_size / .pt   # .pt ≈ 2.845276
```

Examples using the named constants:
- Annotation inside a panel (small): `size = FIG_ANNOT_SIZE`  (= 14 / .pt ≈ 4.92)
- Inset AUC label on a single figure: `size = FIG_INSET_SIZE` (= 17.5 / .pt ≈ 6.15)

Never hard-code the numeric ggplot size directly — derive it from the pt constant so it stays in sync if you change the base size.

## Sample Size (n) Reporting

- Every figure must display the **per-group n directly on the graph** so the value is visible without reading a caption or external table.
- Acceptable placements: incorporated into x-axis tick labels (e.g., `IMST (n=12)`), in a corner annotation, or in the legend text. Pick one convention per notebook and stay consistent.
- When a figure shows multiple panels with different n (e.g., a variable with extra missingness in one panel), each panel must show its own n, not a single shared value.
- The n shown must match the analytic subset actually plotted after exclusions, not the full enrolled sample.

## Exclusion Disclosure

- For every figure, the notebook cell that generates it must **print a text summary of exclusions to the user** as cell output (e.g., via `print()` or a displayed DataFrame). Do not rely on the figure or caption alone.
- The printed summary must include, at minimum:
  - Count excluded from this figure's analytic subset.
  - Reason category for each exclusion (e.g., missing peak VO2, missing leg lean mass, missing group).
  - Participant IDs when the exclusion is participant-specific, so the reader can cross-reference the exclusion CSV from `rules_analysis.md`.
- If zero participants are excluded for a given figure, still print an explicit `"No exclusions for this figure (n=… per group)"` line so the absence is confirmed, not assumed.
- The printed exclusion text is for the notebook reader. It does **not** replace the exported exclusion CSVs required by `rules_analysis.md`; those remain the canonical record.

## Consistency

- The n displayed on the graph and the n implied by the printed exclusion summary must agree. If they don't, the figure is wrong — fix the subset before saving.

