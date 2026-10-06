# rule: transform_guard   (step 2: check non-positive before log/sqrt)
library(ggplot2)
d_bad  = data.frame(x = 1:4, y = c(0, 1, 2, 3))
d_good = data.frame(x = 1:4, y = c(1, 2, 3, 4))

bad  = function() ggplot(d_bad, aes(x, y)) + geom_point() + scale_y_log10()
good = function() ggplot(d_good, aes(x, y)) + geom_point() + scale_y_log10()

expect_bad = "FAIL"
