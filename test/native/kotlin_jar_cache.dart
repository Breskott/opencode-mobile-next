import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// Compiles [sources] with [compiler] into a jar, reusing an earlier build of
/// byte-identical sources, arguments and compiler (kotlinc costs 7 to 12 s a
/// time). The cache lives in the system temp directory; a fresh checkout or a
/// changed source compiles again, so a stale jar never hides a break.
///
/// Returns the jar's path, or throws with the compiler's message.
Future<String> cachedKotlinJar({
  required String compiler,
  required List<String> sources,
  List<String> extraArgs = const [],
}) async {
  final key = sha256.convert(
    utf8.encode(
      [
        compiler,
        ...extraArgs,
        for (final source in sources) ...[
          source,
          sha256.convert(File(source).readAsBytesSync()).toString(),
        ],
      ].join('\n'),
    ),
  );
  final cache = Directory('${Directory.systemTemp.path}/oc-kotlin-jar-cache')
    ..createSync(recursive: true);
  final jar = '${cache.path}/$key.jar';
  if (File(jar).existsSync()) return jar;
  final partial = '${cache.path}/$key.$pid.part.jar';
  final result = await Process.run(compiler, [
    ...sources,
    ...extraArgs,
    '-include-runtime',
    '-d',
    partial,
  ]);
  if (result.exitCode != 0) {
    throw StateError('kotlinc failed: ${result.stderr}');
  }
  // Atomic: a parallel run either sees the whole jar or none.
  File(partial).renameSync(jar);
  return jar;
}
