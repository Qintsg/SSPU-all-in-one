# 变更日志

<!-- markdownlint-disable MD024 -->

本文档遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/) 规范，版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

---

## [0.2.2-alpha+4] - 2026-04-25

### 修复

- macOS 启动阶段托盘初始化失败时降级为无托盘模式，避免托盘异常中断主窗口启动导致应用无法打开
- macOS 托盘图标路径补充 App.framework 与 Resources 下的 Flutter assets 候选路径，并保留跨平台回退路径

### 发布

- 以 `0.2.2-alpha+4` 重新发布 alpha hotfix 构建批次，使用 `v0.2.2-alpha` Tag，并通过完整版本号区分新产物

## [0.2.2-alpha+3] - 2026-04-24

### 修复

- Android release 构建将 `compileSdk` 提升到至少 34，修复 `flutter_secure_storage` 依赖链中的 AndroidX AAR metadata 要求 API 34 以上导致 APK 构建失败的问题
- Android release 构建补充 Tink 编译期注解类的 R8 `dontwarn` 规则，修复 release shrink 阶段因缺少注解类而中断的问题

### 发布

- 以 `0.2.2-alpha+3` 重新发布 alpha 构建批次，使用 `v0.2.2-alpha` Tag，并通过完整版本号区分新产物

## [0.2.2-alpha+2] - 2026-04-24

### 修复

- Release 工作流的 Linux x64 / arm64 构建依赖补齐 `libsecret-1-dev`，修复 `flutter_secure_storage_linux` 在 CMake 阶段找不到 `libsecret-1>=0.18.4` 导致 Linux 产物构建失败的问题

### 发布

- 以 `0.2.2-alpha+2` 重新发布 alpha 构建批次，使用 `v0.2.2-alpha` Tag，并通过完整版本号区分新产物

## [0.2.2-alpha] - 2026-04-24

### 新增

- 微信推文认证卡片新增“打开配置文件所在文件夹”入口，并保留使用系统默认应用打开 `wxmp_config.toml`
- 快速跳转页新增搜索框，支持名称 / URL 精确匹配、模糊匹配和校园服务意图匹配，并可直接打开最佳匹配结果
- 安全设置页新增教务凭据本地保存入口，支持学工号、OA 密码、体育部查询密码和邮箱密码的加密存储与填写状态提示

### 变更

- 移除设置页中的 VS Code 专用配置文件入口，统一改为使用系统默认文件管理器打开配置目录
- 同步 Release PR 发布说明章节校验规则，确保工作流可从 PR 正文生成规范化的 `release-notes.md`

### 修复

- 修复 Android 启动前等待本地状态目录、通知和自动刷新初始化导致首帧无法渲染、界面纯白的问题
- 修复微信公众号平台认证信息提取与配置文件编辑流程，避免无效认证状态影响刷新链路
- 优化配置入口异常提示和相关测试命名，降低配置文件打开失败时的排查成本
- 修复 Windows arm64 Release 构建中 JDK 架构与 Flutter Windows toolchain 不一致导致 `jni` 插件链接失败的问题

## [0.2.1-alpha] - 2026-04-23

### 修复

- 恢复 Android `applicationName` 注入，重新启用 Flutter 默认插件注册链路，修复安装后启动黑屏的问题
- 回退错误的 Android 自适应启动图标资源引用，恢复应用图标显示，避免系统回退到默认安卓图标

## [0.2.0-alpha] - 2026-04-23

### 新增

- 快速跳转改为读取仓库内 YAML 配置，支持后续维护分组、链接和可选自定义图标
- 微信公众号平台支持本地 `wxmp_config.toml` 高级配置文件，并在设置页提供打开与重新加载入口
- 信息中心官网刷新增加进度反馈与分渠道增量合并，刷新过程中保留当前列表并逐步显示已解析的新内容
- 新增“信息网页接入请求”Issue 模板，便于统一收集学院 / 部门官网名称、栏目列表页 URL、解析结构与验收标准
- 接通信息中心自动刷新与推送配置，支持官网渠道和微信公众号分别设置刷新间隔，并在设置变更后即时重载定时器
- 消息推送设置页新增一键全开、一键全关操作，支持职能部门、教学单位和微信推文分区快速切换
- README 与使用文档补充各平台 Release 产物位置、分发方式与 Android 本地签名说明
- Release 工作流新增 Windows arm64 安装器与 Linux x64/arm64 的 `.deb` 安装包产物
- Windows arm64 / Linux arm64 公开发布矩阵提升为与 x64 同级，自动进入正式 Release 资产清单
- 新增 `docs/RELEASE.md`，统一版本来源、Tag 规则、资产命名、平台矩阵、Release Notes 模板与发布门槛
- 新增发布说明提取与元数据生成脚本，自动产出 `release-notes.md`、`manifest.json` 与 `SHA256SUMS.txt`
- 新增 Release 申请 Issue 模板与复合 action，统一发布版本解析和 Release 元数据生成

### 变更

- Android 构建链升级到 Gradle 9.4.1，并同步将 Android Gradle Plugin 调整到兼容的 8.13.2
- Android release 构建改为优先读取本地 `key.properties` 中的签名配置，缺失时回退到 debug 签名
- 关于页版本号改为运行时读取应用包信息，README 徽章改为直接从 `pubspec.yaml` 动态取值
- 完善设置页“微信推文消息获取”操作逻辑，补齐公众号平台刷新设置、认证入口与 SSPU 微信矩阵展示
- 将用户设置、认证信息、文章缓存和 WebView2 运行态统一收敛到 `~/.sspu-all-in-one/`
- 将微信推文高级配置文件入口合并到公众号平台认证卡片，扫码登录成功后自动更新 `wxmp_config.toml`
- 删除设置页微信推文中的独立搜索公众号卡片和已关注公众号卡片，关注入口收敛到 SSPU 微信矩阵
- 信息中心刷新进度改为服务层状态，切换页面后仍会保留官网消息和微信推文刷新进度
- 微信推文默认刷新条数调整为 10，并按 SSPU 微信矩阵中的公众号开关过滤抓取范围
- 完善设置页“消息推送（官网）”操作逻辑，将职能部门 / 教学部门渠道调整为分组级刷新设置、网站总开关和内容分类按钮
- 删除微信读书接入方式，统一改为通过公众号平台获取微信公众号文章，并在信息中心未完成认证时禁用对应刷新按钮
- 将信息公开网“最新公开信息”在应用内显示为“公开信息”，并将渠道设置调整为一级列表直接操作开关、刷新间隔和子分类开关
- 学校官网接入“学校新闻 / 通知公告 / 校内活动”三个栏目，其中校内活动改用官网动态接口解析
- 教务处接入“教学动态 / 学生专栏 / 教师专栏”三个栏目，并进入文章页读取精确发布时间
- 将信息技术中心单一分类显示为“消息”
- 将体育部分类显示为“通知公告 / 部门动态”
- 体育部进入文章页读取精确发布时间，并将保卫处分类显示为“动态/通知 / 宣教专栏”
- 将校区建设办统一显示为“基建处”，并改为解析“建设要闻 / 通知公告”列表页
- 新闻网改为解析“综合新闻”列表页并支持翻页
- 学生处改为解析“学工要闻 / 通知公告”列表页，并校正通知分类显示名称
- 计算机与信息工程学院改为聚合解析“工作动态 / 教师工作 / 学生工作”多个子栏目
- 智能制造与控制工程学院改为聚合解析“学院动态 / 教学科研 / 通知公告”列表页
- 资源与环境工程学院改为聚合解析“新闻资讯 / 通知公告 / 科研与服务 / 党建思政”列表页
- 能源与材料学院改为聚合解析“新闻资讯 / 通知与公告 / 育人园地 / 科学研究”列表页
- 经济与管理学院改为聚合解析“学院动态 / 通知公告 / 育人园地 / 党群引领”列表页
- 语言与文化传播学院改为聚合解析“新闻动态 / 学院公告 / 学生活动 / 讲座信息”列表页
- 数理与统计学院改为聚合解析“学院新闻 / 学院公告 / 学术动态 / 育人园地”列表页，并进入文章页读取精确发布时间
- 职业技术教师教育学院改为聚合解析“新闻动态 / 通知公告”列表页
- 国际教育中心改为聚合解析“新闻 / 公告”列表页
- 继续教育学院改为聚合解析“学院新闻 / 学院公告”列表页
- 职业技术学院改为聚合解析“学院新闻 / 学院公告”列表页
- 马克思主义学院改为聚合解析“学院新闻 / 通知公告 / 学术科研 / 教育教学”列表页
- 新增工程训练与创新教育中心来源，并解析“中心动态 / 通知公告”两个栏目
- 新增后勤服务中心、外国留学生事务办公室、国际交流处、招生办、人事处、科研处、校工会、党委组织部、党委统战部、党委办公室、校团委、资产与实验管理处来源，研究生处改为解析指定“动态”列表页，并补齐快速跳转入口
- 集成电路学院、智能医学与健康工程学院、艺术与设计学院、创新创业教育中心、图书馆、艺术教育中心改为解析用户指定栏目列表页，并补齐对应分类筛选

### 修复

- 收敛 Android 侧静态检查噪声，补齐启动图标自适应资源，并将 `AndroidManifest.xml` 中的类引用改为确定值
- 微信公众号刷新按页获取每个公众号的推文直到达到条数上限或遇到已存文章，并为桌面端退出步骤增加超时兜底
- 微信公众号刷新前增加公众号平台认证有效性校验，避免失效 Cookie / Token 继续进入刷新链路
- 放宽设置页刷新文章个数输入框宽度，修复三类消息推送设置页数字显示不全的问题
- 微信推文手动刷新支持逐公众号合并新内容并更新进度条，同时将按钮文案调整为“刷新最新微信推文”
- 设置页在窄屏设备改用顶部下拉切换分区，避免固定左侧导航挤压内容导致移动端出框
- 优化微信公众平台认证状态检测，增加脱敏调试日志和认证状态诊断，避免无效 Token 被误判为可用
- 将 macOS Flutter Debug / Release xcconfig wrapper 纳入版本控制，修复新检出后 `flutter run -d macos` 找不到 Flutter 配置文件的问题
- 过滤官网解析中的 `javascript:` 等无效链接，并为 WebView 增加非法 URL 兜底页，避免点击消息时崩溃
- 将自动打标中的 `release` 标签更名为 `release-files`，避免仓库治理 / 安装器 / Release 配置类 PR 在合并时误触发发布工作流
- 调整 `develop` / `main` 同步策略：移除导致历史持续分叉的线性历史要求，并明确同步 PR 必须使用 merge commit
- 统一桌面端退出流程，修复 Windows 点击关闭后选择“退出应用”时窗口未响应、退出失败的问题
- 为移动端竖屏手机切换到底部导航，并为窄屏保留顶栏入口，修复低 DPI 竖屏下导航栏缺失的问题
- 为 Linux Release 显式补齐并校验主程序可执行权限，同时补充压缩包解压与 `chmod +x` 使用说明
- 收窄“刷新官网消息”的手动刷新范围，避免微信公众号抓取串入官网刷新链路导致信息中心长时间卡在加载状态
- 为 macOS Debug / Release entitlements 补充 `com.apple.security.network.client`，修复官网刷新与内嵌 WebView 页面统一空白的问题
- 修复 Release 版本解析会丢失 `+BUILD`、Tag 与资产命名不一致、Web / Linux / Android 公开产物不符合发布规则的问题
- 修复最新 Release workflow 中 Windows arm64 / Linux arm64 依赖 `subosito/flutter-action` 获取不存在的 stable arm64 bundle 而失败的问题，改为从官方 `flutter/flutter` 仓库检出指定 tag 并在 runner 本机预缓存 SDK

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
- PR 模板补充标准 Release Notes 章节，带 `release` 标签的 PR merge 后直接作为 GitHub Release 正文来源
- Labeler 标签拆分为 `ci`、`release`、`governance`、`dependencies` 等更细粒度规则
- Dependabot 默认向 `develop` 提交分组升级 PR，减少依赖更新噪音并贴合分支流转
- Issue 配置关闭空白提单入口，并补充文档导向链接
- PR CI 调整为仅执行 `flutter analyze`，并对带 `release` 标签的 PR 追加发布分支与发布说明模板校验
- Release 工作流改为从 `pubspec.yaml` 读取完整版本号，统一生成 Android/Windows/macOS/Linux/Web 公开资产与校验文件
- Release 工作流新增 Windows arm64、Linux arm64 正式构建与打包步骤，删除独立实验性架构发布分叉
- 预发布 Release 的目标分支约束调整为允许 `main`、`develop` 与 `release/*`，并同步到 CI、Release workflow 与仓库模板
- 依赖升级：`package_info_plus` 升级到 `10.1.0`，并同步刷新锁文件中的 `package_info_plus_platform_interface` 与 `win32`
- `Build & Release` 工作流新增 `workflow_dispatch` 手动触发入口，支持显式传入目标分支与 Release Notes

### 修复

- 修复 Release 工作流中的 macOS DMG 打包路径错误，改为自动发现真实 `.app` 产物
- 修复 Windows 安装器编译依赖宿主机缺失中文语言文件导致的发布失败
- 修复 Windows arm64 Release 安装器脚本中的 Inno Setup 架构标识，恢复为当前编译器支持的 `arm64`
- 修复 Windows arm64 Release workflow 对 Flutter 输出目录的硬编码假设，改为构建后自动定位主程序目录并传入 Inno Setup
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
