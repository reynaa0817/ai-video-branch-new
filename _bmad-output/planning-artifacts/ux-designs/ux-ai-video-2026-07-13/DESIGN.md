---
title: AI 漫剧创作平台 — DESIGN.md
name: Frochy Studio
description: 面向非专业创作者的深色电影感 AI 漫剧创作工作室视觉系统。
status: final
updated: 2026-07-13
sources:
  - ../../prds/prd-ai-video-2026-07-13/AI漫剧创作平台-完整PRD.md
colors:
  surface-base: '#080A12'
  surface-sidebar: '#0B0E18'
  surface-raised: '#101522'
  surface-elevated: '#171E2E'
  surface-hover: '#1D2638'
  ink-primary: '#F4F7FF'
  ink-secondary: '#AAB3C5'
  ink-muted: '#8490A7'
  ink-disabled: '#59647A'
  primary: '#6547D9'
  primary-hover: '#7658E8'
  primary-foreground: '#FFFFFF'
  accent-cyan: '#2DD4E5'
  accent-cyan-foreground: '#080A12'
  success: '#45D6A0'
  warning: '#F6C85F'
  destructive: '#FF7A90'
  border-subtle: '#20283A'
  border-strong: '#374158'
  focus-ring: '#62E7F3'
  overlay: 'rgba(3, 5, 10, 0.72)'
  preview-gradient: 'linear-gradient(135deg, #6547D9 0%, #2DD4E5 100%)'
typography:
  display:
    fontFamily: 'Geist, PingFang SC, Noto Sans SC, Microsoft YaHei, sans-serif'
    fontSize: 32px
    fontWeight: '650'
    lineHeight: '1.2'
    letterSpacing: -0.02em
  heading-lg:
    fontFamily: 'Geist, PingFang SC, Noto Sans SC, Microsoft YaHei, sans-serif'
    fontSize: 24px
    fontWeight: '600'
    lineHeight: '1.3'
  heading-md:
    fontFamily: 'Geist, PingFang SC, Noto Sans SC, Microsoft YaHei, sans-serif'
    fontSize: 18px
    fontWeight: '600'
    lineHeight: '1.4'
  body:
    fontFamily: 'Geist, PingFang SC, Noto Sans SC, Microsoft YaHei, sans-serif'
    fontSize: 14px
    fontWeight: '400'
    lineHeight: '1.6'
  label:
    fontFamily: 'Geist, PingFang SC, Noto Sans SC, Microsoft YaHei, sans-serif'
    fontSize: 13px
    fontWeight: '550'
    lineHeight: '1.4'
  meta:
    fontFamily: 'Geist, PingFang SC, Noto Sans SC, Microsoft YaHei, sans-serif'
    fontSize: 12px
    fontWeight: '400'
    lineHeight: '1.5'
  data:
    fontFamily: 'JetBrains Mono, SFMono-Regular, Consolas, monospace'
    fontSize: 12px
    fontWeight: '500'
    lineHeight: '1.5'
rounded:
  sm: 6px
  md: 10px
  lg: 14px
  xl: 18px
  full: 9999px
spacing:
  '1': 4px
  '2': 8px
  '3': 12px
  '4': 16px
  '5': 20px
  '6': 24px
  '8': 32px
  '10': 40px
  '12': 48px
components:
  primary-button:
    background: '{colors.primary}'
    foreground: '{colors.primary-foreground}'
    radius: '{rounded.md}'
  preview-frame:
    background: '{colors.surface-base}'
    border: '1px solid {colors.border-subtle}'
    radius: '{rounded.lg}'
  gate-card:
    background: '{colors.surface-raised}'
    border: '1px solid {colors.border-strong}'
    radius: '{rounded.lg}'
  ai-panel:
    background: '{colors.surface-sidebar}'
    border-left: '1px solid {colors.border-subtle}'
---

# AI 漫剧创作平台 — Visual Design System

## 1. 品牌与风格

产品的视觉隐喻是一间灯光已经暗下、作品正在发光的数字工作室。深色界面让竖屏视频、角色图和分镜成为视觉中心；紫色代表 AI 创作与主要动作，青色代表正在生成、可预览和“作品活起来”的时刻。

整体风格为 **前沿电影感 × 专业创作工具**：

- 有氛围，但不把工作台做成营销落地页；
- 有未来感，但不使用难以阅读的霓虹文字和泛滥光效；
- 有专业密度，但不暴露普通创作者不需要理解的模型参数；
- 强调作品和阶段成果，不用大量统计卡片制造“后台系统感”。

深色是 MVP 默认且唯一需要完整验收的主题。浅色主题可以在后续提供，不在当前设计中通过简单反色伪造。

## 2. 色彩

### 2.1 基础表面

- **Studio Black `#080A12`**：主画布背景。接近放映空间，但保留轻微蓝色倾向，避免纯黑造成层级消失。
- **Sidebar `#0B0E18`**：全局导航和 AI 共创面板背景。
- **Raised `#101522`**：卡片、确认区域、表单与分镜容器。
- **Elevated `#171E2E`**：菜单、浮层、选中产出物和高层级区域。
- **Hover `#1D2638`**：可交互行悬停与键盘高亮。

层级优先通过色调差和边框建立。阴影只用于浮层，不给每张卡片添加发光阴影。

### 2.2 文字

- **Primary `#F4F7FF`**：标题、正文重点和主要数值；相对基础表面对比度约 18.44:1。
- **Secondary `#AAB3C5`**：普通正文和辅助解释；对比度约 9.38:1。
- **Muted `#8490A7`**：时间、来源和元数据；对比度约 6.14:1。
- **Disabled `#59647A`**：仅用于明确不可用状态，不承载必要信息。

文字不使用渐变。渐变是品牌光源，不是内容颜色。

### 2.3 品牌与语义颜色

- **Creator Violet `#6547D9`**：主要按钮、当前阶段、已采用版本和 AI 主动作。白字对比度约 6.08:1。
- **Living Cyan `#2DD4E5`**：生成中、可播放新成果、时间进度和焦点环；深色前景对比度约 10.97:1。
- **Success `#45D6A0`**：质量通过、保存成功和安全恢复。
- **Warning `#F6C85F`**：预算 70% / 90%、非阻断质量提醒和可能过期。
- **Destructive `#FF7A90`**：阻断、删除和不可恢复动作。

语义状态必须同时使用图标、标题或文本。颜色不能独立承担“通过、提醒、失败”的含义。

### 2.4 紫青渐变

`linear-gradient(135deg, #6547D9 0%, #2DD4E5 100%)` 只用于：

- 作品首次生成样片后的预览边缘光；
- 空状态或欢迎区域的小面积品牌光晕；
- 当前正在形成的新成果进度线；
- 营销图和封面视觉。

禁止用于大段按钮、正文背景、所有卡片边框或持续闪烁的装饰。

## 3. 字体

### 3.1 字体栈

- 界面：Geist → PingFang SC → Noto Sans SC → Microsoft YaHei → sans-serif；
- 数据：JetBrains Mono → SFMono-Regular → Consolas → monospace。

中文界面以系统中可用的中文字体为准，Geist 负责拉丁字符和数字。MVP 不依赖必须联网下载的展示字体，避免字体加载影响创作工作台。

### 3.2 字级

| Token | 字号 / 行高 | 用途 |
|---|---|---|
| display | 32 / 1.2，650 | 首次创建、空状态核心句、成片完成标题 |
| heading-lg | 24 / 1.3，600 | 页面标题、主要阶段标题 |
| heading-md | 18 / 1.4，600 | 卡片标题、剧集标题、闸门标题 |
| body | 14 / 1.6，400 | 主体说明、剧本摘要、AI 回复 |
| label | 13 / 1.4，550 | 表单标签、操作和状态 |
| meta | 12 / 1.5，400 | 时间、版本、来源、次要数据 |
| data | 12 / 1.5，500 | 成本、时长、任务和技术标识 |

不使用全大写中文标签。关键数字采用等宽数字，避免成本和时间更新时跳动。

## 4. 布局与间距

基础间距为 4px，常用节奏为 8 / 12 / 16 / 24 / 32 / 40 / 48px。

- 全局侧栏：展开 224px，折叠 64px；
- AI 共创面板：默认 360px，可在 320–480px 调整；
- 主工作台最小建议宽度：1024px；
- 页面内容边距：桌面 24px，宽屏 32px；
- 卡片内边距：紧凑 12px、常规 16px、确认闸门 24px；
- 竖屏视频预览保持 9:16，不因容器拉伸变形；
- 故事与制作信息密集区域允许紧凑行，但主要确认区域保留明显留白。

作品画布可以滚动；顶部作品状态栏和六阶段轨道保持可见。右侧 AI 共创面板独立滚动，不能因长对话把主画布带离当前成果。

## 5. 层级与深度

工作台主要通过表面色阶和边框表达层级。普通卡片不使用阴影；菜单、浮层和需要脱离画布的对比窗口使用低透明黑色大范围扩散阴影。

播放器和预览可以使用极弱紫青环境光，模拟作品照亮工作室的氛围，但不得改变画面边界、遮挡字幕或影响质量判断。确认闸门通过更强边框和留白建立权重，不通过发光制造紧迫感。

## 6. 形状

- 6px：输入框、小标签和镜头状态；
- 10px：按钮、列表行和普通卡片；
- 14px：播放器、确认闸门和主要面板；
- 18px：首次创建和成片完成等品牌性容器；
- 全圆角只用于短状态徽标、头像和进度点。

工作台应读作“精准的工具”，因此避免所有容器都使用超大圆角。

## 7. 图标与影像

- 图标统一使用 1.75px 左右的圆角线性风格；
- 常用动作必须同时有文本或可访问标签；
- 生成中使用静态状态图标加细进度，不使用无限旋转的大型魔法图标；
- 作品缩略图优先使用实际产出帧，不使用通用 AI 插画；
- 角色、场景和分镜图保持原始宽高比，并明确版本和采用状态；
- “AI 生成内容”标识清晰但不抢夺作品标题层级。

## 8. 核心组件

### 8.1 按钮

| 变体 | 用途 | 规则 |
|---|---|---|
| Primary | 当前页面唯一主要推进动作 | 紫色实底；同一确认区域最多一个 |
| Secondary | 预览、保存、普通编辑 | Raised 表面 + Strong 边框 |
| Ghost | 工具栏和次要操作 | 无底色，悬停显示 Hover 表面 |
| Destructive | 删除、丢弃候选、不可恢复动作 | 默认轮廓式；最终确认才使用危险实底 |

按钮文案使用具体结果，例如“确认故事并继续”“生成样片（预计 ¥12）”，避免只有“确定”“继续”。

### 8.2 六阶段轨道

- 当前阶段：紫色主标记 + 文字；
- 已完成阶段：中性文字 + 成功图标；
- 有新预览：青色小点与“可预览”文本；
- 需要确认：紫色强调环与“需要你确认”；
- 阻断：危险图标与明确文本；
- 未开始：低对比中性色，但仍保持可读。

轨道不展示每个模型节点。点击历史阶段进入只读回看；修改会产生影响分析，不直接覆盖。

### 8.3 作品卡

- 实际视频帧或渐进生成封面；
- 状态置于封面左上，预算置于卡片底部；
- “需要你确认”卡片使用紫色边缘强调；
- “需要处理”使用危险图标和短原因，不整卡铺红；
- 生成中卡片展示“下一个可见成果”，而不是只显示百分比。

### 8.4 确认闸门卡

结构固定为：

1. 阶段成果标题与版本；
2. 可播放 / 可浏览的主要成果；
3. AI 做了什么；
4. 用户需要判断什么；
5. 下一阶段成本与时间；
6. 主动作、修改动作、暂停动作。

闸门卡使用 Raised 表面、Strong 边框和 14px 圆角。确认动作不放入小型模态框。

### 8.5 AI 共创面板

- 面板标题始终显示作用范围；
- 用户输入区固定在底部；
- AI 回答使用普通卡片，不做聊天气泡瀑布；
- “引用的设定”“影响范围”“修改候选”使用结构化区块；
- 使用记忆时出现可点击提示，进入创作设定查看依据；
- 高成本动作必须从建议态进入确认态，不能由一句自然语言立即扣费执行。

### 8.6 预算条

预算条分为：

- 已消耗：中性实色；
- 已预留：斜纹或轮廓区分；
- 剩余：低对比底色。

70% / 90% 标记可见但不持续发光；达到 100% 后显示“已暂停新增付费任务”。金额、占比和原因必须同时可查看。

### 8.7 视频与分镜

- 播放器控制层使用高对比黑色渐变遮罩；
- 字幕默认位于安全区，支持隐藏；
- 当前镜头在分镜条中使用紫色边框；
- 有新候选版本时使用青色角标；
- 质量阻断以角标和侧栏说明呈现，不在画面中央盖住问题区域；
- A/B 对比支持同步播放和单帧对齐。

### 8.8 状态徽标

徽标只使用短状态：需要确认、生成中、可预览、已暂停、需处理、已完成。徽标不能代替完整说明；在阻断卡、任务详情和质量结果中必须给出原因。

## 9. 动效

动效的目的只有三个：表明作品正在形成、维持空间连续性、确认版本采用。

- 页面与面板过渡：160–220ms；
- 候选版本采用：旧版本淡出、新版本对齐淡入，240ms；
- 新成果可预览：预览边缘出现一次紫青光扫，不循环；
- 任务进度：平滑更新，不用无法预测的跳跃庆祝；
- 成片完成：可有一次 600ms 以内的克制光晕，不使用彩纸、金币或游戏化奖励；
- Reduce Motion 开启时，所有光扫、位移动效和自动过渡改为即时状态变化。

## 10. Do / Don't

| Do | Don't |
|---|---|
| 让实际作品画面成为最高视觉焦点 | 用装饰性 AI 插画占据工作台 |
| 紫色表示主要创作动作，青色表示生成与新成果 | 每种阶段使用一种彩虹颜色 |
| 把模型细节收进制作详情 | 在普通用户首屏展示提示词和采样参数 |
| 通过表面色和边框建立层级 | 给每张卡片加霓虹外发光 |
| 状态同时有图标、文字和解释 | 只靠红黄绿判断质量 |
| 主要确认使用具体、结果导向文案 | 使用“确定”“继续”“OK” |
| 让成本与作品结果邻近出现 | 把预算藏在独立账单页面 |
| 使用实际产出帧作为封面与预览 | 用通用占位图长期替代作品 |

## 11. 实施边界

- 组件可以基于成熟 Web 组件库实现，但品牌 token 和本文行为必须保持；
- 普通组件继承组件库的可访问性与键盘行为，品牌层重点覆盖颜色、圆角、播放器、阶段轨道、闸门、预算条和 AI 共创面板；
- 任何新组件必须先证明现有组件无法表达，不为“更像 AI 产品”创造独立视觉语言；
- 关键文字、按钮和状态组合需在实际背景上验证 WCAG 2.1 AA；
- 浅色主题、复杂品牌动画和高度定制图标不属于 MVP 阻断项。

## 12. 视觉参考

- [作品中心](mockups/key-project-home.html)：首次 idea 输入、预算上限与作品状态卡。
- [概念样片确认](mockups/key-concept-preview.html)：深色工作台、竖屏视频、确认闸门与 AI 共创面板。
- [局部重做](mockups/key-local-redo.html)：播放器、镜头定位、候选版本与 A/B 对比。
- [成片验收](mockups/key-final-validation.html)：成片优先、质量门、成本总结与最终确认。

这些 mock 说明构图和 token 应用；若 mock 与本文件或 `EXPERIENCE.md` 冲突，以两份 spine 为准。
