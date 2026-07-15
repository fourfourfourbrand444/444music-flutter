// ═══════════════════════════════════════════════════════════════════
//  444MUSIC — Rejection Fix & Resubmit Screen
//  Reached from: ReleasesScreen → "Check Reasons & Fix" (on a rejected card)
//  Route: '/rejection', arguments: the full submission map (with '_id')
//
//  Two modes, driven by rejectionCategory on the submission doc:
//   • Copyright / License Issue → ONLY a license/proof upload field.
//     Leaving it blank and going back is fine — release just stays
//     'Rejected' until they come back with proof.
//   • Other → re-upload audio file + artist name (prefilled). Nothing else.
//
//  On submit: uploads to Cloudinary (same unsigned preset as UploadScreen),
//  updates the SAME submissions/{id} doc back to status: 'Review', clears
//  rejectionReason/rejectionCategory, and pings the admin backend so you
//  know a fix came in. paid / paymentVerified are never touched — no
//  second payment is ever triggered.
// ═══════════════════════════════════════════════════════════════════
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

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
const _notifyUrl = 'https://444music-backend.bonto.run/api/submissions/notify';
const _appSecret = 'e993b17f0762667e27d5298839dacff4a7409bb74e11e9ecaf0bb2bb647120a8';

class RejectionFixScreen extends StatefulWidget {
  const RejectionFixScreen({super.key});
  @override
  State<RejectionFixScreen> createState() => _RejectionFixScreenState();
}

class _RejectionFixScreenState extends State<RejectionFixScreen> {
  Map<String, dynamic> _data = {};
  bool _dataLoaded = false;

  late TextEditingController _artistCtrl;

  File?   _pickedFile;
  String? _pickedFileName;
  int?    _pickedFileSize;

  bool   _submitting = false;
  bool   _done       = false;
  String _error      = '';

  String get _category =>
      (_data['rejectionCategory'] ?? 'Other').toString().trim();
  bool get _isCopyright =>
      _category.toLowerCase().contains('copyright') ||
      _category.toLowerCase().contains('license');
  String get _reason => (_data['rejectionReason'] ?? '').toString().trim();
  String get _id      => (_data['_id'] ?? '').toString();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dataLoaded) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) _data = args;
      _artistCtrl = TextEditingController(
          text: (_data['artistName'] ?? '').toString());
      _dataLoaded = true;
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
    _artistCtrl.dispose();
    super.dispose();
  }

  // ── PICKERS ─────────────────────────────────────────────────────────
  Future<void> _pickLicenseFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.single.path == null) return;
    final path = result.files.single.path!;
    final ext  = result.files.single.extension?.toLowerCase() ?? '';
    if (ext != 'pdf') {
      setState(() => _error = 'Only PDF files are accepted.');
      return;
    }
    setState(() {
      _pickedFile     = File(path);
      _pickedFileName = result.files.single.name;
      _pickedFileSize = result.files.single.size;
      _error = '';
    });
  }

  Future<void> _pickAudioFile() async {
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
      setState(() => _error = 'File exceeds 50 MB limit.');
      return;
    }
    setState(() {
      _pickedFile     = file;
      _pickedFileName = result.name;
      _pickedFileSize = size;
      _error = '';
    });
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

  // ── NOTIFY ADMIN OF THE FIX ─────────────────────────────────────────
  Future<void> _notifyAdmin({
    required String fileUrl,
    required String kind, // 'license' or 'audio'
  }) async {
    try {
      final res = await http.post(
        Uri.parse(_notifyUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-app-secret': _appSecret,
        },
        body: jsonEncode({
          'type':            'resubmission',
          'submissionId':    _id,
          'artist_name':     _artistCtrl.text.trim(),
          'release_title':   _data['releaseTitle'] ?? '',
          'category':        _category,
          'previous_reason': _reason,
          'fix_kind':        kind,
          'fix_file_url':    fileUrl,
          'status':          'Review',
          'submitted_at':    DateTime.now().toLocal().toString(),
        }),
      ).timeout(const Duration(seconds: 15));
      debugPrint('[Notify resubmit] status=${res.statusCode} body=${res.body}');
    } catch (e) {
      debugPrint('[Notify resubmit] ERROR: $e');
    }
  }

  // ── SUBMIT ───────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (_id.isEmpty) {
      setState(() => _error = 'Missing submission reference. Please go back and try again.');
      return;
    }
    if (_pickedFile == null) {
      setState(() => _error = _isCopyright
          ? 'Please upload your license / proof document.'
          : 'Please re-upload the audio file.');
      return;
    }
    if (!_isCopyright && _artistCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Artist name is required.');
      return;
    }

    setState(() { _submitting = true; _error = ''; });

    final folder = _isCopyright ? 'license-proofs' : 'tracks';
    final url    = await _uploadToCloudinary(_pickedFile!, folder);

    if (url == null) {
      setState(() {
        _submitting = false;
        _error = 'Upload failed. Check your connection and try again.';
      });
      return;
    }

    try {
      final update = <String, dynamic>{
        'status':            'Review',
        'rejectionReason':   FieldValue.delete(),
        'rejectionCategory': FieldValue.delete(),
        'resubmittedAt':     FieldValue.serverTimestamp(),
      };

      if (_isCopyright) {
        update['licenseURL'] = url;
      } else {
        update['artistName']       = _artistCtrl.text.trim();
        update['resubmittedAudioURL'] = url;
      }

      await FirebaseFirestore.instance
          .collection('submissions')
          .doc(_id)
          .update(update);

      await _notifyAdmin(fileUrl: url, kind: _isCopyright ? 'license' : 'audio');

      setState(() { _submitting = false; _done = true; });
      await Future.delayed(const Duration(milliseconds: 1400));
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
        ),
      ],
    );
  }

  // ── OTHER MODE — audio re-upload + artist name only ──────────────
  Widget _buildOtherSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Artist Name',
            style: GoogleFonts.nunito(
                color: _white, fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        TextField(
          controller: _artistCtrl,
          style: GoogleFonts.nunito(color: _white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'e.g. Burna Boy',
            hintStyle: GoogleFonts.nunito(color: _greyDark, fontSize: 13),
            filled: true,
            fillColor: _black3,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _white10)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _white10)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _white40)),
          ),
        ),
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
        ),
      ],
    );
  }

  Widget _buildFileZone({
    required VoidCallback onTap,
    required IconData icon,
    required String hint,
    required String sub,
  }) {
    final hasFile = _pickedFile != null;
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
                      Text(_pickedFileName ?? 'File selected',
                          style: GoogleFonts.nunito(
                              color: _white, fontSize: 13, fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis),
                      if (_pickedFileSize != null)
                        Text(_fmtBytes(_pickedFileSize!),
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

  Widget _buildSuccess() {
    return Center(
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
          Text('We\'ll take another look — no payment needed.',
              style: GoogleFonts.nunito(color: _grey, fontSize: 12.5)),
        ],
      ),
    );
  }
}