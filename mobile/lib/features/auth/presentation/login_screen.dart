import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/error_message.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../application/auth_controller.dart';

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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                 child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Logo ───────────────────────────────────────────────
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.bar_chart_rounded,
                          size: 38,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        'Lifey',
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        l10n.signInSubtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Fields card ────────────────────────────────────────
                    _AuthCard(
                      children: [
                        _AuthField(
                          controller: _emailController,
                          label: l10n.emailLabel,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          autofocus: true,
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
                          autofillHints: const [AutofillHints.password],
                          last: true,
                          onFieldSubmitted: (_) => _submit(),
                          validator: (value) => (value == null || value.isEmpty)
                              ? l10n.requiredFieldError
                              : null,
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _submitting ? null : () => context.push('/forgot-password'),
                        child: Text(l10n.forgotPasswordButton),
                      ),
                    ),

                    // ── Error ──────────────────────────────────────────────
                    if (_submitError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _submitError!,
                        style: TextStyle(color: scheme.error),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 20),

                    // ── Submit ─────────────────────────────────────────────
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
                          : Text(l10n.signInButton),
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
                      onPressed: _submitting ? null : () => context.push('/register'),
                      child: Text(l10n.registerPromptButton),
                    ),
                  ],
                 ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared auth widgets
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
    this.autofillHints,
    this.obscureText = false,
    this.autofocus = false,
    this.last = false,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String> validator;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final bool autofocus;
  final bool last;
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
          autofillHints: autofillHints,
          obscureText: obscureText,
          onFieldSubmitted: onFieldSubmitted,
          decoration: InputDecoration(
            labelText: label,
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
