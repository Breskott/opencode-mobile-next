import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/migration/migration_provider_names.dart';

void main() {
  const secret = 'synthetic-secret-never-render';

  test(
    'JSONC returns only fixed labels, ignoring secrets and custom names',
    () {
      final output = <String>[];
      final labels = runZoned(
        () => parseMigrationProviderNames('''
      {
        // Provider settings can contain credentials.
        "provider": {
          "anthropic": {"name": "$secret", "options": {"apiKey": "$secret"}},
          "openai": {"options": {"baseURL": "https://example.test/a//b/*c*/"}},
          "$secret": {"name": "OpenAI"},
          "github-copilot": {},
          "github-copilot-enterprise": {}, /* duplicates */
        },
      }
      '''),
        zoneSpecification: ZoneSpecification(
          print: (_, _, _, text) => output.add(text),
        ),
      );
      expect(labels, ['Anthropic', 'GitHub Copilot', 'OpenAI']);
      expect(output, isEmpty);
      expect(labels.join(), isNot(contains(secret)));
    },
  );

  test('invalid, over-limit and non-provider documents disclose nothing', () {
    for (final text in [
      '{"provider":{"anthropic":{}}',
      '{"provider":{"anthropic":{}}} /* unfinished',
      '{"provider":{"anthropic":"$secret"}}',
      '{"auth":{"openai":{"key":"$secret"}}}',
      '{"provider":[]}',
      jsonEncode({
        'provider': {
          for (var i = 0; i < 65; i++) 'provider$i': {},
          'openai': {},
        },
      }),
      ' ' * (1024 * 1024 + 1),
      '${'[' * 65}${']' * 65}',
    ]) {
      expect(parseMigrationProviderNames(text), isEmpty);
    }
  });

  test('escaped strings and comment markers cannot introduce provider IDs', () {
    expect(
      parseMigrationProviderNames(
        jsonEncode({
          'provider': {
            'anthropic': {'name': '\\" // /* $secret'},
            'custom': {
              'name': 'openai',
              'provider': {'google': {}},
            },
          },
        }),
      ),
      ['Anthropic'],
    );
  });

  test('model-only config exposes fixed provider labels, never model text', () {
    expect(
      parseMigrationProviderNames(
        jsonEncode({
          'model': 'anthropic/$secret',
          'small_model': 'openai/$secret',
        }),
      ),
      ['Anthropic', 'OpenAI'],
    );
    expect(
      parseMigrationProviderNames(
        jsonEncode({
          'model': '$secret/anthropic',
          'small_model': 'custom/openai',
        }),
      ),
      isEmpty,
    );
    for (final providers in [
      null,
      <dynamic>[],
      {'anthropic': secret},
      {for (var i = 0; i < 65; i++) 'provider$i': <String, dynamic>{}},
    ]) {
      expect(
        parseMigrationProviderNames(
          jsonEncode({'provider': providers, 'model': 'openai/$secret'}),
        ),
        isEmpty,
      );
    }
  });

  group('private export reader', () {
    late Directory root;
    setUp(() async {
      root = await Directory.systemTemp.createTemp('migration-provider-names-');
    });
    tearDown(() async {
      await root.delete(recursive: true);
    });

    Future<File> config(String relative, String content) async {
      final file = File('${root.path}/$relative');
      await file.parent.create(recursive: true);
      return file.writeAsString(content);
    }

    test(
      'reads only fixed OC1/OC2 config paths and deduplicates labels',
      () async {
        await config(
          '.config/opencode/opencode.json',
          '{"provider":{"anthropic":{},"openai":{}}}',
        );
        await config(
          '.oc-opencode2/config/opencode/opencode.jsonc',
          '{/* isolated */"provider":{"openai":{},"google":{},},}',
        );
        await config(
          '.local/share/opencode/auth.json',
          '{"provider":{"groq":{"key":"$secret"}}}',
        );
        await config('opencode.json', '{"provider":{"mistral":{}}}');
        expect(await readMigrationProviderNames(root), [
          'Anthropic',
          'Google',
          'OpenAI',
        ]);
      },
    );

    test('rejects oversized files and symlinked files or parents', () async {
      final oversized = await config(
        '.config/opencode/opencode.json',
        '${' ' * (1024 * 1024)}{"provider":{"anthropic":{}}}',
      );
      expect(await readMigrationProviderNames(root), isEmpty);
      await oversized.delete();
      final outside = await config('other.json', '{"provider":{"openai":{}}}');
      await Link(oversized.path).create(outside.path);
      expect(await readMigrationProviderNames(root), isEmpty);
      await Link(oversized.path).delete();
      final originalParent = oversized.parent;
      final movedParent = await originalParent.rename('${root.path}/actual');
      await File(
        '${movedParent.path}/opencode.json',
      ).writeAsString('{"provider":{"openai":{}}}');
      await Link(originalParent.path).create(movedParent.path);
      expect(await readMigrationProviderNames(root), isEmpty);
    });

    test('rejects export-root symlinks and contains read failures', () async {
      final target = Directory('${root.path}/actual');
      await target.create();
      final file = File('${target.path}/.config/opencode/opencode.json');
      await file.parent.create(recursive: true);
      await file.writeAsString('{"provider":{"openai":{}}}');
      final link = Link('${root.path}/export');
      await link.create(target.path);
      expect(await readMigrationProviderNames(Directory(link.path)), isEmpty);
      expect(
        await readMigrationProviderNames(Directory('${root.path}/missing')),
        isEmpty,
      );
    });

    test('permits a platform alias above the verified export root', () async {
      final actual = Directory('${root.path}/actual');
      final file = File('${actual.path}/export/.config/opencode/opencode.json');
      await file.parent.create(recursive: true);
      await file.writeAsString('{"provider":{"openai":{}}}');
      final alias = Link('${root.path}/platform-alias');
      await alias.create(actual.path);
      expect(
        await readMigrationProviderNames(Directory('${alias.path}/export')),
        ['OpenAI'],
      );
    });
  });
}
