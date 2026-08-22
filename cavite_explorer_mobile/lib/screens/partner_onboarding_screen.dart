import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';

class PartnerOnboardingScreen extends StatefulWidget {
  final Map<String, dynamic>? application;
  final VoidCallback onChanged;
  const PartnerOnboardingScreen(
      {super.key, this.application, required this.onChanged});

  @override
  State<PartnerOnboardingScreen> createState() =>
      _PartnerOnboardingScreenState();
}

class _PartnerOnboardingScreenState extends State<PartnerOnboardingScreen> {
  static const List<String> _businessCategories = [
    'Coffee Shop',
    'Restaurant',
    'Fast Food',
    'Bakery',
    'Dessert Shop',
    'Hotel / Accommodation',
    'Souvenir Shop',
    'Retail Store',
    'Recreation',
    'Wellness / Spa',
    'Tourism Service',
    'Other',
  ];
  final _formKey = GlobalKey<FormState>();
  final _map = MapController();
  late final Map<String, TextEditingController> _fields;
  List<dynamic> _landmarks = [];
  LatLng? _pin;
  TimeOfDay? _openingTime;
  TimeOfDay? _closingTime;
  String _logoPath = '';
  bool _saving = false;
  bool _uploadingLogo = false;
  bool _locating = false;

  String get _status =>
      widget.application?['approvalStatus']?.toString() ?? 'draft';
  bool get _pending => _status == 'pending';

  @override
  void initState() {
    super.initState();
    final app = widget.application ?? const {};
    String value(String key) => app[key]?.toString() ?? '';
    _fields = {
      for (final key in [
        'name',
        'category',
        'address',
        'municipality',
        'barangay',
        'contact',
        'operatingHours',
        'description',
        'proposedDiscountTitle',
        'proposedDiscountLabel',
        'proposedDiscountDescription'
      ])
        key: TextEditingController(text: value(key))
    };
    _logoPath = value('image');
    _restoreOperatingHours(value('operatingHours'));
    final lat = double.tryParse(value('latitude'));
    final lng = double.tryParse(value('longitude'));
    if (lat != null && lng != null) _pin = LatLng(lat, lng);
    _loadLandmarks();
  }

  Future<void> _loadLandmarks() async {
    try {
      final values = await ApiService.getLandmarks();
      if (mounted) setState(() => _landmarks = values);
    } catch (_) {}
  }

  Future<Map<String, String>> _headers() async => {
        'Authorization':
            'Bearer ${(await AuthService.getUser())?['token'] ?? ''}',
        'Content-Type': 'application/json'
      };

  double _distanceMeters(LatLng a, LatLng b) {
    return const Distance().as(LengthUnit.Meter, a, b);
  }

  List<Map<String, dynamic>> get _nearbyBadgeLandmarks {
    if (_pin == null) return [];
    final nearby = _landmarks
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map((item) {
          final latitude = double.tryParse(item['latitude']?.toString() ?? '');
          final longitude =
              double.tryParse(item['longitude']?.toString() ?? '');
          if (latitude == null || longitude == null) return null;
          return {
            ...item,
            'distanceMeters':
                _distanceMeters(_pin!, LatLng(latitude, longitude))
          };
        })
        .whereType<Map<String, dynamic>>()
        .where((item) => (item['distanceMeters'] as double) <= 2500)
        .toList();
    nearby.sort((a, b) => (a['distanceMeters'] as double)
        .compareTo(b['distanceMeters'] as double));
    return nearby;
  }

  void _restoreOperatingHours(String value) {
    final match = RegExp(
            r'^\s*(\d{1,2}):(\d{2})\s*(AM|PM)\s*(?:-|\u2013)\s*(\d{1,2}):(\d{2})\s*(AM|PM)\s*$',
            caseSensitive: false)
        .firstMatch(value);
    if (match == null) return;
    _openingTime =
        _toTimeOfDay(match.group(1)!, match.group(2)!, match.group(3)!);
    _closingTime =
        _toTimeOfDay(match.group(4)!, match.group(5)!, match.group(6)!);
  }

  TimeOfDay? _toTimeOfDay(String hourText, String minuteText, String period) {
    var hour = int.tryParse(hourText);
    final minute = int.tryParse(minuteText);
    if (hour == null ||
        minute == null ||
        hour < 1 ||
        hour > 12 ||
        minute < 0 ||
        minute > 59) return null;
    if (hour == 12) hour = 0;
    if (period.toUpperCase() == 'PM') hour += 12;
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> _selectOperatingTime({required bool opening}) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: opening
          ? (_openingTime ?? const TimeOfDay(hour: 9, minute: 0))
          : (_closingTime ?? const TimeOfDay(hour: 18, minute: 0)),
      helpText: opening ? 'SELECT OPENING TIME' : 'SELECT CLOSING TIME',
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (opening) {
        _openingTime = selected;
      } else {
        _closingTime = selected;
      }
      if (_openingTime != null && _closingTime != null) {
        final localizations = MaterialLocalizations.of(context);
        final opens = localizations.formatTimeOfDay(_openingTime!,
            alwaysUse24HourFormat: false);
        final closes = localizations.formatTimeOfDay(_closingTime!,
            alwaysUse24HourFormat: false);
        _fields['operatingHours']!.text = '$opens - $closes';
      }
    });
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever)
        throw Exception('Location permission is required.');
      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      await _setPin(LatLng(position.latitude, position.longitude));
    } catch (error) {
      _show(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _setPin(LatLng point) async {
    setState(() => _pin = point);
    _map.move(point, 16);
    try {
      final response = await http.get(
          Uri.parse(
              'https://nominatim.openstreetmap.org/reverse?format=json&addressdetails=1&lat=${point.latitude}&lon=${point.longitude}'),
          headers: {
            'User-Agent': 'CaviteExplorerPartner/1.0'
          }).timeout(const Duration(seconds: 7));
      if (response.statusCode != 200) return;
      final body = json.decode(response.body);
      final address = body['address'] is Map
          ? Map<String, dynamic>.from(body['address'])
          : <String, dynamic>{};
      _fields['address']!.text =
          body['display_name']?.toString() ?? _fields['address']!.text;
      _fields['municipality']!.text = (address['city'] ??
              address['municipality'] ??
              address['town'] ??
              address['village'] ??
              '')
          .toString();
      _fields['barangay']!.text = (address['suburb'] ??
              address['quarter'] ??
              address['neighbourhood'] ??
              address['village'] ??
              '')
          .toString();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Map<String, dynamic> _payload() => {
        for (final item in _fields.entries) item.key: item.value.text.trim(),
        'image': _logoPath.isEmpty ? null : _logoPath,
        'latitude': _pin?.latitude,
        'longitude': _pin?.longitude,
        'proposedBadgeLandmarkId': _nearbyBadgeLandmarks.isEmpty
            ? null
            : _nearbyBadgeLandmarks.first['id'],
      };

  Future<void> _pickLogo() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1400,
      maxHeight: 1400,
    );
    if (picked == null || !mounted) return;
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      maxWidth: 1200,
      maxHeight: 1200,
      compressFormat: ImageCompressFormat.png,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Fill the logo circle',
          toolbarColor: const Color(0xFF176A50),
          toolbarWidgetColor: Colors.white,
          cropStyle: CropStyle.circle,
          lockAspectRatio: true,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: 'Fill the logo circle',
          cropStyle: CropStyle.circle,
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );
    if (cropped == null || !mounted) return;
    setState(() => _uploadingLogo = true);
    try {
      final user = await AuthService.getUser();
      final request = http.MultipartRequest(
        'POST',
        ApiService.uri('/rewards/partner/logo'),
      )
        ..headers['Authorization'] = 'Bearer ${user?['token'] ?? ''}'
        ..files.add(await http.MultipartFile.fromPath(
          'file',
          cropped.path,
          filename: 'partner-logo.png',
          contentType: MediaType('image', 'png'),
        ));
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      final body = json.decode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(body['message'] ?? 'Could not upload the logo.');
      }
      setState(() => _logoPath = body['image']?.toString() ?? '');
      _show('Business logo uploaded.');
    } catch (error) {
      _show(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  Future<void> _save({bool submit = false}) async {
    if (!_formKey.currentState!.validate()) return;
    if (_pin == null) return _show('Pin your business location on the map.');
    if (submit && _nearbyBadgeLandmarks.isEmpty)
      return _show(
          'Pin the business within 2.5 km of at least one landmark badge.');
    setState(() => _saving = true);
    try {
      final saved = await http.put(
          ApiService.uri('/rewards/partner/application'),
          headers: await _headers(),
          body: json.encode(_payload()));
      final savedBody = json.decode(saved.body);
      if (saved.statusCode < 200 || saved.statusCode >= 300)
        throw Exception(savedBody['message'] ?? 'Could not save profile.');
      if (submit) {
        final response = await http.post(
            ApiService.uri('/rewards/partner/application/submit'),
            headers: await _headers());
        final body = json.decode(response.body);
        if (response.statusCode < 200 || response.statusCode >= 300)
          throw Exception(body['message'] ?? 'Could not submit profile.');
      }
      _show(submit
          ? 'Application sent for administrator approval.'
          : 'Draft saved.');
      widget.onChanged();
    } catch (error) {
      _show(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _show(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_pending)
      return _statusView(
          Icons.hourglass_top_rounded,
          'Application under review',
          'An administrator will review your business, location, and discount. You can scan badges after approval.');
    final reason = widget.application?['rejectionReason']?.toString();
    final center = _pin ?? const LatLng(14.28, 120.95);
    return Form(
        key: _formKey,
        child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
            children: [
              _header(reason),
              const SizedBox(height: 15),
              _section(
                  '1',
                  'Pin your business',
                  'This approved pin controls nearby badge eligibility.',
                  Column(children: [
                    ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: SizedBox(
                            height: 270,
                            child: FlutterMap(
                                mapController: _map,
                                options: MapOptions(
                                    initialCenter: center,
                                    initialZoom: _pin == null ? 10 : 16,
                                    onTap: (_, point) => _setPin(point)),
                                children: [
                                  TileLayer(
                                      urlTemplate:
                                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      userAgentPackageName:
                                          'com.example.cavite_explorer_mobile'),
                                  if (_pin != null)
                                    MarkerLayer(markers: [
                                      Marker(
                                          point: _pin!,
                                          width: 52,
                                          height: 52,
                                          child: const Icon(
                                              Icons.location_on_rounded,
                                              color: Color(0xFF176A50),
                                              size: 48))
                                    ]),
                                ]))),
                    const SizedBox(height: 10),
                    SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                            onPressed: _locating ? null : _useCurrentLocation,
                            icon: const Icon(Icons.my_location_rounded),
                            label: Text(_locating
                                ? 'Finding location…'
                                : 'Use my current location'))),
                  ])),
              const SizedBox(height: 14),
              _section(
                  '2',
                  'Business information',
                  'Visitors will see these details after approval.',
                  Column(children: [
                    _logoPicker(),
                    _field('name', 'Business name'),
                    _categoryDropdown(),
                    _field('address', 'Complete address', lines: 2),
                    Row(children: [
                      Expanded(
                          child: _field('municipality', 'Municipality / city')),
                      const SizedBox(width: 10),
                      Expanded(child: _field('barangay', 'Barangay'))
                    ]),
                    _field('contact', 'Contact number'),
                    _operatingHoursPicker(),
                    _field('description', 'Business description', lines: 3),
                  ])),
              const SizedBox(height: 14),
              _section(
                  '3',
                  'Discount proposal',
                  'Nearby landmark badges are accepted automatically.',
                  Column(children: [
                    _automaticBadgeCoverage(),
                    const SizedBox(height: 11),
                    _field('proposedDiscountTitle', 'Offer title'),
                    _field('proposedDiscountLabel', 'Discount, e.g. 10% OFF'),
                    _field('proposedDiscountDescription', 'Offer conditions',
                        lines: 3),
                  ])),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(
                    child: OutlinedButton(
                        onPressed: _saving ? null : () => _save(),
                        child: const Text('Save draft'))),
                const SizedBox(width: 10),
                Expanded(
                    flex: 2,
                    child: FilledButton(
                        onPressed: _saving ? null : () => _save(submit: true),
                        style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF176A50)),
                        child:
                            Text(_saving ? 'Saving…' : 'Submit for approval')))
              ]),
            ]));
  }

  Widget _header(String? reason) => Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF123F33), Color(0xFF176A50)]),
          borderRadius: BorderRadius.circular(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('PARTNER ONBOARDING',
            style: GoogleFonts.poppins(
                color: const Color(0xFFD8F270),
                fontSize: 9,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 7),
        Text(
            _status == 'changes_requested'
                ? 'Update your application'
                : 'Set up your business',
            style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700)),
        if (reason?.isNotEmpty == true)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(reason!,
                  style:
                      GoogleFonts.poppins(color: Colors.white70, fontSize: 11)))
      ]));
  Widget _section(String number, String title, String subtitle, Widget child) =>
      Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(21),
              border: Border.all(color: const Color(0xFFDDE5E0))),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(
                  radius: 13,
                  backgroundColor: const Color(0xFF176A50),
                  child: Text(number,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 11))),
              const SizedBox(width: 9),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style:
                            GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                    Text(subtitle,
                        style: GoogleFonts.poppins(
                            fontSize: 9.5, color: Colors.black54))
                  ]))
            ]),
            const SizedBox(height: 14),
            child
          ]));
  Widget _categoryDropdown() {
    final savedCategory = _fields['category']!.text.trim();
    final categories = <String>[..._businessCategories];
    if (savedCategory.isNotEmpty && !categories.contains(savedCategory))
      categories.insert(0, savedCategory);
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: DropdownButtonFormField<String>(
        initialValue: savedCategory.isEmpty ? null : savedCategory,
        isExpanded: true,
        decoration: _decoration('Business category'),
        hint: const Text('Select a category'),
        items: categories
            .map((category) => DropdownMenuItem(
                value: category,
                child: Text(category, overflow: TextOverflow.ellipsis)))
            .toList(),
        onChanged: (value) => _fields['category']!.text = value ?? '',
        validator: (value) => value == null || value.isEmpty
            ? 'Choose a business category'
            : null,
      ),
    );
  }

  Widget _logoPicker() => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F8F5),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: const Color(0xFFD7E4DC)),
        ),
        child: Row(children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFC8D9CF), width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: _logoPath.isEmpty
                ? const Icon(Icons.storefront_rounded,
                    color: Color(0xFF176A50), size: 34)
                : Image.network(
                    ApiService.assetUrl(_logoPath),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image_outlined,
                        color: Color(0xFF176A50)),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Business logo',
                  style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(
                  'Zoom and position the image until it fills the circle. JPG, PNG, or WebP up to 5 MB.',
                  style: GoogleFonts.poppins(
                      fontSize: 9.5, height: 1.35, color: Colors.black54)),
              const SizedBox(height: 9),
              OutlinedButton.icon(
                onPressed: _uploadingLogo ? null : _pickLogo,
                icon: _uploadingLogo
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: Text(_logoPath.isEmpty ? 'Add logo' : 'Change logo'),
              ),
            ],
          )),
        ]),
      );
  Widget _operatingHoursPicker() => Padding(
        padding: const EdgeInsets.only(bottom: 11),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
              padding: const EdgeInsets.only(left: 3, bottom: 7),
              child: Text('Operating hours',
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87))),
          Row(children: [
            Expanded(
                child: _timeSelector(
                    label: 'Opens',
                    value: _openingTime,
                    onTap: () => _selectOperatingTime(opening: true))),
            const SizedBox(width: 10),
            Expanded(
                child: _timeSelector(
                    label: 'Closes',
                    value: _closingTime,
                    onTap: () => _selectOperatingTime(opening: false))),
          ]),
        ]),
      );
  Widget _automaticBadgeCoverage() {
    final nearby = _nearbyBadgeLandmarks;
    final hasPin = _pin != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: nearby.isNotEmpty
            ? const Color(0xFFEAF5ED)
            : const Color(0xFFFFF5E8),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
            color: nearby.isNotEmpty
                ? const Color(0xFFC8E2D0)
                : const Color(0xFFF0D3A7)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(
              nearby.isNotEmpty
                  ? Icons.verified_rounded
                  : Icons.location_searching_rounded,
              color: nearby.isNotEmpty
                  ? const Color(0xFF176A50)
                  : const Color(0xFFB46B19)),
          const SizedBox(width: 9),
          Expanded(
              child: Text(
                  nearby.isNotEmpty
                      ? '${nearby.length} badge${nearby.length == 1 ? '' : 's'} accepted automatically'
                      : hasPin
                          ? 'No landmark badges within 2.5 km'
                          : 'Pin the business to find accepted badges',
                  style: GoogleFonts.poppins(
                      fontSize: 12, fontWeight: FontWeight.w700))),
        ]),
        if (nearby.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...nearby.map((landmark) => Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Row(children: [
                  const Icon(Icons.workspace_premium_rounded,
                      size: 18, color: Color(0xFF176A50)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(
                          landmark['badgeName']?.toString() ??
                              '${landmark['name']} Explorer',
                          style: GoogleFonts.poppins(
                              fontSize: 11, fontWeight: FontWeight.w600))),
                  Text(
                      '${((landmark['distanceMeters'] as double) / 1000).toStringAsFixed(1)} km',
                      style: GoogleFonts.poppins(
                          fontSize: 10, color: Colors.black54)),
                ]),
              )),
        ] else if (hasPin)
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
                'Move the business pin closer to a landmark before submitting.',
                style: GoogleFonts.poppins(
                    fontSize: 10, color: const Color(0xFF8B5A22))),
          ),
      ]),
    );
  }

  Widget _timeSelector(
          {required String label,
          required TimeOfDay? value,
          required VoidCallback onTap}) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: InputDecorator(
          decoration: _decoration(label)
              .copyWith(prefixIcon: const Icon(Icons.schedule_rounded)),
          child: Text(
              value == null
                  ? 'Select time'
                  : MaterialLocalizations.of(context)
                      .formatTimeOfDay(value, alwaysUse24HourFormat: false),
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: value == null ? Colors.black45 : Colors.black87)),
        ),
      );
  Widget _field(String key, String label, {int lines = 1}) => Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: TextFormField(
          controller: _fields[key],
          maxLines: lines,
          decoration: _decoration(label),
          validator: (value) => [
                    'name',
                    'category',
                    'address',
                    'municipality',
                    'contact',
                    'proposedDiscountTitle',
                    'proposedDiscountLabel'
                  ].contains(key) &&
                  (value == null || value.trim().isEmpty)
              ? 'Required'
              : null));
  InputDecoration _decoration(String label) => InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFF8FAF8),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)));
  Widget _statusView(IconData icon, String title, String body) => Center(
      child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(children: [
            CircleAvatar(
                radius: 42,
                backgroundColor: const Color(0xFFE4F2E8),
                child: Icon(icon, size: 42, color: const Color(0xFF176A50))),
            const SizedBox(height: 19),
            Text(title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 23, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(body,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: Colors.black54)),
            const SizedBox(height: 22),
            OutlinedButton.icon(
                onPressed: widget.onChanged,
                icon: const Icon(Icons.refresh),
                label: const Text('Check status'))
          ])));
}
