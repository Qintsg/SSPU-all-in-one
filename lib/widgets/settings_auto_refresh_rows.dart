/*
 * 设置页自动刷新行 — 构建受限服务刷新开关与间隔选择
 * @Project : SSPU-all-in-one
 * @File : settings_auto_refresh_rows.dart
 * @Author : Qintsg
 * @Date : 2026-05-02
 */

part of 'settings_auto_refresh_section.dart';

extension _SettingsAutoRefreshRows on SettingsAutoRefreshSection {
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
    return _buildEnabledIntervalComboBox(
      selectedIntervalMinutes: sportsAttendanceAutoRefreshIntervalMinutes,
      enabled: sportsAttendanceAutoRefreshEnabled,
      onChanged: onSportsAttendanceAutoRefreshIntervalChanged,
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
    return _buildEnabledIntervalComboBox(
      selectedIntervalMinutes: campusCardAutoRefreshIntervalMinutes,
      enabled: campusCardAutoRefreshEnabled,
      onChanged: onCampusCardAutoRefreshIntervalChanged,
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
    return _buildEnabledIntervalComboBox(
      selectedIntervalMinutes: emailAutoRefreshIntervalMinutes,
      enabled: emailAutoRefreshEnabled,
      onChanged: onEmailAutoRefreshIntervalChanged,
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
    return _buildEnabledIntervalComboBox(
      selectedIntervalMinutes: studentReportAutoRefreshIntervalMinutes,
      enabled: studentReportAutoRefreshEnabled,
      onChanged: onStudentReportAutoRefreshIntervalChanged,
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
    return _buildEnabledIntervalComboBox(
      selectedIntervalMinutes: academicEamsAutoRefreshIntervalMinutes,
      enabled: academicEamsAutoRefreshEnabled,
      onChanged: onAcademicEamsAutoRefreshIntervalChanged,
    );
  }

  Widget _buildEnabledIntervalComboBox({
    required int selectedIntervalMinutes,
    required bool enabled,
    required Future<void> Function(int minutes) onChanged,
  }) {
    final enabledIntervalOptions = Map<int, String>.fromEntries(
      kIntervalOptions.entries.where((entry) => entry.key > 0),
    );
    final selectedValue =
        enabledIntervalOptions.containsKey(selectedIntervalMinutes)
        ? selectedIntervalMinutes
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
        onChanged: enabled
            ? (value) {
                if (value != null) {
                  onChanged(value);
                }
              }
            : null,
      ),
    );
  }
}
