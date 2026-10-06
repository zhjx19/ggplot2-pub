# rule: label_duplicates_legend   (step 4: end labels make the legend redundant)
library(ggplot2)
d = data.frame(x = 1:6, v = c(3, 1, 4, 1, 5, 9), g = rep(c("A", "B", "C"), 2))

bad  = function() ggplot(d, aes(x, v, colour = g)) +
  geom_point() + geom_text(aes(label = g))
good = function() ggplot(d, aes(x, v, colour = g)) +
  geom_point() + geom_text(aes(label = v), show.legend = FALSE)

expect_bad = "WARN"
