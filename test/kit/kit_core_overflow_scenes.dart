// G6 scenes for the core parts added during the September 27 kit rollout.
// The same real parts run at every size, text scale and direction in G6.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_overflow_scenes.dart';

void _noop() {}

KitAction _retry(KitSceneCopy copy) =>
    KitAction(label: copy.t('Try again', 'حاول مرة أخرى'), onPressed: _noop);

KitChecklist _checklist(
  KitSceneCopy copy, {
  KitMarkState state = KitMarkState.waiting,
  bool compact = false,
  bool person = false,
  bool paused = false,
}) => KitChecklist(
  compact: compact,
  estimate: state == KitMarkState.waiting
      ? copy.t(
          'About eight minutes the first time',
          'حوالي ثماني دقائق أول مرة',
        )
      : null,
  steps: [
    KitStep(
      title: copy.t('Prepare this phone', 'تجهيز هذا الهاتف'),
      state: KitMarkState.done,
    ),
    KitStep(
      title: copy.t(
        'Install the tools for local conversations',
        'تثبيت أدوات المحادثات المحلية',
      ),
      supporting: copy.t(
        'Keep the phone connected while the tools install',
        'أبق الهاتف متصلاً أثناء تثبيت الأدوات',
      ),
      state: state,
      paused: paused,
      personAction: person
          ? KitAction(
              label: copy.t('Allow access', 'السماح بالوصول'),
              onPressed: _noop,
            )
          : null,
      retry: state == KitMarkState.failed ? _retry(copy) : null,
    ),
  ],
  resume: state == KitMarkState.failed || paused
      ? KitAction(
          label: copy.t('Continue setup', 'متابعة الإعداد'),
          onPressed: _noop,
        )
      : null,
);

class _SceneCamera implements KitScannerCamera {
  _SceneCamera({this.loading = false});
  final bool loading;

  @override
  Stream<String> get codes => const Stream.empty();

  @override
  Future<void> start() => loading ? Completer<void>().future : Future.value();

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}

  @override
  Widget preview(BuildContext context) => const ColoredBox(color: Colors.black);
}

final List<KitOverflowScene> kitCoreOverflowScenes = [
  KitOverflowScene(['KitChecklist'], 'default', build: (_, c) => _checklist(c)),
  KitOverflowScene(
    ['KitChecklist'],
    'working',
    build: (_, c) => _checklist(c, state: KitMarkState.working),
  ),
  KitOverflowScene(
    ['KitChecklist'],
    'person-step',
    build: (_, c) => _checklist(c, person: true),
  ),
  KitOverflowScene(
    ['KitChecklist'],
    'failed',
    build: (_, c) => _checklist(c, state: KitMarkState.failed),
  ),
  KitOverflowScene(
    ['KitChecklist'],
    'paused',
    build: (_, c) => _checklist(c, paused: true),
  ),
  KitOverflowScene(
    ['KitChecklist'],
    'done',
    build: (_, c) => _checklist(c, state: KitMarkState.done),
  ),
  KitOverflowScene(
    ['KitChecklist'],
    'compact',
    build: (_, c) => _checklist(c, state: KitMarkState.working, compact: true),
  ),
  KitOverflowScene(
    ['KitJumpPill'],
    'default',
    build: (_, c) => KitJumpPill(
      label: c.t(
        '3 new messages · Jump to latest',
        '٣ رسائل جديدة · الانتقال للأحدث',
      ),
      visible: true,
      onPressed: _noop,
    ),
  ),
  KitOverflowScene(
    ['KitJumpPill'],
    'older',
    build: (_, c) => KitJumpPill.older(
      label: c.t('Earlier messages', 'الرسائل السابقة'),
      visible: true,
      onPressed: _noop,
    ),
  ),
  KitOverflowScene(
    ['KitJumpPillLayer'],
    'default',
    host: KitOverflowHost.fill,
    build: (_, c) => KitJumpPillLayer(
      pill: KitJumpPill(
        label: c.t(
          '3 new lines · Jump to latest',
          '٣ أسطر جديدة · الانتقال للأحدث',
        ),
        visible: true,
        onPressed: _noop,
      ),
      child: ListView(
        children: [
          for (var i = 0; i < 60; i++)
            KitText(c.t('Build output line $i', 'سطر مخرجات البناء $i')),
        ],
      ),
    ),
  ),
  KitOverflowScene(
    ['KitProgressRow'],
    'loading',
    build: (_, c) => KitProgressRow(
      title: c.t('Conversation context', 'سياق المحادثة'),
      value: null,
    ),
  ),
  for (final (state, value) in [
    ('default', .62),
    ('near-limit', .9),
    ('at-limit', 1.0),
    ('empty', 0.0),
  ])
    KitOverflowScene(
      ['KitProgressRow'],
      state,
      build: (_, c) => KitProgressRow(
        title: c.t('Conversation context', 'سياق المحادثة'),
        value: value,
        valueLabel: c.t(
          'Tokens used in this conversation',
          'الرموز المستخدمة في هذه المحادثة',
        ),
        onTap: _noop,
      ),
    ),
  KitOverflowScene(
    ['KitProgressRow'],
    'segments',
    build: (_, c) => KitProgressRow.segments(
      title: c.t('Conversation context', 'سياق المحادثة'),
      segments: [
        KitProgressSegment(
          label: c.t('Conversation history', 'سجل المحادثة'),
          value: .5,
          valueLabel: c.t('50 thousand tokens', '٥٠ ألف رمز'),
        ),
        KitProgressSegment(
          label: c.t('Tools and instructions', 'الأدوات والتعليمات'),
          value: .2,
          valueLabel: c.t('20 thousand tokens', '٢٠ ألف رمز'),
        ),
      ],
    ),
  ),
  for (final state in KitReceiptState.values)
    KitOverflowScene(
      ['KitReceipt'],
      state.name,
      build: (_, c) => KitReceipt(
        state: state,
        reason: c.t(
          'Your access to this project has changed',
          'تغير وصولك إلى هذا المشروع',
        ),
        where: c.t('another connected device', 'جهاز آخر متصل'),
        onRetry: _noop,
        onUndo: _noop,
      ),
    ),
  KitOverflowScene(
    ['KitReceipt'],
    'automatic',
    build: (_, c) => KitReceipt(
      state: KitReceiptState.confirmed,
      automatic: true,
      label: c.t('Restarted the phone server', 'أعيد تشغيل خادم الهاتف'),
      onUndo: _noop,
    ),
  ),
  for (final state in ['default', 'loading', 'error'])
    KitOverflowScene(
      ['KitScanner'],
      state,
      host: KitOverflowHost.fill,
      build: (_, c) => KitScanner(
        camera: _SceneCamera(loading: state == 'loading'),
        instruction: c.t(
          'Point the camera at the pairing code on your computer',
          'وجه الكاميرا إلى رمز الاقتران على الكمبيوتر',
        ),
        rejected: state == 'error'
            ? c.t(
                'This is not a pairing code for your server',
                'هذا ليس رمز اقتران لخادمك',
              )
            : null,
        onCode: (_) => false,
        onFailed: (_) {},
      ),
    ),
];
