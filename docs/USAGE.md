# SSPU All-in-One 使用文档

> 本文档面向开发者，说明项目在开发状态下的环境准备、运行、测试、构建与调试方式。

---

## 1. 环境准备

### 1.1 必需工具

| 工具 | 最低版本 | 说明 |
|------|----------|------|
| Flutter SDK | 3.41.7 | 框架主体，包含 Dart SDK |
| Dart SDK | 3.11.5 | 随 Flutter SDK 一同安装 |
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

签名说明：

- 仓库通过 `android/key.properties` 读取本地 Android release 签名配置
- 可参考 `android/key.properties.example` 填写签名信息
- 当前工作区已生成本机自签名 keystore：`android/app/sspu-release.jks`
- `key.properties` 与 `.jks` 默认被 `.gitignore` 忽略，不会进入仓库
- GitHub Actions 可通过 `ANDROID_KEYSTORE_BASE64`、`ANDROID_KEYSTORE_PASSWORD`、`ANDROID_KEY_ALIAS`、`ANDROID_KEY_PASSWORD` 四个 Secrets 在运行时写入签名配置

输出路径：

- `build/app/outputs/flutter-apk/app-release.apk`
- `build/app/outputs/bundle/release/app-release.aab`

发布后使用：

- `app-release.apk` 可直接安装到 Android 设备
- `app-release.aab` 用于应用商店上传，不适合本地直接安装

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

发布后使用：

- 需要连同整个 `Release/` 目录一起分发，不能只拷贝单个 `.exe`
- 启动入口为 `sspu_all_in_one.exe`

### 7.5 macOS 桌面

```bash
# 需在 macOS 上运行
flutter build macos --release
```

输出路径：`build/macos/Build/Products/Release/`

发布后使用：

- 分发生成的 `.app` 包
- 若未做 Apple 签名与公证，首次运行可能需要在系统安全设置中手动允许

### 7.6 Linux 桌面

```bash
flutter build linux --release
```

输出路径：`build/linux/x64/release/bundle/`

若使用 Release 压缩包运行，建议使用 `tar` 解压以保留 Unix 可执行权限：

```bash
tar -xzf sspu-all-in-one-linux-x64.tar.gz
cd sspu-all-in-one-linux-x64
./sspu_all_in_one
```

如果使用图形化解压工具后出现 `Permission denied`，请补一次可执行权限：

```bash
chmod +x sspu_all_in_one
./sspu_all_in_one
```

---

## 8. 常用开发命令

| 命令 | 用途 |
|------|------|
| `flutter pub get` | 安装依赖 |
| `flutter pub upgrade --major-versions` | 升级依赖约束到最新主版本 |
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

### 10.5 Android release 构建失败

若 `flutter build apk --release` 提示缺少签名配置，请检查：

- `android/key.properties` 是否存在
- `storeFile` 是否指向实际存在的 keystore 文件
- `storePassword` / `keyPassword` / `keyAlias` 是否与 keystore 一致

### 10.4 本地状态文件异常

应用会将用户设置、认证信息、消息缓存和 WebView2 运行态统一写入 `~/.sspu-all-in-one/`。若状态文件损坏或需要重建本地状态，可先退出应用，备份后删除该目录中的对应文件，再重新启动应用。

常用文件：

- `app_state.json`：应用设置、消息缓存、已读状态、关注列表
- `wxmp_config.toml`：微信公众号平台认证与高级抓取参数
- `webview2/`：Windows WebView2 用户数据目录

---

## 11. 注意事项

1. **不要提交 `.env` 文件**：项目 `.gitignore` 已配置忽略环境变量文件
2. **不要修改 `pubspec.lock`**：除非执行了 `flutter pub get/upgrade`
3. **Windows 开发**：确保以管理员身份运行 Visual Studio Installer 安装 C++ 工作负载
4. **Web 调试**：推荐使用 Chrome，其他浏览器可能存在兼容性差异
5. **用户数据存储位置**：统一位于 `~/.sspu-all-in-one/`，包括密码哈希、设置项、消息缓存、微信公众号认证配置和 WebView2 运行态
