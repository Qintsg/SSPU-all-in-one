# SSPU All-in-One

> 上海第二工业大学校园综合服务应用

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Version](https://img.shields.io/badge/dynamic/yaml?url=https%3A%2F%2Fraw.githubusercontent.com%2FQintsg%2FSSPU-all-in-one%2Fmain%2Fpubspec.yaml&query=%24.version&label=version&color=orange)](docs/CHANGELOG.md)

## 简介

SSPU All-in-One 是面向上海第二工业大学师生的校园综合服务应用，基于 Flutter + Fluent UI 构建，支持 Android / iOS / macOS / Linux / Windows / Web 全平台。所有数据仅保留在本地，不上传至任何云端服务。

## 快速开始

### 环境要求

- Flutter SDK >= 3.41.7
- Dart SDK 3.11.5（随 Flutter 3.41.7 提供）
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

## Release 使用指南

### Android

- 本仓库支持通过 `android/key.properties` 加载本地签名配置；当前工作区已生成一个本机自签名 keystore：`android/app/sspu-release.jks`
- `android/key.properties` 与 `.jks` 文件默认不会提交；若需在新机器复用，请参考 `android/key.properties.example` 重新生成或复制 keystore
- GitHub Actions 进行 Android release build 时，不依赖仓库内签名文件；可通过 Secrets 在运行时下发签名材料：
  `ANDROID_KEYSTORE_BASE64`
  `ANDROID_KEYSTORE_PASSWORD`
  `ANDROID_KEY_ALIAS`
  `ANDROID_KEY_PASSWORD`
- 构建命令：

```bash
flutter build apk --release
flutter build appbundle --release
```

- 产物位置：
  `build/app/outputs/flutter-apk/app-release.apk`
  `build/app/outputs/bundle/release/app-release.aab`
- 使用方式：
  `app-release.apk` 可直接分发安装
  `app-release.aab` 用于应用商店上架，不适合直接本地安装

### Windows

- 构建命令：

```bash
flutter build windows --release
```

- 产物位置：
  `build/windows/x64/runner/Release/`
- 使用方式：
  将整个 `Release/` 目录连同其中的 DLL 和 `data/` 一起分发；直接运行目录中的 `sspu_all_in_one.exe`

### Linux

- 构建命令：

```bash
flutter build linux --release
```

- 产物位置：
  `build/linux/x64/release/bundle/`
- 使用方式：
  打包并分发整个 `bundle/` 目录；目标机器上运行 `./sspu_all_in_one`

### macOS

- 构建命令：

```bash
flutter build macos --release
```

- 产物位置：
  `build/macos/Build/Products/Release/`
- 使用方式：
  分发生成的 `.app` 包；首次运行若被系统拦截，需要在“系统设置 → 隐私与安全性”中手动放行

### Web

- 构建命令：

```bash
flutter build web --release
```

- 产物位置：
  `build/web/`
- 使用方式：
  将整个目录部署到任意静态文件服务器，并确保服务器对 `index.html` 开启 SPA 路由回退

## 文档

- [设计文档](docs/DESIGN.md) — 架构、功能设计、技术选型
- [使用文档](docs/USAGE.md) — 开发环境、运行、测试、构建
- [API 文档](docs/API.md)
- [变更日志](docs/CHANGELOG.md)

## 许可证

[MIT](LICENSE) © [Qintsg](https://github.com/Qintsg)
