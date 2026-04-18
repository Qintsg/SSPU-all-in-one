# 会话实现计划 — SSPU-all-in-one 多模块任务

## 当前状态
- 分支: develop (45fa2f7)
- 项目ID: 69e37a01e4b0028dfb42216d
- intensive chat: 已关闭
- 用户确认: 全部任务确认，不中断，完成后自测再验收

## 已完成任务 (11个)
1-8: 之前完成（AboutPage, AgreementPage, StorageService, EULA, 开源列表, UI修复, Logo, Logo布局）
9: 校园ICO (b0fcf29)
10: ICO加宽+assets迁移+标题 (7dc0e8e)
11: 关闭最小化到托盘 (45fa2f7)

## 待执行任务（按顺序）

### 大任务 1: 基础可复用模块
- [x] 1.1 网络请求模块（dio封装） — 任务ID: 69e3ae8ce4b04a4525eac12b
- [ ] 1.2 数据持久化模块增强 — 任务ID: 69e3ae8ce4b0e77702f77c22
- [ ] 1.3 Windows系统通知模块 — 任务ID: 69e3ae8ce4b04a4525eac12c
- [ ] 1.4 Web内容获取/解析模块 — 任务ID: 69e3ae8ce4b0e77702f77c20

### 大任务 2: Fluent Design 美化
- [ ] 2.1 主题系统统一 — 任务ID: 69e3ae8ce4b0e77702f77c21
- [ ] 2.2 组件美化与动画完善 — 任务ID: 69e3ae8ce4b07b9a474be32f

### 大任务 3: 占位页面填充
- [ ] 3.1 各页面填充文本内容 — 任务ID: 69e3ae8ce4b04a4525eac12a

### 大任务 4: 代码质量与测试
- [ ] 4.1 修复+测试+构建验证 — 任务ID: 69e3ae8ce4b0028dfb455d03

## 关键技术选型
- HTTP: dio (已查阅文档 /cfug/dio)
- 通知: flutter_local_notifications (/maikub/flutter_local_notifications)
- UI: fluent_ui (/bdlukaa/fluent_ui)
- HTML解析: html (dart package)
- 数据存储增强: shared_preferences + JSON序列化

## 现有依赖
fluent_ui ^4.11.1, shared_preferences ^2.5.3, crypto ^3.0.6, url_launcher ^6.3.2, window_manager ^0.4.3, tray_manager ^0.5.1

## 新增依赖计划
dio, flutter_local_notifications, html (HTML解析)

## 项目结构
lib/
├── main.dart (入口+窗口/托盘监听)
├── app.dart (NavigationView 6项: 主页/教务/信息/快速跳转 + footer: 设置/关于)
├── pages/ (home, academic, info, quick_links, settings, about, lock, agreement)
└── services/ (password_service, storage_service, tray_service)

## 新模块文件规划
lib/services/
├── http_service.dart     — dio 封装（单例，拦截器，超时，错误处理）
├── notification_service.dart — Windows 系统通知封装
├── web_content_service.dart  — 网页内容获取+HTML解析
├── data_service.dart     — 结构化数据CRUD+清理（基于SharedPreferences+JSON）

## 约束
- 所有新增第三方库加入关于页开源列表
- fluent_ui 组件约束: titleBar非appBar, .withValues(alpha:x)非.withOpacity(), PaneDisplayMode无open
- 字体: MiSans (Regular/Medium:500/Bold:700/Semibold:600/Light:300 全已注册)
- 主题: ThemeMode.system, accentColor: Colors.blue, fontFamily: 'MiSans'
- 暗色模式 Logo 容器硬编码 0xFFF3F3F3 需适配
- AGENTS.md: 中文注释20-50%, commit格式 type(scope): 中文摘要, 不主动push
- Python文件头/函数注释按AGENTS.md规定（本项目Flutter不涉及）
- Dart文件头按AGENTS.md 6.7.1格式

## 关于页开源列表
当前在 about_page.dart 中，需要添加 dio, flutter_local_notifications, html 等

## 进度
正在开始实现 1.1 网络请求模块
