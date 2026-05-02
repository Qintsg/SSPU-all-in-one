/*
 * 设置页教务凭据区域 — 账号、密码与 OA 登录校验展示
 * @Project : SSPU-all-in-one
 * @File : settings_security_credentials_section.dart
 * @Author : Qintsg
 * @Date : 2026-05-01
 */

part of 'settings_security_section.dart';

extension _SettingsSecurityCredentialsSection on _SettingsSecuritySectionState {
  /// 构建教务系统账号与密码保存区域。
  Widget _buildAcademicCredentialsSection(BuildContext context) {
    final theme = FluentTheme.of(context);
    if (_isCredentialsLoading) {
      return const Center(child: ProgressRing());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('教务凭据', style: theme.typography.subtitle),
        const SizedBox(height: FluentSpacing.xs),
        Text(
          '数据均加密存储在本地，不会上传至云端；密码框留空时不修改已保存密码。',
          style: theme.typography.caption,
        ),
        const SizedBox(height: FluentSpacing.m),
        InfoLabel(
          label: '学工号（OA账号）',
          child: TextBox(
            controller: _oaAccountController,
            placeholder: '请输入学工号',
          ),
        ),
        const SizedBox(height: FluentSpacing.xs),
        Text(
          _credentialsStatus.emailAccount.isEmpty
              ? '学校邮箱账号将自动使用“学工号@sspu.edu.cn”。'
              : '学校邮箱账号：${_credentialsStatus.emailAccount}',
          style: theme.typography.caption?.copyWith(
            color: theme.resources.textFillColorSecondary,
          ),
        ),
        const SizedBox(height: FluentSpacing.m),
        _buildPasswordCredentialField(
          label: 'OA账号密码',
          controller: _oaPasswordController,
          secret: AcademicCredentialSecret.oaPassword,
        ),
        const SizedBox(height: FluentSpacing.m),
        _buildPasswordCredentialField(
          label: '体育部查询密码',
          controller: _sportsPasswordController,
          secret: AcademicCredentialSecret.sportsQueryPassword,
        ),
        const SizedBox(height: FluentSpacing.m),
        _buildPasswordCredentialField(
          label: '邮箱密码',
          controller: _emailPasswordController,
          secret: AcademicCredentialSecret.emailPassword,
        ),
        const SizedBox(height: FluentSpacing.l),
        Wrap(
          spacing: FluentSpacing.s,
          runSpacing: FluentSpacing.s,
          children: [
            FilledButton(
              onPressed: _isSavingCredentials ? null : _saveAcademicCredentials,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isSavingCredentials) ...[
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: ProgressRing(strokeWidth: 2),
                    ),
                  ] else ...[
                    const Icon(FluentIcons.save, size: 14),
                  ],
                  const SizedBox(width: 6),
                  const Text('保存教务凭据'),
                ],
              ),
            ),
            Button(
              onPressed: _isSavingCredentials || _isValidatingAcademicLogin
                  ? null
                  : _validateAcademicLogin,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isValidatingAcademicLogin) ...[
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: ProgressRing(strokeWidth: 2),
                    ),
                  ] else ...[
                    const Icon(FluentIcons.plug_connected, size: 14),
                  ],
                  const SizedBox(width: 6),
                  const Text('验证 OA 登录'),
                ],
              ),
            ),
          ],
        ),
        if (_loginValidationResult != null) ...[
          const SizedBox(height: FluentSpacing.m),
          _buildAcademicLoginValidationResult(_loginValidationResult!),
        ],
      ],
    );
  }

  /// 构建 OA 登录校验结果提示，不展示任何敏感凭据。
  Widget _buildAcademicLoginValidationResult(
    AcademicLoginValidationResult result,
  ) {
    return InfoBar(
      title: Text(result.message),
      content: Text(result.detail),
      severity: _loginValidationSeverity(result.status),
      isLong: true,
    );
  }

  /// 将登录校验状态映射为 Fluent 提示等级。
  InfoBarSeverity _loginValidationSeverity(
    AcademicLoginValidationStatus status,
  ) {
    return switch (status) {
      AcademicLoginValidationStatus.success => InfoBarSeverity.success,
      AcademicLoginValidationStatus.missingOaAccount ||
      AcademicLoginValidationStatus.missingOaPassword ||
      AcademicLoginValidationStatus.campusNetworkUnavailable ||
      AcademicLoginValidationStatus.captchaRequired ||
      AcademicLoginValidationStatus.additionalVerificationRequired =>
        InfoBarSeverity.warning,
      AcademicLoginValidationStatus.loginPageUnavailable ||
      AcademicLoginValidationStatus.credentialsRejected ||
      AcademicLoginValidationStatus.webFlowChanged ||
      AcademicLoginValidationStatus.networkError ||
      AcademicLoginValidationStatus.unexpectedError => InfoBarSeverity.error,
    };
  }

  /// 构建单个密码输入框和填写状态。
  Widget _buildPasswordCredentialField({
    required String label,
    required TextEditingController controller,
    required AcademicCredentialSecret secret,
  }) {
    final hasSecret = _credentialsStatus.hasSecret(secret);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoLabel(
          label: label,
          child: PasswordBox(
            controller: controller,
            placeholder: '留空则不修改已保存密码',
            revealMode: PasswordRevealMode.peekAlways,
          ),
        ),
        const SizedBox(height: FluentSpacing.xs),
        Wrap(
          spacing: FluentSpacing.s,
          runSpacing: FluentSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _buildSecretStatus(hasSecret),
            if (hasSecret)
              Button(
                onPressed: _isSavingCredentials
                    ? null
                    : () => _clearAcademicSecret(secret),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.delete, size: 14),
                    SizedBox(width: 6),
                    Text('清除'),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// 构建已填写/未填写状态提示。
  Widget _buildSecretStatus(bool hasSecret) {
    final theme = FluentTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          hasSecret ? FluentIcons.check_mark : FluentIcons.blocked,
          size: 14,
        ),
        const SizedBox(width: FluentSpacing.xs),
        Text(hasSecret ? '已填写' : '未填写', style: theme.typography.caption),
      ],
    );
  }
}
