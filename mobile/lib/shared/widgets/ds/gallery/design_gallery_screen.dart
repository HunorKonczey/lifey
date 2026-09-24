import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_tokens.dart';
import 'component_sections.dart';
import 'foundation_sections.dart';
import 'gallery_section.dart';

/// Every gallery section, in canvas order. Each redesign step that adds a
/// component appends its sections here (docs/redesign/77-mobile-redesign-plan.md
/// R0.6).
List<GallerySection> get gallerySections => [
      ...foundationSections,
      ...componentSections,
    ];

/// Debug-only design gallery (route `/debug/design`, registered only under
/// `kDebugMode`): renders every design-system token and component so it can
/// be held side by side against the canvases in `docs/redesign/`.
///
/// The toolbar switches the preview — not the app — between dark and light,
/// English and Hungarian, text scale 1.0 and 1.3, and reduced motion: the
/// matrix every redesign step is verified in.
class DesignGalleryScreen extends StatefulWidget {
  const DesignGalleryScreen({super.key, this.sections});

  /// Overrides [gallerySections]; for tests.
  final List<GallerySection>? sections;

  static const String routePath = '/debug/design';

  @override
  State<DesignGalleryScreen> createState() => _DesignGalleryScreenState();
}

class _DesignGalleryScreenState extends State<DesignGalleryScreen> {
  late Brightness _brightness = Theme.of(context).brightness;
  String _language = 'en';
  double _textScale = 1;
  bool _reducedMotion = false;

  late final List<GallerySection> _sections = widget.sections ?? gallerySections;
  late final List<GlobalKey> _keys = [for (final _ in _sections) GlobalKey()];

  void _jumpTo(int index) {
    final target = _keys[index].currentContext;
    if (target != null) {
      Scrollable.ensureVisible(target, duration: AppMotion.page, curve: AppMotion.standard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewTheme = _brightness == Brightness.dark ? AppTheme.dark : AppTheme.light;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Design gallery'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(104),
          child: Column(children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                _Toggle(
                  key: const ValueKey('gallery-theme'),
                  label: _brightness == Brightness.dark ? 'Dark' : 'Light',
                  icon: _brightness == Brightness.dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  onTap: () => setState(() => _brightness =
                      _brightness == Brightness.dark ? Brightness.light : Brightness.dark),
                ),
                _Toggle(
                  key: const ValueKey('gallery-language'),
                  label: _language.toUpperCase(),
                  icon: Icons.translate_rounded,
                  onTap: () => setState(() => _language = _language == 'en' ? 'hu' : 'en'),
                ),
                _Toggle(
                  key: const ValueKey('gallery-textScale'),
                  label: 'Text ${(_textScale * 100).round()} %',
                  icon: Icons.format_size_rounded,
                  onTap: () => setState(() => _textScale = _textScale == 1 ? 1.3 : 1),
                ),
                _Toggle(
                  key: const ValueKey('gallery-motion'),
                  label: _reducedMotion ? 'Motion off' : 'Motion on',
                  icon: _reducedMotion ? Icons.motion_photos_off_rounded : Icons.animation_rounded,
                  onTap: () => setState(() => _reducedMotion = !_reducedMotion),
                ),
              ]),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(children: [
                for (var i = 0; i < _sections.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(label: Text(_sections[i].title), onPressed: () => _jumpTo(i)),
                  ),
              ]),
            ),
          ]),
        ),
      ),
      body: Theme(
        data: previewTheme,
        child: Localizations.override(
          context: context,
          locale: Locale(_language),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(_textScale),
              disableAnimations: _reducedMotion,
            ),
            child: Builder(
              builder: (context) => ColoredBox(
                color: context.palette.bg,
                child: DefaultTextStyle(
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: context.palette.text),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.s56,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < _sections.length; i++)
                          Column(
                            key: _keys[i],
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              GalleryHeading(_sections[i]),
                              Builder(builder: _sections[i].builder),
                            ],
                          ),
                      ],
                    ),
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

class _Toggle extends StatelessWidget {
  const _Toggle({super.key, required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilledButton.tonalIcon(onPressed: onTap, icon: Icon(icon, size: 18), label: Text(label)),
      );
}
