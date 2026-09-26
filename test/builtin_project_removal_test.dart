import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/builtin_linux.dart';

// Finish line: the removal bridge keeps projects by default, requires an exact
// destructive confirmation, and exposes trustworthy measured storage totals.
// Non-goal: UI confirmation sheets and Android filesystem migration execution.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(BuiltinLinux.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  Object? Function(MethodCall call)? answer;

  setUp(() {
    calls.clear();
    answer = null;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return answer?.call(call);
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Matcher failureCode(String code) =>
      isA<BuiltinLinuxException>().having((error) => error.code, 'code', code);

  group('project-preserving removal', () {
    test(
      'remove keeps projects unless explicitly requested otherwise',
      () async {
        await BuiltinLinux().remove();

        expect(calls.single.method, 'removeRuntime');
        expect(calls.single.arguments, {'alsoDeleteProjects': false});
      },
    );

    test('legacy uninstall also keeps projects', () async {
      await BuiltinLinux().uninstall();

      expect(calls.single.method, 'removeRuntime');
      expect(calls.single.arguments, {'alsoDeleteProjects': false});
    });

    test('delete everything sends the exact typed confirmation', () async {
      expect(BuiltinLinux.deletionConfirmationName, 'OpenCode');
      await BuiltinLinux().remove(
        alsoDeleteProjects: true,
        confirmationName: BuiltinLinux.deletionConfirmationName,
      );

      expect(calls.single.method, 'removeRuntime');
      expect(calls.single.arguments, {
        'alsoDeleteProjects': true,
        'confirmationName': 'OpenCode',
      });
    });

    for (final name in <String?>[
      null,
      '',
      'opencode',
      'OpenCode ',
      ' OpenCode',
      'Another project',
    ]) {
      test(
        'invalid confirmation ${name ?? "(missing)"} never deletes',
        () async {
          await expectLater(
            BuiltinLinux().remove(
              alsoDeleteProjects: true,
              confirmationName: name,
            ),
            throwsA(failureCode('confirmation_required')),
          );

          expect(calls, isEmpty);
        },
      );
    }

    test('an older APK never receives its destructive uninstall', () async {
      var oldUninstallCalled = false;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'uninstall') {
          oldUninstallCalled = true;
          return null;
        }
        throw MissingPluginException();
      });

      await expectLater(
        BuiltinLinux().uninstall(),
        throwsA(failureCode('missing_plugin')),
      );
      expect(oldUninstallCalled, isFalse);
    });

    test('keep projects does not forward an unrelated typed value', () async {
      await BuiltinLinux().remove(confirmationName: 'unrelated text');

      expect(calls.single.arguments, {'alsoDeleteProjects': false});
    });
  });

  group('measured project storage', () {
    test('each removal choice has its own measured freed-byte total', () async {
      answer = (_) => {
        'runtimeBytes': 1024,
        'projectsBytes': 4096,
        'measuredAtMilliseconds': 1790467200000,
      };

      final storage = await BuiltinLinux().projectStorage();

      expect(calls.single.method, 'projectStorage');
      expect(storage.runtimeBytes, 1024);
      expect(storage.projectsBytes, 4096);
      expect(storage.measuredAtMilliseconds, 1790467200000);
      expect(storage.keepProjectsFreedBytes, 1024);
      expect(storage.deleteEverythingFreedBytes, 5120);
    });

    test(
      'retained projects remain visible with no runtime installed',
      () async {
        answer = (_) => {
          'runtimeBytes': 0,
          'projectsBytes': 4096,
          'measuredAtMilliseconds': 1790467200000,
        };

        final storage = await BuiltinLinux().projectStorage();

        expect(storage.keepProjectsFreedBytes, 0);
        expect(storage.projectsBytes, 4096);
        expect(storage.deleteEverythingFreedBytes, 4096);
      },
    );

    test(
      'an empty installation measures zero without inventing data',
      () async {
        answer = (_) => {
          'runtimeBytes': 0,
          'projectsBytes': 0,
          'measuredAtMilliseconds': 1790467200000,
        };

        final storage = await BuiltinLinux().projectStorage();

        expect(storage.keepProjectsFreedBytes, 0);
        expect(storage.deleteEverythingFreedBytes, 0);
      },
    );

    for (final field in [
      'runtimeBytes',
      'projectsBytes',
      'measuredAtMilliseconds',
    ]) {
      for (final invalid in <Object?>[null, -1, 1.5, '1024', true]) {
        test('$field rejects ${invalid.runtimeType} invalid data', () async {
          answer = (_) => {
            'runtimeBytes': 1024,
            'projectsBytes': 4096,
            'measuredAtMilliseconds': 1790467200000,
            field: invalid,
          };

          await expectLater(
            BuiltinLinux().projectStorage(),
            throwsA(failureCode('storage_unavailable')),
          );
        });
      }
    }

    for (final invalid in <Object?>[null, <String, Object?>{}, 'not a map']) {
      test(
        'a ${invalid.runtimeType} response cannot imply free space',
        () async {
          answer = (_) => invalid;

          await expectLater(
            BuiltinLinux().projectStorage(),
            throwsA(failureCode('storage_unavailable')),
          );
        },
      );
    }
  });

  group('removal and measurement failure safety', () {
    final operations = <String, Future<Object?> Function(BuiltinLinux)>{
      'measure': (linux) => linux.projectStorage(),
      'keep projects': (linux) => linux.remove(),
      'delete everything': (linux) =>
          linux.remove(alsoDeleteProjects: true, confirmationName: 'OpenCode'),
    };

    for (final operation in operations.entries) {
      test('${operation.key} hides native error message and details', () async {
        answer = (_) => throw PlatformException(
          code: 'migration_failed',
          message: 'synthetic-private-native-message',
          details: {'path': 'synthetic-private-native-detail'},
        );

        await expectLater(
          operation.value(BuiltinLinux()),
          throwsA(
            isA<BuiltinLinuxException>()
                .having((error) => error.message, 'safe message', isNotEmpty)
                .having(
                  (error) => error.toString(),
                  'no native diagnostic content',
                  isNot(contains('synthetic-private-native')),
                ),
          ),
        );
      });

      test(
        '${operation.key} fails when the native channel is absent',
        () async {
          messenger.setMockMethodCallHandler(channel, null);

          await expectLater(
            operation.value(BuiltinLinux()),
            throwsA(failureCode('missing_plugin')),
          );
        },
      );
    }
  });
}
