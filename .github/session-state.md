# 会话状态快照

## 当前状态
- **密集对话已开启**: Session ID = `d80d43b9a4b52440`
- **主题**: 大型多任务需求确认
- **状态**: 刚开启密集对话，尚未向用户提出第一个问题

## 项目信息
- 路径: `e:\Projects\Qintsg\SSPU-all-in-one`
- 分支: `develop`
- 最新提交: `da24ce6` (chore: 同步滴答清单状态镜像)
- Dida365 项目 ID: `69e37a01e4b0028dfb42216d`
- Flutter 3.41.4, Dart 3.11.1, Windows 桌面
- fluent_ui: ^4.11.1 (注意: .withValues(alpha:x) 不是 .withOpacity())

## 用户新需求（大型多任务）
用户提交了一个大型需求清单，要求**先确认需求再规划 todo 进入滴答清单**。需求分为以下几类：

### A. UI/UX 改进
1. 首页最新消息点击跳转
2. Fluent 2 Design System 视觉重构（参考 https://fluent2.microsoft.design/）
3. 设置页导航改为左侧导航 + 右侧内容面板
4. 在参考的开源项目中加入 Fluent 2 Design System

### B. 新数据源（消息抓取）
| 来源 | 首页 | 消息页 | 备注 |
|------|------|--------|------|
| 教务处 | https://jwc.sspu.edu.cn/main.htm | 学生专栏 /897/list.htm, 教师专栏 /898/list.htm | 需要导航+消息 |
| 信息技术中心 | https://itc.sspu.edu.cn/main.htm | /zxxx/list.htm | |
| 体育部 | https://pe2016.sspu.edu.cn/ | /342/list.htm, /343/list.htm | |
| 保卫处 | https://bwwz.sspu.edu.cn/main.psp | /1019/list.psp, /1023/list.psp | |
| 校区建设办公室 | https://xqjsb.sspu.edu.cn/main.htm | 只获取首页 | 日期可能年份不是当年 |
| 新闻网 | https://xww.sspu.edu.cn/ | 只获取首页 | |
| 学生处 | https://xsc.sspu.edu.cn/main.htm | 只获取首页 | |
| SSPU官网 | https://www.sspu.edu.cn/ | /2965/list.htm, /xsjz/list.htm | |

### C. 学院/部门（只获取首页，手动刷新获取更深内容）
计算机与信息工程学院、智能制造与控制工程学院、资源与环境工程学院、能源与材料学院、集成电路学院、智能医学与健康工程学院、经济与管理学院、语言与文化传播学院、数理与统计学院、艺术与设计学院、职业技术教师教育学院、职业技术学院、马克思主义学院、继续教育学院、艺术教育中心、国际教育中心、创新创业教育中心、研究生处、图书馆

每个都需要探索编写规则和 tag2/3，无关内容不获取

### D. 快速跳转新增
- 体育综合查询: https://tygl.sspu.edu.cn/sportscore/
- OA: https://oa.sspu.edu.cn/

### E. 代码质量
- 500 行以上文件需拆分解耦

## 需求确认进度
- 密集对话 Session ID: `d80d43b9a4b52440`（已关闭）
- 所有需求已确认，进入滴答清单规划阶段

### 确认的需求总结
1. 代码拆分（settings_page.dart ~1060行, info_page.dart ~690行）
2. 设置页左侧导航+右侧内容，6个栏目（安全/窗口行为/消息推送/职能部门/教学单位/微信占位）
3. 职能部门和教学单位：一级通道列表+总开关，点击进二级页面做详细设置
4. 首页消息点击→内嵌WebView（失败fallback默认浏览器），WebView内可跳外部
5. Fluent 2视觉重构（颜色/间距/圆角+Design Token），关于页加引用
6. 快速跳转：所有部门/学院首页+体育综合查询+OA，均默认浏览器
7. 新数据源：教务处、信息技术中心、体育部、保卫处、校区建设办公室、新闻网、学生处、SSPU官网 + 17个学院
8. 每个学院单独探索抓取规则
9. 微信栏目仅占位
10. 多平台WebView支持

## 已完成的提交历史
- dcfe19c: base modules
- 7583d96: Fluent Design 美化
- 7c43662: notification service
- 113410e: info center restructure
- 9c3c9f6: info center UX improvements
- c97b9bc: message persistence + channel filtering
- 3aa3172: auto-refresh + system push
- fe845f8: notification toggle + DND + default interval
- 7557b41: settings nav bar + home messages
- da24ce6: sync mirror

## 关键文件和代码约束
- StorageService.getBool: 返回 `bool`，有 `defaultValue:` 参数
- StorageService.getInt: 返回 `int?`（nullable）
- 单例模式: `ServiceName._()` + `static final instance`
- SSPU 分页: page 1 = list.htm, page N = listN.htm, 14 items per page
- commit 格式: `type(scope): 中文摘要`
- 不主动 push 除非用户要求
