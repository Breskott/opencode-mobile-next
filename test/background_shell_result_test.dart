import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/domain/background_shell_result.dart';

Part _notice(String text, {String? filename}) => Part(
  id: 'n',
  type: 'v2:notice',
  toolName: 'synthetic',
  filename: filename,
  text: text,
);

void main() {
  test('reads the command, the output and how it ended', () {
    final result = BackgroundShellResult.fromPart(
      _notice(
        '<shell id="sh_1" state="completed" command="/tmp/opencode/flutter/'
        'bin/flutter test --concurrency=1 test/a_test.dart">\n'
        '00:07 +6: All tests passed!\n\n'
        'Command exited with code 0.\n</shell>',
      ),
    )!;
    expect(result.command, startsWith('/tmp/opencode/flutter/bin/flutter'));
    expect(result.output, '00:07 +6: All tests passed!');
    expect(result.exitCode, 0);
    expect(result.outcome, BackgroundShellOutcome.finished);
  });

  test('a non-zero exit failed; a signal is someone stopping it', () {
    BackgroundShellResult read(int code) => BackgroundShellResult.parse(
      '<shell id="s" state="completed" command="make">x\n'
      'Command exited with code $code.</shell>',
    )!;
    expect(read(1).outcome, BackgroundShellOutcome.failed);
    expect(read(143).outcome, BackgroundShellOutcome.stopped);
  });

  test('escaped quotes in the command are read back', () {
    final result = BackgroundShellResult.parse(
      '<shell state="completed" command="echo &quot;hi &amp; bye&quot;">'
      'hi</shell>',
    )!;
    expect(result.command, 'echo "hi & bye"');
  });

  test('anything else is not a shell result', () {
    expect(BackgroundShellResult.fromPart(_notice('Context added')), isNull);
    expect(
      BackgroundShellResult.fromPart(
        Part(id: 't', type: 'text', text: '<shell command="x">y</shell>'),
      ),
      isNull,
    );
  });
}
