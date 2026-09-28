// The manage-space entrypoint (ManageSpaceActivity → manageSpaceMain in
// main.dart): its own small app, not the whole one. It reads no profiles'
// secrets, connects to nothing and starts nothing; it only measures the
// app's files and offers export, cache clearing and delete.
import 'package:flutter/material.dart';

import 'builtin/project_export.dart';
import 'builtin/project_export_controller.dart';
import 'l10n/app_localizations.dart';
import 'ui/app_theme.dart';
import 'ui/screens/manage_space_screen.dart';

void runManageSpaceApp() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ManageSpaceApp(
      controller: ProjectExportController(
        platform: MethodChannelProjectExport(),
      ),
    ),
  );
}

class ManageSpaceApp extends StatelessWidget {
  const ManageSpaceApp({super.key, required this.controller, this.onClose});

  final ProjectExportController controller;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'OpenCode Mobile',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: ManageSpaceScreen(controller: controller, onClose: onClose),
  );
}
