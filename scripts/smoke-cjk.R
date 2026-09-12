# smoke-cjk.R -- ggplot2-pub environment smoke test
# ASCII-only on purpose: this script must survive legacy locales (LC_CTYPE=C on
# Windows terminals) where UTF-8 source files get mangled at read time.
# All Chinese literals use \u escapes. Run: Rscript scripts/smoke-cjk.R

results <- character(0)
report <- function(status, label, detail = "") {
  results <<- c(results, status)
  cat(sprintf("[%s] %s%s\n", status, label, if (nzchar(detail)) paste0(" -- ", detail) else ""))
}

cat("== ggplot2-pub smoke ==\n")
cat("R ", as.character(getRversion()), "| ggplot2 ", as.character(packageVersion("ggplot2")), "\n", sep = "")
li <- l10n_info()
cat("locale UTF-8: ", li[["UTF-8"]], " | codepage:", li[["codepage"]] %||% NA, "\n", sep = "")
if (!isTRUE(li[["UTF-8"]])) {
  report("WARN", "non-UTF-8 locale (common when Rscript runs from a terminal)",
         "Chinese plots must follow SKILL.md step-6 defense; render-verify before delivery")
} else {
  report("PASS", "UTF-8 locale")
}

# 1. core packages
core <- c("ggplot2", "dplyr", "forcats", "scales")
miss <- core[!core %in% rownames(installed.packages())]
if (length(miss)) report("FAIL", "core packages missing", paste(miss, collapse = ", ")) else
  report("PASS", "core packages present", paste(core, collapse = ", "))

suppressPackageStartupMessages({
  library(ggplot2); library(dplyr); library(forcats); library(scales)
})
`%||%` <- function(a, b) if (is.null(a)) b else a

# 2. theme_pub() exists, uses plain element_text (NOT ggtext textbox), and is overridable
te_paper  <- "#f5f4ee"; te_ink <- "#16241d"; te_body <- "#2c3a31"; te_line <- "#dad9ca"
theme_pub = function(base_size = 12, base_family = "sans") {
  theme_minimal(base_size = base_size, base_family = base_family) +
    theme(
      plot.background  = element_rect(fill = te_paper, colour = NA),
      panel.background = element_rect(fill = te_paper, colour = NA),
      panel.grid.major = element_line(colour = te_line, linewidth = 0.3),
      panel.grid.minor = element_blank(),
      plot.title.position = "plot",
      plot.title    = element_text(colour = te_ink, face = "bold", size = base_size + 2,
                                   hjust = 0, margin = margin(b = 6)),
      plot.subtitle = element_text(colour = te_body, size = base_size - 1,
                                   hjust = 0, margin = margin(b = 12)),
      plot.caption  = element_text(colour = "#7d8a80", size = base_size - 4, hjust = 0),
      text          = element_text(colour = te_body),
      axis.text     = element_text(colour = te_body),
      plot.margin   = margin(18, 18, 18, 18)
    )
}
tp <- theme_pub()
if (inherits(tp$plot.title, "element_textbox")) {
  report("FAIL", "theme_pub plot.title is a ggtext textbox (locked/fragile)") 
} else {
  report("PASS", "theme_pub uses plain element_text (no textbox lock)")
}
ov <- tryCatch({
  p0 <- ggplot(mtcars, aes(wt, mpg)) + geom_point() + tp
  p1 <- p0 + theme(plot.title = element_text(size = 20))
  "ok"
}, error = function(c) paste("override failed:", conditionMessage(c)))
if (identical(ov, "ok")) report("PASS", "theme_pub overridable via + theme()") else
  report("FAIL", ov)

# 3. antipattern regression: constant-in-aes creates a pseudo guide, outside does not
d <- data.frame(x = 1:5, y = (1:5)^2)
g_bad  <- ggplot(d, aes(x, y)) + geom_point(aes(color = "steelblue"))
g_good <- ggplot(d, aes(x, y)) + geom_point(color = "steelblue")
n_bad  <- length(ggplot_build(g_bad)$plot$guides$guides)
n_good <- length(ggplot_build(g_good)$plot$guides$guides)
if (n_bad > 0 && n_good == 0) report("PASS", "aes-constant antipattern detected as documented (pseudo-guide 1 vs 0)") else
  report("WARN", "aes-constant behavior changed upstream", sprintf("bad=%s good=%s", n_bad, n_good))

# 4. CJK canary: full publication pipeline with Chinese labels, then verify the file
CN_TITLE <- "\u76ee\u6807\u7ec4\u663e\u8457\u9ad8\u4e8e\u5176\u4ed6\u7ec4"   # insight title
CN_SUB   <- "\u67f1\u957f\u8868\u793a\u5404\u7ec4\u5e73\u5747\u5f97\u5206"   # subtitle
CN_X     <- "\u5e73\u5747\u5f97\u5206"                                       # x axis
CN_CAP   <- "\u6570\u636e\u6765\u6e90\uff1a\u9879\u76ee\u6570\u636e"         # caption
FOCUS    <- "\u76ee\u6807\u7ec4"                                             # focus group

set.seed(1)
df <- data.frame(
  group = rep(c("\u57fa\u7ebf\u7ec4", "\u5bf9\u7167A", "\u5bf9\u7167B", FOCUS, "\u5907\u9009\u7ec4"), each = 40),
  score = c(rnorm(40, 50, 8), rnorm(40, 52, 8), rnorm(40, 51, 8), rnorm(40, 65, 8), rnorm(40, 49, 8))
)
plot_data <- df |>
  summarise(value = mean(score, na.rm = TRUE), .by = group) |>
  mutate(group = fct_reorder(group, value), is_focus = group == FOCUS)

p <- ggplot(plot_data, aes(x = value, y = group, fill = is_focus)) +
  geom_col(width = 0.7, color = NA) +
  scale_x_continuous(labels = scales::comma) +
  scale_fill_manual(values = c(`TRUE` = "#b5534e", `FALSE` = "#BDBDBD"), guide = "none") +
  labs(title = CN_TITLE, subtitle = CN_SUB, x = CN_X, y = NULL, caption = CN_CAP) +
  theme_pub()

outdir <- file.path(tempdir(), "ggplot2-pub-smoke")
dir.create(outdir, showWarnings = FALSE)
f <- file.path(outdir, "cjk-canary.png")
res <- tryCatch({ ggsave(f, plot = p, width = 8, height = 5, dpi = 150, bg = "#f5f4ee"); NULL },
  error = function(c) conditionMessage(c))
if (is.null(res) && file.exists(f) && file.size(f) > 10000) {
  report("PASS", "CJK canary rendered", sprintf("%.1f KB -> %s", file.size(f) / 1024, f))
} else {
  report("FAIL", "CJK canary failed", if (!is.null(res)) res else "file too small (blank image?)")
}

# 5. CJK PDF export via cairo_pdf (default pdf() device silently replaces CJK with dots)
fp <- file.path(outdir, "cjk-canary.pdf")
resp <- tryCatch({ ggsave(fp, plot = p, width = 8, height = 5, device = cairo_pdf); NULL },
  error = function(c) conditionMessage(c))
if (is.null(resp) && file.exists(fp) && file.size(fp) > 5000) {
  report("PASS", "CJK PDF via cairo_pdf", sprintf("%.1f KB -> %s", file.size(fp) / 1024, fp))
} else {
  report("FAIL", "CJK PDF export failed", if (!is.null(resp)) resp else "file too small")
}

# 6. zero-dep CVD checker sanity (base-R Machado simulation, see references/palettes.md)
cvd_check <- function(palette) {
  s2l <- function(u) ifelse(u <= 0.04045, u / 12.92, ((u + 0.055) / 1.055)^2.4)
  MD <- matrix(c(.367322, .860646, -.227968, .280085, .693084, .026831,
                 .01182, .04294, .94524), 3, 3)
  MP <- matrix(c(.152286, 1.052583, -.204868, .114503, .786281, .099216,
                 -.003882, -.048116, 1.051998), 3, 3)
  sim <- function(M) {
    lin <- apply(col2rgb(palette) / 255, 2, s2l)
    out <- pmin(1, pmax(0, M %*% lin)); out <- matrix(out, 3, ncol(lin))
    sweep(out, 2, colSums(out), "/")
  }
  D <- sim(MD); P <- sim(MP)
  lum <- sapply(palette, function(h) {
    l <- apply(col2rgb(h) / 255, 2, s2l); .2126 * l[1] + .7152 * l[2] + .0722 * l[3] })
  out <- data.frame()
  n <- length(palette)
  for (i in seq_len(n - 1)) for (j in seq(i + 1, n)) {
    cd <- min(sqrt(sum((D[, i] - D[, j])^2)), sqrt(sum((P[, i] - P[, j])^2)))
    dl <- abs(lum[i] - lum[j])
    out <- rbind(out, data.frame(verdict = if (cd < 0.10 && dl < 0.10) "\u786c\u51b2\u7a81" else if (cd < 0.05) "\u8f6f\u63d0\u9192" else "-"))
  }
  out
}
bad_flagged  <- any(cvd_check(c("#B22222", "#228B22"))$verdict == "\u786c\u51b2\u7a81")
good_cleaned <- all(cvd_check(c("#BDBDBD", "#D55E00"))$verdict == "-")
if (bad_flagged && good_cleaned) {
  report("PASS", "CVD checker calibrated (bad pair flagged, highlight pair clean)")
} else {
  report("FAIL", "CVD checker miscalibrated", sprintf("bad_flagged=%s good_cleaned=%s", bad_flagged, good_cleaned))
}

# 7. optional stack status (informational, never fails)
opt <- c("ggrepel", "patchwork", "ggdist", "gghighlight", "scico", "MetBrewer", "khroma", "showtext", "ragg")
have <- opt[opt %in% rownames(installed.packages())]
lack <- setdiff(opt, have)
report("INFO", sprintf("enhancement stack: have %d/%d", length(have), length(opt)),
       if (length(lack)) paste("missing:", paste(lack, collapse = ", ")) else "all present")

cat(sprintf("\n== summary: PASS=%d WARN=%d FAIL=%d INFO=%d ==\n",
    sum(results == "PASS"), sum(results == "WARN"), sum(results == "FAIL"), sum(results == "INFO")))
quit(status = if (any(results == "FAIL")) 1 else 0)
