# rule: limits_drop_data   (step 6: xlim()/ylim() delete rows; coord_cartesian zooms)
# note: `limits = c(0, NA)` is legitimate and must NOT trip this
library(ggplot2)
d = data.frame(x = c("a", "b", "c"), v = c(3, 1, 2))

bad  = function() ggplot(d, aes(x, v)) + geom_point() + xlim("a", "b")
good = function() ggplot(d, aes(x, v)) + geom_point() + coord_cartesian(xlim = c(1, 2))

expect_bad = "FAIL"
