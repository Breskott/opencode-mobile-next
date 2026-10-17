import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_sdk/opencode_sdk.dart' as sdk;

PromptAttachment _file(String path) =>
    PromptAttachment.projectFile(directory: '/srv/app', relativePath: path);

void main() {
  test('a mentioned file goes as the SDK file part the TUI sends', () {
    const text = 'Explain @lib/server.dart please';
    final resolved = resolveFileMentions(text, [_file('lib/server.dart')]);

    expect(resolved, hasLength(1));
    final json = resolved.single.toJson();
    // The generated model accepts it as is.
    final part = sdk.FilePartInput.fromJson(json);
    expect(part.type, sdk.FilePartInputTypeEnum.file);
    expect(part.mime, 'text/plain');
    expect(part.filename, 'server.dart');
    expect(part.url, 'file:///srv/app/lib/server.dart');
    final source = sdk.FileSource.fromJson(part.source_!.objectValue!);
    expect(source.type, sdk.FileSourceTypeEnum.file);
    expect(source.path, 'lib/server.dart');
    expect(source.text.value, '@lib/server.dart');
    expect(source.text.start, 8);
    expect(source.text.end, 24);
    expect(
      text.substring(source.text.start.toInt(), source.text.end.toInt()),
      '@lib/server.dart',
    );
  });

  test('a mention the person deleted before Send sends no file part', () {
    final resolved = resolveFileMentions('Explain it', [
      _file('lib/server.dart'),
    ]);
    expect(resolved, isEmpty);
  });

  test('a path that only starts like the mention does not count', () {
    expect(
      resolveFileMentions('see @lib/server.dartx', [_file('lib/server.dart')]),
      isEmpty,
    );
    expect(
      resolveFileMentions('mail a@lib/server.dart', [_file('lib/server.dart')]),
      isEmpty,
    );
  });

  test('other attachments pass through and an unranged file has no source', () {
    const photo = PromptAttachment(
      mime: 'image/png',
      filename: 'a.png',
      url: 'data:image/png;base64,AA==',
    );
    expect(resolveFileMentions('hi', [photo]), [photo]);
    expect(_file('a.dart').toJson().containsKey('source'), isFalse);
  });
}
