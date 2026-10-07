import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

const String _versionUrl =
    'https://444music-distribution.vercel.app/app-version.json';

// Set per store at build time with --dart-define=STORE_URL=...
// Falls back to your website until you have store links.
const String _storeUrl = String.fromEnvironment(
  'STORE_URL',
  defaultValue: 'https://www.444musicdistro.com',
);

/// Returns true only when the online minVersion is higher than this
/// build. Any problem (offline, bad file, timeout) returns false,
/// so users are never locked out by a failed check.
Future<bool> isUpdateRequired() async {
  if (kIsWeb) return false;
  try {
    final info = await PackageInfo.fromPlatform();
    final current = int.tryParse(info.buildNumber);
    if (current == null) return false;

    final res = await http
        .get(Uri.parse(
            '$_versionUrl?t=${DateTime.now().millisecondsSinceEpoch}'))
        .timeout(const Duration(seconds: 4));
    if (res.statusCode != 200) return false;

    final min = (jsonDecode(res.body)['minVersion'] as num?)?.toInt();
    if (min == null) return false;
    return current < min;
  } catch (_) {
    return false;
  }
}

class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key});

  Future<void> _openStore() async {
    try {
      await launchUrl(Uri.parse(_storeUrl),
          mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const Spacer(),
                const Text(
                  'Update required',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Please update 444Music to continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _openStore,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(
                      'Update',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
