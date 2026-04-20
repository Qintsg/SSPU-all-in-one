# 上下文恢复点 — 任务1.3 设置页左侧导航重构

## 状态
- ✅ 1.1 + 1.2 代码拆分完成，已提交 350b464，Dida365已标记完成
- ➡️ 1.3 设置页左侧导航+右侧内容重构：刚开始，尚未修改代码
- 密集对话：已关闭

## 项目信息
- 路径: e:\Projects\Qintsg\SSPU-all-in-one
- 分支: develop
- Dida365项目ID: 69e37a01e4b0028dfb42216d
- Flutter 3.41.4, Dart 3.11.1, fluent_ui ^4.11.1
- .withValues(alpha:x) 非 .withOpacity()
- commit格式: type(scope): 中文摘要，不主动 git push

## 任务1.3 目标
将 settings_page.dart 从顶部 tab 导航改为左侧导航+右侧内容面板。

### 当前结构（需要重构）
- 4个顶部tab: 安全 / 窗口行为 / 信息渠道 / 消息推送
- _selectedTab 变量控制当前显示
- 使用 buildNavTab() 函数构建tab按钮（已提取到 settings_widgets.dart）

### 目标结构
左侧垂直导航 + 右侧内容面板，6个栏目:
1. **安全** — 密码保护开关+修改+上锁（保持现有功能）
2. **窗口行为** — 关闭按钮行为选择（保持现有功能）
3. **消息推送** — 推送全局开关+勿扰时段（保持现有功能）
4. **职能部门** — 通道列表+总开关（新：教务处、信息技术中心、体育部、保卫处、校区建设办、新闻网、学生处），点击进二级详细设置
5. **教学单位** — 通道列表+总开关（新：19个学院/部门），点击进二级详细设置
6. **微信** — 仅占位文本

### 现有信息渠道的去向
- "最新公开信息"和"通知公示"（信息公开网通道）→ 重新划分到职能部门（信息公开网属于学校级别）
- "微信公众号"和"微信服务号"→ 移到微信占位栏目

### 设计方案
- 使用 Row 布局：左侧固定宽度导航栏（约200px）+ 右侧 Expanded 内容区
- 左侧导航：垂直排列的导航项，带图标和文本，高亮当前选中
- 右侧内容：根据选中栏目显示对应卡片
- 职能部门/教学单位栏目：显示通道列表，每个通道一行（图标+名称+描述+总开关），点击行进入二级页面
- 二级页面：用 Navigator 或简单的状态切换实现

## settings_page.dart 当前内容概览（约620行）
- L1-15: 文件头+imports
- L16-28: SettingsPage StatefulWidget 定义
- L29-73: _SettingsPageState 状态变量
- L74-121: initState + _loadSettings
- L122-132: _showSuccessBar
- L133-: build 方法
  - L143-162: 顶部tab导航（需要替换为左侧导航）
  - L165-246: 安全设置卡片 (_selectedTab == 0)
  - L248-320: 窗口行为卡片 (_selectedTab == 1)
  - L322-434: 信息渠道卡片 (_selectedTab == 2) — 需要重构
  - L436-608: 消息推送卡片 (_selectedTab == 3)
- L609-: _showChannelChangedTip 方法

## 关键文件
- lib/pages/settings_page.dart — 主文件，需要大幅重构
- lib/widgets/settings_widgets.dart — buildNavTab, buildChannelToggle, buildIntervalSelector, buildTimePicker, kIntervalOptions
- lib/widgets/password_dialogs.dart — 密码对话框
- lib/services/message_state_service.dart — 通道开关+推送配置
- lib/services/auto_refresh_service.dart — 自动刷新
- lib/services/storage_service.dart — 本地存储
- lib/models/message_item.dart — MessageSourceType/Name/Category 枚举

## Dida365 任务 ID
- 1.3: 69e44c91e4b0028dfb49639f（当前任务）
- 1.4: 69e44c91e4b00f7b01726187
- 2.1: 69e44c91e4b0e7770300b87f
- 2.2: 69e44c91e4b0028dfb4963a0
- 2.3: 69e44c91e4b0e7770300b880
- 3.1-3.3, 4.1-4.5, 5.1-5.19, 6.1-6.2 见 dida365-state.md

## 实施计划
1. 重构 build() 方法：替换顶部 tab 为左侧垂直导航
2. 新增"职能部门"栏目内容
3. 新增"教学单位"栏目内容
4. 新增"微信"占位栏目
5. 重新组织"信息渠道"中的通道到新栏目
6. 实现通道二级设置页面（可能需要新建 widget 文件）
7. flutter analyze + flutter build windows
8. git commit
