import 'package:flutter/material.dart';

import 'kit_progress.dart';

/// A screen's body (design standard §1, §4): an optional fixed [header],
/// the one [KitLoadingBar] right under it, the scrolling [body], and an
/// optional [bottom] block (the primary button) pinned below the list
/// rather than over it. The bottom block is padded by what the shell
/// publishes at the bottom (a floating tab bar, the gesture inset), so the
/// last row always scrolls clear of the button and of the tab bar. No
/// screen pads for these by hand.
class KitScreen extends StatelessWidget {
  const KitScreen({
    super.key,
    required this.body,
    this.header = const [],
    this.loading = false,
    this.loadingLabel = '',
    this.bottom,
  });

  /// Fixed rows above the loading bar: the screen's own header.
  final List<Widget> header;
  final bool loading;
  final String loadingLabel;

  /// The single scroll view. End it with [endSpacer] when there is no
  /// [bottom] block, so its last row clears the shell's bottom bar.
  final Widget body;
  final Widget? bottom;

  /// Space after the last row when nothing is pinned below the list.
  static double endPadding(BuildContext context) =>
      16 + MediaQuery.paddingOf(context).bottom;

  @override
  Widget build(BuildContext context) {
    final bottom = this.bottom;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...header,
        KitLoadingBar(loading: loading, label: loadingLabel),
        Expanded(child: body),
        if (bottom != null)
          Padding(
            key: const ValueKey('kit-screen-bottom'),
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              8 + MediaQuery.paddingOf(context).bottom,
            ),
            child: bottom,
          ),
      ],
    );
  }
}
