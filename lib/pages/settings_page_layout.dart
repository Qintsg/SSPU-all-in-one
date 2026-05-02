/*
 * 设置页布局 — 响应式导航与设置分区内容切换
 * @Project : SSPU-all-in-one
 * @File : settings_page_layout.dart
 * @Author : Qintsg
 * @Date : 2026-05-01
 */

part of 'settings_page.dart';

mixin _SettingsPageLayout on State<SettingsPage>, _SettingsPageActions {
  int get _selectedTab;
  set _selectedTab(int value);

  /// 宽屏布局。
  Widget _buildWideSettingsLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 180,
          child: Padding(
            padding: const EdgeInsets.only(
              left: FluentSpacing.l,
              top: FluentSpacing.s,
            ),
            child: _buildSettingsNavigation(context),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: FluentSpacing.s),
          child: Divider(direction: Axis.vertical),
        ),
        Expanded(
          child: _buildScrollableContent(
            responsivePagePadding(
              DeviceType.desktop,
              vertical: FluentSpacing.s,
            ),
          ),
        ),
      ],
    );
  }

  /// 窄屏布局。
  Widget _buildNarrowSettingsLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            FluentSpacing.l,
            0,
            FluentSpacing.l,
            FluentSpacing.s,
          ),
          child: _buildSettingsTabCombo(context),
        ),
        const Divider(),
        Expanded(
          child: _buildScrollableContent(
            responsivePagePadding(DeviceType.phone, vertical: FluentSpacing.s),
          ),
        ),
      ],
    );
  }

  /// 左侧导航。
  Widget _buildSettingsNavigation(BuildContext context) {
    final theme = FluentTheme.of(context);
    final captionStyle = theme.typography.caption?.copyWith(
      color: theme.resources.textFillColorSecondary,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Text('系统设置', style: captionStyle),
        ),
        buildSettingsNavItem(
          context: context,
          index: 0,
          selectedIndex: _selectedTab,
          icon: FluentIcons.settings,
          label: '常规设置',
          onTap: () => setState(() => _selectedTab = 0),
        ),
        const SizedBox(height: FluentSpacing.xxs),
        buildSettingsNavItem(
          context: context,
          index: 1,
          selectedIndex: _selectedTab,
          icon: FluentIcons.sync,
          label: '自动刷新设置',
          onTap: () => setState(() => _selectedTab = 1),
        ),
        const SizedBox(height: FluentSpacing.xxs),
        buildSettingsNavItem(
          context: context,
          index: 2,
          selectedIndex: _selectedTab,
          icon: FluentIcons.lock,
          label: '安全设置',
          onTap: () => setState(() => _selectedTab = 2),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Divider(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Text('消息推送设置', style: captionStyle),
        ),
        buildSettingsNavItem(
          context: context,
          index: 3,
          selectedIndex: _selectedTab,
          icon: FluentIcons.education,
          label: '职能部门',
          onTap: () => setState(() => _selectedTab = 3),
        ),
        const SizedBox(height: FluentSpacing.xxs),
        buildSettingsNavItem(
          context: context,
          index: 4,
          selectedIndex: _selectedTab,
          icon: FluentIcons.library,
          label: '教学单位',
          onTap: () => setState(() => _selectedTab = 4),
        ),
        const SizedBox(height: FluentSpacing.xxs),
        buildSettingsNavItem(
          context: context,
          index: 5,
          selectedIndex: _selectedTab,
          icon: FluentIcons.chat,
          label: '微信推文',
          onTap: () => setState(() => _selectedTab = 5),
        ),
      ],
    );
  }

  /// 窄屏顶部下拉。
  Widget _buildSettingsTabCombo(BuildContext context) {
    return Row(
      children: [
        const Icon(FluentIcons.global_nav_button, size: 16),
        const SizedBox(width: FluentSpacing.s),
        Expanded(
          child: ComboBox<int>(
            key: const Key('settings-narrow-tab-combo'),
            value: _selectedTab,
            isExpanded: true,
            items: const [
              ComboBoxItem(value: 0, child: Text('常规设置')),
              ComboBoxItem(value: 1, child: Text('自动刷新设置')),
              ComboBoxItem(value: 2, child: Text('安全设置')),
              ComboBoxItem(value: 3, child: Text('职能部门')),
              ComboBoxItem(value: 4, child: Text('教学单位')),
              ComboBoxItem(value: 5, child: Text('微信推文')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _selectedTab = value);
            },
          ),
        ),
      ],
    );
  }

  /// 带动画的滚动内容区。
  Widget _buildScrollableContent(EdgeInsets padding) {
    return SingleChildScrollView(
      padding: padding,
      child: _buildContentPanel(context)
          .animate(key: ValueKey(_selectedTab))
          .fadeIn(duration: FluentDuration.slow, curve: FluentEasing.decelerate)
          .slideY(begin: 0.02, end: 0),
    );
  }

  /// 根据分区索引切换内容。
  Widget _buildContentPanel(BuildContext context) {
    switch (_selectedTab) {
      case 0:
        return SettingsGeneralSection(
          closeBehavior: _closeBehavior,
          notificationEnabled: _notificationEnabled,
          dndEnabled: _dndEnabled,
          dndStartHour: _dndStartHour,
          dndStartMinute: _dndStartMinute,
          dndEndHour: _dndEndHour,
          dndEndMinute: _dndEndMinute,
          onCloseBehaviorChanged: _onCloseBehaviorChanged,
          onNotificationChanged: _onNotificationChanged,
          onDndChanged: _onDndChanged,
          onDndStartChanged: _onDndStartChanged,
          onDndEndChanged: _onDndEndChanged,
        );
      case 1:
        return SettingsAutoRefreshSection(
          campusNetworkDetectionIntervalMinutes:
              _campusNetworkDetectionIntervalMinutes,
          onCampusNetworkDetectionIntervalChanged:
              _onCampusNetworkDetectionIntervalChanged,
          sportsAttendanceAutoRefreshEnabled:
              _sportsAttendanceAutoRefreshEnabled,
          sportsAttendanceAutoRefreshIntervalMinutes:
              _sportsAttendanceAutoRefreshIntervalMinutes,
          onSportsAttendanceAutoRefreshChanged:
              _onSportsAttendanceAutoRefreshChanged,
          onSportsAttendanceAutoRefreshIntervalChanged:
              _onSportsAttendanceAutoRefreshIntervalChanged,
          campusCardAutoRefreshEnabled: _campusCardAutoRefreshEnabled,
          campusCardAutoRefreshIntervalMinutes:
              _campusCardAutoRefreshIntervalMinutes,
          onCampusCardAutoRefreshChanged: _onCampusCardAutoRefreshChanged,
          onCampusCardAutoRefreshIntervalChanged:
              _onCampusCardAutoRefreshIntervalChanged,
          emailAutoRefreshEnabled: _emailAutoRefreshEnabled,
          emailAutoRefreshIntervalMinutes: _emailAutoRefreshIntervalMinutes,
          onEmailAutoRefreshChanged: _onEmailAutoRefreshChanged,
          onEmailAutoRefreshIntervalChanged: _onEmailAutoRefreshIntervalChanged,
          studentReportAutoRefreshEnabled: _studentReportAutoRefreshEnabled,
          studentReportAutoRefreshIntervalMinutes:
              _studentReportAutoRefreshIntervalMinutes,
          onStudentReportAutoRefreshChanged: _onStudentReportAutoRefreshChanged,
          onStudentReportAutoRefreshIntervalChanged:
              _onStudentReportAutoRefreshIntervalChanged,
          academicEamsAutoRefreshEnabled: _academicEamsAutoRefreshEnabled,
          academicEamsAutoRefreshIntervalMinutes:
              _academicEamsAutoRefreshIntervalMinutes,
          onAcademicEamsAutoRefreshChanged: _onAcademicEamsAutoRefreshChanged,
          onAcademicEamsAutoRefreshIntervalChanged:
              _onAcademicEamsAutoRefreshIntervalChanged,
          onOpenDepartmentRefreshSettings: () =>
              setState(() => _selectedTab = 3),
          onOpenTeachingRefreshSettings: () => setState(() => _selectedTab = 4),
          onOpenWechatRefreshSettings: () => setState(() => _selectedTab = 5),
        );
      case 2:
        return SettingsSecuritySection(
          isPasswordEnabled: _isPasswordEnabled,
          onPasswordProtectionChanged: _onPasswordProtectionChanged,
          onChangePassword: _onChangePassword,
          isQuickAuthEnabled: _isQuickAuthEnabled,
          isQuickAuthAvailable: _isQuickAuthAvailable,
          isQuickAuthBusy: _isQuickAuthBusy,
          onQuickAuthChanged: _onQuickAuthChanged,
          onLock: widget.onLock,
          onClearMessageCache: _showClearMessageCacheDialog,
          onClearAllData: _showClearAllDataDialog,
        );
      case 3:
        return ChannelListSection(
          key: const ValueKey('department'),
          title: '职能部门',
          channels: departmentChannels,
        );
      case 4:
        return ChannelListSection(
          key: const ValueKey('teaching'),
          title: '教学单位',
          channels: teachingChannels,
        );
      case 5:
        return const SettingsWechatSection();
      default:
        return const SizedBox.shrink();
    }
  }
}
