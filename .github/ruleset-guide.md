# GitHub Ruleset 配置指南

本文档记录仓库的分支保护规则，需在 GitHub → Settings → Rules → Rulesets 中配置。

## Ruleset: `protect-main`

- **Target**: `main` 分支
- **Enforcement**: Active

### 规则项

| 规则 | 设置 |
|------|------|
| Restrict deletions | ✅ |
| Require linear history | ✅ |
| Require signed commits | ✅ |
| Block force pushes | ✅ |
| Require pull request before merging | ✅ |
| Required approvals | 1 |
| Dismiss stale reviews on push | ✅ |
| Require review from CODEOWNERS | ✅ |

---

## Ruleset: `protect-develop`

- **Target**: `develop` 分支
- **Enforcement**: Active

### 规则项

| 规则 | 设置 |
|------|------|
| Restrict deletions | ✅ |
| Require linear history | ✅ |
| Require signed commits | ✅ |
| Block force pushes | ✅ |
| Require pull request before merging | ✅ |
| Required approvals | 1 |
| Dismiss stale reviews on push | ✅ |

---

## 仓库全局设置

| 设置项 | 值 |
|--------|-----|
| Default branch | `main` |
| Allow merge commits | ❌ |
| Allow squash merging | ✅（默认 commit message） |
| Allow rebase merging | ✅ |
| Auto-delete head branches | ✅ |
| Discussions | ✅ 启用 |
| Wiki | ✅ 启用 |

## 分支命名规范

- `main` — 稳定发布分支
- `develop` — 开发集成分支
- `feature/<name>` — 功能分支
- `fix/<name>` — 修复分支
- `hotfix/<name>` — 紧急修复分支
- `release/<version>` — 发布准备分支
