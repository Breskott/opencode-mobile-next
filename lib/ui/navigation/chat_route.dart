class ChatRouteArguments {
  const ChatRouteArguments({
    this.discardIfUntouched = false,
    this.focusComposer = false,
    this.landOnRequestID,
    this.landOnFailure = false,
  });

  const ChatRouteArguments.newlyCreated()
    : discardIfUntouched = true,
      focusComposer = false,
      landOnRequestID = null,
      landOnFailure = false;

  /// The conversation first run lands in: new, and with the keyboard already
  /// up, because typing the first message is the only thing left to do.
  const ChatRouteArguments.firstRun()
    : discardIfUntouched = true,
      focusComposer = true,
      landOnRequestID = null,
      landOnFailure = false;

  final bool discardIfUntouched;
  final bool focusComposer;

  /// P4.2a: the waiting request (permission, question or form) the chat
  /// opens on: its card leads and is marked once.
  final String? landOnRequestID;

  /// P4.2a: the chat opens on its newest failed turn.
  final bool landOnFailure;
}

/// The [KitArrival] id of a request card in a chat (P4.2a), so a door that
/// opens the chat for one request lands on exactly that card.
String chatRequestArrivalId(String requestID) => 'chat-request-$requestID';
