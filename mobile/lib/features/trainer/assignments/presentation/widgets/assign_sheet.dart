import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/network/error_message.dart';
import '../../../../../core/theme/app_tokens.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../shared/widgets/ds/lifey_sheet.dart';
import '../../../../../shared/widgets/ds/list_group.dart';
import '../../../clients/application/trainer_clients_controller.dart';
import '../../../clients/domain/trainer_client.dart';
import '../../../shared/client_avatar.dart';
import '../../application/assignable_content.dart';
import '../../application/assignments_controller.dart';
import '../../data/assignments_repository.dart';
import '../../domain/assignment.dart';

/// Hand a template or a recipe to one or more clients (frame E2).
///
/// Content first, then people — because the trainer picks the plan they have
/// in mind and only then decides who needs it, and because the "who already
/// has this" lookup needs the content before it can lock anybody.
class AssignSheet extends ConsumerStatefulWidget {
  const AssignSheet({super.key});

  static Future<BulkAssignmentResult?> show(BuildContext context) {
    return showLifeySheet<BulkAssignmentResult>(
      context: context,
      title: AppLocalizations.of(context)!.trainerAssignButton,
      useRootNavigator: true,
      // The two steps scroll inside a fixed frame, so the sheet does not jump
      // in height when the trainer moves from the content list to the clients.
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: const AssignSheet(),
      ),
    );
  }

  @override
  ConsumerState<AssignSheet> createState() => _AssignSheetState();
}

class _AssignSheetState extends ConsumerState<AssignSheet> {
  final _searchController = TextEditingController();

  AssignableContent? _content;
  final Set<int> _selected = {};

  /// Clients who already hold [_content]; they cannot be selected. Null while
  /// the lookup is still running.
  Set<int>? _alreadyHolding;

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickContent(AssignableContent content) async {
    setState(() {
      _content = content;
      _alreadyHolding = null;
      _error = null;
      _searchController.clear();
    });
    try {
      final holders = await ref
          .read(assignmentsRepositoryProvider)
          .findClientIdsHolding(content.type, content.sourceId);
      if (!mounted) return;
      setState(() {
        _alreadyHolding = holders.toSet();
        // Anyone ticked before the lookup landed who turns out to already
        // hold it drops out, rather than being sent again.
        _selected.removeAll(_alreadyHolding!);
      });
    } catch (error) {
      // Not fatal: without the lookup nobody is locked, and the backend still
      // skips duplicates. Say so rather than blocking the whole flow.
      if (!mounted) return;
      setState(() {
        _alreadyHolding = const {};
        _error = friendlyError(error);
      });
    }
  }

  Future<void> _submit() async {
    final content = _content;
    if (content == null || _selected.isEmpty || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result =
          await ref.read(assignmentsControllerProvider.notifier).assign(
                contentType: content.type,
                sourceId: content.sourceId,
                clientIds: _selected.toList(),
              );
      if (mounted) Navigator.of(context).pop(result);
    } catch (error) {
      // The batch is one transaction, so a failure means nothing was written
      // — the sheet stays exactly as it was and the trainer can try again.
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
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // The sheet's own frame (title, handle, keyboard inset) comes from
    // showLifeySheet; the step's heading, with its way back, is part of this.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (_content != null)
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => setState(() {
                  _content = null;
                  _alreadyHolding = null;
                  _error = null;
                }),
              ),
            Expanded(
              child: Text(
                _content == null
                    ? l10n.trainerAssignPickContentTitle
                    : l10n.trainerAssignPickClientsTitle(_content!.name),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
            ),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s8),
            child: Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
          ),
        const SizedBox(height: AppSpacing.s12),
        Expanded(
          child: _content == null ? _contentStep(l10n) : _clientStep(l10n),
        ),
        if (_content != null) _footer(l10n),
      ],
    );
  }

  // ── Step 1: which content ────────────────────────────────────────────
  Widget _contentStep(AppLocalizations l10n) {
    final all = ref.watch(assignableContentProvider);
    final needle = _searchController.text.trim().toLowerCase();
    final items = needle.isEmpty
        ? all
        : all.where((c) => c.name.toLowerCase().contains(needle)).toList();

    if (all.isEmpty) {
      return Center(
        child: Text(
          l10n.trainerNoAssignableContentMessage,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.palette.text2),
        ),
      );
    }

    return Column(
      children: [
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded, size: 22),
            hintText: l10n.trainerAssignSearchHint,
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        Expanded(
          child: SingleChildScrollView(
            child: ListGroup(
              dividerInset: 72,
              children: [
                for (final item in items)
                  ListRow(
                    leading: ListIconHolder(
                      icon: item.type == AssignableContentType.template
                          ? Icons.fitness_center_rounded
                          : Icons.restaurant_rounded,
                      color: item.type == AssignableContentType.template
                          ? Theme.of(context).colorScheme.primary
                          : context.metricColors.protein,
                      size: 40,
                    ),
                    title: item.name,
                    subtitle: item.type == AssignableContentType.template
                        ? l10n.trainerContentTypeTemplateLabel
                        : l10n.trainerContentTypeRecipeLabel,
                    onTap: () => _pickContent(item),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Step 2: which clients ────────────────────────────────────────────
  Widget _clientStep(AppLocalizations l10n) {
    final clients = ref.watch(trainerClientsControllerProvider).value ?? const [];
    final holding = _alreadyHolding;

    if (holding == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      child: ListGroup(
        dividerInset: 76,
        children: [
          for (final client in clients)
            _clientRow(l10n, client, holding.contains(client.userId)),
        ],
      ),
    );
  }

  Widget _clientRow(AppLocalizations l10n, TrainerClient client, bool alreadyHas) {
    void toggle(bool? checked) => setState(() {
          if (checked ?? false) {
            _selected.add(client.userId);
          } else {
            _selected.remove(client.userId);
          }
        });

    // Locked rather than hidden: the trainer should see that this client is
    // covered, not wonder where they went.
    final locked = alreadyHas || _submitting;
    final checked = alreadyHas || _selected.contains(client.userId);
    return ListRow(
      leading: ClientAvatar(client: client, size: 44),
      title: client.displayName,
      subtitle: alreadyHas ? l10n.trainerAlreadyHasItLabel : null,
      trailing: Checkbox(value: checked, onChanged: locked ? null : toggle),
      onTap: locked ? null : () => toggle(!checked),
    );
  }

  Widget _footer(AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.trainerSelectedClientsCount(_selected.length),
              style: theme.textTheme.bodySmall?.copyWith(color: context.palette.text2),
            ),
          ),
          if (_submitting)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          FilledButton(
            onPressed: _selected.isEmpty || _submitting ? null : _submit,
            child: Text(l10n.trainerAssignButton),
          ),
        ],
      ),
    );
  }
}
