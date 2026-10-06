# rule: empty_layers   (SKILL.md step 7: a plot must have layers)
library(ggplot2)
d = data.frame(x = 1:5, y = (1:5)^2)

bad  = function() ggplot(d, aes(x, y))
good = function() ggplot(d, aes(x, y)) + geom_point()

expect_bad = "FAIL"
