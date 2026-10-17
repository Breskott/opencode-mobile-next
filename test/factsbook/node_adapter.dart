import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// A node stand-in for gateway and session tests: answers from a table keyed
/// `METHOD /path` and records every request.
class NodeCall {
  NodeCall(this.method, this.uri, this.headers, this.body);
  final String method;
  final Uri uri;
  final Map<String, dynamic> headers;
  final Object? body;
}

typedef NodeReply = ({int status, Object? body});

/// A node that answers from a table keyed `METHOD /path`.
class NodeAdapter implements HttpClientAdapter {
  final calls = <NodeCall>[];
  final replies = <String, List<NodeReply>>{};
  Object? failWith;

  void reply(String key, Object? body, {int status = 200}) =>
      (replies[key] ??= []).add((status: status, body: body));

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    Object? body;
    if (options.data is String) {
      body = jsonDecode(options.data as String);
    }
    calls.add(NodeCall(options.method, options.uri, options.headers, body));
    if (failWith != null) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'refused',
      );
    }
    final key = '${options.method} ${options.uri.path}';
    final list = replies[key];
    if (list == null || list.isEmpty) {
      return ResponseBody.fromString('', 404);
    }
    final next = list.length > 1 ? list.removeAt(0) : list.first;
    final text = next.body is String
        ? next.body as String
        : jsonEncode(next.body);
    return ResponseBody.fromString(
      text,
      next.status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}
