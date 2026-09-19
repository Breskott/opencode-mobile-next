import 'package:flutter/material.dart';

import '../app_theme.dart';

/// One answer to a first-run question: a whole-row target with a plain title
/// and one line saying what happens next. Every answer has the same weight,
/// because none of them is the "right" one.
class FirstRunChoice extends StatelessWidget {
  const FirstRunChoice({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card.filled(
    margin: const EdgeInsets.symmetric(vertical: 4),
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      enabled: onTap != null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(detail),
      trailing: const Icon(AppIconography.chevronRight),
      onTap: onTap,
    ),
  );
}
