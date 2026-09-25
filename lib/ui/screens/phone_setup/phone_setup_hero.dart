import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../kit/kit.dart';

/// A setup screen with room for a drawing (design standard §10, "a hero on
/// the few screens with room"): the drawing at the top, then the state's
/// slots in [KitStateView]'s order — title, one line, progress, what it is
/// made of, the actions in the one hierarchy, and the less common ways.
///
/// Unlike a page [KitStateView] it is anchored to the top, so the first
/// thing on the screen is the drawing and never an empty band (design
/// regressions ledger rows 1–2). It scrolls as one, so it fits at 320 dp and
/// at large text.
class PhoneSetupHero extends StatelessWidget {
  const PhoneSetupHero({
    super.key,
    required this.scene,
    required this.title,
    this.ambient = false,
    this.entranceDuration = KitMotion.entrance,
    this.titleKey,
    this.body,
    this.bodyKey,
    this.bodyTone,
    this.progress,
    this.content,
    this.primary,
    this.secondary,
    this.tertiary = const [],
    this.footer,
    this.liveRegion = true,
  });

  final KitScene scene;

  /// Keep the drawing moving after its entrance: only while the person
  /// waits (setup running, OpenCode starting).
  final bool ambient;

  /// How long the drawing takes to draw itself in: [KitMotion.celebration]
  /// for a finished moment (setup ready), [KitMotion.entrance] otherwise.
  final Duration entranceDuration;

  final String title;
  final Key? titleKey;
  final String? body;
  final Key? bodyKey;

  /// Colours the line when it reports a problem; muted otherwise.
  final AppStatusTone? bodyTone;
  final KitProgress? progress;
  final Widget? content;
  final KitAction? primary;
  final KitAction? secondary;
  final List<KitAction> tertiary;
  final Widget? footer;
  final bool liveRegion;

  /// The drawing's widest size; smaller screens scale it down.
  static const heroWidth = 248.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actions = KitActionBlock(
      primary: primary,
      secondary: secondary,
      tertiary: tertiary,
    );
    final tone = bodyTone;
    final body = this.body;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: KitIllustration(
                    key: const ValueKey('phone-setup-hero-drawing'),
                    scene: scene,
                    width: math.min(heroWidth, constraints.maxWidth - 32),
                    ambient: ambient,
                    entranceDuration: entranceDuration,
                  ),
                ),
                const SizedBox(height: 20),
                Semantics(
                  container: true,
                  liveRegion: liveRegion,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        key: titleKey,
                        style: theme.textTheme.headlineSmall,
                      ),
                      if (body != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          body,
                          key: bodyKey,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: tone == null
                                ? AppTheme.mutedOf(theme)
                                : AppTheme.statusColor(theme, tone),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (progress case final progress?) ...[
                  const SizedBox(height: 20),
                  KitProgressView(progress: progress),
                ],
                if (content case final content?) ...[
                  const SizedBox(height: 16),
                  content,
                ],
                if (!actions.isEmpty) ...[const SizedBox(height: 24), actions],
                if (footer case final footer?) ...[
                  const SizedBox(height: 16),
                  footer,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
