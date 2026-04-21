# 微信文章修复 - 会话状态

## 项目路径
`E:\Projects\Qintsg\SSPU-all-in-one`，分支 `feature/wechat`

## 已完成（全部已提交）
1. Cookie 注入 (2671fce)
2. 虚拟关注 + 书架同步 (3df4f47, f7c57ca)
3. API 路径修正为 /web/mp/articles (624cc92)
4. **文章列表解析 + reader URL 编码** (e3ff54c)
   - `_extractArticleList` 展平 `reviews[].subReviews[]`
   - `_extractArticleDate` 使用 `mpInfo.time`
   - `calculateBookStrId` 算法实现（8/8 测试通过）
   - `_extractArticleUrl` 改用 reader URL
5. **清除文章缓存按钮** (0d5de09)
   - 设置页微信区域新增"数据管理"卡片
   - "清除文章缓存"按钮带二次确认对话框
   - `MessageStateService.clearWechatArticles()` 仅清除微信文章

## 修改的文件
- `lib/services/wechat_article_service.dart`: URL 编码算法 + 修复 URL 构造
- `lib/services/weread_api_service.dart`: 展平 subReviews
- `lib/services/message_state_service.dart`: 新增 clearWechatArticles()
- `lib/pages/settings_page.dart`: 数据管理卡片 + 清除缓存对话框

## 待验证
- 实际运行中点击文章是否能正确打开 reader 页面
- 清除缓存功能的 UI 交互
