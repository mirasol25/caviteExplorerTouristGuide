import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import 'photo_gallery_viewer.dart';

class VisitorReviewCard extends StatelessWidget {
  final Map<String, dynamic> post;

  const VisitorReviewCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final user = post['user'] is Map
        ? Map<String, dynamic>.from(post['user'] as Map)
        : const <String, dynamic>{};
    final photos = ((post['photos'] as List?) ?? const [])
        .map((value) => value.toString())
        .where((value) => value.isNotEmpty)
        .toList();
    final memory = post['memory']?.toString() ?? '';
    final thoughts = post['thoughts']?.toString() ?? '';
    final visitorName = user['name']?.toString() ?? 'Verified visitor';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE1E9E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFE3F0E8),
                child: Text(
                  visitorName.trim().isNotEmpty
                      ? visitorName.trim()[0].toUpperCase()
                      : 'V',
                  style: const TextStyle(
                    color: Color(0xFF176A50),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  visitorName,
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _ReviewStars(
                rating: (post['rating'] as num?)?.toDouble() ?? 0,
              ),
            ],
          ),
          if (photos.isNotEmpty) ...[
            const SizedBox(height: 13),
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, index) => Semantics(
                  button: true,
                  label:
                      'Open photo ${index + 1} of ${photos.length} shared by $visitorName',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => showPhotoGallery(
                      context: context,
                      photos: photos,
                      initialIndex: index,
                      title: '$visitorName\'s photos',
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Stack(
                        children: [
                          Image.network(
                            ApiService.assetUrl(photos[index]),
                            width: 210,
                            height: 150,
                            fit: BoxFit.cover,
                            cacheWidth: 630,
                            errorBuilder: (_, __, ___) => Container(
                              width: 210,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.broken_image_outlined),
                            ),
                          ),
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.fullscreen_rounded,
                                  color: Colors.white, size: 18),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (memory.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              memory,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
          ],
          if (thoughts.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              thoughts,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewStars extends StatelessWidget {
  final double rating;

  const _ReviewStars({required this.rating});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          5,
          (index) => Icon(
            index < rating.round() ? Icons.star_rounded : Icons.star_border,
            size: 14,
            color: const Color(0xFFE3A72D),
          ),
        ),
      );
}
