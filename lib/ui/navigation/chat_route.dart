class ChatRouteArguments {
  const ChatRouteArguments({
    this.discardIfUntouched = false,
    this.focusComposer = false,
  });

  const ChatRouteArguments.newlyCreated()
    : discardIfUntouched = true,
      focusComposer = false;

  /// The conversation first run lands in: new, and with the keyboard already
  /// up, because typing the first message is the only thing left to do.
  const ChatRouteArguments.firstRun()
    : discardIfUntouched = true,
      focusComposer = true;

  final bool discardIfUntouched;
  final bool focusComposer;
}
