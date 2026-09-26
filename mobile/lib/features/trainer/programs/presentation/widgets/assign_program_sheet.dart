import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/network/error_message.dart';
import '../../../../../core/theme/app_tokens.dart';
import '../../../../../core/format/lifey_format.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../shared/widgets/ds/lifey_card.dart';
import '../../../../../shared/widgets/ds/lifey_sheet.dart';
import '../../../../../shared/widgets/ds/list_group.dart';
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
    return showLifeySheet<ProgramAssignmentResult>(
      context: context,
      title: AppLocalizations.of(context)!.trainerAssignProgramTitle(programName),
      useRootNavigator: true,
      builder: (context) => SizedBox(
        // The client list scrolls inside a fixed frame, so the sheet does not
        // change height as the trainer picks.
        height: MediaQuery.sizeOf(context).height * 0.6,
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
    final p = context.palette;
    final l10n = AppLocalizations.of(context)!;
    final f = LifeyFormat.of(context);
    final clients = ref.watch(trainerClientsControllerProvider).value ?? const [];
    final endDate = programEndDate(_startDate, widget.weeksCount);

    // The sheet's own frame (title, handle, keyboard inset) comes from
    // showLifeySheet; this is only what goes in it.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: clients.isEmpty
              ? Center(
                  child: Text(
                    l10n.trainerClientsEmptyTitle,
                    style: theme.textTheme.bodyMedium?.copyWith(color: p.text2),
                  ),
                )
              : SingleChildScrollView(
                  child: ListGroup(
                    dividerInset: 76,
                    children: [
                      for (final client in clients)
                        // A plain selectable row rather than a radio: one
                        // client at a time is the endpoint's shape, and the
                        // tick says which one without a second control.
                        ListRow(
                          leading: ClientAvatar(client: client, size: 44),
                          title: client.displayName,
                          trailing: _clientId == client.userId
                              ? Icon(Icons.check_circle_rounded, color: scheme.primary)
                              : null,
                          onTap: _submitting ? null : () => setState(() => _clientId = client.userId),
                        ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: AppSpacing.s12),
        ListGroup(
          dividerInset: 72,
          children: [
            ListRow(
              leading: ListIconHolder(icon: Icons.event_rounded, color: scheme.primary, size: 40),
              title: l10n.trainerProgramStartsLabel,
              subtitle: f.fullDate(_startDate),
              trailing: Icon(Icons.chevron_right_rounded, size: 20, color: p.text3),
              onTap: _submitting ? null : _pickStart,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s12),
        LifeyCard.nested(
          padding: const EdgeInsets.all(AppSpacing.s12),
          child: Row(
            children: [
              Icon(Icons.event_available_rounded, size: 18, color: scheme.primary),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Text(
                  l10n.trainerProgramRunSummary(
                    f.fullDate(_startDate),
                    f.fullDate(endDate),
                    widget.weeksCount,
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: p.text),
                ),
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s12),
            child: Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: scheme.error)),
          ),
        const SizedBox(height: AppSpacing.s16),
        Row(
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
              child: SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: _canSubmit ? _submit : null,
                  child: Text(l10n.trainerStartProgramButton),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
