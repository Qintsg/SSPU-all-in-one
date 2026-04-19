# Task H - 微信读书Cookie便捷获取 + 公众号导入

## 状态: ✅ 已完成

## 已完成工作

### Task 1: WebView 扫码登录
- 创建 `lib/pages/weread_login_page.dart`
- 使用 webview_windows 加载 `https://weread.qq.com/#login`
- 监听 URL 变化检测登录成功
- 通过 `executeScript('document.cookie')` 自动提取 Cookie
- 保存到 `WereadAuthService`
- settings_page 新增"扫码登录" FilledButton

### Task 2: CampusPlus 公众号导入
- 通过 CampusPlus API (POST `newmedia/52/search`) 获取到 37 个公众号
- 创建 `lib/models/sspu_wechat_accounts.dart` 存储所有公众号数据
- settings_page 新增 SSPU 推荐公众号卡片展示

### Git Commit
- `feat(wechat): 新增微信读书扫码登录与SSPU推荐公众号导入` (d3b1ffc)
- 3 files changed, 717 insertions(+), 1 deletion(-)

### 变更文件
1. `lib/models/sspu_wechat_accounts.dart` — 新增，37个SSPU官方公众号数据
2. `lib/pages/weread_login_page.dart` — 新增，WebView扫码登录页
3. `lib/pages/settings_page.dart` — 修改，新增扫码登录按钮和推荐公众号卡片

### 验证
- flutter analyze: 0 errors, 0 warnings (仅3个info级别的pre-existing lint)

## Dida365 项目 ID: 69e37a01e4b0028dfb42216d
