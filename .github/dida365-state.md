# Dida365 State Mirror

## 基本信息
- **MCP 项目名**: mcp-SSPU-all-in-one
- **名称来源**: AGENTS.md
- **远程项目就绪**: 是
- **项目 ID**: 69e37a01e4b0028dfb42216d

## 当前状态
- **当前阶段**: Phase 5 — 学院/部门数据源服务
- **当前子任务**: 5.1-5.19 通用学院解析服务编码中（枚举已扩展，待创建service文件）
- **未完成任务数**: 22（19个学院+2个收尾+1个Phase5父任务）
- **密集对话开启**: 否
- **最后同步**: 2026-04-19T14:20:00+08:00

## 阶段进度
| 阶段 | 状态 | 说明 |
|------|------|------|
| Phase 1 | ✅ 完成 | 基础框架 |
| Phase 2 | ✅ 完成 | 信息公开网数据源 |
| Phase 3 | ✅ 完成 | 主要数据源（教务处/信息技术中心/学校官网） |
| Phase 4 | ✅ 完成 | 次要数据源（体育部/保卫处/校区建设办/新闻网/学生处） |
| Phase 5 | ⏳ 进行中 | 19个学院/部门 — 枚举已扩展，待创建通用service |
| Phase 6 | ⬜ 待开始 | 快速跳转扩充 + 微信占位 |

## Phase 5 探索结果
### 学院域名与HTML模式
| # | 学院 | 域名 | 模板 |
|---|------|------|------|
| 5.1 | 计算机与信息工程学院 | jxxy.sspu.edu.cn | A: ul.list li.ui-preDot > span.time + a |
| 5.2 | 智能制造与控制工程学院 | imce.sspu.edu.cn | C: swiper卡片 |
| 5.3 | 资源与环境工程学院 | zihuan.sspu.edu.cn | A: ul.list li.ui-preDot |
| 5.4 | 能源与材料学院 | sem.sspu.edu.cn | B: ul.news_list li.news |
| 5.5 | 集成电路学院 | sic.sspu.edu.cn | B: news_list + news_date |
| 5.6 | 智能医学与健康工程学院 | imhe.sspu.edu.cn | D: a.btt-3 > div.btt-4 + div.time-1 |
| 5.7 | 经济与管理学院 | jjglxy.sspu.edu.cn | B: news_list + news_meta |
| 5.8 | 语言与文化传播学院 | wywh.sspu.edu.cn | A: ul.tylist li > span.riqi + a[title] |
| 5.9 | 数理与统计学院 | sltj.sspu.edu.cn | A: ul.list li.ui-preDot |
| 5.10 | 艺术与设计学院 | design.sspu.edu.cn | B: div.index_list2_box |
| 5.11 | 职业技术教师教育学院 | stes.sspu.edu.cn | D: a.item > div.tit + div.time |
| 5.12 | 职业技术学院 | cive.sspu.edu.cn | B: news_list li.news |
| 5.13 | 马克思主义学院 | mkszyxy.sspu.edu.cn | A: ul.list li.ui-preDot |
| 5.14 | 继续教育学院 | adult.sspu.edu.cn | A: ul.currency li > span + a[title] |
| 5.15 | 艺术教育中心 | education.sspu.edu.cn | D: span.first + span.last |
| 5.16 | 国际教育中心 | sie.sspu.edu.cn | D: div.item > div.time + a.tit |
| 5.17 | 创新创业教育中心 | cxcy.sspu.edu.cn | B: news_list li.news |
| 5.18 | 研究生处 | yjs.sspu.edu.cn | A: div.tyList ul li > span.riqi + a[title] |
| 5.19 | 图书馆 | library.sspu.edu.cn | A: li.ui-preDot > span.time + a |

## 最近提交
- `cc9c770` feat(backend): 新增体育部/保卫处/校区建设办/新闻网/学生处数据源服务
- `570d667` feat(backend): 新增教务处/信息技术中心/学校官网数据源服务
