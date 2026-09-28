// Prints the exact gated component installer for an isolated Ubuntu probe.
import 'dart:io';

import 'package:opencode_mobile/builtin/setup/claude_scripts.dart';
import 'package:opencode_mobile/builtin/setup/setup_scripts.dart';

void main() => stdout.write('$setupPrelude\n${ClaudeScripts.install}');
