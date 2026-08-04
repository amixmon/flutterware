import 'package:flutter/material.dart';

import '../features/projects/presentation/projects_page.dart';
import '../ui/theme/app_theme.dart';

class FlutterwareApp extends StatelessWidget {
  const FlutterwareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutterware',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      scrollBehavior: const AppScrollBehavior(),
      themeAnimationDuration: const Duration(milliseconds: 200),
      builder: (context, child) {
        final colors = Theme.of(context).colorScheme;
        return AnnotatedRegion(
          value: AppTheme.systemOverlay(colors),
          child: ColoredBox(
            color: colors.surface,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: const ProjectsPage(),
    );
  }
}
