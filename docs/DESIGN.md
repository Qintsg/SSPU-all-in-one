# SSPU All-in-One 设计文档

> 版本：v0.0.1-alpha | 最后更新：2026-04-18

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
| 框架 | Flutter | SDK ^3.11.1 | 跨平台 UI 框架 |
| 语言 | Dart | SDK ^3.11.1 | 随 Flutter SDK 绑定 |
| UI 组件库 | fluent_ui | ^4.11.1 | 微软 Fluent Design 风格 Widget |
| 本地存储 | shared_preferences | ^2.5.3 | 键值对持久化（设置、密码哈希等） |
| 加密 | crypto | ^3.0.6 | SHA-256 哈希（密码安全存储） |
| 代码规范 | flutter_lints | ^6.0.0 | Dart 推荐 lint 规则集 |

---

## 2. 应用架构

### 2.1 整体结构

```
┌─────────────────────────────────────────────┐
│                  main.dart                   │
│         应用入口 / 密码保护决策               │
│  ┌─────────────┐     ┌───────────────────┐  │
│  │  LockPage   │     │     AppShell      │  │
│  │  锁定页面    │────▶│  主导航骨架        │  │
│  └─────────────┘     └───────────────────┘  │
│                            │                │
│         ┌──────────────────┼──────────┐     │
│         ▼          ▼       ▼          ▼     │
│    ┌────────┐ ┌────────┐ ┌────────┐ ┌────┐ │
│    │ 主页   │ │教务中心│ │信息中心│ │ …  │ │
│    └────────┘ └────────┘ └────────┘ └────┘ │
│                                             │
│  ┌─────────────────────────────────────┐    │
│  │       PasswordService (服务层)       │    │
│  │  SHA-256 哈希 + shared_preferences  │    │
│  └─────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
```

### 2.2 分层说明

| 层级 | 目录 | 职责 |
|------|------|------|
| 入口层 | `lib/main.dart` | 应用初始化、FluentApp 配置、密码保护路由决策 |
| 导航层 | `lib/app.dart` | NavigationView 侧边栏导航管理、页面切换动画 |
| 页面层 | `lib/pages/` | 各业务页面的 UI 与交互逻辑 |
| 服务层 | `lib/services/` | 与 UI 无关的业务逻辑（密码管理、数据服务等） |

### 2.3 启动流程

```
应用启动
  │
  ▼
WidgetsFlutterBinding.ensureInitialized()
  │
  ▼
runApp(SSPUApp)
  │
  ▼
_checkPasswordProtection()
  │
  ├── 未设置密码 ──▶ _isUnlocked = true ──▶ AppShell（主界面）
  │
  └── 已设置密码 ──▶ _isUnlocked = false ──▶ LockPage（锁定页）
                                                │
                                                ▼
                                          用户输入密码
                                                │
                                          PasswordService.verifyPassword()
                                                │
                                          ├── 正确 ──▶ onUnlocked() ──▶ AppShell
                                          └── 错误 ──▶ 抖动动画 + 重试
```

---

## 3. 导航系统

### 3.1 NavigationView 结构

应用使用 fluent_ui 的 `NavigationView` 组件实现侧边栏导航，配合 `NavigationPane` 管理导航项。

| 导航项 | 图标 | 位置 | 对应页面 |
|--------|------|------|----------|
| 主页 | `FluentIcons.home` | 主区域 | `HomePage` |
| 教务中心 | `FluentIcons.education` | 主区域 | `AcademicPage` |
| 信息中心 | `FluentIcons.info` | 主区域 | `InfoPage` |
| 快速跳转 | `FluentIcons.link` | 主区域 | `QuickLinksPage` |
| 设置 | `FluentIcons.settings` | 底部 footer | `SettingsPage` |

### 3.2 显示模式

导航栏使用 `PaneDisplayMode.auto`，根据窗口宽度自动切换：

- **宽屏**（>= 1008px）：展开模式（`open`），显示图标+文字
- **中屏**（640–1008px）：紧凑模式（`compact`），仅显示图标
- **窄屏**（< 640px）：最小化模式（`minimal`），汉堡菜单

### 3.3 页面切换动画

所有页面切换使用 `EntrancePageTransition`，提供从右侧滑入的入场动画效果，与 Fluent 2 设计规范一致。

---

## 4. 页面设计

### 4.1 主页（HomePage）

**文件**：`lib/pages/home_page.dart`

**当前状态**：占位骨架

**功能规划**：
- 欢迎信息展示
- 最新消息摘要

**UI 结构**：
- `ScaffoldPage.scrollable` 作为页面容器
- `PageHeader` 显示页面标题
- `Card` 组件包裹内容区域

### 4.2 教务中心（AcademicPage）

**文件**：`lib/pages/academic_page.dart`

**当前状态**：占位骨架

**功能规划**：
- 课表查询与展示
- 成绩查询（按学期筛选）
- 考试安排
- GPA 计算器
- 学分统计

### 4.3 信息中心（InfoPage）

**文件**：`lib/pages/info_page.dart`

**当前状态**：占位骨架

**功能规划**：
- 校园通知聚合
- 微信公众号推文抓取
- 官网资讯整合
- 消息分类（教务、学工、行政、活动）
- 离线缓存支持

### 4.4 快速跳转（QuickLinksPage）

**文件**：`lib/pages/quick_links_page.dart`

**当前状态**：占位骨架

**功能规划**：
- 常用校园网站收藏
- 服务平台快捷入口（教务系统、图书馆、邮箱等）
- 自定义链接管理
- 链接分组与排序

### 4.5 设置页（SettingsPage）

**文件**：`lib/pages/settings_page.dart`

**当前状态**：已实现密码保护功能

**功能模块**：

#### 4.5.1 安全设置

- **密码保护开关**：`ToggleSwitch` 控制启用/禁用
  - 开启时弹出"设置密码"对话框
  - 关闭时弹出"移除密码"对话框（需验证当前密码）
- **修改密码**：仅在已设置密码时显示，需验证旧密码

#### 4.5.2 关于

- 显示应用版本号
- 显示学校名称
- 显示数据本地化声明

### 4.6 锁定页（LockPage）

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

在 `main.dart` 的 `FluentApp` 中统一配置：

| 属性 | 值 | 说明 |
|------|------|------|
| `theme` | `FluentThemeData(brightness: Brightness.light)` | 浅色主题 |
| `darkTheme` | `FluentThemeData(brightness: Brightness.dark)` | 深色主题 |
| `themeMode` | `ThemeMode.system` | 自动跟随系统设置 |
| `accentColor` | `Colors.blue` | 强调色 |
| `visualDensity` | `VisualDensity.adaptivePlatformDensity` | 自适应平台密度 |

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
├── main.dart                    # 应用入口，FluentApp 配置，密码保护决策
├── app.dart                     # NavigationView 导航骨架，页面切换动画
├── pages/
│   ├── home_page.dart           # 主页（占位）
│   ├── academic_page.dart       # 教务中心（占位）
│   ├── info_page.dart           # 信息中心（占位）
│   ├── quick_links_page.dart    # 快速跳转（占位）
│   ├── settings_page.dart       # 设置页（已实现密码保护管理）
│   └── lock_page.dart           # 锁定页（已完整实现）
└── services/
    └── password_service.dart    # 密码管理服务
```

---

## 9. 待实现功能清单

| 优先级 | 功能 | 涉及页面 | 依赖 |
|--------|------|----------|------|
| P0 | 主页内容填充 | HomePage | 无 |
| P0 | 教务系统对接 | AcademicPage | 教务 API 或网页抓取 |
| P1 | 校园信息聚合 | InfoPage | RSS / API / 爬虫 |
| P1 | 快速链接管理 | QuickLinksPage | 本地存储 |
| P2 | 多语言支持 | 全局 | flutter_localizations |
| P2 | 主题自定义 | SettingsPage | 状态管理 |
| P2 | 数据导出/备份 | SettingsPage | 文件系统 |

---

## 10. 安全设计约束

1. **密码不以明文存储**：始终使用 SHA-256 哈希
2. **加盐防御**：防止彩虹表攻击
3. **数据不离开设备**：shared_preferences 仅写入本地文件系统
4. **无远程通信**：当前版本不发起任何网络请求
5. **无敏感信息日志**：密码验证过程不输出到控制台
