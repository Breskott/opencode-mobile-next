// A server plugin's name for people (docs/design/phone-server-screens-
// cleanup-2026-09-24.md §3): the server reports only an id, so Settings ›
// Plugins shows a readable form of its last part.
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/screens/settings/server_plugins_section.dart';

void main() {
  test('a plugin id reads as a plain name', () {
    expect(readablePluginName('opencode.tool.input.repair'), 'Input repair');
    expect(readablePluginName('opencode.config.worktree'), 'Worktree');
    expect(readablePluginName('opencode.browser'), 'Browser');
    expect(readablePluginName('opencode.config.mcp'), 'MCP');
    expect(readablePluginName('@acme/opencode-wakatime'), 'Wakatime');
    expect(readablePluginName('opencode-foo@1.2.3'), 'Foo');
    expect(readablePluginName('reviewer'), 'Reviewer');
    expect(readablePluginName('opencode.tool.webFetch'), 'Web fetch');
  });

  test('an id with nothing readable left is shown as it is', () {
    expect(readablePluginName('...'), '...');
    expect(readablePluginName('---'), '---');
  });
}
