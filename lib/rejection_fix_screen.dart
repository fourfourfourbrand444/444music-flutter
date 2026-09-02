// ═══════════════════════════════════════════════════════════════════
//  444MUSIC — Rejection Fix & Resubmit Screen
//  Reached from: ReleasesScreen → "Check Reasons & Fix" (on a rejected card)
//  Route: '/rejection', arguments: the full submission map (with '_id')
//
//  v2 — brought to exact parity with web's rejection-fix page:
//   • "Other" (non-copyright) mode now shows the same editable fields
//     web has — Artist Name, Release Title, Copyright Holder, Composer
//     — pre-filled from the original submission, correctable before
//     resubmit. These previously didn't exist here at all; only the
//     file re-uploads did.
//   • Added the "CURRENTLY ON FILE — WHAT WE RECEIVED" reference card
//     (original cover + a way to hear the original audio) that web
//     shows above the editable fields in Other mode.
//   • Firestore update on submit now also writes artistName,
//     releaseTitle, copyright, credits (updated composer), coverURL,
//     and officialCoverURL — matching web's updateDoc call exactly.
//     Previously only the file URLs were written; the corrected
//     metadata was silently dropped.
//   • notifyAdmin's cover URL now falls back the same way web's does:
//     freshly-fixed cover → officialCoverURL → coverURL. Previously
//     officialCoverURL was skipped entirely.
//   • Added the same success-screen fallback web has: if the admin
//     notify call fails, the fix is still saved but the success
//     message says so, and the screen stays up longer (3.2s vs 1.4s)
//     so the artist actually reads it.
//
//  Two modes, driven by rejectionCategory on the submission doc:
//   • Copyright / License Issue → ONLY a license/proof upload field.
//     Leaving it blank and going back is fine — release just stays
//     'Rejected' until they come back with proof.
//   • Other → shows what's currently on file, lets the artist correct
//     Artist Name / Release Title / Copyright / Composer, and
//     re-upload BOTH the audio file (MP3) AND cover art (JPG/PNG).
//
//  On submit: uploads to Cloudinary (same unsigned preset as UploadScreen),
//  updates the SAME submissions/{id} doc back to status: 'Review', clears
//  rejectionReason/rejectionCategory, writes the new file URL(s) + any
//  corrected metadata, and pings the admin backend so the fixed version
//  is picked up — same notify pipeline used for new submissions, which
//  already emails 444musicdistro@gmail.com. paid / paymentVerified are
//  never touched — no second payment is ever triggered.
//
//  NOTE — file_picker was replaced with file_selector for BOTH the PDF
//  license/proof upload AND the audio re-upload. The audio picker used
//  to call ImagePicker().pickMedia(), which only supports images/video
//  and could never actually select an MP3 — that was why "Resubmit"
//  looked stuck: the file was silently never picked, so submit always
//  failed its "file required" check.
// ═══════════════════════════════════════════════════════════════════
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_selector/file_selector.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

// ─── PALETTE (matches releases_screen.dart) ──────────────────────────
const _black    = Color(0xFF000000);
const _black2   = Color(0xFF0D0D0D);
const _black3   = Color(0xFF111111);
const _black4   = Color(0xFF161616);
const _white    = Color(0xFFFFFFFF);
const _white70  = Color(0xB3FFFFFF);
const _white40  = Color(0x66FFFFFF);
const _white10  = Color(0x1AFFFFFF);
const _white06  = Color(0x0FFFFFFF);
const _grey     = Color(0xFF888888);
const _greyDark = Color(0xFF444444);
const _green    = Color(0xFF22C55E);
const _greenDim = Color(0x1F22C55E);
const _greenBrd = Color(0x3322C55E);
const _rose     = Color(0xFFEF4444);
const _roseDim  = Color(0x18EF4444);
const _roseBrd  = Color(0x33EF4444);

// ─── CLOUDINARY — same unsigned preset used everywhere else ──────────
const _cloudinaryUrl    = 'https://api.cloudinary.com/v1_1/dlbgqtvqg/auto/upload';
const _cloudinaryPreset = 'glmamp2y';

// ─── ADMIN NOTIFY BACKEND — same one release_info_screen.dart uses ──
const _notifyUrl = 'https://four44music-broadcast-backend.onrender.com/api/submissions/notify';
const _appSecret = 'e993b17f0762667e27d5298839dacff4a7409bb74e11e9ecaf0bb2bb647120a8';

class RejectionFixScreen extends StatefulWidget {
  const RejectionFixScreen({super.key});
  @override
  State<RejectionFixScreen> createState() => _RejectionFixScreenState();
}

class _RejectionFixScreenState extends State<RejectionFixScreen> {
  Map<String, dynamic> _data = {};
  bool _dataLoaded = false;

  // ── License / proof (Copyright category) ──
  File?   _pickedLicenseFile;
  String? _pickedLicenseFileName;
  int?    _pickedLicenseFileSize;

  // ── Audio re-upload (Other category) ──
  File?   _pickedAudioFile;
  String? _pickedAudioFileName;
  int?    _pickedAudioFileSize;

  // ── Cover art re-upload (Other category) ──
  File?   _pickedCoverFile;
  String? _pickedCoverFileName;
  int?    _pickedCoverFileSize;

  // ── Editable metadata (Other category) — mirrors web's
  // "Update Release Details" fields exactly.
  final _artistNameCtrl   = TextEditingController();
  final _releaseTitleCtrl = TextEditingController();
  final _copyrightCtrl    = TextEditingController();
  final _composerCtrl     = TextEditingController();

  bool   _submitting = false;
  bool   _done       = false;
  bool   _notifyOk   = true;
  int    _notifyStatus = 0;
  String _error      = '';

  String get _category =>
      (_data['rejectionCategory'] ?? 'Other').toString().trim();
  bool get _isCopyright =>
      _category.toLowerCase().contains('copyright') ||
      _category.toLowerCase().contains('license');
  String get _reason => (_data['rejectionReason'] ?? '').toString().trim();
  String get _id      => (_data['_id'] ?? '').toString();
  String get _artistName   => (_data['artistName'] ?? '—').toString();
  String get _releaseTitle => (_data['releaseTitle'] ?? '—').toString();

  // ── Original media on file — mirrors web's hasOriginalMedia /
  // originalAudioUrl / originalCoverUrl exactly. Only relevant in
  // Other mode; copyright mode never shows this.
  String get _originalAudioUrl {
    final files = _data['audioFiles'];
    if (files is List && files.isNotEmpty && files.first is Map) {
      return ((files.first as Map)['url'] ?? '').toString();
    }
    return '';
  }

  String get _originalCoverUrl =>
      (_data['officialCoverURL'] ?? _data['coverURL'] ?? '').toString();

  bool get _hasOriginalMedia =>
      !_isCopyright && (_originalAudioUrl.isNotEmpty || _originalCoverUrl.isNotEmpty);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dataLoaded) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) _data = args;
      _dataLoaded = true;
      _artistNameCtrl.text   = (_data['artistName'] ?? '').toString();
      _releaseTitleCtrl.text = (_data['releaseTitle'] ?? '').toString();
      _copyrightCtrl.text    = (_data['copyright'] ?? '').toString();
      _composerCtrl.text     = _composerNameFromData();
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: _black,
    ));
  }

  @override
  void dispose() {
    _artistNameCtrl.dispose();
    _releaseTitleCtrl.dispose();
    _copyrightCtrl.dispose();
    _composerCtrl.dispose();
    super.dispose();
  }

  // ── COMPOSER CREDIT HELPERS — mirror web's getComposerName() /
  // buildUpdatedWriterCredits() exactly: only touch writer[0]'s name,
  // never wipe an existing role/IPI, and leave everything alone if
  // the field is left blank.
  String _composerNameFromData() {
    final credits = _data['credits'];
    final writers = (credits is Map && credits['writer'] is List) ? credits['writer'] as List : const [];
    if (writers.isNotEmpty && writers.first is Map) {
      return ((writers.first as Map)['name'] ?? '').toString();
    }
    return '';
  }

  List<Map<String, dynamic>> _buildUpdatedWriterCredits(String composerName) {
    final credits = _data['credits'];
    final writers = (credits is Map && credits['writer'] is List)
        ? List<dynamic>.from(credits['writer'])
        : <dynamic>[];
    final trimmed = composerName.trim();

    List<Map<String, dynamic>> asMaps() =>
        writers.map((w) => Map<String, dynamic>.from(w as Map)).toList();

    if (trimmed.isEmpty) return asMaps(); // left blank on purpose — don't wipe existing credits

    if (writers.isNotEmpty && writers.first is Map &&
        ((writers.first as Map)['name'] ?? '').toString().trim().toLowerCase() == trimmed.toLowerCase()) {
      return asMaps(); // unchanged
    }

    if (writers.isNotEmpty) {
      final first = Map<String, dynamic>.from(writers.first as Map);
      writers[0] = {
        'name': trimmed,
        'role': first['role'] ?? 'Composer',
        'ipi': first['ipi'] ?? '',
      };
    } else {
      writers.add({'name': trimmed, 'role': 'Composer', 'ipi': ''});
    }
    return asMaps();
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // ── PICKERS ─────────────────────────────────────────────────────────
  // NOTE — mimeTypes is required alongside extensions for file_selector
  // to work reliably on Android. extensions-only can silently fail to
  // launch or show nothing selectable on some Android versions.
  Future<void> _pickLicenseFile() async {
    const typeGroup = XTypeGroup(
      label: 'PDF',
      extensions: ['pdf'],
      mimeTypes: ['application/pdf'],
    );
    final XFile? result = await openFile(acceptedTypeGroups: [typeGroup]);
    if (result == null) return;

    final ext = result.name.split('.').last.toLowerCase();
    if (ext != 'pdf') {
      setState(() => _error = 'Only PDF files are accepted.');
      return;
    }

    final file = File(result.path);
    final size = await file.length();

    setState(() {
      _pickedLicenseFile     = file;
      _pickedLicenseFileName = result.name;
      _pickedLicenseFileSize = size;
      _error = '';
    });
  }

  // ── AUDIO PICKER — mirrors upload_screen.dart's _pickMp3() exactly,
  // since that flow is proven working in production. Uses ImagePicker's
  // pickMedia(), which on this project's target Android versions opens
  // a picker that also surfaces non-media files (unlike a strict
  // media-only picker on some other configurations).
  Future<void> _pickAudioFile() async {
    try {
      final result = await ImagePicker().pickMedia();
      if (result == null) return;

      final ext = result.path.split('.').last.toLowerCase();
      if (ext != 'mp3') {
        setState(() => _error = '.$ext is not accepted — MP3 only.');
        return;
      }

      final file = File(result.path);
      final size = await file.length();
      if (size > 50 * 1024 * 1024) {
        setState(() => _error = 'Audio file exceeds 50 MB limit.');
        return;
      }

      setState(() {
        _pickedAudioFile     = file;
        _pickedAudioFileName = result.name;
        _pickedAudioFileSize = size;
        _error = '';
      });
    } catch (e) {
      setState(() => _error = 'Could not pick file. Try again.');
    }
  }

  // ── COVER PICKER — mirrors upload_screen.dart's _pickCover() exactly.
  Future<void> _pickCoverFile() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
          source: ImageSource.gallery, imageQuality: 95);
      if (picked == null) return;

      final file = File(picked.path);
      final size = await file.length();
      if (size > 15 * 1024 * 1024) {
        setState(() => _error = 'Cover art exceeds 15 MB limit.');
        return;
      }

      setState(() {
        _pickedCoverFile     = file;
        _pickedCoverFileName = picked.name;
        _pickedCoverFileSize = size;
        _error = '';
      });
    } catch (e) {
      setState(() => _error = 'Could not pick file. Try again.');
    }
  }

  // ── CLOUDINARY UPLOAD ───────────────────────────────────────────────
  Future<String?> _uploadToCloudinary(File file, String folder) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(_cloudinaryUrl));
      request.fields['upload_preset'] = _cloudinaryPreset;
      request.fields['folder']        = folder;
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      final streamed = await request.send();
      final body      = await streamed.stream.bytesToString();
      final json      = jsonDecode(body) as Map<String, dynamic>;
      if (json.containsKey('secure_url')) return json['secure_url'] as String;
      debugPrint('Cloudinary error: $body');
      return null;
    } catch (e) {
      debugPrint('Cloudinary upload exception: $e');
      return null;
    }
  }

  // ── FORMAT HELPERS — mirror submissionController.js's mapSubmissionForEmail
  // so the resubmission email renders identically to the original one. ──
  String _fmtCreditList(dynamic list) {
    if (list is! List) return 'None';
    final filtered = list
        .where((c) => c is Map && (c['name'] ?? '').toString().trim().isNotEmpty)
        .toList();
    if (filtered.isEmpty) return 'None';
    return filtered.map((c) {
      var line = '• ${c['name']}';
      if ((c['role'] ?? '').toString().isNotEmpty) line += ' — ${c['role']}';
      if ((c['ipi'] ?? '').toString().isNotEmpty)  line += ' (IPI: ${c['ipi']})';
      return line;
    }).join('\n');
  }

  String _fmtFeaturing() {
    final list = _data['featuredArtists'];
    if (list is! List || list.isEmpty) return 'None';
    return list
        .whereType<Map>()
        .map((f) {
          var line = '${f['name']} (${f['role']})';
          if ((f['url'] ?? '').toString().trim().isNotEmpty) line += ' — ${f['url']}';
          return line;
        })
        .join('\n');
  }

  // ── NOTIFY ADMIN OF THE FIX ─────────────────────────────────────────
  // Builds the SAME shape of payload the backend's notifySubmission()
  // expects for a normal submission (email + snake_case metadata fields),
  // pulling everything except the fixed file(s) from _data — which, by
  // the time this runs, may already carry the artist's corrected
  // artist_name / release_title / copyright / songwriters, so the email
  // just reflects the fix. Returns ok/status so the caller can tell the
  // artist if the admin side didn't get it, same as web does.
  Future<Map<String, dynamic>> _notifyAdmin({
    required String kind, // 'license' or 'audio_and_cover'
    String? licenseUrl,
    String? audioUrl,
    String? coverUrl,
  }) async {
    final credits = _data['credits'];
    final producerList = credits is Map ? credits['producer'] : null;
    final musicianList = credits is Map ? credits['musician'] : null;
    final writerList   = credits is Map ? credits['writer']   : null;

    // Prefer the freshly-fixed cover from THIS resubmit; fall back to the
    // official cover (original upload) before the possibly-stale
    // dashboard-edited coverURL — matches web's
    // `coverUrl || data.officialCoverURL || data.coverURL || ""` exactly.
    final resolvedCoverUrl = coverUrl ??
        ((_data['officialCoverURL'] ?? _data['coverURL'] ?? '').toString());

    List<Map<String, String>> resolvedAudioFiles;
    if (audioUrl != null) {
      resolvedAudioFiles = [
        {'title': _releaseTitle, 'url': audioUrl},
      ];
    } else {
      final existing = _data['audioFiles'];
      resolvedAudioFiles = existing is List
          ? existing
              .whereType<Map>()
              .map((m) => {
                    'title': (m['title'] ?? _releaseTitle).toString(),
                    'url':   (m['url'] ?? '').toString(),
                  })
              .where((m) => (m['url'] ?? '').isNotEmpty)
              .toList()
          : <Map<String, String>>[];
    }

    final body = {
      'type':           'resubmission',
      'submissionId':   _id,
      'is_resend':      true,
      'email':          (_data['email'] ?? '').toString(),
      'artist_name':    _artistName,
      'release_title':  _releaseTitle,
      'featuring':      _fmtFeaturing(),
      'release_type':   (_data['releaseType'] ?? '').toString(),
      'genre':          (_data['genre'] ?? '').toString(),
      'language':       (_data['language'] ?? 'Not specified').toString(),
      'release_date':   (_data['releaseDate'] ?? 'Not set').toString(),
      'explicit':       (_data['explicit'] ?? '').toString(),
      'country':        (_data['country'] ?? '').toString(),
      'phone':          (_data['phone'] ?? 'Not provided').toString(),
      'label':          (_data['label'] ?? 'Independent').toString(),
      'copyright':      (_data['copyright'] ?? 'Not provided').toString(),
      'isrc':           (_data['isrc'] ?? 'Not provided').toString(),
      'upc':            (_data['upc'] ?? 'Auto-assign').toString(),
      'catalog_number': (_data['catalogNumber'] ?? 'Not provided').toString(),
      'version':               (_data['version'] ?? '').toString(),
      'previously_released':   (_data['previouslyReleased'] ?? '').toString(),
      'previous_release_date': (_data['previousReleaseDate'] ?? 'N/A').toString(),
      'vocal_type':            (_data['vocalType'] ?? '').toString(),
      'ownership_confirmed':   (_data['ownershipConfirmed'] == true)
          ? 'Yes — confirmed original work'
          : 'Not confirmed',
      'producers':      _fmtCreditList(producerList),
      'musicians':      _fmtCreditList(musicianList),
      'songwriters':    _fmtCreditList(writerList),
      'lyrics':         (_data['lyrics'] ?? 'Not provided').toString(),
      'payment_status': (_data['paid'] ?? 'Not confirmed').toString(),
      'category':        _category,
      'previous_reason': _reason,
      'fix_kind':        kind,
      if (licenseUrl != null) 'fix_license_url': licenseUrl,
      'cover_url':   resolvedCoverUrl,
      'audio_files': resolvedAudioFiles,
      'status':        'Review',
      'submitted_at':  DateTime.now().toLocal().toString(),
    };

    try {
      final res = await http.post(
        Uri.parse(_notifyUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-app-secret': _appSecret,
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));
      debugPrint('[Notify resubmit] status=${res.statusCode} body=${res.body}');
      return {'ok': res.statusCode >= 200 && res.statusCode < 300, 'status': res.statusCode};
    } catch (e) {
      debugPrint('[Notify resubmit] ERROR: $e');
      return {'ok': false, 'status': 0};
    }
  }

  // ── SUBMIT ───────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (_id.isEmpty) {
      setState(() => _error = 'Missing submission reference. Please go back and try again.');
      return;
    }

    if (_isCopyright) {
      if (_pickedLicenseFile == null) {
        setState(() => _error = 'Please upload your license / proof document.');
        return;
      }
    } else {
      if (_pickedAudioFile == null || _pickedCoverFile == null) {
        setState(() => _error = 'Please upload both the fixed MP3 and cover art.');
        return;
      }
    }

    String newArtistName   = _data['artistName'] ?? '';
    String newReleaseTitle = _data['releaseTitle'] ?? '';
    String newCopyright    = (_data['copyright'] ?? '').toString();
    String newComposer     = _composerNameFromData();

    if (!_isCopyright) {
      newArtistName   = _artistNameCtrl.text.trim();
      newReleaseTitle = _releaseTitleCtrl.text.trim();
      newCopyright    = _copyrightCtrl.text.trim();
      newComposer     = _composerCtrl.text;
      if (newArtistName.isEmpty)   { setState(() => _error = 'Artist name is required.'); return; }
      if (newReleaseTitle.isEmpty) { setState(() => _error = 'Release title is required.'); return; }
    }

    setState(() { _submitting = true; _error = ''; });

    try {
      Map<String, dynamic> notifyResult = {'ok': true, 'status': 200};

      if (_isCopyright) {
        final url = await _uploadToCloudinary(_pickedLicenseFile!, 'license-proofs');
        if (url == null) {
          setState(() {
            _submitting = false;
            _error = 'Upload failed. Check your connection and try again.';
          });
          return;
        }

        await FirebaseFirestore.instance.collection('submissions').doc(_id).update({
          'status':            'Review',
          'rejectionReason':   FieldValue.delete(),
          'rejectionCategory': FieldValue.delete(),
          'resubmittedAt':     FieldValue.serverTimestamp(),
          'licenseURL':        url,
        });

        notifyResult = await _notifyAdmin(kind: 'license', licenseUrl: url);
      } else {
        final audioUrl = await _uploadToCloudinary(_pickedAudioFile!, 'tracks');
        if (audioUrl == null) {
          setState(() {
            _submitting = false;
            _error = 'Audio upload failed. Check your connection and try again.';
          });
          return;
        }

        final coverUrl = await _uploadToCloudinary(_pickedCoverFile!, 'covers');
        if (coverUrl == null) {
          setState(() {
            _submitting = false;
            _error = 'Cover art upload failed. Check your connection and try again.';
          });
          return;
        }

        final updatedWriters = _buildUpdatedWriterCredits(newComposer);
        final updatedCredits = {
          'producer': (_data['credits'] is Map ? _data['credits']['producer'] : null) ?? [],
          'musician': (_data['credits'] is Map ? _data['credits']['musician'] : null) ?? [],
          'writer':   updatedWriters,
        };

        await FirebaseFirestore.instance.collection('submissions').doc(_id).update({
          'status':                 'Review',
          'rejectionReason':        FieldValue.delete(),
          'rejectionCategory':      FieldValue.delete(),
          'resubmittedAt':          FieldValue.serverTimestamp(),
          'resubmittedAudioURL':    audioUrl,
          'resubmittedCoverURL':    coverUrl,
          // Also sync the two fields any future email (e.g. a later Pay
          // Now resend) actually reads from. Without this, coverURL and
          // officialCoverURL would stay frozen on the original — pre-fix
          // — cover art forever, and only THIS immediate notify call
          // would ever show the corrected artwork.
          'coverURL':         coverUrl,
          'officialCoverURL': coverUrl,
          'artistName':   newArtistName,
          'releaseTitle': newReleaseTitle,
          'copyright':    newCopyright,
          'credits':      updatedCredits,
        });

        // Reflect the edits on the in-memory map too, so _notifyAdmin()
        // — which reads straight off `_data` — sends the corrected
        // metadata in the same admin email it always sends.
        _data['artistName']   = newArtistName;
        _data['releaseTitle'] = newReleaseTitle;
        _data['copyright']    = newCopyright;
        _data['credits']      = updatedCredits;

        notifyResult = await _notifyAdmin(kind: 'audio_and_cover', audioUrl: audioUrl, coverUrl: coverUrl);
      }

      final ok = notifyResult['ok'] == true;
      setState(() {
        _submitting  = false;
        _done        = true;
        _notifyOk    = ok;
        _notifyStatus = (notifyResult['status'] as int?) ?? 0;
      });
      await Future.delayed(Duration(milliseconds: ok ? 1400 : 3200));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('[Resubmit] ERROR: $e');
      setState(() {
        _submitting = false;
        _error = 'Something went wrong saving your fix. Please try again.';
      });
    }
  }

  String _fmtBytes(int b) => b < 1024 * 1024
      ? '${(b / 1024).toStringAsFixed(1)} KB'
      : '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';

  // ════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (!_dataLoaded) {
      return const Scaffold(backgroundColor: _black, body: SizedBox());
    }
    final top    = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: _black,
      body: Column(
        children: [
          _buildTopBar(top),
          Expanded(
            child: _done
                ? _buildSuccess()
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(20, 20, 20, bottom + 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildReasonCard(),
                        const SizedBox(height: 20),
                        _buildTrackDetailsCard(),
                        const SizedBox(height: 24),
                        if (_isCopyright)
                          _buildLicenseSection()
                        else
                          _buildOtherSection(),
                        if (_error.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildErrorBanner(_error),
                        ],
                        const SizedBox(height: 28),
                        _buildSubmitButton(),
                        if (_isCopyright) ...[
                          const SizedBox(height: 14),
                          Center(
                            child: Text(
                              "No proof yet? You can leave this and come back —\nyour release stays Rejected until you upload it.",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.nunito(
                                  color: _greyDark, fontSize: 11, height: 1.5),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(double top) {
    return Container(
      padding: EdgeInsets.only(top: top),
      color: _black,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _white10)),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _white06,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _white10),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: _white, size: 15),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Fix & Resubmit',
                  style: GoogleFonts.outfit(
                      color: _white, fontSize: 17, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReasonCard() {
    final title = (_data['releaseTitle'] ?? 'Your release').toString();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _roseDim,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _roseBrd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.info_rounded, color: _rose, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title,
                  style: GoogleFonts.nunito(
                      color: _white, fontSize: 14, fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
          if (_reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_reason,
                style: GoogleFonts.nunito(
                    color: _white70, fontSize: 12.5, height: 1.5)),
          ],
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: _black3,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: _white10),
            ),
            child: Text(
              _isCopyright ? 'Copyright / License Issue' : 'Other Issue',
              style: GoogleFonts.nunito(
                  color: _white70, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ── READ-ONLY TRACK DETAILS — always shown, matches web's top
  // "SUBMISSION DETAILS" card exactly (unedited original values).
  Widget _buildTrackDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _black3,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SUBMISSION DETAILS',
              style: GoogleFonts.outfit(
                  color: _greyDark, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          _detailRow('Artist Name', _artistName),
          const SizedBox(height: 10),
          _detailRow('Release Title', _releaseTitle),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label,
              style: GoogleFonts.nunito(color: _grey, fontSize: 12.5, fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Text(value,
              style: GoogleFonts.nunito(color: _white, fontSize: 13, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  // ── COPYRIGHT/LICENSE MODE — one field only ──────────────────────
  Widget _buildLicenseSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Upload License / Proof',
            style: GoogleFonts.nunito(
                color: _white, fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('A license, purchase receipt, or written permission for the beat — PDF only.',
            style: GoogleFonts.nunito(color: _grey, fontSize: 12, height: 1.5)),
        const SizedBox(height: 12),
        _buildFileZone(
          onTap: _pickLicenseFile,
          icon: Icons.picture_as_pdf_outlined,
          hint: 'Tap to select a PDF',
          sub: 'PDF only',
          fileName: _pickedLicenseFileName,
          fileSize: _pickedLicenseFileSize,
        ),
      ],
    );
  }

  // ── OTHER MODE — currently-on-file reference, editable metadata,
  // audio re-upload, cover re-upload. Order matches web exactly.
  Widget _buildOtherSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_hasOriginalMedia) ...[
          _buildOriginalMediaCard(),
          const SizedBox(height: 20),
        ],

        Text('Update Release Details',
            style: GoogleFonts.nunito(
                color: _white, fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Fix anything that was wrong — this goes out with your resubmission.',
            style: GoogleFonts.nunito(color: _grey, fontSize: 12, height: 1.5)),
        const SizedBox(height: 12),
        _buildEditableFieldsCard(),
        const SizedBox(height: 20),

        Text('Re-upload Audio File',
            style: GoogleFonts.nunito(
                color: _white, fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Fixed version of the track — MP3 only, max 50 MB.',
            style: GoogleFonts.nunito(color: _grey, fontSize: 12, height: 1.5)),
        const SizedBox(height: 12),
        _buildFileZone(
          onTap: _pickAudioFile,
          icon: Icons.audio_file_rounded,
          hint: 'Tap to select MP3',
          sub: 'MP3 only',
          fileName: _pickedAudioFileName,
          fileSize: _pickedAudioFileSize,
        ),
        const SizedBox(height: 20),

        Text('Re-upload Cover Art',
            style: GoogleFonts.nunito(
                color: _white, fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Fixed cover artwork — JPG or PNG, square, max 15 MB.',
            style: GoogleFonts.nunito(color: _grey, fontSize: 12, height: 1.5)),
        const SizedBox(height: 12),
        _buildFileZone(
          onTap: _pickCoverFile,
          icon: Icons.image_rounded,
          hint: 'Tap to select JPG or PNG',
          sub: 'JPG / PNG only',
          fileName: _pickedCoverFileName,
          fileSize: _pickedCoverFileSize,
        ),
      ],
    );
  }

  // ── CURRENTLY ON FILE — mirrors web's original-media-row exactly:
  // a small cover thumbnail plus a way to hear the original audio.
  Widget _buildOriginalMediaCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _black3,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CURRENTLY ON FILE — WHAT WE RECEIVED',
              style: GoogleFonts.outfit(
                  color: _greyDark, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (_originalCoverUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    _originalCoverUrl,
                    width: 56, height: 56, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(color: _black4, borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                )
              else
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                      color: _black4, borderRadius: BorderRadius.circular(10), border: Border.all(color: _white10)),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: _originalAudioUrl.isNotEmpty
                    ? GestureDetector(
                        onTap: () => _launchUrl(_originalAudioUrl),
                        child: Row(children: [
                          const Icon(Icons.play_circle_fill_rounded, color: _white70, size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('Play original audio on file',
                                style: GoogleFonts.nunito(color: _white70, fontSize: 12.5, fontWeight: FontWeight.w700)),
                          ),
                        ]),
                      )
                    : Text('No audio on file yet.',
                        style: GoogleFonts.nunito(color: _grey, fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── EDITABLE METADATA FIELDS — Artist Name, Release Title,
  // Copyright Holder, Composer. Matches web's four .field-row inputs.
  Widget _buildEditableFieldsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _black3,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _white10),
      ),
      child: Column(
        children: [
          _fieldRow('Artist Name', _artistNameCtrl, 'Artist name'),
          const SizedBox(height: 12),
          _fieldRow('Release Title', _releaseTitleCtrl, 'Release title'),
          const SizedBox(height: 12),
          _fieldRow('Copyright Holder', _copyrightCtrl, 'e.g. © 2026 Your Name'),
          const SizedBox(height: 12),
          _fieldRow('Composer', _composerCtrl, 'Composer / songwriter name'),
        ],
      ),
    );
  }

  Widget _fieldRow(String label, TextEditingController ctrl, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: GoogleFonts.nunito(color: _grey, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          style: GoogleFonts.nunito(color: _white, fontSize: 13.5),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: _black4,
            contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            hintText: hint,
            hintStyle: GoogleFonts.nunito(color: _greyDark),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _white10)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _white10)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _white40)),
          ),
        ),
      ],
    );
  }

  Widget _buildFileZone({
    required VoidCallback onTap,
    required IconData icon,
    required String hint,
    required String sub,
    required String? fileName,
    required int? fileSize,
  }) {
    final hasFile = fileName != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _black3,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: hasFile ? _greenBrd : _white10),
        ),
        child: hasFile
            ? Row(children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: _greenDim,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _greenBrd),
                  ),
                  child: const Icon(Icons.check_rounded, color: _green, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fileName,
                          style: GoogleFonts.nunito(
                              color: _white, fontSize: 13, fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis),
                      if (fileSize != null)
                        Text(_fmtBytes(fileSize),
                            style: GoogleFonts.nunito(color: _grey, fontSize: 11)),
                    ],
                  ),
                ),
                const Icon(Icons.swap_horiz_rounded, color: _greyDark, size: 18),
              ])
            : Column(children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: _black4,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _white10),
                  ),
                  child: Icon(icon, color: _greyDark, size: 24),
                ),
                const SizedBox(height: 12),
                Text(hint,
                    style: GoogleFonts.nunito(
                        color: _white70, fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(sub, style: GoogleFonts.nunito(color: _greyDark, fontSize: 11)),
              ]),
      ),
    );
  }

  Widget _buildErrorBanner(String msg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _roseDim,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _roseBrd),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.warning_amber_rounded, color: _rose, size: 16),
        const SizedBox(width: 8),
        Expanded(
            child: Text(msg,
                style: GoogleFonts.nunito(color: _rose, fontSize: 12.5, height: 1.5))),
      ]),
    );
  }

  Widget _buildSubmitButton() {
    return GestureDetector(
      onTap: _submitting ? null : _submit,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _submitting ? _black3 : _white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _submitting ? _white10 : _white),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _submitting
              ? [
                  const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, valueColor: AlwaysStoppedAnimation(_grey)),
                  ),
                  const SizedBox(width: 10),
                  Text('Submitting…',
                      style: GoogleFonts.nunito(
                          color: _grey, fontSize: 13, fontWeight: FontWeight.w700)),
                ]
              : [
                  const Icon(Icons.check_rounded, color: _black, size: 18),
                  const SizedBox(width: 8),
                  Text('Resubmit for Review',
                      style: GoogleFonts.nunito(
                          color: _black, fontSize: 13, fontWeight: FontWeight.w800)),
                ],
        ),
      ),
    );
  }

  // ── SUCCESS — mirrors web's success-wrap, including the fallback
  // copy when the admin notify call itself failed but the fix was
  // still saved to Firestore.
  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: _greenDim,
                shape: BoxShape.circle,
                border: Border.all(color: _greenBrd),
              ),
              child: const Icon(Icons.check_rounded, color: _green, size: 32),
            ),
            const SizedBox(height: 18),
            Text('Sent for Review',
                style: GoogleFonts.outfit(
                    color: _white, fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              _notifyOk
                  ? "We'll take another look — no payment needed."
                  : "Your fix was saved, but we couldn't reach the admin notification service (status $_notifyStatus). The team may not see this until that's checked.",
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(color: _grey, fontSize: 12.5, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}