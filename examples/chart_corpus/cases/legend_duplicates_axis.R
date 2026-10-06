# rule: legend_duplicates_axis   (step 4/7: colour mapping that repeats the axis)
library(ggplot2)
d = data.frame(x = c("a", "b", "c"), v = c(3, 1, 2), g = c("A", "A", "B"))

bad  = function() ggplot(d, aes(x, v, colour = x)) + geom_col()
good = function() ggplot(d, aes(x, v, colour = g)) + geom_col()

expect_bad = "WARN"
