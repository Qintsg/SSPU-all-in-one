#!/usr/bin/env python3
# -*- coding: UTF-8 -*-
'''
发布说明提取与校验脚本
@Project : SSPU-all-in-one
@File : render_release_notes.py
@Author : Qintsg
@Date : 2026-04-23 23:20
'''

from __future__ import annotations

import argparse
from pathlib import Path
from typing import Dict, List


REQUIRED_SECTION_TITLES: List[str] = [
    "亮点",
    "破坏性变更",
    "平台清单",
    "安装 / 升级说明",
    "Linux 安装说明",
    "已知问题",
    "校验信息",
]


def parse_arguments() -> argparse.Namespace:
    """
    解析命令行参数
    :param: None
    :return: 解析后的参数对象
    """
    parser = argparse.ArgumentParser(description="校验并渲染 Release Notes。")
    parser.add_argument("--body-file", required=True, help="PR 正文 markdown 文件路径。")
    parser.add_argument("--output", required=True, help="生成的 release-notes.md 输出路径。")
    parser.add_argument(
        "--validate-only",
        action="store_true",
        help="仅校验必备章节，不写入输出文件。",
    )
    return parser.parse_args()


def collect_sections(markdown_text: str) -> Dict[str, List[str]]:
    """
    从 markdown 中提取二级标题章节
    :param markdown_text: 原始 markdown 文本
    :return: 以二级标题为键、正文行为值的章节映射
    """
    sections: Dict[str, List[str]] = {}
    current_title: str | None = None

    for line in markdown_text.splitlines():
        if line.startswith("## "):
            current_title = line[3:].strip()
            sections.setdefault(current_title, [])
            continue

        if current_title is not None:
            sections[current_title].append(line.rstrip())

    return sections


def normalize_section_lines(section_lines: List[str]) -> List[str]:
    """
    清理章节内容中的空白行
    :param section_lines: 原始章节行
    :return: 去掉首尾空白后的章节内容
    """
    normalized_lines: List[str] = [line for line in section_lines]

    while normalized_lines and not normalized_lines[0].strip():
        normalized_lines.pop(0)

    while normalized_lines and not normalized_lines[-1].strip():
        normalized_lines.pop()

    return normalized_lines


def validate_required_sections(section_map: Dict[str, List[str]]) -> Dict[str, List[str]]:
    """
    校验发布说明中的必备章节
    :param section_map: 已解析的章节映射
    :return: 仅包含必备章节且内容已规范化的映射
    :raises ValueError: 当必备章节缺失或内容为空时抛出异常
    """
    validated_sections: Dict[str, List[str]] = {}
    missing_titles: List[str] = []
    empty_titles: List[str] = []

    for required_title in REQUIRED_SECTION_TITLES:
        if required_title not in section_map:
            missing_titles.append(required_title)
            continue

        normalized_lines = normalize_section_lines(section_map[required_title])
        if not normalized_lines:
            empty_titles.append(required_title)
            continue

        validated_sections[required_title] = normalized_lines

    if missing_titles or empty_titles:
        message_lines: List[str] = ["Release PR 正文未满足发布说明模板要求："]
        if missing_titles:
            message_lines.append(f"- 缺失章节：{', '.join(missing_titles)}")
        if empty_titles:
            message_lines.append(f"- 章节为空：{', '.join(empty_titles)}")
        raise ValueError("\n".join(message_lines))

    return validated_sections


def render_release_notes(section_map: Dict[str, List[str]]) -> str:
    """
    按固定顺序输出发布说明
    :param section_map: 已校验完成的章节映射
    :return: 规范化后的 release notes 文本
    """
    rendered_lines: List[str] = []

    for required_title in REQUIRED_SECTION_TITLES:
        rendered_lines.append(f"## {required_title}")
        rendered_lines.extend(section_map[required_title])
        rendered_lines.append("")

    return "\n".join(rendered_lines).rstrip() + "\n"


def main() -> int:
    """
    程序主入口
    :param: None
    :return: 进程退出码，成功返回 0
    """
    arguments = parse_arguments()
    markdown_text = Path(arguments.body_file).read_text(encoding="utf-8")
    section_map = collect_sections(markdown_text)
    validated_sections = validate_required_sections(section_map)

    if arguments.validate_only:
        return 0

    rendered_notes = render_release_notes(validated_sections)
    output_path = Path(arguments.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(rendered_notes, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
