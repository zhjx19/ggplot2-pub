# rule: unordered_categories   (step 2: character categories sorted by value)
# note: factors are respected as-is -- only CHARACTER axes are flagged
library(ggplot2)
library(forcats)
d = data.frame(x = c("a", "b", "c"), v = c(3, 1, 2))

bad  = function() ggplot(d, aes(x, v)) + geom_col()
good = function() ggplot(d, aes(fct_reorder(x, v), v)) + geom_col()

expect_bad = "WARN"
