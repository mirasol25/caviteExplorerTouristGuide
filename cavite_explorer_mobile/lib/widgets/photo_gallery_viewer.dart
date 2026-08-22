import 'package:flutter/material.dart';

import '../services/api_service.dart';

Future<void> showPhotoGallery({
  required BuildContext context,
  required List<String> photos,
  int initialIndex = 0,
  String? title,
}) {
  if (photos.isEmpty) return Future.value();
  final safeIndex = initialIndex.clamp(0, photos.length - 1);
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _PhotoGalleryScreen(
        photos: photos,
        initialIndex: safeIndex,
        title: title,
      ),
    ),
  );
}

class _PhotoGalleryScreen extends StatefulWidget {
  final List<String> photos;
  final int initialIndex;
  final String? title;

  const _PhotoGalleryScreen({
    required this.photos,
    required this.initialIndex,
    this.title,
  });

  @override
  State<_PhotoGalleryScreen> createState() => _PhotoGalleryScreenState();
}

class _PhotoGalleryScreenState extends State<_PhotoGalleryScreen> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _move(int offset) {
    final next = (_index + offset).clamp(0, widget.photos.length - 1);
    if (next == _index) return;
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.photos.length,
              onPageChanged: (value) => setState(() => _index = value),
              itemBuilder: (_, index) => Semantics(
                image: true,
                label: 'Photo ${index + 1} of ${widget.photos.length}',
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: Image.network(
                      ApiService.assetUrl(widget.photos[index]),
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image_outlined,
                              color: Colors.white70, size: 48),
                          SizedBox(height: 10),
                          Text('This photo could not be loaded.',
                              style: TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  _GalleryButton(
                    tooltip: 'Close photo viewer',
                    icon: Icons.close_rounded,
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title ?? 'Visitor photo',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '${_index + 1} / ${widget.photos.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.photos.length > 1) ...[
              Positioned(
                left: 12,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _GalleryButton(
                    tooltip: 'Previous photo',
                    icon: Icons.chevron_left_rounded,
                    onPressed: _index > 0 ? () => _move(-1) : null,
                  ),
                ),
              ),
              Positioned(
                right: 12,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _GalleryButton(
                    tooltip: 'Next photo',
                    icon: Icons.chevron_right_rounded,
                    onPressed: _index < widget.photos.length - 1
                        ? () => _move(1)
                        : null,
                  ),
                ),
              ),
            ],
            if (widget.photos.length > 1)
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Text(
                  'Swipe left or right to view more photos',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withOpacity(.75)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GalleryButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  const _GalleryButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: Colors.black54,
          disabledBackgroundColor: Colors.black26,
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white30,
        ),
        icon: Icon(icon, size: 30),
      );
}
