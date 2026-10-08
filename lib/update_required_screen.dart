import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

const String _versionUrl =
    'https://444music-distribution.vercel.app/app-version.json';

// Where the Update button goes. Can be overridden per build with
// --dart-define=STORE_URL=...
const String _storeUrl = String.fromEnvironment(
  'STORE_URL',
  defaultValue: 'https://www.444musicdistro.com/download',
);

enum _VersionStatus { ok, updateRequired, offline }

Future<http.Response?> _fetchVersionFile() async {
  try {
    return await http
        .get(Uri.parse(
            '$_versionUrl?t=${DateTime.now().millisecondsSinceEpoch}'))
        .timeout(const Duration(seconds: 10));
  } catch (_) {
    return null;
  }
}

/// ok              -> let the user in
/// updateRequired  -> this build is below minVersion
/// offline         -> the version file could not be reached at all
///
/// If the server answers but the file is missing or broken, the user is
/// let in, so a mistake on our side can never lock everyone out.
Future<_VersionStatus> _checkVersion() async {
  if (kIsWeb) return _VersionStatus.ok;

  int? current;
  try {
    final info = await PackageInfo.fromPlatform();
    current = int.tryParse(info.buildNumber);
  } catch (_) {}
  if (current == null) return _VersionStatus.ok;

  final res = await _fetchVersionFile();
  if (res == null) return _VersionStatus.offline;
  if (res.statusCode != 200) return _VersionStatus.ok;

  try {
    final min = (jsonDecode(res.body)['minVersion'] as num?)?.toInt();
    if (min == null) return _VersionStatus.ok;
    return current < min
        ? _VersionStatus.updateRequired
        : _VersionStatus.ok;
  } catch (_) {
    return _VersionStatus.ok;
  }
}

/// Wrap the first real screen in this. It shows the child only after the
/// version check passes.
class VersionGate extends StatefulWidget {
  final Widget child;
  const VersionGate({super.key, required this.child});

  @override
  State<VersionGate> createState() => _VersionGateState();
}

class _VersionGateState extends State<VersionGate> {
  _VersionStatus? _status; // null while checking
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final s = await _checkVersion();
    if (!mounted) return;
    setState(() {
      _status = s;
      _retrying = false;
    });
  }

  Future<void> _retry() async {
    setState(() => _retrying = true);
    await _run();
  }

  @override
  Widget build(BuildContext context) {
    if (_status == null) return const _CheckingScreen();
    if (_status == _VersionStatus.updateRequired) {
      return const UpdateRequiredScreen();
    }
    if (_status == _VersionStatus.offline) {
      return _NoInternetScreen(loading: _retrying, onRetry: _retry);
    }
    return widget.child;
  }
}

// Same red as the splash screen so the hand-off looks seamless.
class _CheckingScreen extends StatelessWidget {
  const _CheckingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFD90429),
      body: SizedBox.expand(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Distribute. Earn. Grow.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.6,
                ),
              ),
              SizedBox(height: 56),
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageScreen extends StatelessWidget {
  final String title;
  final String body;
  final String buttonLabel;
  final bool loading;
  final VoidCallback onPressed;

  const _MessageScreen({
    required this.title,
    required this.body,
    required this.buttonLabel,
    required this.onPressed,
    this.loading = false,
  });

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
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
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
                    onPressed: loading ? null : onPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor:
                          Colors.white.withOpacity(0.15),
                      elevation: 0,
                      shape: const StadiumBorder(),
                    ),
                    child: loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF08080A),
                            ),
                          )
                        : Text(
                            buttonLabel,
                            style: const TextStyle(
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

class _NoInternetScreen extends StatelessWidget {
  final bool loading;
  final VoidCallback onRetry;
  const _NoInternetScreen({required this.loading, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return _MessageScreen(
      title: 'No connection',
      body: 'Turn on your data to continue.',
      buttonLabel: 'Try again',
      loading: loading,
      onPressed: onRetry,
    );
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
    return _MessageScreen(
      title: 'Update required',
      body: 'Please update 444Music to continue.',
      buttonLabel: 'Update',
      onPressed: _openStore,
    );
  }
}
