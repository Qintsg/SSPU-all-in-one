/*
 * 设置页安全分区组件 — 密码保护与数据管理
 * @Project : SSPU-all-in-one
 * @File : settings_security_section.dart
 * @Author : Qintsg
 * @Date : 2026-04-23
 */

import 'package:fluent_ui/fluent_ui.dart';

import '../models/academic_credentials.dart';
import '../models/academic_login_validation.dart';
import '../services/academic_credentials_service.dart';
import '../services/academic_login_validation_service.dart';
import '../theme/fluent_tokens.dart';
import 'settings_widgets.dart';

part 'settings_security_credentials_section.dart';

/// 安全设置分区。
class SettingsSecuritySection extends StatefulWidget {
  /// 是否已启用密码保护。
  final bool isPasswordEnabled;

  /// 开关密码保护。
  final ValueChanged<bool> onPasswordProtectionChanged;

  /// 修改密码回调。
  final VoidCallback onChangePassword;

  /// 是否已启用系统快速验证。
  final bool isQuickAuthEnabled;

  /// 当前平台/设备是否可用系统快速验证。
  final bool isQuickAuthAvailable;

  /// 系统快速验证开关是否正在处理。
  final bool isQuickAuthBusy;

  /// 开关系统快速验证。
  final ValueChanged<bool> onQuickAuthChanged;

  /// 立即上锁回调。
  final VoidCallback? onLock;

  /// 清理消息缓存回调。
  final VoidCallback onClearMessageCache;

  /// 清除所有数据回调。
  final VoidCallback onClearAllData;

  /// 可替换的 OA 登录校验服务，便于测试中使用 fake 网关。
  final AcademicLoginValidationService? academicLoginValidationService;

  const SettingsSecuritySection({
    super.key,
    required this.isPasswordEnabled,
    required this.onPasswordProtectionChanged,
    required this.onChangePassword,
    required this.isQuickAuthEnabled,
    required this.isQuickAuthAvailable,
    required this.isQuickAuthBusy,
    required this.onQuickAuthChanged,
    required this.onLock,
    required this.onClearMessageCache,
    required this.onClearAllData,
    this.academicLoginValidationService,
  });

  @override
  State<SettingsSecuritySection> createState() =>
      _SettingsSecuritySectionState();
}

class _SettingsSecuritySectionState extends State<SettingsSecuritySection> {
  final AcademicCredentialsService _academicCredentials =
      AcademicCredentialsService.instance;
  final TextEditingController _oaAccountController = TextEditingController();
  final TextEditingController _emailAccountController = TextEditingController();
  final TextEditingController _oaPasswordController = TextEditingController();
  final TextEditingController _sportsPasswordController =
      TextEditingController();
  final TextEditingController _emailPasswordController =
      TextEditingController();

  AcademicCredentialsStatus _credentialsStatus =
      const AcademicCredentialsStatus.empty();
  AcademicLoginValidationResult? _loginValidationResult;
  bool _isCredentialsLoading = true;
  bool _isSavingCredentials = false;
  bool _isValidatingAcademicLogin = false;

  AcademicLoginValidationService get _academicLoginValidationService {
    return widget.academicLoginValidationService ??
        AcademicLoginValidationService.instance;
  }

  @override
  void initState() {
    super.initState();
    _loadAcademicCredentials();
  }

  @override
  void dispose() {
    _oaAccountController.dispose();
    _emailAccountController.dispose();
    _oaPasswordController.dispose();
    _sportsPasswordController.dispose();
    _emailPasswordController.dispose();
    super.dispose();
  }

  /// 加载教务凭据状态，密码输入框始终保持为空。
  Future<void> _loadAcademicCredentials() async {
    try {
      final status = await _academicCredentials.getStatus();
      if (!mounted) return;
      _oaAccountController.text = status.oaAccount;
      _emailAccountController.text = status.emailAccount;
      _clearPasswordInputs();
      setState(() {
        _credentialsStatus = status;
        _isCredentialsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _credentialsStatus = const AcademicCredentialsStatus.empty();
        _isCredentialsLoading = false;
      });
    }
  }

  /// 保存本次填写的账号和密码。
  Future<void> _saveAcademicCredentials() async {
    if (_isSavingCredentials) return;
    setState(() => _isSavingCredentials = true);

    try {
      await _academicCredentials.saveCredentials(
        oaAccount: _oaAccountController.text,
        emailAccount: _emailAccountController.text,
        oaPassword: _nullablePassword(_oaPasswordController.text),
        sportsQueryPassword: _nullablePassword(_sportsPasswordController.text),
        emailPassword: _nullablePassword(_emailPasswordController.text),
      );
      final status = await _academicCredentials.getStatus();
      if (!mounted) return;
      _clearPasswordInputs();
      setState(() {
        _credentialsStatus = status;
        _isSavingCredentials = false;
      });
      _showCredentialInfoBar('教务凭据已保存', InfoBarSeverity.success);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSavingCredentials = false);
      _showCredentialInfoBar('保存失败，请确认系统安全存储可用', InfoBarSeverity.error);
    }
  }

  /// 清除指定密码字段。
  Future<void> _clearAcademicSecret(AcademicCredentialSecret secret) async {
    if (_isSavingCredentials) return;
    setState(() => _isSavingCredentials = true);

    try {
      await _academicCredentials.clearSecret(secret);
      final status = await _academicCredentials.getStatus();
      if (!mounted) return;
      _clearPasswordInputs();
      setState(() {
        _credentialsStatus = status;
        _isSavingCredentials = false;
      });
      _showCredentialInfoBar(
        '${_secretLabel(secret)}已清除',
        InfoBarSeverity.info,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSavingCredentials = false);
      _showCredentialInfoBar('清除失败，请确认系统安全存储可用', InfoBarSeverity.error);
    }
  }

  /// 使用已保存账号密码执行一次只读 OA 登录校验。
  Future<void> _validateAcademicLogin() async {
    if (_isSavingCredentials || _isValidatingAcademicLogin) return;
    setState(() {
      _isValidatingAcademicLogin = true;
      _loginValidationResult = null;
    });

    final result = await _academicLoginValidationService
        .validateSavedCredentials();
    if (!mounted) return;
    setState(() {
      _loginValidationResult = result;
      _isValidatingAcademicLogin = false;
    });
  }

  /// 空输入表示不修改当前密码。
  String? _nullablePassword(String value) => value.isEmpty ? null : value;

  /// 清空所有密码输入框，避免明文停留在页面控件中。
  void _clearPasswordInputs() {
    _oaPasswordController.clear();
    _sportsPasswordController.clear();
    _emailPasswordController.clear();
  }

  /// 显示教务凭据操作反馈。
  void _showCredentialInfoBar(String message, InfoBarSeverity severity) {
    displayInfoBar(
      context,
      builder: (ctx, close) => InfoBar(
        title: Text(message),
        severity: severity,
        action: IconButton(
          icon: const Icon(FluentIcons.clear),
          onPressed: close,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FluentSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('安全', style: FluentTheme.of(context).typography.subtitle),
            const SizedBox(height: FluentSpacing.l),
            buildResponsiveSettingsRow(
              context: context,
              icon: FluentIcons.lock,
              title: Text(
                '密码保护',
                style: FluentTheme.of(context).typography.bodyStrong,
              ),
              subtitle: Text(
                widget.isPasswordEnabled
                    ? '已开启 — 重新打开应用时需要输入密码'
                    : '未开启 — 任何人可直接进入应用',
                style: FluentTheme.of(context).typography.caption,
              ),
              trailing: ToggleSwitch(
                checked: widget.isPasswordEnabled,
                onChanged: widget.onPasswordProtectionChanged,
              ),
            ),
            if (widget.isPasswordEnabled && widget.isQuickAuthAvailable) ...[
              const SizedBox(height: FluentSpacing.l),
              buildResponsiveSettingsRow(
                context: context,
                icon: FluentIcons.fingerprint,
                title: Text(
                  '系统快速验证',
                  style: FluentTheme.of(context).typography.bodyStrong,
                ),
                subtitle: Text(
                  widget.isQuickAuthEnabled
                      ? '已开启 — 锁定页会优先请求系统认证，仍可输入密码解锁'
                      : '可使用设备 PIN、生物识别或平台支持的系统认证快速解锁',
                  style: FluentTheme.of(context).typography.caption,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.isQuickAuthBusy) ...[
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: ProgressRing(strokeWidth: 2),
                      ),
                      const SizedBox(width: FluentSpacing.s),
                    ],
                    ToggleSwitch(
                      checked: widget.isQuickAuthEnabled,
                      onChanged: widget.isQuickAuthBusy
                          ? null
                          : widget.onQuickAuthChanged,
                    ),
                  ],
                ),
              ),
            ] else if (widget.isPasswordEnabled) ...[
              const SizedBox(height: FluentSpacing.l),
              buildResponsiveSettingsRow(
                context: context,
                icon: FluentIcons.fingerprint,
                title: Text(
                  '系统快速验证不可用',
                  style: FluentTheme.of(context).typography.bodyStrong,
                ),
                subtitle: Text(
                  '当前平台、设备或系统认证未配置；仍可使用应用密码手动解锁。',
                  style: FluentTheme.of(context).typography.caption,
                ),
                trailing: const Icon(FluentIcons.info, size: 16),
              ),
            ],
            if (widget.isPasswordEnabled) ...[
              const SizedBox(height: FluentSpacing.m),
              Wrap(
                spacing: FluentSpacing.m,
                runSpacing: FluentSpacing.s,
                children: [
                  Button(
                    onPressed: widget.onChangePassword,
                    child: const Text('修改密码'),
                  ),
                  FilledButton(
                    onPressed: widget.onLock,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.lock, size: 14),
                        SizedBox(width: FluentSpacing.xs + FluentSpacing.xxs),
                        Text('立即上锁'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: FluentSpacing.xl),
            const Divider(),
            const SizedBox(height: FluentSpacing.l),
            _buildAcademicCredentialsSection(context),
            const SizedBox(height: FluentSpacing.xl),
            const Divider(),
            const SizedBox(height: FluentSpacing.l),
            Text('数据管理', style: FluentTheme.of(context).typography.subtitle),
            const SizedBox(height: FluentSpacing.xs),
            Text(
              '清理信息中心缓存的消息，不影响登录信息和设置',
              style: FluentTheme.of(context).typography.caption,
            ),
            const SizedBox(height: FluentSpacing.m),
            Wrap(
              spacing: FluentSpacing.s,
              runSpacing: FluentSpacing.s,
              children: [
                Button(
                  onPressed: widget.onClearMessageCache,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FluentIcons.broom, size: 14),
                      SizedBox(width: FluentSpacing.xs + FluentSpacing.xxs),
                      Text('清理信息中心缓存'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: FluentSpacing.l),
            const Divider(),
            const SizedBox(height: FluentSpacing.l),
            Text(
              '清除所有本地数据（包括登录信息、设置、缓存等），应用将退出',
              style: FluentTheme.of(context).typography.caption,
            ),
            const SizedBox(height: FluentSpacing.m),
            Wrap(
              spacing: FluentSpacing.s,
              runSpacing: FluentSpacing.s,
              children: [
                Button(
                  onPressed: widget.onClearAllData,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FluentIcons.delete, size: 14),
                      SizedBox(width: FluentSpacing.xs + FluentSpacing.xxs),
                      Text('清除所有数据'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 返回密码字段展示名。
  String _secretLabel(AcademicCredentialSecret secret) {
    return switch (secret) {
      AcademicCredentialSecret.oaPassword => 'OA账号密码',
      AcademicCredentialSecret.sportsQueryPassword => '体育部查询密码',
      AcademicCredentialSecret.emailPassword => '邮箱密码',
    };
  }
}
