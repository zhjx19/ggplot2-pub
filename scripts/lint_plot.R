#!/usr/bin/env Rscript
# lint_plot.R -- executable form of SKILL.md step 7 ("six quick checks") plus
# the structural rules from steps 2/4/5.
#
# Why this exists: the six quick checks used to be prose. Prose rules cannot
# fail a build, so a rule that is never asserted quietly rots -- the CJK export
# prescription did exactly that for months. Everything mechanically checkable
# lives here; everything that needs eyes stays out (see the SKIP note).
#
# ASCII-only on purpose, like smoke-cjk.R: this must survive legacy locales.
# Zero extra dependencies: ggplot2 (and its own deps rlang/scales) only.
#
# Usage:
#   source("scripts/lint_plot.R"); lint_plot(p)
#   Rscript scripts/lint_plot.R path/to/plot.R     # the file must define `p`

suppressPackageStartupMessages(library(ggplot2))

## ---------------------------------------------------------------- helpers
quo_name_of = function(q) {
  if (is.null(q)) return(NA_character_)
  e = rlang::get_expr(q)
  if (is.symbol(e)) rlang::as_string(e) else NA_character_
}
quo_is_literal = function(q) {
  if (is.null(q)) return(FALSE)
  e = rlang::get_expr(q)
  is.character(e) || is.numeric(e)
}
eval_quo = function(q, data) {
  if (is.null(q) || is.null(data)) return(NULL)
  tryCatch(rlang::eval_tidy(q, data), error = function(e) NULL)
}
## every aesthetic a layer maps, plot-level mapping merged in (layer wins)
## note: ggplot stores mappings as `uneval` objects, which modifyList() rejects
all_aes = function(p) {
  out = list()
  base = p$mapping
  for (ly in p$layers) {
    m = base
    for (nm in names(ly$mapping)) m[[nm]] = ly$mapping[[nm]]
    out[[length(out) + 1L]] = m
  }
  if (!length(p$layers)) out[[1L]] = base
  out
}
layer_classes = function(p) vapply(p$layers, function(l) class(l$geom)[1], character(1))
has_geom = function(p, cls) any(grepl(cls, layer_classes(p)))
panel_range = function(p, axis = "y") {
  b = tryCatch(ggplot_build(p), error = function(e) NULL)
  if (is.null(b)) return(NULL)
  pp = b$layout$panel_params[[1]]
  if (is.null(pp)) return(NULL)
  r = pp[[paste0(axis, ".range")]]
  if (is.null(r)) r = pp[[paste0(axis, ".continuous_range")]]
  r
}

## Rules that need a human/agent to LOOK at the rendered image. They are
## reported as SKIP so nobody mistakes them for "verified", and the corpus
## runner excludes them from the coverage check. Single source of truth.
human_only_rules = c("title_is_insight", "palette_harmony", "labels_not_overlapping",
                     "missing_impact_noted", "colour_consistent_across_plots")

## ---------------------------------------------------------------- rules
## Each rule returns list(status, detail); status in PASS/WARN/FAIL/SKIP.
## The public entry point never throws: a linter that crashes takes the whole
## regression down with it, which is worse than a missed rule. Internal errors
## surface as a FAIL row named `linter_error` instead of an exception.
lint_plot = function(p, min_group = 10, max_legend = 6) {
  tryCatch(
    .lint_plot_impl(p, min_group, max_legend),
    error = function(e) data.frame(rule = "linter_error", status = "FAIL",
                                   detail = conditionMessage(e), stringsAsFactors = FALSE))
}

.lint_plot_impl = function(p, min_group = 10, max_legend = 6) {
  res = list()
  add = function(rule, status, detail = "") res[[length(res) + 1L]] <<-
    data.frame(rule = rule, status = status, detail = detail, stringsAsFactors = FALSE)

  aes_list  = all_aes(p)
  geoms     = layer_classes(p)
  data      = tryCatch(p$data, error = function(e) NULL)

  ## 1. empty layers -- an empty ggplot() should not ship
  if (!length(p$layers)) add("empty_layers", "FAIL", "no layers")
  else add("empty_layers", "PASS", sprintf("%d layer(s)", length(p$layers)))

  ## 2. constant mapped inside aes() -> pseudo guide (step 4 antipattern)
  ##    `group = 1` is the RECOMMENDED way to collapse grouping (step 4), so
  ##    `group` is excluded; only guide-creating aesthetics count.
  guide_aes = c("colour", "color", "fill", "shape", "size", "linetype", "alpha")
  lit = character(0)
  for (m in aes_list) for (a in intersect(names(m), guide_aes)) if (quo_is_literal(m[[a]]))
    lit = c(lit, sprintf("%s = %s", a, deparse(rlang::get_expr(m[[a]]))))
  if (length(lit)) add("const_in_aes", "FAIL",
                       paste0("constant mapped in aes(): ", paste(unique(lit), collapse = "; ")))
  else add("const_in_aes", "PASS", "")

  ## 3. legend levels > 6 -> facet instead (step 5)
  ##    any aesthetic that draws a DISCRETE legend counts, not just colour/fill
  over = character(0)
  for (m in aes_list) for (a in c("colour", "color", "fill", "shape", "linetype", "size")) {
    v = eval_quo(m[[a]], data)
    if (!is.null(v) && (is.character(v) || is.factor(v))) {
      n = length(unique(v[!is.na(v)]))
      if (n > max_legend) over = c(over, sprintf("%s has %d levels", a, n))
    }
  }
  if (length(over)) add("legend_levels_gt6", "WARN",
                        paste0(paste(over, collapse = "; "), " -- facet instead"))
  else add("legend_levels_gt6", "PASS", "")

  ## 4/5. legend duplicated by an axis, or by a text label (step 4/7)
  dup_axis = character(0); dup_label = character(0)
  axis_vars = c(quo_name_of(p$mapping$x), quo_name_of(p$mapping$y))
  for (m in aes_list) {
    for (a in c("colour", "color", "fill")) {
      v = quo_name_of(m[[a]])
      if (!is.na(v) && v %in% axis_vars) dup_axis = c(dup_axis, v)
    }
    lab = quo_name_of(m$label)
    if (!is.na(lab)) for (a in c("colour", "color", "fill"))
      if (identical(quo_name_of(m[[a]]), lab)) dup_label = c(dup_label, lab)
  }
  legend_off = identical(p$theme$legend.position, "none")
  if (length(dup_axis) && !legend_off)
    add("legend_duplicates_axis", "WARN",
        paste0(paste(unique(dup_axis), collapse = ", "), " also on an axis -- drop the legend"))
  else add("legend_duplicates_axis", "PASS", if (legend_off) "legend off" else "")

  if (length(dup_label) && !legend_off)
    add("label_duplicates_legend", "WARN",
        paste0("label and colour both map ", unique(dup_label)[1], " -- drop the legend"))
  else add("label_duplicates_legend", "PASS", if (legend_off) "legend off" else "")

  ## 6. bar chart must start at zero (step 4)
  bars = grepl("GeomCol|GeomBar", geoms)
  yr = panel_range(p, "y")
  if (any(bars) && !is.null(yr) && is.finite(yr[1]) && yr[1] > 0)
    add("bar_y_not_zero", "FAIL", sprintf("panel y starts at %.3g", yr[1]))
  else add("bar_y_not_zero", "PASS", if (!any(bars)) "no bar layer" else "")

  ## 7. character categories should be ordered by value (step 2)
  ##    The recommended fix is INLINE: aes(fct_reorder(x, value), value) -- a
  ##    call, not a symbol. So evaluate the aesthetic instead of matching names.
  if (any(bars)) {
    xval = eval_quo(p$mapping$x, data); yval = eval_quo(p$mapping$y, data)
    if (!is.null(xval) && !is.null(yval) && length(xval) == length(yval) && length(xval) > 0 &&
        (is.character(xval) || is.factor(xval)) && is.numeric(yval)) {
      agg = tapply(yval, as.factor(xval), mean, na.rm = TRUE)
      if (!identical(names(agg)[order(agg)], names(agg)))
        add("unordered_categories", "WARN",
            "category axis not sorted by value -- use fct_reorder()")
      else add("unordered_categories", "PASS", "")
    } else add("unordered_categories", "SKIP", "category axis is neither character nor factor")
  } else add("unordered_categories", "SKIP", "no bar layer")

  ## 8. xlim()/ylim() drop data; coord_cartesian() only zooms (step 6)
  ##    NOTE: ggplot_build() does NOT drop out-of-range rows (measured: 3 -> 3,
  ##    10 -> 10), so comparing row counts is useless. What matters is whether
  ##    a scale-level limit actually EXCLUDES data -- `limits = c(0, NA)` is
  ##    fine, `xlim("a","b")` when "c" exists is not.
  dropped = character(0)
  for (sc in p$scales$scales) {
    is_pos = inherits(sc, "ScaleContinuousPosition") || inherits(sc, "ScaleDiscretePosition")
    if (!is_pos || is.null(sc$limits)) next
    for (a in intersect(sc$aesthetics, c("x", "y"))) {
      v = eval_quo(p$mapping[[a]], data)
      if (is.null(v)) next
      lim = sc$limits
      out = if (is.numeric(lim) && is.numeric(v)) {
        any(v < min(lim, na.rm = TRUE) | v > max(lim, na.rm = TRUE), na.rm = TRUE)
      } else {
        !all(as.character(v[!is.na(v)]) %in% as.character(lim))
      }
      if (out) dropped = c(dropped, a)
    }
  }
  if (length(dropped)) add("limits_drop_data", "FAIL",
                           paste0(paste(unique(dropped), collapse = ", "),
                                  " limits exclude rows -- use coord_cartesian() to zoom"))
  else add("limits_drop_data", "PASS", "")

  ## 9. pie / 3D / dual axis (step 7 antipatterns)
  bad_coord = inherits(p$coordinates, "CoordPolar")
  dual = any(vapply(p$scales$scales,
                    function(s) !is.null(s$secondary.axis) && !inherits(s$secondary.axis, "waiver"),
                    logical(1)))
  if (bad_coord || dual)
    add("polar_or_dual_axis", "FAIL",
        paste(c(if (bad_coord) "polar coord (pie)", if (dual) "secondary axis"), collapse = "; "))
  else add("polar_or_dual_axis", "PASS", "")

  ## 10. log/sqrt transform fed non-positive values (step 2 guard)
  badtrans = character(0)
  for (sc in p$scales$scales) {
    tr = tryCatch(sc$trans$name, error = function(e) NULL)
    if (!is.null(tr) && tr %in% c("log-10", "log-2", "log", "log10", "sqrt")) {
      a = sc$aesthetics[1]
      v = eval_quo(p$mapping[[a]], data)
      if (!is.null(v) && is.numeric(v) && any(v <= 0, na.rm = TRUE))
        badtrans = c(badtrans, sprintf("%s on non-positive values", a))
    }
  }
  if (length(badtrans)) add("transform_guard", "FAIL", paste(badtrans, collapse = "; "))
  else add("transform_guard", "PASS", "")

  ## 11. grouped smooth with too few observations per group (step 2/4)
  ##     ggplot groups a smooth implicitly by ANY discrete aesthetic, so
  ##     `aes(colour = g) + geom_smooth()` fits one line per group as well --
  ##     that is the most common way to write it, and the one this rule used to
  ##     miss (it only looked at an explicit `group`). `group = 1` is the
  ##     documented way to collapse on purpose, so a numeric literal is skipped.
  sm = which(grepl("GeomSmooth", geoms))
  if (length(sm)) {
    small = character(0)
    for (i in sm) {
      m = aes_list[[i]]
      grp = NULL; lab = NA_character_
      gq = m$group
      if (!is.null(gq)) {
        if (is.numeric(rlang::get_expr(gq))) {
          grp = NULL                                   # group = 1 -> collapsed on purpose
        } else {
          grp = eval_quo(gq, data); lab = quo_name_of(gq)
        }
      } else {
        for (a in c("colour", "color", "fill", "linetype", "shape")) {
          v = eval_quo(m[[a]], data)
          if (!is.null(v) && (is.character(v) || is.factor(v))) { grp = v; lab = a; break }
        }
      }
      if (!is.null(grp)) {
        n = min(table(as.factor(grp)))
        if (n < min_group) small = c(small, sprintf("grouped by %s: min %d obs", lab, n))
      }
    }
    if (length(small)) add("smooth_small_groups", "WARN",
                           paste0(paste(small, collapse = "; "), " -- fit one overall trend"))
    else add("smooth_small_groups", "PASS", "")
  } else add("smooth_small_groups", "SKIP", "no smooth layer")

  ## 12. continuous geom with BOTH axes categorical (step 7 quick check)
  ##     note: a dot plot legitimately has ONE categorical axis -- only the
  ##     "neither axis is continuous" case is the antipattern
  both_cat = FALSE
  for (i in seq_along(p$layers)) {
    if (!grepl("GeomPoint|GeomLine|GeomPath|GeomSmooth", geoms[i])) next
    vx = eval_quo(aes_list[[i]]$x, data); vy = eval_quo(aes_list[[i]]$y, data)
    is_cat = \(v) !is.null(v) && (is.character(v) || is.factor(v))
    if (is_cat(vx) && is_cat(vy)) both_cat = TRUE
  }
  if (both_cat) add("categorical_scatter", "FAIL",
                    "point/line layer with both axes categorical -- no continuous dimension")
  else add("categorical_scatter", "PASS", "")

  ## explicit human-only items: never pretend these were checked
  add("title_is_insight", "SKIP", "needs eyes: title must state the finding")
  add("palette_harmony", "SKIP", "needs eyes: colours must be readable and consistent")
  add("labels_not_overlapping", "SKIP", "needs eyes: ggrepel layout depends on canvas size")
  add("missing_impact_noted", "SKIP", "needs eyes: heavy missingness must be stated on the plot")
  add("colour_consistent_across_plots", "SKIP", "needs all plots at once, not one object")

  out = do.call(rbind, res)
  rownames(out) = NULL
  out
}

## ---------------------------------------------------------------- CLI
if (sys.nframe() == 0L) {
  args = commandArgs(trailingOnly = TRUE)
  if (!length(args)) { cat("usage: Rscript lint_plot.R <file.R>  (file must define `p`)\n"); quit(status = 1) }
  env = new.env(parent = globalenv())
  sys.source(args[1], envir = env)
  if (!exists("p", envir = env)) { cat("no object `p` defined by ", args[1], "\n"); quit(status = 1) }
  r = lint_plot(get("p", envir = env))
  for (i in seq_len(nrow(r))) cat(sprintf("[%-4s] %-26s %s\n", r$status[i], r$rule[i], r$detail[i]))
  quit(status = if (any(r$status == "FAIL")) 1 else 0)
}
