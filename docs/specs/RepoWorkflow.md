# Spec: RepoWorkflow

Scope: repo

# 仓库工作流约束

适用于 SSPU-all-in-one 仓库内所有修复、功能、视觉与工程配置改动。

## 已确认文件

- `AGENTS.md` 在当前 `pr-134` 工作树中不存在，但已在其它本地/远端分支与历史提交中找到：`main`、`origin/main`、多个 release/tag 分支均包含同一最新 blob `ed4fed841efaa0275ebd43ad1f6e8fd3e7441506`。
- 当前分支历史中 `15c1ff8d7c97c6829d83c92c63bfaa993e7244ec` 删除了 `AGENTS.md` 并把它加入 `.gitignore`；用户已明确要求取消 ignore，当前 `.gitignore` 不再忽略 `AGENTS.md`。
- 在 `AGENTS.md` 未恢复到当前工作树前，本次以 `main:AGENTS.md` 的最新内容、`.github/分支命名规范.md`、`.github/pull_request_template.md`、`.github/PULL_REQUEST_TEMPLATE/*`、`docs/USAGE.md`、`docs/DESIGN.md` 共同作为仓库工作流与工程约束来源。
- 项目为 Flutter + Dart + `fluent_ui` 应用，目标覆盖 Android / iOS / macOS / Linux / Windows / Web。

## AGENTS 工作流摘要

- 规则优先级：用户当前明确要求 > 子目录 `AGENTS.md` > 根目录 `AGENTS.md` > 仓库既有约定 > 官方标准与通用工程约定。
- 修改前必须阅读相邻文件、当前模块目录、已有分层方式、API 契约、测试风格、脚本与配置、相关文档。
- 修改时优先最小改动、最小影响面、最低回滚成本、最易审查的实现。
- 修改后必须保证分层清晰、代码可验证、注释有效、类型完整、文档同步。
- 默认要求实现可运行、可验证、可交付；不得保留空实现、假返回值、假成功逻辑或未接线伪完成。
- 只在确有必要时保留 `TODO:` / `FIXME:`，并写清原因、影响范围、后续动作和风险说明。
- 最终代码、注释、文档、提交说明只保留稳定、正向、可执行、面向结果的内容。

## 分支与 PR 规则

- `main` 是稳定发布分支，`develop` 是日常开发集成分支。
- 常规功能、修复、文档、治理与依赖升级默认合入 `develop`。
- `AGENTS.md` 规定开始任务前应执行 `git status`、检查未提交内容，状态安全后执行 `git pull --rebase`；在本会话中如遇“提交/拉取”与系统级限制冲突，以系统级限制和用户显式授权为准。
- `AGENTS.md` 规定每完成一个独立可审查块提交一次；本会话仍遵守“除非用户明确要求，不主动 commit/push”的上级约束。
- 分支命名推荐：`feature/<topic-kebab-case>`、`fix/<topic-kebab-case>`、`docs/<topic-kebab-case>`、`chore/<topic-kebab-case>` 等。
- 禁止直接向 `main` / `develop` 推送未审查提交。
- Pull Request 标题与 commit message 统一使用 `type(scope): 中文摘要`。
- 影响 `docs/`、依赖、构建发布、平台配置或 API 契约时，必须同步更新相关文档。
- 修改 `.github/`、依赖或 Release 流程时，PR 中必须写明验证结果、影响平台与回滚方式。

## 验证规则

- Dart/Flutter 静态分析：优先运行 `flutter analyze`，期望 `No issues found!`。
- 测试：优先运行 `flutter test`；若耗时或平台限制导致无法全量运行，应至少运行受影响测试并说明限制。
- UI/响应式改动应至少覆盖桌面宽屏、平板/中屏、移动窄屏的布局自查；不可出现非预期横向滚动、遮挡、溢出。
- 安全/密码保护改动必须验证：启用、禁用、修改密码、失败/取消回退、清除本地状态等路径。

## 安全与隐私

- 不读取、不输出、不提交 `.env`、密钥、token、私钥、keystore、云凭据等敏感内容。
- 不保存系统 PIN、指纹、Face ID、Touch ID 等原始生物识别数据。
- 不以明文形式保存用户密码。
- 所有用户数据原则上仅保留在本地，不上传云端。

## 本地工具与插件配置

- `AGENTS.md` 是可共享仓库工作流文件，不应被 `.gitignore` 忽略。
- 本地插件、agent 运行态、worktree、临时状态、自动化缓存、浏览器测试状态等文件默认不入库。
- 如果任务需要新增本地插件/worktree 配置目录，应同步更新 `.gitignore`，至少考虑 `.worktree/`、`.worktrees/`、`.opencode/`、`.sisyphus/` 等本地状态目录。
- 只有明确需要团队共享的配置才允许入库；共享配置必须不含机器路径、密钥、token 或个人账号信息。
- 新增忽略规则时应避免误忽略项目源码、文档、测试、CI 配置和平台工程文件。

## 代码风格

- 遵循 `flutter_lints` 推荐规则。
- 不使用 `as any`、`@ts-ignore`、`@ts-expect-error` 等类型压制模式；Dart 中也不得通过不安全动态绕过真实类型问题。
- Bugfix 保持最小变更，不夹带无关重构。
- Fluent 2 / UI 优化应优先复用 `fluent_ui` 组件、现有主题与既有响应式断点。
