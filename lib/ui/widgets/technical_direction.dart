import 'package:flutter/widgets.dart';

/// Isolates actual code, commands, paths and URLs from surrounding RTL chrome.
/// Do not wrap user prose, server descriptions or whole mixed-content cards.
class TechnicalDirection extends StatelessWidget {
  const TechnicalDirection({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Directionality(textDirection: TextDirection.ltr, child: child);
}
