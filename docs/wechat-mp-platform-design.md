# 微信公众号平台方式 — 技术设计文档

> 本文档为"第二种微信公众号文章获取方式"（公众号平台 API）的完整技术参考。  
> 参照 [WeRSS / we-mp-rss](https://github.com/rachelos/we-mp-rss) 项目分析，在 Flutter/Dart 中实现。

---

## 1. 背景与目标

### 1.1 现有方式（方式一：微信读书）

- 通过 `weread.qq.com` Web API 获取用户已关注的公众号文章
- 认证方式：微信读书 Cookie（`wr_skey` + `wr_vid`）
- 优点：无需公众号身份，普通微信用户即可
- 缺点：依赖微信读书平台，Cookie 容易过期，搜索 API 已下架

### 1.2 新方式（方式二：公众号平台）

- 通过 `mp.weixin.qq.com`（微信公众号管理平台）API 获取任意公众号的文章
- 认证方式：扫码登录公众号平台，获取 Cookie + Token
- 前提：用户需拥有一个微信公众号（个人订阅号即可，免费注册）
- 优点：可搜索任意公众号、API 稳定、文章列表完整
- 缺点：需有公众号身份、Token 有效期有限

### 1.3 两种方式关系

- 二选一，用户在设置页选择使用哪种方式
- 各自独立认证、独立存储 Cookie/Token
- 共享本地关注列表和通知开关
- 输出统一为 `MessageItem` 格式

---

## 2. 公众号平台 API 分析

### 2.1 认证流程

```
用户打开 mp.weixin.qq.com
  → 显示扫码登录页
  → 用户用微信扫码确认
  → 浏览器重定向到管理后台
  → 从 URL 和 Cookie 中提取 token 和 cookie
```

**Token 提取**：登录成功后，页面 URL 中包含 `token` 参数：
```
https://mp.weixin.qq.com/cgi-bin/home?t=home/index&token=123456789&lang=zh_CN
```

**Cookie 提取**：从 WebView 的 Cookie 存储中获取 `mp.weixin.qq.com` 域的所有 Cookie。

### 2.2 搜索公众号 API

**接口**: `GET https://mp.weixin.qq.com/cgi-bin/searchbiz`

**参数**:
| 参数 | 类型 | 说明 |
|------|------|------|
| action | string | 固定 `search_biz` |
| begin | int | 偏移量（分页用） |
| count | int | 每页数量（5-10） |
| query | string | 搜索关键词（公众号名称） |
| token | string | 登录 Token |
| lang | string | 固定 `zh_CN` |
| f | string | 固定 `json` |
| ajax | string | 固定 `1` |

**请求头**:
```
Cookie: <登录获取的 Cookie>
User-Agent: <标准浏览器 UA>
```

**响应示例**:
```json
{
  "base_resp": {
    "ret": 0,
    "err_msg": "ok"
  },
  "list": [
    {
      "fakeid": "MzI1NTQxNjY0MQ==",
      "nickname": "上海第二工业大学",
      "alias": "sspu1960",
      "round_head_img": "https://wx.qlogo.cn/...",
      "service_type": 0
    }
  ],
  "total": 1
}
```

**关键字段**:
- `fakeid`：公众号唯一标识，后续获取文章时使用
- `nickname`：公众号名称
- `alias`：公众号微信号
- `round_head_img`：头像 URL

### 2.3 获取文章列表 API

**接口**: `GET https://mp.weixin.qq.com/cgi-bin/appmsgpublish`

**参数**:
| 参数 | 类型 | 说明 |
|------|------|------|
| sub | string | 固定 `list` |
| sub_action | string | 固定 `list_ex` |
| begin | int | 偏移量 = 页码 × count |
| count | int | 每页数量（通常 5） |
| fakeid | string | 公众号的 fakeid |
| token | string | 登录 Token |
| lang | string | 固定 `zh_CN` |
| f | string | 固定 `json` |
| ajax | int | 固定 `1` |

**请求头**: 同上（Cookie + User-Agent）

**响应结构**:
```json
{
  "base_resp": {
    "ret": 0,
    "err_msg": "ok"
  },
  "publish_page": "{\"publish_list\": [...]}"  // JSON 字符串，需二次解析
}
```

`publish_page` 是 JSON 字符串，解析后结构：
```json
{
  "publish_list": [
    {
      "publish_info": "{\"appmsgex\": [...]}"  // 再次 JSON 字符串
    }
  ]
}
```

`publish_info` 也是 JSON 字符串，解析后：
```json
{
  "appmsgex": [
    {
      "aid": "2651234567_1",
      "title": "文章标题",
      "link": "https://mp.weixin.qq.com/s?__biz=...",
      "cover": "https://mmbiz.qpic.cn/...",
      "digest": "文章摘要...",
      "update_time": 1721452800,
      "create_time": 1721452800,
      "is_deleted": false,
      "copyright_stat": 0,
      "item_show_type": 0
    }
  ]
}
```

**关键字段**:
- `aid`：文章唯一 ID
- `title`：文章标题
- `link`：文章永久链接（mp.weixin.qq.com/s?__biz=... 格式）
- `cover`：封面图 URL
- `digest`：摘要
- `update_time`：更新时间（Unix 秒级时间戳）
- `create_time`：创建时间（Unix 秒级时间戳）
- `is_deleted`：是否已删除

### 2.4 错误码

| ret 值 | 含义 |
|--------|------|
| 0 | 成功 |
| 200003 | Session 失效（Token/Cookie 过期） |
| 200013 | 频率控制（请求过快） |
| 其他非0 | 其他错误 |

### 2.5 重要限制

- **Token 有效期**：登录后 Token 约有 2-4 小时有效期
- **频率限制**：请求不宜过快，建议每次请求间隔 3-10 秒
- **二次解析**：`publish_page` 和 `publish_info` 都是 JSON 字符串嵌套在 JSON 中，需要两次 `jsonDecode`
- **Cookie 绑定**：Cookie 与登录设备/浏览器绑定

---

## 3. 实现方案

### 3.1 新建文件

| 文件 | 用途 |
|------|------|
| `lib/services/wxmp_auth_service.dart` | 公众号平台认证服务（Cookie/Token 存取） |
| `lib/services/wxmp_article_service.dart` | 公众号平台文章获取服务（搜索、拉取文章） |
| `lib/pages/wxmp_login_page.dart` | 公众号平台扫码登录页 |
| `docs/wechat-mp-guide.md` | 用户使用指南 |

### 3.2 修改文件

| 文件 | 修改内容 |
|------|----------|
| `lib/services/storage_service.dart` | 添加存储键名（方式选择、公众号平台 Cookie/Token） |
| `lib/services/wechat_article_service.dart` | 添加方式切换逻辑，方式二时委托给 `WxmpArticleService` |
| `lib/pages/settings_page.dart` | 微信 Tab 添加方式选择 UI，方式二的认证和管理 UI |

### 3.3 核心类设计

#### 3.3.1 WxmpAuthService（公众号平台认证服务）

```dart
class WxmpAuthService {
  // 单例
  static final instance = WxmpAuthService._();
  
  // 存储键名
  static const _keyCookie = 'wxmp_cookie';
  static const _keyToken = 'wxmp_token';
  static const _keyLastUpdate = 'wxmp_last_update';
  
  // Cookie/Token 读写
  Future<void> saveAuth(String cookie, String token);
  Future<String?> getCookie();
  Future<String?> getToken();
  Future<bool> hasAuth();
  Future<void> clearAuth();
  
  // 有效性检查（用 token 请求一个轻量 API 看返回码）
  Future<bool> validateAuth();
}
```

#### 3.3.2 WxmpArticleService（公众号平台文章服务）

```dart
class WxmpArticleService {
  // 单例
  static final instance = WxmpArticleService._();
  
  final WxmpAuthService _auth = WxmpAuthService.instance;
  final Dio _dio = Dio();
  
  // 搜索公众号
  // 返回: [{fakeid, nickname, alias, round_head_img}]
  Future<List<Map<String, String>>> searchMp(String keyword);
  
  // 获取文章列表
  // fakeid: 公众号 fakeid
  // page: 页码（从0开始）
  // count: 每页数量
  // 返回: [{aid, title, link, cover, digest, update_time, create_time}]
  Future<List<Map<String, dynamic>>> getArticles(String fakeid, {int page = 0, int count = 5});
  
  // 获取所有已关注公众号的文章并转为 MessageItem
  Future<List<MessageItem>> fetchArticles({int maxCount = 50});
  
  // 本地关注列表管理（复用 WechatArticleService 的格式）
  // 存储格式: {fakeid: {name, alias, avatar}}
  Future<Map<String, Map<String, String>>> getLocalFollowedMps();
  Future<void> followMp(String fakeid, String name, {String? alias, String? avatar});
  Future<void> unfollowMp(String fakeid);
}
```

#### 3.3.3 WxmpLoginPage（扫码登录页）

```dart
class WxmpLoginPage extends StatefulWidget {
  // 使用 InAppWebView 加载 mp.weixin.qq.com
  // 检测登录成功：
  //   1. 监听 URL 变化，当 URL 包含 /cgi-bin/home?...&token= 时
  //   2. 从 URL 中正则提取 token
  //   3. 从 WebView CookieManager 获取 mp.weixin.qq.com 的所有 Cookie
  //   4. 保存 cookie + token 到 WxmpAuthService
  //   5. Navigator.pop(true) 返回成功
}
```

### 3.4 方式选择机制

在 `StorageService` 中添加存储键：
```dart
static const String wechatMethod = 'wechat_fetch_method';
// 值: 'weread'（默认） 或 'wxmp'
```

在 `WechatArticleService.fetchArticles()` 中：
```dart
Future<List<MessageItem>> fetchArticles({int maxCount = 50}) async {
  final method = await StorageService.getString('wechat_fetch_method') ?? 'weread';
  
  if (method == 'wxmp') {
    return WxmpArticleService.instance.fetchArticles(maxCount: maxCount);
  }
  
  // 原有微信读书逻辑...
}
```

### 3.5 本地关注列表

公众号平台方式的关注列表使用独立存储键 `wxmp_followed_mps`，格式：
```json
{
  "MzI1NTQxNjY0MQ==": {
    "name": "上海第二工业大学",
    "alias": "sspu1960",
    "avatar": "https://wx.qlogo.cn/..."
  }
}
```

与方式一（微信读书）的关注列表（`wechat_followed_mps`）相互独立。

### 3.6 Settings UI 变更

在微信 Tab 顶部添加方式选择器（ComboBox 或 RadioButton）：
```
获取方式：
  ○ 方式一：微信读书（通过微信读书 Web API）
  ● 方式二：公众号平台（通过 mp.weixin.qq.com API）
```

选择方式二后显示：
- 公众号平台认证卡片（扫码登录 / 认证状态 / 清除认证）
- 已关注公众号列表（从公众号平台方式的存储）
- 添加公众号（搜索框 → 调用 searchMp → 选择关注）

选择方式一时显示原有 UI（微信读书 Cookie 配置）。

两种方式共享：
- 渠道开关（ChannelListSection）
- SSPU 推荐公众号列表

---

## 4. 请求构造参考

### 4.1 标准请求头

```dart
final headers = {
  'Cookie': cookie,
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36',
  'Accept': 'application/json, text/javascript, */*; q=0.01',
  'Accept-Language': 'zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7',
  'X-Requested-With': 'XMLHttpRequest',
  'Referer': 'https://mp.weixin.qq.com/',
};
```

### 4.2 搜索公众号请求

```dart
final response = await dio.get(
  'https://mp.weixin.qq.com/cgi-bin/searchbiz',
  queryParameters: {
    'action': 'search_biz',
    'begin': 0,
    'count': 5,
    'query': keyword,
    'token': token,
    'lang': 'zh_CN',
    'f': 'json',
    'ajax': '1',
  },
  options: Options(headers: headers),
);
```

### 4.3 获取文章列表请求

```dart
final response = await dio.get(
  'https://mp.weixin.qq.com/cgi-bin/appmsgpublish',
  queryParameters: {
    'sub': 'list',
    'sub_action': 'list_ex',
    'begin': page * count,
    'count': count,
    'fakeid': fakeid,
    'token': token,
    'lang': 'zh_CN',
    'f': 'json',
    'ajax': 1,
  },
  options: Options(headers: headers),
);
```

### 4.4 响应解析

```dart
// 解析文章列表响应
final data = response.data as Map<String, dynamic>;
final baseResp = data['base_resp'] as Map<String, dynamic>;
final ret = baseResp['ret'] as int;

if (ret == 200003) throw Exception('Session 失效，请重新登录');
if (ret == 200013) throw Exception('请求频率过快，请稍后再试');
if (ret != 0) throw Exception('API 错误: ${baseResp['err_msg']}');

// publish_page 是 JSON 字符串
final publishPageStr = data['publish_page'] as String;
final publishPage = jsonDecode(publishPageStr) as Map<String, dynamic>;
final publishList = publishPage['publish_list'] as List<dynamic>;

final articles = <Map<String, dynamic>>[];
for (final item in publishList) {
  // publish_info 也是 JSON 字符串
  final publishInfoStr = item['publish_info'] as String;
  final publishInfo = jsonDecode(publishInfoStr) as Map<String, dynamic>;
  final appmsgex = publishInfo['appmsgex'] as List<dynamic>;
  
  for (final article in appmsgex) {
    articles.add(article as Map<String, dynamic>);
  }
}
```

---

## 5. WebView 登录流程

### 5.1 页面加载

```dart
InAppWebView(
  initialUrlRequest: URLRequest(
    url: WebUri('https://mp.weixin.qq.com/'),
  ),
)
```

### 5.2 登录成功检测

监听 `onLoadStop` 或 `onUpdateVisitedHistory`：

```dart
void onUrlChanged(Uri? url) {
  if (url == null) return;
  final urlStr = url.toString();
  
  // 登录成功后 URL 包含 token 参数
  // 形如: https://mp.weixin.qq.com/cgi-bin/home?t=home/index&token=123456789&lang=zh_CN
  if (urlStr.contains('mp.weixin.qq.com') && urlStr.contains('token=')) {
    final tokenMatch = RegExp(r'token=(\d+)').firstMatch(urlStr);
    if (tokenMatch != null) {
      final token = tokenMatch.group(1)!;
      _extractCookieAndSave(token);
    }
  }
}
```

### 5.3 Cookie 提取

```dart
Future<void> _extractCookieAndSave(String token) async {
  final cookieManager = CookieManager.instance();
  final cookies = await cookieManager.getCookies(
    url: WebUri('https://mp.weixin.qq.com'),
  );
  
  // 拼接为标准 Cookie 字符串
  final cookieStr = cookies.map((c) => '${c.name}=${c.value}').join('; ');
  
  // 保存
  await WxmpAuthService.instance.saveAuth(cookieStr, token);
}
```

---

## 6. 数据流转

```
方式二选中
  → 用户扫码登录 mp.weixin.qq.com
  → 提取 cookie + token → WxmpAuthService 存储
  → 用户搜索公众号 → searchMp(keyword)
  → 选择关注 → followMp(fakeid, name)
  → 定时/手动刷新 → fetchArticles()
    → 遍历已关注公众号
    → 对每个 fakeid 调用 getArticles()
    → 转换为 MessageItem
    → 返回统一格式
```

---

## 7. 与 SSPU 推荐公众号的兼容

现有 `sspu_wechat_accounts.dart` 中的推荐公众号列表存储的是微信读书的 `bookId`（如 `MP_WXS_xxx`）。

公众号平台方式使用 `fakeid`（如 `MzI1NTQxNjY0MQ==`）。

兼容方案：
- SSPU 推荐列表中额外添加公众号名称
- 方式二关注推荐公众号时，先通过 `searchMp(公众号名称)` 搜索得到 `fakeid`，再关注
- 推荐列表数据结构扩展：`{bookId, name, fakeid?}`

---

## 8. 存储键名汇总

| 键名 | 用途 | 格式 |
|------|------|------|
| `wechat_fetch_method` | 当前使用的获取方式 | `'weread'` 或 `'wxmp'` |
| `wxmp_cookie` | 公众号平台 Cookie | String |
| `wxmp_token` | 公众号平台 Token | String |
| `wxmp_last_update` | 认证最后更新时间戳 | int (毫秒) |
| `wxmp_followed_mps` | 公众号平台方式的关注列表 | JSON String |

---

## 9. 风险与注意事项

1. **Token 过期**：公众号平台 Token 有效期有限（约 2-4 小时），需提示用户重新登录
2. **频率限制**：请求间需适当延迟（3-10 秒），避免触发频率控制（ret=200013）
3. **Cookie 变化**：每次登录的 Cookie 可能不同，需完整替换
4. **WebView 兼容性**：InAppWebView 在 Windows 上依赖 Edge WebView2 Runtime
5. **公众号个人号注册**：用户需自行在 mp.weixin.qq.com 注册个人订阅号
6. **文章链接格式**：公众号平台返回的 `link` 是 `mp.weixin.qq.com/s?__biz=` 格式，可直接用 `url_launcher` 打开
