import '../domain/free_model.dart';
import 'connection.dart';

/// [usesOpenCodeFreeModel] for the connected server: the model a new reply
/// in [sessionID] uses (its own choice, else the server's current one),
/// against the providers signed in there.
///
/// The chat and its model chip, This phone and the move from Termux all ask
/// the same question through this one function.
bool connectionUsesFreeModel(
  ConnectionController connection, {
  String? sessionID,
}) {
  if (!connection.hasConnectedServer) return false;
  final model =
      (sessionID == null ? null : connection.sessionModels[sessionID]?.model) ??
      connection.selectedModel;
  return usesOpenCodeFreeModel(
    signedInProviderIDs: [
      for (final provider in connection.providers?.providers ?? const [])
        provider.id,
    ],
    providerID: model?.providerID,
    modelID: model?.modelID,
    models: connection.catalog?.models ?? const [],
  );
}
