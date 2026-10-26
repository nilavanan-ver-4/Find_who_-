import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../models/records.dart';
import '../../widgets/common.dart';
import 'game_card_games.dart';
import 'game_generators.dart';
import 'game_quiz_games.dart';
import 'game_registry.dart';
import 'game_wheel.dart';
import 'games_common.dart';
import 'player_setup.dart';

/// Hosts a game: player setup -> game -> result screen.
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key, required this.gameId});
  final String gameId;
  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  List<String>? _players;
  GameResult? _result;
  int _run = 0;
  bool _historyRecorded = false;

  GameInfo? get _info => Games.byId(widget.gameId);

  void _start(List<String> players) {
    final info = _info!;
    ref.read(historyProvider.notifier).record(HistoryKind.game, info.id, info.title);
    setState(() {
      _players = players;
      _result = null;
      _historyRecorded = false;
      _run++;
    });
  }

  void _finish(GameResult r) {
    final info = _info!;
    if (!_historyRecorded) {
      _historyRecorded = true;
      ref.read(historyProvider.notifier).record(HistoryKind.game, info.id, info.title, detail: r.headline);
    }
    ref.read(feedbackProvider).success();
    setState(() => _result = r);
  }

  Widget _buildGame(GameInfo info, GameContext ctx) {
    switch (info.id) {
      case 'truth_dare':
        return TruthDareGame(key: ValueKey(_run), ctx: ctx);
      case 'would_you_rather':
        return WouldYouRatherGame(key: ValueKey(_run), ctx: ctx);
      case 'never_have_i_ever':
        return NeverHaveIEverGame(key: ValueKey(_run), ctx: ctx);
      case 'spin_wheel':
        return SpinWheelGame(key: ValueKey(_run), ctx: ctx);
      case 'random_challenge':
        return GeneratorGame(key: ValueKey(_run), ctx: ctx, kind: GeneratorKind.challenge);
      case 'punishment':
        return GeneratorGame(key: ValueKey(_run), ctx: ctx, kind: GeneratorKind.punishment);
      case 'friendship_quiz':
        return FriendshipQuizGame(key: ValueKey(_run), ctx: ctx);
      case 'who_knows_whom':
        return WhoKnowsWhomGame(key: ValueKey(_run), ctx: ctx);
      case 'guess_friend':
        return GuessFriendGame(key: ValueKey(_run), ctx: ctx);
      case 'guess_emoji':
        return GuessEmojiGame(key: ValueKey(_run), ctx: ctx);
      case 'complete_sentence':
        return CompleteSentenceGame(key: ValueKey(_run), ctx: ctx);
      default:
        if (Games.mostLikelyIds.contains(info.id)) {
          return MostLikelyGame(key: ValueKey(_run), ctx: ctx, deckId: info.id);
        }
        return const ErrorState(message: 'This game is not available.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    if (info == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const ErrorState(message: 'We could not find that game.'),
      );
    }
    final inProgress = _players != null && _result == null;
    final fav = isFav(ref, FavoritesNotifier.gameKey(info.id));
    return PopScope(
      canPop: !inProgress,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await confirm(
          context,
          title: 'Leave the game?',
          message: 'Your current progress will be lost.',
          confirmLabel: 'Leave',
        );
        if (leave && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('${info.emoji} ${info.title}'),
          actions: [
            IconButton(
              tooltip: fav ? 'Remove from favorites' : 'Add to favorites',
              icon: Icon(fav ? Icons.favorite : Icons.favorite_border),
              onPressed: () => ref.read(favoritesProvider.notifier).toggle(FavoritesNotifier.gameKey(info.id)),
            ),
          ],
        ),
        body: SafeArea(
          child: _result != null
              ? ResultView(
                  result: _result!,
                  onPlayAgain: () => _start(_players!),
                  onDone: () => context.pop(),
                )
              : _players == null
                  ? PlayerSetup(game: info, onStart: _start)
                  : _buildGame(
                      info,
                      GameContext(
                        content: ref.read(contentProvider),
                        players: _players!,
                        random: ref.read(randomProvider),
                        tap: ref.read(feedbackProvider).tap,
                        finish: _finish,
                      ),
                    ),
        ),
      ),
    );
  }
}
