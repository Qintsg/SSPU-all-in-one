# Session State — WeChat MP Platform Feature

## Current Task
为微信公众号推文获取添加第二种方式（公众号平台方式），参照 WeRSS/we-mp-rss 项目。

## Git State
- Branch: `feature/wechat`
- HEAD: `29e7666` (all previous work committed, build verified)

## Dida365
- Project ID: `69e37a01e4b0028dfb42216d`
- Project name: `mcp-SSPU-all-in-one`

## Intensive Chat
- Session ID: `5861d38c0b152268` — STILL OPEN
- Latest user request: "请你再给现在已有的WeRead方案编写一份完整详细的实现文档"

## Files Created
- `docs/wechat-mp-platform-design.md` — 公众号平台方式技术设计文档 (DONE)
- Need to create: WeRead 现有方案实现文档

## Existing WeRead Implementation Files (已读取完毕)

### lib/services/weread_auth_service.dart
- Singleton: `WereadAuthService.instance`
- Storage keys: `weread_cookie_string`, `weread_vid`, `weread_skey`, `weread_cookie_last_update`
- Key methods: `saveCookies(rawCookie)`, `getCookieString()`, `getVid()`, `hasCookies()`, `clearCookies()`, `validateCookie({webViewController})`, `renewCookie({webViewController})`
- Validates via WebView JS fetch or Dio fallback
- API: `https://weread.qq.com/web/shelf/sync` (validate), `https://weread.qq.com/web/login/renewal` (renew)

### lib/services/weread_api_service.dart
- Singleton: `WereadApiService.instance`
- API base: `https://weread.qq.com/web`
- Key methods: `getShelf()`, `getFollowedMpBookIds()`, `getArticleContent(reviewId)`, `getArticles(bookId, {offset, count})`, `getAllArticles(bookId, {maxCount})`, `getBookInfo(bookId)`, `search(keyword, {count})`
- ALL API calls go through WebView JS fetch (Cookie session bound to WebView2)
- Uses HeadlessInAppWebView via WereadWebViewService
- Article list: `/web/mp/articles?bookId=xxx`
- Article parsing: `reviews[].subReviews[]` flattened

### lib/services/weread_webview_service.dart
- Singleton: `WereadWebViewService.instance`
- Manages HeadlessInAppWebView for background session
- `ensureInitialized()`: creates headless WebView, loads weread.qq.com, injects stored cookies
- `reinitialize()`: dispose + ensureInitialized
- Cookie injection: parses stored cookie string, injects via CookieManager to both domains

### lib/services/wechat_article_service.dart
- Singleton: `WechatArticleService.instance`
- Storage key: `wechat_followed_mps` (JSON: {bookId: name})
- Local follow management (independent of WeRead shelf)
- `fetchArticles({maxCount})`: iterates local followed MPs, calls WereadApiService
- `followMpBySearch(keyword)`, `syncFromShelf()`, `followMpDirectly(bookId, name)`, `unfollowMp(bookId)`
- Article→MessageItem conversion: `_articleToMessageItem()`
- URL encoding: `calculateBookStrId(bookId)` with MD5-based encoding, `_transformId()`

### lib/pages/weread_login_page.dart
- InAppWebView loads `https://weread.qq.com/#login`
- Detects login success: URL changes to `/web/shelf`
- Extracts cookies via CookieManager (up to 5 retries with incremental delay)
- Validates via WebView JS, then starts HeadlessInAppWebView service
- Returns true/false via Navigator.pop

### lib/pages/settings_page.dart — WeChat Tab
- Tab index 5 (微信)
- `_buildWechatSection()` shows:
  - Cookie config card (status, scan login, manual cookie, validate, refresh, clear)
  - Followed MP list with per-MP notification toggles
  - Channel switches (ChannelListSection)
  - SSPU recommended accounts
- State vars: `_wereadAuthenticated`, `_wereadChecking`, `_followedMps`, `_mpNotificationEnabled`

### lib/services/http_service.dart
- HTTP client wrapper using Dio

### lib/services/storage_service.dart
- SharedPreferences wrapper
- `clearAll()`: clears all prefs
- StorageKeys constants

### lib/models/message_item.dart
- MessageItem with sourceType, sourceName, category
- MessageSourceType.wechatPublic, MessageSourceName.wechatPublicPlaceholder

### Dependencies (pubspec.yaml)
- fluent_ui: ^4.11.1
- shared_preferences: ^2.5.3
- crypto: ^3.0.6
- dio: ^5.8.0+1
- flutter_inappwebview: ^6.1.5
- window_manager: ^0.4.3
- html: ^0.15.5
- flutter_animate: ^4.5.2

## Implementation Plan (from design doc)
1. New: `lib/services/wxmp_auth_service.dart`
2. New: `lib/services/wxmp_article_service.dart`
3. New: `lib/pages/wxmp_login_page.dart`
4. Modify: `lib/services/wechat_article_service.dart` (method switching)
5. Modify: `lib/pages/settings_page.dart` (method selector UI)
6. New: `docs/wechat-mp-guide.md` (user guide)
