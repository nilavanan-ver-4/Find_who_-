import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/awards/awards_screen.dart';
import '../features/friends/friends_screen.dart';
import '../features/games/game_screen.dart';
import '../features/games/games_screen.dart';
import '../features/home/home_screen.dart';
import '../features/posters/editor_screen.dart';
import '../features/posters/favorites_screen.dart';
import '../features/posters/personalize_screen.dart';
import '../features/posters/posters_screen.dart';
import '../features/posters/saved_posters_screen.dart';
import '../features/settings/settings_screen.dart';
import '../widgets/common.dart';
import 'shell.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter buildRouter({String initialLocation = '/home'}) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLocation,
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(),
      body: ErrorState(message: 'We could not find that page.', onRetry: () => context.go('/home')),
    ),
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, _) => const HomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/posters', builder: (_, _) => const PostersScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/games', builder: (_, _) => const GamesScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/friends', builder: (_, _) => const FriendsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen())]),
        ],
      ),
      GoRoute(
        path: '/create',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => PersonalizeScreen(
          templateId: state.uri.queryParameters['template'],
          friendName: state.uri.queryParameters['name'],
        ),
      ),
      GoRoute(
        path: '/editor',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final args = state.extra;
          if (args is! EditorArgs) {
            return Scaffold(
              appBar: AppBar(),
              body: ErrorState(message: 'Nothing to edit here.', onRetry: () => context.go('/posters')),
            );
          }
          return EditorScreen(args: args);
        },
      ),
      GoRoute(path: '/saved', parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const SavedPostersScreen()),
      GoRoute(path: '/favorites', parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const FavoritesScreen()),
      GoRoute(
        path: '/awards',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => AwardsScreen(initialName: state.uri.queryParameters['name']),
      ),
      GoRoute(
        path: '/game/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => GameScreen(gameId: state.pathParameters['id']!),
      ),
    ],
  );
}
