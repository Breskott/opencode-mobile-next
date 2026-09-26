import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../kit/chat/kit_agent_strip.dart';

/// Retired by kit-KitAgentStrip: use KitAgentTint.
///
/// A server agent colour (`#rgb`, a colour name or a theme token) resolved
/// to the agents' one neutral tint: identity is carried by the name, never
/// by colour (KitAgentStrip.md, Open question 1). [raw] is accepted and
/// ignored until the owner decides otherwise.
Color agentColor(String? raw, ColorScheme scheme) =>
    KitAgentTint.ofScheme(scheme, name: '', serverColor: raw);

/// Agent name → raw server colour, for widgets that only know an agent by
/// name (a `task` tool card naming its subagent). Hosts that hold the agent
/// catalogue wrap the transcript in one; the colour is passed through to
/// [KitAgentTint], which keeps it in the data.
class AgentColorScope extends InheritedWidget {
  const AgentColorScope({
    super.key,
    required this.colors,
    required super.child,
  });

  final Map<String, String?> colors;

  static AgentColorScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AgentColorScope>();

  String? rawColorOf(String name) {
    if (colors[name] case final raw?) return raw;
    final lower = name.toLowerCase();
    for (final entry in colors.entries) {
      if (entry.key.toLowerCase() == lower) return entry.value;
    }
    return null;
  }

  @override
  bool updateShouldNotify(AgentColorScope oldWidget) =>
      !mapEquals(colors, oldWidget.colors);
}

/// Retired by kit-KitAgentStrip: use KitAgentTint.
///
/// Colour for an agent known only by name: [KitAgentTint.of], given the
/// server colour from the nearest [AgentColorScope] when there is one.
Color agentColorFor(BuildContext context, String name) => KitAgentTint.of(
  context,
  name: name,
  serverColor: AgentColorScope.maybeOf(context)?.rawColorOf(name),
);

/// Retired by kit-KitAgentStrip: use KitAgentTint.
///
/// The tint for an agent name with no configured colour.
Color agentFallbackColor(String name, ColorScheme scheme) =>
    KitAgentTint.ofScheme(scheme, name: name);
