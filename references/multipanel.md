# 多面板决策（multipanel）

> SKILL.md 第 2/6 步的深料。设计参考 plotthis 的 split_by/facet_by 决策表与
> ggauto 的分面高亮模式；所有代码在本技能验证环境（R 4.6.1 / ggplot2 4.0.3）跑通。

## 先决策：分面还是拆分拼合？

| 场景 | 用什么 |
|---|---|
| 面板间共享刻度、同一图型、只是按类别分开看 | **`facet_wrap()` / `facet_grid()`**（首选，更高效） |
| 每个面板要**独立色板/图例/坐标轴**，或面板图型不同 | **拆成独立 ggplot 对象 + `patchwork` 拼合** |
| 图型不是 ggplot 对象（如 pheatmap 系热图） | 只能拆分拼合 |
| 既要分组又要组内分面 | 拆分拼合后，每个拼块内部再分面 |

拼合时收集图例避免重复：`p1 + p2 + patchwork::plot_layout(guides = "collect") & theme(legend.position = "bottom")`

## >6 组折线：分面 + 每面板高亮本组

不用在面板里堆六种以上颜色：所有线画一遍浅灰，每面板只高亮本面板的类别。

**默认做法（零额外依赖，已验证）**：灰背景线 + 末端直接标签——
不要再往面板里塞颜色，末端标签就是"每面板高亮"的替代：

```r
end_pts = df |> group_by(city) |> slice_max(date, n = 1)
ggplot(df, aes(date, sales, group = city)) +
  geom_line(colour = "grey80") +
  ggrepel::geom_text_repel(data = end_pts,
    aes(label = city, x = date + 30), direction = "y", min.segment.length = 0)
```

**可选增强**（装了 gghighlight 才用，不推荐为它专门装包）：

```r
ggplot(df, aes(date, sales)) +
  geom_line(linewidth = 0.4) +
  gghighlight::gghighlight(use_direct_label = FALSE) +
  facet_wrap(~city)
```

## 分面顺序有讲究

- 类别面板按**值**排（默认继承数据的 factor 顺序）。
- 折线图按**各序列末端值**排名排面板——读者从左到右看到的就是从差到好：

```r
end = df |> group_by(city) |> slice_max(date, n = 1) |> arrange(sales)
df = df |> mutate(city = factor(city, levels = end$city))
```

## 尺寸估算（避免惯性 10×6）

导出宽高按内容估，不要所有图都一个尺寸（plotthis 的思路，边界 3–12 英寸）：

- 类别数驱动的轴：每类约 0.4–0.6 英寸（横向柱状图的高度 ≈ `0.5 × n + 1`）
- 分面：行数每加一行加一个面板高度；条带文字 >15 字符时加高条带
- 长图例放底部时高度 +0.5 英寸；左右并排多图按面板数加宽

```r
n = length(unique(df$city))
h = min(12, max(3, 0.5 * n + 1))
ggsave("plot.png", p, width = 8, height = h, dpi = 300, bg = "white")
```

## 相关规则

- 同一类别跨面板/跨图颜色一致：见 `palettes.md` 的全局色板映射。
- 每面板高亮后仍要遵守"图例级别 >6 改分面"的快检（SKILL.md 第 7 步）。
