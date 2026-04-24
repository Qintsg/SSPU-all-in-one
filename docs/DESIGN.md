# SSPU All-in-One 设计文档

> 版本：v0.2.1-alpha.2 | 最后更新：2026-04-24

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
| 加密 | crypto | ^3.0.6 | SHA-256 哈希（密码安全存储） |
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
│ Services: Password / MessageState / InfoRefresh / Wxmp /    │
│ AutoRefresh / Notification / Storage / AppExit / AppInfo    │
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

#### 4.5.2 安全设置

- **密码保护开关**：`ToggleSwitch` 控制启用/禁用
  - 开启时弹出"设置密码"对话框
  - 关闭时弹出"移除密码"对话框（需验证当前密码）
- **修改密码**：仅在已设置密码时显示，需验证旧密码
- **立即上锁**：不退出应用，直接回到锁定页
- **清理信息中心缓存**：只清理消息缓存与已读状态
- **清除所有本地数据**：清空状态文件并退出应用

#### 4.5.3 消息推送设置

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
      └──▶ SettingsPage（管理入口）
```

### 5.2 PasswordService

**文件**：`lib/services/password_service.dart`

**存储机制**：
- 后端：`shared_preferences`（键值对本地存储）
- 键名：`app_password_hash`
- 存储格式：SHA-256 哈希字符串（64 位十六进制）

**安全设计**：
- 明文密码不落盘，仅存储哈希值
- 加盐哈希：`sspu_aio_salt_$<password>_$end`
- 哈希算法：SHA-256（来自 `crypto` 包）

**API 接口**：

| 方法 | 签名 | 说明 |
|------|------|------|
| `isPasswordSet` | `static Future<bool>` | 检查是否已设置密码 |
| `setPassword` | `static Future<void> (String)` | 设置新密码 |
| `verifyPassword` | `static Future<bool> (String)` | 验证密码是否正确 |
| `removePassword` | `static Future<void>` | 移除密码保护 |

### 5.3 密码操作流程

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
  └── 全部通过 → PasswordService.setPassword() → 成功提示
```

#### 移除密码

```
用户点击开关(关闭)
  │
  ▼
ContentDialog: 输入当前密码
  │
  ├── 验证失败 → 错误提示
  └── 验证通过 → PasswordService.removePassword() → 成功提示
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

1. **密码不以明文存储**：始终使用 SHA-256 哈希
2. **加盐防御**：防止彩虹表攻击
3. **状态文件本地化**：桌面端保存在用户目录，移动端保存在系统分配的应用支持目录
4. **网络请求仅用于内容抓取**：当前版本会访问学校官网与微信公众平台，不上传用户业务数据到自建服务
5. **认证材料最小暴露**：公众号平台 Cookie / Token 仅保存在本地状态文件，不进入仓库
6. **发布签名不入库**：Android release keystore 通过本地文件或 CI Secrets 注入
7. **无敏感信息调试日志**：密码与微信认证敏感字段不输出到控制台
