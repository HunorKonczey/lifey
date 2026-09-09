import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/network/error_message.dart';
import '../../../../../core/theme/app_tokens.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../clients/application/trainer_clients_controller.dart';
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
    return showModalBottomSheet<BulkAssignmentResult>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (_content != null)
                IconButton(
                  icon: const Icon(Icons.arrow_back),
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
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ),
          const SizedBox(height: 10),
          Expanded(
            child: _content == null ? _contentStep(l10n) : _clientStep(l10n),
          ),
          if (_content != null) _footer(l10n),
        ],
      ),
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
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }

    return Column(
      children: [
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: l10n.trainerAssignSearchHint,
            isDense: true,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  item.type == AssignableContentType.template
                      ? Icons.fitness_center
                      : Icons.restaurant,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
                title: Text(item.name),
                subtitle: Text(
                  item.type == AssignableContentType.template
                      ? l10n.trainerContentTypeTemplateLabel
                      : l10n.trainerContentTypeRecipeLabel,
                ),
                onTap: () => _pickContent(item),
              );
            },
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

    return ListView.builder(
      itemCount: clients.length,
      itemBuilder: (context, index) {
        final client = clients[index];
        final alreadyHas = holding.contains(client.userId);
        return CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: alreadyHas || _selected.contains(client.userId),
          // Locked rather than hidden: the trainer should see that this
          // client is covered, not wonder where they went.
          onChanged: alreadyHas || _submitting
              ? null
              : (checked) => setState(() {
                    if (checked ?? false) {
                      _selected.add(client.userId);
                    } else {
                      _selected.remove(client.userId);
                    }
                  }),
          secondary: ClientAvatar(client: client, size: 36),
          title: Text(client.displayName),
          subtitle: alreadyHas ? Text(l10n.trainerAlreadyHasItLabel) : null,
        );
      },
    );
  }

  Widget _footer(AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        top: 8,
        bottom: MediaQuery.paddingOf(context).bottom + 12,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.trainerSelectedClientsCount(_selected.length),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.tertiary,
              foregroundColor: theme.colorScheme.onTertiary,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(AppRadius.input)),
              ),
            ),
            child: Text(l10n.trainerAssignButton),
          ),
        ],
      ),
    );
  }
}
