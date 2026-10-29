# rule: redundant_colour_with_facet   (step 4: the facet strip already names the category)
library(ggplot2)
d = data.frame(
  g = rep(c("A", "B"), each = 3),
  x = 1:6,
  y = c(2, 4, 3, 5, 6, 4)
)

# colour repeats the facet variable -> same thing said twice, plus a legend column
bad  = function() ggplot(d, aes(x, y, colour = g)) + geom_point() + facet_wrap(~g)
# one colour for all panels -> the strip does the labelling
good = function() ggplot(d, aes(x, y)) + geom_point() + facet_wrap(~g)

expect_bad = "WARN"
