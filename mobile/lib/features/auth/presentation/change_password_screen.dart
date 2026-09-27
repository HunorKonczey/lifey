import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/error_message.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/ds/lifey_header.dart';
import '../application/auth_controller.dart';
import 'widgets/auth_widgets.dart';

/// Change password for the signed-in user, pushed from Settings. Requires
/// connectivity like the rest of auth; on success the backend returns a
/// fresh token pair (see [AuthController.changePassword]) so this device
/// stays signed in even though every other session is revoked.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _submitting = false;
  String? _submitError;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
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
      await ref.read(authControllerProvider.notifier).changePassword(
            currentPassword: _currentController.text,
            newPassword: _newController.text,
          );
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        AppSnackbar.showSuccess(context, title: l10n.passwordChangedSuccessMessage);
        Navigator.of(context).pop();
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

    return Scaffold(
      appBar: LifeySubpageHeader(title: l10n.changePasswordButton),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.s16, AppSpacing.screen, AppSpacing.s24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AuthTextField(
                      controller: _currentController,
                      label: l10n.currentPasswordLabel,
                      icon: Icons.lock_outline_rounded,
                      obscureText: true,
                      autofocus: true,
                      textInputAction: TextInputAction.next,
                      validator: (value) => (value == null || value.isEmpty) ? l10n.requiredFieldError : null,
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    AuthTextField(
                      controller: _newController,
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
                      onFieldSubmitted: (_) => _submit(),
                      validator: (value) => value != _newController.text ? l10n.passwordsDoNotMatchError : null,
                    ),
                    if (_submitError != null) AuthErrorText(_submitError!),
                    const SizedBox(height: AppSpacing.s24),
                    AuthPrimaryButton(
                      label: l10n.changePasswordButton,
                      onPressed: _submitting ? null : _submit,
                      loading: _submitting,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
