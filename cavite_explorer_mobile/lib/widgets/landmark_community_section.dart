import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';

class LandmarkCommunitySection extends StatefulWidget {
  final Map<String, dynamic> place;
  final bool openComposerOnLoad;

  const LandmarkCommunitySection({
    super.key,
    required this.place,
    this.openComposerOnLoad = false,
  });

  @override
  State<LandmarkCommunitySection> createState() =>
      _LandmarkCommunitySectionState();
}

class _LandmarkCommunitySectionState extends State<LandmarkCommunitySection> {
  bool _loading = true;
  bool _canPost = false;
  String? _error;
  double _average = 0;
  int _reviewCount = 0;
  List<Map<String, dynamic>> _posts = [];
  bool _composerOpened = false;

  String get _landmarkId => widget.place['id']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_landmarkId.isEmpty) return;
    if (mounted) setState(() => _loading = true);
    try {
      final user = await AuthService.getUser();
      final token = user?['token']?.toString();
      final requests = <Future<http.Response>>[
        http.get(ApiService.uri('/places/$_landmarkId/community')),
        if (token != null && token.isNotEmpty)
          http.get(ApiService.uri('/badges/me'),
              headers: {'Authorization': 'Bearer $token'}),
      ];
      final responses = await Future.wait(requests);
      if (responses.first.statusCode != 200) {
        throw Exception('Could not load visitor stories.');
      }
      final community =
          json.decode(responses.first.body) as Map<String, dynamic>;
      _average = (community['averageRating'] as num?)?.toDouble() ?? 0;
      _reviewCount = (community['reviewCount'] as num?)?.round() ?? 0;
      _posts = ((community['posts'] as List?) ?? const [])
          .whereType<Map>()
          .map((value) => Map<String, dynamic>.from(value))
          .toList();
      _canPost = false;
      if (responses.length > 1 && responses[1].statusCode == 200) {
        final badges = json.decode(responses[1].body) as Map<String, dynamic>;
        _canPost =
            ((badges['earned'] as List?) ?? const []).whereType<Map>().any(
                  (badge) => badge['landmarkId']?.toString() == _landmarkId,
                );
      }
      _error = null;
      if (_canPost && widget.openComposerOnLoad && !_composerOpened) {
        _composerOpened = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _share();
        });
      }
    } catch (error) {
      _error = error.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _share() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ShareMemorySheet(landmarkId: _landmarkId),
    );
    if (saved == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          children: [
            Text(_error!, textAlign: TextAlign.center),
            TextButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF173F34),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_reviewCount == 0 ? 'New' : _average.toStringAsFixed(1),
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w800)),
                  if (_reviewCount > 0) _Stars(rating: _average, size: 17),
                  Text(
                      '$_reviewCount visitor ${_reviewCount == 1 ? 'story' : 'stories'}',
                      style: GoogleFonts.poppins(
                          color: Colors.white70, fontSize: 10)),
                ],
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _canPost ? _share : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFD8F270),
                  foregroundColor: const Color(0xFF173F34),
                ),
                icon: Icon(_canPost
                    ? Icons.add_a_photo_outlined
                    : Icons.lock_outline_rounded),
                label: Text(_canPost ? 'Share yours' : 'Earn badge first'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('Visitor photos and memories',
            style:
                GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Stories shared by verified landmark visitors.',
            style: GoogleFonts.poppins(
                fontSize: 10.5, color: Colors.grey.shade600)),
        const SizedBox(height: 14),
        if (_posts.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE1E9E1)),
            ),
            child: Column(
              children: [
                const Icon(Icons.photo_library_outlined,
                    size: 34, color: Color(0xFF176A50)),
                const SizedBox(height: 8),
                Text('No memories shared yet',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                Text('Be the first verified visitor to share this place.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        fontSize: 10, color: Colors.grey.shade600)),
              ],
            ),
          )
        else
          ..._posts.map(_postCard),
      ],
    );
  }

  Widget _postCard(Map<String, dynamic> post) {
    final user = post['user'] is Map
        ? Map<String, dynamic>.from(post['user'] as Map)
        : const <String, dynamic>{};
    final photos = ((post['photos'] as List?) ?? const [])
        .map((value) => value.toString())
        .toList();
    final memory = post['memory']?.toString() ?? '';
    final thoughts = post['thoughts']?.toString() ?? '';
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
                  (user['name']?.toString().trim().isNotEmpty ?? false)
                      ? user['name'].toString()[0].toUpperCase()
                      : 'V',
                  style: const TextStyle(
                      color: Color(0xFF176A50), fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(user['name']?.toString() ?? 'Verified visitor',
                    style: GoogleFonts.poppins(
                        fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
              _Stars(rating: (post['rating'] as num?)?.toDouble() ?? 0),
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
                itemBuilder: (_, index) => ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    ApiService.assetUrl(photos[index]),
                    width: 210,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 210,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (memory.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(memory,
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w600, height: 1.45)),
          ],
          if (thoughts.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(thoughts,
                style: GoogleFonts.poppins(
                    fontSize: 11, color: Colors.grey.shade700, height: 1.5)),
          ],
        ],
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  final double rating;
  final double size;

  const _Stars({required this.rating, this.size = 14});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          5,
          (index) => Icon(
            index < rating.round() ? Icons.star_rounded : Icons.star_border,
            size: size,
            color: const Color(0xFFE3A72D),
          ),
        ),
      );
}

class _ShareMemorySheet extends StatefulWidget {
  final String landmarkId;

  const _ShareMemorySheet({required this.landmarkId});

  @override
  State<_ShareMemorySheet> createState() => _ShareMemorySheetState();
}

class _ShareMemorySheetState extends State<_ShareMemorySheet> {
  final _memory = TextEditingController();
  final _thoughts = TextEditingController();
  final _picker = ImagePicker();
  List<XFile> _photos = [];
  List<Uint8List> _photoBytes = [];
  int _rating = 5;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _memory.dispose();
    _thoughts.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final selected = await _picker.pickMultiImage(
      imageQuality: 82,
      maxWidth: 1800,
    );
    if (!mounted || selected.isEmpty) return;
    final photos = selected.take(6).toList();
    final bytes = await Future.wait(photos.map((photo) => photo.readAsBytes()));
    if (!mounted) return;
    setState(() {
      _photos = photos;
      _photoBytes = bytes;
    });
  }

  MediaType _contentType(String filename) {
    final extension = filename.toLowerCase().split('.').last;
    return switch (extension) {
      'png' => MediaType('image', 'png'),
      'webp' => MediaType('image', 'webp'),
      'heic' => MediaType('image', 'heic'),
      'heif' => MediaType('image', 'heif'),
      _ => MediaType('image', 'jpeg'),
    };
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final token = (await AuthService.getUser())?['token']?.toString();
      if (token == null || token.isEmpty) throw Exception('Sign in first.');
      final request = http.MultipartRequest(
        'POST',
        ApiService.uri('/places/${widget.landmarkId}/community'),
      )
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['rating'] = _rating.toString()
        ..fields['memory'] = _memory.text.trim()
        ..fields['thoughts'] = _thoughts.text.trim();
      for (var index = 0; index < _photos.length; index++) {
        final photo = _photos[index];
        request.files.add(http.MultipartFile.fromBytes(
          'photos',
          _photoBytes[index],
          filename: photo.name,
          contentType: _contentType(photo.name),
        ));
      }
      final response = await request.send();
      final body = await response.stream.bytesToString();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final decoded = body.isNotEmpty ? json.decode(body) : null;
        throw Exception(decoded is Map
            ? decoded['message']?.toString() ?? 'Could not share your memory.'
            : 'Could not share your memory.');
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(
            () => _error = error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 18, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      decoration: const BoxDecoration(
        color: Color(0xFFFDFCF9),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Share your visit',
                  style: GoogleFonts.poppins(
                      fontSize: 21, fontWeight: FontWeight.w800)),
              Text('Add photos, memories, and an honest rating.',
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: Colors.grey.shade600)),
              const SizedBox(height: 18),
              Text('Your rating',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
              Row(
                children: List.generate(
                  5,
                  (index) => IconButton(
                    onPressed: () => setState(() => _rating = index + 1),
                    icon: Icon(index < _rating
                        ? Icons.star_rounded
                        : Icons.star_border_rounded),
                    color: const Color(0xFFE3A72D),
                    iconSize: 32,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _pickPhotos,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(_photos.isEmpty
                    ? 'Add photos'
                    : '${_photos.length} photos selected'),
              ),
              if (_photoBytes.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 86,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _photoBytes.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, index) => ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        _photoBytes[index],
                        width: 110,
                        height: 86,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _memory,
                maxLines: 3,
                maxLength: 1200,
                decoration: const InputDecoration(
                  labelText: 'Your favorite memory',
                  hintText: 'What happened during your visit?',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _thoughts,
                maxLines: 3,
                maxLength: 1200,
                decoration: const InputDecoration(
                  labelText: 'Thoughts about this place',
                  hintText: 'What should future visitors know?',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(_saving ? 'Sharing...' : 'Share memory'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF176A50),
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
