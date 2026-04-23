# Pull Request

## 背景与目标
<!-- 说明这次变更为什么要做、解决什么问题 -->

## 关联事项
<!-- 关联当前仓库内的 Issue / 任务 -->
Closes #

## 变更类型
- [ ] feat：新功能
- [ ] fix：缺陷修复
- [ ] refactor：代码重构
- [ ] docs：文档更新
- [ ] style：代码风格调整
- [ ] test：测试补充
- [ ] perf：性能优化
- [ ] build / ci：构建或 CI 变更
- [ ] chore：其他杂项

## 影响范围
- [ ] Flutter 前端（`lib/`）
- [ ] 平台工程（Android / iOS / macOS / Linux / Windows / Web）
- [ ] 依赖 / 工具链
- [ ] GitHub 工作流 / Release
- [ ] 仓库治理（Issue / PR 模板、Labeler、CODEOWNERS、Dependabot）
- [ ] 文档

## 风险与回滚
- 风险等级：
  - [ ] 低
  - [ ] 中
  - [ ] 高
- 主要风险：
- 回滚方案：

## 验证记录
- [ ] `flutter analyze`
- [ ] `flutter test`
- [ ] 手动验证（请补充关键路径）
- [ ] 未执行部分验证（请说明原因）

## 发布触发说明
- [ ] 本 PR 不触发公开 Release
- [ ] 本 PR 需要在 merge 后触发公开 Release，并已人工添加 `release` 标签
- [ ] 如为正式发布，目标分支为 `main`
- [ ] 如为预发布，目标分支为 `main`、`develop` 或 `release/*`

## 截图 / 录屏（如涉及 UI）
<!-- 若无，可写“无” -->

## 发布说明（仅带 `release` 标签时必填）
<!--
Release workflow 会直接从下列章节生成 release-notes.md 与 GitHub Release 正文。
带 `release` 标签时，必须把每个章节替换为真实内容，不允许保留“无”“新装用户：”这类模板占位文本。
若本 PR 不触发公开 Release，请删除或忽略下列章节内容，不要给 PR 添加 `release` 标签。
-->

## 亮点
- 请填写本次发布的新增、修复、优化亮点

## 破坏性变更
- 若无破坏性变更，请明确写“无破坏性变更”

## 平台清单
- Android
- Windows x64 / arm64
- macOS universal
- Linux x64 / arm64（AppImage / deb / rpm / tar.gz）
- Web

## 安装 / 升级说明
- 新装用户：
- 升级用户：
- 是否需要清理旧配置：

## Linux 安装说明
- Debian / Ubuntu / Linux Mint 用户优先使用 `.deb`
- Fedora / openSUSE / RHEL 系用户优先使用 `.rpm`
- 需要免安装时使用 `.AppImage`
- 无法直接安装时使用 `.tar.gz`

## 已知问题
- 若无已知问题，请明确写“无已知问题”

## 校验信息
- 合并后 Release 将附带 `SHA256SUMS.txt`
- 合并后 Release 将附带 `manifest.json`

## 自查清单
- [ ] 命名清晰，类型完整
- [ ] 注释有效（注释率 20%~50%）
- [ ] 无残留调试代码
- [ ] 无未说明的 TODO / FIXME
- [ ] 相关 `docs/` 已同步更新
- [ ] `docs/CHANGELOG.md` 已同步更新（如适用）
- [ ] 依赖 / 工作流变更已说明版本与平台影响
- [ ] 如 PR 目标为 `main`，已确认后续是否需要回合并到 `develop`
