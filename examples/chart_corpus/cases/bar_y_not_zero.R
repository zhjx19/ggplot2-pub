# rule: bar_y_not_zero   (step 4: a bar chart's value axis must start at zero)
library(ggplot2)
d = data.frame(x = c("a", "b", "c"), v = c(3, 4, 5))

bad  = function() ggplot(d, aes(x, v)) + geom_col() + ylim(1, 5)
good = function() ggplot(d, aes(x, v)) + geom_col()

expect_bad = "FAIL"
