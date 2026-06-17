# FSU Figure Branding & Design Guide

Reference for producing AKI manuscript figures that conform to FSU brand standards. Updated for the AKI ROC analysis project (v5). FSU color palette is universal; group encoding, themes, and sizing are AKI-project specific.

---

## 1. Color Palette

### Primary (use as main figure colors)

| Role | Name | HEX | RGB |
|---|---|---|---|
| Primary 1 | FSU Garnet | `#782F40` | 120/47/64 |
| Primary 2 | FSU Gold | `#CEB888` | 206/184/136 |
| Neutral | White | `#FFFFFF` | 255/255/255 |
| Neutral | Stadium Night (Black) | `#101820` | 16/24/32 |

- **FSU Garnet must never be lightened or tinted.**
- **FSU Gold must never be darkened.**

### Secondary (allowed in data viz, gradients, icons, accents)

| Name | HEX |
|---|---|
| Plaza Brick | `#572932` |
| Gulf Sands | `#DFD1A7` |

Do **not** use secondary colors as primary figure colors or without a primary color present.

### Accent (data viz only, never as body text or gradients)

| Name | HEX | Used in figures for |
|---|---|---|
| Vault Garnet | `#A6192E` | — |
| Legacy Blue | `#425563` | **Young Females (YF)** |
| Westcott Water | `#5CB8B2` | — |
| Vault Gold | `#FFC72C` | — |

Accent colors must never be lightened, tinted, or darkened.

### Group Encoding — AKI project (Young Female / Older Female)

```r
COL_YOUNG <- "#425563"   # Legacy Blue  — Young Females (YF)
COL_OLDER <- "#782F40"   # FSU Garnet   — Older Females (OF)
COL_TEXT  <- "#101820"   # Stadium Night — all text and axes
COL_CI    <- "#D9D9D9"   # light gray   — CI ribbon fills
COL_DIAG  <- "#7A7A7A"   # medium gray  — diagonal chance line
```

Both groups use shape 21 (filled circle). Color alone distinguishes them; no shape change needed when only two groups share the same geometry.

In `scale_color_manual`, include n in the legend labels:

```r
scale_color_manual(
  values = c(YF = COL_YOUNG, OF = COL_OLDER),
  labels = c(YF = sprintf("Young females (n = %d)", n_young),
             OF = sprintf("Older females (n = %d)", n_older))
)
```

### Supporting (non-data) elements

- Reference line at zero: dashed `gray60`, `linewidth = 0.6`.
- Regression/OLS overlay (analysis figures): `color = "gray40"`, `fill = "gray85"`, `linewidth = 0.8`, `alpha = 0.35`.
- Plot background: `bg = "white"` on every saved figure.

---

## 2. Themes

There are two distinct theme patterns: one for **panel (faceted) figures** and one for **single figures**. Do not mix them. See `rules_figures.md § Panel vs. Single Figure Text Sizing` for the full sizing rationale.

### Panel figure theme — `fig1_theme` (for facet_wrap layouts)

```r
fig1_theme <- theme_classic(base_size = 11) +   # low base; all elements overridden below
  theme(
    text              = element_text(color = COL_TEXT),
    axis.title        = element_text(size = FIG1_AXIS_TITLE_SIZE),      # 20
    axis.text         = element_text(size = FIG1_AXIS_TEXT_SIZE, color = COL_TEXT),  # 18
    axis.line         = element_line(linewidth = 1.0, color = COL_TEXT),
    axis.ticks        = element_line(linewidth = 0.9, color = COL_TEXT),
    strip.background  = element_rect(fill = "grey95", color = NA),
    strip.text        = element_text(size = FIG1_PANEL_TITLE_SIZE, face = "bold", color = COL_TEXT),  # 24
    panel.grid.major  = element_line(color = "grey92", linewidth = 0.4),
    panel.grid.minor  = element_blank(),
    plot.title        = element_text(size = FIG1_TITLE_SIZE, face = "bold", hjust = 0.5),  # 26
    plot.background   = element_rect(fill = "white", color = NA),
    panel.background  = element_rect(fill = "white", color = NA),
    panel.spacing.x   = unit(3.4, "lines"),
    panel.spacing.y   = unit(1.2, "lines"),
    axis.title.y      = element_text(size = FIG1_AXIS_TITLE_SIZE, margin = margin(r = 10)),
    axis.title.x      = element_text(size = FIG1_AXIS_TITLE_SIZE, margin = margin(t = 10)),
    plot.margin       = margin(t = 10, r = 18, b = 12, l = 18)
  )
```

### Single-figure theme pattern (ROC, dot plot)

Use `base_size = FIG_INSET_TEXT_SIZE` and **do not explicitly set `axis.title`**. This lets the axis title inherit base_size so it always matches the axis text exactly — the most common source of visual mismatch in earlier versions.

```r
theme_single <- theme_classic(base_size = FIG_INSET_TEXT_SIZE) +   # 17.5 pt
  theme(
    text              = element_text(family = "Arial", color = COL_TEXT),
    axis.text         = element_text(size = FIG_INSET_TEXT_SIZE, color = COL_TEXT),
    # axis.title intentionally omitted — inherits base_size (matches axis.text)
    axis.line         = element_line(linewidth = 1.6, color = COL_TEXT),
    axis.ticks        = element_line(linewidth = 1.2, color = COL_TEXT),
    axis.ticks.length = unit(6, "pt"),
    plot.title        = element_text(size = FIG_TITLE_SIZE, face = "bold",
                                     hjust = 0.5, margin = margin(b = 10)),
    legend.position   = "bottom",          # or "none" for ROC figures
    legend.title      = element_blank(),
    legend.text       = element_text(size = FIG_INSET_TEXT_SIZE, color = COL_TEXT),
    panel.grid        = element_blank(),
    plot.background   = element_rect(fill = "white", color = NA),
    panel.background  = element_rect(fill = "white", color = NA),
    plot.margin       = margin(t = 20, r = 24, b = 16, l = 16)
  )
```

For dot plots with horizontal grid lines:

```r
panel.grid.major.x = element_blank(),
panel.grid.major.y = element_line(color = "grey92", linewidth = 0.6),
panel.grid.minor   = element_blank(),
```

---

## 3. Sizing

### Figure dimensions — AKI project (saved at 300 DPI, white background)

| Figure | Type | Width × Height (in) | Theme |
|---|---|---|---|
| Fig 1 — 6-panel ROC | `facet_wrap` (3 × 2) | **15 × 10** | `fig1_theme` |
| Fig 2 — AUC dot plot | Single horizontal | **11 × 7** | `theme_single` |
| Fig 3 — Paired ROC | Single ROC | **9 × 8** | `theme_single` |

```r
ggsave("figures/Fig1_6panel_ROC_v5.png", p_fig1, width = 15, height = 10, dpi = 300, bg = "white")
ggsave("figures/Fig2_AUC_dotplot_v5.png", p_fig2, width = 11, height = 7,  dpi = 300, bg = "white")
ggsave("figures/Fig3_paired_ROC_v5.png",  p_fig3, width = 9,  height = 8,  dpi = 300, bg = "white")
```

### Named size constants — define once at the top of the analysis cell, use everywhere

```r
FIG_AXIS_TEXT_SIZE  <- 14
FIG_AXIS_TITLE_SIZE <- FIG_AXIS_TEXT_SIZE             # 14
FIG_INSET_TEXT_SIZE <- FIG_AXIS_TEXT_SIZE * 1.25      # 17.5 — axis text on single figs
FIG_TITLE_SIZE      <- FIG_AXIS_TEXT_SIZE * 1.25      # 17.5 — title on single figs
FIG_ANNOT_SIZE      <- FIG_AXIS_TEXT_SIZE  / .pt      # ≈ 4.92 — geom_text inside panels
FIG_INSET_SIZE      <- FIG_INSET_TEXT_SIZE / .pt      # ≈ 6.15 — geom_text on single figs

# Panel-figure overrides (Fig 1 specific)
FIG1_AXIS_TEXT_SIZE   <- 18
FIG1_AXIS_TITLE_SIZE  <- 20
FIG1_PANEL_TITLE_SIZE <- 24   # strip.text on each facet
FIG1_TITLE_SIZE       <- 26   # overall figure title
```

### Line and point sizing — AKI figures

| Element | Value |
|---|---|
| ROC curve line (single figure) | `linewidth = 1.8` |
| ROC curve line (panel figure) | `linewidth = 1.1` |
| Diagonal chance line | `linetype = "dashed"`, `linewidth = 0.7–1.0` |
| CI ribbon alpha | `alpha = 0.18–0.35` |
| Dot plot point | `size = 4.2–5` |
| Error bar | `linewidth = 1.0–1.2`, `width = 0.18` |
| Dot plot dodge width | `position_dodge(width = 0.45–0.5)` |
| Axis line (single) | `linewidth = 1.6` |
| Axis line (panel) | `linewidth = 1.0` |
| Axis ticks (single) | `linewidth = 1.2`, `length = 6 pt` |
| Axis ticks (panel) | `linewidth = 0.9` |

---

## 4. Axis Value Spacing (X and Y)

This is the rule poster figures depend on: **the first and last tick must sit exactly on the bottom and top of the axis, with evenly spaced, round-number ticks in between.**

### Y axis — pattern

```r
scale_y_continuous(
  limits = c(LO, HI),
  breaks = c(LO, ..., HI),       # first break == LO, last break == HI
  expand = expansion(add = c(0, 0))   # no padding past the limits
)
```

Combined with:

```r
coord_cartesian(clip = "off")    # points/lines near the limits don't get clipped
```

### Why each piece matters

- `limits = c(LO, HI)` — fixes the axis to a chosen, human-friendly range.
- `breaks` listed explicitly — guarantees a tick is drawn at both the **bottom (`LO`)** and the **top (`HI`)**, plus evenly spaced interior values. Do not rely on ggplot's automatic break selection for poster figures; it often omits the endpoints.
- `expand = expansion(add = c(0, 0))` — kills the default 5% padding so the bottom and top breaks align with the actual ends of the axis line.
- `coord_cartesian(clip = "off")` — keeps `expand = 0` from clipping the radius of points or the cap of error bars sitting on the limits.

### Choosing the break set

Aim for **4–6 ticks** spanning the full range, at a round interval that hits both endpoints exactly. Worked examples from the AKI figures:

| Variable | Range | Breaks | Interval | # ticks |
|---|---|---|---|---|
| ROC axes (all figures) | 0 – 1 | 0, 0.25, 0.50, 0.75, 1.00 | 0.25 | 5 |
| AUC dot plot (x axis) | 0.20 – 1.02 | 0.25, 0.50, 0.75, 1.00 | 0.25 | 4 |

Workflow when picking breaks for a new variable:

1. Inspect the data range; round the lower bound **down** and upper bound **up** to a clean number that brackets the data plus error bars.
2. Pick an interval (1, 2, 5, 10, 20, 25, 40, 50, 100, …) that produces 4–6 ticks.
3. The bottom break **is** the lower limit; the top break **is** the upper limit.
4. Confirm visually: error bars and individual points should sit inside the limits, not on top of the axis ends.

### X axis — categorical (marker groups)

For dot plots where markers are on the x axis and groups are dodged, use `position_dodge(width = 0.45–0.5)` consistently across both `geom_errorbar` and `geom_point`. Keep `coord_cartesian(clip = "off")` so dodged points at the edges don't get clipped.

### Y axis on analysis (non-poster) figures

When in-notebook analysis figures don't need to land breaks on the limits, use the breathing-room expansion instead of `expand = c(0, 0)`:

```r
scale_y_continuous(
  breaks = if (!is.null(ybreaks)) ybreaks else waiver(),
  expand = expansion(mult = c(0.12, 0.04))   # 12% bottom, 4% top
)
```

The asymmetric expansion lifts the data off the x axis without overshooting at the top, which keeps room for subtitle text without dwarfing the data.

---

## 5. In-Figure Statistical Annotations

AKI figures use direct `annotate("text", ...)` and `geom_text()` for stats labels — not ggtext subtitles. All text sizes must use the `.pt` conversion (see `rules_figures.md § geom_text / annotate() Size Units`).

### Panel inset label (Fig 1 — inside each ROC panel)

```r
geom_text(data = stats_df, aes(x = 0.98, y = 0.04, label = label),
          hjust = 1, vjust = 0,
          size = FIG_ANNOT_SIZE,   # = 14 / .pt ≈ 4.92
          color = COL_TEXT, lineheight = 1.05)
```

The multi-line label is a single string with `\n`: `"AUC 0.72 (0.54–0.91)\nCutoff >1.0074\nSens 0.75 | Spec 0.63\nn = 34"`.

### Single-figure AUC label (Fig 3 — ROC side annotations)

```r
annotate("text", x = 0.97, y = 0.38, label = label_text,
         color = COL_24HR, size = FIG_INSET_SIZE,   # = 17.5 / .pt ≈ 6.15
         hjust = 1, fontface = "bold", lineheight = 1.25)
```

### DeLong p-value (Fig 3 — bottom right)

```r
annotate("text", x = 0.98, y = 0.08,
         label = delong_expr,    # use parse = TRUE with paste("DeLong ", italic(p), ...)
         color = COL_TEXT, size = FIG_INSET_SIZE, hjust = 1,
         parse = TRUE)
```

For parsed expressions, build the string as: `'paste("DeLong ", italic(p), " = 0.123")'`.

---

## 6. Quick Checklist Before Saving a Figure

### Colors and groups
- [ ] Young females = `#425563` (Legacy Blue), Older females = `#782F40` (Garnet), both shape 21.
- [ ] All text/axes = `#101820` (Stadium Night). CI bands = `#D9D9D9`. Diagonal = `#7A7A7A`.
- [ ] Legend labels include n: `sprintf("Young females (n = %d)", n_young)`.

### Theme
- [ ] Panel figures use `fig1_theme` (explicit FIG1_* sizes, low base_size, panel.spacing set).
- [ ] Single figures use `theme_single` (base_size = FIG_INSET_TEXT_SIZE; NO explicit axis.title).
- [ ] No panel grid on ROC figures. Horizontal grid only on dot plots.
- [ ] All figures: `plot.background` and `panel.background` = white.

### Text sizing
- [ ] Named size constants defined at the top of the analysis section.
- [ ] Any `geom_text()` or `annotate("text", ...)` uses `size = pt_value / .pt`, not raw pt.
- [ ] Axis title and axis text look the same visual weight on single figures (they should — if not, check that axis.title is not being overridden separately).

### Axes
- [ ] `coord_cartesian(clip = "off")` on all saved figures.
- [ ] ROC axes: `limits = c(0, 1)`, `breaks = c(0, 0.25, 0.5, 0.75, 1)`, `expand = expansion(mult = c(0.01, 0.01))`.
- [ ] Axis titles use sentence case; units in parentheses; same label text across all figures for the same variable.

### Save
- [ ] Dimensions match §3 table for the figure type.
- [ ] `dpi = 300`, `bg = "white"`.
- [ ] Filename follows `Fig{N}_{descriptor}_v{version}.png` convention.
