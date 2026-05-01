# 校园卡查询规则探索

本文记录 issue #114 实现前对校园卡查询系统的只读探索结果，后续维护校园卡余额、状态和交易记录查询时以本文为约束。

## 入口与认证

- OA 校园卡入口为 `https://oa.sspu.edu.cn//interface/Entrance.jsp?id=xykxt`。
- 未认证访问 OA 入口时，会先跳转到 `https://oa.sspu.edu.cn/sso/login.jsp`，再跳转到 `https://id.sspu.edu.cn/cas/login`。
- 校园卡业务入口为 `https://card.sspu.edu.cn/epay/`。
- 未认证访问校园卡业务入口时，会跳转到 CAS，`service` 为 `https://card.sspu.edu.cn/epay/j_spring_cas_security_check`。
- OA 入口中的 `{base64}Ly9pbnRlcmZhY2UvRW50cmFuY2UuanNwP2lkPXh5a3h0` 解码后为 `//interface/Entrance.jsp?id=xykxt`。
- 实现中复用已保存的 OA/CAS Cookie 会话；若会话失效，则调用现有 OA 登录校验刷新会话后重试校园卡入口。

## 页面与接口线索

- 已确认 `card.sspu.edu.cn/epay/` 和 `/epay/j_spring_cas_security_check` 属于校园卡 CAS 业务链路。
- 未认证请求无法确认业务页 DOM 结构；未认证访问任意候选业务路径都会先进入 CAS，因此不能仅凭跳转判断路径真实存在。
- 同类 `epay` 系统常见只读候选路径包括：
  - 余额 / 个人页：`/epay/myepay/index`
  - 交易记录页：`/epay/consume/index`
  - 交易查询接口：`/epay/consume/query`
- 交易查询接口在同类系统中可能返回 XML / CDATA 包裹的 HTML 表格，应用同时支持普通 HTML 和 XML / CDATA 表格解析。

## 刷新与展示策略

- 首页“校园卡余额”卡片默认不自动读取，避免进入主页即访问需要 OA 登录与校园网 / VPN 的受限服务。
- 可点击卡片右下角刷新图标手动读取，卡片右下角显示上次刷新时间。
- 设置页“自动刷新设置”可开启校园卡余额自动刷新并选择刷新间隔；开启后进入主页会主动读取一次。
- 每次读取前必须先执行校园网 / VPN 前置检测，检测不可达时不打开校园卡入口、不刷新 OA 会话。
- 首页展示账户余额；当页面明确返回的卡状态不是“正常 / 有效 / 可用”时，首页同步展示状态警告。
- 详情页展示余额、状态和交易记录，并允许按日期范围执行交易记录查询。

## 只读边界

- 当前能力只允许访问 OA/CAS 登录链路、校园卡余额页、交易记录页和交易记录查询接口。
- 不执行充值、支付、二维码付款、挂失、解挂、修改限额、提交订单、确认交易等任何写入或状态变更操作。
- 实现中将交易查询限制在明确的 `/epay/consume/query` 候选路径，禁止主动探测支付、充值或订单接口。
- UI、日志和文档不得展示 OA 密码、Cookie、CAS Ticket 或其它可直接复用的身份值。

## 未确认风险

- 登录后的实际业务页 DOM 结构、余额字段文案、卡状态字段和交易记录列顺序仍需在真实登录态下持续验证。
- `/epay/myepay/index`、`/epay/consume/index`、`/epay/consume/query` 是同类系统候选路径，SSPU 是否长期稳定支持需要后续真实环境确认。
- 若页面结构变化导致无法解析，应用应返回“页面结构异常”，不得伪造余额、状态或空成功结果。
