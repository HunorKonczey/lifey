import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ds/lifey_header.dart';

/// The page of every signed-out screen (canvas Lifey 5 › 6 "Login"; docs/
/// redesign/77-mobile-redesign-plan.md R5.1): a scrolling column with the
/// 20 dp gutter of the rest of the app, at most 400 dp wide on a tablet, and an
/// optional [bottom] prompt ("New to Lifey? Create account") that sits at the
/// foot of the screen when there is room and scrolls with the form — never
/// under the keyboard — when there isn't.
///
/// Screens reached from the login form ([showBack]) carry the round back
/// button of the subpage header above their heading.
class AuthPage extends StatelessWidget {
  const AuthPage({super.key, required this.children, this.bottom, this.showBack = false});

  final List<Widget> children;
  final Widget? bottom;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (showBack)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.s8, AppSpacing.screen, 0),
                  child: HeaderIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: CustomScrollView(
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            AppSpacing.screen,
                            showBack ? AppSpacing.s24 : AppSpacing.s56,
                            AppSpacing.screen,
                            AppSpacing.s24,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ...children,
                              if (bottom != null) ...[
                                const Spacer(),
                                const SizedBox(height: AppSpacing.s24),
                                bottom!,
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
          ],
        ),
      ),
    );
  }
}

/// A filled field on the page with its label above it and a leading icon
/// (canvas login: 56 dp, card fill, hairline, primary ring when focused).
class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    required this.validator,
    this.keyboardType,
    this.autofillHints,
    this.obscureText = false,
    this.autofocus = false,
    this.helperText,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final FormFieldValidator<String> validator;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final bool autofocus;
  final String? helperText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final ring = OutlineInputBorder(
      borderRadius: AppRadius.controlAll,
      borderSide: BorderSide(color: context.elevation.border),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.s8, bottom: AppSpacing.s8),
          child: Text(label, style: t.labelMedium!.copyWith(color: p.text2)),
        ),
        TextFormField(
          controller: controller,
          autofocus: autofocus,
          keyboardType: keyboardType,
          autofillHints: autofillHints,
          obscureText: obscureText,
          textInputAction: textInputAction,
          onFieldSubmitted: onFieldSubmitted,
          style: t.bodyLarge!.copyWith(color: p.text),
          decoration: InputDecoration(
            hintText: label,
            helperText: helperText,
            helperMaxLines: 2,
            prefixIcon: Icon(icon, size: 22),
            fillColor: p.card,
            constraints: const BoxConstraints(minHeight: 56),
            border: ring,
            enabledBorder: ring,
          ),
          validator: validator,
        ),
      ],
    );
  }
}

/// The primary action: full width, 56 dp, a spinner while working. Always the
/// filled button — the alternatives on the page are quieter.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({super.key, required this.label, required this.onPressed, this.loading = false});

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: FilledButton(
        onPressed: onPressed,
        child: loading
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(label),
      ),
    );
  }
}

/// A failed attempt, in the error colour, under the fields.
class AuthErrorText extends StatelessWidget {
  const AuthErrorText(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.s16),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.error),
        ),
      );
}

/// "or" between the email form and the social sign-in, so the two read as two
/// paths and not one form.
class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final line = Expanded(child: Divider(height: 1, color: p.hairline));
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
          child: Text(
            AppLocalizations.of(context)!.orDividerLabel,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: p.text2),
          ),
        ),
        line,
      ],
    );
  }
}

/// "Continue with Google": the secondary, outlined button, with Google's own
/// multi-colour "G" — its branding guidelines ask for the mark, so it stays
/// although the canvas draws the label alone.
class AuthGoogleButton extends StatelessWidget {
  const AuthGoogleButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: p.control,
          foregroundColor: p.text,
          side: BorderSide(color: context.elevation.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset('assets/icons/google_logo.svg', width: 20, height: 20),
            const SizedBox(width: AppSpacing.s12),
            Flexible(
              child: Text(AppLocalizations.of(context)!.continueWithGoogleButton, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

/// "New to Lifey? Create account" — a grey lead-in and the action in the
/// accent colour, one 48 dp tap target.
class AuthSwitchPrompt extends StatelessWidget {
  const AuthSwitchPrompt({super.key, required this.lead, required this.action, required this.onPressed});

  final String lead;
  final String action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return Center(
      child: TextButton(
        onPressed: onPressed,
        child: Text.rich(
          TextSpan(
            text: '$lead ',
            style: t.bodyLarge!.copyWith(fontWeight: FontWeight.w500, color: p.text2),
            children: [
              TextSpan(
                text: action,
                style: t.bodyLarge!.copyWith(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
