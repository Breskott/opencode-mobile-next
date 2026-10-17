// The shared fake app scope: everything a real screen needs to be pumped
// without a server, a phone or a Keystore. Modelled on how the tests pump
// screens (test/server_capabilities_screen_test.dart and
// test/support/usage_ui_harness.dart).
//
//   * [FakeApp.create] builds a real ProfileStore over in-memory preferences
//     and an in-memory Keystore, and a real ConnectionController over it.
//     Profiles, the connection state and the server capabilities are
//     arguments.
//   * [FakePlatform] pins PlatformCapabilities to Android or to a browser.
//   * [FakeAppScene] builds one of these asynchronously, pins the platform
//     for the life of the use-case, shows the real screen and cleans up.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/host/byo_host_signer.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'secure_storage.dart';

/// Which platform a use-case pretends to run on.
enum FakePlatform {
  /// A phone: the Android-only rows (quiet hours, Wi-Fi, Termux) exist.
  android,

  /// A browser: what the web shell shows.
  web,

  /// Whatever the catalog itself runs on (a browser, with no pin).
  none;

  PlatformCapabilities? get capabilities => switch (this) {
    FakePlatform.android => const PlatformCapabilities.android(),
    FakePlatform.web => const PlatformCapabilities(
      platform: TargetPlatform.android,
      isWeb: true,
    ),
    FakePlatform.none => null,
  };
}

/// Something a scene owns and releases when the use-case closes.
abstract interface class SceneResource {
  void dispose();
}

/// One saved server for [FakeApp.create].
class FakeProfile {
  const FakeProfile(this.id, this.name, {this.url, this.username = ''});
  final String id;
  final String name;
  final String? url;
  final String username;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'baseUrl': url ?? 'http://$id.example:4096',
    'username': username,
  };
}

class _NoSigner implements ByoHostSigner {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeApi extends OpenCodeApi {
  _FakeApi(this._capabilities) : super(baseUrl: 'http://localhost');
  final ServerCapabilities _capabilities;

  @override
  ServerCapabilities get capabilities => _capabilities;
}

class _FakeRepository implements ProductRepository {
  @override
  void setLocation({String? directory, String? workspace}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A real [ConnectionController] over fake storage.
class FakeApp implements SceneResource {
  FakeApp._(this.store, this.connection);

  final ProfileStore store;
  final ConnectionController connection;

  /// [profiles] are the saved servers (the first is active). With
  /// [connected], the controller reports a live connection whose server has
  /// [capabilities]; repository calls are not answered, so screens that list
  /// server data need their own fake in the use-case.
  static Future<FakeApp> create({
    List<FakeProfile> profiles = const [FakeProfile('main', 'Workstation')],
    bool connected = false,
    ServerCapabilities capabilities = ServerCapabilities.allV1,
    Map<String, Object> prefs = const {},
    // A fake server's transport, operations and controller (fake_gateway.dart).
    OpenCodeApi? api,
    ProductRepository? repository,
    ConnectionController Function(ProfileStore store)? controllerFactory,
  }) async {
    // The package offers no other in-memory store; the catalog has no device.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({
      'oc.profiles': jsonEncode([for (final p in profiles) p.toJson()]),
      if (profiles.isNotEmpty) 'oc.activeProfile': profiles.first.id,
      ...prefs,
    });
    final store = ProfileStore(
      prefs: await SharedPreferences.getInstance(),
      secure: MemorySecureStorage(),
      // Both defaults read dart:io's Platform, which a browser does not have.
      byoHostSigner: _NoSigner(),
      agentHostCleanup: (_) async {},
    );
    await store.load();
    final connection =
        controllerFactory?.call(store) ?? ConnectionController(store);
    if (connected) {
      connection
        ..api = api ?? _FakeApi(capabilities)
        ..repository = repository ?? _FakeRepository()
        ..status = StreamStatus.connected;
    }
    return FakeApp._(store, connection);
  }

  @override
  void dispose() => connection.dispose();
}

/// Builds a [SceneResource] (a [FakeApp] or a harness on top of one), then
/// shows the real screen [builder] returns.
///
/// [autoTap] presses the widget with that key once the screen has settled, for
/// states a person reaches by tapping (a result that follows a button).
class FakeAppScene<T extends SceneResource> extends StatefulWidget {
  const FakeAppScene({
    super.key,
    required this.create,
    required this.builder,
    this.autoTap,
    this.platform = FakePlatform.none,
  });

  final Future<T> Function() create;
  final Widget Function(BuildContext context, T resource) builder;
  final String? autoTap;
  final FakePlatform platform;

  @override
  State<FakeAppScene<T>> createState() => _FakeAppSceneState<T>();
}

class _FakeAppSceneState<T extends SceneResource>
    extends State<FakeAppScene<T>> {
  T? _resource;
  bool _disposed = false;
  String? _failure;

  @override
  void initState() {
    super.initState();
    // ignore: invalid_use_of_visible_for_testing_member
    debugPlatformCapabilities = widget.platform.capabilities;
    unawaited(_start());
  }

  Future<void> _start() async {
    final T resource;
    try {
      resource = await widget.create();
    } catch (error, stack) {
      debugPrint('Scene failed: $error\n$stack');
      if (mounted) setState(() => _failure = '$error');
      return;
    }
    if (_disposed) {
      resource.dispose();
      return;
    }
    setState(() => _resource = resource);
    final key = widget.autoTap;
    if (key != null) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (mounted) _tap(ValueKey(key));
    }
  }

  void _tap(Key key) {
    RenderBox? box;
    void visit(Element element) {
      if (box != null) return;
      if (element.widget.key == key) {
        final object = element.renderObject;
        if (object is RenderBox && object.hasSize) box = object;
        return;
      }
      element.visitChildren(visit);
    }

    (context as Element).visitChildren(visit);
    final target = box;
    if (target == null) return;
    final at = target.localToGlobal(target.size.center(Offset.zero));
    final binding = GestureBinding.instance;
    binding.handlePointerEvent(PointerDownEvent(position: at, pointer: 9001));
    binding.handlePointerEvent(PointerUpEvent(position: at, pointer: 9001));
  }

  @override
  void dispose() {
    _disposed = true;
    // ignore: invalid_use_of_visible_for_testing_member
    debugPlatformCapabilities = null;
    _resource?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failure != null) {
      return Center(child: Text('Fake data failed: $_failure'));
    }
    final resource = _resource;
    if (resource == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return widget.builder(context, resource);
  }
}
