import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.playerId,
    required this.displayName,
    required this.bestMilliseconds,
    required this.runCount,
  });

  final String playerId;
  final String displayName;
  final int bestMilliseconds;
  final int runCount;
}

class RankingsService {
  RankingsService() : _db = Supabase.instance.client;

  final SupabaseClient _db;

  Future<void> upsertProfile({
    required String playerId,
    required String displayName,
  }) async {
    Sentry.addBreadcrumb(Breadcrumb(
      message: 'upsertProfile: $playerId',
      category: 'rankings',
      level: SentryLevel.info,
    ));
    try {
      await _db.from('profiles').upsert(
        {'id': playerId, 'display_name': displayName},
        onConflict: 'id',
      );
    } catch (e, st) {
      await Sentry.captureException(
        e,
        stackTrace: st,
        hint: Hint.withMap({
          'place': 'upsertProfile',
          'player_id': playerId,
        }),
      );
      rethrow;
    }
  }

  Future<void> submitScore({
    required String playerId,
    required String displayName,
    required String aircraftId,
    required int milliseconds,
  }) async {
    Sentry.addBreadcrumb(Breadcrumb(
      message: 'submitScore: $aircraftId ${milliseconds}ms',
      category: 'rankings',
      level: SentryLevel.info,
      data: {'aircraft_id': aircraftId, 'milliseconds': milliseconds},
    ));
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await upsertProfile(playerId: playerId, displayName: displayName);
        await _db.from('scores').insert({
          'player_id': playerId,
          'aircraft_id': aircraftId,
          'milliseconds': milliseconds,
        });
        Sentry.addBreadcrumb(Breadcrumb(
          message: 'submitScore ok (attempt $attempt)',
          category: 'rankings',
          level: SentryLevel.info,
        ));
        return;
      } catch (e, st) {
        if (attempt == 2) {
          await Sentry.captureException(
            e,
            stackTrace: st,
            hint: Hint.withMap({
              'place': 'submitScore',
              'aircraft_id': aircraftId,
              'milliseconds': milliseconds,
              'attempt': attempt,
            }),
          );
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 800));
      }
    }
  }

  Future<List<LeaderboardEntry>> fetchLeaderboard(String aircraftId) async {
    Sentry.addBreadcrumb(Breadcrumb(
      message: 'fetchLeaderboard: $aircraftId',
      category: 'rankings',
      level: SentryLevel.info,
    ));
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final rows = await _db
            .from('leaderboard')
            .select('player_id, display_name, best_milliseconds, run_count')
            .eq('aircraft_id', aircraftId)
            .order('best_milliseconds', ascending: true)
            .limit(50);
        Sentry.addBreadcrumb(Breadcrumb(
          message: 'fetchLeaderboard ok: ${rows.length} rows',
          category: 'rankings',
          level: SentryLevel.info,
        ));
        return [
          for (final row in rows)
            LeaderboardEntry(
              playerId: row['player_id'] as String,
              displayName: row['display_name'] as String,
              bestMilliseconds: row['best_milliseconds'] as int,
              runCount: row['run_count'] as int,
            ),
        ];
      } catch (e, st) {
        if (attempt == 2) {
          await Sentry.captureException(
            e,
            stackTrace: st,
            hint: Hint.withMap({
              'place': 'fetchLeaderboard',
              'aircraft_id': aircraftId,
              'attempt': attempt,
            }),
          );
          rethrow;
        }
        await Future<void>.delayed(const Duration(milliseconds: 800));
      }
    }
    return const [];
  }

  Future<LeaderboardEntry?> fetchPlayerBest(
    String aircraftId,
    String playerId,
  ) async {
    Sentry.addBreadcrumb(Breadcrumb(
      message: 'fetchPlayerBest: $aircraftId',
      category: 'rankings',
      level: SentryLevel.info,
    ));
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final rows = await _db
            .from('leaderboard')
            .select('display_name, best_milliseconds, run_count')
            .eq('aircraft_id', aircraftId)
            .eq('player_id', playerId)
            .limit(1);
        if (rows.isEmpty) return null;
        final row = rows.first;
        return LeaderboardEntry(
          playerId: row['player_id'] as String,
          displayName: row['display_name'] as String,
          bestMilliseconds: row['best_milliseconds'] as int,
          runCount: row['run_count'] as int,
        );
      } catch (e, st) {
        if (attempt == 2) {
          await Sentry.captureException(
            e,
            stackTrace: st,
            hint: Hint.withMap({
              'place': 'fetchPlayerBest',
              'aircraft_id': aircraftId,
              'attempt': attempt,
            }),
          );
          return null;
        }
        await Future<void>.delayed(const Duration(milliseconds: 800));
      }
    }
    return null;
  }
}
