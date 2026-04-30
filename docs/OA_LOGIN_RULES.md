# OA 登录规则探索

本文记录 issue #110 实现前对学校 OA / CAS 登录链路的只读探索结果，后续维护登录校验和会话复用时以本文为约束。

## 入口与跳转

- 本专科教务入口为 `https://oa.sspu.edu.cn/interface/Entrance.jsp?id=bzkjw`。
- 首次访问入口会返回 `302` 到 `https://oa.sspu.edu.cn/sso/login.jsp?targetUrl=/interface/Entrance.jsp?id=bzkjw`，OA 侧可能设置 `route`、`__clusterSessionIDCookieName`、`__clusterSessionCookieName`、`ecology_JSessionid` 等 Cookie。
- OA SSO 页面会继续返回 `302` 到 `https://id.sspu.edu.cn/cas/login?service=...`。
- CAS 登录页返回 `200`，账号密码登录表单的 `action` 当前为相对路径 `login`。

## 表单字段

- 可识别的账号密码登录表单满足 `currentMenu=1` 且 `_eventId=submit`。
- 必填登录字段包括 `username`、`password`、`currentMenu`、`failN`、`mfaState`、`execution`、`_eventId`。
- `captcha`、`geolocation`、`fpVisitorId` 在无交互校验中保持空值；一旦 CAS 要求验证码或额外安全验证，应用只提示状态，不尝试绕过。
- `execution` 每次登录页生成，必须从当前登录页读取，不可复用旧值。

## 密码加密

- CAS 页面加载 `/cas/deps/js/jsencrypt/3.0.0-rc.1/jsencrypt.min.js`，并从 `/cas/jwt/publicKey` 读取 RSA 公钥。
- 页面脚本会将密码转为 `__RSA__` + `JSEncrypt.encrypt(password)`，其中加密结果是 RSA PKCS#1 v1.5 密文的 Base64 字符串。
- 应用提交登录时必须使用同样的 `__RSA__` 前缀，不保存或记录明文密码。

## 成功与会话

- 登录成功以跳转到 `oa.sspu.edu.cn` 且不再停留在 `id.sspu.edu.cn/cas/login` 为准。
- CAS 服务票据只存在于跳转 URL 中，属于一次性登录交换参数，不作为持久身份信息保存。
- 应用只保存响应链路中获得的 Cookie 请求头，并按 Cookie 作用域写入系统安全存储，供后续只读网页请求复用。
- OA 登录持久性较低，关闭浏览器、异地登录、超时或访问会主动退出登录的页面后都可能失效；后续请求发现跳回 CAS 或返回未登录状态时，应直接重新执行登录校验刷新会话。

## 只读边界

- 当前能力只允许打开登录页、读取公钥、提交登录表单并跟随跳转验证身份。
- 不执行新增、修改、删除、提交、发送邮件、标记已读、删除邮件等任何写入或状态变更操作。
- 日志、UI 和文档不得展示密码、Cookie、CAS Ticket 或其它可直接复用的身份值。
