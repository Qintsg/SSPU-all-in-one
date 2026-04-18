/*
 * 使用协议页面 — 展示完整的使用协议条款
 * @Project : SSPU-all-in-one
 * @File : agreement_page.dart
 * @Author : Qintsg
 * @Date : 2026-04-18
 */

import 'package:fluent_ui/fluent_ui.dart';

/// 使用协议全文
/// 若后续用户没有明确说明，不得修改此内容
const String kAgreementText = '''
SSPU All-in-One 使用协议

开发者：Qintsg
最后更新日期：2026年4月18日

请在使用本软件前仔细阅读以下条款。使用本软件即表示您已阅读并同意以下全部内容。

一、免责声明

1. 本软件（SSPU All-in-One）未获得上海第二工业大学（SSPU）、微信、微信读书及其关联方的任何官方授权、认可或背书。

2. 本软件与上海第二工业大学、腾讯公司及其旗下产品（包括但不限于微信、微信读书）不存在任何合作、代理或隶属关系。

3. 使用本软件所产生的一切后果（包括但不限于账号风险、数据丢失、隐私泄露、学业影响等）由用户自行承担，本软件的开发者不承担任何直接或间接责任。

4. 本软件不保证所提供信息的准确性、完整性和时效性。用户应自行核实相关信息的正确性。

二、知识产权

1. 本软件采用 MIT 许可证开源。

2. 本软件中涉及的第三方商标、名称、标识（包括但不限于"上海第二工业大学"、"微信"、"微信读书"等）均为其各自所有者的财产，本软件对其不主张任何权利。

三、使用限制

1. 用户不得利用本软件从事任何违反法律法规的活动。

2. 用户不得利用本软件对任何第三方服务进行恶意攻击、干扰或破坏。

四、协议变更

开发者保留随时修改本协议的权利。修改后的协议将在软件更新时生效。继续使用本软件即表示您接受修改后的协议。

五、其他

1. 本协议受中华人民共和国法律管辖。

2. 如本协议的任何条款被认定为无效或不可执行，其余条款仍然有效。
''';

/// 使用协议页面
class AgreementPage extends StatelessWidget {
  const AgreementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage.scrollable(
      header: const PageHeader(title: Text('使用协议')),
      children: [
        Card(
          child: SelectableText(
            kAgreementText.trim(),
            style: FluentTheme.of(context).typography.body,
          ),
        ),
      ],
    );
  }
}
