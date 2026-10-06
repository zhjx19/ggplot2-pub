# rule: const_in_aes   variant: the constant is parked in a variable first
#
# `red = "red"; aes(colour = red)` maps a constant and draws a pseudo guide,
# exactly like `aes(colour = "red")` -- but it used to slip through, because the
# check only looked for a LITERAL. The name must NOT be a column of the data,
# otherwise it is a legitimate column mapping (see good()).
library(ggplot2)
d = data.frame(x = 1:6, y = c(1, 3, 2, 5, 4, 6), g = rep(c("A", "B"), 3))
red = "red"

bad  = function() ggplot(d, aes(x, y, colour = red)) + geom_point()
good = function() ggplot(d, aes(x, y, colour = g)) + geom_point()

expect_bad = "FAIL"
