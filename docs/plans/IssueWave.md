---
plan name: IssueWave
plan description: Frontend security roadmap
plan status: done
---

## Idea
围绕 GitHub issue #132、#126、#127、#128、#107 建立一轮可长期演进的前端与本地安全能力完善计划。计划按优先级先处理 P0/P1 的信息中心微信推文重复 tag、公众号/服务号名称与 ID 展示、密码保护系统级快速验证，再推进 P2 的响应式布局与 Fluent 2 视觉统一。所有变更必须遵循 `main:AGENTS.md`、仓库工作流、Flutter/Fluent UI 架构、本地隐私原则；共享的 `AGENTS.md` 不应被忽略，本地插件/worktree 运行态配置仍需纳入 .gitignore 保护。

## Implementation
- 确认仓库工作流与本地配置边界：记录 `AGENTS.md` 已在其它分支/历史中找到且当前已取消 ignore，采用 `main:AGENTS.md`、.github 分支/PR 规范和 docs 设计/使用文档作为约束来源，并检查 .gitignore 是否覆盖新增本地插件、agent 运行态、worktree、临时状态目录。
- 完成 issue 范围建模与优先级排序：将 #132 作为 P0 bugfix，#126 与 #107 作为 P1 功能完善，#127/#128 作为 P2 视觉与响应式长期改进，并明确每个 issue 的验收标准、风险和验证方式。
- 探索现有代码结构：定位 InfoPage、微信推文模型/服务、卡片/tag 渲染、设置页安全分区、LockPage、PasswordService、响应式导航与主题/样式工具，确认可复用模式和最小改动点。
- 修复 #132 微信推文 tag 重复显示：查明重复来源是数据层重复、渲染层重复还是分类/tag 合并逻辑问题，按最小变更去重，并保留正确样式与筛选行为。
- 完善 #126 微信推文来源展示：补全公众号/服务号名称与 ID 的数据模型、映射、降级文案和卡片/详情 UI，确保名称与 ID 层级清晰且桌面/移动端不溢出。
- 规划并实现 #107 系统级快速验证：基于官方文档确认 Flutter 跨平台能力边界，新增可选设置、可用性检测、解锁优先触发、失败/取消/不可用回退密码、修改密码/关闭密码保护时清理快速验证配置，并保证不保存生物识别/PIN 原始数据。
- 推进 #127 响应式布局第一轮治理：优先处理主要页面、导航、卡片、列表、按钮、表单在桌面/平板/移动宽度下的溢出、遮挡、横向滚动和点击区域问题。
- 推进 #128 Fluent 2 视觉统一第一轮治理：梳理颜色、间距、圆角、阴影、层级、hover/active/disabled/loading/empty/error 状态，优先抽取或复用高影响的样式/组件约定。
- 同步文档与本地配置忽略规则：若新增依赖、平台配置、权限说明、插件/worktree 本地配置或安全行为变化，同步更新 pubspec、平台配置、docs/USAGE.md、docs/DESIGN.md、.gitignore 与相关说明。
- 执行验证与收尾：运行 lsp/Flutter diagnostics、flutter analyze、flutter test；对 UI 响应式和密码保护关键路径进行手动/脚本化验证，记录平台限制、剩余风险和后续拆分建议。

## Required Specs
<!-- SPECS_START -->
- RepoWorkflow
<!-- SPECS_END -->
