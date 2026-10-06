# rule: smooth_small_groups   (step 2/4: few obs per group -> one overall trend)
# bad() uses the IMPLICIT grouping form -- `aes(colour = g)` with a plain
# geom_smooth() fits one line per group, which is how people actually write it.
# That form used to slip through (the rule only looked at an explicit `group`).
library(ggplot2)
d = data.frame(x = 1:8, y = c(1, 2, 3, 4, 2, 3, 4, 5), g = rep(c("A", "B"), 4))

bad  = function() ggplot(d, aes(x, y, colour = g)) +
  geom_smooth(method = "lm", formula = y ~ x, se = FALSE)
good = function() ggplot(d, aes(x, y, colour = g)) +
  geom_smooth(aes(group = 1), method = "lm", formula = y ~ x, se = FALSE)

expect_bad = "WARN"
