import 'dart:convert';

import '../ui/kit/kit_redact.dart';
import 'prompt_shelf.dart';
import 'session_drafts.dart';

/// Rejects an identity/location which redaction would change. Never silently
/// routes a saved prompt or recovered photo to a different owner or directory.
String savedPromptIdentity(String value) {
  if (KitRedact.text(value) != value) {
    throw StateError('Saved prompt identity contains sensitive data');
  }
  return value;
}

Object? _safe(Object? value, [String? key]) {
  if (value is Map) {
    return <String, dynamic>{
      for (final entry in value.entries)
        entry.key as String: _safe(entry.value, entry.key as String),
    };
  }
  if (value is List) return value.map((v) => _safe(v)).toList();
  if (value is! String) return value;
  if (const {
    'id',
    'sessionID',
    'profileID',
    'directory',
    'workspace',
    'blob',
  }.contains(key)) {
    return savedPromptIdentity(value);
  }
  if (key == 'url') {
    final uri = Uri.tryParse(value);
    if (uri?.scheme == 'data') {
      final data = uri!.data!;
      final mime = data.mimeType;
      if (mime.startsWith('text/') ||
          mime == 'application/json' ||
          mime == 'application/xml' ||
          mime == 'application/javascript') {
        return Uri.dataFromString(
          KitRedact.text(utf8.decode(data.contentAsBytes())),
          mimeType: mime,
          encoding: utf8,
          base64: true,
        ).toString();
      }
      // Binary media is opaque; never rewrite encoded image bytes.
    }
    return savedPromptIdentity(value);
  }
  return KitRedact.text(value);
}

/// Redacts persisted copy, metadata, references and text attachment payloads.
/// Opaque binary media is retained byte for byte. No credential is logged.
StashedPrompt sanitizeSavedPrompt(StashedPrompt prompt) =>
    StashedPrompt.fromJson(_safe(prompt.toJson()) as Map<String, dynamic>);

/// Use before publishing a recovered photo into the existing draft index.
SessionDraft sanitizeSessionDraft(SessionDraft draft) =>
    SessionDraft.fromJson(_safe(draft.toJson()))!;
