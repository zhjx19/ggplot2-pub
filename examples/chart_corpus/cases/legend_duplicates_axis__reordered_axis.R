# rule: legend_duplicates_axis   variant: the axis variable arrives through a call
#
# This rule's own recommended fix is inline -- aes(fct_reorder(cat, value), value)
# -- so the same variable reaches the axis wrapped in a call. Comparing raw
# expressions could not see through the wrapper and missed the duplication;
# comparing the UNDERLYING variable (mapped_var) catches it.
library(ggplot2)
d = data.frame(cat = c("a", "b", "c", "d"), v = c(4, 1, 3, 2))

bad  = function() ggplot(d, aes(fct_reorder(cat, v), v, colour = cat)) + geom_point()
good = function() ggplot(d, aes(fct_reorder(cat, v), v, colour = cat)) +
  geom_point() + theme(legend.position = "none")

expect_bad = "WARN"
