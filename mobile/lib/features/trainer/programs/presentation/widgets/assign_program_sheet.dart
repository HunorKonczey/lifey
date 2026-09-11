import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/network/error_message.dart';
import '../../../../../core/theme/app_tokens.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../clients/application/trainer_clients_controller.dart';
import '../../../shared/client_avatar.dart';
import '../../application/programs_controller.dart';
import '../../domain/program.dart';
import '../../domain/program_dates.dart';

/// Start a client on a program (frame G3).
///
/// The most common thing a trainer does in this whole block, so it is one
/// sheet: who, from which Monday, and a sentence saying what that means.
///
/// One client at a time, because the endpoint takes one. A multi-select would
/// be several independent requests with real partial failure behind it —
/// unlike content assignment, there is no batch transaction to stand on.
class AssignProgramSheet extends ConsumerStatefulWidget {
  const AssignProgramSheet({
    super.key,
    required this.programId,
    required this.programName,
    required this.weeksCount,
  });

  final int programId;
  final String programName;
  final int weeksCount;

  static Future<ProgramAssignmentResult?> show(
    BuildContext context, {
    required int programId,
    required String programName,
    required int weeksCount,
  }) {
    return showModalBottomSheet<ProgramAssignmentResult>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: AssignProgramSheet(
          programId: programId,
          programName: programName,
          weeksCount: weeksCount,
        ),
      ),
    );
  }

  @override
  ConsumerState<AssignProgramSheet> createState() => _AssignProgramSheetState();
}

class _AssignProgramSheetState extends ConsumerState<AssignProgramSheet> {
  int? _clientId;

  /// Weeks are Monday-anchored, so the run can only begin on one. The default
  /// is the next available Monday rather than today, which is usually not one.
  late DateTime _startDate = nextOrSameMonday(DateTime.now());

  bool _submitting = false;
  String? _error;

  bool get _canSubmit =>
      _clientId != null &&
      isValidProgramStartDate(_startDate) &&
      !_submitting;

  Future<void> _pickStart() async {
    final firstMonday = nextOrSameMonday(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: firstMonday,
      lastDate: firstMonday.add(const Duration(days: 365)),
      // Only Mondays are selectable, so the rule is visible in the picker
      // instead of arriving as a rejected request.
      selectableDayPredicate: (day) => day.weekday == DateTime.monday,
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await ref.read(assignProgramProvider)(
        programId: widget.programId,
        clientId: _clientId!,
        startDate: _startDate,
      );
      if (mounted) Navigator.of(context).pop(result);
    } catch (error) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = friendlyError(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final dateFormat = DateFormat.yMMMd(locale);
    final clients = ref.watch(trainerClientsControllerProvider).value ?? const [];
    final endDate = programEndDate(_startDate, widget.weeksCount);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.trainerAssignProgramTitle(widget.programName),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: clients.isEmpty
                ? Center(
                    child: Text(
                      l10n.trainerClientsEmptyTitle,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  )
                : ListView(
                    children: [
                      for (final client in clients)
                        // A plain selectable row rather than a radio: one
                        // client at a time is the endpoint's shape, and the
                        // tick says which one without a second control.
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          selected: _clientId == client.userId,
                          leading: ClientAvatar(client: client, size: 36),
                          title: Text(client.displayName),
                          trailing: _clientId == client.userId
                              ? Icon(Icons.check_circle, color: scheme.tertiary)
                              : null,
                          onTap: _submitting
                              ? null
                              : () => setState(() => _clientId = client.userId),
                        ),
                    ],
                  ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.event, color: scheme.onSurfaceVariant),
            title: Text(l10n.trainerProgramStartsLabel,
                style: theme.textTheme.bodySmall),
            subtitle: Text(
              dateFormat.format(_startDate),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            onTap: _submitting ? null : _pickStart,
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: AppRadius.mdAll,
            ),
            child: Row(
              children: [
                Icon(Icons.event_available, size: 18, color: scheme.tertiary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.trainerProgramRunSummary(
                      dateFormat.format(_startDate),
                      dateFormat.format(endDate),
                      widget.weeksCount,
                    ),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
              ),
            ),
          Padding(
            padding: EdgeInsets.only(
              top: 12,
              bottom: MediaQuery.paddingOf(context).bottom + 12,
            ),
            child: Row(
              children: [
                if (_submitting)
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                Expanded(
                  child: FilledButton(
                    onPressed: _canSubmit ? _submit : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.tertiary,
                      foregroundColor: scheme.onTertiary,
                    ),
                    child: Text(l10n.trainerStartProgramButton),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
