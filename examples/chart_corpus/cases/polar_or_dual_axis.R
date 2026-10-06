# rule: polar_or_dual_axis   (step 7: no pie / 3D / dual axis)
library(ggplot2)
d = data.frame(x = c("a", "b", "c"), v = c(3, 1, 2))

bad  = function() ggplot(d, aes(x, v, fill = x)) + geom_col() + coord_polar()
good = function() ggplot(d, aes(x, v)) + geom_col()

expect_bad = "FAIL"
