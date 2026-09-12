---
name: ggplot2-rule
description: >-
  ggplot2 出版级可视化规范。生成或改写 R 图表时激活：先整理数据再作图，
  克制配色、高数据墨水比、左对齐标题、直接标签、避免 3D/双轴/饼图，
  使用 ggrepel / ggtext / patchwork / scico 等提升可读性。
globs:
  - "**/*.R"
  - "**/*.qmd"
  - "**/*.Rmd"
regex: "ggplot|geom_|aes\\(|theme_|ggsave|facet_|patchwork|ggrepel|ggtext|ggdist|scico|MetBrewer|khroma|element_textbox|stat_halfeye|coord_cartesian|scale_"
alwaysApply: false
version: 1.2
---

# ggplot2 出版级可视化规范

> **核心理念**：图表是结论表达，不是装饰。先把数据整理成适合绘图的 tidy 数据，再进入 `ggplot()`。  
> **风格目标**：克制、清晰、高数据墨水比、可复现、适合报告与论文。

## 1. 作图前数据原则

- 聚合、排序、标签字段、高亮字段应在 `ggplot()` 前用 dplyr 完成。
- 不在 `aes()` 内写复杂清洗逻辑。
- 图中每个颜色、大小、标签都必须服务于一个明确问题。

```r
plot_data = df |>
  summarise(value = mean(score, na.rm = TRUE), .by = group) |>
  mutate(
    group = fct_reorder(group, value),
    is_focus = group == "目标组"
  )
```

## 2. 美学与排版铁律

| 原则 | 要求 |
|---|---|
| 高数据墨水比 | 去除多余边框、背景、次要网格线 |
| 克制配色 | 非重点灰色，重点强调色；避免彩虹色 |
| 避免纯黑 | 文本/轴线用 `grey20` 或 `#2C3E50` |
| 左对齐 | 标题、副标题、注脚、图例标题优先左对齐 |
| 直接表达结论 | 标题说洞察，副标题说背景，注脚说数据来源 |
| 标签不重叠 | 文本标注优先 `ggrepel` |

推荐基础主题：

```r
base_theme = theme_minimal(base_size = 14, base_family = "sans") +
  theme(
    plot.title.position = "plot",
    plot.title = ggtext::element_textbox_simple(
      face = "bold", size = 16, hjust = 0,
      margin = margin(b = 8)
    ),
    plot.subtitle = ggtext::element_textbox_simple(
      color = "grey40", size = 12, hjust = 0,
      margin = margin(b = 16)
    ),
    plot.caption = element_text(color = "grey60", size = 9, hjust = 0),
    panel.grid.minor = element_blank(),
    plot.margin = margin(18, 18, 18, 18)
  )
```

## 3. 图表选择矩阵

| 数据关系 | 首选图表 | 注意 |
|---|---|---|
| 单个连续变量分布 | `ggdist::stat_halfeye()` / 直方图 / 密度图 | 样本点可轻微 jitter |
| 连续 vs 连续 | `geom_point()` + `geom_smooth()` | 大样本用透明度或 `geom_bin2d()` |
| 离散 vs 连续 | `geom_col()` / boxplot / halfeye | 类别按值排序 |
| 时间 vs 连续 | `geom_line()` | 折线末端可直接标签 |
| 两个类别变量 | 堆叠/分组柱或热图 | 百分比需标明分母 |
| 多组趋势 | 小于等于 6 组可上色；超过 6 组必须分面 | 避免意大利面条图 |

禁止默认使用：饼图、3D 图、双 Y 轴、无意义渐变色。

## 4. 几何对象微调

| 目的 | 推荐写法 | 细节 |
|---|---|---|
| 散点 | `geom_point(alpha = 0.75, size = 2)` | 常量颜色写在 `aes()` 外 |
| 大量点 | `geom_bin2d()` / `geom_hex()` | >5000 点不要硬画所有点 |
| 柱状 | `geom_col(width = 0.7, color = NA)` | Y 轴必须从 0 开始 |
| 分布 | `ggdist::stat_halfeye()` | boxplot 隐藏离群点时需说明 |
| 标签 | `ggrepel::geom_text_repel()` | 禁止标签重叠 |
| 多图 | `patchwork` | 禁止默认用 `gridExtra` / `cowplot` |

常量映射规则：

```r
# 错误：常量放进 aes 会生成伪图例
geom_point(aes(color = "steelblue"))

# 正确
geom_point(color = "steelblue")
```

## 5. 配色规范

| 场景 | 推荐方案 |
|---|---|
| 连续变量 | `scico`：`batlow`, `oslo`, `roma`；或 `viridis` |
| 离散类别 | `MetBrewer` / `khroma` / Paul Tol 色板 |
| 高亮重点 | 中性灰 + 单一强调色 |
| 品牌报告 | 使用给定 HEX，但检查对比度与色盲友好 |

- 避免默认彩虹色。
- 类别超过 6 个优先分面，不要继续堆颜色。
- 颜色含义必须在图例、标题或注释中可理解。

## 6. 坐标、排序与比例

- 局部放大用 `coord_cartesian()`，禁止用 `xlim()` / `ylim()` 截断数据后再统计。
- 柱状图 Y 轴必须从 0 开始。
- 类别轴按数值或业务逻辑排序，禁止默认字母序。
- 比例、金额、千分位使用 `scales::percent()`、`comma()`、`dollar()`。
- 横向柱状图通常更适合长类别标签。

```r
p = ggplot(plot_data, aes(x = value, y = group, fill = is_focus)) +
  geom_col(width = 0.7, color = NA) +
  scale_x_continuous(labels = scales::comma) +
  scale_fill_manual(values = c(`TRUE` = "#D55E00", `FALSE` = "#BDBDBD"), guide = "none") +
  labs(
    title = "目标组显著高于其他组",
    subtitle = "柱长表示各组平均得分",
    x = "平均得分", y = NULL,
    caption = "数据来源：项目数据"
  ) +
  base_theme
```

## 7. 图例与标注

- 能直接标注就不要图例，尤其是少数折线。
- 折线终点标签优先 `ggrepel::geom_text_repel()`。
- 图例放在不干扰数据的位置；必要时放底部。
- 注释只解释关键变化，不要把图变成文字墙。

## 8. 导出规范

```r
ggsave(
  "figures/plot.png",
  plot = p,
  width = 10,
  height = 6,
  dpi = 300,
  bg = "white"
)
```

- PNG 用于报告预览；PDF/SVG 用于矢量出版。
- 明确 `width`、`height`、`dpi`、`bg`。
- 深色编辑器/幻灯片环境下必须设 `bg = "white"`，避免透明背景导致不可读。

## 9. 致命反模式

| 错误做法 | 专业做法 |
|---|---|
| 饼图比较多个类别 | 排序柱状图或点图 |
| 3D 柱状图 | 2D 图，必要时分面 |
| 双 Y 轴 | 分面、标准化、或拆成两图 |
| 默认彩虹色 | 感知均匀或低饱和色板 |
| 文本标签互相覆盖 | `ggrepel` 或减少标签 |
| 类别太多仍用颜色 | 分面或筛选重点类别 |
| `aes(color = "red")` | `geom_*(color = "red")` |
| 用 `xlim()/ylim()` 放大 | `coord_cartesian()` |
| 柱状图不从 0 开始 | 从 0 开始或换点图 |

## 10. AI 自检清单

- [ ] 数据是否已在 ggplot 前整理好？
- [ ] 图表类型是否匹配变量关系？
- [ ] 是否避免饼图、3D、双轴、彩虹色？
- [ ] 类别是否合理排序？
- [ ] 颜色是否克制且服务于重点？
- [ ] 标签是否不重叠？
- [ ] 坐标放大是否用 `coord_cartesian()`？
- [ ] 导出是否指定尺寸、dpi、白色背景？
