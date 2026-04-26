# AGENTS.md

## 0.基础信息

本仓库为项目仓库，项目名称为：SSPU-all-in-one

## 1. 适用范围

所有代理都必须遵守本文件；进入 `frontend/` 或 `backend/` 时，还必须同时遵守对应目录下的 `AGENTS.md`。

---

## 2. 规则优先级

冲突处理顺序：

1. 用户当前明确要求
2. 子目录 `AGENTS.md`
3. 根目录 `AGENTS.md`
4. 仓库既有约定
5. 官方标准与通用工程约定

---

## 3. 通用工作原则

### 3.1 修改前

先阅读：

- 相邻文件
- 当前模块目录
- 已有分层方式
- API 契约
- 测试风格
- 脚本与配置
- 相关文档

### 3.2 修改时

优先：

- 最小改动
- 最小影响面
- 最低回滚成本
- 最易审查的实现

### 3.3 修改后

必须保证：

- 分层清晰
- 代码可验证
- 注释有效
- 类型完整
- 文档同步
- 当前块内容已提交

### 3.4 未完成实现

默认要求是“可运行、可验证、可交付”。

除非确有必要，不保留：

- 仅有函数名的空实现
- 函数体仅 `pass`
- 假返回值占位
- 假成功逻辑
- 未接线的伪完成功能

若确有必要保留未完成事项，只允许使用：

- `TODO:`
- `FIXME:`

并写清：

- 原因
- 影响范围
- 后续动作
- 风险说明

### 3.5 最终表达

最终代码、注释、文档、提交说明中，只保留稳定、正向、可执行、面向结果的内容。
过程性口语说明、情绪化说明、临时性抱怨式表达都必须清理掉。

---

## 4. Git 工作流

### 4.1 开始任务前

固定流程：

1. `git status`
2. 检查是否有未提交内容
3. 若有未提交内容：
   - 与当前任务相关且已稳定：先 commit
   - 与当前任务无关：做保护性 commit
4. 状态安全后执行 `git pull --rebase`
5. pull 产生冲突时自行处理
6. pull 完成后再开始改动

### 4.2 提交节奏

每完成一个**独立可审查块**，必须 commit 一次。
块内容示例：

- 一个接口修复
- 一个页面完整调整
- 一组关联模型与序列化修改
- 一次测试补充
- 一次文档同步

### 4.3 commit 规范

提交信息格式：

```text
type(scope): 中文摘要
```

可用 `type`：

- `feat`
- `fix`
- `refactor`
- `docs`
- `style`
- `test`
- `perf`
- `build`
- `ci`
- `chore`
- `revert`

示例：

```text
feat(frontend): 新增用户管理页筛选面板
fix(backend): 修复订单分页接口空参数异常
docs(api): 补充用户详情接口响应字段说明
chore(repo): 任务开始前保存未提交内容
```

### 4.3.1 外部引用限制

commit message、代码注释、文档中，禁止包含：

- 外部 GitHub issue 引用格式 `owner/repo#number`（如 `flutter/flutter#12345`）
- 外部 GitHub issue / PR 的完整 URL
- 其他外部仓库的引用链接

原因：GitHub 会自动在被引用的 issue 页面创建 cross-reference 记录，且无法删除。

### 4.4 默认禁止的 Git 动作

除非用户明确要求或明确要求处理issue/pr，否则不主动执行：

- `git push`
- 切换分支
- 新建分支
- 提交 PR
- 改写远端历史

---

## 5. 文档规则

### 5.1 文档位置

说明文档统一放在：

- `docs/`

重点文档：

- `docs/API.md`
- `docs/CHANGELOG.md`

### 5.2 完成工作后必须同步更新文档

只要变更影响：

- API 契约
- 配置
- 权限
- 数据结构
- 迁移
- 路由
- 平台支持
- 开发 / 运行流程
- 错误处理与联调方式

就必须同步更新 `docs/` 下相关文档。

### 5.3 更新原则

更新文档时：

- 保留原有总体结构
- 仅在相关章节增补或修订
- 保持原有标题层级
- 保持现有风格
- 不随意重写整份文档

### 5.4 版本号

除非用户明确要求或任务本身就是发版，不修改版本号。

### 5.5 目录新增限制

`frontend/` 与 `backend/` 下默认不新增说明型文档。
允许新增的必要文件仅限：

- `.env.example`
- 依赖或工具链必须存在的标准文件
- 运行、构建、部署、测试所需的配置模板

---

## 6. 全仓库代码规范

### 6.1 通用要求

除子目录文件另有规定外，代码规范遵循：

- 官方标准文档
- 仓库既有约定
- 通用工程实践

### 6.2 注释率

所有手写代码注释率必须满足：

- 不低于 20%
- 不高于 50%

注释必须解释：

- 意图
- 约束
- 边界
- 风险
- 为什么这样做

### 6.3 弱类型与弱命名限制

前后端统一要求：

- 禁止无语义变量名，如 `var`、`tmp`、`foo`、`bar`、`data`、`obj`
- 禁止用注释弥补糟糕命名
- 优先强类型、显式类型、清晰命名

### 6.4 TODO / FIXME

只在确有必要时保留，并写清原因、影响与后续动作。

### 6.5 审查清单

提交前至少自查：

- 命名是否清晰
- 类型是否完整
- 注释是否有效
- 是否残留调试代码
- 是否有无说明 TODO / FIXME
- 是否影响 API / DB / 平台
- 是否已更新相关 `docs/`
- 当前块内容是否已 commit

### 6.6 Python专项注释要求

Python除文件头、函数注释外均使用PEP 8标准

#### 6.6.1 Python 文件头

默认模板：

```python
#!/user/bin/env python
# -*- coding: UTF-8 -*-
'''
文件内容描述
@Project : ${PROJECT_NAME}
@File : ${NAME}.py
@Author : Qintsg
@Date : ${DATE} ${TIME}
'''
```

#### 6.6.2 Python 函数注释

默认模板：

```python
def fun_name(var1: int, var2: List[double]) -> None | str:
    """
    函数功能描述
    :param var1: 变量1描述
    :param var2: 变量2描述
    :return: 返回值描述
    """
    pass
```

要求：

- 所有参数必须写类型注释
- 所有返回值必须写类型注释
- `-> None` 必须显式写出
- 注释说明目的、参数语义、返回语义，必要时说明异常

### 6.7 Flutter(Dart)专项注释要求

#### 6.7.1 Dart 文件头

若仓库无既有模板，默认：

```dart
/*
 * 文件内容描述
 * @Project : ${PROJECT_NAME}
 * @File : ${NAME}.dart
 * @Author : Qintsg
 * @Date : ${DATE} ${TIME}
 */
```

#### 6.7.2 Dart 函数注释

若仓库无既有模板，默认：

```dart
/**
 * 函数功能描述
 * @param userId 用户标识
 * @param orderItems 订单项集合
 * @return 返回值描述
 */
Future<OrderDetailState> buildOrderDetailState(
  int userId,
  List<OrderItemModel> orderItems,
) async {
  return OrderDetailState.empty();
}
```

若仓库统一采用 `///` Dartdoc 风格，可沿用，但信息量不得低于上例。
