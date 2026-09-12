# make-demo.R -- render assets/demo.gif as a REAL replay of the smoke test
# No vhs/ffmpeg needed: frames are drawn with ragg (already a defense-stack package),
# assembled with gifski (maintainer-only one-time install). The typed command and the
# output are an actual `Rscript scripts/smoke-cjk.R` run captured live, not staged.
# Run from the skill root:  Rscript scripts/make-demo.R

suppressPackageStartupMessages(library(gifski))

root <- tryCatch(dirname(dirname(normalizePath(sub("^--file=", "",
  grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)), winslash = "/"))),
  error = function(e) getwd())
setwd(root)
outdir <- file.path(root, "assets")
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)

# -- 1. capture a real smoke run ------------------------------------------
out <- suppressWarnings(system2("Rscript", "scripts/smoke-cjk.R",
  stdout = TRUE, stderr = TRUE))
out <- out[!grepl("During startup|LC_CTYPE|Setting LC", out)]
out <- out[nzchar(trimws(out))]
# wrap long lines so nothing clips off the right edge
wrapped <- unlist(lapply(out, function(l) {
  if (nchar(l) <= 92) return(l)
  paste0(strwrap(l, width = 92, initial = "", prefix = ""), collapse = "\n") |> strsplit("\n") |> unlist()
}))
out <- wrapped
stopifnot(length(out) > 5)  # sanity: we must have real output

# -- 2. terminal look (Catppuccin Mocha-ish, matches assets/demo.tape) ------
BG <- "#1e1e2e"; FG <- "#cdd6f4"; GREEN <- "#a6e3a1"; YELLOW <- "#f9e2af"
GREY <- "#6c7086"; PROMPT <- "#89b4fa"

col_of <- function(l) {
  if (grepl("^\\[PASS\\]", l)) GREEN
  else if (grepl("^\\[WARN\\]", l)) YELLOW
  else if (grepl("^\\[INFO\\]", l) || grepl("^== summary", l)) GREY
  else FG
}

draw_frame <- function(lines, path, w = 760, h = 430, cursor = FALSE) {
  ragg::agg_png(path, width = w, height = h, res = 96, background = BG)
  par(mar = rep(0, 4), xaxs = "i", yaxs = "i")
  plot.new()
  usr <- par("usr")
  y0 <- usr[4] - 0.06
  dy <- (usr[4] - usr[3] - 0.10) / 18
  # titlebar dots
  for (k in 1:3) {
    symbols(0.035 + (k - 1) * 0.028, usr[4] - 0.025, circles = 0.011,
            bg = c("#f38ba8", "#f9e2af", "#a6e3a1")[k], fg = NA, add = TRUE, inches = FALSE)
  }
  yy <- y0
  for (l in lines) {
    text(0.03, yy, l, adj = c(0, 0.5), family = "mono", cex = 0.62, col = col_of(l))
    yy <- yy - dy
  }
  if (cursor) text(0.03 + nchar(tail(lines, 1)) * 0.0078, yy, "_",
                   adj = c(0, 0.5), family = "mono", cex = 0.62, col = FG)
  dev.off()
  path
}

# -- 3. build the frame sequence -------------------------------------------
cmd <- "Rscript scripts/smoke-cjk.R"
frames <- character(0)
tmp <- file.path(tempdir(), "frames"); dir.create(tmp, showWarnings = FALSE)
add <- function(lines, cursor = FALSE) {
  frames <<- c(frames, draw_frame(lines, file.path(tmp, sprintf("%03d.png", length(frames))), cursor = cursor))
}
# typing animation
lines <- character(0)
for (k in seq_len(nchar(cmd))) {
  add(c(lines, paste0("$ ", substr(cmd, 1, k))), cursor = TRUE)
}
lines <- c(lines, paste0("$ ", cmd))
add(lines); add(lines)  # beat before output
# output reveal
for (l in out) { lines <- c(lines, l); add(lines) }
for (k in 1:8) add(lines)  # final hold ~1s

# -- 4. assemble -------------------------------------------------------------
gif <- file.path(outdir, "demo.gif")
gifski(frames, gif, delay = 1/8, width = 760, height = 430)
cat(sprintf("demo.gif: %.1f KB, %d frames -> %s\n",
    file.size(gif) / 1024, length(frames), gif))
file.copy(frames[1], file.path(outdir, "demo-first-frame.png"), overwrite = TRUE)
file.copy(tail(frames, 1), file.path(outdir, "demo-last-frame.png"), overwrite = TRUE)
