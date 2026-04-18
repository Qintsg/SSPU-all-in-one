# SSPU All-in-One 使用文档

> 本文档面向开发者，说明项目在开发状态下的环境准备、运行、测试、构建与调试方式。

---

## 1. 环境准备

### 1.1 必需工具

| 工具 | 最低版本 | 说明 |
|------|----------|------|
| Flutter SDK | 3.11.x | 框架主体，包含 Dart SDK |
| Dart SDK | 3.11.x | 随 Flutter SDK 一同安装 |
| Git | 2.x | 版本控制 |

### 1.2 平台开发工具

根据目标平台安装对应工具链：

| 平台 | 所需工具 |
|------|----------|
| Android | Android Studio + Android SDK |
| iOS | Xcode（仅 macOS） |
| macOS | Xcode + CocoaPods（仅 macOS） |
| Linux | clang、cmake、ninja-build、pkg-config、libgtk-3-dev |
| Windows | Visual Studio 2022（含"使用 C++ 的桌面开发"工作负载） |
| Web | Chrome 浏览器（推荐） |

### 1.3 验证环境

```bash
# 检查 Flutter 环境是否就绪
flutter doctor

# 期望输出：所有目标平台显示 ✓
```

---

## 2. 获取项目

```bash
# 克隆仓库
git clone https://github.com/Qintsg/SSPU-all-in-one.git
cd SSPU-all-in-one
```

---

## 3. 依赖安装

```bash
# 获取所有 Dart/Flutter 依赖
flutter pub get
```

依赖列表（见 `pubspec.yaml`）：

| 包名 | 用途 |
|------|------|
| `fluent_ui` | Fluent Design 风格 UI 组件 |
| `shared_preferences` | 本地键值对存储 |
| `crypto` | SHA-256 哈希 |
| `flutter_lints` | 代码规范（dev） |

---

## 4. 运行项目

### 4.1 列出可用设备

```bash
flutter devices
```

### 4.2 运行（调试模式）

```bash
# 使用默认设备
flutter run

# 指定平台
flutter run -d chrome          # Web
flutter run -d windows         # Windows 桌面
flutter run -d macos           # macOS 桌面
flutter run -d linux           # Linux 桌面

# 指定 Android/iOS 设备（使用 flutter devices 获取设备 ID）
flutter run -d <device_id>
```

### 4.3 热重载与热重启

在调试模式运行时：

| 操作 | 快捷键 | 说明 |
|------|--------|------|
| 热重载 | `r` | 保留状态，更新 UI 代码 |
| 热重启 | `R` | 重置状态，重新构建 |
| 退出 | `q` | 停止调试运行 |

### 4.4 VS Code 调试

1. 安装 Flutter 扩展（`Dart-Code.flutter`）
2. 打开项目根目录
3. 按 `F5` 或点击"运行和调试" → "Dart & Flutter"
4. 选择目标设备运行

---

## 5. 代码分析

```bash
# 运行静态分析（lint + 类型检查）
flutter analyze
```

规则配置见项目根目录的 `analysis_options.yaml`，基于 `flutter_lints` 推荐规则集。

期望输出：

```
Analyzing sspu_all_in_one...
No issues found!
```

---

## 6. 测试

### 6.1 运行全部测试

```bash
flutter test
```

### 6.2 运行指定测试文件

```bash
flutter test test/widget_test.dart
```

### 6.3 当前测试覆盖

| 测试文件 | 类型 | 覆盖范围 |
|----------|------|----------|
| `test/widget_test.dart` | 冒烟测试 | SSPUApp 可正常构建 |

> 测试体系待补充：Widget 测试、服务层单元测试、集成测试等。

### 6.4 查看测试覆盖率

```bash
flutter test --coverage
# 生成 coverage/lcov.info

# 使用 lcov 工具生成 HTML 报告（需安装 lcov）
# genhtml coverage/lcov.info -o coverage/html
```

---

## 7. 构建发布包

### 7.1 Android

```bash
# 调试 APK
flutter build apk --debug

# 发布 APK
flutter build apk --release

# App Bundle（Google Play 推荐）
flutter build appbundle --release
```

输出路径：`build/app/outputs/flutter-apk/`

### 7.2 iOS

```bash
# 需在 macOS 上运行
flutter build ios --release
```

### 7.3 Web

```bash
flutter build web --release
```

输出路径：`build/web/`

可使用任意静态文件服务器预览：

```bash
cd build/web
python -m http.server 8080
# 访问 http://localhost:8080
```

### 7.4 Windows 桌面

```bash
flutter build windows --release
```

输出路径：`build/windows/x64/runner/Release/`

### 7.5 macOS 桌面

```bash
# 需在 macOS 上运行
flutter build macos --release
```

输出路径：`build/macos/Build/Products/Release/`

### 7.6 Linux 桌面

```bash
flutter build linux --release
```

输出路径：`build/linux/x64/release/bundle/`

---

## 8. 常用开发命令

| 命令 | 用途 |
|------|------|
| `flutter pub get` | 安装依赖 |
| `flutter pub upgrade` | 升级依赖到最新兼容版本 |
| `flutter pub outdated` | 检查过期依赖 |
| `flutter analyze` | 静态代码分析 |
| `flutter test` | 运行测试 |
| `flutter clean` | 清理构建缓存 |
| `flutter pub cache repair` | 修复依赖缓存 |
| `flutter doctor` | 检查开发环境 |
| `flutter devices` | 列出可用设备 |

---

## 9. 项目目录结构

```
SSPU-all-in-one/
├── lib/                         # Dart 源码
│   ├── main.dart                # 应用入口
│   ├── app.dart                 # 导航骨架
│   ├── pages/                   # 页面
│   │   ├── home_page.dart       # 主页
│   │   ├── academic_page.dart   # 教务中心
│   │   ├── info_page.dart       # 信息中心
│   │   ├── quick_links_page.dart# 快速跳转
│   │   ├── settings_page.dart   # 设置
│   │   └── lock_page.dart       # 锁定页
│   └── services/                # 服务层
│       └── password_service.dart# 密码管理
├── test/                        # 测试文件
│   └── widget_test.dart         # 冒烟测试
├── android/                     # Android 平台配置
├── ios/                         # iOS 平台配置
├── macos/                       # macOS 平台配置
├── linux/                       # Linux 平台配置
├── windows/                     # Windows 平台配置
├── web/                         # Web 平台配置
├── docs/                        # 项目文档
│   ├── API.md                   # API 文档
│   ├── CHANGELOG.md             # 变更日志
│   ├── DESIGN.md                # 设计文档
│   └── USAGE.md                 # 使用文档（本文件）
├── .github/                     # GitHub 配置
│   └── dida365-state.md         # 任务状态镜像
├── AGENTS.md                    # 代理工作规范
├── LICENSE                      # MIT 许可证
├── pubspec.yaml                 # 项目配置与依赖
├── pubspec.lock                 # 依赖锁定文件
└── analysis_options.yaml        # 静态分析配置
```

---

## 10. 故障排查

### 10.1 依赖安装失败

```bash
flutter clean
flutter pub cache repair
flutter pub get
```

### 10.2 平台编译错误

```bash
# 确认平台工具链已安装
flutter doctor -v

# 重新生成平台配置文件（慎用，会覆盖自定义配置）
# flutter create .
```

### 10.3 fluent_ui 编译问题

确认 Flutter SDK 版本与 fluent_ui 版本兼容：

```bash
flutter --version
flutter pub deps | Select-String "fluent_ui"
```

### 10.4 shared_preferences 平台异常

Desktop 平台（Windows/macOS/Linux）需要确保平台插件已正确注册。若出现 `MissingPluginException`：

```bash
flutter clean
flutter pub get
flutter run
```

---

## 11. 注意事项

1. **不要提交 `.env` 文件**：项目 `.gitignore` 已配置忽略环境变量文件
2. **不要修改 `pubspec.lock`**：除非执行了 `flutter pub get/upgrade`
3. **Windows 开发**：确保以管理员身份运行 Visual Studio Installer 安装 C++ 工作负载
4. **Web 调试**：推荐使用 Chrome，其他浏览器可能存在兼容性差异
5. **密码数据存储位置**：
   - Android: SharedPreferences XML 文件
   - iOS/macOS: NSUserDefaults
   - Windows: 注册表
   - Linux: 本地文件
   - Web: localStorage
