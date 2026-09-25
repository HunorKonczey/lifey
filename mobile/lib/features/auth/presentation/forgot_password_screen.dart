import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/error_message.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/ds/notice_card.dart';
import '../application/auth_controller.dart';
import 'widgets/auth_widgets.dart';

enum _Step { email, reset }

/// Two-step forgot-password flow: email → 6-digit code + new password.
/// Both endpoints are online-only (no outbox involvement), matching the rest
/// of auth.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmController = TextEditingController();

  _Step _step = _Step.email;
  bool _submitting = false;
  String? _submitError;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submitEmail() async {
    if (_submitting) return;
    if (!_emailFormKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .forgotPassword(_emailController.text.trim());
      if (mounted) setState(() => _step = _Step.reset);
    } catch (error) {
      setState(() => _submitError = friendlyError(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitReset() async {
    if (_submitting) return;
    if (!_resetFormKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).resetPassword(
            email: _emailController.text.trim(),
            code: _codeController.text.trim(),
            newPassword: _newPasswordController.text,
          );
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        AppSnackbar.showSuccess(context, title: l10n.passwordResetSuccessMessage);
        context.go('/login');
      }
    } catch (error) {
      setState(() => _submitError = friendlyError(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AuthPage(
      showBack: true,
      children: _step == _Step.email ? _emailStep(l10n) : _resetStep(l10n),
    );
  }

  List<Widget> _emailStep(AppLocalizations l10n) => [
        AuthHeading(title: l10n.forgotPasswordTitle, subtitle: l10n.forgotPasswordSubtitle),
        const SizedBox(height: AppSpacing.s24),
        Form(
          key: _emailFormKey,
          child: AuthTextField(
            controller: _emailController,
            label: l10n.emailLabel,
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submitEmail(),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return l10n.requiredFieldError;
              if (!text.contains('@')) return l10n.invalidEmailError;
              return null;
            },
          ),
        ),
        if (_submitError != null) AuthErrorText(_submitError!),
        const SizedBox(height: AppSpacing.s24),
        AuthPrimaryButton(label: l10n.sendResetCodeButton, onPressed: _submitting ? null : _submitEmail, loading: _submitting),
        const SizedBox(height: AppSpacing.s8),
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).maybePop(),
          child: Text(l10n.backToSignInButton),
        ),
      ];

  List<Widget> _resetStep(AppLocalizations l10n) => [
        AuthHeading(title: l10n.resetPasswordTitle, subtitle: l10n.resetPasswordSubtitle),
        const SizedBox(height: AppSpacing.s16),
        NoticeCard(icon: Icons.mark_email_read_outlined, title: l10n.resetCodeSentMessage),
        const SizedBox(height: AppSpacing.s24),
        Form(
          key: _resetFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthTextField(
                controller: _codeController,
                label: l10n.resetCodeLabel,
                icon: Icons.pin_outlined,
                keyboardType: TextInputType.number,
                autofocus: true,
                textInputAction: TextInputAction.next,
                validator: (value) =>
                    RegExp(r'^\d{6}$').hasMatch(value?.trim() ?? '') ? null : l10n.invalidResetCodeError,
              ),
              const SizedBox(height: AppSpacing.s16),
              AuthTextField(
                controller: _newPasswordController,
                label: l10n.newPasswordLabel,
                icon: Icons.lock_outline_rounded,
                obscureText: true,
                helperText: l10n.passwordHelperText,
                textInputAction: TextInputAction.next,
                validator: (value) => (value == null || value.length < 8) ? l10n.passwordTooShortError : null,
              ),
              const SizedBox(height: AppSpacing.s16),
              AuthTextField(
                controller: _confirmController,
                label: l10n.confirmPasswordLabel,
                icon: Icons.lock_outline_rounded,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submitReset(),
                validator: (value) => value != _newPasswordController.text ? l10n.passwordsDoNotMatchError : null,
              ),
            ],
          ),
        ),
        if (_submitError != null) AuthErrorText(_submitError!),
        const SizedBox(height: AppSpacing.s24),
        AuthPrimaryButton(label: l10n.resetPasswordButton, onPressed: _submitting ? null : _submitReset, loading: _submitting),
        const SizedBox(height: AppSpacing.s8),
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).maybePop(),
          child: Text(l10n.backToSignInButton),
        ),
      ];
}
