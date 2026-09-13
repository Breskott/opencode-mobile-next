import '../l10n/app_localizations.dart';
import '../l10n/app_localizations_en.dart';

String permissionRequestTitle(String permission, {AppLocalizations? l10n}) {
  final strings = l10n ?? AppLocalizationsEn();
  return switch (permission) {
    'bash' => strings.e7PermissionAction1,
    'edit' => strings.e7PermissionAction2,
    'read' => strings.e7PermissionAction3,
    'external_directory' => strings.e7PermissionAction4,
    'doom_loop' => strings.e7PermissionAction5,
    _ when permission.trim().isEmpty => strings.e7PermissionAction6,
    _ => strings.e7PermissionAction7(permission),
  };
}
