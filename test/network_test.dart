import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/platform/network.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';

const _wifi = NetworkReading(
  status: NetworkStatus.online,
  transport: NetworkTransport.wifi,
  metered: false,
  connected: true,
);
const _offline = NetworkReading(
  status: NetworkStatus.offline,
  connected: false,
);

class _Bridge extends NetworkBridge {
  final events = StreamController<NetworkReading>.broadcast(sync: true);
  final pending = <Completer<NetworkReading>>[];
  int listens = 0;

  @override
  Future<NetworkReading> current() {
    final request = Completer<NetworkReading>();
    pending.add(request);
    return request.future;
  }

  @override
  Stream<NetworkReading> readings() {
    listens++;
    return events.stream;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const method = MethodChannel('oc/network');
  const eventMethod = MethodChannel('oc/network/events');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    debugPlatformCapabilities = const PlatformCapabilities.android();
  });
  tearDown(() {
    debugPlatformCapabilities = null;
    messenger.setMockMethodCallHandler(method, null);
    messenger.setMockMethodCallHandler(eventMethod, null);
  });

  test('distinguishes no network from unvalidated Wi-Fi and unknown', () {
    final lan = NetworkReading.fromMap({
      'status': 'offline',
      'transport': 'wifi',
      'connected': true,
      'metered': false,
    });
    expect(lan.status, NetworkStatus.offline);
    expect(lan.hasNoNetwork, false);
    expect(lan.transport, NetworkTransport.wifi);
    expect(_offline.hasNoNetwork, true);
    expect(NetworkReading.unknown.hasNoNetwork, false);
    expect(NetworkReading.fromMap(null), NetworkReading.unknown);
    expect(NetworkReading.fromMap({'metered': 'false'}).metered, isNull);
  });

  test('reads typed mobile and metered state from Android', () async {
    messenger.setMockMethodCallHandler(method, (call) async {
      expect(call.method, 'current');
      return {
        'status': 'online',
        'transport': 'mobile',
        'metered': true,
        'connected': true,
      };
    });
    final reading = await const NetworkBridge().current();
    expect(reading.status, NetworkStatus.online);
    expect(reading.transport, NetworkTransport.mobile);
    expect(reading.metered, true);
  });

  test('desktop and web return unknown without channel calls', () async {
    var calls = 0;
    messenger.setMockMethodCallHandler(method, (_) async {
      calls++;
      return {'connected': true};
    });
    messenger.setMockMethodCallHandler(eventMethod, (_) async {
      calls++;
      return null;
    });
    for (final capabilities in const [
      PlatformCapabilities.linuxDesktop(),
      PlatformCapabilities(platform: TargetPlatform.android, isWeb: true),
    ]) {
      debugPlatformCapabilities = capabilities;
      expect(await const NetworkBridge().current(), NetworkReading.unknown);
      expect(
        await const NetworkBridge().readings().first,
        NetworkReading.unknown,
      );
    }
    expect(calls, 0);
  });

  test(
    'channel failures return unknown without exposing native errors',
    () async {
      messenger.setMockMethodCallHandler(method, (_) async {
        throw PlatformException(
          code: 'failed',
          message: 'private native details',
        );
      });
      expect(await const NetworkBridge().current(), NetworkReading.unknown);
    },
  );

  test('event errors publish unknown and later events recover', () async {
    messenger.setMockMethodCallHandler(eventMethod, (_) async => null);
    final values = <NetworkReading>[];
    final subscription = const NetworkBridge().readings().listen(values.add);
    await Future<void>.delayed(Duration.zero);
    Future<void> send(ByteData data) async {
      await messenger.handlePlatformMessage('oc/network/events', data, (_) {});
      await Future<void>.delayed(Duration.zero);
    }

    const codec = StandardMethodCodec();
    await send(
      codec.encodeSuccessEnvelope({
        'status': 'online',
        'transport': 'wifi',
        'metered': false,
        'connected': true,
      }),
    );
    await send(codec.encodeErrorEnvelope(code: 'unavailable'));
    await send(
      codec.encodeSuccessEnvelope({'status': 'offline', 'connected': false}),
    );
    expect(values, [_wifi, NetworkReading.unknown, _offline]);
    await subscription.cancel();
  });

  test('start is idempotent and newer events beat pending snapshots', () async {
    final bridge = _Bridge();
    final state = NetworkState(bridge: bridge);
    final starting = state.start();
    await state.start();
    expect(bridge.listens, 1);
    expect(bridge.pending, hasLength(1));
    bridge.events.add(_offline);
    bridge.pending.single.complete(_wifi);
    await starting;
    expect(state.value, _offline);
    state.dispose();
    await bridge.events.close();
  });

  test('refresh, event failures, duplicates, and dispose are safe', () async {
    final bridge = _Bridge();
    final state = NetworkState(bridge: bridge);
    var notifications = 0;
    state.addListener(() => notifications++);
    final starting = state.start();
    bridge.pending.removeAt(0).complete(_wifi);
    await starting;
    bridge.events.add(_wifi);
    expect(notifications, 1);
    bridge.events.addError(StateError('native details'));
    expect(state.value, NetworkReading.unknown);
    final first = state.refresh();
    final second = state.refresh();
    bridge.pending[1].complete(_offline);
    await second;
    bridge.pending[0].complete(_wifi);
    await first;
    expect(state.value, _offline);
    final last = state.refresh();
    state.dispose();
    bridge.pending.last.complete(_wifi);
    await last;
    bridge.events.add(_wifi);
    expect(state.value, _offline);
    expect(notifications, 3);
    await bridge.events.close();
  });
}
