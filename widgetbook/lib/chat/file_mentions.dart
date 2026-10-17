// Pointing the agent at a project file: the suggestion strip that opens when
// `@ser` is typed (a subagent first, then files: name, then folder), and the
// "File from the project" sheet the + menu opens.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:widgetbook/widgetbook.dart';

import '../catalog.dart';

const _files = [
  'lib/server.dart',
  'lib/api/server_client.dart',
  'test/server_test.dart',
  'README.md',
];

const _long = [
  'packages/opencode_sdk/lib/src/model/session_prompt_async_request_model.dart',
  'lib/ui/screens/settings/connections/connection_details_and_recovery.dart',
  'مستندات/دليل-المستخدم.md',
];

KitSuggestion _file(String path) => KitSuggestion(
  id: path,
  label: path.split('/').last,
  kind: KitSuggestionKind.file,
  description: path.contains('/')
      ? path.substring(0, path.lastIndexOf('/'))
      : null,
  key: Key('inline-file-$path'),
);

/// The strip under a conversation, above the field.
class _StripScene extends StatelessWidget {
  const _StripScene({required this.paths, this.withAgent = true});

  final List<String> paths;
  final bool withAgent;

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    return Scaffold(
      backgroundColor: tokens.roles.ground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.all(tokens.gutter),
              child: const KitText('Fix the login', role: KitTextRole.headline),
            ),
            const Spacer(),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: tokens.gutter),
              child: KitComposerChips.suggestions(
                listKey: const Key('inline-agent-suggestions'),
                suggestions: [
                  if (withAgent)
                    const KitSuggestion(
                      id: 'server-helper',
                      label: '@server-helper',
                      kind: KitSuggestionKind.agent,
                      description: 'Looks after the server code',
                    ),
                  for (final path in paths) _file(path),
                ],
                onSelected: (_) {},
              ),
            ),
            SizedBox(height: tokens.space3),
          ],
        ),
      ),
    );
  }
}

/// Opens the project file sheet once the scene is up.
class _SheetScene extends StatefulWidget {
  const _SheetScene({required this.top});

  /// The top-level files listed before a query.
  final List<String> top;

  @override
  State<_SheetScene> createState() => _SheetSceneState();
}

class _SheetSceneState extends State<_SheetScene> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        showKitProjectFileSheet(
          context,
          search: (q) async => _files
              .where((p) => p.toLowerCase().contains(q.toLowerCase()))
              .toList(),
          initial: (_) async => widget.top,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) =>
      Scaffold(backgroundColor: KitTokens.of(context).roles.ground);
}

CatalogComponent kitFileMentions() => catalogComponent(
  area: 'Chats',
  name: 'File mentions',
  useCases: [
    WidgetbookUseCase(
      name: 'Suggestions: a subagent and files',
      builder: (_) => const _StripScene(paths: _files),
    ),
    WidgetbookUseCase(
      name: 'Suggestions: long paths',
      builder: (_) => const _StripScene(paths: _long, withAgent: false),
    ),
    WidgetbookUseCase(
      name: 'Project file sheet',
      builder: (_) => const _SheetScene(
        top: ['pubspec.yaml', 'README.md', 'analysis_options.yaml'],
      ),
    ),
    WidgetbookUseCase(
      name: 'Project file sheet: no top-level files',
      builder: (_) => const _SheetScene(top: []),
    ),
  ],
);
