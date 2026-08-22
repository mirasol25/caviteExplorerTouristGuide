import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:geolocator/geolocator.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'partner_onboarding_screen.dart';
import 'partner_redemption_report_screen.dart';

class PartnerDashboardScreen extends StatefulWidget {
  const PartnerDashboardScreen({super.key});

  @override
  State<PartnerDashboardScreen> createState() => _PartnerDashboardScreenState();
}

class _PartnerDashboardScreenState extends State<PartnerDashboardScreen> {
  bool _loading = true;
  bool _uploadingLogo = false;
  String? _error;
  Map<String, dynamic> _data = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = await AuthService.getUser();
      final response = await http.get(
        ApiService.uri('/rewards/partner/dashboard'),
        headers: {'Authorization': 'Bearer ${user?['token'] ?? ''}'},
      );
      final body = json.decode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(body['message'] ?? 'Could not load partner dashboard.');
      }
      _data = Map<String, dynamic>.from(body);
      _error = null;
    } catch (error) {
      _error = error.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _scan() async {
    final accepted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const PartnerScannerScreen()),
    );
    if (accepted == true) {
      setState(() => _loading = true);
      await _load();
    }
  }

  Future<void> _changeLogo() async {
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
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Business logo updated.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ));
      }
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  Future<void> _editDiscount(Map<String, dynamic> business) async {
    final title = TextEditingController(
        text: business['proposedDiscountTitle']?.toString() ?? '');
    final label = TextEditingController(
        text: business['proposedDiscountLabel']?.toString() ?? '');
    final description = TextEditingController(
        text: business['proposedDiscountDescription']?.toString() ?? '');
    final updated = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        var saving = false;
        String? error;
        return StatefulBuilder(builder: (context, setDialogState) {
          Future<void> save() async {
            if (title.text.trim().isEmpty || label.text.trim().isEmpty) {
              setDialogState(
                  () => error = 'Discount title and label are required.');
              return;
            }
            setDialogState(() {
              saving = true;
              error = null;
            });
            try {
              final user = await AuthService.getUser();
              final response = await http.patch(
                ApiService.uri('/rewards/partner/discount'),
                headers: {
                  'Authorization': 'Bearer ${user?['token'] ?? ''}',
                  'Content-Type': 'application/json',
                },
                body: json.encode({
                  'title': title.text.trim(),
                  'label': label.text.trim(),
                  'description': description.text.trim(),
                }),
              );
              final body = json.decode(response.body);
              if (response.statusCode < 200 || response.statusCode >= 300) {
                throw Exception(body['message'] ?? 'Could not update reward.');
              }
              if (dialogContext.mounted) Navigator.pop(dialogContext, true);
            } catch (exception) {
              setDialogState(() {
                saving = false;
                error = exception.toString().replaceFirst('Exception: ', '');
              });
            }
          }

          return AlertDialog(
            backgroundColor: const Color(0xFFF9FAF7),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            icon: const CircleAvatar(
              backgroundColor: Color(0xFFE5F2E9),
              child: Icon(Icons.local_offer_rounded, color: Color(0xFF176A50)),
            ),
            title: Text('Edit badge reward',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 420,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                    controller: title,
                    maxLength: 100,
                    decoration: const InputDecoration(
                      labelText: 'Offer title',
                      hintText: 'Example: Explorer meal discount',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: label,
                    maxLength: 50,
                    decoration: const InputDecoration(
                      labelText: 'Discount label',
                      hintText: 'Example: 10% OFF',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: description,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'Conditions',
                      hintText: 'Explain eligible items and restrictions.',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(error!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                              color: const Color(0xFFC34738), fontSize: 10.5)),
                    ),
                ]),
              ),
            ),
            actions: [
              TextButton(
                onPressed:
                    saving ? null : () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: saving ? null : save,
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF176A50)),
                icon: saving
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded),
                label: Text(saving ? 'Saving' : 'Save reward'),
              ),
            ],
          );
        });
      },
    );
    title.dispose();
    label.dispose();
    description.dispose();
    if (updated == true) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Badge reward updated.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final business = _data['business'] is Map
        ? Map<String, dynamic>.from(_data['business'])
        : <String, dynamic>{};
    final stats = _data['stats'] is Map
        ? Map<String, dynamic>.from(_data['stats'])
        : <String, dynamic>{};
    final recent = ((_data['recent'] as List?) ?? const []).whereType<Map>();
    final approved = _data['applicationStatus'] == 'approved';
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F4),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFF6F7F4),
        surfaceTintColor: Colors.transparent,
        title: Text('Partner workspace',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
              tooltip: 'Sign out',
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : !approved
                  ? PartnerOnboardingScreen(
                      key: ValueKey(
                          '${business['id']}-${business['updatedAt']}'),
                      application: business.isEmpty ? null : business,
                      onChanged: () {
                        setState(() => _loading = true);
                        _load();
                      },
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [
                                Color(0xFF123F33),
                                Color(0xFF176A50)
                              ]),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('PARTNER OVERVIEW',
                                      style: GoogleFonts.poppins(
                                          color: const Color(0xFFD8F270),
                                          fontSize: 9,
                                          letterSpacing: 1,
                                          fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 8),
                                  Row(children: [
                                    Container(
                                      width: 66,
                                      height: 66,
                                      clipBehavior: Clip.antiAlias,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white54, width: 2),
                                      ),
                                      child: business['image']
                                                  ?.toString()
                                                  .isNotEmpty ==
                                              true
                                          ? Padding(
                                              padding: const EdgeInsets.all(2),
                                              child: ClipOval(
                                                child: Image.network(
                                                  ApiService.assetUrl(
                                                      business['image']),
                                                  fit: BoxFit.contain,
                                                  errorBuilder: (_, __, ___) =>
                                                      const Icon(
                                                          Icons
                                                              .storefront_rounded,
                                                          color: Color(
                                                              0xFF176A50)),
                                                ),
                                              ),
                                            )
                                          : const Icon(Icons.storefront_rounded,
                                              color: Color(0xFF176A50),
                                              size: 31),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                        child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            business['name']?.toString() ??
                                                'Business',
                                            style: GoogleFonts.poppins(
                                                color: Colors.white,
                                                fontSize: 21,
                                                fontWeight: FontWeight.w700)),
                                        Text(
                                          business['address']?.toString() ?? '',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.poppins(
                                              color: Colors.white70,
                                              fontSize: 10.5),
                                        ),
                                      ],
                                    )),
                                    IconButton(
                                      tooltip: 'Change business logo',
                                      onPressed:
                                          _uploadingLogo ? null : _changeLogo,
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.white12,
                                        foregroundColor: Colors.white,
                                      ),
                                      icon: _uploadingLogo
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white))
                                          : const Icon(Icons.edit_rounded,
                                              size: 19),
                                    ),
                                  ]),
                                ]),
                          ),
                          const SizedBox(height: 15),
                          Row(children: [
                            Expanded(
                                child: _StatCard(
                                    label: 'Today',
                                    value: '${stats['today'] ?? 0}')),
                            const SizedBox(width: 11),
                            Expanded(
                                child: _StatCard(
                                    label: 'All scans',
                                    value: '${stats['total'] ?? 0}')),
                          ]),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const PartnerRedemptionReportScreen())),
                              icon: const Icon(Icons.analytics_outlined),
                              label: const Text('View history and reports'),
                            ),
                          ),
                          const SizedBox(height: 15),
                          _DiscountCard(
                            business: business,
                            onEdit: () => _editDiscount(business),
                          ),
                          const SizedBox(height: 15),
                          SizedBox(
                            height: 58,
                            child: FilledButton.icon(
                              onPressed: _scan,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF176A50),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(17)),
                              ),
                              icon: const Icon(Icons.qr_code_scanner_rounded,
                                  size: 27),
                              label: Text('Scan badge QR',
                                  style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text('Recent redemptions',
                              style: GoogleFonts.poppins(
                                  fontSize: 17, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 9),
                          if (recent.isEmpty)
                            Text('No badge rewards have been scanned yet.',
                                style: GoogleFonts.poppins(
                                    color: Colors.grey.shade600, fontSize: 11))
                          else
                            ...recent.map((item) {
                              final badge = item['userBadge'] is Map
                                  ? item['userBadge'] as Map
                                  : const {};
                              final landmark = badge['landmark'] is Map
                                  ? badge['landmark'] as Map
                                  : const {};
                              final offer = item['offer'] is Map
                                  ? item['offer'] as Map
                                  : const {};
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                tileColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15)),
                                leading: const CircleAvatar(
                                  backgroundColor: Color(0xFFE4F2E8),
                                  child: Icon(Icons.check_rounded,
                                      color: Color(0xFF176A50)),
                                ),
                                title: Text(
                                    landmark['name']?.toString() ?? 'Badge',
                                    style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                    offer['discountLabel']?.toString() ??
                                        'Reward',
                                    style: GoogleFonts.poppins(fontSize: 10)),
                              );
                            }),
                        ],
                      ),
                    ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: const Color(0xFFDDE5E0))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              style: GoogleFonts.poppins(
                  color: const Color(0xFF176A50),
                  fontSize: 25,
                  fontWeight: FontWeight.w800)),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 10.5, color: Colors.grey.shade600)),
        ]),
      );
}

class _DiscountCard extends StatelessWidget {
  final Map<String, dynamic> business;
  final VoidCallback onEdit;

  const _DiscountCard({required this.business, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final title = business['proposedDiscountTitle']?.toString() ?? 'Reward';
    final label =
        business['proposedDiscountLabel']?.toString() ?? 'Badge reward';
    final description =
        business['proposedDiscountDescription']?.toString() ?? '';
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAEA),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFE8D59D)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const CircleAvatar(
          backgroundColor: Color(0xFFF3E3B5),
          child: Icon(Icons.local_offer_rounded, color: Color(0xFF8B6728)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFD8F270),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(label,
                  style: GoogleFonts.poppins(
                      color: const Color(0xFF173F34),
                      fontSize: 10,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 7),
            Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w700)),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                      fontSize: 9.5, height: 1.4, color: Colors.black54)),
            ],
          ]),
        ),
        IconButton(
          tooltip: 'Edit badge reward',
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined, color: Color(0xFF176A50)),
        ),
      ]),
    );
  }
}

class PartnerScannerScreen extends StatefulWidget {
  const PartnerScannerScreen({super.key});

  @override
  State<PartnerScannerScreen> createState() => _PartnerScannerScreenState();
}

class _PartnerScannerScreenState extends State<PartnerScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _processing = false;

  Future<void> _detected(BarcodeCapture capture) async {
    if (_processing) return;
    String? value;
    for (final barcode in capture.barcodes) {
      if (barcode.rawValue?.isNotEmpty == true) {
        value = barcode.rawValue;
        break;
      }
    }
    if (value == null) return;
    await _redeem(value);
  }

  Future<void> _redeem(String value) async {
    if (_processing) return;
    setState(() => _processing = true);
    await _controller.stop();
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Enable precise location to scan a badge.');
      }
      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final user = await AuthService.getUser();
      final response = await http.post(
        ApiService.uri('/rewards/partner/scan'),
        headers: {
          'Authorization': 'Bearer ${user?['token'] ?? ''}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'token': value,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy
        }),
      );
      final body = json.decode(response.body);
      if (!mounted) return;
      final accepted = response.statusCode >= 200 && response.statusCode < 300;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: Icon(
            accepted ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: accepted ? const Color(0xFF176A50) : Colors.redAccent,
            size: 52,
          ),
          title: Text(accepted ? 'Discount accepted' : 'Redemption declined',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          content: Text(
              body['message']?.toString() ?? 'Could not verify badge.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 12)),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (accepted) {
        Navigator.pop(context, true);
      } else {
        setState(() => _processing = false);
        await _controller.start();
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', ''))));
      setState(() => _processing = false);
      await _controller.start();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text('Scan badge QR'),
        ),
        body: Stack(fit: StackFit.expand, children: [
          MobileScanner(controller: _controller, onDetect: _detected),
          Center(
            child: Container(
              width: 270,
              height: 270,
              decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  borderRadius: BorderRadius.circular(24)),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 42,
            child: Text(
              _processing
                  ? 'Verifying badge...'
                  : 'Place the explorer’s badge QR inside the frame.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 12),
            ),
          ),
        ]),
      );
}
