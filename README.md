# SSPU All-in-One

> 上海电力大学校园综合服务应用

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Version](https://img.shields.io/badge/version-v0.0.1--alpha-orange)](docs/CHANGELOG.md)

## 简介

SSPU All-in-One 是一款面向上海电力大学师生的校园综合服务应用，基于 Flutter 构建，支持 Android、iOS、macOS、Linux、Windows 和 Web 全平台。

## 技术栈

- **框架**：Flutter (Dart)
- **目标平台**：Android / iOS / macOS / Linux / Windows / Web
- **包管理**：pub

## 快速开始

### 环境要求

- Flutter SDK >= 3.11
- Dart SDK >= 3.11
- 各平台对应的开发工具（Android Studio / Xcode / Visual Studio 等）

### 安装与运行

```bash
# 克隆仓库
git clone https://github.com/Qintsg/SSPU-all-in-one.git
cd SSPU-all-in-one

# 获取依赖
flutter pub get

# 运行（默认平台）
flutter run

# 指定平台运行
flutter run -d chrome       # Web
flutter run -d windows      # Windows
flutter run -d macos        # macOS
flutter run -d linux        # Linux
```

### 构建

```bash
flutter build apk           # Android APK
flutter build ios            # iOS
flutter build web            # Web
flutter build windows        # Windows
flutter build macos          # macOS
flutter build linux          # Linux
```

## 项目结构

```
SSPU-all-in-one/
├── lib/                     # Dart 源码
│   └── main.dart            # 应用入口
├── test/                    # 测试
├── android/                 # Android 平台配置
├── ios/                     # iOS 平台配置
├── macos/                   # macOS 平台配置
├── linux/                   # Linux 平台配置
├── windows/                 # Windows 平台配置
├── web/                     # Web 平台配置
├── docs/                    # 项目文档
│   ├── API.md               # API 文档
│   └── CHANGELOG.md         # 变更日志
├── AGENTS.md                # 代理工作规范
├── LICENSE                  # MIT 许可证
└── pubspec.yaml             # 项目配置与依赖
```

## 文档

- [API 文档](docs/API.md)
- [变更日志](docs/CHANGELOG.md)

## 许可证

本项目基于 [MIT 许可证](LICENSE) 开源。

## 作者

- [Qintsg](https://github.com/Qintsg)
