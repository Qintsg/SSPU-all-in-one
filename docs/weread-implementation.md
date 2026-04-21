# 微信读书方式 — 现有实现文档

> 本文档为"方式一：微信读书"（WeRead API）的完整实现参考。  
> 记录当前项目中已实现的完整技术细节，供维护和对比参考。

---

## 1. 方案概述

通过微信读书 Web 版（weread.qq.com）的 API 获取用户已关注的公众号推文。

### 1.1 核心依赖

- 微信读书 Web 版 API（`weread.qq.com/web/*`）
- InAppWebView（flutter_inappwebview ^6.1.5）用于维持 Cookie session
- Cookie 认证（`wr_skey` + `wr_vid`）

### 1.2 技术限制

- Cookie 与 WebView2 session 绑定，外部 HTTP 客户端（如 Dio）无法直接使用
- 所有 API 请求必须通过 WebView 内部的 JS fetch 执行
- 微信读书搜索 API 已下架，新增关注只能通过书架同步

### 1.3 架构图

```
用户扫码登录 weread.qq.com
  → WereadLoginPage (InAppWebView)
  → 提取 Cookie (CookieManager)
  → WereadAuthService 存储 Cookie
  → WereadWebViewService 后台 HeadlessInAppWebView
  → WereadApiService 通过 JS fetch 调用 API
  → WechatArticleService 转换为 MessageItem
```

---

## 2. 文件清单与职责

| 文件 | 职责 |
|------|------|
| `lib/services/weread_auth_service.dart` | Cookie 存储、校验、刷新 |
| `lib/services/weread_api_service.dart` | 微信读书 REST API 封装 |
| `lib/services/weread_webview_service.dart` | 后台 HeadlessInAppWebView 管理 |
| `lib/services/wechat_article_service.dart` | 文章采集与 MessageItem 转换 |
| `lib/pages/weread_login_page.dart` | 扫码登录 WebView 页面 |
| `lib/pages/settings_page.dart` | 设置页微信 Tab（认证管理 + 关注列表） |

---

## 3. WereadAuthService — 认证服务

### 3.1 单例模式

```dart
class WereadAuthService {
  WereadAuthService._();
  static final WereadAuthService instance = WereadAuthService._();
}
```

### 3.2 存储键名

| 键名 | 用途 | 类型 |
|------|------|------|
| `weread_cookie_string` | 完整 Cookie 字符串 | String |
| `weread_vid` | wr_vid（用户标识） | String |
| `weread_skey` | wr_skey（会话密钥） | String |
| `weread_cookie_last_update` | Cookie 最后更新时间戳 | int (毫秒) |

### 3.3 核心方法

#### saveCookies(String rawCookie) → Future<bool>

解析 Cookie 字符串，提取 `wr_vid` 和 `wr_skey`，四项分别存入 StorageService。  
返回值：是否包含必要字段。

#### getCookieString() → Future<String?>

获取完整 Cookie 字符串，用于注入请求头。

#### hasCookies() → Future<bool>

检查本地是否存有 Cookie（不校验有效性）。

#### clearCookies() → Future<void>

清除所有四个存储键。

#### validateCookie({dynamic webViewController}) → Future<bool>

验证 Cookie 是否有效。

**优先方式**：通过 WebView 内部 JS fetch 调用：
```javascript
const resp = await fetch('/web/shelf/sync?synckey=0&teenmode=0', { credentials: 'include' });
const data = await resp.json();
// data.errcode == 0 表示有效
```

**回退方式**：通过 Dio 外部请求：
```dart
GET https://i.weread.qq.com/shelf/sync?synckey=0&teenmode=0&album=1
Headers: Cookie, User-Agent, Referer, Origin, Sec-Fetch-*
```

#### renewCookie({dynamic webViewController}) → Future<bool>

刷新 Cookie 续期。

**优先方式**：WebView JS fetch：
```javascript
const resp = await fetch('/web/login/renewal', {
  method: 'POST',
  credentials: 'include',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ rq: '%2Fweb%2Fbook%2Fread' })
});
// data.succ == 1 表示成功
```

**回退方式**：Dio POST `https://weread.qq.com/web/login/renewal`

### 3.4 请求头构造

```dart
Map<String, dynamic> _buildHeaders(String cookie) {
  return {
    'Cookie': cookie,
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Referer': 'https://weread.qq.com/',
    'Origin': 'https://weread.qq.com',
    'Sec-Fetch-Site': 'same-site',
    'Sec-Fetch-Mode': 'cors',
    'Sec-Fetch-Dest': 'empty',
    'Accept': 'application/json, text/plain, */*',
  };
}
```

### 3.5 Cookie 解析与更新

- `_parseCookieString(String)`: 将 `"key1=val1; key2=val2"` 解析为 Map
- `_updateFromSetCookie(List<String>)`: 从响应 Set-Cookie 头合并更新本地 Cookie

---

## 4. WereadWebViewService — WebView 会话服务

### 4.1 职责

维持后台 HeadlessInAppWebView 实例，保持微信读书登录态。  
所有 API 请求都通过此 WebView 的 JS fetch 执行，确保 Cookie session 有效。

### 4.2 单例

```dart
class WereadWebViewService {
  WereadWebViewService._();
  static final WereadWebViewService instance = WereadWebViewService._();
}
```

### 4.3 核心属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `_headlessWebView` | HeadlessInAppWebView? | 后台 WebView 实例 |
| `_controller` | InAppWebViewController? | WebView 控制器 |
| `_isReady` | bool | 是否初始化完成 |
| `controller` | InAppWebViewController? | 公开的控制器 getter |
| `isReady` | bool | 公开的就绪状态 getter |

### 4.4 核心方法

#### ensureInitialized() → Future<bool>

创建 HeadlessInAppWebView，加载 `https://weread.qq.com/`。  
加载完成后注入本地存储的 Cookie（`_injectStoredCookies`）。  
超时 30 秒。支持并发调用安全（Completer 锁）。

#### dispose() → Future<void>

销毁 WebView，释放资源。

#### reinitialize() → Future<bool>

先 dispose 再 ensureInitialized，用于 Cookie 变更后刷新 session。

### 4.5 Cookie 注入流程

```dart
Future<void> _injectStoredCookies() async {
  // 1. 从 WereadAuthService 获取存储的 Cookie 字符串
  // 2. 解析为键值对
  // 3. 通过 CookieManager.setCookie 逐个注入到两个域:
  //    - https://weread.qq.com/
  //    - https://i.weread.qq.com/
  //    domain: '.weread.qq.com', path: '/', isSecure: true
  // 4. 重新加载 weread.qq.com 激活 session
  // 5. 等待 3 秒
}
```

---

## 5. WereadApiService — API 服务

### 5.1 单例

```dart
class WereadApiService {
  WereadApiService._();
  static final WereadApiService instance = WereadApiService._();
}
```

### 5.2 API 基础 URL

```dart
static const String _apiBase = 'https://weread.qq.com/web';
```

### 5.3 核心方法

| 方法 | API 路径 | 参数 | 返回 |
|------|----------|------|------|
| `getShelf()` | `/shelf/sync` | synckey=0, teenmode=0, album=1 | 书架 JSON |
| `getFollowedMpBookIds()` | 调用 getShelf | — | `List<String>` (MP_WXS_* bookIds) |
| `getArticles(bookId, {offset, count})` | `/mp/articles` | bookId, offset, count | 文章列表 JSON |
| `getAllArticles(bookId, {maxCount})` | 循环调用 getArticles | — | `List<Map>` 全量文章 |
| `getArticleContent(reviewId)` | `/mp/content` | reviewId | 文章内容 JSON |
| `getBookInfo(bookId)` | `/book/info` | bookId | 书籍/公众号详情 JSON |
| `search(keyword, {count})` | `/mp/search` | keyword, count | 搜索结果 JSON |

### 5.4 请求执行机制

**所有请求都通过 WebView JS fetch 执行**：

```dart
Future<Map<String, dynamic>?> _getJson(String url, {Map<String, dynamic>? queryParameters}) async {
  // 1. 检查 Cookie 是否存在
  // 2. 拼接查询参数到 URL
  // 3. 获取 WereadWebViewService 的 controller
  //    - 若已就绪：直接调用 _getJsonViaWebView
  //    - 若未就绪：先 ensureInitialized()，成功后调用
  //    - 均不可用：返回 null
}
```

**JS fetch 实现**：

```dart
Future<Map<String, dynamic>?> _getJsonViaWebView(controller, fullUrl) async {
  final result = await controller.callAsyncJavaScript(
    functionBody: '''
      try {
        const resp = await fetch(url, {
          method: 'GET',
          credentials: 'include',
          headers: { 'Accept': 'application/json, text/plain, */*' }
        });
        if (status !== 200) return { __error: true, status };
        return await resp.json();
      } catch (e) {
        return { __error: true, message: e.toString() };
      }
    ''',
    arguments: {'url': fullUrl},
  );
  // 解析 CallAsyncJavaScriptResult.value
  // 检查 __error 标记和业务 errCode
}
```

### 5.5 文章列表解析

`/web/mp/articles` 返回格式：

```json
{
  "reviews": [
    {
      "subReviews": [
        {
          "review": {
            "reviewId": "...",
            "mpInfo": {
              "title": "文章标题",
              "originalUrl": "https://mp.weixin.qq.com/...",
              "time": 1721452800
            }
          }
        }
      ]
    }
  ]
}
```

解析逻辑（`_extractArticleList`）：
1. 遍历 `reviews[]`
2. 展平 `subReviews[]`（每个 subReview 是一篇文章）
3. 若无 subReviews，直接作为文章
4. 兜底：尝试 `articles[]` 或 `data[]` 字段

---

## 6. WechatArticleService — 文章采集服务

### 6.1 单例

```dart
class WechatArticleService {
  WechatArticleService._();
  static final WechatArticleService instance = WechatArticleService._();
}
```

### 6.2 存储键名

| 键名 | 用途 | 格式 |
|------|------|------|
| `wechat_followed_mps` | 本地关注列表 | JSON: `{"bookId": "公众号名称", ...}` |

### 6.3 本地关注管理

与微信读书书架解耦，独立维护本地关注列表。

| 方法 | 说明 |
|------|------|
| `getLocalFollowedMps()` | 获取关注列表 `Map<String, String>` |
| `followMpBySearch(keyword)` | 搜索并关注 |
| `syncFromShelf()` | 从书架同步公众号 |
| `followMpDirectly(bookId, name)` | 直接关注 |
| `unfollowMp(bookId)` | 取消关注 |
| `isFollowed(bookId)` | 检查是否已关注 |

### 6.4 fetchArticles({maxCount}) — 核心采集方法

```dart
Future<List<MessageItem>> fetchArticles({int maxCount = 50}) async {
  // 1. 检查认证状态 (WereadAuthService.hasCookies)
  // 2. 获取本地关注列表 (getLocalFollowedMps)
  // 3. 遍历每个公众号:
  //    a. 检查通知开关 (MessageStateService.isMpNotificationEnabled)
  //    b. 调用 WereadApiService.getAllArticles(bookId, maxCount: 10)
  //    c. 将每篇文章通过 _articleToMessageItem 转换
  // 4. 返回 allMessages
}
```

### 6.5 文章→MessageItem 转换

```dart
MessageItem? _articleToMessageItem(article, mpName, bookId) {
  // 提取标题: review.mpInfo.title → review.content → article.title
  // 提取URL: review.mpInfo.originalUrl → review.mpInfo.doc_url
  //          → 构造 weread reader URL (用 bookStrId + reviewId)
  //          → article.url / originalUrl / mp_url
  // 提取日期: review.mpInfo.time → review.createTime → article.create_time
  //          → 秒级时间戳转 YYYY-MM-DD
  // ID: URL 的 MD5
  
  return MessageItem(
    id: md5(url),
    title: title,
    date: date,
    url: url,
    sourceType: MessageSourceType.wechatPublic,
    sourceName: MessageSourceName.wechatPublicPlaceholder,
    category: MessageCategory.wechatArticle,
    mpBookId: bookId,
    mpName: mpName,
  );
}
```

### 6.6 bookId 编码 — calculateBookStrId

微信读书 reader URL 格式：`https://weread.qq.com/web/mp/reader/{bookStrId}?reviewId={reviewId}`

```dart
static String calculateBookStrId(String bookId) {
  final digest = md5(bookId);
  final buf = StringBuffer(digest.substring(0, 3));
  
  final (code, transformedIds) = _transformId(bookId);
  buf.write(code);     // '3'(纯数字) 或 '4'(非纯数字)
  buf.write('2');
  buf.write(digest.substring(digest.length - 2));
  
  for (var i = 0; i < transformedIds.length; i++) {
    var hexLen = transformedIds[i].length.toRadixString(16);
    if (hexLen.length == 1) hexLen = '0$hexLen';
    buf.write(hexLen);
    buf.write(transformedIds[i]);
    if (i < transformedIds.length - 1) buf.write('g');
  }
  
  // 不足 20 位用 digest 补齐
  // 最后追加 result 的 MD5 前 3 位
}

static (String, List<String>) _transformId(String bookId) {
  final isNumeric = bookId.codeUnits.every((c) => c >= 48 && c <= 57);
  if (isNumeric) {
    // 每 9 位数字转 hex
    return ('3', chunkedHexList);
  }
  // 逐字符 codeUnit 转 hex
  return ('4', [hexString]);
}
```

---

## 7. WereadLoginPage — 扫码登录页

### 7.1 登录流程

1. InAppWebView 加载 `https://weread.qq.com/#login`
2. 监听 URL 变化（`onUpdateVisitedHistory` / `onLoadStop`）
3. 检测登录成功：URL 以 `https://weread.qq.com/web/shelf` 开头，或不再包含 `#login`
4. 调用 `_extractCookies()` 提取 Cookie

### 7.2 Cookie 提取

```dart
Future<void> _extractCookies() async {
  final cookieManager = CookieManager.instance();
  final urls = [
    WebUri('https://weread.qq.com/'),
    WebUri('https://i.weread.qq.com/'),
  ];
  
  // 最多重试 5 次，递增等待 1s, 2s, 3s, 4s, 5s
  for (int attempt = 1; attempt <= 5; attempt++) {
    await Future.delayed(Duration(seconds: attempt));
    
    final cookieMap = <String, String>{};
    for (final url in urls) {
      final cookies = await cookieManager.getCookies(
        url: url,
        webViewController: _controller,
      );
      for (final c in cookies) {
        cookieMap[c.name] = c.value.toString();
      }
    }
    
    // 检查 wr_skey + wr_vid
    if (cookieMap.containsKey('wr_skey') && cookieMap.containsKey('wr_vid')) {
      final cookieStr = cookieMap.entries.map((e) => '${e.key}=${e.value}').join('; ');
      await WereadAuthService.instance.saveCookies(cookieStr);
      
      // WebView 内验证
      final valid = await WereadAuthService.instance.validateCookie(
        webViewController: _controller,
      );
      
      // 启动后台 HeadlessInAppWebView
      unawaited(WereadWebViewService.instance.ensureInitialized());
      
      // 设置结果并返回
      break;
    }
  }
}
```

### 7.3 返回值

- `Navigator.pop(true)`: 登录成功
- `Navigator.pop(false)` / `Navigator.pop(null)`: 用户取消或失败

---

## 8. Settings Page — 微信 Tab 交互

### 8.1 状态变量

| 变量 | 类型 | 说明 |
|------|------|------|
| `_wereadAuthenticated` | bool | Cookie 是否已配置 |
| `_wereadChecking` | bool | 是否正在校验 |
| `_followedMps` | `List<Map<String, String>>` | 已关注公众号列表 |
| `_mpNotificationEnabled` | `Map<String, bool>` | 每个公众号的通知开关 |

### 8.2 UI 结构

```
微信 Tab
├── Cookie 配置卡片
│   ├── 认证状态 (✓ 已配置 / ⚠ 未配置)
│   ├── [扫码登录] [手动配置Cookie]
│   └── (已认证时) [校验有效性] [刷新Cookie] [清除Cookie]
├── 已关注公众号列表
│   └── 每项: 名称 + 简介 + 通知开关
├── 渠道开关 (ChannelListSection)
└── SSPU 推荐公众号
```

### 8.3 操作方法

| 方法 | 说明 |
|------|------|
| `_openWereadLogin(context)` | 打开扫码登录页 |
| `_showCookieInputDialog(context)` | 弹出 Cookie 输入对话框 |
| `_checkWereadAuth()` | 校验 Cookie 有效性 |
| `_refreshWereadCookie()` | 刷新 Cookie |
| `_clearWereadCookie()` | 清除 Cookie |
| `_loadFollowedMps()` | 加载关注列表及通知开关 |
| `_syncMpsFromShelf(context)` | 从书架同步公众号 |

---

## 9. 依赖关系图

```
settings_page.dart
  ├── WereadAuthService (认证状态检查)
  ├── WereadWebViewService (Cookie 变更后重初始化)
  ├── WechatArticleService (关注列表管理)
  └── WereadLoginPage (扫码登录)

WechatArticleService
  ├── WereadApiService (API 调用)
  ├── WereadAuthService (认证检查)
  ├── MessageStateService (通知开关)
  └── StorageService (关注列表存储)

WereadApiService
  ├── WereadAuthService (获取 Cookie)
  └── WereadWebViewService (WebView 控制器)

WereadWebViewService
  └── WereadAuthService (注入 Cookie)

WereadLoginPage
  ├── WereadAuthService (保存 Cookie)
  └── WereadWebViewService (启动后台 session)
```

---

## 10. 数据流

```
扫码登录 → WereadLoginPage → CookieManager → WereadAuthService → StorageService
                                                                      ↓
                                                         WereadWebViewService
                                                         (HeadlessInAppWebView)
                                                                      ↓
定时刷新 → WechatArticleService → WereadApiService → JS fetch via WebView
                ↓                       ↓
        遍历本地关注列表          /web/mp/articles?bookId=xxx
                ↓                       ↓
        检查通知开关             解析 reviews[].subReviews[]
                ↓                       ↓
        _articleToMessageItem    返回 Map<String, dynamic>
                ↓
        List<MessageItem> → UI 展示
```

---

## 11. 关键 API 响应格式参考

### 11.1 书架 /web/shelf/sync

```json
{
  "books": [
    { "bookId": "MP_WXS_123456", "title": "公众号名称", ... },
    { "bookId": "CB_123456", "title": "普通书籍", ... }
  ]
}
```

### 11.2 文章列表 /web/mp/articles

```json
{
  "reviews": [
    {
      "subReviews": [
        {
          "reviewId": "MP_WXS_123456_xxx",
          "review": {
            "reviewId": "...",
            "mpInfo": {
              "title": "文章标题",
              "originalUrl": "https://mp.weixin.qq.com/s?__biz=...",
              "doc_url": "...",
              "time": 1721452800,
              "create_time": 1721452800
            },
            "content": "文章摘要",
            "createTime": 1721452800
          }
        }
      ]
    }
  ]
}
```

### 11.3 搜索 /web/mp/search

```json
{
  "books": [
    {
      "bookInfo": {
        "bookId": "MP_WXS_123456",
        "title": "公众号名称",
        "intro": "公众号简介",
        "cover": "https://..."
      }
    }
  ]
}
```

### 11.4 书籍详情 /web/book/info

```json
{
  "bookId": "MP_WXS_123456",
  "title": "公众号名称",
  "intro": "公众号简介",
  "cover": "https://..."
}
```
