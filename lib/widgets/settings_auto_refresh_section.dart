/*
 * 设置页自动刷新分区组件 — 校园网检测频率与刷新设置快捷入口
 * @Project : SSPU-all-in-one
 * @File : settings_auto_refresh_section.dart
 * @Author : Qintsg
 * @Date : 2026-04-27
 */

import 'package:fluent_ui/fluent_ui.dart';

import '../theme/fluent_tokens.dart';
import 'settings_widgets.dart';

/// 设置页自动刷新设置分区。
class SettingsAutoRefreshSection extends StatelessWidget {
  /// 校园网 / VPN 状态检测间隔，单位分钟。
  final int campusNetworkDetectionIntervalMinutes;

  /// 体育部课外活动考勤自动刷新开关。
  final bool sportsAttendanceAutoRefreshEnabled;

  /// 体育部课外活动考勤自动刷新间隔，单位分钟。
  final int sportsAttendanceAutoRefreshIntervalMinutes;

  /// 校园卡余额自动刷新开关。
  final bool campusCardAutoRefreshEnabled;

  /// 校园卡余额自动刷新间隔，单位分钟。
  final int campusCardAutoRefreshIntervalMinutes;

  /// 学校邮箱自动刷新开关。
  final bool emailAutoRefreshEnabled;

  /// 学校邮箱自动刷新间隔，单位分钟。
  final int emailAutoRefreshIntervalMinutes;

  /// 第二课堂学分自动刷新开关。
  final bool studentReportAutoRefreshEnabled;

  /// 第二课堂学分自动刷新间隔，单位分钟。
  final int studentReportAutoRefreshIntervalMinutes;

  /// 本专科教务自动刷新开关。
  final bool academicEamsAutoRefreshEnabled;

  /// 本专科教务自动刷新间隔，单位分钟。
  final int academicEamsAutoRefreshIntervalMinutes;

  /// 校园网 / VPN 状态检测间隔修改回调。
  final Future<void> Function(int minutes)
  onCampusNetworkDetectionIntervalChanged;

  /// 体育部课外活动考勤自动刷新开关修改回调。
  final Future<void> Function(bool enabled)
  onSportsAttendanceAutoRefreshChanged;

  /// 体育部课外活动考勤自动刷新间隔修改回调。
  final Future<void> Function(int minutes)
  onSportsAttendanceAutoRefreshIntervalChanged;

  /// 校园卡余额自动刷新开关修改回调。
  final Future<void> Function(bool enabled) onCampusCardAutoRefreshChanged;

  /// 校园卡余额自动刷新间隔修改回调。
  final Future<void> Function(int minutes)
  onCampusCardAutoRefreshIntervalChanged;

  /// 学校邮箱自动刷新开关修改回调。
  final Future<void> Function(bool enabled) onEmailAutoRefreshChanged;

  /// 学校邮箱自动刷新间隔修改回调。
  final Future<void> Function(int minutes) onEmailAutoRefreshIntervalChanged;

  /// 第二课堂学分自动刷新开关修改回调。
  final Future<void> Function(bool enabled) onStudentReportAutoRefreshChanged;

  /// 第二课堂学分自动刷新间隔修改回调。
  final Future<void> Function(int minutes)
  onStudentReportAutoRefreshIntervalChanged;

  /// 本专科教务自动刷新开关修改回调。
  final Future<void> Function(bool enabled) onAcademicEamsAutoRefreshChanged;

  /// 本专科教务自动刷新间隔修改回调。
  final Future<void> Function(int minutes)
  onAcademicEamsAutoRefreshIntervalChanged;

  /// 跳转职能部门自动刷新设置。
  final VoidCallback onOpenDepartmentRefreshSettings;

  /// 跳转教学单位自动刷新设置。
  final VoidCallback onOpenTeachingRefreshSettings;

  /// 跳转微信推文自动刷新设置。
  final VoidCallback onOpenWechatRefreshSettings;

  const SettingsAutoRefreshSection({
    super.key,
    required this.campusNetworkDetectionIntervalMinutes,
    required this.sportsAttendanceAutoRefreshEnabled,
    required this.sportsAttendanceAutoRefreshIntervalMinutes,
    required this.campusCardAutoRefreshEnabled,
    required this.campusCardAutoRefreshIntervalMinutes,
    required this.emailAutoRefreshEnabled,
    required this.emailAutoRefreshIntervalMinutes,
    required this.studentReportAutoRefreshEnabled,
    required this.studentReportAutoRefreshIntervalMinutes,
    required this.academicEamsAutoRefreshEnabled,
    required this.academicEamsAutoRefreshIntervalMinutes,
    required this.onCampusNetworkDetectionIntervalChanged,
    required this.onSportsAttendanceAutoRefreshChanged,
    required this.onSportsAttendanceAutoRefreshIntervalChanged,
    required this.onCampusCardAutoRefreshChanged,
    required this.onCampusCardAutoRefreshIntervalChanged,
    required this.onEmailAutoRefreshChanged,
    required this.onEmailAutoRefreshIntervalChanged,
    required this.onStudentReportAutoRefreshChanged,
    required this.onStudentReportAutoRefreshIntervalChanged,
    required this.onAcademicEamsAutoRefreshChanged,
    required this.onAcademicEamsAutoRefreshIntervalChanged,
    required this.onOpenDepartmentRefreshSettings,
    required this.onOpenTeachingRefreshSettings,
    required this.onOpenWechatRefreshSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCampusNetworkIntervalCard(context),
        const SizedBox(height: FluentSpacing.l),
        _buildRefreshShortcutCard(context),
      ],
    );
  }

  Widget _buildCampusNetworkIntervalCard(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FluentSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('自动刷新设置', style: theme.typography.subtitle),
            const SizedBox(height: FluentSpacing.l),
            buildResponsiveSettingsRow(
              context: context,
              icon: FluentIcons.plug_connected,
              title: Text('校园网 / VPN 状态检测', style: theme.typography.bodyStrong),
              subtitle: Text(
                '控制导航栏状态徽标的自动检测频率；关闭后仍可点击徽标手动检测',
                style: theme.typography.caption,
              ),
              trailing: _buildIntervalComboBox(),
            ),
            const SizedBox(height: FluentSpacing.m),
            _buildSportsAttendanceAutoRefreshRow(context),
            const SizedBox(height: FluentSpacing.m),
            _buildCampusCardAutoRefreshRow(context),
            const SizedBox(height: FluentSpacing.m),
            _buildEmailAutoRefreshRow(context),
            const SizedBox(height: FluentSpacing.m),
            _buildStudentReportAutoRefreshRow(context),
            const SizedBox(height: FluentSpacing.m),
            _buildAcademicEamsAutoRefreshRow(context),
          ],
        ),
      ),
    );
  }

  Widget _buildRefreshShortcutCard(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FluentSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('消息自动刷新快捷入口', style: theme.typography.subtitle),
            const SizedBox(height: FluentSpacing.s),
            Text(
              '以下入口会跳转到对应分区顶部的自动刷新设置面板。',
              style: theme.typography.caption?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
            ),
            const SizedBox(height: FluentSpacing.l),
            _buildShortcutRow(
              context: context,
              icon: FluentIcons.education,
              title: '职能部门',
              description: '配置职能部门官网消息的自动刷新频率和抓取条数',
              onPressed: onOpenDepartmentRefreshSettings,
            ),
            const SizedBox(height: FluentSpacing.m),
            _buildShortcutRow(
              context: context,
              icon: FluentIcons.library,
              title: '教学单位',
              description: '配置学院、中心等教学单位消息的自动刷新频率和抓取条数',
              onPressed: onOpenTeachingRefreshSettings,
            ),
            const SizedBox(height: FluentSpacing.m),
            _buildShortcutRow(
              context: context,
              icon: FluentIcons.chat,
              title: '微信推文',
              description: '配置公众号平台推文的自动刷新频率和抓取条数',
              onPressed: onOpenWechatRefreshSettings,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntervalComboBox() {
    final selectedValue =
        kIntervalOptions.containsKey(campusNetworkDetectionIntervalMinutes)
        ? campusNetworkDetectionIntervalMinutes
        : 15;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: ComboBox<int>(
        isExpanded: true,
        value: selectedValue,
        items: kIntervalOptions.entries
            .map(
              (entry) =>
                  ComboBoxItem<int>(value: entry.key, child: Text(entry.value)),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) {
            onCampusNetworkDetectionIntervalChanged(value);
          }
        },
      ),
    );
  }

  Widget _buildSportsAttendanceAutoRefreshRow(BuildContext context) {
    final theme = FluentTheme.of(context);
    return buildResponsiveSettingsRow(
      context: context,
      icon: FluentIcons.running,
      title: Text('体育查询自动刷新', style: theme.typography.bodyStrong),
      subtitle: Text(
        '控制教务中心课外活动考勤卡片的自动读取；体育查询需要校园网或学校 VPN，关闭后仍可在卡片右上角手动刷新',
        style: theme.typography.caption,
      ),
      trailing: Wrap(
        spacing: FluentSpacing.s,
        runSpacing: FluentSpacing.s,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ToggleSwitch(
            checked: sportsAttendanceAutoRefreshEnabled,
            onChanged: (value) => onSportsAttendanceAutoRefreshChanged(value),
          ),
          _buildSportsAttendanceIntervalComboBox(),
        ],
      ),
    );
  }

  Widget _buildSportsAttendanceIntervalComboBox() {
    final enabledIntervalOptions = Map<int, String>.fromEntries(
      kIntervalOptions.entries.where((entry) => entry.key > 0),
    );
    final selectedValue =
        enabledIntervalOptions.containsKey(
          sportsAttendanceAutoRefreshIntervalMinutes,
        )
        ? sportsAttendanceAutoRefreshIntervalMinutes
        : 30;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: ComboBox<int>(
        isExpanded: true,
        value: selectedValue,
        items: enabledIntervalOptions.entries
            .map(
              (entry) =>
                  ComboBoxItem<int>(value: entry.key, child: Text(entry.value)),
            )
            .toList(),
        onChanged: sportsAttendanceAutoRefreshEnabled
            ? (value) {
                if (value != null) {
                  onSportsAttendanceAutoRefreshIntervalChanged(value);
                }
              }
            : null,
      ),
    );
  }

  Widget _buildCampusCardAutoRefreshRow(BuildContext context) {
    final theme = FluentTheme.of(context);
    return buildResponsiveSettingsRow(
      context: context,
      icon: FluentIcons.payment_card,
      title: Text('校园卡余额自动刷新', style: theme.typography.bodyStrong),
      subtitle: Text(
        '控制主页校园卡余额卡片的自动读取；需要校园网或学校 VPN 与 OA 登录，关闭后仍可在卡片右下角手动刷新',
        style: theme.typography.caption,
      ),
      trailing: Wrap(
        spacing: FluentSpacing.s,
        runSpacing: FluentSpacing.s,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ToggleSwitch(
            checked: campusCardAutoRefreshEnabled,
            onChanged: (value) => onCampusCardAutoRefreshChanged(value),
          ),
          _buildCampusCardIntervalComboBox(),
        ],
      ),
    );
  }

  Widget _buildCampusCardIntervalComboBox() {
    final enabledIntervalOptions = Map<int, String>.fromEntries(
      kIntervalOptions.entries.where((entry) => entry.key > 0),
    );
    final selectedValue =
        enabledIntervalOptions.containsKey(campusCardAutoRefreshIntervalMinutes)
        ? campusCardAutoRefreshIntervalMinutes
        : 30;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: ComboBox<int>(
        isExpanded: true,
        value: selectedValue,
        items: enabledIntervalOptions.entries
            .map(
              (entry) =>
                  ComboBoxItem<int>(value: entry.key, child: Text(entry.value)),
            )
            .toList(),
        onChanged: campusCardAutoRefreshEnabled
            ? (value) {
                if (value != null) {
                  onCampusCardAutoRefreshIntervalChanged(value);
                }
              }
            : null,
      ),
    );
  }

  Widget _buildEmailAutoRefreshRow(BuildContext context) {
    final theme = FluentTheme.of(context);
    return buildResponsiveSettingsRow(
      context: context,
      icon: FluentIcons.mail,
      title: Text('学校邮箱自动刷新', style: theme.typography.bodyStrong),
      subtitle: Text(
        '控制学校邮箱页面的自动收信；邮箱系统不要求校园网或 VPN，关闭后仍可在邮箱页手动读取',
        style: theme.typography.caption,
      ),
      trailing: Wrap(
        spacing: FluentSpacing.s,
        runSpacing: FluentSpacing.s,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ToggleSwitch(
            checked: emailAutoRefreshEnabled,
            onChanged: (value) => onEmailAutoRefreshChanged(value),
          ),
          _buildEmailIntervalComboBox(),
        ],
      ),
    );
  }

  Widget _buildEmailIntervalComboBox() {
    final enabledIntervalOptions = Map<int, String>.fromEntries(
      kIntervalOptions.entries.where((entry) => entry.key > 0),
    );
    final selectedValue =
        enabledIntervalOptions.containsKey(emailAutoRefreshIntervalMinutes)
        ? emailAutoRefreshIntervalMinutes
        : 30;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: ComboBox<int>(
        isExpanded: true,
        value: selectedValue,
        items: enabledIntervalOptions.entries
            .map(
              (entry) =>
                  ComboBoxItem<int>(value: entry.key, child: Text(entry.value)),
            )
            .toList(),
        onChanged: emailAutoRefreshEnabled
            ? (value) {
                if (value != null) {
                  onEmailAutoRefreshIntervalChanged(value);
                }
              }
            : null,
      ),
    );
  }

  Widget _buildStudentReportAutoRefreshRow(BuildContext context) {
    final theme = FluentTheme.of(context);
    return buildResponsiveSettingsRow(
      context: context,
      icon: FluentIcons.education,
      title: Text('第二课堂学分自动刷新', style: theme.typography.bodyStrong),
      subtitle: Text(
        '控制教务中心第二课堂学分卡片的自动读取；需要校园网或学校 VPN 与 OA 登录，关闭后仍可在卡片右上角手动刷新',
        style: theme.typography.caption,
      ),
      trailing: Wrap(
        spacing: FluentSpacing.s,
        runSpacing: FluentSpacing.s,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ToggleSwitch(
            checked: studentReportAutoRefreshEnabled,
            onChanged: (value) => onStudentReportAutoRefreshChanged(value),
          ),
          _buildStudentReportIntervalComboBox(),
        ],
      ),
    );
  }

  Widget _buildStudentReportIntervalComboBox() {
    final enabledIntervalOptions = Map<int, String>.fromEntries(
      kIntervalOptions.entries.where((entry) => entry.key > 0),
    );
    final selectedValue =
        enabledIntervalOptions.containsKey(
          studentReportAutoRefreshIntervalMinutes,
        )
        ? studentReportAutoRefreshIntervalMinutes
        : 30;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: ComboBox<int>(
        isExpanded: true,
        value: selectedValue,
        items: enabledIntervalOptions.entries
            .map(
              (entry) =>
                  ComboBoxItem<int>(value: entry.key, child: Text(entry.value)),
            )
            .toList(),
        onChanged: studentReportAutoRefreshEnabled
            ? (value) {
                if (value != null) {
                  onStudentReportAutoRefreshIntervalChanged(value);
                }
              }
            : null,
      ),
    );
  }

  Widget _buildAcademicEamsAutoRefreshRow(BuildContext context) {
    final theme = FluentTheme.of(context);
    return buildResponsiveSettingsRow(
      context: context,
      icon: FluentIcons.education,
      title: Text('本专科教务自动刷新', style: theme.typography.bodyStrong),
      subtitle: Text(
        '控制教务中心本专科教务摘要和独立课程表页面的自动读取；需要校园网或学校 VPN 与 OA 登录，关闭后仍可在页面中手动刷新',
        style: theme.typography.caption,
      ),
      trailing: Wrap(
        spacing: FluentSpacing.s,
        runSpacing: FluentSpacing.s,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ToggleSwitch(
            checked: academicEamsAutoRefreshEnabled,
            onChanged: (value) => onAcademicEamsAutoRefreshChanged(value),
          ),
          _buildAcademicEamsIntervalComboBox(),
        ],
      ),
    );
  }

  Widget _buildAcademicEamsIntervalComboBox() {
    final enabledIntervalOptions = Map<int, String>.fromEntries(
      kIntervalOptions.entries.where((entry) => entry.key > 0),
    );
    final selectedValue =
        enabledIntervalOptions.containsKey(
          academicEamsAutoRefreshIntervalMinutes,
        )
        ? academicEamsAutoRefreshIntervalMinutes
        : 30;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: ComboBox<int>(
        isExpanded: true,
        value: selectedValue,
        items: enabledIntervalOptions.entries
            .map(
              (entry) =>
                  ComboBoxItem<int>(value: entry.key, child: Text(entry.value)),
            )
            .toList(),
        onChanged: academicEamsAutoRefreshEnabled
            ? (value) {
                if (value != null) {
                  onAcademicEamsAutoRefreshIntervalChanged(value);
                }
              }
            : null,
      ),
    );
  }

  Widget _buildShortcutRow({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onPressed,
  }) {
    final theme = FluentTheme.of(context);
    return buildResponsiveSettingsRow(
      context: context,
      icon: icon,
      title: Text(title, style: theme.typography.bodyStrong),
      subtitle: Text(description, style: theme.typography.caption),
      trailing: Button(onPressed: onPressed, child: const Text('前往设置')),
    );
  }
}
