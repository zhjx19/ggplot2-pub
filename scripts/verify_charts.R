#!/usr/bin/env Rscript
# verify_charts.R -- run every examples/chart_corpus case through lint_plot.R
# and assert the verdicts.
#
# The point: a rule whose VIOLATING case is not caught has not landed. This is
# the chart-side twin of data-cleaning's verify_snippets.R.
#
# ASCII-only on purpose, like smoke-cjk.R. Zero extra dependencies.
#
# Usage (any CWD): Rscript --vanilla scripts/verify_charts.R
# Exit code: 0 = all PASS; 1 = any FAIL.

suppressPackageStartupMessages(library(ggplot2))

failures = 0L
total    = 0L
check = function(name, cond, detail = "") {
  total <<- total + 1L
  ok = isTRUE(cond)
  if (!ok) failures <<- failures + 1L
  cat(sprintf("[%s] %s%s\n", if (ok) "PASS" else "FAIL", name,
              if (nzchar(detail)) paste0(" -- ", detail) else ""))
  invisible(ok)
}

args = commandArgs(trailingOnly = FALSE)
root = dirname(dirname(normalizePath(sub("^--file=", "", args[grep("^--file=", args)]))))
source(file.path(root, "scripts", "lint_plot.R"))

case_dir = file.path(root, "examples", "chart_corpus", "cases")
cases    = list.files(case_dir, pattern = "\\.R$", full.names = TRUE)

## ---- each rule: violating case must be caught, conforming case must pass ----
## A file named `rule__variant.R` adds another case for the same rule, so one
## rule can be pinned down in several shapes without inventing fake rule names.
for (f in cases) {
  rule = sub("__.*$", "", sub("\\.R$", "", basename(f)))
  env  = new.env(parent = globalenv())
  ok = tryCatch({ sys.source(f, envir = env); TRUE },
                error = function(e) { check(paste0(rule, ": source"), FALSE, conditionMessage(e)); FALSE })
  if (!ok) next
  s_bad  = lint_plot(env$bad())$status
  s_good = lint_plot(env$good())$status
  r_bad  = lint_plot(env$bad())$rule
  r_good = lint_plot(env$good())$rule

  got_bad  = s_bad[match(rule, r_bad)]
  got_good = s_good[match(rule, r_good)]
  check(sprintf("%-24s violating case is caught", rule),
        length(got_bad) == 1 && identical(got_bad, env$expect_bad),
        sprintf("got %s, want %s", paste(got_bad, collapse = "/"), env$expect_bad))
  check(sprintf("%-24s conforming case passes", rule),
        length(got_good) == 1 && identical(got_good, "PASS"),
        sprintf("got %s, want PASS", paste(got_good, collapse = "/")))
}

## ---- meta: every structural rule must have a corpus case ----
probe   = lint_plot(ggplot(mtcars, aes(wt, mpg)) + geom_point())
human   = human_only_rules          # single source of truth, defined in lint_plot.R
covered = sub("__.*$", "", sub("\\.R$", "", basename(cases)))
missing = setdiff(setdiff(probe$rule, human), covered)
check("every structural rule has a corpus case",
      length(missing) == 0,
      if (length(missing)) paste("no case for:", paste(missing, collapse = ", ")) else "")

## ---- robustness: the linter must never throw --------------------------------
## Found by probing: a bar chart with a CONSTANT x aesthetic (the pie idiom
## `aes("", value, fill = g)`) used to crash tapply() inside the category-sort
## rule and take the whole regression down with it. A linter must report.
pie_idiom = ggplot(data.frame(cat = c("a", "b", "c"), val = c(3, 4, 5)),
                   aes("", val, fill = cat)) +
  geom_bar(stat = "identity") + coord_polar(theta = "y")
r = tryCatch(lint_plot(pie_idiom), error = function(e) NULL)
check("linter survives odd-but-legal input and still flags it",
      !is.null(r) && !any(r$rule == "linter_error") &&
        r$status[r$rule == "polar_or_dual_axis"] == "FAIL",
      if (is.null(r)) "threw an exception"
      else sprintf("linter_error=%s polar=%s", any(r$rule == "linter_error"),
                   paste(r$status[r$rule == "polar_or_dual_axis"], collapse = "/")))

## ---- false alarms are worse than misses -------------------------------------
## coord_flip() renders a bar's value on the display x axis. The zero-baseline
## rule used to measure y regardless, and y after a flip is the CATEGORY axis
## (always > 0) -- so a correct chart got a FAIL telling you to fix it.
flip_ok = ggplot(data.frame(cat = c("a", "b", "c"), val = c(3, 4, 5)),
                 aes(fct_reorder(cat, val), val)) + geom_col() + coord_flip()
rf = lint_plot(flip_ok)
check("coord_flip bar chart is not falsely flagged on the zero baseline",
      rf$status[rf$rule == "bar_y_not_zero"] == "PASS",
      sprintf("got %s", paste(rf$status[rf$rule == "bar_y_not_zero"], collapse = "/")))

## A distribution plot's category axis is a deliberate design order
## (control -> treatment); the sort rule must stay out of it. This is the
## repeat-measures guard chart from the docs, so it is the exact shape that
## must not be "sorted".
dist_ok = ggplot(data.frame(g = factor(rep(c("ctl", "trtA", "trtB"), each = 5),
                                        levels = c("ctl", "trtA", "trtB")),
                            v = c(5, 6, 5, 7, 4, 9, 8, 9, 10, 8, 3, 9, 4, 8, 2)),
                 aes(g, v)) + geom_boxplot() + geom_jitter(width = 0.1)
rd = lint_plot(dist_ok)
check("distribution plot is exempt from the category-sort rule",
      rd$status[rd$rule == "unordered_categories"] == "SKIP",
      sprintf("got %s", paste(rd$status[rd$rule == "unordered_categories"], collapse = "/")))

## Never-throws must also hold for a layer-less plot: `grepl(..., character(0)) || ...`
## silently evaluates to NA, which used to blow up the sort rule's `if`.
re = lint_plot(ggplot(data.frame(x = 1:3, y = 1:3), aes(x, y)))
check("layer-less plot reports empty_layers instead of linter_error",
      re$status[re$rule == "empty_layers"] == "FAIL" && !any(re$rule == "linter_error"),
      sprintf("empty=%s linter_error=%s",
              paste(re$status[re$rule == "empty_layers"], collapse = "/"),
              any(re$rule == "linter_error")))

## ---- version mirror must match SKILL.md frontmatter ----
## The README version badge reads version.json dynamically; SKILL.md stays the
## single source of truth. This guard is what stops the mirror from drifting.
read_ver = function(path, n = -1L) {
  ln  = readLines(path, n = n, warn = FALSE)
  hit = grep('version"?[[:space:]]*:[[:space:]]*"', ln, value = TRUE)
  if (!length(hit)) return(NA_character_)
  sub('.*"([^"]+)".*', "\\1", hit[1])
}
fm = read_ver(file.path(root, "SKILL.md"), n = 30L)
jm = read_ver(file.path(root, "version.json"))
check("version.json mirrors SKILL.md frontmatter",
      !is.na(fm) && identical(fm, jm),
      sprintf("SKILL.md=%s version.json=%s", fm, jm))

cat(sprintf("\n== summary: %d check(s), %d failure(s) ==\n", total, failures))
cat(sprintf("   rules needing eyes (never auto-checked): %s\n", paste(human, collapse = ", ")))
if (failures > 0) quit(status = 1)
