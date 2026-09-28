// Gallery (gate G4) for KitGlass, docs/ux-system/kit-api/KitGlass.md: the
// floating navigation layer in fluid glass (the owner's approved "Fluid
// glass" sample; visual language §6, design standard §10).
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_glass_golden_test.dart
// and look at every changed image before committing it.
//
// - The shell (top controls, content, dock / rail / sidebar) at the five
//   §8.4 window sizes, light and dark, and at 412x915 and 1280x800 with 2.0
//   text: the glass reads on the Graphite default in both themes.
// - Motion samples at 412x915, frozen mid-motion: the lens stretching
//   towards a tab, the lens lifted under a dragging finger, the server pill
//   pressed, search joining the pill as the page scrolls, joined, and a
//   glass surface flowing taller. Plus glass off (the solid fallback).
//
// flutter_tester runs Skia, so these are the frosted look; the liquid look
// (Impeller) is rendered by tool/capture/fluid_glass_test.dart into
// docs/qa/kit-fluid-glass-2026-09-28/renders/.
//
// The stand-in content is kept out of semantics: it scrolls beneath the
// glass on purpose, and G5 would read a row behind the dock as text on
// glass (the nav gallery's reasoning; the scene, not the part).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/theme_packs.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_gallery.dart';

List<KitNavDestination> _destinations() => const [
  KitNavDestination(
    label: 'Work',
    icon: AppIconography.workspace,
    selectedIcon: AppIconography.workspaceSelected,
    key: ValueKey('nav-work'),
  ),
  KitNavDestination(
    label: 'Inbox',
    icon: AppIconography.activity,
    selectedIcon: AppIconography.activitySelected,
    needsYou: 1,
    key: ValueKey('nav-inbox'),
  ),
  KitNavDestination(
    label: 'Project',
    icon: AppIconography.files,
    selectedIcon: AppIconography.filesSelected,
    key: ValueKey('nav-project'),
  ),
  KitNavDestination(
    label: 'Settings',
    icon: AppIconography.settings,
    key: ValueKey('nav-settings'),
  ),
];

/// Rows with colour in them, so the glass has something to bend.
class _Content extends StatelessWidget {
  const _Content();

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final roles = tokens.roles;
    final marks = [roles.accent, roles.success, roles.attention, roles.danger];
    return ExcludeSemantics(
      child: ListView.builder(
        key: const ValueKey('content'),
        padding: EdgeInsets.fromLTRB(
          tokens.gutter,
          tokens.space2,
          tokens.gutter,
          MediaQuery.paddingOf(context).bottom + tokens.gutter,
        ),
        itemCount: 40,
        itemBuilder: (context, i) => Padding(
          padding: EdgeInsets.symmetric(vertical: tokens.space2),
          child: Row(
            children: [
              DecoratedBox(
                decoration: ShapeDecoration(
                  color: marks[i % marks.length],
                  shape: const StadiumBorder(),
                ),
                child: SizedBox(width: tokens.space3, height: tokens.minTarget),
              ),
              SizedBox(width: tokens.space3),
              Expanded(
                child: KitText(
                  'Conversation ${i + 1}: fix the reconnect loop',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The shell: KitNav around the top controls and the content; the sidebar
/// holds the controls on a wide window.
class _Shell extends StatefulWidget {
  const _Shell();

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  var _selected = 0;

  @override
  Widget build(BuildContext context) {
    final layout = KitNav.layoutOf(context);
    final sidebar = layout == KitNavLayout.sidebar;
    return KitNav(
      destinations: _destinations(),
      selected: _selected,
      onSelected: (i) => setState(() => _selected = i),
      sidebarHeader: KitShellControls(
        layout: KitShellControlsLayout.sidebar,
        server: 'Laptop',
        serverStatus: 'Connected',
        serverTone: AppStatusTone.ok,
        onServer: () {},
        project: 'shopfront',
        onProject: () {},
        onSearch: () {},
      ),
      sidebarPrimary: KitAction(
        label: 'New conversation',
        onPressed: () {},
        shortcut: 'Ctrl N',
      ),
      child: sidebar
          ? const _Content()
          : _railContent(
              layout,
              Column(
                children: [
                  SafeArea(
                    bottom: false,
                    child: KitTopBar.shell(
                      controls: KitShellControls(
                        server: 'Laptop',
                        serverStatus: 'Connected',
                        serverTone: AppStatusTone.ok,
                        onServer: () {},
                        onSearch: () {},
                      ),
                    ),
                  ),
                  const Expanded(child: _Content()),
                ],
              ),
            ),
    );
  }
}

/// Beside the rail, the stand-in page is kept out of semantics: KitNav
/// reads navigation before content (A11Y-4), and G5's reading-order check,
/// which compares consecutive leaves only, reads the jump from the rail's
/// last destination up to the top controls as "goes back up" (the nav
/// gallery's reasoning; the harness is not a kit unit's to change).
Widget _railContent(KitNavLayout layout, Widget child) =>
    layout == KitNavLayout.rail ? ExcludeSemantics(child: child) : child;

/// A glass surface that grows a line per tap (a composer-like flow).
class _Flow extends StatefulWidget {
  const _Flow();

  @override
  State<_Flow> createState() => _FlowState();
}

class _FlowState extends State<_Flow> {
  var _lines = 1;

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    return Stack(
      children: [
        const Positioned.fill(child: _Content()),
        Positioned(
          left: tokens.gutter,
          right: tokens.gutter,
          top: MediaQuery.paddingOf(context).top + tokens.gutter,
          child: KitButton(
            role: KitButtonRole.secondary,
            label: 'Add a line',
            onPressed: () => setState(() => _lines++),
          ),
        ),
        Positioned(
          left: tokens.gutter,
          right: tokens.gutter,
          bottom: MediaQuery.paddingOf(context).bottom + tokens.gutter,
          child: KitGlass(
            flow: true,
            borderRadius: BorderRadius.circular(tokens.composerRadius),
            child: Padding(
              padding: EdgeInsets.all(tokens.space3),
              child: KitText(
                List.filled(
                  _lines,
                  'Add a retry to the checkout test and run it twice.',
                ).join('\n'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Widget _scene(Widget child, {KitEffects effects = KitEffects.defaults}) =>
    KitEffectsScope(
      effects: effects,
      // The gallery harness turns animations off, which also makes glass
      // solid; these scenes turn them back on so the glass shows its
      // material and moves.
      child: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: false),
          child: Material(
            color: KitTokens.of(context).roles.ground,
            child: child,
          ),
        ),
      ),
    );

Future<void> _open(BuildContext context, Widget scene) =>
    Navigator.of(context).push(KitPageRoute<void>(builder: (_) => scene));

void main() {
  setUpAll(loadKitGalleryFonts);
  tearDown(KitGlassShader.debugReset);

  const phone = Size(412, 915);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    for (final size in kitGallerySizes) {
      testWidgets('shell ${kitGallerySize(size)} ($mode)', (tester) async {
        await kitGalleryShot(
          tester,
          name: kitGalleryName('kit_glass_shell', size, light: light),
          size: size,
          light: light,
          open: (context) => _open(context, _scene(const _Shell())),
        );
      });
    }

    for (final size in kitGalleryScaledSizes) {
      testWidgets('shell text 2.0 ${kitGallerySize(size)} ($mode)', (
        tester,
      ) async {
        await kitGalleryShot(
          tester,
          name: kitGalleryName(
            'kit_glass_shell',
            size,
            light: light,
            text2: true,
          ),
          size: size,
          light: light,
          textScale: 2,
          open: (context) => _open(context, _scene(const _Shell())),
        );
      });
    }

    testWidgets('lens stretching towards a tab ($mode)', (tester) async {
      await kitGalleryShot(
        tester,
        name: kitGalleryName('kit_glass_lens_stretch', phone, light: light),
        size: phone,
        light: light,
        open: (context) => _open(context, _scene(const _Shell())),
        then: (tester) async {
          await tester.tap(find.byKey(const ValueKey('nav-settings')));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));
        },
        settleAfterThen: false,
      );
    });

    testWidgets('lens lifted under a dragging finger ($mode)', (tester) async {
      await kitGalleryShot(
        tester,
        name: kitGalleryName('kit_glass_lens_lift', phone, light: light),
        size: phone,
        light: light,
        open: (context) => _open(context, _scene(const _Shell())),
        then: (tester) async {
          final from = tester.getCenter(find.byKey(const ValueKey('nav-work')));
          final to = tester.getCenter(find.byKey(const ValueKey('nav-inbox')));
          final gesture = await tester.startGesture(from);
          await gesture.moveBy(const Offset(20, 0));
          await tester.pump();
          for (var i = 0; i < 6; i++) {
            await gesture.moveBy(Offset((to.dx - from.dx) * .8 / 6, 0));
            await tester.pump(const Duration(milliseconds: 16));
          }
          await tester.pump(const Duration(milliseconds: 120));
          addTearDown(gesture.up);
        },
        settleAfterThen: false,
      );
    });

    testWidgets('server pill pressed ($mode)', (tester) async {
      await kitGalleryShot(
        tester,
        name: kitGalleryName('kit_glass_pressed', phone, light: light),
        size: phone,
        light: light,
        open: (context) => _open(context, _scene(const _Shell())),
        then: (tester) async {
          final gesture = await tester.startGesture(
            tester.getCenter(find.textContaining('Laptop', findRichText: true)),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 90));
          addTearDown(gesture.up);
        },
        settleAfterThen: false,
      );
    });

    testWidgets('search joining the pill as the page scrolls ($mode)', (
      tester,
    ) async {
      await kitGalleryShot(
        tester,
        name: kitGalleryName('kit_glass_joining', phone, light: light),
        size: phone,
        light: light,
        open: (context) => _open(context, _scene(const _Shell())),
        then: (tester) async {
          await tester.drag(
            find.byKey(const ValueKey('content')),
            const Offset(0, -300),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 110));
        },
        settleAfterThen: false,
      );
    });

    testWidgets('search joined to the pill ($mode)', (tester) async {
      await kitGalleryShot(
        tester,
        name: kitGalleryName('kit_glass_joined', phone, light: light),
        size: phone,
        light: light,
        open: (context) => _open(context, _scene(const _Shell())),
        then: (tester) => tester.drag(
          find.byKey(const ValueKey('content')),
          const Offset(0, -300),
        ),
      );
    });

    testWidgets('glass flowing taller ($mode)', (tester) async {
      await kitGalleryShot(
        tester,
        name: kitGalleryName('kit_glass_flow', phone, light: light),
        size: phone,
        light: light,
        open: (context) => _open(context, _scene(const _Flow())),
        then: (tester) async {
          await tester.tap(find.text('Add a line'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 60));
        },
        settleAfterThen: false,
      );
    });

    // A theme pack the person picks: the glass reads on its colours too
    // (contrast on every pack: test/glass_surface_test.dart).
    testWidgets('joined on the Catppuccin pack ($mode)', (tester) async {
      await kitGalleryShot(
        tester,
        name: kitGalleryName(
          'kit_glass_joined_catppuccin',
          phone,
          light: light,
        ),
        size: phone,
        light: light,
        open: (context) => _open(
          context,
          Theme(
            data: light
                ? AppTheme.light(themePack(ThemePackId.catppuccin))
                : AppTheme.dark(themePack(ThemePackId.catppuccin)),
            child: _scene(const _Shell()),
          ),
        ),
        then: (tester) => tester.drag(
          find.byKey(const ValueKey('content')),
          const Offset(0, -300),
        ),
      );
    });

    testWidgets('glass off ($mode)', (tester) async {
      await kitGalleryShot(
        tester,
        name: kitGalleryName('kit_glass_solid', phone, light: light),
        size: phone,
        light: light,
        open: (context) => _open(
          context,
          _scene(const _Shell(), effects: const KitEffects(glass: false)),
        ),
      );
    });
  }
}
