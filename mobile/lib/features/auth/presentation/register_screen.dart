import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/error_message.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../onboarding/data/user_details_repository.dart';
import '../application/auth_controller.dart';
import 'widgets/auth_widgets.dart';

/// Account creation. Registering also logs the user in immediately, matching
/// the backend flow (register, then login to receive a token pair).
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _submitting = false;
  String? _submitError;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
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
      await ref.read(authControllerProvider.notifier).register(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
          );
      // A fresh registration never has a user_details row yet — go straight
      // to onboarding instead of the router's default post-login /dashboard.
      if (mounted) context.go('/onboarding');
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
      if (!signedIn) {
        if (mounted) setState(() => _submitError = l10n.googleSignInCancelledMessage);
      } else if (mounted) {
        // Google sign-in from the register screen may resolve to an
        // existing account — only route to onboarding if it truly hasn't
        // been completed yet (GET /user-details 404).
        await _routeAfterGoogleSignIn();
      }
    } catch (error) {
      setState(() => _submitError = friendlyError(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _routeAfterGoogleSignIn() async {
    try {
      await ref.read(userDetailsRepositoryProvider).get();
      if (mounted) context.go('/dashboard');
    } on DioException catch (e) {
      if (!mounted) return;
      context.go(e.response?.statusCode == 404 ? '/onboarding' : '/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    String? required(String? value) => (value?.trim().isEmpty ?? true) ? l10n.requiredFieldError : null;

    return AuthPage(
      showBack: true,
      bottom: AuthSwitchPrompt(
        lead: l10n.signInPromptLead,
        action: l10n.signInButton,
        onPressed: _submitting ? null : () => Navigator.of(context).maybePop(),
      ),
      children: [
        AuthHeading(title: l10n.createAccountTitle),
        const SizedBox(height: AppSpacing.s24),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthTextField(
                controller: _firstNameController,
                label: l10n.firstNameLabel,
                icon: Icons.person_outline_rounded,
                textInputAction: TextInputAction.next,
                validator: required,
              ),
              const SizedBox(height: AppSpacing.s16),
              AuthTextField(
                controller: _lastNameController,
                label: l10n.lastNameLabel,
                icon: Icons.person_outline_rounded,
                textInputAction: TextInputAction.next,
                validator: required,
              ),
              const SizedBox(height: AppSpacing.s16),
              AuthTextField(
                controller: _emailController,
                label: l10n.emailLabel,
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
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
                onFieldSubmitted: (_) => _submit(),
                validator: (value) => value != _passwordController.text ? l10n.passwordsDoNotMatchError : null,
              ),
            ],
          ),
        ),
        if (_submitError != null) AuthErrorText(_submitError!),
        const SizedBox(height: AppSpacing.s24),
        AuthPrimaryButton(label: l10n.createAccountTitle, onPressed: _submitting ? null : _submit, loading: _submitting),
        const SizedBox(height: AppSpacing.s20),
        const AuthOrDivider(),
        const SizedBox(height: AppSpacing.s20),
        AuthGoogleButton(onPressed: _submitting ? null : _submitGoogle),
      ],
    );
  }
}
