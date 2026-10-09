import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/song.dart';
import 'storage_service.dart';
import 'ytmusic_service.dart';
import 'playback_log_service.dart';

class ScoredTrackMatch {
  final Song song;
  final int score;
  final int durationDiffSeconds;
  final String qualityLabel;
  final bool isTopicOrOfficial;

  ScoredTrackMatch({
    required this.song,
    required this.score,
    required this.durationDiffSeconds,
    required this.qualityLabel,
    required this.isTopicOrOfficial,
  });
}

class TrackMatcherService {
  TrackMatcherService._internal();
  static final TrackMatcherService instance = TrackMatcherService._internal();

  static final RegExp _parentheticalRegex = RegExp(r'\s*[\(\[][^\)\]]*[\)\]]');
  static final RegExp _featRegex = RegExp(r'\s*(feat\.?|ft\.?|featuring)\s+.*', caseSensitive: false);
  static final RegExp _nonAlphaNumRegex = RegExp(r'[^\w\s]', unicode: true);

  String _canonicalTitle(String title) {
    return title
        .replaceAll(_parentheticalRegex, '')
        .replaceAll(_featRegex, '')
        .replaceAll(_nonAlphaNumRegex, '')
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _canonicalArtist(String artist) {
    return artist
        .split(RegExp(r'\s*[,;&/]\s*|\s+(?:and|&)\s+', caseSensitive: false))
        .map((e) => e.replaceAll(_parentheticalRegex, '').replaceAll(_nonAlphaNumRegex, '').toLowerCase().trim())
        .where((e) => e.isNotEmpty)
        .join(', ');
  }

  bool _titleMatches(String target, String candidate) {
    // If the candidate doesn't even share the main word of the target, it's garbage.
    final targetWords = target.split(' ').where((w) => w.length > 2).toList();
    if (targetWords.isEmpty) return true; // too short to filter

    final candidateLower = candidate.toLowerCase();
    for (final w in targetWords) {
      if (candidateLower.contains(w)) return true;
    }
    return false;
  }

  int scoreCandidate(Song candidate, Song target) {
    int score = 0;
    final targetTitle = _canonicalTitle(target.title);
    final candTitle = _canonicalTitle(candidate.title);

    // Duration is ABSOLUTE KING in Demus
    final diff = target.duration.inSeconds > 0 && candidate.duration.inSeconds > 0
        ? (target.duration.inSeconds - candidate.duration.inSeconds).abs()
        : 0;

    if (diff == 0) score += 10000;
    else if (diff <= 2) score += 5000;
    else if (diff <= 5) score += 2000;
    else if (diff <= 10) score += 500;
    else score -= diff * 50; // Penalize heavy duration differences

    // Title match
    if (candTitle == targetTitle) score += 2000;
    else if (candTitle.contains(targetTitle) || targetTitle.contains(candTitle)) score += 500;
    else if (_titleMatches(targetTitle, candTitle)) score += 100;
    else score -= 5000; // Se non c'entra niente col titolo, penalità forte ma non scarto assoluto (previene blocchi)

    // Official/Topic bonus
    if (candidate.artist.toLowerCase().contains('- topic')) score += 300;
    if (candidate.title.toLowerCase().contains('official audio')) score += 300;
    
    // Penalty for wrong variants (live, cover)
    final lowerCand = '${candidate.title} ${candidate.artist}'.toLowerCase();
    if (lowerCand.contains('live') && !target.title.toLowerCase().contains('live')) score -= 2000;
    if (lowerCand.contains('cover') && !target.title.toLowerCase().contains('cover')) score -= 2000;
    if (lowerCand.contains('sped up') && !target.title.toLowerCase().contains('sped up')) score -= 2000;
    if (lowerCand.contains('slowed') && !target.title.toLowerCase().contains('slowed')) score -= 2000;

    return score;
  }


  Song pickBestMatch(List<Song> candidates, Song target) {
    if (candidates.isEmpty) throw ArgumentError('Candidates list cannot be empty');
    if (candidates.length == 1) return candidates.first;

    Song bestSong = candidates.first;
    int highestScore = -999999;

    for (final candidate in candidates) {
      final s = scoreCandidate(candidate, target);
      if (s > highestScore) {
        highestScore = s;
        bestSong = candidate;
      }
    }

    return bestSong;
  }

  Future<String> resolveAndCacheStreamId(Song song) async {
    if (!song.id.startsWith('spotify_') && !song.id.startsWith('itunes_')) {
      return song.id;
    }

    if (song.youtubeVideoId != null && song.youtubeVideoId!.isNotEmpty) {
      return song.youtubeVideoId!;
    }

    final cached = StorageService.instance.getCachedYouTubeMapping(song.id);
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    try {
      final cleanTitle = _canonicalTitle(song.title);
      final cleanArtist = _canonicalArtist(song.artist).split(',').first;
      
      // FIRE SEARCHES, ma diamo priorità ASSOLUTA a YT Music per evitare i video Vevo.
      final queryMusic = '$cleanTitle $cleanArtist';
      final queryTube = '${song.title} ${song.artist} audio';
      
      final musicResults = await YTMusicService.instance.search(queryMusic);
      var allCandidates = [...musicResults];
      
      if (allCandidates.isEmpty) {
        final explodeResults = await YTMusicService.instance.explodeSearch(queryTube);
        allCandidates = [...explodeResults];
      }
      
      if (allCandidates.isEmpty) {
         return song.id; // Desperate fallback
      }

      Song? best;
      int bestScore = -999999;

      for (final candidate in allCandidates) {
         final score = scoreCandidate(candidate, song);
         if (score > bestScore) {
            bestScore = score;
            best = candidate;
         }
      }

      if (best != null) {
        PlaybackLogService.instance.log('MATCHER', 'Match Trovato per ${song.title}: ${best.title} (Score: $bestScore)');
        await StorageService.instance.cacheYouTubeMapping(song.id, best.id);
        return best.id;
      }
      
    } catch (e) {
      debugPrint('TrackMatcherService.resolveAndCacheStreamId: $e');
    }

    // Se arriviamo qui, non abbiamo trovato NESSUN candidato o c'è stato un errore di rete.
    // L'AudioHandler andrà in errore se gli passiamo un itunes_ o spotify_ id, ma è inevitabile se YT non va.
    return song.id;
  }
  
  Future<List<ScoredTrackMatch>> getAlternativeMatches(Song targetSong, {int limit = 12}) async {
      try {
        final cleanTitle = _canonicalTitle(targetSong.title);
        final cleanArtist = _canonicalArtist(targetSong.artist).split(',').first;
        final query = '$cleanTitle $cleanArtist';
        
        final results = await YTMusicService.instance.search(query);
        final explode = await YTMusicService.instance.explodeSearch('$query audio');
        
        final allCandidates = <String, Song>{};
        for (final r in [...results, ...explode]) {
          allCandidates[r.id] = r;
        }
  
        final scoredList = <ScoredTrackMatch>[];
  
        for (final candidate in allCandidates.values) {
          final score = scoreCandidate(candidate, targetSong);
          final diff = targetSong.duration > Duration.zero && candidate.duration > Duration.zero
              ? (candidate.duration.inSeconds - targetSong.duration.inSeconds).abs()
              : 0;
  
          String label;
          if (diff <= 3 && score >= 300) {
            label = 'Match Perfetto (±${diff}s)';
          } else if (diff <= 8 && score >= 100) {
            label = 'Ottimo (±${diff}s)';
          } else if (diff <= 15) {
            label = 'Buono (±${diff}s)';
          } else {
            label = 'Fonte Alternativa (+${diff}s)';
          }
  
          scoredList.add(ScoredTrackMatch(
            song: candidate,
            score: score,
            durationDiffSeconds: diff,
            qualityLabel: label,
            isTopicOrOfficial: candidate.artist.toLowerCase().contains('- topic'),
          ));
        }
  
        scoredList.sort((a, b) => b.score.compareTo(a.score));
        return scoredList.take(limit).toList();
      } catch (e) {
        debugPrint('TrackMatcherService.getAlternativeMatches: $e');
        return [];
      }
  }
}