# chart_corpus — 图表规则的语料（每条规则一对：违规 / 合规）

`scripts/lint_plot.R` 是第 7 步「快检」的可执行版本（12 条机检 + 5 条必须人看）；这个目录是它的靶子。

## 为什么有它

ggplot2-pub 的规则原来全是**散文**——散文规则不会让构建失败，所以一条从没被断言的规则会
悄悄腐烂（中文导出处方就这样躺了很久）。这里把每条**可机检**的规则配一对用例：

- **违规例**：断言 linter **必须抓住**
- **合规例**：断言 linter **必须放行**

跑法：`Rscript --vanilla scripts/verify_charts.R`

**违规例没被抓住 = 规则没落地。** 这是 chart 侧的 `verify_snippets.R`。

## 用例

一个规则可以有**多个用例**：文件名写成 `规则名__变体.R`，`verify_charts.R` 会剥掉 `__`
后面的部分当规则名。所以同一规则可以在多种形状下被钉住，而不用编造假规则名。

| 文件（= 规则名，`__` 后为变体）| 对应 SKILL.md |
|---|---|
| `empty_layers` | 第 7 步：空 `ggplot()` 不该存在 |
| `const_in_aes` | 第 4 步：常量写在 `aes()` 外（伪图例）。**注意 `group = 1` 是推荐写法，不得误报** |
| `const_in_aes__in_variable` | 同上：常量先存进变量（`red = "red"; aes(colour = red)`）也是伪图例 |
| `legend_levels_gt6` | 第 5 步：>6 类改分面（`colour`/`fill`/`shape`/`linetype`/`size` 都算）|
| `legend_duplicates_axis` | 第 4/7 步：图例重复了坐标轴 |
| `legend_duplicates_axis__reordered_axis` | 同上：轴上走 `fct_reorder(cat, v)` 时也要认得出是同一个变量 |
| `label_duplicates_legend` | 第 4 步：末端/直接标签时图例多余 |
| `bar_y_not_zero` | 第 4 步：柱状图数值轴从 0 开始（`coord_flip()` 后数值轴在 x，不得误报）|
| `unordered_categories` | 第 2 步：字符型类别按值排序（factor 尊重既有顺序）|
| `unordered_categories__dot_horizontal` | 同上：点图与横向朝向同样要查；**分布图豁免**（类目轴是刻意的设计顺序）|
| `limits_drop_data` | 第 6 步：`xlim()/ylim()` 删数据 → 用 `coord_cartesian()`。**`limits = c(0, NA)` 不得误报** |
| `polar_or_dual_axis` | 第 7 步：禁饼图 / 3D / 双 Y 轴 |
| `transform_guard` | 第 2 步：`log/sqrt` 前查正值 |
| `smooth_small_groups` | 第 2/4 步：每组观测太少别分组拟合 |
| `categorical_scatter` | 第 7 步：点/线图层两个轴都是类目（没有任何连续维度）|

除了这些成对用例，`verify_charts.R` 还单独钉了三类**回归**：不得误报的合法写法
（`coord_flip` 柱状图）、必须豁免的写法（分布图的类目顺序）、以及「linter 永不抛异常」
（非常规输入、空图层）。

## 两条设计约定

1. **期望值内嵌在用例里**（`expect_bad = "FAIL"`），不另写 `expected.json`。
   这里和 data-cleaning 的 `messy_corpus` 不同：那边的数据是**生成**的，答案必须从生成结果
   推导才不会脱节；这里的用例是**手写**的违规图，期望值是规则本身的定义，内嵌最直接。
2. **不可机检的规则明确列出来**，不假装被覆盖。`verify_charts.R` 结尾会打印它们，
   单一真源是 `lint_plot.R` 里的 `human_only_rules`：
   `title_is_insight`（标题是否结论式）、`palette_harmony`（配色是否协调）、
   `labels_not_overlapping`（标签是否真没压在一起——`ggrepel` 的排布依赖画布尺寸）、
   `missing_impact_noted`（缺失数据有没有说明）、`colour_consistent_across_plots`（跨图配色是否一致）。
   这五条只能靠**打开图看**，就是第 7 步第 4 条。

## 加一条新规则时

1. 在 `scripts/lint_plot.R` 里加规则；
2. 在本目录加同名 `.R` 用例（违规 + 合规 + `expect_bad`）；同一规则要覆盖多种形状时，
   用 `规则名__变体.R` 再加几个；
3. 跑 `Rscript --vanilla scripts/verify_charts.R`——**元检查会因为你漏了第 2 步而失败**。
