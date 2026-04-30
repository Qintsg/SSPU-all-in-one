# SSPU All-in-One 设计文档

> 版本：v0.2.2-alpha+4 | 最后更新：2026-04-25

---

## 1. 项目概述

### 1.1 项目定位

SSPU All-in-One 是面向上海第二工业大学（SSPU）师生的校园综合服务应用。目标是将分散在多个官网、微信公众号、教务系统中的校园信息和服务聚合到一个客户端中，提供统一、高效的使用体验。

### 1.2 核心原则

- **数据本地化**：所有用户数据仅保留在设备本地，不上传至任何云端服务
- **全平台覆盖**：基于 Flutter 构建，支持 Android、iOS、macOS、Linux、Windows、Web 六大平台
- **Fluent 2 设计语言**：采用微软 Fluent Design System 2 风格，提供现代、一致的视觉体验

### 1.3 技术选型

| 层级 | 技术 | 版本约束 | 说明 |
|------|------|----------|------|
| 框架 | Flutter | >= 3.41.7 | 跨平台 UI 框架 |
| 语言 | Dart | ^3.11.5 | 随 Flutter SDK 绑定 |
| UI 组件库 | fluent_ui | ^4.11.1 | 微软 Fluent Design 风格 Widget |
| 本地存储 | shared_preferences / path_provider | ^2.5.3 / ^2.1.5 | 键值迁移与平台应用目录解析 |
| 加密 | crypto / flutter_secure_storage | ^3.0.6 / ^8.1.0 | 应用锁密码哈希与可解密凭据安全存储 |
| 系统认证 | local_auth | ^3.0.1 | 可选系统快速验证，作为应用锁密码的本机认证辅助入口 |
| 网络请求 | dio | ^5.8.0+1 | 官网与公众号平台 HTTP 抓取 |
| 桌面集成 | window_manager / tray_manager | ^0.5.1 | 桌面窗口控制与系统托盘 |
| Windows WebView | flutter_inappwebview | ^6.1.5 | 文章页与公众号平台登录页 |
| 应用信息 | package_info_plus | ^10.1.0 | 运行时版本号与构建号读取 |
| 代码规范 | flutter_lints | ^6.0.0 | Dart 推荐 lint 规则集 |

---

## 2. 应用架构

### 2.1 整体结构

```
┌─────────────────────────────────────────────────────────────┐
│                          main.dart                           │
│ WebView2 / Storage / Tray / Notification / AutoRefresh 初始化 │
├─────────────────────────────────────────────────────────────┤
│                         SSPUApp                              │
│          EULA 校验 / 密码保护 / 窗口关闭拦截 / 托盘监听        │
├─────────────────────────────────────────────────────────────┤
│                         AppShell                             │
│       Desktop NavigationView + Mobile BottomNavigation       │
├─────────────┬─────────────┬─────────────┬─────────────┬─────┤
│  HomePage   │ AcademicPage│  InfoPage   │QuickLinks   │ ... │
│  最新消息    │ 教务预览页   │ 官网/微信聚合 │ YAML 快捷跳转 │     │
├─────────────┴─────────────┴─────────────┴─────────────┴─────┤
│ Services: Password / MessageState / CampusNetwork / Wxmp /  │
│ InfoRefresh / AutoRefresh / Notification / Storage / AppInfo│
└─────────────────────────────────────────────────────────────┘
```

### 2.2 分层说明

| 层级 | 目录 | 职责 |
|------|------|------|
| 入口层 | `lib/main.dart` | 平台能力初始化、FluentApp 配置、EULA / 密码 / 托盘生命周期 |
| 导航层 | `lib/app.dart` | 桌面侧边栏导航、移动端底部导航、页面切换容器 |
| 页面层 | `lib/pages/` | 主页、教务、信息中心、设置、关于、登录 WebView 等页面 |
| 组件层 | `lib/widgets/` | 设置分区、消息项、频道列表、响应式布局等可复用 UI |
| 控制层 | `lib/controllers/` | 复杂分区状态协调，当前主要用于微信推文设置 |
| 服务层 | `lib/services/` | 状态持久化、抓取、自动刷新、通知、退出、应用信息等 |
| 模型 / 工具层 | `lib/models/`、`lib/utils/` | 消息模型、渠道配置、时间/匹配/WebView 环境工具 |

### 2.3 启动流程

```
应用启动
  │
  ▼
WidgetsFlutterBinding.ensureInitialized()
  │
  ▼
平台能力初始化
  ├── Windows: WebView2 环境
  └── 桌面端 windowManager + TrayService
  │
  ▼
runApp(SSPUApp)
  │
_initApp()
  ├── StorageService.init()
  ├── 检查 EULA 状态
  ├── 检查密码是否已设置
  └── 后台启动 NotificationService / AutoRefreshService
  │
  ├── 未同意 EULA ──▶ Agreement Dialog
  ├── 未设密码 ─────▶ AppShell（主界面）
  └── 已设密码 ─────▶ LockPage（锁定页）
                           │
                           ▼
                     PasswordService.verifyPassword()
                           │
                     ├── 正确 ──▶ AppShell
                     └── 错误 ──▶ 抖动动画 + 重试
```

---

## 3. 导航系统

### 3.1 NavigationView 结构

应用在桌面 / 平板使用 fluent_ui 的 `NavigationView`，在手机竖屏切换为自定义底部导航栏。

| 导航项 | 图标 | 位置 | 对应页面 |
|--------|------|------|----------|
| 主页 | `FluentIcons.home` | 主区域 | `HomePage` |
| 教务中心 | `FluentIcons.education` | 主区域 | `AcademicPage` |
| 信息中心 | `FluentIcons.info` | 主区域 | `InfoPage` |
| 快速跳转 | `FluentIcons.link` | 主区域 | `QuickLinksPage` |
| 设置 | `FluentIcons.settings` | 底部 footer | `SettingsPage` |
| 关于 | `FluentIcons.info_solid` | 底部 footer | `AboutPage` |

应用桌面 / 平板侧边导航在“设置”上方显示校园网 / VPN 状态徽标，启动后自动检测一次，点击徽标可重新检测。当前默认通过只读访问 `https://tygl.sspu.edu.cn/` 判断校园受限资源是否可达。

### 3.2 显示模式

桌面布局使用 `PaneDisplayMode.auto`，移动端额外根据方向切换导航组件：

- **宽屏**（>= 1008px）：展开模式（`open`），显示图标+文字
- **中屏**（640–1008px）：紧凑模式（`compact`），仅显示图标
- **窄屏桌面/平板**（< 640px）：最小化模式（`minimal`），汉堡菜单
- **手机竖屏**：底部导航栏（`_MobileBottomNavigationShell`）

### 3.3 页面切换动画

所有主页面切换使用 `EntrancePageTransition`；手机底部导航通过 `KeyedSubtree` 强制刷新当前页，保持切换后的内容状态与动画一致。

---

## 4. 页面设计

### 4.1 主页（HomePage）

**文件**：`lib/pages/home_page.dart`

**当前状态**：已实现

**已实现功能**：
- 欢迎信息展示
- 最新消息摘要
- 最新 5 条消息本地读取与排序
- 点击消息后标记已读并打开内嵌 WebView

**UI 结构**：
- `ScaffoldPage.scrollable` 作为页面容器
- `PageHeader` 显示页面标题
- `Card` 组件包裹内容区域

### 4.2 教务中心（AcademicPage）

**文件**：`lib/pages/academic_page.dart`

**当前状态**：功能预览页

**当前状态说明**：
- 课表查询与展示
- 成绩查询（按学期筛选）
- 考试安排
- GPA 计算器
- 学分统计
- 当前以服务卡片形式展示规划入口，尚未接入真实教务系统

### 4.3 信息中心（InfoPage）

**文件**：`lib/pages/info_page.dart`

**当前状态**：核心页面已实现

**已实现能力**：
- 官网 / 职能部门 / 教学单位 / 微信推文聚合
- 搜索、来源类型、来源名称、分类、未读筛选
- 分页浏览、全部标已读
- 官网消息刷新与微信推文刷新
- 刷新进度条与单例刷新状态保持
- 本地缓存持久化与已读状态管理

### 4.4 快速跳转（QuickLinksPage）

**文件**：`lib/pages/quick_links_page.dart`

**当前状态**：已实现

**已实现能力**：
- 从 `assets/config/quick_links.yaml` 读取分组链接
- 支持快捷入口名称、URL 与校园服务意图搜索
- 按设备宽度响应式布局磁贴
- 根据名称自动推断图标与强调色
- 点击后通过默认浏览器打开外部链接

### 4.5 设置页（SettingsPage）

**文件**：`lib/pages/settings_page.dart`

**当前状态**：已实现多分区设置页

**功能模块**：

#### 4.5.1 常规设置

- **关闭按钮行为**：支持每次询问 / 最小化到托盘 / 直接退出
- **消息推送总开关**：控制自动刷新后的桌面通知
- **勿扰时段**：设置开始/结束时间，通知服务按时间窗静默

#### 4.5.2 自动刷新设置

- **校园网 / VPN 状态检测间隔**：默认 15 分钟，可关闭自动检测；关闭后仍可点击导航栏状态徽标手动检测
- **体育查询自动刷新**：默认关闭，可配置教务中心课外活动考勤卡片的自动读取间隔；关闭后仍可在卡片右下角手动刷新并查看上次刷新时间
- **自动刷新快捷入口**：提供职能部门、教学单位、微信推文三个入口，跳转到对应分区顶部的自动刷新设置面板

#### 4.5.3 安全设置

- **密码保护开关**：`ToggleSwitch` 控制启用/禁用
  - 开启时弹出"设置密码"对话框
  - 关闭时弹出"移除密码"对话框（需验证当前密码）
- **修改密码**：仅在已设置密码时显示，需验证旧密码
- **系统快速验证**：仅在密码保护已开启且 Android / iOS / macOS / Windows 设备支持系统认证时显示开关；不可用或未配置时显示密码兜底提示，不改变手动密码解锁语义
- **立即上锁**：不退出应用，直接回到锁定页
- **教务凭据**：保存学工号、OA 密码、体育部查询密码和邮箱密码，密码框回访时保持为空，仅显示“已填写 / 未填写”
- **清理信息中心缓存**：只清理消息缓存与已读状态
- **清除所有本地数据**：清空状态文件、教务安全存储项并退出应用

#### 4.5.4 消息推送设置

- **职能部门**：按渠道分组展示开关、刷新间隔、分类开关
- **教学单位**：按学院 / 中心分组管理抓取与筛选
- **微信推文**：公众号平台认证、刷新配置、SSPU 微信矩阵关注与单号开关

### 4.6 关于页（AboutPage）

**文件**：`lib/pages/about_page.dart`

**当前状态**：已实现

**已实现能力**：
- 运行时读取 `PackageInfo` 展示版本号
- 展示作者与许可证
- 提供 GitHub 仓库与使用协议入口
- 展示使用/参考的开源项目列表

### 4.7 锁定页（LockPage）

**文件**：`lib/pages/lock_page.dart`

**当前状态**：已完整实现

**设计参考**：1Password 锁定页面

**功能细节**：

| 特性 | 实现方式 |
|------|----------|
| 密码输入 | `PasswordBox`，支持 `peekAlways` 明文预览 |
| 自动聚焦 | `WidgetsBinding.addPostFrameCallback` 延迟请求焦点 |
| 回车提交 | `onSubmitted` 回调直接触发验证 |
| 错误提示 | 密码框下方红色文本 |
| 抖动动画 | `TweenSequence` 5段水平偏移，500ms，`easeInOut` 曲线 |
| 加载状态 | 验证中按钮显示 `ProgressRing` 并禁用 |
| 错误恢复 | 密码错误后自动清空输入、重新聚焦 |
| 主题适配 | 根据 `FluentTheme.brightness` 调整文字透明度 |
| 系统快速验证 | 若用户启用且当前设备支持，进入锁定页后优先请求系统认证；失败、取消、超时或不可用时回到手动密码 |

**抖动动画序列**：

```
  0 → -10 → +10 → -10 → +10 → 0
  (权重: 1 : 2 : 2 : 2 : 1)
```

---

## 5. 密码保护系统

### 5.1 架构设计

密码保护系统由三个组件协同工作：

```
PasswordService（核心服务）
      │
      ├──▶ LockPage（验证入口）
      │
      ├──▶ SettingsPage（管理入口）
      │
      └──▶ SystemAuthService（可选系统认证封装）
```

### 5.2 PasswordService

**文件**：`lib/services/password_service.dart`

**存储机制**：
- 后端：native 平台使用统一 JSON 状态文件，Web 平台使用 `shared_preferences` 浏览器存储保存同一份 JSON 状态；浏览器存储不可用时退回内存态保证启动
- 键名：`app_password_hash`
- 系统快速验证配置键名：`app_quick_auth_enabled`
- 存储格式：SHA-256 哈希字符串（64 位十六进制）

**安全设计**：
- 明文密码不落盘，仅存储哈希值
- 加盐哈希：`sspu_aio_salt_$<password>_$end`
- 哈希算法：SHA-256（来自 `crypto` 包）
- 系统快速验证只保存本地布尔开关，不保存、读取或记录 PIN、Face ID、Touch ID、生物识别模板等原始认证数据
- 修改密码和移除密码保护会同步清除 `app_quick_auth_enabled`，避免旧密码上下文下的快速验证配置继续生效

**API 接口**：

| 方法 | 签名 | 说明 |
|------|------|------|
| `isPasswordSet` | `static Future<bool>` | 检查是否已设置密码 |
| `setPassword` | `static Future<void> (String)` | 设置新密码 |
| `verifyPassword` | `static Future<bool> (String)` | 验证密码是否正确 |
| `removePassword` | `static Future<void>` | 移除密码保护 |
| `isQuickAuthEnabled` | `static Future<bool>` | 检查系统快速验证开关 |
| `setQuickAuthEnabled` | `static Future<void> (bool)` | 设置系统快速验证开关 |
| `clearQuickAuth` | `static Future<void>` | 清除系统快速验证配置 |

### 5.3 SystemAuthService

**文件**：`lib/services/system_auth_service.dart`

**平台支持**：
- Android / iOS / macOS / Windows：通过 `local_auth` 调用系统认证能力
- Linux / Web：直接返回不可用，不调用插件，设置入口隐藏且锁定页保留手动密码

**认证策略**：
- 不使用 `biometricOnly: true`，允许 Windows 和移动端按系统策略使用 PIN、密码或生物识别
- 启用 quick auth 前必须先输入当前应用密码，再成功完成一次系统认证
- 锁定页在 quick auth 启用且设备可用时自动优先请求系统认证，同时保留密码输入框和“解锁”按钮
- 系统认证失败、取消、超时或插件不可用时不清空密码、不退出应用，只提示用户使用手动密码

### 5.4 AcademicCredentialsService

**文件**：`lib/services/academic_credentials_service.dart`

**存储机制**：
- 后端：`flutter_secure_storage`，按平台委托系统安全存储能力
- Android：启用 `EncryptedSharedPreferences`
- iOS / macOS：使用系统 Keychain；macOS Runner 配置 `keychain-access-groups`
- Windows / Linux / Web：使用插件对应平台实现；Linux 打包需提供 `libsecret` 运行依赖

**安全设计**：
- 教务凭据需要后续解密登录外部网站，因此不能使用不可逆哈希
- 设置页只回填学工号，OA 密码、体育部查询密码和邮箱密码输入框始终为空
- 页面展示每个密码字段是否已保存，并提示数据加密存储在本地、不上传至云端
- 不使用 `readAll` / `deleteAll` 批量接口，清理时逐项删除已知键，保持 Windows 兼容性

**API 接口**：

| 方法 | 签名 | 说明 |
|------|------|------|
| `getStatus` | `Future<AcademicCredentialsStatus>` | 获取学工号和各密码填写状态 |
| `saveCredentials` | `Future<void> ({required String oaAccount, String? oaPassword, String? sportsQueryPassword, String? emailPassword})` | 保存账号和本次填写的密码，空密码不覆盖旧值 |
| `readSecret` | `Future<String?> (AcademicCredentialSecret)` | 读取指定密码原文 |
| `clearSecret` | `Future<void> (AcademicCredentialSecret)` | 清除指定密码字段 |
| `clearAll` | `Future<void>` | 清除全部教务凭据 |

### 5.5 密码操作流程

#### 设置密码

```
用户点击开关(开启)
  │
  ▼
ContentDialog: 输入密码 + 确认密码
  │
  ├── 密码为空 → 错误提示
  ├── 两次不一致 → 错误提示
  └── 通过验证 → PasswordService.setPassword() → 成功提示
```

#### 修改密码

```
用户点击"修改密码"
  │
  ▼
ContentDialog: 旧密码 + 新密码 + 确认新密码
  │
  ├── 旧密码验证失败 → 错误提示
  ├── 新密码为空 → 错误提示
  ├── 两次不一致 → 错误提示
  └── 全部通过 → PasswordService.setPassword() → 清除 quick auth → 成功提示
```

#### 移除密码

```
用户点击开关(关闭)
  │
  ▼
ContentDialog: 输入当前密码
  │
  ├── 验证失败 → 错误提示
  └── 验证通过 → PasswordService.removePassword() → 清除 quick auth → 成功提示
```

#### 启用系统快速验证

```
用户点击“系统快速验证”开关
  │
  ▼
检查密码保护已开启且 SystemAuthService.isAvailable() 为 true
  │
  ▼
ContentDialog: 输入当前密码
  │
  ├── 密码错误 / 取消 → 不启用
  └── 密码正确 → local_auth 系统认证
                      │
                      ├── 认证成功 → app_quick_auth_enabled = true
                      └── 失败 / 取消 / 超时 / 不可用 → app_quick_auth_enabled 清除，保留手动密码
```

#### 锁定页解锁

```
进入 LockPage
  │
  ├── quick auth 未启用或不可用 → 显示手动密码
  └── quick auth 已启用且可用 → 自动请求系统认证
                                  │
                                  ├── 成功 → AppShell
                                  └── 失败 / 取消 / 超时 → 手动密码仍可用
```

---

## 6. 主题系统

### 6.1 配置方式

在 `main.dart` 的 `FluentApp` 中统一接入 `FluentTokenTheme.light()` / `dark()`：

| 属性 | 值 | 说明 |
|------|------|------|
| `theme` | `FluentTokenTheme.light()` | 浅色主题 |
| `darkTheme` | `FluentTokenTheme.dark()` | 深色主题 |
| `themeMode` | `ThemeMode.system` | 自动跟随系统设置 |
| `fontFamily` | `MiSans` | 全局字体 |
| `typography` | Token 化字号/字重体系 | 标题、正文、说明文字统一 |

### 6.2 主题适配要求

- 所有页面的文字颜色、背景色必须通过 `FluentTheme.of(context)` 获取
- 半透明效果使用 `.withValues(alpha: x)` 方法
- 不硬编码颜色值（白色/黑色除外的主题依赖色）
- `Card`、`InfoBar` 等组件自动适配主题色

---

## 7. 国际化

### 7.1 当前状态

- 已配置 `FluentLocalizations.localizationsDelegates` 和 `supportedLocales`
- 当前界面文字使用硬编码中文
- 后续可接入 Flutter 国际化方案实现多语言切换

---

## 8. 目录结构

```
lib/
├── main.dart                         # 应用入口、平台初始化、EULA/锁定流程
├── app.dart                          # 桌面导航与移动端底部导航
├── controllers/
│   └── settings_wechat_controller.dart
├── models/                           # 渠道配置、消息模型、微信矩阵模型
├── pages/
│   ├── home_page.dart
│   ├── academic_page.dart
│   ├── info_page.dart
│   ├── quick_links_page.dart
│   ├── settings_page.dart
│   ├── about_page.dart
│   ├── lock_page.dart
│   ├── webview_page.dart
│   └── wxmp_login_page.dart
├── services/                         # 持久化、抓取、自动刷新、通知、退出、版本信息
├── theme/                            # Fluent 2 token 体系
├── utils/                            # WebView 环境、时间工具、微信匹配工具
└── widgets/                          # 设置分区、频道列表、响应式与消息项组件
```

---

## 9. 待实现功能清单

| 优先级 | 功能 | 涉及页面 | 依赖 |
|--------|------|----------|------|
| P0 | 教务真实接口接入 | AcademicPage | 教务系统鉴权与接口/网页抓取 |
| P0 | Android / 桌面 Release 持续集成完善 | 构建流程 | GitHub Actions / 平台签名材料 |
| P1 | 信息中心抓取源继续扩充 | InfoPage | 新站点解析规则 |
| P1 | 主页卡片扩展为可配置摘要面板 | HomePage | 本地状态与组件抽象 |
| P1 | 快速跳转支持用户自定义与排序 | QuickLinksPage | 本地配置写回 |
| P2 | 多语言支持 | 全局 | flutter_localizations |
| P2 | 数据导出/备份 | SettingsPage | 文件系统 |
| P2 | 发布安装器与签名公证完善 | 各平台 | 平台证书与打包工具 |

---

## 10. 安全设计约束

1. **应用锁密码不以明文存储**：始终使用 SHA-256 哈希
2. **加盐防御**：防止彩虹表攻击
3. **可解密凭据使用系统安全存储**：教务凭据不写入统一 JSON 状态文件，按平台使用 Keychain / Keystore / Credential Locker / libsecret 等能力
4. **系统快速验证不保存原始认证数据**：仅保存本地布尔配置，真实认证由操作系统和 `local_auth` 完成
5. **状态文件本地化**：桌面端保存在用户目录，移动端保存在系统分配的应用支持目录
6. **网络请求仅用于内容抓取**：当前版本会访问学校官网与微信公众平台，不上传用户业务数据到自建服务
7. **认证材料最小暴露**：公众号平台 Cookie / Token 仅保存在本地状态文件，不进入仓库
8. **发布签名不入库**：Android release keystore 通过本地文件或 CI Secrets 注入
9. **无敏感信息调试日志**：密码、教务凭据与微信认证敏感字段不输出到控制台
