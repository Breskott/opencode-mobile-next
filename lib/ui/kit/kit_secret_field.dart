import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_iconography.dart';
import 'kit_icon_button.dart';

/// A field for a secret: a token, a password, a header value
/// (docs/ux-system/kit-v2.md §1.4, the secret kind of KitField, §4.10).
///
/// Masked until the person presses show, never autocorrected or suggested,
/// laid out left to right so a token inside Arabic text never reorders.
/// It never prefills a saved secret: the caller passes an empty controller
/// and says "saved · replace" elsewhere when one exists.
class KitSecretField extends StatefulWidget {
  const KitSecretField({
    super.key,
    required this.controller,
    required this.label,
    required this.showLabel,
    required this.hideLabel,
    this.hint,
    this.enabled = true,
    this.validator,
    this.inputFormatters = const [],
    this.fieldKey,
    this.revealKey,
  });

  final TextEditingController controller;
  final String label;

  /// The reveal button's label while masked ("Show value") and while shown.
  final String showLabel;
  final String hideLabel;
  final String? hint;
  final bool enabled;
  final FormFieldValidator<String>? validator;
  final List<TextInputFormatter> inputFormatters;
  final Key? fieldKey;
  final Key? revealKey;

  @override
  State<KitSecretField> createState() => _KitSecretFieldState();
}

class _KitSecretFieldState extends State<KitSecretField> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) => TextFormField(
    key: widget.fieldKey,
    controller: widget.controller,
    enabled: widget.enabled,
    obscureText: !_revealed,
    autocorrect: false,
    enableSuggestions: false,
    keyboardType: TextInputType.visiblePassword,
    textDirection: TextDirection.ltr,
    inputFormatters: widget.inputFormatters,
    validator: widget.validator,
    decoration: InputDecoration(
      labelText: widget.label,
      hintText: widget.hint,
      suffixIcon: KitIconButton(
        key: widget.revealKey,
        icon: _revealed ? AppIconography.hidden : AppIconography.visible,
        label: _revealed ? widget.hideLabel : widget.showLabel,
        onPressed: widget.enabled
            ? () => setState(() => _revealed = !_revealed)
            : null,
      ),
    ),
  );
}
