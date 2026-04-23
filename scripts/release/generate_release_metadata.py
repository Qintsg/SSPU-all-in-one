#!/usr/bin/env python3
# -*- coding: UTF-8 -*-
'''
Release 资产元数据生成脚本
@Project : SSPU-all-in-one
@File : generate_release_metadata.py
@Author : Qintsg
@Date : 2026-04-23 23:20
'''

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Dict, List


FILENAME_PATTERN = re.compile(
    r"^SSPU-All-in-One-v(?P<version>.+?)-"
    r"(?P<platform>android|ios|windows|macos|linux|web)-"
    r"(?P<arch>universal|x64|arm64|armv7)"
    r"(?:-(?P<kind>installer|portable|bundle|static|unsigned|appimage|deb|rpm))?"
    r"(?P<ext>\.AppImage|\.tar\.gz|\.zip|\.exe|\.dmg|\.deb|\.rpm|\.apk)$"
)


def parse_arguments() -> argparse.Namespace:
    """
    解析命令行参数
    :param: None
    :return: 解析后的参数对象
    """
    parser = argparse.ArgumentParser(description="生成 Release 元数据与校验文件。")
    parser.add_argument("--asset-dir", required=True, help="Release 资产目录。")
    parser.add_argument("--version", required=True, help="完整版本号，例如 0.2.0-alpha+1。")
    parser.add_argument("--channel", required=True, help="版本通道，例如 stable 或 beta。")
    parser.add_argument("--build-number", required=True, type=int, help="构建序号。")
    parser.add_argument("--tag", required=True, help="Release Tag，例如 v0.2.0-alpha。")
    parser.add_argument("--release-date", required=True, help="发布日期，ISO 8601 UTC 格式。")
    parser.add_argument("--flutter-version", required=True, help="Flutter 版本。")
    parser.add_argument("--dart-version", required=True, help="Dart 版本。")
    return parser.parse_args()


def sha256_for_file(file_path: Path) -> str:
    """
    计算文件的 SHA-256
    :param file_path: 待计算文件路径
    :return: 十六进制 SHA-256 值
    """
    digest = hashlib.sha256()
    with file_path.open("rb") as file_handle:
        for chunk in iter(lambda: file_handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def infer_kind(platform_name: str, extension_name: str) -> str:
    """
    为省略 kind 的资产推断类型
    :param platform_name: 平台名称
    :param extension_name: 文件扩展名
    :return: 推断后的资产类型
    :raises ValueError: 无法推断时抛出异常
    """
    if platform_name == "android" and extension_name == ".apk":
        return "bundle"

    raise ValueError(
        f"资产文件名缺少 kind 且无法推断：platform={platform_name}, ext={extension_name}",
    )


def build_platform_entry(asset_file: Path, expected_version: str) -> Dict[str, str]:
    """
    解析单个产物文件并生成 manifest 平台条目
    :param asset_file: 产物文件路径
    :param expected_version: 应与文件名严格匹配的完整版本号
    :return: manifest.json 中的单个平台信息
    :raises ValueError: 文件名不符合命名规范时抛出异常
    """
    match = FILENAME_PATTERN.match(asset_file.name)
    if match is None:
        raise ValueError(f"资产文件名不符合规范：{asset_file.name}")

    parsed_data = match.groupdict()
    if parsed_data["version"] != expected_version:
        raise ValueError(
            f"资产文件版本与 pubspec.yaml 不一致：{asset_file.name} != {expected_version}",
        )

    inferred_kind = parsed_data["kind"] or infer_kind(
        platform_name=parsed_data["platform"],
        extension_name=parsed_data["ext"],
    )

    return {
        "platform": parsed_data["platform"],
        "arch": parsed_data["arch"],
        "kind": inferred_kind,
        "filename": asset_file.name,
        "sha256": sha256_for_file(asset_file),
    }


def collect_release_assets(asset_directory: Path) -> List[Path]:
    """
    收集目录中的发布资产文件
    :param asset_directory: Release 资产目录
    :return: 资产文件路径列表
    """
    return sorted(
        [
            file_path
            for file_path in asset_directory.iterdir()
            if file_path.is_file() and file_path.name != "SHA256SUMS.txt"
        ],
        key=lambda path_item: path_item.name,
    )


def render_manifest(
    platform_entries: List[Dict[str, str]],
    arguments: argparse.Namespace,
) -> Dict[str, object]:
    """
    生成 manifest.json 对象
    :param platform_entries: 已解析的产物条目
    :param arguments: 命令行参数
    :return: manifest.json 对应的数据结构
    """
    return {
        "name": "SSPU-all-in-one",
        "version": arguments.version,
        "channel": arguments.channel,
        "build_number": arguments.build_number,
        "tag": arguments.tag,
        "release_date": arguments.release_date,
        "flutter_version": arguments.flutter_version,
        "dart_version": arguments.dart_version,
        "platforms": platform_entries,
    }


def write_sha256_sums(asset_directory: Path, asset_files: List[Path]) -> None:
    """
    写入 SHA256SUMS.txt
    :param asset_directory: Release 资产目录
    :param asset_files: 需要写入校验值的资产列表
    :return: None
    """
    checksum_lines: List[str] = []
    for asset_file in asset_files:
        checksum_lines.append(f"{sha256_for_file(asset_file)}  {asset_file.name}")

    checksum_path = asset_directory / "SHA256SUMS.txt"
    checksum_path.write_text("\n".join(checksum_lines) + "\n", encoding="utf-8")


def main() -> int:
    """
    程序主入口
    :param: None
    :return: 进程退出码，成功返回 0
    """
    arguments = parse_arguments()
    asset_directory = Path(arguments.asset_dir)
    asset_directory.mkdir(parents=True, exist_ok=True)

    raw_asset_files = collect_release_assets(asset_directory)
    product_asset_files = [
        asset_file
        for asset_file in raw_asset_files
        if asset_file.suffix != ".md" and asset_file.name != "manifest.json"
    ]

    if not product_asset_files:
        raise ValueError("未在资产目录中找到任何可发布产物。")

    platform_entries = [
        build_platform_entry(asset_file=asset_file, expected_version=arguments.version)
        for asset_file in product_asset_files
    ]

    manifest_path = asset_directory / "manifest.json"
    manifest_payload = render_manifest(platform_entries=platform_entries, arguments=arguments)
    manifest_path.write_text(
        json.dumps(manifest_payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    checksum_assets = collect_release_assets(asset_directory)
    write_sha256_sums(asset_directory=asset_directory, asset_files=checksum_assets)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
