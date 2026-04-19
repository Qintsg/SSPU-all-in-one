# Pre-Compaction State Snapshot

## Must Restore First
- current task goal
- latest user requirements
- AGGENTS.md / AGENTS.md and project constraints
- current Dida365 project/list name: mcp-SSPU-all-in-one
- global plan
- current subtask plan
- completed work
- unfinished work
- next action
- key changed files
- key validation results
- risks / blockers / unresolved questions
- whether an intensive chat session is active

## Current Dida365 Mirror Snapshot
# Dida365 状态镜像

## 基本信息
- **MCP 项目/清单名称**: mcp-SSPU-all-in-one
- **项目 ID**: 69e37a01e4b0028dfb42216d
- **名称来源**: AGENTS.md (`项目名称为：SSPU-all-in-one`)
- **远程项目就绪**: ✅

## 当前状态
- **当前阶段**: 规划完成，待开始阶段1执行
- **当前子任务**: 无（尚未开始）
- **剩余未完成项**: 38（6个阶段父任务 + 32个子任务）
- **密集对话是否开启**: 否
- **最后同步时间**: 2025-07-17T16:30:00+08:00

## 任务清单

### 阶段1：基础设施（高优先级）
| 编号 | 任务 | 状态 |
|------|------|------|
| 1.1 | 代码拆分：settings_page.dart (~1060行) | ⬜ 待做 |
| 1.2 | 代码拆分：info_page.dart (~690行) | ⬜ 待做 |
| 1.3 | 设置页左侧导航+右侧内容重构（6栏目，通道二级页面） | ⬜ 待做 |
| 1.4 | 首页消息点击跳转（内嵌WebView，多平台） | ⬜ 待做 |

### 阶段2：Fluent 2 视觉升级（中优先级）
| 编号 | 任务 | 状态 |
|------|------|------|
| 2.1 | Fluent 2 Design Token 体系引入 | ⬜ 待做 |
| 2.2 | 全局视觉重构（颜色/间距/圆角） | ⬜ 待做 |
| 2.3 | 关于页添加 Fluent 2 引用链接 | ⬜ 待做 |

### 阶段3：核心数据源（中优先级）
| 编号 | 任务 | 状态 |
|------|------|------|
| 3.1 | 数据源：教务处 (jwc.sspu.edu.cn) | ⬜ 待做 |
| 3.2 | 数据源：信息技术中心 (itc.sspu.edu.cn) | ⬜ 待做 |
| 3.3 | 数据源：SSPU官网 (www.sspu.edu.cn) | ⬜ 待做 |

### 阶段4：次要数据源（低优先级）
| 编号 | 任务 | 状态 |
|------|------|------|
| 4.1 | 数据源：体育部 (pe2016.sspu.edu.cn) | ⬜ 待做 |
| 4.2 | 数据源：保卫处 (bwwz.sspu.edu.cn) | ⬜ 待做 |
| 4.3 | 数据源：校区建设办公室（仅首页） | ⬜ 待做 |
| 4.4 | 数据源：新闻网（仅首页） | ⬜ 待做 |
| 4.5 | 数据源：学生处（仅首页） | ⬜ 待做 |

### 阶段5：学院/部门（逐个探索，低优先级）
| 编号 | 任务 | 状态 |
|------|------|------|
| 5.1 | 计算机与信息工程学院 | ⬜ 待做 |
| 5.2 | 智能制造与控制工程学院 | ⬜ 待做 |
| 5.3 | 资源与环境工程学院 | ⬜ 待做 |
| 5.4 | 能源与材料学院 | ⬜ 待做 |
| 5.5 | 集成电路学院 | ⬜ 待做 |
| 5.6 | 智能医学与健康工程学院 | ⬜ 待做 |
| 5.7 | 经济与管理学院 | ⬜ 待做 |
| 5.8 | 语言与文化传播学院 | ⬜ 待做 |
| 5.9 | 数理与统计学院 | ⬜ 待做 |
| 5.10 | 艺术与设计学院 | ⬜ 待做 |
| 5.11 | 职业技术教师教育学院 | ⬜ 待做 |
| 5.12 | 职业技术学院 | ⬜ 待做 |
| 5.13 | 马克思主义学院 | ⬜ 待做 |
| 5.14 | 继续教育学院 | ⬜ 待做 |
| 5.15 | 艺术教育中心 | ⬜ 待做 |
| 5.16 | 国际教育中心 | ⬜ 待做 |
| 5.17 | 创新创业教育中心 | ⬜ 待做 |
| 5.18 | 研究生处 | ⬜ 待做 |
| 5.19 | 图书馆 | ⬜ 待做 |

### 阶段6：收尾（无优先级）
| 编号 | 任务 | 状态 |
|------|------|------|
| 6.1 | 快速跳转页面扩充（所有部门/学院+体育综合查询+OA） | ⬜ 待做 |
| 6.2 | 微信栏目占位 | ⬜ 待做 |

## 需求确认摘要
- 设置页：左侧导航+右侧内容，6个栏目（安全/窗口行为/消息推送/职能部门/教学单位/微信占位）
- 职能部门和教学单位：一级通道列表+总开关，点击进二级页面做详细设置
- 消息跳转：内嵌WebView（失败fallback默认浏览器），WebView内可跳外部浏览器，多平台
- 快速跳转：所有部门/学院首页链接 + 体育综合查询 + OA，均用默认浏览器
- Fluent 2：调整颜色/间距/圆角 + Design Token 体系，关于页加引用
- tag命名：参考现有 MessageSourceType/MessageSourceName/MessageCategory 设计
- 微信栏目：仅占位，暂不实现功能


## Recovery Steps
1. Re-read AGGENTS.md; if it does not exist, re-read AGENTS.md
2. Re-read .github/dida365-state.md
3. Restore the plan and task thread
4. Continue execution only after recovery
