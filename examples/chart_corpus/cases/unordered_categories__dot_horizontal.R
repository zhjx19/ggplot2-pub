# rule: unordered_categories   variant: horizontal DOT plot (category on y)
#
# Two blind spots in one case: the rule used to look only at BAR layers, and
# only at the vertical orientation. A dot plot is the very chart this rule
# pushes people towards, and a horizontal one puts the category on y.
library(ggplot2)
d = data.frame(cat = c("a", "b", "c", "d"), v = c(30, 12, 22, 5))

bad  = function() ggplot(d, aes(v, cat)) + geom_point(size = 3)
good = function() ggplot(d, aes(v, fct_reorder(cat, v))) + geom_point(size = 3)

expect_bad = "WARN"
