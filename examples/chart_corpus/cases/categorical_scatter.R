# rule: categorical_scatter   (step 7 quick check: a continuous geom needs a
# continuous dimension -- both axes categorical is the antipattern)
# note: a dot plot with ONE categorical axis is legitimate and must NOT trip this
library(ggplot2)
d = data.frame(a = c("x", "y", "z"), b = c("p", "q", "r"), v = c(3, 1, 2))

bad  = function() ggplot(d, aes(a, b)) + geom_point()
good = function() ggplot(d, aes(v, a)) + geom_point()

expect_bad = "FAIL"
