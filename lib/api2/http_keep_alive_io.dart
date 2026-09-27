import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// Retains native connections through a brief reading/navigation pause.
void configureHttpKeepAlive(Dio dio) {
  if (dio.httpClientAdapter case IOHttpClientAdapter adapter) {
    // Dio 5.11.1 creates this same default client with a three-second idle
    // timeout and no proxy override. Only the idle timeout changes here;
    // adapter ownership, TLS/proxy defaults and force-close behavior remain.
    adapter.createHttpClient = () =>
        HttpClient()..idleTimeout = const Duration(seconds: 15);
  }
}
