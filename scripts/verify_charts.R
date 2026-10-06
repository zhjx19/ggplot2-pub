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
for (f in cases) {
  rule = sub("\\.R$", "", basename(f))
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
covered = sub("\\.R$", "", basename(cases))
missing = setdiff(setdiff(probe$rule, human), covered)
check("every structural rule has a corpus case",
      length(missing) == 0,
      if (length(missing)) paste("no case for:", paste(missing, collapse = ", ")) else "")

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
