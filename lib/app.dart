import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/providers.dart';
import 'navigation/router.dart';
import 'theme/app_theme.dart';

class FindWhoApp extends ConsumerStatefulWidget {
  const FindWhoApp({super.key, this.initialLocation = '/home'});
  final String initialLocation;
  @override
  ConsumerState<FindWhoApp> createState() => _FindWhoAppState();
}

class _FindWhoAppState extends ConsumerState<FindWhoApp> {
  late final GoRouter _router = buildRouter(initialLocation: widget.initialLocation);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(settingsProvider.select((s) => s.themeMode));
    return MaterialApp.router(
      title: 'Find Who',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      routerConfig: _router,
    );
  }
}
