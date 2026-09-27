import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'kit_status_line.dart';
import 'motion/kit_reveal.dart';

/// App-wide conditions (connection, Android stopped the app, heat, update
/// ready), provided once above the Navigator by main.dart (coord-main).
///
/// States: none — it carries conditions; `KitStatusLineSlot` draws them.
class KitStatusScope extends InheritedWidget {
  const KitStatusScope({
    super.key,
    required this.conditions,
    required super.child,
  });

  final ValueListenable<List<KitStatus>> conditions;

  static final ValueListenable<List<KitStatus>> _none =
      ValueNotifier<List<KitStatus>>(const []);

  /// Empty when no scope is above (tests, galleries).
  static ValueListenable<List<KitStatus>> of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<KitStatusScope>()
          ?.conditions ??
      _none;

  @override
  bool updateShouldNotify(KitStatusScope oldWidget) =>
      conditions != oldWidget.conditions;
}

/// Draws the one line: [KitStatus.highest] over the app-wide conditions,
/// this slot's own [status] and every status contributed from below (ties
/// keep the first: app-wide, then own, then contributions in registration
/// order), rendered with [KitStatusLine.of]. Nothing to show → nothing
/// drawn. The line folds in and out through [KitReveal] (it stays mounted
/// with no child).
///
/// With [child] (coordinator ruling on the KitStatusLine-v2 contract, for
/// KitScreen), the slot also hosts what sits below its line: it draws the
/// line above [child], which fills the rest of the slot's height (give the
/// slot a bounded height), and every [KitStatusContribution] inside [child]
/// reaches this slot. Without [child] only contributions below the line
/// itself reach it.
///
/// States: none drawn / one condition (KitStatusLine's own states).
class KitStatusLineSlot extends StatefulWidget {
  const KitStatusLineSlot({super.key, this.status, this.slotKey, this.child});

  final KitStatus? status;
  final Key? slotKey;

  /// What sits below the line, inside this slot's reach (null: the line
  /// alone).
  final Widget? child;

  /// True when a slot is above [context] (a KitScreen then contributes
  /// instead of drawing).
  static bool existsAbove(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_KitStatusSlotScope>() != null;

  @override
  State<KitStatusLineSlot> createState() => _KitStatusLineSlotState();
}

class _KitStatusLineSlotState extends State<KitStatusLineSlot> {
  /// Contributions in registration order.
  final List<_KitStatusContributionState> _contributions = [];
  bool _rebuildScheduled = false;

  void _register(_KitStatusContributionState contribution) {
    if (_contributions.contains(contribution)) return;
    _contributions.add(contribution);
    _changed();
  }

  void _unregister(_KitStatusContributionState contribution) {
    if (_contributions.remove(contribution)) _changed();
  }

  /// A contribution changes during its own build or teardown, when this
  /// slot cannot rebuild synchronously; it redraws after the frame.
  void _changed() {
    if (_rebuildScheduled || !mounted) return;
    _rebuildScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _rebuildScheduled = false;
      if (mounted) setState(() {});
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  @override
  Widget build(BuildContext context) {
    final conditions = KitStatusScope.of(context);
    final line = KeyedSubtree(
      key: widget.slotKey,
      child: ValueListenableBuilder<List<KitStatus>>(
        valueListenable: conditions,
        builder: (context, appWide, _) {
          final shown = KitStatus.highest([
            ...appWide,
            widget.status,
            for (final contribution in _contributions)
              if (contribution.active) contribution.widget.status,
          ]);
          return KitReveal(
            child: shown == null ? null : KitStatusLine.of(shown),
          );
        },
      ),
    );
    final child = widget.child;
    return _KitStatusSlotScope(
      state: this,
      child: child == null
          ? line
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                line,
                Expanded(child: child),
              ],
            ),
    );
  }
}

class _KitStatusSlotScope extends InheritedWidget {
  const _KitStatusSlotScope({required this.state, required super.child});

  final _KitStatusLineSlotState state;

  @override
  bool updateShouldNotify(_KitStatusSlotScope oldWidget) =>
      state != oldWidget.state;
}

/// Contributes [status] (null = nothing) to the nearest [KitStatusLineSlot]
/// above, for as long as it is mounted and its TickerMode is enabled (an
/// offstage tab stops contributing). Used by KitScreen; public for parts
/// that are not screens (a composer's risky-switch line).
///
/// States: none — it draws only [child].
class KitStatusContribution extends StatefulWidget {
  const KitStatusContribution({
    super.key,
    required this.status,
    required this.child,
  });

  final KitStatus? status;
  final Widget child;

  @override
  State<KitStatusContribution> createState() => _KitStatusContributionState();
}

class _KitStatusContributionState extends State<KitStatusContribution> {
  _KitStatusLineSlotState? _slot;
  bool _enabled = true;

  bool get active => _enabled;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final slot = context
        .dependOnInheritedWidgetOfExactType<_KitStatusSlotScope>()
        ?.state;
    final enabled = TickerMode.valuesOf(context).enabled;
    if (slot != _slot) {
      _slot?._unregister(this);
      _slot = slot;
      _enabled = enabled;
      slot?._register(this);
    } else if (enabled != _enabled) {
      _enabled = enabled;
      slot?._changed();
    }
  }

  @override
  void didUpdateWidget(KitStatusContribution oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) _slot?._changed();
  }

  @override
  void dispose() {
    _slot?._unregister(this);
    _slot = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
