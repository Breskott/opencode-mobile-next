// Paseo's usage reader finds Claude's sign-in in $CLAUDE_HOME (or
// ~/.claude), not in CLAUDE_CONFIG_DIR. Every agent process the built-in
// Linux starts must set both, or the Usage widget never shows Claude
// (owner's phone, APK 2228).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every agent launch that sets CLAUDE_CONFIG_DIR sets CLAUDE_HOME to '
      'the same folder', () {
    final source = File(
      'android/app/src/main/kotlin/io/github/eslamasabry/opencode_mobile/BuiltinLinux.kt',
    ).readAsStringSync();
    final launches = RegExp(
      r'listOf\("/usr/bin/env", "HOME=\$guestHome", "CLAUDE_CONFIG_DIR=\$guestHome/claude",\s*"CLAUDE_HOME=\$guestHome/claude",',
    ).allMatches(source).length;
    final configDirs = RegExp(
      r'"CLAUDE_CONFIG_DIR=\$guestHome/claude"',
    ).allMatches(source).length;
    expect(configDirs, greaterThan(0));
    expect(launches, configDirs);
  });
}
