import 'package:flutter_test/flutter_test.dart';
import 'package:me_mine/features/journal/domain/utils/music_attachment_utils.dart';

void main() {
  group('extractYoutubeVideoId', () {
    test('accepts raw video ids', () {
      expect(extractYoutubeVideoId('dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
    });

    test('accepts YouTube and YouTube Music watch links', () {
      expect(
        extractYoutubeVideoId('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
      expect(
        extractYoutubeVideoId(
          'https://music.youtube.com/watch?v=dQw4w9WgXcQ&feature=share',
        ),
        'dQw4w9WgXcQ',
      );
    });

    test('accepts short and embedded links', () {
      expect(
        extractYoutubeVideoId('https://youtu.be/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
      expect(
        extractYoutubeVideoId('https://www.youtube.com/embed/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('rejects unsupported links', () {
      expect(
        extractYoutubeVideoId('https://example.com/watch?v=dQw4w9WgXcQ'),
        isNull,
      );
      expect(extractYoutubeVideoId('not a link'), isNull);
    });
  });
}
