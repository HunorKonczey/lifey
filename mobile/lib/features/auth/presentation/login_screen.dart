import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/error_message.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../application/auth_controller.dart';
import '../../../shared/widgets/ds/screen_heading.dart';
import 'widgets/auth_widgets.dart';

/// Email/password sign-in. On success the router redirect takes over.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;
  String? _submitError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      TextInput.finishAutofillContext();
    } catch (error) {
      setState(() => _submitError = friendlyError(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitGoogle() async {
    if (_submitting) return;
    final l10n = AppLocalizations.of(context)!;

    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final signedIn = await ref.read(authControllerProvider.notifier).loginWithGoogle();
      if (!signedIn && mounted) {
        setState(() => _submitError = l10n.googleSignInCancelledMessage);
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
      bottom: AuthSwitchPrompt(
        lead: l10n.registerPromptLead,
        action: l10n.createAccountTitle,
        onPressed: _submitting ? null : () => context.push('/register'),
      ),
      children: [
        const BrandTile(),
        const SizedBox(height: AppSpacing.s32),
        ScreenHeading(title: l10n.signInWelcomeTitle, subtitle: l10n.signInSubtitle),
        const SizedBox(height: AppSpacing.s32),
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthTextField(
                  controller: _emailController,
                  label: l10n.emailLabel,
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return l10n.requiredFieldError;
                    if (!text.contains('@')) return l10n.invalidEmailError;
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.s16),
                AuthTextField(
                  controller: _passwordController,
                  label: l10n.passwordLabel,
                  icon: Icons.lock_outline_rounded,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: (value) => (value == null || value.isEmpty) ? l10n.requiredFieldError : null,
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _submitting ? null : () => context.push('/forgot-password'),
            child: Text(l10n.forgotPasswordButton),
          ),
        ),
        if (_submitError != null) AuthErrorText(_submitError!),
        const SizedBox(height: AppSpacing.s8),
        AuthPrimaryButton(label: l10n.signInButton, onPressed: _submitting ? null : _submit, loading: _submitting),
        const SizedBox(height: AppSpacing.s20),
        const AuthOrDivider(),
        const SizedBox(height: AppSpacing.s20),
        AuthGoogleButton(onPressed: _submitting ? null : _submitGoogle),
      ],
    );
  }
}
