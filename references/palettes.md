# 配色速查（palettes）

> SKILL.md 第 5 步的深料。全部 HEX 可直接复制；优先用这里查表，少装一个包就少一个依赖。

## 默认色板（tidyecology datasheet 风）

主题与高亮默认取自 [tidyecology.com](https://tidyecology.com/)（纸底 `#f5f4ee`、墨字 `#16241d`）。

**离散 ≤3 类**（默认主题三色）：

```r
te_forest = "#275139"; te_rust = "#b5534e"; te_gold = "#c9b458"
scale_fill_manual(values = c(te_forest, te_rust, te_gold))
```

**离散 >3 类**：回退 Okabe-Ito（下一节），不要往三色里继续堆。

色盲档案（`cvd_check()` 实测）：森林/锈红/金 无硬冲突；锈红 vs 金色相塌缩
（cd≈0.004）但亮度差 0.29 兜底（软提醒）——灰度打印、粗线条叠加场景谨慎。

## 高亮重点（零依赖，默认首选）

中性灰 + 单一强调色（默认强调色 = 主题锈红），无需任何包：

```r
scale_fill_manual(values = c(`TRUE` = "#b5534e", `FALSE` = "#BDBDBD"), guide = "none")
# 朱红 #D55E00 仍是合格备选
```

## Okabe-Ito（色盲安全，8 色，零依赖）

论文作图的通用底牌；`#D55E00`（vermillion）即本技能的默认强调色。

| 用途 | HEX |
|---|---|
| 黑 | `#000000` |
| 橙 | `#E69F00` |
| 天蓝 | `#56B4E9` |
| 蓝绿 | `#009E73` |
| 黄 | `#F0E442` |
| 蓝 | `#0072B2` |
| 朱红 | `#D55E00` |
| 紫红 | `#CC79A7` |

```r
okabe_ito <- c("#000000", "#E69F00", "#56B4E9", "#009E73",
               "#F0E442", "#0072B2", "#D55E00", "#CC79A7")
scale_fill_manual(values = okabe_ito)
```

## Paul Tol muted（12 色，离散类别的稳重方案）

| # | HEX | # | HEX |
|---|---|---|---|
| indigo | `#332288` | sand | `#DDCC77` |
| cyan | `#88CCEE` | rose | `#CC6677` |
| teal | `#44AA99` | wine | `#882255` |
| green | `#117733` | purple | `#AA4499` |
| olive | `#999933` | pale grey | `#DDDDDD` |

## Paul Tol bright（7 色，需要更高区分度时）

`#4477AA` `#66CCEE` `#228833` `#CCBB44` `#EE6677` `#AA3377` `#BBBBBB`

## 连续变量

| 方案 | 用法 | 备注 |
|---|---|---|
| viridis（ggplot2 自带） | `scale_fill_viridis_c()` | **零依赖默认**，感知均匀、色盲安全 |
| 发散数据（有正负/中心值） | `scale_fill_gradient2(low = "#CC6677", mid = "white", high = "#332288")` | 中点必须有意义 |
| scico::batlow（进阶） | `scico::scale_fill_scico(palette = "batlow")` | 仅用户点名时用；`oslo` 偏冷单色、`roma` 发散 |

## 色盲自检（零依赖，交付前 30 秒）

不用装 colorblindr——下面这个纯 base R 函数用 Machado(2009) 模拟矩阵 + 色度坐标
把任意色板跑一遍（已校准：红绿经典对→软提醒；砖红vs森林绿→硬冲突；
灰底+朱红高亮组合→干净；Okabe-Ito 仅橙/朱红一条软提醒）：

```r
cvd_check = function(palette) {
  s2l = function(u) ifelse(u <= 0.04045, u / 12.92, ((u + 0.055) / 1.055)^2.4)
  MD = matrix(c(.367322, .860646, -.227968, .280085, .693084, .026831,
                .01182, .04294, .94524), 3, 3)
  MP = matrix(c(.152286, 1.052583, -.204868, .114503, .786281, .099216,
                -.003882, -.048116, 1.051998), 3, 3)
  sim = function(M) {
    lin = apply(col2rgb(palette) / 255, 2, s2l)
    out = pmin(1, pmax(0, M %*% lin)); out = matrix(out, 3, ncol(lin))
    sweep(out, 2, colSums(out), "/")            # 色度坐标（去掉亮度维度）
  }
  D = sim(MD); P = sim(MP)
  lum = sapply(palette, function(h) {
    l = apply(col2rgb(h) / 255, 2, s2l); .2126 * l[1] + .7152 * l[2] + .0722 * l[3] })
  res = data.frame()
  n = length(palette)
  for (i in 1:(n - 1)) for (j in (i + 1):n) {
    cd = min(sqrt(sum((D[, i] - D[, j])^2)), sqrt(sum((P[, i] - P[, j])^2)))
    dl = abs(lum[i] - lum[j])
    sev = if (cd < 0.10 && dl < 0.10) "硬冲突" else if (cd < 0.05) "软提醒" else "-"
    res = rbind(res, data.frame(a = palette[i], b = palette[j],
                                chroma = round(cd, 3), dLum = round(dl, 3), verdict = sev))
  }
  res
}
cvd_check(c("#BDBDBD", "#D55E00", "#56B4E9"))   # 跑自己的色板
```

判定规则与处置：

- **硬冲突**（色相塌缩且亮度几乎相同，如砖红 vs 森林绿）：必须换色或错开亮度。
- **软提醒**（色相塌缩但亮度差 ≥0.10，如纯红/纯绿）：当前靠亮度区分——
  灰度打印、粗线条、半透明叠加下会失效，谨慎使用；可给两色错开明度。
- 对比度另行目测：图形元素对白底 ≥3:1，正文文字 ≥4.5:1。
- 本函数是启发式（sRGB 近似模拟），过检不等于医学精确，但能拦住绝大多数事故。

## 跨图同色一致

同一篇报告/论文里，**同一类别永远同一颜色**。全局定义一次命名色板，所有图复用；
某图没出现的类别不许占用别的类别的颜色（plotthis 的 keep_empty 思想：空层级不出图也不换色）：

```r
# 全局定义一次（放脚本顶部）
pal = c("对照" = "#BDBDBD", "低剂量" = "#56B4E9", "高剂量" = "#D55E00")

# 各图只取自己出现的类别子集
scale_fill_manual(values = pal[intersect(names(pal), as.character(df$group))])
```

## 铁律提醒

- 类别 >6：分面，不要继续堆颜色。
- 禁止彩虹色（`rainbow()` / 默认 `hue_pal` 用于多类别）。
- 颜色必须服务于问题：高亮重点、区分类别、编码数值——三者之外的颜色都删掉。
- 跨图一致性优先于单图好看：换报告章节不改色板。
