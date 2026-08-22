import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../services/api_service.dart';
import '../services/auth_service.dart';

class PartnerRedemptionReportScreen extends StatefulWidget {
  const PartnerRedemptionReportScreen({super.key});
  @override
  State<PartnerRedemptionReportScreen> createState() =>
      _PartnerRedemptionReportScreenState();
}

class _PartnerRedemptionReportScreenState
    extends State<PartnerRedemptionReportScreen> {
  String _range = '30d';
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _report = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final user = await AuthService.getUser();
      final response = await http.get(
          ApiService.uri('/rewards/partner/redemptions?range=$_range'),
          headers: {'Authorization': 'Bearer ${user?['token'] ?? ''}'});
      final body = json.decode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(body['message'] ?? 'Could not load redemption report.');
      }
      _report = Map<String, dynamic>.from(body);
      _error = null;
    } catch (error) {
      _error = error.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _date(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return 'Date unavailable';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    return '${months[date.month - 1]} ${date.day}, ${date.year} · $hour:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}';
  }

  @override
  Widget build(BuildContext context) {
    final summary =
        _report['summary'] is Map ? _report['summary'] as Map : const {};
    final rows = ((_report['rows'] as List?) ?? const []).whereType<Map>();
    final offers = ((_report['byOffer'] as List?) ?? const []).whereType<Map>();
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F4),
      appBar: AppBar(
          backgroundColor: const Color(0xFFF6F7F4),
          surfaceTintColor: Colors.transparent,
          title: Text('Redemption reports',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
                      children: [
                        Semantics(
                            label: 'Report time range',
                            child: DropdownButtonFormField<String>(
            initialValue: _range,
                              decoration: InputDecoration(
                                  labelText: 'Report period',
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      borderSide: BorderSide.none)),
                              items: const [
                                DropdownMenuItem(
                                    value: '7d', child: Text('Last 7 days')),
                                DropdownMenuItem(
                                    value: '30d', child: Text('Last 30 days')),
                                DropdownMenuItem(
                                    value: 'all', child: Text('All time'))
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  _range = value;
                                  _load();
                                }
                              },
                            )),
                        const SizedBox(height: 16),
                        Row(children: [
                          Expanded(
                              child: _ReportMetric('Today', summary['today'])),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _ReportMetric(
                                  '7 days', summary['last7Days'])),
                          const SizedBox(width: 10),
                          Expanded(
                              child:
                                  _ReportMetric('All time', summary['allTime']))
                        ]),
                        const SizedBox(height: 22),
                        Text('Reward performance',
                            style: GoogleFonts.poppins(
                                fontSize: 17, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 9),
                        if (offers.isEmpty)
                          const Text('No reward activity for this period.')
                        else
                          ...offers.map<Widget>((offer) => Card(
                                elevation: 0,
                                child: ListTile(
                                  leading: const Icon(
                                      Icons.local_offer_outlined,
                                      color: Color(0xFF176A50)),
                                  title: Text(
                                      offer['title']?.toString() ?? 'Reward'),
                                  subtitle: Text(
                                      offer['discountLabel']?.toString() ?? ''),
                                  trailing: Text('${offer['count'] ?? 0}',
                                      style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF176A50))),
                                ),
                              )),
                        const SizedBox(height: 22),
                        Text('Redemption history',
                            style: GoogleFonts.poppins(
                                fontSize: 17, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 9),
                        if (rows.isEmpty)
                          const Text('No redemptions in this period.')
                        else
                          ...rows.map<Widget>((item) {
                            final badge = item['userBadge'] is Map
                                ? item['userBadge'] as Map
                                : const {};
                            final landmark = badge['landmark'] is Map
                                ? badge['landmark'] as Map
                                : const {};
                            final offer = item['offer'] is Map
                                ? item['offer'] as Map
                                : const {};
                            return Semantics(
                              label:
                                  '${offer['discountLabel'] ?? 'Reward'} redeemed for ${landmark['name'] ?? 'landmark'} on ${_date(item['redeemedAt'])}',
                              child: Card(
                                elevation: 0,
                                margin: const EdgeInsets.only(bottom: 9),
                                child: ListTile(
                                  leading: const CircleAvatar(
                                      backgroundColor: Color(0xFFE4F2E8),
                                      child: Icon(Icons.check_rounded,
                                          color: Color(0xFF176A50))),
                                  title: Text(
                                      landmark['name']?.toString() ??
                                          'Landmark badge',
                                      style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                  subtitle: Text(
                                      '${offer['discountLabel'] ?? 'Reward'}\n${_date(item['redeemedAt'])}',
                                      style: GoogleFonts.poppins(fontSize: 10)),
                                  isThreeLine: true,
                                ),
                              ),
                            );
                          }),
                      ]),
                ),
    );
  }
}

class _ReportMetric extends StatelessWidget {
  final String label;
  final dynamic value;
  const _ReportMetric(this.label, this.value);
  @override
  Widget build(BuildContext context) => Semantics(
      label: '$label: ${value ?? 0} redemptions',
      child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(17)),
          child: Column(children: [
            Text('${value ?? 0}',
                style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF176A50))),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 10, color: Colors.grey.shade600))
          ])));
}
