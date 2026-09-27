import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../ui/kit/kit_redact.dart';

/// Metadata only: registry content is untrusted and is never executed.
class RegistryEntry {
  RegistryEntry._({
    required this.name,
    required this.version,
    required this.description,
    required this.remotes,
    required this.packages,
  });

  final String name;
  final String version;
  final String description;
  final List<RegistryRemote> remotes;
  final List<RegistryPackage> packages;
  String get id => '$name@$version';

  /// The UI must still ask the user to select the endpoint and review a diff.
  RegistryRemote? get connectableRemote =>
      remotes.where((remote) => !remote.requiresConfiguration).firstOrNull;

  String? get unsupportedReason {
    if (connectableRemote != null) return null;
    if (remotes.isNotEmpty) {
      return 'This server needs connection details. Set it up by hand.';
    }
    if (packages.isNotEmpty) {
      return 'Package installation needs a reviewed command on your server. Set it up by hand.';
    }
    return 'This listing has no supported HTTPS endpoint. Set it up by hand.';
  }

  static RegistryEntry? fromJson(Object? value) {
    if (value is! Map) return null;
    final name = _identifier(value['name']);
    final version = _identifier(value['version']);
    if (name == null || version == null) return null;
    return RegistryEntry._(
      name: name,
      version: version,
      description: _safeText(value['description'], 1000),
      remotes: List.unmodifiable([
        for (final item in _items(value['remotes']))
          ?RegistryRemote.fromJson(item),
      ]),
      packages: List.unmodifiable([
        for (final item in _items(value['packages']))
          ?RegistryPackage.fromJson(item),
      ]),
    );
  }

  Map<String, Object?> toJson() => {
    'name': KitRedact.text(name),
    'version': KitRedact.text(version),
    'description': KitRedact.text(description),
    'remotes': remotes.map((entry) => entry.toJson()).toList(),
    'packages': packages.map((entry) => entry.toJson()).toList(),
  };
}

class RegistryRemote {
  RegistryRemote._(this.type, this.url, this.requiresConfiguration);
  final String type;
  final String url;

  /// Registry header/variable declarations are deliberately not retained.
  /// This is not evidence that OAuth is supported or that sign-in is required.
  final bool requiresConfiguration;

  static RegistryRemote? fromJson(Object? value) {
    if (value is! Map) return null;
    final type = value['type'];
    final raw = value['url'];
    if (type != 'streamable-http' && type != 'sse') return null;
    if (raw is! String || raw.length > 2048) return null;
    final url = Uri.tryParse(raw);
    if (url == null ||
        url.scheme != 'https' ||
        url.host.isEmpty ||
        url.userInfo.isNotEmpty ||
        url.hasQuery ||
        url.hasFragment ||
        raw.contains(RegExp(r'[{}\s]')) ||
        _unsafeEncodedUrl(raw)) {
      return null;
    }
    return RegistryRemote._(
      type as String,
      KitRedact.text(raw),
      value['requiresConfiguration'] == true ||
          (value['headers'] is List && (value['headers'] as List).isNotEmpty) ||
          (value['variables'] is Map && (value['variables'] as Map).isNotEmpty),
    );
  }

  /// A disabled candidate only. Applying it still needs the setup controller's
  /// validation, explicit confirmation and server capability checks.
  Map<String, Object?> toMcpConfig() {
    if (requiresConfiguration) {
      throw const SetupRegistryException(
        'This server needs connection details. Set it up by hand.',
      );
    }
    return {'type': 'remote', 'url': url, 'enabled': false};
  }

  Map<String, Object?> toJson() => {
    'type': KitRedact.text(type),
    'url': KitRedact.text(url),
    'requiresConfiguration': requiresConfiguration,
  };
}

class RegistryPackage {
  RegistryPackage._(this.registryType, this.identifier, this.version);
  final String registryType;
  final String identifier;
  final String version;

  static RegistryPackage? fromJson(Object? value) {
    if (value is! Map) return null;
    final type = _identifier(value['registryType']);
    final identifier = _identifier(value['identifier']);
    final version = _identifier(value['version']);
    if (type == null || identifier == null || version == null) return null;
    return RegistryPackage._(type, identifier, version);
  }

  Map<String, Object?> toJson() => {
    'registryType': KitRedact.text(registryType),
    'identifier': KitRedact.text(identifier),
    'version': KitRedact.text(version),
  };
}

/// Contains only fixed application copy, never an HTTP body or raw exception.
class SetupRegistryException implements Exception {
  const SetupRegistryException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Explicitly invoked, unauthenticated, single-page public catalog request.
/// Never pass a server's authenticated Dio to this client.
class SetupRegistryClient {
  SetupRegistryClient({HttpClientAdapter? adapter})
    : _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15))) {
    if (adapter != null) _dio.httpClientAdapter = adapter;
  }

  static const endpoint =
      'https://registry.modelcontextprotocol.io/v0.1/servers';
  static const maxResponseBytes = 512 * 1024;
  static const maxEntries = 100;
  final Dio _dio;

  Future<List<RegistryEntry>> fetch({CancelToken? cancelToken}) async {
    try {
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      final response = await _dio
          .get<ResponseBody>(
            endpoint,
            queryParameters: const {'limit': maxEntries, 'version': 'latest'},
            cancelToken: cancelToken,
            options: Options(
              responseType: ResponseType.stream,
              followRedirects: false,
              maxRedirects: 0,
              receiveTimeout: const Duration(seconds: 15),
              sendTimeout: const Duration(seconds: 15),
              headers: const {'Accept': 'application/json'},
              validateStatus: (status) => status == 200,
            ),
          )
          .timeout(const Duration(seconds: 20));
      final body = response.data;
      if (body == null) throw const FormatException();
      final builder = BytesBuilder(copy: false);
      await for (final chunk in body.stream.timeout(
        const Duration(seconds: 15),
      )) {
        if (builder.length + chunk.length > maxResponseBytes ||
            DateTime.now().isAfter(deadline)) {
          throw const FormatException();
        }
        builder.add(chunk);
      }
      final decoded = jsonDecode(utf8.decode(builder.takeBytes()));
      if (decoded is! Map || decoded['servers'] is! List) {
        throw const FormatException();
      }
      final result = <RegistryEntry>[];
      for (final item in (decoded['servers'] as List).take(maxEntries)) {
        if (item is! Map) continue;
        final meta = item['_meta'];
        final official = meta is Map
            ? meta['io.modelcontextprotocol.registry/official']
            : null;
        if (official is Map &&
            (official['status'] == 'deleted' ||
                official['status'] == 'deprecated')) {
          continue;
        }
        final entry = RegistryEntry.fromJson(item['server']);
        if (entry != null) result.add(entry);
      }
      return List.unmodifiable(result);
    } catch (_) {
      throw const SetupRegistryException(
        'The public registry could not be loaded. Try again or set up by hand.',
      );
    }
  }

  void dispose() => _dio.close(force: true);
}

Iterable<Object?> _items(Object? value) =>
    value is List ? value.take(10) : const [];

String _safeText(Object? value, int limit) {
  if (value is! String) return '';
  final safe = KitRedact.text(value).replaceAll(RegExp(r'[\x00-\x1f]'), ' ');
  return safe.length > limit ? safe.substring(0, limit) : safe;
}

String? _identifier(Object? value) {
  if (value is! String || value.isEmpty || value.length > 256) return null;
  // Identifiers are metadata, never URLs, command lines or credential values.
  if (!RegExp(r'^[A-Za-z0-9@._/+-]+$').hasMatch(value) ||
      KitRedact.containsSecret(value)) {
    return null;
  }
  return KitRedact.text(value);
}

bool _unsafeEncodedUrl(String value) {
  try {
    return KitRedact.containsSecret(Uri.decodeFull(value));
  } catch (_) {
    return true;
  }
}
