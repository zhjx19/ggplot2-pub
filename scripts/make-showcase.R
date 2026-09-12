# make-showcase.R -- render assets/before.png and assets/after.png
# before = what a naive default ggplot call produces from the same data (unretouched)
# after  = what ggplot2-pub rules produce
# ASCII-only source with \u escapes (locale-proof). Run from anywhere:
#   Rscript scripts/make-showcase.R
# Optional: set SHOWCASE_DIR to redirect output.

suppressPackageStartupMessages({
  library(ggplot2); library(dplyr); library(forcats); library(scales)
})

# locate assets/ from this script's path: <skill root>/scripts/make-showcase.R
fa <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(fa)) {
  script_dir <- dirname(normalizePath(sub("^--file=", "", fa), winslash = "/"))
  root <- dirname(script_dir)
} else {
  root <- getwd()
}
assets <- Sys.getenv("SHOWCASE_DIR", file.path(root, "assets"))
dir.create(assets, showWarnings = FALSE, recursive = TRUE)
cat("output dir:", assets, "\n")

te_paper  <- "#f5f4ee"; te_ink <- "#16241d"; te_body <- "#2c3a31"
te_rust <- "#b5534e"; te_line <- "#dad9ca"

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

CN <- list(
  base  = "\u57fa\u7ebf\u7ec4",   # baseline group
  ca    = "\u5bf9\u7167A",        # control A
  cb    = "\u5bf9\u7167B",        # control B
  focus = "\u76ee\u6807\u7ec4",   # focus group
  alt   = "\u5907\u9009\u7ec4",   # alternate group
  title = "\u76ee\u6807\u7ec4\u663e\u8457\u9ad8\u4e8e\u5176\u4ed6\u7ec4",      # insight title
  sub   = "\u67f1\u957f\u8868\u793a\u5404\u7ec4\u5e73\u5747\u5f97\u5206",      # subtitle
  x     = "\u5e73\u5747\u5f97\u5206",                                          # x axis label
  cap   = "\u6570\u636e\u6765\u6e90\uff1a\u9879\u76ee\u6570\u636e",            # caption
  ylab  = "\u5e73\u5747\u5f97\u5206"                                           # (same as x)
)

set.seed(1)
df <- data.frame(
  group = rep(c(CN$base, CN$ca, CN$cb, CN$focus, CN$alt), each = 40),
  score = c(rnorm(40, 50, 8), rnorm(40, 52, 8), rnorm(40, 51, 8),
            rnorm(40, 65, 8), rnorm(40, 49, 8))
)

# -- BEFORE: the naive default. One line of thought, zero deliberate choices. --
before_data <- df |>
  summarise(value = mean(score), .by = group)   # aggregated, but unsorted & no highlight field

p_before <- ggplot(before_data, aes(x = group, y = value, fill = group)) +
  geom_col() +
  labs(title = "Mean score by group")           # default theme, default palette, legend, centered title

# -- AFTER: ggplot2-pub rules applied. --
after_data <- df |>
  summarise(value = mean(score, na.rm = TRUE), .by = group) |>
  mutate(group = fct_reorder(group, value), is_focus = group == CN$focus)

p_after <- ggplot(after_data, aes(x = value, y = group, fill = is_focus)) +
  geom_col(width = 0.7, color = NA) +
  scale_x_continuous(labels = scales::comma) +
  scale_fill_manual(values = c(`TRUE` = te_rust, `FALSE` = "#BDBDBD"), guide = "none") +
  labs(title = CN$title, subtitle = CN$sub, x = CN$x, y = NULL, caption = CN$cap) +
  theme_pub()

ggsave(file.path(assets, "before.png"), p_before, width = 8, height = 5, dpi = 150, bg = "white")
ggsave(file.path(assets, "after.png"),  p_after,  width = 8, height = 5, dpi = 150, bg = te_paper)
cat(sprintf("rendered: %s (%.1f KB), %s (%.1f KB)\n",
            file.path(assets, "before.png"), file.size(file.path(assets, "before.png")) / 1024,
            file.path(assets, "after.png"),  file.size(file.path(assets, "after.png")) / 1024))
