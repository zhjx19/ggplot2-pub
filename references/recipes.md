# 出版统计标注与图型配方（recipes）

> SKILL.md 第 4/6 步的深料：误差条/置信区间、显著性标注、坐标变换、热图。
> 全部配方零额外依赖（ggplot2 + dplyr + scales），且在本技能验证环境
> （R 4.6.1 / ggplot2 4.0.3）渲染通过。含中文标签时遵循第 6 步导出防线。

## 误差条 / 置信区间（出版刚需）

先聚合出均值与误差，再叠加。**误差棒宽度显式给**（`width = 0.15`），别用默认：

```r
summ = df |>
  group_by(group) |>
  summarise(mean = mean(y), se = sd(y) / sqrt(n()), .groups = "drop") |>
  mutate(lo = mean - 1.96 * se, hi = mean + 1.96 * se)   # 95% CI

ggplot(summ, aes(group, mean, fill = group)) +
  geom_col(width = 0.7, color = NA) +
  geom_errorbar(aes(ymin = lo, ymax = hi), width = 0.15, linewidth = 0.4)
```

- 论文更推荐的形态是 **pointrange**（点 + 区间，不画柱），阅读误差更直接：
  `ggplot(summ, aes(group, mean)) + geom_pointrange(aes(ymin = lo, ymax = hi))`
- 样本量 `n()` 计入的是去掉 `NA` 后的有效样本：先 `filter(!is.na(y))` 或在
  `summarise` 里用 `sum(!is.na(y))`，别拿含 NA 的 n 除。
- n < 30 时报精确 t 分位（`qt(0.975, n - 1)`）而不是 1.96。
- 柱状 + 误差条时柱底必须从 0 开始（铁律），否则改用 pointrange。

## 显著性标注（零依赖手写括号）

`ggsignif`/`ggpubr` 不必装——两行 `geom_path + annotate` 就是出版级括号：

```r
ymax = max(summ$hi)                                   # 比最高误差棒再高一截
brk = data.frame(x = c(1, 1, 3, 3),                   # x 取两组的列位置
                 y = c(ymax, ymax * 1.06, ymax * 1.06, ymax))
ggplot(summ, aes(group, mean, fill = group)) +
  geom_col(width = 0.7, color = NA) +
  geom_errorbar(aes(ymin = lo, ymax = hi), width = 0.15, linewidth = 0.4) +
  geom_path(data = brk, aes(x, y), inherit.aes = FALSE, linewidth = 0.4) +
  annotate("text", x = 2, y = ymax * 1.075, label = "*** (p < 0.001)", size = 3.5) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +   # 顶部留出括号空间
  ...
```

- `inherit.aes = FALSE` 必须加，否则括号会继承填色映射。
- y 轴 `expand` 上限留 15% 给括号与星号，避免出界。
- p 值写法遵照目标期刊；标 `ns` 也比不标好。

## 坐标变换

```r
# 对数轴（跨度跨数量级时）：
scale_y_log10(labels = label_comma())
# 数据含 0/负值时不要 log10，先想清楚语义，或用 symlog 语义的 scale_y_continuous +
# 变换说明；变换守卫（第 2 步）先过一遍。

# 日期轴（时间 vs 连续）：
scale_x_date(date_breaks = "2 months", date_labels = "%Y-%m")
```

- `date_labels` 用 `%Y-%m`/`%b` 这类简洁格式；默认的长日期轴是出版大忌。
- 对数轴上的数据必须严格为正（第 2 步变换守卫）。

## 热图（geom_tile 零依赖配方）

```r
m = as.matrix(宽表)                       # 行=观测，列=变量
ord_r = hclust(dist(m))$order             # 行聚类排序（base stats，零依赖）
ord_c = hclust(dist(t(m)))$order
hm = as.data.frame(as.table(m)); names(hm) = c("row", "col", "z")
hm$row = factor(hm$row, levels = rownames(m)[ord_r])
hm$col = factor(hm$col, levels = colnames(m)[ord_c])

ggplot(hm, aes(col, row, fill = z)) +
  geom_tile(color = "white", linewidth = 0.4) +
  scale_fill_viridis_c() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
```

- 连续色标用 viridis（内置、感知均匀、色盲安全）。
- 聚类排序让相似行列相邻；**排序必须由数据驱动**（hclust），不要手工拖。
- 格子数 > 5000 时热图不是好选择，先聚合或换 `geom_bin2d()`。

## SVG 导出

中文 SVG 两个写法都实测正常：`ggsave("p.svg")`（装了 svglite 时自动用）与
`ggsave("p.svg", device = svg)`（base grDevices，零依赖）。SVG 是文本格式，
交付前用文本编辑器抽一眼 `<text>` 内容确认中文完整。
