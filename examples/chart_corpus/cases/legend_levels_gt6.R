# rule: legend_levels_gt6   (step 5: >6 levels -> facet, do not pile up a legend)
# bad() piles the levels onto `shape` -- the rule used to only look at
# colour/fill, so a shape legend with 9 levels slipped through.
library(ggplot2)
d9 = data.frame(x = 1:9, g = letters[1:9])
d5 = data.frame(x = 1:10, g = rep(letters[1:5], 2))

bad  = function() ggplot(d9, aes(x, x, shape = g)) + geom_point()
good = function() ggplot(d5, aes(x, x)) + geom_point() + facet_wrap(~ g)

expect_bad = "WARN"
