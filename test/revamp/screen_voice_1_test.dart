// screen-voice-1 (wave 2b): the voice model setup sheet, its delete
// confirmation, the voice input sheet and the voice licenses page, rebuilt
// from kit parts. These tests assert what the person sees and what reaches
// the voice model manager.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/voice/audio.dart';
import 'package:opencode_mobile/voice/controller.dart';
import 'package:opencode_mobile/voice/model_manager.dart';
import 'package:opencode_mobile/voice/model_manifest.dart';
import 'package:opencode_mobile/voice/notices.dart';
import 'package:opencode_mobile/voice/voice_ui.dart';

import 'screen_voice_1_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(rootBundle.clear);

  Future<void> openSetup(
    WidgetTester tester,
    ScriptedVoiceModels models, {
    void Function(bool)? onResult,
    Size size = voicePhone,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      voiceHost(
        home: voiceLauncher((context) async {
          final ready = await showVoiceModelSetupSheet(context, models);
          onResult?.call(ready);
          return ready;
        }),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  group('voice model setup sheet', () {
    testWidgets('names the model it downloads and sends the download', (
      tester,
    ) async {
      final models = await ScriptedVoiceModels.create(installed: {});
      addTearDown(models.dispose);
      await openSetup(tester, models);

      expect(find.text('Local voice input'), findsOneWidget);
      expect(
        find.textContaining('Download a speech model once'),
        findsOneWidget,
      );
      final download = find.textContaining('Download Balanced (');
      expect(download, findsOneWidget);
      // Nothing is on the phone, so there is nothing to delete.
      expect(find.byKey(const Key('voice-delete-base')), findsNothing);

      await tester.tap(download);
      await tester.pump();
      expect(models.acts, ['download:base']);
    });

    testWidgets('choosing another model renames the pinned action', (
      tester,
    ) async {
      final models = await ScriptedVoiceModels.create(installed: {'base'});
      addTearDown(models.dispose);
      await openSetup(tester, models);

      expect(find.text('Use Balanced'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('voice-model-tiny')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('voice-model-tiny')));
      await tester.pumpAndSettle();

      expect(models.selectedPack.id, 'tiny');
      expect(find.text('Use Balanced'), findsNothing);
      expect(find.textContaining('Download Compact fallback'), findsOneWidget);
    });

    testWidgets('Use <model> closes the sheet with the model ready', (
      tester,
    ) async {
      final models = await ScriptedVoiceModels.create(installed: {'base'});
      addTearDown(models.dispose);
      bool? result;
      await openSetup(tester, models, onResult: (ready) => result = ready);

      await tester.tap(find.text('Use Balanced'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
      expect(find.text('Local voice input'), findsNothing);
    });

    testWidgets('Not now closes the sheet without a model', (tester) async {
      final models = await ScriptedVoiceModels.create(installed: {});
      addTearDown(models.dispose);
      bool? result;
      await openSetup(tester, models, onResult: (ready) => result = ready);

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });

    testWidgets('delete asks with the model name, and Keep keeps it', (
      tester,
    ) async {
      final models = await ScriptedVoiceModels.create(installed: {'base'});
      addTearDown(models.dispose);
      await openSetup(tester, models);

      await tester.ensureVisible(find.text('Delete Balanced'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete Balanced'));
      await tester.pumpAndSettle();
      expect(find.text('Delete Balanced?'), findsOneWidget);
      expect(find.textContaining('This removes'), findsOneWidget);
      await tester.tap(find.text('Keep Balanced'));
      await tester.pumpAndSettle();
      expect(models.acts, isEmpty);
      expect(models.isInstalled(voiceModelPack('base')), isTrue);

      await tester.ensureVisible(find.text('Delete Balanced'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete Balanced'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('voice-delete-confirm')));
      await tester.pumpAndSettle();
      expect(models.acts, ['delete:base']);
      // The sheet stays open and now offers the download again.
      expect(find.textContaining('Download Balanced ('), findsOneWidget);
    });

    testWidgets('download again names the model and is sent', (tester) async {
      final models = await ScriptedVoiceModels.create(installed: {'base'});
      addTearDown(models.dispose);
      await openSetup(tester, models);

      await tester.ensureVisible(find.text('Download Balanced again'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Download Balanced again'));
      await tester.pump();
      expect(models.acts, ['redownload:base']);
    });

    testWidgets('a running download shows its progress and its Cancel', (
      tester,
    ) async {
      final models = await ScriptedVoiceModels.create(installed: {});
      addTearDown(models.dispose);
      await openSetup(tester, models);
      final pack = voiceModelPack('base');
      models.downloading(pack, pack.downloadBytes ~/ 2);
      await tester.pumpAndSettle();

      final title = find.text('Downloading Balanced', skipOffstage: false);
      await tester.ensureVisible(title);
      await tester.pumpAndSettle();
      expect(title, findsOneWidget);
      // No pinned Download stands in for the progress.
      expect(find.byKey(const Key('voice-model-primary-action')), findsNothing);
      final cancel = find.byKey(
        const Key('voice-model-cancel-download'),
        skipOffstage: false,
      );
      await tester.ensureVisible(cancel);
      await tester.pumpAndSettle();
      await tester.tap(cancel);
      await tester.pump();
      expect(models.acts, ['cancel']);
    });

    testWidgets('language is one tap and is saved on the manager', (
      tester,
    ) async {
      final models = await ScriptedVoiceModels.create(installed: {'base'});
      addTearDown(models.dispose);
      await openSetup(tester, models);

      await tester.ensureVisible(find.text('English', skipOffstage: false));
      await tester.pumpAndSettle();
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(models.language, VoiceLanguage.english);
    });

    testWidgets('a failed setup explains and keeps the details folded', (
      tester,
    ) async {
      final models = await ScriptedVoiceModels.create(installed: {});
      addTearDown(models.dispose);
      models
        ..state = VoiceModelState.error
        ..error = StateError('HTTP 503 raw detail');
      await openSetup(tester, models);

      expect(find.textContaining('Model setup failed'), findsOneWidget);
      expect(find.text('Technical details'), findsOneWidget);
      expect(find.textContaining('HTTP 503 raw detail'), findsNothing);
      // The download stays one tap away as the retry.
      expect(find.textContaining('Download Balanced ('), findsOneWidget);
    });

    testWidgets('fits a phone and a PC window with no overflow', (
      tester,
    ) async {
      for (final size in const [
        Size(360, 800),
        voicePhone,
        Size(915, 412),
        voiceWide,
      ]) {
        final models = await ScriptedVoiceModels.create(installed: {'base'});
        await openSetup(tester, models, size: size);
        expect(tester.takeException(), isNull, reason: '$size');
        await tester.pumpWidget(const SizedBox.shrink());
        models.dispose();
      }
    });
  });

  group('voice input sheet', () {
    Future<VoiceComposerResult?> Function() open(
      WidgetTester tester,
      ScriptedVoiceComposer voice,
    ) {
      VoiceComposerResult? result;
      tester.view.physicalSize = voicePhone;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      return () async {
        await tester.pumpWidget(
          voiceHost(
            home: voiceLauncher((context) async {
              result = await showVoiceComposerResultSheet(context, voice);
              return result;
            }),
          ),
        );
        await tester.tap(find.text('Open'));
        await pumpSheet(tester);
        return result;
      };
    }

    testWidgets('listen, stop, review and insert the transcript', (
      tester,
    ) async {
      final models = await ScriptedVoiceModels.create();
      final voice = ScriptedVoiceComposer(
        models: models,
        transcript: 'Fix the flaky checkout test',
      );
      addTearDown(voice.dispose);
      VoiceComposerResult? result;
      tester.view.physicalSize = voicePhone;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        voiceHost(
          home: voiceLauncher((context) async {
            result = await showVoiceComposerResultSheet(context, voice);
            return result;
          }),
        ),
      );
      await tester.tap(find.text('Open'));
      await pumpSheet(tester);

      expect(find.text('Voice input'), findsOneWidget);
      expect(find.text('Audio stays on this device'), findsOneWidget);
      expect(find.text('Listening 0:07 of 0:30'), findsOneWidget);
      await tester.tap(find.text('Stop recording'));
      await pumpSheet(tester);

      expect(find.text('Transcript ready to review'), findsOneWidget);
      expect(find.text('Fix the flaky checkout test'), findsOneWidget);
      await tester.tap(find.text('Insert & send'));
      await pumpSheet(tester);
      expect(result?.text, 'Fix the flaky checkout test');
      expect(result?.send, isTrue);
    });

    testWidgets('a blocked microphone explains and offers app settings', (
      tester,
    ) async {
      final models = await ScriptedVoiceModels.create();
      final voice = ScriptedVoiceComposer(models: models);
      addTearDown(voice.dispose);
      await open(tester, voice)();
      voice.show(
        VoiceComposerState.error,
        failure: const VoicePermissionDenied(permanent: true),
      );
      await pumpSheet(tester);

      expect(find.textContaining('Microphone access is blocked'), findsOne);
      expect(find.text('Open app settings'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('Cancel stops the recorder and closes', (tester) async {
      final models = await ScriptedVoiceModels.create();
      final voice = ScriptedVoiceComposer(models: models);
      addTearDown(voice.dispose);
      await open(tester, voice)();

      await tester.tap(find.byKey(const Key('voice-composer-cancel')));
      await pumpSheet(tester);
      expect(voice.cancels, greaterThan(0));
      expect(find.text('Voice input'), findsNothing);
    });
  });

  group('voice licenses page', () {
    testWidgets('lists each part with its maker and license', (tester) async {
      tester.view.physicalSize = voicePhone;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(voiceHost(home: const VoiceNoticesPage()));
      await tester.pumpAndSettle();

      expect(find.text('Voice licenses'), findsOneWidget);
      expect(find.text('Whisper speech models'), findsOneWidget);
      expect(find.text('OpenAI · MIT License'), findsOneWidget);
      expect(find.text('sherpa-onnx'), findsOneWidget);
      expect(find.text('ONNX Runtime'), findsOneWidget);
      expect(find.text('record'), findsOneWidget);
      // Build provenance stays in the repository.
      expect(find.textContaining('pubspec.lock'), findsNothing);
    });

    testWidgets('a part opens its license text and its website action', (
      tester,
    ) async {
      tester.view.physicalSize = voicePhone;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(voiceHost(home: const VoiceNoticesPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ONNX Runtime'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Copyright (c) Microsoft Corporation'),
        findsOneWidget,
      );
      expect(find.text('Open the ONNX Runtime website'), findsOneWidget);
    });
  });
}
