import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/cardio_formatter.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/adaptive_app_bar.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../application/cardio_interval_plan_controller.dart';
import '../domain/cardio_interval_plan.dart';

// ---------------------------------------------------------------------------
// Editor model (mutable; lives only in screen state)
// ---------------------------------------------------------------------------

/// One item of the plan being edited. A section carries [intensity] and
/// [durationSeconds]; a block carries [repeatCount] and [children] and never
/// nests another block — the same one-level shape the backend enforces
/// (docs/cardio/60 C7.2).
class _Item {
  _Item.section({required this.name, required this.intensity, required this.durationSeconds})
      : type = IntervalStepType.step,
        repeatCount = 0,
        children = [];

  _Item.block({required this.repeatCount, required this.children})
      : type = IntervalStepType.repeat,
        name = null,
        intensity = null,
        durationSeconds = 0;

  final IntervalStepType type;
  String? name;
  IntervalIntensity? intensity;
  int durationSeconds;
  int repeatCount;
  List<_Item> children;

  /// Collapsed blocks show as a single summary row — what a long plan looks
  /// like once scrolled (docs/cardio/61 §3 M37).
  bool collapsed = false;

  int get totalSeconds => type == IntervalStepType.step
      ? durationSeconds
      : repeatCount * children.fold(0, (sum, c) => sum + c.totalSeconds);

  int get hardSeconds => type == IntervalStepType.step
      ? (intensity == IntervalIntensity.hard ? durationSeconds : 0)
      : repeatCount * children.fold(0, (sum, c) => sum + c.hardSeconds);

  int get sectionCount => type == IntervalStepType.step
      ? 1
      : repeatCount * children.fold(0, (sum, c) => sum + c.sectionCount);

  /// One pass of the block's children, e.g. the "7:00" in "4 × 7:00 = 28:00".
  int get onePassSeconds => children.fold(0, (sum, c) => sum + c.totalSeconds);

  IntervalStep toStep() {
    if (type == IntervalStepType.repeat) {
      return IntervalStep.block(
        repeatCount: repeatCount,
        children: children.map((c) => c.toStep()).toList(),
      );
    }
    return IntervalStep.section(
      name: name,
      intensity: intensity ?? IntervalIntensity.easy,
      durationSeconds: durationSeconds,
    );
  }

  static _Item fromStep(IntervalStep step) {
    if (step.type == IntervalStepType.repeat) {
      return _Item.block(
        repeatCount: step.repeatCount ?? 1,
        children: step.children.map(_Item.fromStep).toList(),
      );
    }
    return _Item.section(
      name: step.name,
      intensity: step.intensity ?? IntervalIntensity.easy,
      durationSeconds: step.durationSeconds ?? 0,
    );
  }
}

/// What the editor was closed with. [start] is the "Save and start" button —
/// the plan is already saved either way, so the caller only has to decide
/// whether to open the live screen with it (wired in C7.5).
class IntervalPlanEditorResult {
  const IntervalPlanEditorResult({required this.planClientId, required this.start});

  final String planClientId;
  final bool start;
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// The interval plan editor (docs/cardio/61 §3 M37). Sections and repeat
/// blocks in playback order, with the three numbers that define a plan —
/// total length, section count and hard time — live in the header.
class IntervalPlanEditorScreen extends ConsumerStatefulWidget {
  const IntervalPlanEditorScreen({super.key, this.plan});

  /// Non-null when editing an existing plan.
  final CardioIntervalPlan? plan;

  @override
  ConsumerState<IntervalPlanEditorScreen> createState() => _IntervalPlanEditorScreenState();
}

class _IntervalPlanEditorScreenState extends ConsumerState<IntervalPlanEditorScreen> {
  static const _defaultSectionSeconds = 300;
  static const _defaultHardSeconds = 240;
  static const _defaultRestSeconds = 180;
  static const _defaultRepeatCount = 4;

  /// The stepper moves in 15-second steps: fine enough for a 0:30 sprint,
  /// coarse enough that a 5:00 warm-up is a few taps, not twenty.
  static const _durationStep = 15;
  static const _minDurationSeconds = 15;
  static const _maxDurationSeconds = 3600;

  final _name = TextEditingController();
  late final List<_Item> _items;
  bool _saving = false;

  bool get _isEditing => widget.plan != null;

  @override
  void initState() {
    super.initState();
    final plan = widget.plan;
    _name.text = plan?.name ?? '';
    _items = plan?.steps.map(_Item.fromStep).toList() ?? [];
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  // ── Derived numbers (the header, M37) ─────────────────────────────────────

  int get _totalSeconds => _items.fold(0, (sum, i) => sum + i.totalSeconds);

  int get _hardSeconds => _items.fold(0, (sum, i) => sum + i.hardSeconds);

  int get _sectionCount => _items.fold(0, (sum, i) => sum + i.sectionCount);

  // ── Actions ───────────────────────────────────────────────────────────────

  void _addSection() {
    setState(() => _items.add(_Item.section(
          name: null,
          intensity: IntervalIntensity.easy,
          durationSeconds: _defaultSectionSeconds,
        )));
  }

  /// A block arrives ready to run — 4× (4:00 hard + 3:00 easy), the pattern
  /// the whole feature is named after. An empty block would be a form to fill
  /// in; this is a plan to adjust, which is why 4×(4+3) is one tap away.
  void _addRepeatBlock(AppLocalizations l10n) {
    setState(() => _addRepeatBlockTo(_items, l10n));
  }

  /// The empty state's offer: warm-up, the 4×4 block, cool-down — a whole
  /// plan in one tap, because the model is understood from an example rather
  /// than from an explanation (docs/cardio/61 §3 M37).
  void _useStarterPlan(AppLocalizations l10n) {
    setState(() {
      _items
        ..clear()
        ..add(_Item.section(
          name: l10n.intervalWarmUpSectionName,
          intensity: IntervalIntensity.easy,
          durationSeconds: _defaultSectionSeconds,
        ));
      _addRepeatBlockTo(_items, l10n);
      _items.add(_Item.section(
        name: l10n.intervalCoolDownSectionName,
        intensity: IntervalIntensity.easy,
        durationSeconds: _defaultSectionSeconds,
      ));
      if (_name.text.trim().isEmpty) _name.text = l10n.intervalStarterTitle;
    });
  }

  void _addRepeatBlockTo(List<_Item> target, AppLocalizations l10n) {
    target.add(_Item.block(
      repeatCount: _defaultRepeatCount,
      children: [
        _Item.section(
          name: l10n.intervalHardSectionName,
          intensity: IntervalIntensity.hard,
          durationSeconds: _defaultHardSeconds,
        ),
        _Item.section(
          name: l10n.intervalRestSectionName,
          intensity: IntervalIntensity.easy,
          durationSeconds: _defaultRestSeconds,
        ),
      ],
    ));
  }

  Future<void> _editSection(_Item item, {required VoidCallback onRemove}) async {
    final l10n = AppLocalizations.of(context)!;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _SectionEditorSheet(
        durationSeconds: item.durationSeconds,
        intensity: item.intensity ?? IntervalIntensity.easy,
        step: _durationStep,
        minSeconds: _minDurationSeconds,
        maxSeconds: _maxDurationSeconds,
        onChanged: (duration, intensity) {
          setState(() {
            item.durationSeconds = duration;
            item.intensity = intensity;
          });
        },
        onRemove: () {
          Navigator.pop(ctx);
          setState(onRemove);
        },
        l10n: l10n,
      ),
    );
  }

  Future<void> _save({required bool start}) async {
    if (_saving || _items.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;
    final name = _name.text.trim().isEmpty ? l10n.intervalDefaultPlanName : _name.text.trim();
    final steps = _items.map((i) => i.toStep()).toList();

    setState(() => _saving = true);
    try {
      final notifier = ref.read(cardioIntervalPlanControllerProvider.notifier);
      final existingId = _isEditing ? widget.plan!.clientId : null;
      final String savedId;
      if (existingId != null) {
        await notifier.updatePlan(clientId: existingId, name: name, steps: steps);
        savedId = existingId;
      } else {
        savedId = await notifier.createPlan(name: name, steps: steps);
      }
      if (!mounted) return;
      Navigator.of(context)
          .pop(IntervalPlanEditorResult(planClientId: savedId, start: start));
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnackbar.showError(context, title: l10n.couldNotSaveIntervalPlanMessage);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final statusTop = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final contentTop = statusTop + 8.0 + 58.0 + 12.0;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        children: [
          ReorderableListView(
            padding: EdgeInsets.fromLTRB(16, contentTop, 16, bottomPad + 24),
            onReorderItem: (oldIndex, newIndex) {
              setState(() {
                final item = _items.removeAt(oldIndex);
                _items.insert(newIndex, item);
              });
            },
            header: _buildHeader(l10n, scheme),
            footer: _buildFooter(l10n, scheme),
            children: [
              for (var i = 0; i < _items.length; i++)
                Padding(
                  key: ValueKey(_items[i]),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _items[i].type == IntervalStepType.repeat
                      ? _buildBlockCard(_items[i], i, l10n, scheme)
                      : _buildSectionCard(_items[i], l10n, scheme,
                          onRemove: () => _items.removeAt(i), draggableIndex: i),
                ),
            ],
          ),
          Positioned(
            top: statusTop + 8,
            left: 12,
            right: 12,
            child: AdaptiveAppBar(
              title: l10n.intervalPlanTitle,
              onBack: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header: name + the three live numbers ─────────────────────────────────

  Widget _buildHeader(AppLocalizations l10n, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.intervalPlanNameLabel,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          decoration: InputDecoration(
            hintText: l10n.intervalPlanNameHint,
            filled: true,
            fillColor: scheme.surfaceContainerHigh,
            suffixIcon: Icon(Icons.edit_outlined, size: 18, color: scheme.onSurfaceVariant),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // The three numbers that define a plan — the last one most of all
        // (docs/cardio/61 §3 M37).
        Row(
          children: [
            Expanded(
              child: _statTile(
                CardioFormatter.duration(Duration(seconds: _totalSeconds)),
                l10n.intervalTotalLengthLabel,
                scheme,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: _statTile('$_sectionCount', l10n.intervalSectionsLabel, scheme)),
            const SizedBox(width: 8),
            Expanded(
              child: _statTile(
                CardioFormatter.duration(Duration(seconds: _hardSeconds)),
                l10n.intervalHardTimeLabel,
                scheme,
                accent: context.metricColors.carbs,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_items.isEmpty) _buildEmptyState(l10n, scheme),
      ],
    );
  }

  Widget _statTile(String value, String caption, ColorScheme scheme, {Color? accent}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: accent ?? scheme.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            caption,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmptyState(AppLocalizations l10n, ColorScheme scheme) {
    final accent = context.metricColors.carbs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.timeline, size: 26, color: scheme.onSurfaceVariant),
              const SizedBox(height: 10),
              Text(
                l10n.intervalEmptyTitle,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.intervalEmptyBody,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _useStarterPlan(l10n),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: accent.withValues(alpha: 0.28)),
            ),
            child: Row(
              children: [
                Icon(Icons.bolt, size: 18, color: accent),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.intervalStarterTitle,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        l10n.intervalStarterSubtitle,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  // ── Section card ──────────────────────────────────────────────────────────

  Widget _buildSectionCard(
    _Item item,
    AppLocalizations l10n,
    ColorScheme scheme, {
    required VoidCallback onRemove,
    int? draggableIndex,
    bool nested = false,
  }) {
    return Material(
      color: nested ? scheme.surfaceContainerHigh : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(nested ? 14 : 18),
      child: InkWell(
        borderRadius: BorderRadius.circular(nested ? 14 : 18),
        onTap: () => _editSection(item, onRemove: onRemove),
        child: Padding(
          padding: EdgeInsets.fromLTRB(nested ? 12 : 8, 11, 14, 11),
          child: Row(
            children: [
              if (draggableIndex != null)
                ReorderableDragStartListener(
                  index: draggableIndex,
                  child: Icon(Icons.drag_indicator, size: 20, color: scheme.onSurfaceVariant),
                ),
              if (draggableIndex != null) const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name ?? _intensityLabel(item.intensity, l10n),
                      style: TextStyle(
                        fontSize: nested ? 14 : 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    _intensityTag(item.intensity, l10n, scheme),
                  ],
                ),
              ),
              Text(
                CardioFormatter.duration(Duration(seconds: item.durationSeconds)),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The three levels are one amber hue at three saturations, not three
  /// colours — so the list, the editor and the player all speak the same
  /// language (docs/cardio/61 §3 M37).
  Widget _intensityTag(IntervalIntensity? intensity, AppLocalizations l10n, ColorScheme scheme) {
    final accent = context.metricColors.carbs;
    final isHard = intensity == IntervalIntensity.hard;
    final dot = switch (intensity) {
      IntervalIntensity.hard => accent,
      IntervalIntensity.moderate => accent.withValues(alpha: 0.65),
      _ => accent.withValues(alpha: 0.4),
    };
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dot, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 7),
        Text(
          // The RPE hint rides along on the hard level only: it's the one
          // level "hard" alone doesn't pin down (docs/cardio/61 §3 M37).
          isHard ? '${l10n.intervalIntensityHard} · 9–10/10' : _intensityLabel(intensity, l10n),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isHard ? accent : scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  String _intensityLabel(IntervalIntensity? intensity, AppLocalizations l10n) {
    return switch (intensity) {
      IntervalIntensity.hard => l10n.intervalIntensityHard,
      IntervalIntensity.moderate => l10n.intervalIntensityModerate,
      _ => l10n.intervalIntensityEasy,
    };
  }

  // ── Repeat block card ─────────────────────────────────────────────────────

  Widget _buildBlockCard(_Item block, int index, AppLocalizations l10n, ColorScheme scheme) {
    final accent = context.metricColors.carbs;
    if (block.collapsed) {
      return Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => setState(() => block.collapsed = false),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: accent.withValues(alpha: 0.28)),
            ),
            child: Row(
              children: [
                Icon(Icons.repeat, size: 17, color: accent),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _collapsedSummary(block, l10n),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        CardioFormatter.duration(Duration(seconds: block.totalSeconds)),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.expand_more, size: 18, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      padding: const EdgeInsets.fromLTRB(8, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: Icon(Icons.drag_indicator, size: 20, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(width: 4),
              Icon(Icons.repeat, size: 16, color: accent),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  l10n.intervalRepeatBlockLabel,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: accent,
                  ),
                ),
              ),
              // Edit-in-place counter (−/number/+): the repeat count is the
              // one number a user changes most often.
              _counter(block, scheme, accent),
              IconButton(
                onPressed: () => setState(() => block.collapsed = true),
                icon: Icon(Icons.expand_less, size: 18, color: scheme.onSurfaceVariant),
                tooltip: l10n.intervalRepeatBlockLabel,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final child in block.children)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _buildSectionCard(
                child,
                l10n,
                scheme,
                nested: true,
                onRemove: () {
                  block.children.remove(child);
                  if (block.children.isEmpty) _items.remove(block);
                },
              ),
            ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Where the user checks that they got what they meant to build.
              Text(
                '${block.repeatCount} × ${CardioFormatter.duration(Duration(seconds: block.onePassSeconds))}'
                ' = ${CardioFormatter.duration(Duration(seconds: block.totalSeconds))}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _items.remove(block)),
                child: Text(
                  l10n.intervalRemoveBlockButton,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _counter(_Item block, ColorScheme scheme, Color accent) {
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _counterButton(
            Icons.remove,
            scheme,
            onTap: block.repeatCount > 1
                ? () => setState(() => block.repeatCount -= 1)
                : null,
          ),
          Text(
            '×${block.repeatCount}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: accent,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          _counterButton(
            Icons.add,
            scheme,
            // 99 is the backend's ceiling (V70's check constraint).
            onTap: block.repeatCount < 99
                ? () => setState(() => block.repeatCount += 1)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _counterButton(IconData icon, ColorScheme scheme, {VoidCallback? onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Icon(
          icon,
          size: 16,
          color: onTap == null ? scheme.onSurfaceVariant.withValues(alpha: 0.4) : scheme.onSurface,
        ),
      ),
    );
  }

  String _collapsedSummary(_Item block, AppLocalizations l10n) {
    final parts = block.children
        .map((c) =>
            '${CardioFormatter.duration(Duration(seconds: c.durationSeconds))} ${_intensityLabel(c.intensity, l10n)}')
        .join(' + ');
    return '${block.repeatCount}× ($parts)';
  }

  // ── Footer: add buttons + save ────────────────────────────────────────────

  Widget _buildFooter(AppLocalizations l10n, ColorScheme scheme) {
    final canSave = _items.isNotEmpty && !_saving;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        children: [
          Row(
            children: [
              // Both add buttons are the same size: a repeat block isn't an
              // "advanced" feature, it's the normal way to build a plan.
              Expanded(
                child: _addButton(
                  icon: Icons.add,
                  label: l10n.intervalAddSectionButton,
                  scheme: scheme,
                  onTap: _addSection,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _addButton(
                  icon: Icons.repeat,
                  label: l10n.intervalAddRepeatButton,
                  scheme: scheme,
                  onTap: () => _addRepeatBlock(l10n),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: canSave ? () => _save(start: true) : null,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save, size: 18),
              label: Text(l10n.intervalSaveAndStartButton),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: canSave ? () => _save(start: false) : null,
            child: Text(l10n.intervalSaveOnlyButton),
          ),
        ],
      ),
    );
  }

  Widget _addButton({
    required IconData icon,
    required String label,
    required ColorScheme scheme,
    required VoidCallback onTap,
  }) {
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section editor sheet
// ---------------------------------------------------------------------------

class _SectionEditorSheet extends StatefulWidget {
  const _SectionEditorSheet({
    required this.durationSeconds,
    required this.intensity,
    required this.step,
    required this.minSeconds,
    required this.maxSeconds,
    required this.onChanged,
    required this.onRemove,
    required this.l10n,
  });

  final int durationSeconds;
  final IntervalIntensity intensity;
  final int step;
  final int minSeconds;
  final int maxSeconds;
  final void Function(int durationSeconds, IntervalIntensity intensity) onChanged;
  final VoidCallback onRemove;
  final AppLocalizations l10n;

  @override
  State<_SectionEditorSheet> createState() => _SectionEditorSheetState();
}

class _SectionEditorSheetState extends State<_SectionEditorSheet> {
  late int _duration = widget.durationSeconds;
  late IntervalIntensity _intensity = widget.intensity;

  void _apply() => widget.onChanged(_duration, _intensity);

  String _label(IntervalIntensity intensity) => switch (intensity) {
        IntervalIntensity.hard => widget.l10n.intervalIntensityHard,
        IntervalIntensity.moderate => widget.l10n.intervalIntensityModerate,
        IntervalIntensity.easy => widget.l10n.intervalIntensityEasy,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = context.metricColors.carbs;
    final l10n = widget.l10n;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.intervalSectionEditorTitle(_label(_intensity)),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            Text(
              l10n.intervalDurationLabel,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _stepperButton(Icons.remove, scheme, onTap: () {
                  if (_duration - widget.step < widget.minSeconds) return;
                  setState(() => _duration -= widget.step);
                  _apply();
                }),
                Text(
                  CardioFormatter.duration(Duration(seconds: _duration)),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                _stepperButton(Icons.add, scheme, onTap: () {
                  if (_duration + widget.step > widget.maxSeconds) return;
                  setState(() => _duration += widget.step);
                  _apply();
                }),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              l10n.intervalTargetIntensityLabel,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final level in IntervalIntensity.values) ...[
                  Expanded(child: _intensityOption(level, scheme, accent)),
                  if (level != IntervalIntensity.values.last) const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 14),
            Text(
              l10n.intervalResistanceNote,
              style: TextStyle(
                fontSize: 10.5,
                height: 1.5,
                fontWeight: FontWeight.w500,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: widget.onRemove,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: Text(l10n.intervalRemoveSectionButton),
                style: TextButton.styleFrom(foregroundColor: scheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepperButton(IconData icon, ColorScheme scheme, {required VoidCallback onTap}) {
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Icon(icon, size: 20, color: scheme.onSurface),
        ),
      ),
    );
  }

  Widget _intensityOption(IntervalIntensity level, ColorScheme scheme, Color accent) {
    final selected = _intensity == level;
    final fill = switch (level) {
      IntervalIntensity.hard => accent,
      IntervalIntensity.moderate => accent.withValues(alpha: 0.65),
      IntervalIntensity.easy => accent.withValues(alpha: 0.35),
    };
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        setState(() => _intensity = level);
        _apply();
      },
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: selected && level == IntervalIntensity.hard
              ? accent
              : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: selected
              ? Border.all(color: accent, width: 2)
              : Border.all(color: Colors.transparent, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 22,
              height: 6,
              decoration: BoxDecoration(
                color: selected && level == IntervalIntensity.hard ? scheme.surface : fill,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _label(level),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                color: selected && level == IntervalIntensity.hard
                    ? scheme.surface
                    : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
