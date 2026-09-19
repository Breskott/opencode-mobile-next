/// The one saved server that stands for Claude Code on this phone.
///
/// The daemon `claude.sh` runs is reached at a fixed loopback address, so
/// there is never more than one saved server for it: connecting again
/// updates that server (a new project folder, a refreshed password) rather
/// than adding a second one a person would then have to tell apart.
library;

import '../termux/bridge.dart';
import '../termux/local_agent_runtime.dart';
import 'profiles.dart';

/// Whether [profile] is the saved server for the daemon on this phone.
bool isLocalAgentProfile(ServerProfile profile) {
  if (profile.backend != ServerBackend.paseo) return false;
  final uri = Uri.tryParse(profile.baseUrl.trim());
  if (uri == null || uri.scheme != 'ws') return false;
  final port = uri.hasPort ? uri.port : 80;
  return uri.host == '127.0.0.1' && port == TermuxBridge.localAgentsPort;
}

/// The saved server for the daemon on this phone, if there is one.
ServerProfile? savedLocalAgentProfile(List<ServerProfile> profiles) {
  for (final profile in profiles) {
    if (isLocalAgentProfile(profile)) return profile;
  }
  return null;
}

/// A typed project path must be absolute and free of `.`/`..` segments: it
/// is a path inside Ubuntu, handed to a shell verb and to the daemon.
String? localAgentProjectPathProblem(String value) {
  final path = value.trim();
  if (path.isEmpty || !path.startsWith('/')) return 'not-absolute';
  if (path.contains('\n') || path.contains('\x00')) return 'not-absolute';
  for (final segment in path.split('/')) {
    if (segment == '.' || segment == '..') return 'not-absolute';
  }
  return validateCodexProjectDirectory(path);
}

/// Creates the saved server for the daemon, or updates the one that exists,
/// and returns it. [directory] is the project path as Ubuntu sees it.
///
/// The password comes from the script's `password` verb and goes straight
/// into the profile's secret (secure storage). It is never logged, shown or
/// placed in an error message.
Future<ServerProfile> saveLocalAgentProfile({
  required ProfileStore store,
  required LocalAgentRuntime runtime,
  required String name,
  required String directory,
  DateTime Function() now = DateTime.now,
}) async {
  final password = await runtime.password();
  final existing = savedLocalAgentProfile(store.profiles);
  final profile =
      existing ??
      ServerProfile(
        id: now().microsecondsSinceEpoch.toString(),
        name: name,
        baseUrl: TermuxBridge.localAgentsUrl,
        backend: ServerBackend.paseo,
      );
  profile
    ..baseUrl = TermuxBridge.localAgentsUrl
    ..backend = ServerBackend.paseo
    ..codexToken = password
    ..codexDirectory = directory.trim()
    ..requiresCodexTokenReentry = false;
  // A person may have renamed it; only a server this call creates is named.
  if (existing == null) profile.name = name;
  await store.upsert(profile);
  return profile;
}
