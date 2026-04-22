# 变更日志

<!-- markdownlint-disable MD024 -->

本文档遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/) 规范，版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

---

## [Unreleased]

### 新增

- 接通信息中心自动刷新与推送配置，支持官网渠道和微信公众号分别设置刷新间隔，并在设置变更后即时重载定时器

### 变更

- 将信息公开网“最新公开信息”在应用内显示为“公开信息”，并将渠道设置调整为一级列表直接操作开关、刷新间隔和子分类开关
- 学校官网接入“学校新闻 / 通知公告 / 校内活动”三个栏目，其中校内活动改用官网动态接口解析
- 将体育部第二分类从“体育赛事”校正为官网栏目名称“部门动态”
- 校区建设办改为解析“建设要闻 / 通知公告”栏目列表页，支持翻页与完整日期

### 修复

- 将自动打标中的 `release` 标签更名为 `release-files`，避免仓库治理 / 安装器 / Release 配置类 PR 在合并时误触发发布工作流
- 调整 `develop` / `main` 同步策略：移除导致历史持续分叉的线性历史要求，并明确同步 PR 必须使用 merge commit
- 统一桌面端退出流程，修复 Windows 点击关闭后选择“退出应用”时窗口未响应、退出失败的问题
- 为移动端竖屏手机切换到底部导航，并为窄屏保留顶栏入口，修复低 DPI 竖屏下导航栏缺失的问题
- 为 Linux Release 显式补齐并校验主程序可执行权限，同时补充压缩包解压与 `chmod +x` 使用说明
- 收窄“刷新官网消息”的手动刷新范围，避免微信公众号抓取串入官网刷新链路导致信息中心长时间卡在加载状态
- 为 macOS Debug / Release entitlements 补充 `com.apple.security.network.client`，修复官网刷新与内嵌 WebView 页面统一空白的问题

## [0.1.5-alpha] - 2026-04-21

### 新增

- Release 新增 Windows x64 / arm64 安装器、Android arm32 / arm64 / x64 APK、iOS arm64 未签名应用包、macOS universal DMG、Linux x64 / arm64 压缩包、Web JavaScript / WebAssembly 压缩包
- Issue 模板升级为表单式模板，补充平台、环境、复现、日志、验收标准等必填信息
- 补充分支命名规范与目标分支约定，明确 `main` / `develop` 的回合并要求

### 变更

- Flutter 工具链升级到 `3.41.7`，Dart SDK 基线升级到 `3.11.5`
- `window_manager` 升级到 `0.5.1`，同步刷新锁文件与桌面插件注册产物
- GitHub Actions 依赖升级到当前最新稳定标签（`actions/checkout@v6.0.2`、`upload-artifact@v7.0.1`、`download-artifact@v8.0.1` 等）
- PR CI 精简为 `flutter analyze`，草稿 PR 仅保留自动标签工作流
- GitHub Actions 官方 action 升级到 Node.js 24 runtime 兼容版本，消除 Node.js 20 deprecation warning
- 删除 CodeQL PR 安全扫描工作流
- 移除 PR 阶段跨平台 build check，平台构建集中到 Release 工作流
- PR 模板补充风险、回滚、验证记录、发布说明与回合并检查项
- Labeler 标签拆分为 `ci`、`release`、`governance`、`dependencies` 等更细粒度规则
- Dependabot 默认向 `develop` 提交分组升级 PR，减少依赖更新噪音并贴合分支流转
- Issue 配置关闭空白提单入口，并补充文档导向链接

### 修复

- 修复 Release 工作流中的 macOS DMG 打包路径错误，改为自动发现真实 `.app` 产物
- 修复 Windows 安装器编译依赖宿主机缺失中文语言文件导致的发布失败
- 暂时收敛未验证的 Windows arm64 / Linux arm64 桌面发布矩阵，避免 Release 因官方 Flutter SDK 架构解析失败而整体中断
- 修复 macOS Runner 的 Xcode 配置引用错误，恢复 Flutter 生成配置与 CocoaPods 支持文件的正确加载，解决 `flutter build macos` 编译失败问题
- 修复 Android 启动阶段调用桌面插件导致黑屏闪退的问题，并同步 Android / iOS / macOS / Linux / Web 的应用名称与图标资源

---

## [0.0.1-alpha] - 2026-04-18

### 新增

- 初始化 Flutter 项目，支持 Android / iOS / macOS / Linux / Windows / Web 全平台
- 项目基础结构与配置
- MIT 许可证
- README.md 项目文档
- AGENTS.md 代理工作规范
- docs/ 文档目录（API.md、CHANGELOG.md）
- .gitignore 版本控制忽略规则
- Fluent 2 设计风格前端页面驾架（主页、教务中心、信息中心、快速跳转、设置）
- NavigationView 侧边栏导航 + EntrancePageTransition 页面切换动画
- 密码保护功能（SHA-256 哈希本地存储，设置/修改/移除）
- 1Password 风格锁定页（抨动动画、自动聚焦）
- 深色/浅色主题自动跟随系统
