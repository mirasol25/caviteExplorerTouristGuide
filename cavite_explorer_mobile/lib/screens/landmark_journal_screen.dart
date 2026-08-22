import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'place_details_screen.dart';

class LandmarkJournalScreen extends StatefulWidget {
  final Map<String, dynamic> place;

  const LandmarkJournalScreen({super.key, required this.place});

  @override
  State<LandmarkJournalScreen> createState() => _LandmarkJournalScreenState();
}

class _LandmarkJournalScreenState extends State<LandmarkJournalScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _memories = [];

  String get _landmarkId => widget.place['id']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final token = (await AuthService.getUser())?['token']?.toString() ?? '';
      if (token.isEmpty) throw Exception('Sign in to open your journey.');
      final response = await http.get(
        ApiService.uri('/places/$_landmarkId/memories/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final body = json.decode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(body is Map
            ? body['message'] ?? 'Could not load your memories.'
            : 'Could not load your memories.');
      }
      _memories = ((body['memories'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      _error = null;
    } catch (error) {
      _error = error.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addMemory() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MemoryComposer(landmarkId: _landmarkId),
    );
    if (saved == true) await _load();
  }

  Future<void> _deleteMemory(Map<String, dynamic> memory) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon:
            const Icon(Icons.delete_outline_rounded, color: Color(0xFFC34738)),
        title: const Text('Delete this memory?'),
        content: const Text(
            'The photos and story in this personal journal entry will be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFC34738)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final token = (await AuthService.getUser())?['token']?.toString() ?? '';
      final response = await http.delete(
        ApiService.uri('/places/$_landmarkId/memories/${memory['id']}'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Could not delete this memory.');
      }
      if (mounted) {
        setState(() => _memories.removeWhere(
            (item) => item['id']?.toString() == memory['id']?.toString()));
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', ''))));
    }
  }

  String _placeImage() {
    final images = widget.place['images'];
    if (images is List && images.isNotEmpty) {
      return ApiService.assetUrl(images.first);
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final location = [widget.place['barangay'], widget.place['municipality']]
        .where((value) => value?.toString().trim().isNotEmpty == true)
        .join(', ');
    return Scaffold(
      backgroundColor: const Color(0xFFF7F6F1),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F6F1),
        surfaceTintColor: Colors.transparent,
        title: Text('My memory lane',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: 'Landmark information',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => PlaceDetailsScreen(place: widget.place)),
            ),
            icon: const Icon(Icons.info_outline_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addMemory,
        backgroundColor: const Color(0xFF176A50),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Add memory'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 110),
          children: [
            _JourneyHeader(
              name: widget.place['name']?.toString() ?? 'Landmark',
              location: location,
              imageUrl: _placeImage(),
              memoryCount: _memories.length,
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your visits',
                          style: GoogleFonts.poppins(
                              fontSize: 20, fontWeight: FontWeight.w800)),
                      Text('Stories preserved from every visit.',
                          style: GoogleFonts.poppins(
                              fontSize: 10.5, color: Colors.grey.shade600)),
                    ]),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: const Color(0xFFE5F0E8),
                    borderRadius: BorderRadius.circular(99)),
                child: Text('${_memories.length} memories',
                    style: GoogleFonts.poppins(
                        color: const Color(0xFF176A50),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 15),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(44),
                child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF176A50))),
              )
            else if (_error != null)
              _JournalEmpty(
                  icon: Icons.cloud_off_rounded,
                  title: 'Could not open memory lane',
                  message: _error!,
                  action: _load)
            else if (_memories.isEmpty)
              _JournalEmpty(
                icon: Icons.auto_stories_outlined,
                title: 'Start your first memory',
                message:
                    'Add photos and write what made your visit meaningful. Your journal is private unless you choose to share it.',
                action: _addMemory,
              )
            else
              ..._memories.asMap().entries.map((entry) => _MemoryCard(
                    memory: entry.value,
                    isLatest: entry.key == 0,
                    onDelete: () => _deleteMemory(entry.value),
                  )),
          ],
        ),
      ),
    );
  }
}

class _JourneyHeader extends StatelessWidget {
  final String name;
  final String location;
  final String imageUrl;
  final int memoryCount;

  const _JourneyHeader({
    required this.name,
    required this.location,
    required this.imageUrl,
    required this.memoryCount,
  });

  @override
  Widget build(BuildContext context) => Container(
        height: 225,
        decoration: BoxDecoration(
          color: const Color(0xFF173F34),
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(
                color: Color(0x22000000), blurRadius: 18, offset: Offset(0, 8))
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(fit: StackFit.expand, children: [
          if (imageUrl.isNotEmpty)
            Image.network(imageUrl,
                fit: BoxFit.cover,
                cacheWidth: 900,
                errorBuilder: (_, __, ___) => const SizedBox()),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x22000000), Color(0xE8173F34)],
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 18,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                      color: const Color(0xFFDDF56E),
                      borderRadius: BorderRadius.circular(99)),
                  child: Text('MY CAVITE JOURNEY',
                      style: GoogleFonts.poppins(
                          color: const Color(0xFF173F34),
                          fontSize: 8,
                          letterSpacing: .7,
                          fontWeight: FontWeight.w800)),
                ),
                const Spacer(),
                const Icon(Icons.verified_rounded,
                    color: Color(0xFFDDF56E), size: 18),
                const SizedBox(width: 5),
                Text('Badge collected',
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 10),
              Text(name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 24,
                      height: 1.1,
                      fontWeight: FontWeight.w800)),
              if (location.isNotEmpty) ...[
                const SizedBox(height: 7),
                Text(location,
                    style: GoogleFonts.poppins(
                        color: Colors.white70, fontSize: 10.5)),
              ],
            ]),
          ),
        ]),
      );
}

class _MemoryCard extends StatelessWidget {
  final Map<String, dynamic> memory;
  final bool isLatest;
  final VoidCallback onDelete;

  const _MemoryCard(
      {required this.memory, required this.isLatest, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(memory['visitedAt']?.toString() ?? '');
    final photos = ((memory['photos'] as List?) ?? const [])
        .map((photo) => photo.toString())
        .toList();
    final rating = (memory['rating'] as num?)?.toInt();
    final public = memory['visibility']?.toString() == 'PUBLIC';
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Column(children: [
        Container(
          width: 15,
          height: 15,
          decoration: BoxDecoration(
              color:
                  isLatest ? const Color(0xFF176A50) : const Color(0xFFB7C8BD),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3)),
        ),
        Container(width: 2, height: 260, color: const Color(0xFFD9E2DB)),
      ]),
      const SizedBox(width: 11),
      Expanded(
        child: Container(
          margin: const EdgeInsets.only(bottom: 15),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: const Color(0xFFDDE5DF)),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(
                    date == null
                        ? 'A memorable visit'
                        : DateFormat('MMMM d, yyyy').format(date.toLocal()),
                    style: GoogleFonts.poppins(
                        color: const Color(0xFF176A50),
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: public
                        ? const Color(0xFFE4F2E8)
                        : const Color(0xFFF0F0ED),
                    borderRadius: BorderRadius.circular(99)),
                child: Row(children: [
                  Icon(public ? Icons.public_rounded : Icons.lock_outline,
                      size: 12,
                      color: public
                          ? const Color(0xFF176A50)
                          : Colors.grey.shade600),
                  const SizedBox(width: 3),
                  Text(public ? 'Shared' : 'Private',
                      style: GoogleFonts.poppins(
                          fontSize: 8.5, fontWeight: FontWeight.w600)),
                ]),
              ),
              PopupMenuButton<String>(
                tooltip: 'Memory options',
                onSelected: (value) {
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'delete', child: Text('Delete memory'))
                ],
                icon: const Icon(Icons.more_horiz_rounded, size: 20),
              ),
            ]),
            if ((memory['mood']?.toString() ?? '').isNotEmpty ||
                rating != null) ...[
              Row(children: [
                if ((memory['mood']?.toString() ?? '').isNotEmpty)
                  Text('${memory['mood']}  ',
                      style: GoogleFonts.poppins(fontSize: 11)),
                if (rating != null)
                  ...List.generate(
                      5,
                      (index) => Icon(Icons.star_rounded,
                          size: 15,
                          color: index < rating
                              ? const Color(0xFFE3A72D)
                              : Colors.grey.shade300)),
              ]),
              const SizedBox(height: 7),
            ],
            if ((memory['title']?.toString() ?? '').isNotEmpty)
              Text(memory['title'].toString(),
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            Text(memory['story']?.toString() ?? '',
                style: GoogleFonts.poppins(
                    fontSize: 11.5, height: 1.55, color: Colors.grey.shade800)),
            if ((memory['favoriteMoment']?.toString() ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                    color: const Color(0xFFF2F6EF),
                    borderRadius: BorderRadius.circular(13)),
                child: Text('Favorite moment: ${memory['favoriteMoment']}',
                    style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: const Color(0xFF365346),
                        fontStyle: FontStyle.italic)),
              ),
            ],
            if (photos.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 118,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: photos.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 7),
                  itemBuilder: (_, index) => ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: Image.network(ApiService.assetUrl(photos[index]),
                        width: 155,
                        fit: BoxFit.cover,
                        cacheWidth: 460,
                        errorBuilder: (_, __, ___) => Container(
                            width: 155,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.broken_image_outlined))),
                  ),
                ),
              ),
            ],
          ]),
        ),
      ),
    ]);
  }
}

class _MemoryComposer extends StatefulWidget {
  final String landmarkId;
  const _MemoryComposer({required this.landmarkId});

  @override
  State<_MemoryComposer> createState() => _MemoryComposerState();
}

class _MemoryComposerState extends State<_MemoryComposer> {
  final _title = TextEditingController();
  final _story = TextEditingController();
  final _favorite = TextEditingController();
  final _picker = ImagePicker();
  List<XFile> _photos = [];
  DateTime _visitDate = DateTime.now();
  String _mood = '😊 Happy';
  int _rating = 5;
  bool _sharePublicly = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _story.dispose();
    _favorite.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDate: _visitDate,
    );
    if (selected != null && mounted) setState(() => _visitDate = selected);
  }

  Future<void> _pickPhotos() async {
    final selected =
        await _picker.pickMultiImage(imageQuality: 82, maxWidth: 1800);
    if (selected.isNotEmpty && mounted) {
      setState(() => _photos = selected.take(8).toList());
    }
  }

  Future<void> _save() async {
    if (_story.text.trim().isEmpty) {
      setState(() => _error = 'Write something about this visit.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final token = (await AuthService.getUser())?['token']?.toString() ?? '';
      if (token.isEmpty) throw Exception('Sign in first.');
      final request = http.MultipartRequest(
          'POST', ApiService.uri('/places/${widget.landmarkId}/memories'))
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['title'] = _title.text.trim()
        ..fields['story'] = _story.text.trim()
        ..fields['favoriteMoment'] = _favorite.text.trim()
        ..fields['mood'] = _mood
        ..fields['rating'] = _rating.toString()
        ..fields['visitedAt'] = _visitDate.toIso8601String()
        ..fields['sharePublicly'] = _sharePublicly.toString();
      for (final photo in _photos) {
        request.files.add(await http.MultipartFile.fromPath(
            'photos', photo.path,
            filename: photo.name));
      }
      final response = await request.send();
      final text = await response.stream.bytesToString();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = text.isEmpty ? null : json.decode(text);
        throw Exception(body is Map
            ? body['message'] ?? 'Could not save your memory.'
            : 'Could not save your memory.');
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
  Widget build(BuildContext context) => Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .92),
        padding: EdgeInsets.fromLTRB(
            20, 12, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
        decoration: const BoxDecoration(
          color: Color(0xFFFCFBF7),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(
                  child: Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(99)))),
              const SizedBox(height: 15),
              Text('Preserve this visit',
                  style: GoogleFonts.poppins(
                      fontSize: 22, fontWeight: FontWeight.w800)),
              Text('Create a memory you can return to anytime.',
                  style: GoogleFonts.poppins(
                      fontSize: 10.5, color: Colors.grey.shade600)),
              const SizedBox(height: 17),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: const Color(0xFFEAF2EB),
                      borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    const Icon(Icons.calendar_month_rounded,
                        color: Color(0xFF176A50)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(
                            DateFormat('EEEE, MMMM d, yyyy').format(_visitDate),
                            style: GoogleFonts.poppins(
                                fontSize: 11.5, fontWeight: FontWeight.w600))),
                    const Icon(Icons.edit_calendar_outlined, size: 18),
                  ]),
                ),
              ),
              const SizedBox(height: 13),
              DropdownButtonFormField<String>(
                initialValue: _mood,
                decoration: const InputDecoration(
                    labelText: 'How did this visit feel?',
                    border: OutlineInputBorder()),
                items: const [
                  '😊 Happy',
                  '🤩 Amazed',
                  '😌 Peaceful',
                  '🥹 Nostalgic',
                  '💚 Inspired'
                ]
                    .map((mood) =>
                        DropdownMenuItem(value: mood, child: Text(mood)))
                    .toList(),
                onChanged: (value) => setState(() => _mood = value ?? _mood),
              ),
              const SizedBox(height: 13),
              TextField(
                controller: _title,
                maxLength: 100,
                decoration: const InputDecoration(
                    labelText: 'Memory title (optional)',
                    hintText: 'A quiet afternoon at the park',
                    border: OutlineInputBorder()),
              ),
              TextField(
                controller: _story,
                minLines: 4,
                maxLines: 7,
                maxLength: 4000,
                decoration: const InputDecoration(
                    labelText: 'Your story',
                    hintText:
                        'What happened, who were you with, and what will you remember?',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 11),
              TextField(
                controller: _favorite,
                maxLines: 2,
                maxLength: 300,
                decoration: const InputDecoration(
                    labelText: 'Favorite moment (optional)',
                    border: OutlineInputBorder()),
              ),
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
                          iconSize: 30,
                        )),
              ),
              OutlinedButton.icon(
                onPressed: _pickPhotos,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(_photos.isEmpty
                    ? 'Add photos'
                    : '${_photos.length} photos selected'),
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _sharePublicly,
                activeTrackColor: const Color(0xFF176A50),
                onChanged: (value) => setState(() => _sharePublicly = value),
                title: Text('Share with the community',
                    style: GoogleFonts.poppins(
                        fontSize: 12.5, fontWeight: FontWeight.w700)),
                subtitle: Text(
                    'Your story, photos, and rating become visible to other tourists. Your rating still counts only once.',
                    style: GoogleFonts.poppins(
                        fontSize: 9.5, color: Colors.grey.shade600)),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style: GoogleFonts.poppins(
                        color: const Color(0xFFC34738), fontSize: 10.5)),
              ],
              const SizedBox(height: 13),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF176A50)),
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.auto_stories_rounded),
                  label:
                      Text(_saving ? 'Saving memory...' : 'Save to my journey'),
                ),
              ),
            ]),
          ),
        ),
      );
}

class _JournalEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Future<void> Function()? action;

  const _JournalEmpty(
      {required this.icon,
      required this.title,
      required this.message,
      this.action});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFDDE5DF))),
        child: Column(children: [
          Icon(icon, size: 40, color: const Color(0xFF176A50)),
          const SizedBox(height: 10),
          Text(title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text(message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 10.5, height: 1.5, color: Colors.grey.shade600)),
          if (action != null) ...[
            const SizedBox(height: 14),
            OutlinedButton(onPressed: action, child: const Text('Continue')),
          ]
        ]),
      );
}
