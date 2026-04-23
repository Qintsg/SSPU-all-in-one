/*
 * 微信推文设置指引组件 — 公众号平台注册与接入说明
 * @Project : SSPU-all-in-one
 * @File : settings_wechat_auth_guide.dart
 * @Author : Qintsg
 * @Date : 2026-04-23
 */

import 'package:fluent_ui/fluent_ui.dart';

import '../theme/fluent_tokens.dart';

/// 微信公众号平台接入说明。
class SettingsWechatAuthGuide extends StatelessWidget {
  /// 打开外部注册链接。
  final VoidCallback onOpenOfficialSite;

  const SettingsWechatAuthGuide({super.key, required this.onOpenOfficialSite});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Expander(
      header: const Text('微信公众平台注册方式 >'),
      icon: const Icon(FluentIcons.help, size: 16),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('适用人群', style: theme.typography.bodyStrong),
          const SizedBox(height: FluentSpacing.xs),
          Text('• 想统一使用公众号平台链路获取 SSPU 微信矩阵推文。', style: theme.typography.body),
          Text(
            '• 能接受先注册一个微信公众号账号，再回来用该账号登录公众平台。',
            style: theme.typography.body,
          ),
          const SizedBox(height: FluentSpacing.m),
          Text('前置条件', style: theme.typography.bodyStrong),
          const SizedBox(height: FluentSpacing.xs),
          Text('• 需要一个可以登录微信公众平台的公众号账号。', style: theme.typography.body),
          Text(
            '• 注册时通常需要：一个未用于公众号注册的邮箱、一个实名认证微信作为管理员微信，以及按平台页面要求填写的主体信息。',
            style: theme.typography.body,
          ),
          const SizedBox(height: FluentSpacing.m),
          Text('如何注册微信公众平台账号', style: theme.typography.bodyStrong),
          const SizedBox(height: FluentSpacing.xs),
          Text(
            '根据微信公众平台首页和微信开放社区现有流程说明：先在电脑浏览器打开 mp.weixin.qq.com，点击右上角“立即注册”。',
            style: theme.typography.body,
          ),
          Text(
            '常见顺序为：1）选择账号类型；2）填写并激活邮箱；3）完成信息登记；4）填写公众号名称、简介和运营地区。',
            style: theme.typography.body,
          ),
          Text(
            '个人使用场景通常会先看“公众号 / 订阅号”路线；具体账号能力与限制请以注册页当时显示的官方说明为准。',
            style: theme.typography.body,
          ),
          Text(
            '如果扫码登录时页面提示“该微信还未注册公众平台账号”，说明当前微信下没有可登录的公众号，需要先完成上面的注册流程。',
            style: theme.typography.body,
          ),
          const SizedBox(height: FluentSpacing.s),
          Button(
            onPressed: onOpenOfficialSite,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('打开微信公众平台官网'),
                SizedBox(width: 6),
                Icon(FluentIcons.open_in_new_window, size: 12),
              ],
            ),
          ),
          const SizedBox(height: FluentSpacing.m),
          Text('在本应用中的配置步骤', style: theme.typography.bodyStrong),
          const SizedBox(height: FluentSpacing.xs),
          Text(
            '1. 先确保你已经能在浏览器正常进入 mp.weixin.qq.com 后台。',
            style: theme.typography.body,
          ),
          Text('2. 回到本应用，进入「设置 → 微信」。', style: theme.typography.body),
          Text('3. 点击下方「扫码登录」，使用管理员微信完成登录。', style: theme.typography.body),
          Text(
            '4. 登录成功后，应用会自动提取 Cookie 和 Token，状态显示为「已认证」。',
            style: theme.typography.body,
          ),
          Text(
            '5. 之后可在 SSPU 微信矩阵中关注未关注项，或使用「一键全部关注」。',
            style: theme.typography.body,
          ),
          const SizedBox(height: FluentSpacing.m),
          Text('关注方式', style: theme.typography.bodyStrong),
          const SizedBox(height: FluentSpacing.xs),
          Text(
            '• SSPU 微信矩阵中未关注的公众号会显示「关注」按钮，系统会按推荐名称搜索并保存匹配结果。',
            style: theme.typography.body,
          ),
          Text(
            '• 批量方式：点击「一键全部关注」，系统会逐个搜索并自动跳过已关注项。',
            style: theme.typography.body,
          ),
          Text('• 矩阵中的通知开关只影响本应用是否抓取/提醒。', style: theme.typography.body),
          const SizedBox(height: FluentSpacing.m),
          Text('失败排查', style: theme.typography.bodyStrong),
          const SizedBox(height: FluentSpacing.xs),
          Text('• 扫码页提示没有可登录账号：先去官网完成注册，再回来扫码。', style: theme.typography.body),
          Text(
            '• 注册后仍无法登录：确认账号信息已经填写完成，并且你能在普通浏览器中正常进入后台首页。',
            style: theme.typography.body,
          ),
          Text(
            '• 搜索或批量关注中断：通常是会话过期或接口频率限制，重新扫码后稍等一会儿再试。',
            style: theme.typography.body,
          ),
          Text(
            '• 关注失败：可稍后重试，或确认公众平台搜索结果中能找到该公众号。',
            style: theme.typography.body,
          ),
          const SizedBox(height: FluentSpacing.m),
          Text('是否推荐使用', style: theme.typography.bodyStrong),
          const SizedBox(height: FluentSpacing.xs),
          Text(
            '• 如果你追求稳定的 SSPU 微信矩阵推文聚合，这一方式更直接。',
            style: theme.typography.body,
          ),
          Text('• 当前应用已统一保留这一条链路，完成一次认证后即可持续使用。', style: theme.typography.body),
          const SizedBox(height: FluentSpacing.m),
          Text('FAQ', style: theme.typography.bodyStrong),
          const SizedBox(height: FluentSpacing.xs),
          Text('Q：个人一定要完成额外认证才能用吗？', style: theme.typography.bodyStrong),
          Text(
            'A：本应用需要的是“你能正常登录公众平台后台并拿到登录态”。是否还需要做后续认证，取决于你自己的运营需求和平台当时规则。',
            style: theme.typography.body,
          ),
          const SizedBox(height: FluentSpacing.xs),
          Text('Q：为什么这一方式要先注册公众号？', style: theme.typography.bodyStrong),
          Text(
            'A：因为应用调用的是公众平台后台接口，必须先有一个能登录后台的账号作为入口。',
            style: theme.typography.body,
          ),
          const SizedBox(height: FluentSpacing.xs),
          Text('Q：为什么现在只保留这一种方式？', style: theme.typography.bodyStrong),
          Text(
            'A：为减少配置分叉与维护成本，应用已统一保留公众号平台链路，并围绕该链路提供搜索、关注和刷新能力。',
            style: theme.typography.body,
          ),
        ],
      ),
    );
  }
}
