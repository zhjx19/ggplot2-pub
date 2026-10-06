# rule: const_in_aes   (step 4: constants go OUTSIDE aes(), else a pseudo guide)
# note: `group = 1` is the RECOMMENDED way to collapse grouping -- it must not trip this
library(ggplot2)
d = data.frame(x = 1:5, y = (1:5)^2, g = rep(c("A", "B"), length.out = 5))

bad  = function() ggplot(d, aes(x, y)) + geom_point(aes(color = "steelblue"))
good = function() ggplot(d, aes(x, y)) + geom_point(color = "steelblue")

expect_bad = "FAIL"
