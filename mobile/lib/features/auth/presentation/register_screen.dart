import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/error_message.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../onboarding/data/user_details_repository.dart';
import '../application/auth_controller.dart';

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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back button
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back),
              padding: const EdgeInsets.all(16),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── Header ──────────────────────────────────────
                          Text(
                            l10n.createAccountTitle,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Lifey',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 28),

                          // ── Fields card ──────────────────────────────────
                          _AuthCard(
                            children: [
                              _AuthField(
                                controller: _firstNameController,
                                label: l10n.firstNameLabel,
                                autofocus: true,
                                validator: (value) {
                                  final text = value?.trim() ?? '';
                                  if (text.isEmpty) return l10n.requiredFieldError;
                                  return null;
                                },
                              ),
                              _AuthField(
                                controller: _lastNameController,
                                label: l10n.lastNameLabel,
                                validator: (value) {
                                  final text = value?.trim() ?? '';
                                  if (text.isEmpty) return l10n.requiredFieldError;
                                  return null;
                                },
                              ),
                              _AuthField(
                                controller: _emailController,
                                label: l10n.emailLabel,
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  final text = value?.trim() ?? '';
                                  if (text.isEmpty) return l10n.requiredFieldError;
                                  if (!text.contains('@')) return l10n.invalidEmailError;
                                  return null;
                                },
                              ),
                              _AuthField(
                                controller: _passwordController,
                                label: l10n.passwordLabel,
                                obscureText: true,
                                helperText: l10n.passwordHelperText,
                                validator: (value) {
                                  if (value == null || value.length < 8) {
                                    return l10n.passwordTooShortError;
                                  }
                                  return null;
                                },
                              ),
                              _AuthField(
                                controller: _confirmController,
                                label: l10n.confirmPasswordLabel,
                                obscureText: true,
                                last: true,
                                onFieldSubmitted: (_) => _submit(),
                                validator: (value) => value != _passwordController.text
                                    ? l10n.passwordsDoNotMatchError
                                    : null,
                              ),
                            ],
                          ),

                          // ── Error ────────────────────────────────────────
                          if (_submitError != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _submitError!,
                              style: TextStyle(color: scheme.error),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          const SizedBox(height: 20),

                          // ── Submit ───────────────────────────────────────
                          FilledButton(
                            onPressed: _submitting ? null : _submit,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _submitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(l10n.createAccountTitle),
                          ),
                          const SizedBox(height: 20),
                          _OrDivider(label: l10n.orDividerLabel),
                          const SizedBox(height: 20),
                          _GoogleSignInButton(
                            label: l10n.continueWithGoogleButton,
                            onPressed: _submitting ? null : _submitGoogle,
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _submitting
                                ? null
                                : () => Navigator.of(context).maybePop(),
                            child: Text(l10n.signInPromptButton),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared auth widgets (duplicated from login_screen — both files are thin)
// ---------------------------------------------------------------------------

/// "or" divider between the email/password form and the social sign-in
/// button, so the two options read as distinct paths rather than one form.
class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final line = Expanded(
      child: Divider(color: scheme.outlineVariant.withValues(alpha: 0.5)),
    );
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label, style: TextStyle(color: scheme.onSurfaceVariant)),
        ),
        line,
      ],
    );
  }
}

/// "Continue with Google" button, styled per Google's branding guidelines:
/// a neutral (white/surface) outlined button with the official multi-color
/// "G" mark and black/on-surface text — never a custom-colored fill.
class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset('assets/icons/google_logo.svg', width: 20, height: 20),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(children: children),
    );
  }
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.controller,
    required this.label,
    required this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.autofocus = false,
    this.last = false,
    this.helperText,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String> validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool autofocus;
  final bool last;
  final String? helperText;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        TextFormField(
          controller: controller,
          autofocus: autofocus,
          keyboardType: keyboardType,
          obscureText: obscureText,
          onFieldSubmitted: onFieldSubmitted,
          decoration: InputDecoration(
            labelText: label,
            helperText: helperText,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
          validator: validator,
        ),
        if (!last)
          Divider(
            height: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
      ],
    );
  }
}
