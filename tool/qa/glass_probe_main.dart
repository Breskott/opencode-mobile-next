// Emulator probe for the light-glass crash (F1, emulator QA of build 2062).
//
//   flutter build apk --release --target-platform android-x64 \
//     -t tool/qa/glass_probe_main.dart
//   adb -s emulator-5554 shell am start -n <pkg>/.MainActivity \
//     --es route "'/p?theme=light&look=liquid&ambient=1&safety=0'"
//
// Draws the shell (the glass pill, search and dock over a list) in one
// variant, chosen by the launch route (theme, look, ambient fields; safety=1
// keeps KitGlassSafety's renderer check, which makes an emulator frosted), and keeps it repainting (a list that
// scrolls back and forth, a spinner) as the app does while in use.
import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) => debugPrint(
    'GLASSPROBE error: ${details.exceptionAsString()}\n${details.stack}',
  );
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('GLASSPROBE zone: $error\n$stack');
    return true;
  };
  debugPrint(
    'GLASSPROBE start ${WidgetsBinding.instance.platformDispatcher.defaultRouteName}',
  );
  final route = WidgetsBinding.instance.platformDispatcher.defaultRouteName;
  final q = Uri.parse(route).queryParameters;
  bool on(String key, [bool fallback = true]) =>
      q[key] == null ? fallback : q[key] == '1';
  final light = (q['theme'] ?? 'light') == 'light';
  final look = q['look'] ?? 'liquid';
  if (look == 'frosted') KitGlassShader.debugSupportedOverride = false;
  // The emulator is exactly where KitGlassSafety keeps glass frosted;
  // safety=0 skips the renderer check to prove liquid glass itself runs.
  if (!on('safety', false)) {
    KitGlassSafety.readProperties = () async => const {};
  }
  var roles = light ? graphiteLight : graphiteDark;
  if (!on('ambient')) roles = roles.copyWith(ambient: const []);
  runApp(
    _Probe(
      theme: AppTheme.fromRoles(roles),
      effects: KitEffects(glass: look != 'solid'),
      label: route,
      anim: on('anim'),
    ),
  );
}

class _Probe extends StatelessWidget {
  const _Probe({
    required this.theme,
    required this.effects,
    required this.label,
    required this.anim,
  });

  final ThemeData theme;
  final KitEffects effects;
  final String label;
  final bool anim;

  @override
  Widget build(BuildContext context) {
    return KitEffectsScope(
      effects: effects,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) => _Shell(label: label, anim: anim),
        ),
        onGenerateInitialRoutes: (_) => [
          MaterialPageRoute<void>(
            builder: (_) => _Shell(label: label, anim: anim),
          ),
        ],
      ),
    );
  }
}

class _Shell extends StatefulWidget {
  const _Shell({required this.label, required this.anim});

  final String label;
  final bool anim;

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  final _scroll = ScrollController();
  Timer? _timer;
  var _down = true;
  var _selected = 0;

  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 4), () {
      if (mounted) debugPrint('GLASSPROBE look ${KitGlass.lookOf(context)}');
    });
    if (widget.anim) {
      _timer = Timer.periodic(const Duration(milliseconds: 1600), (_) {
        if (!_scroll.hasClients) return;
        _scroll.animateTo(
          _down ? 900 : 0,
          duration: const Duration(milliseconds: 1400),
          curve: Curves.easeInOut,
        );
        _down = !_down;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('GLASSPROBE build shell');
    if (Uri.parse(widget.label).queryParameters['simple'] == '1') {
      return const ColoredBox(color: Color(0xFFFF00FF));
    }
    const marks = [
      Color(0xFF3DDC8A),
      Color(0xFF7FB0FF),
      Color(0xFFFFB88A),
      Color(0xFFC7A6FF),
    ];
    return KitNav(
      destinations: const [
        KitNavDestination(
          label: 'Work',
          icon: AppIconography.workspace,
          selectedIcon: AppIconography.workspaceSelected,
        ),
        KitNavDestination(
          label: 'Inbox',
          icon: AppIconography.activity,
          selectedIcon: AppIconography.activitySelected,
        ),
        KitNavDestination(label: 'Project', icon: AppIconography.files),
        KitNavDestination(label: 'Settings', icon: AppIconography.settings),
      ],
      selected: _selected,
      onSelected: (i) => setState(() => _selected = i),
      child: KitScreen(
        topBar: KitTopBar.shell(
          controls: KitShellControls(
            server: 'This phone',
            serverStatus: 'Connected',
            serverTone: AppStatusTone.ok,
            onServer: () {},
            onSearch: () {},
          ),
        ),
        body: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 160),
          children: [
            KitText(widget.label, role: KitTextRole.caption),
            if (widget.anim)
              const Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(),
                ),
              ),
            for (var i = 0; i < 40; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: marks[i % marks.length],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: KitText(
                        'Conversation ${i + 1}: fix the reconnect loop',
                        role: KitTextRole.rowTitle,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
