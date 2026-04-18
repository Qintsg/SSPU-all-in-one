# SSPU All-in-One

> 上海第二工业大学校园综合服务应用

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Version](https://img.shields.io/badge/version-v0.0.1--alpha-orange)](docs/CHANGELOG.md)

## 简介

SSPU All-in-One 是面向上海第二工业大学师生的校园综合服务应用，基于 Flutter + Fluent UI 构建，支持 Android / iOS / macOS / Linux / Windows / Web 全平台。所有数据仅保留在本地，不上传至任何云端服务。

## 快速开始

### 环境要求

- Flutter SDK >= 3.11
- 各平台对应的开发工具（详见 [使用文档](docs/USAGE.md)）

### 安装与运行

```bash
git clone https://github.com/Qintsg/SSPU-all-in-one.git
cd SSPU-all-in-one
flutter pub get
flutter run
```

### 构建

```bash
flutter build apk           # Android APK
flutter build web            # Web
flutter build windows        # Windows
flutter build macos          # macOS
flutter build linux          # Linux
```

## 文档

- [设计文档](docs/DESIGN.md) — 架构、功能设计、技术选型
- [使用文档](docs/USAGE.md) — 开发环境、运行、测试、构建
- [API 文档](docs/API.md)
- [变更日志](docs/CHANGELOG.md)

## 许可证

[MIT](LICENSE) © [Qintsg](https://github.com/Qintsg)
