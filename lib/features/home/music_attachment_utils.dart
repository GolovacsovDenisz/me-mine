String? extractYoutubeVideoId(String rawInput) {
  final input = rawInput.trim();
  if (input.isEmpty) return null;

  final idOnly = RegExp(r'^[A-Za-z0-9_-]{11}$');
  if (idOnly.hasMatch(input)) return input;

  final uri = Uri.tryParse(input);
  if (uri == null) return null;

  final host = uri.host.toLowerCase();
  if (host == 'youtu.be') {
    final segment = uri.pathSegments.isEmpty ? '' : uri.pathSegments.first;
    return idOnly.hasMatch(segment) ? segment : null;
  }

  final isYoutubeHost =
      host == 'youtube.com' ||
      host == 'www.youtube.com' ||
      host == 'm.youtube.com' ||
      host == 'music.youtube.com';
  if (!isYoutubeHost) return null;

  final queryId = uri.queryParameters['v'];
  if (queryId != null && idOnly.hasMatch(queryId)) return queryId;

  if (uri.pathSegments.length >= 2) {
    final first = uri.pathSegments[0];
    final second = uri.pathSegments[1];
    if ((first == 'embed' || first == 'shorts' || first == 'live') &&
        idOnly.hasMatch(second)) {
      return second;
    }
  }

  return null;
}

String youtubeWatchUrl(String videoId) =>
    'https://www.youtube.com/watch?v=$videoId';

String youtubeThumbnailUrl(String videoId) =>
    'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
