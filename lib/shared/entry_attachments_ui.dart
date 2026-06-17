import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../core/location/place_label.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_shape.dart';
import 'package:me_mine/features/journal/domain/entities/entry.dart';
import 'entry_local_image_stub.dart'
    if (dart.library.io) 'entry_local_image_io.dart';

class EntryImage extends StatelessWidget {
  const EntryImage({
    super.key,
    required this.source,
    this.fit,
    this.width,
    this.height,
    this.errorWidget,
  });

  final String source;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final Widget? errorWidget;

  bool get _isRemote =>
      source.startsWith('http://') || source.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    final fallback =
        errorWidget ??
        ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Center(child: Icon(Icons.broken_image, size: 48)),
        );
    if (!_isRemote) {
      return buildLocalEntryImage(
        source: source,
        fit: fit,
        width: width,
        height: height,
        fallback: fallback,
      );
    }
    return CachedNetworkImage(
      imageUrl: source,
      fit: fit,
      width: width,
      height: height,
      errorWidget: (context, error, stackTrace) => fallback,
    );
  }
}

/// Square tile with a single icon (calendar-day style).
class AttachmentIconTile extends StatelessWidget {
  const AttachmentIconTile({
    super.key,
    required this.icon,
    required this.onPressed,
    this.enabled = true,
    this.size = 64,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final bool enabled;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppShape.radiusMd,
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.45)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          child: Center(
            child: Icon(
              icon,
              size: size * 0.36,
              color: enabled ? scheme.onSurface : scheme.outline,
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact icon in the attachment toolbar under the photo carousel.
class AttachmentToolbarIcon extends StatelessWidget {
  const AttachmentToolbarIcon({
    super.key,
    required this.icon,
    required this.onPressed,
    this.enabled = true,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final bool enabled;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final btn = Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppShape.radiusMd,
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: AppShape.radiusMd,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, size: 22, color: scheme.onSurface),
        ),
      ),
    );
    if (tooltip == null) return btn;
    return Tooltip(message: tooltip!, child: btn);
  }
}

class EntryPhotoCarousel extends StatefulWidget {
  const EntryPhotoCarousel({
    super.key,
    required this.imageUrls,
    this.onPhotoLongPress,
  });

  final List<String> imageUrls;

  /// Called with the photo index when the user long-presses a slide.
  final ValueChanged<int>? onPhotoLongPress;

  @override
  State<EntryPhotoCarousel> createState() => _EntryPhotoCarouselState();
}

class _EntryPhotoCarouselState extends State<EntryPhotoCarousel> {
  late final PageController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void didUpdateWidget(covariant EntryPhotoCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final n = widget.imageUrls.length;
    if (n == 0) return;
    if (_index >= n) {
      _index = n - 1;
      _controller.jumpToPage(_index);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openFullscreen() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) =>
            _FullscreenGallery(urls: widget.imageUrls, initialIndex: _index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.imageUrls.length;
    if (n == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: AppShape.radiusLg,
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: PageView.builder(
              controller: _controller,
              itemCount: n,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, index) {
                final url = widget.imageUrls[index];
                return GestureDetector(
                  onTap: _openFullscreen,
                  onLongPress: widget.onPhotoLongPress == null
                      ? null
                      : () {
                          HapticFeedback.mediumImpact();
                          widget.onPhotoLongPress!(index);
                        },
                  child: EntryImage(
                    source: url,
                    fit: BoxFit.cover,
                    errorWidget: ColoredBox(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      child: const Center(
                        child: Icon(Icons.broken_image, size: 48),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (n > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(n, (i) {
              final active = i == _index;
              return Container(
                width: active ? 8 : 6,
                height: active ? 8 : 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.outlineVariant,
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _FullscreenGallery extends StatefulWidget {
  const _FullscreenGallery({required this.urls, required this.initialIndex});

  final List<String> urls;
  final int initialIndex;

  @override
  State<_FullscreenGallery> createState() => _FullscreenGalleryState();
}

class _FullscreenGalleryState extends State<_FullscreenGallery> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.urls.length,
        itemBuilder: (context, index) {
          return InteractiveViewer(
            child: Center(
              child: EntryImage(
                source: widget.urls[index],
                fit: BoxFit.contain,
                errorWidget: const Icon(
                  Icons.broken_image,
                  color: Colors.white54,
                  size: 64,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class VolumetricStarRating extends StatelessWidget {
  const VolumetricStarRating({
    super.key,
    required this.rating,
    required this.onRatingChanged,
    this.enabled = true,
  });

  final int rating;
  final ValueChanged<int> onRatingChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const count = 5;
        const gap = 8.0;
        final maxW = constraints.maxWidth;
        final starSize = ((maxW - gap * (count - 1)) / count).clamp(28.0, 38.0);

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 1; i <= count; i++)
              _StarButton(
                filled: i <= rating,
                size: starSize,
                enabled: enabled,
                onPressed: () => onRatingChanged(i),
              ),
          ],
        );
      },
    );
  }
}

class _StarButton extends StatelessWidget {
  const _StarButton({
    required this.filled,
    required this.size,
    required this.enabled,
    required this.onPressed,
  });

  final bool filled;
  final double size;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(
            filled ? Icons.star_rounded : Icons.star_border_rounded,
            size: size,
            color: filled
                ? AppColors.star
                : Theme.of(context).colorScheme.outlineVariant,
            shadows: filled
                ? [
                    Shadow(
                      color: AppColors.star.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}

class EntryFileRow extends StatelessWidget {
  const EntryFileRow({super.key, required this.name, this.onLongPress});

  final String name;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        Icon(
          Icons.insert_drive_file_outlined,
          size: 20,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
    if (onLongPress == null) return row;
    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        onLongPress!();
      },
      behavior: HitTestBehavior.opaque,
      child: row,
    );
  }
}

class EntryLocationChip extends StatelessWidget {
  const EntryLocationChip({
    super.key,
    required this.location,
    this.onLongPress,
  });

  final EntryLocation location;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.location_on_outlined,
          size: 20,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            displayPlaceLabel(location),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
    if (onLongPress == null) return row;
    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        onLongPress!();
      },
      behavior: HitTestBehavior.opaque,
      child: row,
    );
  }
}

class EntryMusicCard extends StatelessWidget {
  const EntryMusicCard({super.key, required this.music, this.onLongPress});

  final EntryMusicAttachment music;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = music.title?.trim().isNotEmpty == true
        ? music.title!.trim()
        : 'YouTube music';
    final row = Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppShape.radiusMd,
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 56,
                height: 42,
                child: music.thumbnailUrl == null
                    ? ColoredBox(
                        color: scheme.surfaceContainerHighest,
                        child: const Icon(Icons.music_note_outlined),
                      )
                    : CachedNetworkImage(
                        imageUrl: music.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (context, error, stackTrace) =>
                            const Icon(Icons.music_note_outlined),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'YouTube',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.play_circle_outline),
          ],
        ),
      ),
    );

    if (onLongPress == null) return row;
    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        onLongPress!();
      },
      behavior: HitTestBehavior.opaque,
      child: row,
    );
  }
}

class EntryMusicPlayer extends StatefulWidget {
  const EntryMusicPlayer({super.key, required this.music});

  final EntryMusicAttachment music;

  @override
  State<EntryMusicPlayer> createState() => _EntryMusicPlayerState();
}

class _EntryMusicPlayerState extends State<EntryMusicPlayer> {
  YoutubePlayerController? _controller;

  void _startPlayer() {
    if (_controller != null) return;
    setState(() {
      _controller = YoutubePlayerController.fromVideoId(
        videoId: widget.music.videoId,
        autoPlay: true,
        params: const YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
          strictRelatedVideos: true,
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller != null) {
      return ClipRRect(
        borderRadius: AppShape.radiusMd,
        child: YoutubePlayer(controller: controller, aspectRatio: 16 / 9),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: _startPlayer,
      borderRadius: AppShape.radiusMd,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: AppShape.radiusMd,
          border: Border.all(color: scheme.outline.withValues(alpha: 0.4)),
          color: scheme.surface,
        ),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (widget.music.thumbnailUrl != null)
                ClipRRect(
                  borderRadius: AppShape.radiusMd,
                  child: CachedNetworkImage(
                    imageUrl: widget.music.thumbnailUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                  ),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: AppShape.radiusMd,
                  color: Colors.black.withValues(alpha: 0.24),
                ),
              ),
              const Center(
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  color: Colors.white,
                  size: 64,
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Text(
                  widget.music.title?.trim().isNotEmpty == true
                      ? widget.music.title!.trim()
                      : 'Play YouTube music',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    shadows: const [
                      Shadow(color: Colors.black54, blurRadius: 8),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows a short success message, waits 2s, then runs [onComplete].
Future<void> showEntrySavedAndNavigate(
  BuildContext context, {
  required VoidCallback onComplete,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      content: Row(
        children: [
          Icon(Icons.check_circle, color: AppColors.success),
          const SizedBox(width: 12),
          const Expanded(child: Text('Entry saved successfully')),
        ],
      ),
    ),
  );
  await Future<void>.delayed(const Duration(seconds: 2));
  if (context.mounted) onComplete();
}
