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
| `path_provider` | 平台应用支持目录解析 |
| `crypto` | SHA-256 哈希 |
| `flutter_secure_storage` | 系统安全存储，用于保存可解密教务凭据 |
| `local_auth` | 可选系统快速验证，用于密码保护开启后的本机认证解锁 |
| `gbk_codec` | GBK / GB2312 解码，用于体育部查询系统旧版页面 |
| `enough_mail` | IMAP / POP / SMTP 邮箱协议客户端，用于学校邮箱只读收信和登录校验 |
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

## 6.5 本专科教务 / OA 登录校验调试

安全设置页的“教务凭据”区域提供“验证 OA 登录”按钮，用于只读检查已保存的 OA 账号密码是否可完成本专科教务系统入口登录。

校验流程：

- 先执行校园网 / VPN 前置检测；不可访问受限校园站点时不提交 OA 凭据
- 访问 `https://oa.sspu.edu.cn/interface/Entrance.jsp?id=bzkjw`，按网页跳转进入 `id.sspu.edu.cn/cas/login`
- 从 CAS 登录页读取 `execution` 等隐藏字段，并通过 `/cas/jwt/publicKey` 获取 RSA 公钥
- 按 CAS 页面规则提交 `__RSA__` 前缀的 RSA 加密密码；成功条件是 CAS 跳转回 `oa.sspu.edu.cn`
- 登录成功后仅将响应链路中的 Cookie 会话快照写入系统安全存储，供后续只读网页请求复用；不保存一次性 CAS Ticket

已知交互限制：

- CAS 要求图形验证码时，应用会提示“需要图形验证码”，不会尝试绕过验证码
- CAS 要求 MFA / 安全验证时，应用会提示“需要额外安全验证”，不会继续无交互登录
- CAS 登录页结构缺少表单、`execution` 或公钥解析失败时，按网页流程异常处理
- OA 登录持久性较低；后续请求发现跳回 CAS 或返回未登录状态时，可直接重新点击“验证 OA 登录”刷新会话
- 登录校验仅允许登录状态判断，不执行查询、提交、标记、删除等写入或状态变更操作

登录规则探索记录见 [OA_LOGIN_RULES.md](OA_LOGIN_RULES.md)。

## 6.6 体育部课外活动考勤调试

教务中心页提供体育部查询系统的课外活动考勤卡片，展示总次数和四类拆分：早操、课外活动、次数调整、体育长廊。

刷新方式：

- 默认不自动访问体育部查询系统，避免未连接校园网或学校 VPN 时进入教务页就发起受限请求
- 可点击考勤卡片右下角刷新图标手动读取最新数据，旁边会显示上次刷新时间
- 可在设置页“自动刷新设置”中开启“体育查询自动刷新”并选择刷新间隔；开启后进入教务中心会主动读取一次，并按设置间隔刷新
- 每次读取前都会重新执行校园网 / VPN 前置检测；不可访问受限校园站点时不提交体育部密码

查询流程：

- 先执行校园网 / VPN 前置检测；不可访问受限校园站点时不提交体育部密码
- 使用安全设置页保存的学工号作为 `txtuser`，使用“体育部查询密码”作为 `txtpwd`
- 固定学生身份 `dlljs=st`，并携带体育部登录页当前返回的 ASP.NET WebForms 隐藏字段
- 登录成功后只读访问 `https://tygl.sspu.edu.cn/sportscore/stScore.aspx?item=1`
- 页面使用 GBK / GB2312 编码，应用解码后解析四类次数与明细记录

已知交互限制：

- 体育部查询密码与 OA 密码不同，缺少体育部查询密码时不会尝试复用 OA 密码
- 登录失败、会话不可用或页面结构变化时，教务中心页会展示明确错误状态
- “查看考勤记录”会打开二级页面展示明细；仅展示只读结果，不执行次数调整等写入操作

登录与解析规则探索记录见 [SPORTS_ATTENDANCE_RULES.md](SPORTS_ATTENDANCE_RULES.md)。

## 6.7 校园卡余额与交易记录调试

主页提供“校园卡余额”卡片，展示当前账户余额、非正常卡状态提示和最近交易记录。

刷新方式：

- 默认不自动访问校园卡系统，避免未连接校园网或学校 VPN 时进入主页就发起受限请求
- 可点击卡片右下角刷新图标手动读取最新余额、卡状态和交易记录，旁边会显示上次刷新时间
- 可在设置页“自动刷新设置”中开启“校园卡余额自动刷新”并选择刷新间隔；开启后进入主页会主动读取一次，并按设置间隔刷新
- 每次读取前都会重新执行校园网 / VPN 前置检测；不可访问受限校园站点时不进入 OA / 校园卡登录链路

查询流程：

- 使用 `https://oa.sspu.edu.cn//interface/Entrance.jsp?id=xykxt` 作为 OA 校园卡入口
- 复用已保存的 OA/CAS Cookie 会话；会话失效时调用现有 OA 登录校验刷新会话
- 校园卡业务入口为 `https://card.sspu.edu.cn/epay/`，CAS 回调服务为 `https://card.sspu.edu.cn/epay/j_spring_cas_security_check`
- 读取余额 / 状态页面和交易记录页面后解析余额、卡状态、最近交易记录
- 详情页支持按日期范围查询交易记录；该操作仅访问交易查询接口，不执行充值、支付或其它写入操作

已知交互限制：

- 缺少学工号或 OA 密码时不会访问校园卡系统
- OA/CAS 要求验证码、MFA 或安全验证时，需要先在安全设置中完成 OA 登录校验
- 页面结构变化时，主页和详情页会展示明确错误状态，不会伪造余额或交易记录

登录与解析规则探索记录见 [CAMPUS_CARD_RULES.md](CAMPUS_CARD_RULES.md)。

## 6.8 学校邮箱只读收信调试

侧边导航提供“学校邮箱”页面，用于校验邮箱协议登录状态，并通过 IMAP 或 POP 读取最近邮件。

刷新方式：

- 默认不自动访问邮箱系统，避免进入邮箱页即下载邮件正文
- 可点击“读取最近邮件”手动读取，读取成功后会显示上次刷新时间
- 可在设置页“自动刷新设置”中开启“学校邮箱自动刷新”并选择刷新间隔；开启后进入邮箱页会主动读取一次，并按设置间隔刷新
- 邮箱系统不执行校园网 / VPN 前置检测，网络失败会直接在页面提示邮箱协议连接异常

配置方式：

- 在设置页“教务凭据”区域保存“学校邮箱账号”和“邮箱密码”
- 邮箱账号可填写完整地址，也可只填写 `@sspu.edu.cn` 前的用户名
- 邮箱密码独立于 OA 密码；缺少邮箱密码时不会尝试复用 OA 密码

读取与校验流程：

- IMAP 默认访问 `imap.exmail.qq.com:993`，使用 TLS，并通过 `EXAMINE INBOX` + `BODY.PEEK[]` 读取最近邮件
- POP 默认访问 `pop.exmail.qq.com:995`，使用 TLS，通过 `LIST` + `RETR` 读取最近邮件，不调用删除命令
- SMTP 默认访问 `smtp.exmail.qq.com:465`，仅执行 `EHLO` + `AUTH` 校验，不发送邮件

只读限制：

- 页面仅展示标题、发件人、时间、正文摘要和正文快照
- 不提供发送、回复、转发、删除、移动、标记已读或修改文件夹入口
- 错误信息不会展示邮箱密码、认证载荷或服务器会话值

登录与协议规则探索记录见 [EMAIL_RULES.md](EMAIL_RULES.md)。

## 6.9 学工报表第二课堂学分调试

教务中心页提供“第二课堂学分”卡片，用于通过学工报表系统只读读取第二课堂学分明细，并按类别统计总分。

刷新方式：

- 默认不自动访问学工报表系统，避免未连接校园网或学校 VPN 时进入教务中心就发起受限请求
- 可点击卡片右上角刷新图标手动读取最新学分，卡片右下角显示上次刷新时间
- 可在设置页“自动刷新设置”中开启“第二课堂学分自动刷新”并选择刷新间隔；开启后进入教务中心会主动读取一次，并按设置间隔刷新
- 每次读取前都会重新执行校园网 / VPN 前置检测；不可访问受限校园站点时不进入 OA / 学工报表登录链路

查询流程：

- 使用 `https://oa.sspu.edu.cn/interface/Entrance.jsp?id=xgreport` 作为 OA 学工报表入口
- 复用已保存的 OA/CAS Cookie 会话；会话失效时调用现有 OA 登录校验刷新会话
- 读取 `https://xgbb.sspu.edu.cn/sharedc/core/home/index.do` 后定位“第二课堂学分查询”入口
- 只读打开第二课堂学分页面，解析类别、项目名称、认定时间、状态和学分字段

已知交互限制：

- 缺少学工号或 OA 密码时不会访问学工报表系统
- `xgbb` 本地登录页包含验证码，应用不会提交该表单，只通过 OA/CAS 入口复用登录态
- OA/CAS 要求验证码、MFA 或安全验证时，需要先在安全设置中完成 OA 登录校验
- 页面结构变化时，教务中心页会展示明确错误状态，不会伪造学分或空成功结果

登录与解析规则探索记录见 [STUDENT_REPORT_RULES.md](STUDENT_REPORT_RULES.md)。

## 7. 构建发布包

发布版本号、Tag、GitHub Release 资产命名、Release Notes 模板与平台清单，统一以 [docs/RELEASE.md](RELEASE.md) 为准。
公开 Release 仍然通过带 `release` 标签的 PR merge 自动触发，版本号只读取 `pubspec.yaml`。

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
- 系统快速验证依赖 `local_auth`，Android Runner 使用 `FlutterFragmentActivity` 并声明 `android.permission.USE_BIOMETRIC`；仍保留密码输入作为兜底路径

输出路径：

- `build/app/outputs/flutter-apk/app-release.apk`
- `build/app/outputs/bundle/release/app-release.aab`

发布后使用：

- `app-release.apk` 可直接安装到 Android 设备
- `app-release.aab` 用于应用商店上传，不适合本地直接安装
- GitHub Release 默认公开发布 `SSPU-All-in-One-v{version}-android-universal.apk`

### 7.2 iOS

```bash
# 需在 macOS 上运行
flutter build ios --release
```

iOS 系统快速验证通过 `local_auth` 调用系统能力，`Info.plist` 已配置 `NSFaceIDUsageDescription`。启用该功能仍需先开启应用密码保护并输入当前密码确认。

### 7.3 Web

```bash
flutter build web --release
```

输出路径：`build/web/`

Web 不支持 `local_auth`，系统快速验证入口会隐藏或显示不可用提示，用户仍使用手动密码解锁。Web 端也不访问本地文件目录，应用状态会保存到浏览器提供的 `shared_preferences` Web 存储；若浏览器存储不可用，则退回本次会话内存态以保证启动可用。

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

输出路径：

- `build/windows/x64/runner/Release/`
- `build/windows/arm64/runner/Release/`

发布后使用：

- 需要连同整个 `Release/` 目录一起分发，不能只拷贝单个 `.exe`
- 启动入口为 `sspu_all_in_one.exe`
- GitHub Release 默认同时提供 x64 / arm64 的 installer 与 portable 产物

### 7.5 macOS 桌面

```bash
# 需在 macOS 上运行
flutter build macos --release
```

输出路径：`build/macos/Build/Products/Release/`

发布后使用：

- 分发生成的 `.app` 包
- 若未做 Apple 签名与公证，首次运行可能需要在系统安全设置中手动允许
- 当前 GitHub Release 默认产出未签名 DMG：`SSPU-All-in-One-v{version}-macos-universal-unsigned.dmg`
- macOS 系统快速验证通过 `local_auth` 调用系统能力，`Info.plist` 已配置 `NSFaceIDUsageDescription`

### 7.6 Linux 桌面

```bash
flutter build linux --release
```

输出路径：

- `build/linux/x64/release/bundle/`
- `build/linux/arm64/release/bundle/`

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

若通过 GitHub Release 工作流发布，当前还会额外生成：

- `SSPU-All-in-One-v{version}-linux-x64-appimage.AppImage`
- `SSPU-All-in-One-v{version}-linux-x64-deb.deb`
- `SSPU-All-in-One-v{version}-linux-x64-rpm.rpm`
- `SSPU-All-in-One-v{version}-linux-x64-portable.tar.gz`
- `SSPU-All-in-One-v{version}-linux-arm64-appimage.AppImage`
- `SSPU-All-in-One-v{version}-linux-arm64-deb.deb`
- `SSPU-All-in-One-v{version}-linux-arm64-rpm.rpm`
- `SSPU-All-in-One-v{version}-linux-arm64-portable.tar.gz`

Linux 当前没有 `local_auth` 官方实现，系统快速验证入口会隐藏，用户仍使用手动密码解锁。

面向 Debian / Ubuntu 及其衍生发行版，可直接使用：

```bash
sudo apt install ./SSPU-All-in-One-v{version}-linux-x64-deb.deb
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

桌面端会将用户设置、认证信息、消息缓存和 WebView2 运行态写入 `~/.sspu-all-in-one/`；Android / iOS 会写入系统分配的应用支持目录。设置页提供 `wxmp_config.toml` 内置编辑器，移动端可直接在应用内修改公众号平台认证配置。教务凭据使用系统安全存储单独保存，不写入 `app_state.json`，安全设置页只显示学工号和密码填写状态。若状态文件损坏或需要重建本地状态，可先退出应用，备份后删除对应目录中的文件，再重新启动应用。

常用文件：

- `app_state.json`：应用设置、消息缓存、已读状态、关注列表；系统快速验证只保存 `app_quick_auth_enabled` 布尔配置，不保存任何 PIN、生物识别或系统认证原始数据
- `wxmp_config.toml`：微信公众号平台认证与高级抓取参数
- `webview2/`：Windows WebView2 用户数据目录
- 系统安全存储：学工号、OA 密码、体育部查询密码和邮箱密码；Linux 打包运行时需提供 `libsecret` 相关依赖

---

## 11. 注意事项

1. **不要提交 `.env` 文件**：项目 `.gitignore` 已配置忽略环境变量文件
2. **不要修改 `pubspec.lock`**：除非执行了 `flutter pub get/upgrade`
3. **Windows 开发**：确保以管理员身份运行 Visual Studio Installer 安装 C++ 工作负载
4. **Web 调试**：推荐使用 Chrome，其他浏览器可能存在兼容性差异
5. **用户数据存储位置**：桌面端位于 `~/.sspu-all-in-one/`，移动端位于系统分配的应用支持目录，包括密码哈希、设置项、消息缓存、微信公众号认证配置和 WebView2 运行态；教务凭据另存于系统安全存储
