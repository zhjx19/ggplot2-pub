---
name: ggplot2-pub
description: |
  出版级 ggplot2 图表：在 R 中生成、修复或审查达到论文/报告出版标准的统计图。
  当用户要求画图、作图、出图、生成图表、论文 figure、按审稿意见改图（字太小/标签重叠/配色乱）、
  或用 ggsave 导出图片时使用。触发词：ggplot、geom、aes、theme、R 可视化、bar chart、
  line plot、publication figure、出版级、画图、作图、图不太好看。
  不要用于：Python（matplotlib/plotnine/seaborn）图表、交互式图表（plotly/bokeh）、
  纯数据清洗、仪表盘开发。
license: MIT
metadata:
  # 注意：metadata 值必须保持单行引号字符串——部分 skill CLI 的 YAML 解析器不接受多行裸标量
  version: "2.6"
  source: "重写自 05-ggplot2-rule.v1.2（Cursor rule）；v2.1 融合 ggauto/plotthis/ggnext 三包提炼；v2.3 默认主题与配色采用 tidyecology.com datasheet 风（用户指定）；v2.4 中文导出处方补全（设备 + 字体两步）、冒烟测试改为真验字形；v2.5 补末端标签去图例、小样本别分组拟合；v2.6 快检变可执行 linter + 图表语料回归"
  baseline: "references/baseline-v1.2-cursor-rule.md"
  verified: "R 4.6.1 / ggplot2 4.0.3 / dplyr 1.2.1 / Windows 11 实测通过（scripts/smoke-cjk.R）"
---

# ggplot2-pub：出版级 ggplot2 作图

**核心理念**：图表是结论表达，不是装饰。先把数据整理成适合绘图的 tidy 数据，再进 `ggplot()`。
**风格目标**：克制、高数据墨水比、可复现，适合报告与论文。

## 工作流（按序执行，勿跳步）

### 第 0 步：环境与依赖自检

```r
core = c("ggplot2", "dplyr", "forcats", "scales")
missing = core[!core %in% rownames(installed.packages())]
if (length(missing)) install.packages(missing)
```

- 推荐增强包缺失时**不阻塞**，按「依赖与降级」表换方案，不要现场强行装包。
- 图中含中文时，第 6 步的导出防线与第 7 步的渲染验收**不可省**
  （历史事故：locale 异常时中文乱码、富文本管线崩溃产出**空白图**，
  且报错信息完全看不出是编码问题）。

### 第 1 步：先把数据整理成可画的样子

- 聚合、排序、标签字段、高亮字段在 `ggplot()` 之前用 dplyr 完成；不在 `aes()` 内写清洗逻辑。
- 图中每个颜色、大小、标签都必须服务于一个明确问题。

```r
plot_data = df |>
  summarise(value = mean(score, na.rm = TRUE), .by = group) |>
  mutate(
    group = fct_reorder(group, value),
    is_focus = group == "目标组"   # 高亮字段在数据里预先算好
  )
```

### 第 2 步：选对图表类型

先按变量类型走判定，再查矩阵。三条守卫（均实测）：

- **重复测量守卫**：离散 + 连续，但每个类别有多个观测（`max(table(x)) > 1`）→
  画分布（halfeye/箱线），不要汇总成柱状丢掉波动信息；确要汇总必须先向用户说明。
- **汇总守卫**：两个离散 + 一个连续，且每格多于一个值 → 必须先 `summarise()`，
  热图/柱状每格只允许一个值，禁止把原始值硬塞进 geom。
- **变换守卫**：连续值做 `sqrt()/log()` 前先检查非负/为正，不满足就换刻度而非改数据。

| 数据关系 | 首选 | 注意 |
|---|---|---|
| 单个连续变量分布 | 直方图 / 密度（零依赖）；`ggdist::stat_halfeye()` 装了更佳 | 样本点可轻微 jitter |
| 连续 vs 连续 | `geom_point()` + `geom_smooth()` | 大样本用透明度或 `geom_bin2d()`；**分组拟合前先看每组观测数**——每组很少（如 <10）时不要分组各拟合一条，那是过度解读，改画一条总体趋势或只画点 |
| 离散 vs 连续 | `geom_col()` / boxplot / halfeye | 类别按值排序（见下） |
| 时间 vs 连续 | `geom_line()` | 折线末端可直接标签；**用了末端标签就去掉图例**（`legend.position = "none"`），别两样都留 |
| 两个类别变量 | 堆叠/分组柱或热图 | 百分比需标明分母 |
| 多组趋势 | ≤6 组可上色；超过必须分面，每面板高亮本组 | 见 `references/multipanel.md`；避免意大利面条图 |

排序细则：字符型类别用 `fct_reorder(x, value)` 按值排；**factor 尊重既有水平顺序**，
改动 factor 顺序必须说明理由。

### 第 3 步：主题一律用 `theme_pub()`（tidyecology datasheet 风默认）

配色与主题常量（来源 [tidyecology.com](https://tidyecology.com/)，经用户指定为默认）：

```r
te_paper  = "#f5f4ee"; te_ink   = "#16241d"; te_body = "#2c3a31"
te_forest = "#275139"; te_rust  = "#b5534e"; te_gold = "#c9b458"; te_line = "#dad9ca"

theme_pub = function(base_size = 12, base_family = "sans") {
  theme_minimal(base_size = base_size, base_family = base_family) +
    theme(
      plot.background  = element_rect(fill = te_paper, colour = NA),
      panel.background = element_rect(fill = te_paper, colour = NA),
      panel.grid.major = element_line(colour = te_line, linewidth = 0.3),
      panel.grid.minor = element_blank(),
      plot.title.position = "plot",
      plot.title    = element_text(colour = te_ink, face = "bold", size = base_size + 2,
                                   hjust = 0, margin = margin(b = 6)),
      plot.subtitle = element_text(colour = te_body, size = base_size - 1,
                                   hjust = 0, margin = margin(b = 12)),
      plot.caption  = element_text(colour = "#7d8a80", size = base_size - 4, hjust = 0),
      text          = element_text(colour = te_body),
      axis.text     = element_text(colour = te_body),
      plot.margin   = margin(18, 18, 18, 18)
    )
}
```

- 标题说洞察，副标题说背景，注脚说数据来源；三者一律左对齐。
- 文本用主题墨色（`te_ink`/`te_body`），不引入新的纯黑文字。
- `ggsave` 的 `bg` 与主题背景一致：theme_pub 图导出时 `bg = "#f5f4ee"`（暗色环境防透明规则不变）。
- **禁用 ggtext textbox 主题元素**（`element_textbox_simple`）承载标题副标题。实测两大问题：
  （a）legacy locale 下中文被读成乱码后，会在 markdown 渲染管线里拼出伪 HTML 标签，
  使 `ggsave()` 直接报错并产出**空白图**；
  （b）ggplot2 ≥4.0 中 textbox 元素无法用 `+ theme()` 覆盖，会把主题锁死。
  需要富文本时只在单个 geom 标签上用 `ggtext::element_markdown()`，标题副标题保持纯文本。

### 第 4 步：几何与标注微调

| 目的 | 推荐写法 | 细节 |
|---|---|---|
| 散点 | `geom_point(alpha = 0.75, size = 2)` | 常量颜色写在 `aes()` 外 |
| 大量点 | `geom_bin2d()` / `geom_hex()` | >5000 点不要硬画所有点 |
| 柱状 | `geom_col(width = 0.7, color = NA)` | Y 轴必须从 0 开始 |
| 分布 | `ggdist::stat_halfeye()`（增强） | boxplot 隐藏离群点时需说明 |
| 误差条/CI | `geom_errorbar(width = 0.15)` / `geom_pointrange()` | 先聚合算 SE/CI，配方见 `references/recipes.md` |
| 显著性标注 | 手写括号：`geom_path + annotate` | 零依赖配方见 `references/recipes.md`，不必装 ggsignif |
| 标签 | `ggrepel::geom_text_repel()` | 禁止标签重叠；用末端/直接标签时同步 `theme(legend.position = "none")`——图例与标签重复是"业余感"的常见来源 |
| 趋势线 | `geom_smooth(method = "lm", se = FALSE)` | 先看每组观测数：每组 <10 时只画一条总体（`aes(group = 1)`），别分组拟合 |
| 多图 | `patchwork` | `gridExtra`/`cowplot` 仅作降级 |

```r
# 错：常量进 aes 生成伪图例
geom_point(aes(color = "steelblue"))
# 对：常量写在 aes() 外
geom_point(color = "steelblue")
```

### 第 5 步：配色（零依赖优先，不推荐用户装冷门色板包）

| 场景 | 首选（零依赖/内置） | 备选 |
|---|---|---|
| 离散 ≤3 类 | 主题三色：森林 `#275139` / 锈红 `#b5534e` / 金 `#c9b458` | 用户品牌色 |
| 离散 >3 类 | Okabe-Ito 固定 HEX（查 `references/palettes.md`） | `RColorBrewer`（随 R 预装） |
| 连续变量 | `scale_fill_viridis_c()`（内置，感知均匀、色盲安全） | scico/MetBrewer 仅当用户点名 |
| 高亮重点 | 中性灰 `#BDBDBD` + 锈红 `#b5534e` | 灰 + 朱红 `#D55E00` |
| 品牌/期刊 | 给定 HEX，先过色盲自检（`references/palettes.md`） | — |

- 类别超过 6 个优先分面，不要继续堆颜色；禁止默认彩虹色。
- 颜色含义必须能从图例、标题或注释中读懂。
- 已知软提醒：锈红/金在红绿色盲下色相塌缩（cd≈0.004），靠亮度差 0.29 区分——
  灰度打印、粗线条叠加场景谨慎（`cvd_check()` 可复核）。
- 同一类别跨图同色（规则见 `references/palettes.md`）。
- 完整 HEX 色板与零依赖色盲自检：按需读 `references/palettes.md`。

### 第 6 步：导出（中文环境防线在此）

```r
ggsave("figures/plot.png", plot = p,
       width = 10, height = 6, dpi = 300, bg = "white")
```

- 必须显式 `width`、`height`、`dpi`、`bg`；`bg` 与主题背景一致——theme_pub 图用
  `bg = "#f5f4ee"`（深色编辑器/幻灯片环境下透明背景会不可读）。
- 报告预览用 PNG；论文投稿用 PDF/SVG 矢量。**中文图导出就两件事：设备对 + 字体有中文字形**，
  缺一件就废：
  - **设备**（选一）：`device = cairo_pdf`（矢量、文字可选中，投稿首选）｜
    `sysfonts::font_add()` + `showtext::showtext_auto()`（文字转轮廓，PDF 抽不出文本）｜
    `ragg::agg_png`（位图，零配置，但不能当投稿矢量）；
  - **字体**（不能省）：`theme_pub(base_family = "<中文字体>")`——走 showtext 则由 `font_add()` 注册。
    省了它，字体族落到 `sans`，在 Windows 上就是 Arial，**没有中文字形**。
- 只做设备那一步会看到的两种残局：默认 `pdf()` → **点号**（静默，文件照常生成；警告数与图里汉字数
  成正比，实测 61 条）；`cairo_pdf` 不指定字体 → **方块**（字体表里内嵌的是 ArialMT 子集，而文字层
  抽取却正常，所以只有打开看才发现）。
- 中文 PDF 会明显变大（实测 7～10 倍）。SVG 两写法实测中文正常：默认设备（有 svglite 时）
  或 `device = svg`（零依赖）。
- 数据跨零（有正有负）时加灰色零线，让正负一眼可分：
  `if (min(v) <= 0 && max(v) >= 0) p = p + geom_hline(yintercept = 0, colour = "grey", linewidth = 0.8)`
- 跨数量级用 `scale_y_log10()`；日期轴用 `scale_x_date(date_breaks = "2 months", date_labels = "%Y-%m")`——
  配方与注意事项见 `references/recipes.md`。
- 放大坐标用 `coord_cartesian(xlim = ...)`，**禁止** `xlim()/ylim()` 截断后再统计。
- 金额/百分比/千分位用 `scales::percent()/comma()/dollar()`；长类别标签优先横向柱状图。
- **中文渲染防线**（症状 → 处置，均已真机实测）：

| 症状 | 根因 | 处置 |
|---|---|---|
| `ggsave` 报 `gridtext ... isn't supported` 且导出空白图 | 脚本中文被 legacy locale 读成乱码，乱码在富文本管线里拼出伪 HTML 标签 | 用 UTF-8 保存脚本并在 IDE 中运行；标题副标题保持纯文本（见第 3 步） |
| 图里中文变方块 `□□□` | 图形设备缺 CJK 字形。**注意：只加 `device = cairo_pdf` 也会落到这一行**——设备对了，字体族仍是 Arial | `theme_pub(base_family = "<中文字体>")`，或 `ggsave(device = ragg::agg_png)`；`showtext` 必须**先 `sysfonts::font_add()` 注册中文字体**，否则照样方块 |
| `+ theme()` 报 `Only elements of the same class can be merged` | 在覆盖 ggtext textbox 主题元素 | 换 `theme_pub()`；要变体就写新的工厂函数 |
| 终端跑 `Rscript` 时路径/字符串中文变乱码 | R 启动在非 UTF-8 locale | 启动前设环境变量 `LC_CTYPE="Chinese (Simplified)_China.utf8"`（实测可从 Git Bash 救回整个管线） |
| 投稿 PDF 打开全是点号 `......`，无报错 | `ggsave` 默认 `pdf()` 设备不做 CJK 转换，静默逐字替换 | `ggsave(device = cairo_pdf, ...)` **且**指定中文字体族——**只做前半步会从"点号"变成"方块"**（见第 6 步两步走）。实测 cairo_pdf + 中文字体后 0 警告、字体内嵌 |

### 第 7 步：交付前验收（不可省）

1. 数据在 `ggplot()` 前已整理；类别按值排序，factor 顺序是有意为之。
2. 图表类型匹配变量关系；无饼图/3D/双轴/彩虹色。
3. **快检——可机检的部分直接跑 linter，别用眼睛过**：
   `source("scripts/lint_plot.R"); lint_plot(p)` → 逐条 PASS/WARN/FAIL。覆盖 12 条：
   空图层、常量进 `aes()`（伪图例）、图例级别 >6、图例重复坐标轴或标签、柱状图 Y 轴从 0 开始、
   字符类别按值排序、`xlim()/ylim()` 删数据、饼图/双轴、`log/sqrt` 喂非正值、小样本分组拟合、
   两个轴都是分类的散点。
   **五条只能靠眼睛**（标题是否结论式、配色是否协调、标签是否真没压在一起、缺失是否已说明、
   跨图同色）——linter 明确报 `SKIP`，不假装被验过，它们归下一条。
4. **把导出的文件实际打开看一遍**：中文可读、无 `□`、标题左对齐、标签不重叠、
   柱状图 Y 轴从 0 开始、跨零数据零线可见。只看过代码没看过图 = 没有验收。
5. **对账交付**：正式交付时把"图上画的数"一并导出，图和数据必须对得上：
   `write.csv(ggplot_build(p)$data[[1]], "figure-1-data.csv", row.names = FALSE)`
   （存的是统计变换后的最终绘制值，不是喂进去的原始值。）
6. 改渲染规则或交付前跑两个回归，全 PASS 再交付：
   - `Rscript scripts/smoke-cjk.R` —— 环境与中文导出。第 5 项**验字形**（文字层 + 内嵌字体），
     不是只验文件存在；它以前只验 `file.exists + size`，一张**方块**的 PDF 照样报 PASS。
   - `Rscript scripts/verify_charts.R` —— 图表语料回归：每条 linter 规则一对**违规/合规**用例，
     **违规没被抓住 = 规则没落地**。改 linter 或加规则后必跑（漏加用例会被元检查挡下）。
   **"文件生成了"和"测试全绿了"都不等于"图对了"**，第 4 条"打开看一遍"永远是最后一道。

## 强制停手点

- 用户明确要求饼图/3D/双 Y 轴：先给一次理由和替代方案（排序柱状图/分面/拆两图），
  用户仍坚持则照做，不反复劝。
- 需要联网装包、修改用户全局配置（注册字体、改 .Rprofile）时，先问一句再动。

## 致命反模式

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
| ggtext textbox 做标题且图含中文 | `theme_pub()` 纯文本标题（第 3 步） |
| 中文图只加 `device = cairo_pdf`，不指定中文字体族 | `theme_pub(base_family = "<中文字体>")`，或 `ragg::agg_png`（第 6 步两步走） |

## 依赖与降级（不逼用户装冷门包）

- **核心**（缺了阻塞，第 0 步自动补装）：ggplot2 ≥3.5、dplyr ≥1.1、forcats、scales
- **常用增强**（可直接装）：ggrepel、patchwork
  一句话安装：`install.packages(c("ggrepel", "patchwork"))`
- **按需增强**（场景触发再装，**默认不装不推荐**）：ggdist（halfeye 分布）、
  gghighlight（每面板高亮一步到位，降级写法见 `references/multipanel.md`）、
  scico / MetBrewer / khroma（进阶色板，viridis + HEX 速查已覆盖绝大多数场景）、
  showtext / ragg（中文渲染防线触发时才需要）
- 零依赖底线：分布图有直方图/密度，色板有内置 viridis + Okabe-Ito/Tol HEX，
  显著性括号可手写，热图聚类排序用 base `stats::hclust`——没有任何场景强迫用户装冷门包。

## 深料索引（按需读取，勿全量加载）

- `references/palettes.md` —— tidyecology 默认色板 / Okabe-Ito / Paul Tol HEX 速查 + 零依赖色盲自检
- `references/recipes.md` —— 误差条/CI、显著性括号、坐标变换、热图配方
- `references/multipanel.md` —— 多面板决策表（分面 vs 拆分）、每面板高亮、尺寸估算
- `references/antipatterns.md` —— 反模式前后对照代码与渲染图
- `references/baseline-v1.2-cursor-rule.md` —— v1.2 原始规则存档（溯源用）
- `scripts/smoke-cjk.R` —— 中文环境冒烟测试（第 7 步用）
- `scripts/lint_plot.R` —— 「快检」的可执行版本（12 条规则 + 5 条"需人看"）
- `examples/chart_corpus/` —— 每条规则一对违规/合规用例（`scripts/verify_charts.R` 的靶子）
