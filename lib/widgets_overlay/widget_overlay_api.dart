import '../background/widget_v2_contract.dart';

/// What the floating widget screens ask of the phone. The real one is the
/// `oc/widgets` channel ([WidgetOverlayPort]); tests pass a fake.
abstract interface class WidgetOverlayApi {
  Future<Map<String, dynamic>> getLaunchArguments();
  Future<void> saveStyle({required String background, required String accent});
  Future<String> dictate({String? languageTag});
  Future<Map<String, dynamic>> submitAction(String text);
  Future<void> close();
}

class PortWidgetOverlayApi implements WidgetOverlayApi {
  const PortWidgetOverlayApi();
  @override
  Future<Map<String, dynamic>> getLaunchArguments() =>
      WidgetOverlayPort.getLaunchArguments();
  @override
  Future<void> saveStyle({
    required String background,
    required String accent,
  }) => WidgetOverlayPort.saveStyle(background: background, accent: accent);
  @override
  Future<String> dictate({String? languageTag}) =>
      WidgetOverlayPort.dictate(languageTag: languageTag);
  @override
  Future<Map<String, dynamic>> submitAction(String text) =>
      WidgetOverlayPort.submitAction(text);
  @override
  Future<void> close() => WidgetOverlayPort.close();
}
