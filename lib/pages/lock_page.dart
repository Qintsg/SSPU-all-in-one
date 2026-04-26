/*
 * 锁定页 — 应用启动时的密码验证界面
 * 设计参考 1Password 锁定页面风格
 * @Project : SSPU-all-in-one
 * @File : lock_page.dart
 * @Author : Qintsg
 * @Date : 2026-04-18
 */

import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import '../services/password_service.dart';
import '../services/system_auth_service.dart';
import '../theme/fluent_tokens.dart';

/// 锁定页面
/// 当用户设置密码保护后，应用启动时显示此页面
/// 输入正确密码后解锁进入主界面
class LockPage extends StatefulWidget {
  /// 解锁成功后的回调
  final VoidCallback onUnlocked;

  const LockPage({super.key, required this.onUnlocked});

  @override
  State<LockPage> createState() => _LockPageState();
}

class _LockPageState extends State<LockPage> with TickerProviderStateMixin {
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  /// 错误提示文本
  String? _errorMessage;

  /// 是否正在验证中
  bool _isVerifying = false;

  /// 是否已启用且当前设备可用系统快速验证。
  bool _isSystemAuthEnabled = false;

  /// 是否正在请求系统认证。
  bool _isSystemAuthenticating = false;

  /// 防止系统认证与密码验证重复触发解锁回调。
  bool _hasCompletedUnlock = false;

  /// 抖动动画控制器，密码错误时触发
  late AnimationController _shakeController;

  /// 抖动偏移动画
  late Animation<double> _shakeAnimation;

  /// 解锁动画控制器（成功验证后播放）
  late AnimationController _unlockController;

  /// 解锁缩放动画
  late Animation<double> _unlockScale;

  /// 解锁透明度动画
  late Animation<double> _unlockOpacity;

  @override
  void initState() {
    super.initState();
    // 初始化抖动动画（密码错误时水平晃动）
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0, end: -10), weight: 1),
          TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
          TweenSequenceItem(tween: Tween(begin: 10, end: -10), weight: 2),
          TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
          TweenSequenceItem(tween: Tween(begin: 10, end: 0), weight: 1),
        ]).animate(
          CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
        );

    // 初始化解锁动画（缩放 + 淡出）
    _unlockController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _unlockScale = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _unlockController, curve: Curves.easeOut),
    );
    _unlockOpacity = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _unlockController, curve: Curves.easeIn));

    // 自动聚焦到密码输入框
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });

    unawaited(_loadAndTrySystemAuth());
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _unlockController.dispose();
    _passwordController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// 执行密码验证
  Future<void> _handleUnlock() async {
    if (_hasCompletedUnlock) return;
    final inputPassword = _passwordController.text;

    // 空密码直接提示
    if (inputPassword.isEmpty) {
      setState(() => _errorMessage = '请输入密码');
      _triggerShake();
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    final isCorrect = await PasswordService.verifyPassword(inputPassword);

    if (!mounted) return;

    if (isCorrect) {
      // 密码正确，播放解锁动画后回调
      _completeUnlock();
    } else {
      // 密码错误，显示错误提示并触发抖动动画
      setState(() {
        _isVerifying = false;
        _errorMessage = '密码错误，请重试';
      });
      _passwordController.clear();
      _triggerShake();
      _focusNode.requestFocus();
    }
  }

  /// 加载系统快速验证配置，并在可用时优先尝试系统认证。
  Future<void> _loadAndTrySystemAuth() async {
    final quickAuthEnabled = await PasswordService.isQuickAuthEnabled();
    if (!quickAuthEnabled) return;

    final systemAuthAvailable = await SystemAuthService.instance.isAvailable();
    if (!mounted || !systemAuthAvailable) return;

    setState(() => _isSystemAuthEnabled = true);
    await _handleSystemUnlock(autoTriggered: true);
  }

  /// 执行系统认证解锁。失败、取消、超时或不可用时保留手动密码路径。
  Future<void> _handleSystemUnlock({bool autoTriggered = false}) async {
    if (_hasCompletedUnlock || _isSystemAuthenticating) return;

    setState(() {
      _isSystemAuthenticating = true;
      if (!autoTriggered) _errorMessage = null;
    });

    final result = await SystemAuthService.instance.authenticate(
      localizedReason: '验证身份以解锁 SSPU All-in-One',
    );

    if (!mounted || _hasCompletedUnlock) return;

    if (result == SystemAuthResult.success) {
      _completeUnlock();
      return;
    }

    setState(() {
      _isSystemAuthenticating = false;
      _errorMessage = '系统认证未完成，请输入密码解锁';
    });
    _focusNode.requestFocus();
  }

  /// 播放解锁动画并通知上层进入主界面。
  void _completeUnlock() {
    if (_hasCompletedUnlock) return;
    _hasCompletedUnlock = true;
    _unlockController.forward().then((_) {
      if (mounted) {
        widget.onUnlocked();
      }
    });
  }

  /// 触发密码输入框抖动效果
  void _triggerShake() {
    _shakeController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 使用 ScaffoldPage 替代 NavigationView，避免 FocusNode 生命周期冲突
    return AnimatedBuilder(
      animation: Listenable.merge([_unlockScale, _unlockOpacity]),
      builder: (context, child) {
        return Opacity(
          opacity: _unlockOpacity.value,
          child: Transform.scale(scale: _unlockScale.value, child: child),
        );
      },
      child: ScaffoldPage(
        content: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(FluentSpacing.xxxl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Image.asset('assets/images/logo.png', width: 80, height: 80),
                const SizedBox(height: FluentSpacing.xxl),

                // 应用名称
                Text('SSPU All-in-One', style: theme.typography.subtitle),
                const SizedBox(height: FluentSpacing.s),
                Text(
                  '应用已锁定',
                  style: theme.typography.bodyLarge?.copyWith(
                    color: isDark
                        ? FluentDarkColors.textSecondary
                        : FluentLightColors.textSecondary,
                  ),
                ),
                const SizedBox(height: FluentSpacing.xxxl + FluentSpacing.s),

                // 密码输入区域（带抖动动画）
                AnimatedBuilder(
                  animation: _shakeAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(_shakeAnimation.value, 0),
                      child: child,
                    );
                  },
                  child: SizedBox(
                    width: 320,
                    child: Column(
                      children: [
                        PasswordBox(
                          controller: _passwordController,
                          placeholder: '输入密码以解锁',
                          focusNode: _focusNode,
                          revealMode: PasswordRevealMode.peekAlways,
                          onSubmitted: (_) => _handleUnlock(),
                        ),
                        const SizedBox(height: FluentSpacing.s),

                        // 错误提示
                        if (_errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: FluentSpacing.s,
                            ),
                            child: Text(
                              _errorMessage!,
                              style: theme.typography.caption?.copyWith(
                                color: isDark
                                    ? FluentDarkColors.statusError
                                    : FluentLightColors.statusError,
                              ),
                            ),
                          ),

                        const SizedBox(height: FluentSpacing.s),

                        // 解锁按钮
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _isVerifying ? null : _handleUnlock,
                            child: _isVerifying
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: ProgressRing(strokeWidth: 2),
                                  )
                                : const Text('解锁'),
                          ),
                        ),
                        if (_isSystemAuthEnabled) ...[
                          const SizedBox(height: FluentSpacing.s),
                          SizedBox(
                            width: double.infinity,
                            child: Button(
                              onPressed: _isSystemAuthenticating
                                  ? null
                                  : () => _handleSystemUnlock(),
                              child: _isSystemAuthenticating
                                  ? const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          height: 16,
                                          width: 16,
                                          child: ProgressRing(strokeWidth: 2),
                                        ),
                                        SizedBox(width: FluentSpacing.s),
                                        Text('等待系统认证'),
                                      ],
                                    )
                                  : const Text('使用系统认证'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
