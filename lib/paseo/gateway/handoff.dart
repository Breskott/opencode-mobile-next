part of '../gateway.dart';

const _handoffIgnore = '# OpenCode Mobile conversation handoff\n*\n';

extension _PaseoHandoff on PaseoGateway {
  Future<String> _writeAgentHandoff({
    required String directory,
    required String recordId,
    required String markdown,
  }) async {
    if (!capabilities.agentHandoffFiles ||
        directory != _scope ||
        !RegExp(r'^[a-zA-Z0-9_-]{1,128}$').hasMatch(recordId) ||
        markdown.isEmpty ||
        KitRedact.opaqueTokens(KitRedact.text(markdown)) != markdown ||
        utf8.encode(markdown).length > 98304) {
      throw PaseoFailure(PaseoFailureKind.unavailable);
    }
    final scope = _scope;
    final locationEpoch = _locationEpoch;
    final connectionEpoch = transport.epoch;
    void check() {
      _checkLocation(scope, locationEpoch);
      if (!capabilities.agentHandoffFiles ||
          transport.epoch != connectionEpoch) {
        throw PaseoFailure(PaseoFailureKind.staleRequest);
      }
    }

    Future<Map<String, dynamic>> request(
      String type,
      Map<String, dynamic> body, {
      bool mutation = false,
    }) async {
      check();
      final result = await transport.request(
        type,
        {'cwd': scope, ...body},
        mutation: mutation,
        answerErrors: true,
        expectedEpoch: connectionEpoch,
        beforeSend: check,
      );
      check();
      return result;
    }

    Future<bool> create(String parent, String name, String kind) async {
      final result = await request('fs.entry.create.request', {
        'parentPath': parent,
        'name': name,
        'kind': kind,
      }, mutation: true);
      final path = parent == '.' ? name : '$parent/$name';
      if (result['cwd'] != scope || result['parentPath'] != parent) {
        throw PaseoFailure(PaseoFailureKind.invalidResponse);
      }
      if (result['success'] == true && result['path'] == path) return true;
      return false;
    }

    Future<Map<String, dynamic>> read(String path) async {
      final result = await request('file_explorer_request', {
        'path': path,
        'mode': 'file',
        'maxBytes': 98304,
      });
      final file = result['file'];
      if (result['error'] != null ||
          result['cwd'] != scope ||
          result['path'] != path ||
          file is! Map<String, dynamic> ||
          file['path'] != path ||
          file['kind'] != 'text' ||
          file['encoding'] != 'utf-8' ||
          file['content'] is! String ||
          file['modifiedAt'] is! String) {
        throw PaseoFailure(PaseoFailureKind.invalidResponse);
      }
      return file;
    }

    Future<void> writeNew(String parent, String name, String content) async {
      if (!await create(parent, name, 'file')) {
        throw PaseoFailure(PaseoFailureKind.unavailable);
      }
      final path = '$parent/$name';
      final empty = await read(path);
      if (empty['content'] != '') {
        throw PaseoFailure(PaseoFailureKind.unavailable);
      }
      final result = await request('fs.file.write.request', {
        'path': path,
        'content': content,
        'expectedModifiedAt': empty['modifiedAt'],
        if (empty['revision'] is String) 'expectedRevision': empty['revision'],
      }, mutation: true);
      final outcome = result['result'];
      if (outcome is! Map || outcome['status'] != 'written') {
        throw PaseoFailure(PaseoFailureKind.unavailable);
      }
      if ((await read(path))['content'] != content) {
        throw PaseoFailure(PaseoFailureKind.invalidResponse);
      }
    }

    // Never alter an existing ignore file. Every transfer gets an exclusively
    // created directory, with its own ignore rule installed before its record.
    if (!await create('.', '.handoff', 'directory')) {
      final listing = await request('file_explorer_request', {
        'path': '.',
        'mode': 'list',
      });
      final folder = listing['directory'];
      final entries = folder is Map ? folder['entries'] : null;
      if (listing['error'] != null ||
          listing['cwd'] != scope ||
          listing['path'] != '.' ||
          entries is! List ||
          !entries.any(
            (entry) =>
                entry is Map &&
                entry['name'] == '.handoff' &&
                entry['kind'] == 'directory',
          )) {
        throw PaseoFailure(PaseoFailureKind.unavailable);
      }
    }
    final folder = '.handoff/$recordId';
    if (!await create('.handoff', recordId, 'directory')) {
      throw PaseoFailure(PaseoFailureKind.unavailable);
    }
    await writeNew(folder, '.gitignore', _handoffIgnore);
    await writeNew(folder, 'record.md', markdown);
    return '$folder/record.md';
  }
}
