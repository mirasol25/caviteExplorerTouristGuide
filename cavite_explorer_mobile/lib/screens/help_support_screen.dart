import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  Future<void> _emailSupport(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'explorecavite26@gmail.com',
      queryParameters: {'subject': 'Cavite Explorer support request'},
    );
    if (!await launchUrl(uri)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Email us at explorecavite26@gmail.com')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const questions = <({String title, String answer})>[
      (
        title: 'How do landmark badges work?',
        answer:
            'Enter the landmark verification area and remain there for the required visit time. Keep location enabled so the app can verify your visit and add the badge to your collection.'
      ),
      (
        title: 'Why did my badge timer pause?',
        answer:
            'The timer pauses when the app detects that you left the verification area. Return within the displayed grace period to continue without losing your progress.'
      ),
      (
        title: 'How are commute routes created?',
        answer:
            'Commute suggestions use routes and terminals verified by Cavite Explorer administrators and editors. Actual fares, availability, and road conditions may still change.'
      ),
      (
        title: 'How can I report incorrect information?',
        answer:
            'Email support with the landmark or route name, the incorrect detail, and any photo or local reference that can help us verify the correction.'
      ),
      (
        title: 'Why does the app need my location?',
        answer:
            'Location powers nearby landmark alerts, live commute guidance, and badge visit verification. You can review location permissions in Settings.'
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F7F4),
        surfaceTintColor: Colors.transparent,
        title: Text('Help & Support',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF123F33), Color(0xFF176A50)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.support_agent_rounded,
                  color: Color(0xFFD8F270), size: 38),
              const SizedBox(height: 13),
              Text('How can we help?',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 5),
              Text(
                'Find quick answers or contact the Cavite Explorer team.',
                style: GoogleFonts.poppins(
                    color: Colors.white70, fontSize: 11.5, height: 1.5),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _emailSupport(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD8F270),
                    foregroundColor: const Color(0xFF123F33),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.email_outlined),
                  label: Text('Email support',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          Text('Frequently asked questions',
              style: GoogleFonts.poppins(
                  fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ...questions.map(
            (question) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: const Color(0xFFDDE5E0)),
              ),
              child: ExpansionTile(
                shape: const Border(),
                collapsedShape: const Border(),
                iconColor: const Color(0xFF176A50),
                title: Text(question.title,
                    style: GoogleFonts.poppins(
                        fontSize: 12.5, fontWeight: FontWeight.w600)),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Text(question.answer,
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          height: 1.55,
                          color: Colors.grey.shade700)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text('Support email',
              style: GoogleFonts.poppins(
                  color: Colors.grey.shade500, fontSize: 10)),
          const SizedBox(height: 3),
          SelectableText('explorecavite26@gmail.com',
              style: GoogleFonts.poppins(
                  color: const Color(0xFF176A50),
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
