# SSPU-all-in-one 发布规则

> 适用范围：本规则基于仓库当前代码结构制定，忽略历史 workflow 与既有 release 实现。
> 目标：统一版本、命名、打包、发布矩阵、校验与说明，确保产物可追踪、可下载、可验证。
> 当前自动化约定：公开 Release 仍然通过带 `release` 标签的 PR merge 触发；正式版要求合并到 `main`，预发布版允许合并到 `main`、`develop` 或 `release/*`。

---

## 1. 总体原则

1. 发布规则以仓库源码结构与实际可构建产物为准。
2. `pubspec.yaml` 中的版本号是唯一版本事实来源。
3. Git Tag、Release 标题、Release 资产命名、校验文件、元数据文件必须互相对应。
4. GitHub Release 只放最终用户可直接消费的产物，不放中间构建文件。
5. 默认优先保证 Android、Windows、macOS、Linux、Web 五类产物质量；iOS 默认不进入公开 Release。
6. Linux 平台除通用压缩包外，应额外提供主流发行版可直接安装的软件包。

---

## 2. 版本规则

### 2.1 版本来源

版本号统一读取自 `pubspec.yaml`：

```yaml
version: MAJOR.MINOR.PATCH[-CHANNEL]+BUILD
```

示例：

- `0.2.0-alpha+3`
- `0.2.0-beta+1`
- `0.2.0-rc+2`
- `0.2.0+1`

### 2.2 版本字段含义

- `MAJOR`：不兼容变更
- `MINOR`：向后兼容的新功能
- `PATCH`：向后兼容的问题修复
- `CHANNEL`：预发布通道，可选值：
  - `alpha`
  - `beta`
  - `rc`
- `BUILD`：构建序号，仅用于区分同版本的构建批次

### 2.3 版本约束

1. 正式版不带预发布后缀，例如：`1.0.0+1`
2. 预发布版必须带通道后缀，例如：`1.0.0-beta+2`
3. `BUILD` 必须为正整数
4. 发布时不得手工在多个文件中分别维护版本，统一以 `pubspec.yaml` 为准

---

## 3. 分支与发版流

### 3.1 分支约定

- `main`：可发布分支
- `develop`：集成开发分支
- `feature/*`：功能开发分支
- `hotfix/*`：线上修复分支

### 3.2 发版约定

1. 正式 Release 只能从 `main` 发出
2. 预发布版本可从 `main`、`develop` 或 `release/*` 预发布稳定分支生成，但最终必须回到 `main`
3. 不允许直接从 `feature/*` 创建正式 Release
4. 紧急修复优先使用 `hotfix/*`，修复完成后同时回合到 `main` 与 `develop`
5. 公开 Release 由目标分支满足上述规则、且带 `release` 标签的 PR merge 自动触发

---

## 4. 发布类型

### 4.1 预发布

适用于：

- 新功能初测
- 架构改动验证
- 跨平台兼容性验证

通道：

- `alpha`
- `beta`
- `rc`

要求：

- GitHub Release 必须标记为 Pre-release
- Release 标题中必须体现通道信息
- 允许仅发布部分平台，但必须在说明中明确列出缺失平台

### 4.2 正式发布

适用于：

- 面向普通用户分发
- 具备完整发布说明
- 所有正式支持平台构建通过

要求：

- GitHub Release 不标记为 Pre-release
- 必须附带校验文件与元数据文件
- 必须包含安装/升级说明与已知问题

---

## 5. 平台支持矩阵

### 5.1 正式支持平台

以下平台属于默认正式发布范围：

| 平台 | 架构 | 发布形式 | 必须进入公开 Release |
|---|---|---|---|
| Android | universal | APK | 是 |
| Windows | x64 | installer / portable | 是 |
| Windows | arm64 | installer / portable | 是 |
| macOS | universal | DMG | 是 |
| Linux | x64 | AppImage / deb / rpm / tar.gz | 是 |
| Linux | arm64 | AppImage / deb / rpm / tar.gz | 是 |
| Web | universal | static.zip | 是 |

### 5.2 实验性平台

以下平台默认不纳入正式支持承诺：

| 平台 | 架构 | 发布形式 | 默认策略 |
|---|---|---|---|
| Android | split ABI | APK / AAB | 可选，预发布可提供 |
| iOS | device / archive | IPA / archive | 默认不公开发布 |

### 5.3 iOS 特别规则

1. iOS 默认不进入 GitHub 公开 Release
2. 除非签名、分发方式、安装说明均已明确，否则只允许作为内部测试产物
3. 若未来需要公开分发，必须单独补充 iOS 发布与安装文档

---

## 6. 产物命名规范

### 6.1 统一命名格式

除 Android 通用 APK 外，所有发布资产统一命名为：

```text
SSPU-All-in-One-v{version}-{platform}-{arch}-{kind}.{ext}
```

Android 通用 APK 采用以下固定短名：

```text
SSPU-All-in-One-v{version}-android-universal.apk
```

字段说明：

- `{version}`：来自 `pubspec.yaml`，完整保留
- `{platform}`：平台标识
- `{arch}`：架构标识
- `{kind}`：产物类型
- `{ext}`：文件扩展名

### 6.2 平台字段取值

#### platform

仅允许以下值：

- `android`
- `ios`
- `windows`
- `macos`
- `linux`
- `web`

#### arch

仅允许以下值：

- `universal`
- `x64`
- `arm64`
- `armv7`

#### kind

仅允许以下值：

- `installer`
- `portable`
- `bundle`
- `static`
- `unsigned`
- `appimage`
- `deb`
- `rpm`

### 6.3 推荐命名示例

```text
SSPU-All-in-One-v0.2.0-alpha+3-android-universal.apk
SSPU-All-in-One-v0.2.0+1-windows-x64-installer.exe
SSPU-All-in-One-v0.2.0+1-windows-x64-portable.zip
SSPU-All-in-One-v0.2.0+1-windows-arm64-installer.exe
SSPU-All-in-One-v0.2.0+1-windows-arm64-portable.zip
SSPU-All-in-One-v0.2.0+1-macos-universal-installer.dmg
SSPU-All-in-One-v0.2.0+1-macos-universal-unsigned.dmg
SSPU-All-in-One-v0.2.0+1-linux-x64-appimage.AppImage
SSPU-All-in-One-v0.2.0+1-linux-x64-deb.deb
SSPU-All-in-One-v0.2.0+1-linux-x64-rpm.rpm
SSPU-All-in-One-v0.2.0+1-linux-x64-portable.tar.gz
SSPU-All-in-One-v0.2.0+1-linux-arm64-appimage.AppImage
SSPU-All-in-One-v0.2.0+1-linux-arm64-deb.deb
SSPU-All-in-One-v0.2.0+1-linux-arm64-rpm.rpm
SSPU-All-in-One-v0.2.0+1-linux-arm64-portable.tar.gz
SSPU-All-in-One-v0.2.0+1-web-universal-static.zip
```

### 6.4 命名约束

1. 文件名中必须包含版本、平台、架构与类型信息；Android 通用 APK 使用固定短名但仍必须包含版本与平台/架构语义
2. 不允许使用含糊命名，例如：
   - `app.apk`
   - `release.zip`
   - `windows-build.zip`
3. 不允许在文件名中混入时间戳、随机字符串、构建机器信息
4. 不允许使用中文文件名

---

## 7. 各平台发布产物规则

### 7.1 Android

公开 Release 默认只上传：

- `SSPU-All-in-One-v{version}-android-universal.apk`

可选附加产物（非默认）：

- ABI 分包 APK
- `.aab`

约束：

1. 默认优先提供 `universal.apk`
2. `.aab` 不作为普通用户首选下载项
3. 若提供 ABI 分包，必须明确标注架构并保留 `universal.apk`

### 7.2 Windows

公开 Release 默认上传：

- `SSPU-All-in-One-v{version}-windows-x64-installer.exe`
- `SSPU-All-in-One-v{version}-windows-x64-portable.zip`
- `SSPU-All-in-One-v{version}-windows-arm64-installer.exe`
- `SSPU-All-in-One-v{version}-windows-arm64-portable.zip`

约束：

1. 安装版与便携版可同时存在
2. 压缩包内根目录应直接包含应用目录，不应多包一层杂乱结构
3. `x64` 与 `arm64` 应保持同级发布，不允许只补其中一个架构
4. 若单架构仅提供一种形式，优先 installer

### 7.3 macOS

公开 Release 默认上传：

- `SSPU-All-in-One-v{version}-macos-universal-installer.dmg`

约束：

1. 默认只提供 DMG
2. 未签名或未公证时，必须在发布说明中明确标注
3. 若必须提供未签名产物，命名应使用 `unsigned`
4. 当前仓库自动化默认产出未签名 DMG，因此公开 Release 资产使用：
   `SSPU-All-in-One-v{version}-macos-universal-unsigned.dmg`
5. unsigned DMG 的 Release 构建不得携带 App Sandbox、Keychain Access Groups 等受限 entitlement；若改为 Developer ID 签名与公证，必须同步调整签名配置、产物命名和发布说明

### 7.4 Linux

公开 Release 默认上传以下 Linux 资产：

- `SSPU-All-in-One-v{version}-linux-x64-appimage.AppImage`
- `SSPU-All-in-One-v{version}-linux-x64-deb.deb`
- `SSPU-All-in-One-v{version}-linux-x64-rpm.rpm`
- `SSPU-All-in-One-v{version}-linux-x64-portable.tar.gz`
- `SSPU-All-in-One-v{version}-linux-arm64-appimage.AppImage`
- `SSPU-All-in-One-v{version}-linux-arm64-deb.deb`
- `SSPU-All-in-One-v{version}-linux-arm64-rpm.rpm`
- `SSPU-All-in-One-v{version}-linux-arm64-portable.tar.gz`

#### 7.4.1 Linux 包类型与适用发行版

| 包类型 | 适用发行版 | 说明 |
|---|---|---|
| AppImage | 通用 | 免安装，适合绝大多数桌面发行版 |
| deb | Debian / Ubuntu / Linux Mint / Deepin / UOS 等 | 适合 Debian 系主流桌面用户 |
| rpm | Fedora / RHEL / CentOS Stream / openSUSE 等 | 适合 RPM 系发行版 |
| tar.gz | 通用 | 兜底便携包，适合手工解压运行 |

#### 7.4.2 Linux 正式发布最低要求

正式 Release 时，Linux 平台至少应满足以下要求：

1. `x64` 必须提供 `AppImage`、`deb`、`rpm`、`tar.gz`
2. `arm64` 必须提供 `AppImage`、`deb`、`rpm`、`tar.gz`
3. 两个架构的命名风格、校验文件与发布说明必须保持一致

#### 7.4.3 Linux 预发布最低要求

预发布时至少应提供以下两类之一：

- `x64 AppImage`
- `x64 tar.gz`
- `arm64 AppImage`
- `arm64 tar.gz`

建议仍尽量附带 `deb` 与 `rpm`

#### 7.4.4 Linux 打包约束

1. 正式公开 Release 必须同时覆盖 `x64` 与 `arm64`
2. 压缩包解压后目录结构应清晰，不应包含构建缓存或临时目录
3. `deb` 包应尽量遵循 Debian 系安装约定
4. `rpm` 包应尽量遵循 RPM 系安装约定
5. `AppImage` 应保证双击或加执行权限后可直接运行
6. 如依赖额外系统库，必须在 Release 说明中列出

#### 7.4.5 Linux 包命名补充要求

1. Linux 文件名中必须明确写出包类型，不允许只写 `linux-x64.zip`
2. 对同一版本，`x64` 与 `arm64` 的 `AppImage`、`deb`、`rpm`、`tar.gz` 必须并列存在且命名风格一致
3. 不允许把 `.deb`、`.rpm` 作为压缩包内附件二次打包上传

### 7.5 Web

公开 Release 默认上传：

- `SSPU-All-in-One-v{version}-web-universal-static.zip`

约束：

1. 必须打包完整静态站点目录
2. 不直接上传零散静态文件
3. 若存在部署要求，需在 Release 中注明基础路径、反向代理或静态服务器要求

### 7.6 iOS

默认不进入公开 Release。

如确需提供：

1. 必须明确分发方式
2. 必须明确安装前置条件
3. 必须单独说明签名状态、适配设备与测试方式

---

## 8. 不得进入 Release 的内容

以下内容一律不得上传到 GitHub Release：

- 构建缓存目录
- 临时中间产物
- 调试版产物
- 未压缩的 `build/web/` 散文件树
- 日志文件
- 本地测试报告原始目录
- 构建脚本临时输出
- 符号文件（除非单独定义开发者下载区）
- 无说明的 `.aab`、`.app`、`.xcarchive`、`intermediates` 等中间件

原则：Release 面向终端用户，不面向构建排错。

---

## 9. 必备附属文件

每次 Release 必须额外附带以下文件：

### 9.1 `SHA256SUMS.txt`

内容要求：

- 列出所有发布资产的 SHA-256
- 一行一个文件
- 格式统一为：

```text
<sha256>  <filename>
```

### 9.2 `manifest.json`

用于机器读取的元数据，至少包含：

```json
{
  "name": "SSPU-all-in-one",
  "version": "0.2.0+1",
  "channel": "stable",
  "build_number": 1,
  "tag": "v0.2.0",
  "platforms": [
    {
      "platform": "linux",
      "arch": "x64",
      "kind": "appimage",
      "filename": "SSPU-All-in-One-v0.2.0+1-linux-x64-appimage.AppImage",
      "sha256": "..."
    },
    {
      "platform": "linux",
      "arch": "x64",
      "kind": "deb",
      "filename": "SSPU-All-in-One-v0.2.0+1-linux-x64-deb.deb",
      "sha256": "..."
    },
    {
      "platform": "linux",
      "arch": "x64",
      "kind": "rpm",
      "filename": "SSPU-All-in-One-v0.2.0+1-linux-x64-rpm.rpm",
      "sha256": "..."
    }
  ]
}
```

建议字段：

- `name`
- `version`
- `channel`
- `build_number`
- `tag`
- `release_date`
- `flutter_version`
- `dart_version`
- `platforms`

### 9.3 `release-notes.md`

要求：

- 与 GitHub Release 正文内容一致或基本一致
- 可直接作为归档文档保存
- 自动化从 Release PR 正文中提取并生成，因此带 `release` 标签的 PR 必须提供完整发布说明章节

---

## 10. Tag 规则

### 10.1 Tag 格式

统一使用：

```text
vMAJOR.MINOR.PATCH
vMAJOR.MINOR.PATCH-alpha
vMAJOR.MINOR.PATCH-beta
vMAJOR.MINOR.PATCH-rc
```

示例：

- `v0.2.0-alpha`
- `v0.2.0-beta`
- `v0.2.0-rc`
- `v0.2.0`

### 10.2 Tag 约束

1. Tag 不包含 `+BUILD`
2. `+BUILD` 只体现在版本号和产物元数据中
3. 同一源码版本允许重新构建，但不建议重复覆盖同名 Release 资产
4. 如需重发产物，优先增加 `BUILD` 并重新创建对应版本

---

## 11. 发布说明模板

每次 Release 正文必须至少包含以下章节：

```markdown
## 亮点
- 新增了什么
- 修复了什么
- 优化了什么

## 破坏性变更
- 是否存在配置、数据、行为不兼容

## 平台清单
- Android
- Windows x64 / arm64
- macOS universal
- Linux x64 / arm64（AppImage / deb / rpm / tar.gz）
- Web

## 安装 / 升级说明
- 新装用户怎么用
- 老用户怎么升级
- 是否需要清理旧配置

## Linux 安装说明
- Debian / Ubuntu / Linux Mint 用户优先使用 `.deb`
- Fedora / openSUSE / RHEL 系用户优先使用 `.rpm`
- 需要免安装时使用 `.AppImage`
- 无法直接安装时使用 `.tar.gz`

## 已知问题
- 当前存在但未修复的问题
- 哪些平台受影响

## 校验信息
- 提供 SHA256SUMS.txt
- 提供 manifest.json
```

### 说明要求

1. 不允许只写“修复若干问题”
2. 必须说明缺失平台或异常平台
3. 如存在签名、公证、权限限制，必须明确写出
4. 如是预发布，必须说明测试性质与风险
5. Linux 若未提供某种包型，必须说明原因

---

## 12. 质量门槛

### 12.1 合并门槛

进入可发布分支前，至少满足：

- 代码格式正常
- `flutter analyze` 通过
- `flutter test` 通过

### 12.2 发版门槛

创建 Release 前，至少满足：

1. 所有正式支持平台 release build 通过
2. 产物命名符合规范
3. `pubspec.yaml` 版本与 Tag 一致
4. `SHA256SUMS.txt` 已生成
5. `manifest.json` 已生成
6. `release-notes.md` 已准备
7. 发布说明已明确：
   - 支持平台
   - 已知问题
   - 安装方式
   - 校验方式

### 12.3 Linux 发版附加门槛

正式 Release 时，Linux 额外要求：

1. `x64` 与 `arm64` 的 `AppImage` 均可直接运行
2. `x64` 与 `arm64` 的 `deb` 均可被 Debian/Ubuntu 系正常安装
3. `x64` 与 `arm64` 的 `rpm` 均可被 Fedora/openSUSE/RHEL 系正常安装
4. `x64` 与 `arm64` 的 `tar.gz` 解压后均可直接运行
5. 八类 Linux 产物的校验值必须全部写入 `SHA256SUMS.txt`

### 12.4 可选增强门槛

后续可逐步补充：

- 多平台冒烟启动验证
- 产物体积变化阈值检查
- Android 安装校验
- Windows/macOS/Linux 启动可用性校验
- Web 页面加载与路由校验

---

## 13. 发布资产清单建议

### 13.1 预发布建议最小清单

```text
SSPU-All-in-One-v{version}-android-universal.apk
SSPU-All-in-One-v{version}-windows-x64-portable.zip
SSPU-All-in-One-v{version}-windows-arm64-portable.zip
SSPU-All-in-One-v{version}-linux-x64-appimage.AppImage
SSPU-All-in-One-v{version}-linux-x64-portable.tar.gz
SSPU-All-in-One-v{version}-linux-arm64-appimage.AppImage
SSPU-All-in-One-v{version}-linux-arm64-portable.tar.gz
SSPU-All-in-One-v{version}-web-universal-static.zip
SHA256SUMS.txt
manifest.json
release-notes.md
```

### 13.2 正式发布建议完整清单

```text
SSPU-All-in-One-v{version}-android-universal.apk
SSPU-All-in-One-v{version}-windows-x64-installer.exe
SSPU-All-in-One-v{version}-windows-x64-portable.zip
SSPU-All-in-One-v{version}-windows-arm64-installer.exe
SSPU-All-in-One-v{version}-windows-arm64-portable.zip
SSPU-All-in-One-v{version}-macos-universal-unsigned.dmg
SSPU-All-in-One-v{version}-linux-x64-appimage.AppImage
SSPU-All-in-One-v{version}-linux-x64-deb.deb
SSPU-All-in-One-v{version}-linux-x64-rpm.rpm
SSPU-All-in-One-v{version}-linux-x64-portable.tar.gz
SSPU-All-in-One-v{version}-linux-arm64-appimage.AppImage
SSPU-All-in-One-v{version}-linux-arm64-deb.deb
SSPU-All-in-One-v{version}-linux-arm64-rpm.rpm
SSPU-All-in-One-v{version}-linux-arm64-portable.tar.gz
SSPU-All-in-One-v{version}-web-universal-static.zip
SHA256SUMS.txt
manifest.json
release-notes.md
```

---

## 14. 失败与回滚规则

1. 若正式支持平台有任意一个构建失败，则不得创建正式 Release
2. 若发布后发现产物命名错误、校验错误、版本错误，应立即撤回或标记为失效
3. 若发布后发现严重功能问题：
   - 预发布：可直接废弃并重发
   - 正式版：必须走 `hotfix/*` 流程修复后重新发布
4. 不允许悄悄替换同名产物而不更新校验与说明

---

## 15. 后续扩展建议

未来如需增强发布体系，可在不破坏本规则前提下增加：

- 自动更新清单文件
- 渠道分发配置（stable / beta）
- 桌面端签名与公证规范
- iOS 专项分发规范
- Linux 仓库源分发规范（APT / YUM / DNF / Zypper）
- 产物下载统计与镜像规则

---

## 16. 一句话执行标准

> 每次发布都必须做到：版本唯一、命名统一、平台清晰、产物可用、校验完整、说明明确。
> 对 Linux 平台，正式发布必须同时兼顾通用运行与主流发行版原生安装。
