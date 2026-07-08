import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// ─── PALETTE ────────────────────────────────────────────────────────
const _black       = Color(0xFF000000);
const _black1      = Color(0xFF0A0A0A);
const _black2      = Color(0xFF111111);
const _black3      = Color(0xFF1A1A1A);
const _black4      = Color(0xFF222222);
const _white       = Color(0xFFFFFFFF);
const _white70     = Color(0xB3FFFFFF);
const _white40     = Color(0x66FFFFFF);
const _white20     = Color(0x33FFFFFF);
const _white10     = Color(0x1AFFFFFF);
const _white06     = Color(0x0FFFFFFF);
const _grey        = Color(0xFF888888);
const _greyDark    = Color(0xFF444444);
const _green       = Color(0xFF22C55E);
const _greenDim    = Color(0x1F22C55E);
const _greenBorder = Color(0x3322C55E);
const _red         = Color(0xFFEF4444);
const _redDim      = Color(0x18EF4444);
const _redBorder   = Color(0x33EF4444);
const _amber       = Color(0xFFF59E0B);
const _amberDim    = Color(0x18F59E0B);
const _amberBorder = Color(0x33F59E0B);

// ─── CLOUDINARY ──────────────────────────────────────────────────────
const _cloudinaryUrl    = 'https://api.cloudinary.com/v1_1/dlbgqtvqg/auto/upload';
const _cloudinaryPreset = 'glmamp2y';

// ─── EMAILJS ─────────────────────────────────────────────────────────
const _emailjsUrl        = 'https://api.emailjs.com/api/v1.0/email/send';
const _emailjsServiceId  = 'service_aykr0hz';
const _emailjsTemplateId = 'template_hrekcw6';
const _emailjsPublicKey  = 'JOJdEmnvcMiSbDeAz';

// ─── TRACK MODEL ─────────────────────────────────────────────────────
class TrackModel {
  final String id;
  String artistName;
  String releaseTitle;
  String featuring;
  File? mp3File;
  String? mp3FileName;
  double progress;
  String status;
  String errorMsg;
  Map<String, String> errors;

  TrackModel({
    required this.id,
    this.artistName    = '',
    this.releaseTitle  = '',
    this.featuring     = '',
    this.mp3File,
    this.mp3FileName,
    this.progress      = 0,
    this.status        = 'idle',
    this.errorMsg      = '',
    Map<String, String>? errors,
  }) : errors = errors ?? {};

  TrackModel copyWith({
    String? artistName,
    String? releaseTitle,
    String? featuring,
    File? mp3File,
    String? mp3FileName,
    double? progress,
    String? status,
    String? errorMsg,
    Map<String, String>? errors,
  }) {
    return TrackModel(
      id:           id,
      artistName:   artistName   ?? this.artistName,
      releaseTitle: releaseTitle ?? this.releaseTitle,
      featuring:    featuring    ?? this.featuring,
      mp3File:      mp3File      ?? this.mp3File,
      mp3FileName:  mp3FileName  ?? this.mp3FileName,
      progress:     progress     ?? this.progress,
      status:       status       ?? this.status,
      errorMsg:     errorMsg     ?? this.errorMsg,
      errors:       errors       ?? this.errors,
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  UPLOAD SCREEN
// ════════════════════════════════════════════════════════════════════
class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});
  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen>
    with TickerProviderStateMixin {

  File? _coverFile;
  String? _coverError;

  final List<TrackModel> _tracks   = [TrackModel(id: '1')];
  final Set<String>      _expanded = {'1'};

  bool   _uploading   = false;
  bool   _allDone     = false;
  String _globalError = '';

  late AnimationController _entranceCtrl;
  late Animation<double>   _entranceFade;
  late Animation<Offset>   _entranceSlide;

  // ── FONT SHORTHAND ───────────────────────────────────────────────
  TextStyle _t(double size, FontWeight w, Color c, {double ls = 0}) =>
      GoogleFonts.bebasNeue(fontSize: size, fontWeight: w, color: c, letterSpacing: ls);

  TextStyle _body(double size, FontWeight w, Color c, {double ls = 0, double h = 1.4}) =>
      GoogleFonts.nunito(fontSize: size, fontWeight: w, color: c, letterSpacing: ls, height: h);

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(
      statusBarColor:           Colors.transparent,
      systemNavigationBarColor: _black,
    ));
    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _entranceFade = CurvedAnimation(
        parent: _entranceCtrl, curve: Curves.easeOut);
    _entranceSlide = Tween<Offset>(
        begin: const Offset(0, 0.04), end: Offset.zero).animate(
        CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic));
    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  // ── COVER ART PICKER ─────────────────────────────────────────────
  Future<void> _pickCover() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 95);
    if (picked != null) {
      setState(() {
        _coverFile  = File(picked.path);
        _coverError = null;
      });
    }
  }

  // ── MP3 PICKER ───────────────────────────────────────────────────
  Future<void> _pickMp3(String trackId) async {
    try {
      _updateTrack(trackId, (t) {
        final errs = Map<String, String>.from(t.errors)..remove('mp3');
        return t.copyWith(errors: errs);
      });

      final result = await ImagePicker().pickMedia();
      if (result == null) return;

      final ext = result.path.split('.').last.toLowerCase();
      if (ext != 'mp3') {
        _updateTrack(trackId, (t) => t.copyWith(
          errors: {...t.errors, 'mp3':
          '.$ext files are not accepted. Please select an MP3 file only.'},
        ));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: _black2,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: _redBorder),
            ),
            content: Row(children: [
              const Icon(Icons.block_rounded, color: _red, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(
                '.$ext is not allowed — MP3 only',
                style: GoogleFonts.nunito(
                    color: _white, fontSize: 13, fontWeight: FontWeight.w600),
              )),
            ]),
            duration: const Duration(seconds: 4),
          ));
        }
        return;
      }

      final file = File(result.path);
      final size = await file.length();
      if (size > 50 * 1024 * 1024) {
        _updateTrack(trackId, (t) => t.copyWith(
          errors: {...t.errors, 'mp3': 'File exceeds 50 MB limit.'},
        ));
        return;
      }

      _updateTrack(trackId, (t) => t.copyWith(
        mp3File:     file,
        mp3FileName: result.name,
        errors:      Map.from(t.errors)..remove('mp3'),
      ));
    } catch (e) {
      _updateTrack(trackId, (t) => t.copyWith(
        errors: {...t.errors, 'mp3': 'Could not pick file. Try again.'},
      ));
    }
  }

  // ── TRACK HELPERS ────────────────────────────────────────────────
  void _updateTrack(String id, TrackModel Function(TrackModel) fn) {
    setState(() {
      final i = _tracks.indexWhere((t) => t.id == id);
      if (i != -1) _tracks[i] = fn(_tracks[i]);
    });
  }

  void _addTrack() {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    setState(() {
      _tracks.add(TrackModel(id: id));
      _expanded.add(id);
    });
  }

  void _removeTrack(String id) {
    setState(() {
      _tracks.removeWhere((t) => t.id == id);
      _expanded.remove(id);
    });
  }

  void _toggleExpand(String id) {
    setState(() {
      if (_expanded.contains(id)) _expanded.remove(id);
      else _expanded.add(id);
    });
  }

  // ── VALIDATE ─────────────────────────────────────────────────────
  bool _validateAll() {
    bool valid = true;
    if (_coverFile == null) {
      setState(() => _coverError = 'Cover art is required.');
      valid = false;
    }
    for (final track in _tracks) {
      final errs = <String, String>{};
      if (track.artistName.trim().isEmpty)   errs['artistName']   = 'Required';
      if (track.releaseTitle.trim().isEmpty) errs['releaseTitle'] = 'Required';
      if (track.mp3File == null)             errs['mp3']          = 'Please select an MP3 file.';
      if (errs.isNotEmpty) {
        valid = false;
        _updateTrack(track.id, (t) => t.copyWith(errors: errs));
        setState(() => _expanded.add(track.id));
      }
    }
    return valid;
  }

  // ── CLOUDINARY UPLOAD ────────────────────────────────────────────
  Future<String?> _uploadToCloudinary(File file, String folder) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(_cloudinaryUrl));
      request.fields['upload_preset'] = _cloudinaryPreset;
      request.fields['folder']        = folder;
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      final streamed = await request.send();
      final body     = await streamed.stream.bytesToString();
      final json     = jsonDecode(body) as Map<String, dynamic>;
      if (json.containsKey('secure_url')) return json['secure_url'] as String;
      debugPrint('Cloudinary error: $body');
      return null;
    } catch (e) {
      debugPrint('Cloudinary upload exception: $e');
      return null;
    }
  }

  // ── SEND EMAIL VIA EMAILJS ───────────────────────────────────────
  Future<void> _sendEmail(
      TrackModel track, String fileUrl, String? coverUrl) async {
    try {
      final now = DateTime.now();
      final submissionTime =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')} '
          '${now.hour.toString().padLeft(2, '0')}:'
          '${now.minute.toString().padLeft(2, '0')}';

      final response = await http.post(
        Uri.parse(_emailjsUrl),
        headers: {
          'Content-Type': 'application/json',
          'origin': 'http://localhost',
        },
        body: jsonEncode({
          'service_id':  _emailjsServiceId,
          'template_id': _emailjsTemplateId,
          'user_id':     _emailjsPublicKey,
          'accessToken': _emailjsPublicKey,
          'template_params': {
            'artist_name':      track.artistName,
            'release_title':    track.releaseTitle,
            'featuring':        track.featuring.isEmpty ? 'None' : track.featuring,
            'download_link':    fileUrl,
            'cover_art_link':   coverUrl ?? '',
            'submission_time':  submissionTime,
          },
        }),
      );

      if (response.statusCode != 200) {
        debugPrint('EmailJS error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('EmailJS send failed: $e');
    }
  }

  // ── UPLOAD ALL ───────────────────────────────────────────────────
  Future<void> _uploadAll() async {
    if (!_validateAll()) return;
    setState(() { _uploading = true; _globalError = ''; });

    String? coverUrl;
    if (_coverFile != null) {
      coverUrl = await _uploadToCloudinary(_coverFile!, 'covers');
    }

    bool anyError = false;

    for (final track in _tracks) {
      if (track.status == 'success') continue;
      _updateTrack(track.id, (t) => t.copyWith(
          status: 'uploading', progress: 0, errorMsg: ''));
      try {
        double sim = 0;
        final ticker = Stream.periodic(
            const Duration(milliseconds: 200)).listen((_) {
          sim = (sim + 8).clamp(0, 85);
          _updateTrack(track.id, (t) => t.copyWith(progress: sim));
        });
        final fileUrl = await _uploadToCloudinary(track.mp3File!, 'tracks');
        await ticker.cancel();
        if (fileUrl == null) throw Exception('Cloudinary returned no URL');
        _updateTrack(track.id, (t) => t.copyWith(progress: 95));
        await _sendEmail(track, fileUrl, coverUrl);
        _updateTrack(track.id,
                (t) => t.copyWith(progress: 100, status: 'success'));
      } catch (e) {
        anyError = true;
        _updateTrack(track.id, (t) => t.copyWith(
          status:   'error',
          errorMsg: 'Upload failed. Check connection and retry.',
          progress: 0,
        ));
      }
    }

    setState(() => _uploading = false);

    if (!anyError) {
      setState(() => _allDone = true);
      await Future.delayed(const Duration(milliseconds: 1800));
      if (mounted) Navigator.pushReplacementNamed(context, '/release-info');
    } else {
      setState(() =>
      _globalError = 'Some tracks failed. Check errors and retry.');
    }
  }

  String _fmtBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  int get _completedCount =>
      _tracks.where((t) => t.status == 'success').length;

  // ════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final top    = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: _black,
      body: FadeTransition(
        opacity: _entranceFade,
        child: SlideTransition(
          position: _entranceSlide,
          child: Column(
            children: [
              _buildTopBar(top),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCoverSection(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 32, 22, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('TRACKLIST',
                                      style: _t(18, FontWeight.w400,
                                          _greyDark, ls: 2)),
                                  Text('$_completedCount/${_tracks.length} ready',
                                      style: _body(12, FontWeight.w600, _grey)),
                                ],
                              )),
                            ]),
                            const SizedBox(height: 14),
                            ..._tracks.asMap().entries.map(
                                    (e) => _buildTrackRow(e.value, e.key)),
                            if (!_uploading && !_allDone) ...[
                              const SizedBox(height: 4),
                              _AddTrackButton(onTap: _addTrack),
                              const SizedBox(height: 24),
                            ],
                            if (_uploading) ...[
                              _buildUploadProgress(),
                              const SizedBox(height: 20),
                            ],
                            if (_allDone) ...[
                              _buildSuccessBanner(),
                              const SizedBox(height: 20),
                            ],
                            if (_globalError.isNotEmpty) ...[
                              _buildErrorBanner(_globalError),
                              const SizedBox(height: 16),
                            ],
                            if (!_allDone)
                              _SubmitButton(
                                uploading:      _uploading,
                                trackCount:     _tracks.length,
                                completedCount: _completedCount,
                                onTap:          _uploadAll,
                              ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.lock_outline_rounded,
                                    color: _greyDark, size: 11),
                                const SizedBox(width: 5),
                                Text('Secured · Powered by Cloudinary',
                                    style: _body(
                                        11, FontWeight.w500, _greyDark)),
                              ],
                            ),
                            SizedBox(height: bottom + 32),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── TOP BAR ──────────────────────────────────────────────────────
  Widget _buildTopBar(double top) {
    return Container(
      padding: EdgeInsets.only(top: top),
      color: _black,
      child: Container(
        height: 64,
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _white10))),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Row(children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: _white06,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _white10),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: _white, size: 16),
            ),
          ),
          const SizedBox(width: 14),
          Text('UPLOAD RELEASE',
              style: _t(20, FontWeight.w400, _white, ls: 1.5)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _white06,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: _white10),
            ),
            child: Row(children: [
              const Icon(Icons.lock_outline_rounded, color: _grey, size: 10),
              const SizedBox(width: 5),
              Text('Secure', style: _body(10, FontWeight.w600, _grey)),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── COVER SECTION ────────────────────────────────────────────────
  Widget _buildCoverSection() {
    return GestureDetector(
      onTap: _pickCover,
      child: Container(
        width: double.infinity, height: 320,
        color: _black1,
        child: Stack(fit: StackFit.expand, children: [
          if (_coverFile != null)
            Image.file(_coverFile!, fit: BoxFit.cover)
          else
            Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: _black3,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _white10),
                ),
                child: const Icon(Icons.image_outlined,
                    color: _greyDark, size: 32),
              ),
              const SizedBox(height: 16),
              Text('TAP TO ADD COVER ART',
                  style: _t(18, FontWeight.w400, _grey, ls: 1)),
              const SizedBox(height: 6),
              Text('3000×3000 px · JPG or PNG',
                  style: _body(12, FontWeight.w500, _greyDark)),
            ]),
          if (_coverFile != null)
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end:   Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xCC000000)],
                  stops:  [0.5, 1.0],
                ),
              ),
            ),
          if (_coverFile != null)
            Positioned(
              bottom: 16, left: 16, right: 16,
              child: Row(children: [
                _pillTag(Icons.check_circle_outline_rounded,
                    'Cover art set', _green),
                const Spacer(),
                _pillTag(Icons.edit_outlined, 'Change', _white70),
              ]),
            ),
          Positioned(
            top: 16, right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: _white10),
              ),
              child: Text('REQUIRED',
                  style: _body(9, FontWeight.w800,
                      _coverFile != null ? _green : _grey, ls: 1.2)),
            ),
          ),
          if (_coverError != null)
            Positioned(
              bottom: 60, left: 16,
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _redDim,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _redBorder),
                ),
                child: Text(_coverError!,
                    style: _body(11, FontWeight.w600, _red)),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _pillTag(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: _white20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 5),
        Text(label, style: _body(11, FontWeight.w600, color)),
      ]),
    );
  }

  // ── TRACK ROW ────────────────────────────────────────────────────
  Widget _buildTrackRow(TrackModel track, int index) {
    final isExpanded  = _expanded.contains(track.id);
    final isDone      = track.status == 'success';
    final hasError    = track.errors.isNotEmpty || track.errorMsg.isNotEmpty;
    final isUploading = track.status == 'uploading';

    final displayName = track.releaseTitle.isNotEmpty
        ? track.releaseTitle
        : track.artistName.isNotEmpty
        ? track.artistName
        : 'Track ${index + 1}';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _black2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDone
              ? _greenBorder
              : hasError
              ? _redBorder
              : isExpanded
              ? _white20
              : _white10,
        ),
      ),
      child: Column(children: [
        GestureDetector(
          onTap: () => _toggleExpand(track.id),
          child: Container(
            color: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: isDone
                      ? _greenDim
                      : hasError
                      ? _redDim
                      : _white06,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                      color: isDone
                          ? _greenBorder
                          : hasError
                          ? _redBorder
                          : _white10),
                ),
                child: Center(
                  child: isDone
                      ? const Icon(Icons.check_rounded,
                      color: _green, size: 16)
                      : Text(
                    (index + 1).toString().padLeft(2, '0'),
                    style: _body(11, FontWeight.w800,
                        hasError ? _red : _white70),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: _body(
                          14,
                          FontWeight.w700,
                          track.releaseTitle.isNotEmpty ||
                              track.artistName.isNotEmpty
                              ? _white
                              : _greyDark),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (track.mp3FileName != null)
                      Text(track.mp3FileName!,
                          style: _body(11, FontWeight.w500, _grey),
                          overflow: TextOverflow.ellipsis)
                    else
                      Text(
                        isUploading
                            ? 'Uploading ${track.progress.toInt()}%…'
                            : 'Tap to add details',
                        style: _body(11, FontWeight.w500,
                            isUploading ? _white70 : _greyDark),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (_tracks.length > 1 && !_uploading && !isDone)
                GestureDetector(
                  onTap: () => _removeTrack(track.id),
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: _redDim,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _redBorder),
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: _red, size: 13),
                  ),
                ),
              const SizedBox(width: 8),
              if (isUploading)
                _PulsingDot()
              else
                Container(
                  width: 7, height: 7,
                  decoration: BoxDecoration(
                    color: isDone
                        ? _green
                        : hasError
                        ? _red
                        : _white10,
                    shape: BoxShape.circle,
                  ),
                ),
              const SizedBox(width: 8),
              AnimatedRotation(
                turns: isExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: _greyDark, size: 20),
              ),
            ]),
          ),
        ),

        if (isUploading)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Uploading',
                        style: _body(10, FontWeight.w600, _grey, ls: 0.5)),
                    Text('${track.progress.toInt()}%',
                        style: _body(10, FontWeight.w700, _white70)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value:           track.progress / 100,
                    backgroundColor: _white06,
                    valueColor:
                    const AlwaysStoppedAnimation<Color>(_white),
                    minHeight: 3,
                  ),
                ),
              ],
            ),
          ),

        if (isExpanded) ...[
          Container(height: 1, color: _white10),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: _InputField(
                    label:       'Artist Name',
                    required:    true,
                    placeholder: 'e.g. Burna Boy',
                    value:       track.artistName,
                    error:       track.errors['artistName'],
                    enabled:     !_uploading && !isDone,
                    onChanged:   (v) => _updateTrack(
                        track.id, (t) => t.copyWith(artistName: v)),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _InputField(
                    label:       'Track Title',
                    required:    true,
                    placeholder: 'e.g. Abundance',
                    value:       track.releaseTitle,
                    error:       track.errors['releaseTitle'],
                    enabled:     !_uploading && !isDone,
                    onChanged:   (v) => _updateTrack(
                        track.id, (t) => t.copyWith(releaseTitle: v)),
                  )),
                ]),
                const SizedBox(height: 14),
                _InputField(
                  label:       'Featuring',
                  required:    false,
                  placeholder: 'Leave blank if none',
                  value:       track.featuring,
                  enabled:     !_uploading && !isDone,
                  onChanged:   (v) => _updateTrack(
                      track.id, (t) => t.copyWith(featuring: v)),
                ),
                const SizedBox(height: 14),
                _Mp3Zone(
                  fileName: track.mp3FileName,
                  fileSize: track.mp3File != null
                      ? _fmtBytes(track.mp3File!.lengthSync())
                      : null,
                  error:   track.errors['mp3'],
                  enabled: !_uploading && !isDone,
                  onTap:   () => _pickMp3(track.id),
                ),
                if (track.errorMsg.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildErrorBanner(track.errorMsg),
                ],
                if (isDone) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _greenDim,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _greenBorder),
                    ),
                    child: Row(children: [
                      const Icon(Icons.check_circle_outline_rounded,
                          color: _green, size: 16),
                      const SizedBox(width: 8),
                      Text('Track uploaded successfully',
                          style: _body(13, FontWeight.w600, _green)),
                    ]),
                  ),
                ],
                if (!isDone) ...[
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () => _toggleExpand(track.id),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _white06,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _white10),
                      ),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_rounded,
                                color: _grey, size: 14),
                            const SizedBox(width: 7),
                            Text('Done — Collapse',
                                style: _body(12, FontWeight.w700, _grey)),
                          ]),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ]),
    );
  }

  Widget _buildUploadProgress() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _black2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _white10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('UPLOADING YOUR RELEASE…',
            style: _t(20, FontWeight.w400, _white, ls: 1)),
        const SizedBox(height: 4),
        Text("Please don't close this page",
            style: _body(12, FontWeight.w500, _grey)),
        const SizedBox(height: 16),
        ..._tracks.map((t) {
          final dot = t.status == 'success'
              ? _green
              : t.status == 'error'
              ? _red
              : t.status == 'uploading'
              ? _white70
              : _greyDark;
          final label = t.status == 'success'
              ? '✓ Done'
              : t.status == 'error'
              ? '✗ Error'
              : t.status == 'uploading'
              ? '${t.progress.toInt()}%'
              : 'Waiting';
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Container(
                  width: 7, height: 7,
                  decoration:
                  BoxDecoration(color: dot, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  t.releaseTitle.isNotEmpty ? t.releaseTitle : 'Track',
                  style: _body(13, FontWeight.w600, _white70),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(label, style: _body(12, FontWeight.w700, dot)),
            ]),
          );
        }),
      ]),
    );
  }

  Widget _buildSuccessBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _greenDim,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _greenBorder),
      ),
      child: Row(children: [
        const Icon(Icons.check_circle_outline_rounded,
            color: _green, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ALL TRACKS UPLOADED!',
                    style: _t(18, FontWeight.w400, _green, ls: 1)),
                const SizedBox(height: 2),
                Text('Redirecting to next step…',
                    style: _body(12, FontWeight.w500, _green)),
              ]),
        ),
      ]),
    );
  }

  Widget _buildErrorBanner(String msg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _redDim,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _redBorder),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.warning_amber_rounded, color: _red, size: 16),
        const SizedBox(width: 8),
        Expanded(
            child: Text(msg,
                style: _body(12, FontWeight.w600, _red, h: 1.5))),
      ]),
    );
  }
}

// ── INPUT FIELD ───────────────────────────────────────────────────────
class _InputField extends StatelessWidget {
  final String label, placeholder, value;
  final bool required, enabled;
  final String? error;
  final ValueChanged<String> onChanged;

  const _InputField({
    required this.label,
    required this.required,
    required this.placeholder,
    required this.value,
    required this.onChanged,
    this.error,
    this.enabled = true,
  });

  TextStyle _body(double s, FontWeight w, Color c) =>
      GoogleFonts.nunito(fontSize: s, fontWeight: w, color: c);

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label.toUpperCase(),
            style: GoogleFonts.bebasNeue(
                color: _greyDark,
                fontSize: 13,
                fontWeight: FontWeight.w400,
                letterSpacing: 1.5)),
        if (required) ...[
          const SizedBox(width: 4),
          Container(
              width: 5, height: 5,
              decoration: const BoxDecoration(
                  color: _white40, shape: BoxShape.circle)),
        ],
      ]),
      const SizedBox(height: 6),
      TextFormField(
        initialValue: value,
        enabled:      enabled,
        onChanged:    onChanged,
        style:        _body(13, FontWeight.w600, _white),
        decoration: InputDecoration(
          hintText:  placeholder,
          hintStyle: _body(13, FontWeight.w400, _greyDark),
          filled:    true,
          fillColor: _black3,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _white10)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                  color: error != null ? _redBorder : _white10)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _white40)),
          disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _white06)),
        ),
      ),
      if (error != null) ...[
        const SizedBox(height: 5),
        Row(children: [
          const Icon(Icons.error_outline_rounded, color: _red, size: 11),
          const SizedBox(width: 4),
          Text(error!, style: _body(10, FontWeight.w600, _red)),
        ]),
      ],
    ]);
  }
}

// ── MP3 ZONE ─────────────────────────────────────────────────────────
class _Mp3Zone extends StatelessWidget {
  final String? fileName, fileSize, error;
  final bool enabled;
  final VoidCallback onTap;

  const _Mp3Zone({
    this.fileName, this.fileSize, this.error,
    this.enabled = true, required this.onTap,
  });

  TextStyle _t(double s, FontWeight w, Color c, {double ls = 0}) =>
      GoogleFonts.bebasNeue(
          fontSize: s, fontWeight: w, color: c, letterSpacing: ls);
  TextStyle _body(double s, FontWeight w, Color c) =>
      GoogleFonts.nunito(fontSize: s, fontWeight: w, color: c);

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('AUDIO FILE',
            style: _t(13, FontWeight.w400, _greyDark, ls: 1.5)),
        const SizedBox(width: 4),
        Container(
            width: 5, height: 5,
            decoration: const BoxDecoration(
                color: _white40, shape: BoxShape.circle)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _amberDim,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _amberBorder),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.music_note_rounded, color: _amber, size: 10),
            const SizedBox(width: 4),
            Text('MP3 ONLY', style: _t(10, FontWeight.w400, _amber, ls: 1)),
          ]),
        ),
      ]),
      const SizedBox(height: 6),
      GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _black3,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: error != null
                  ? _redBorder
                  : fileName != null
                  ? _white20
                  : _white10,
              width: error != null ? 1.5 : 1,
            ),
          ),
          child: fileName != null
              ? Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _black4,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _white10),
              ),
              child: const Icon(Icons.headphones_rounded,
                  color: _white70, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fileName!,
                      style: _body(13, FontWeight.w700, _white),
                      overflow: TextOverflow.ellipsis),
                  if (fileSize != null)
                    Text(fileSize!,
                        style: _body(11, FontWeight.w500, _grey)),
                ],
              ),
            ),
            const Icon(Icons.swap_horiz_rounded,
                color: _greyDark, size: 16),
          ])
              : Column(children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: _black4,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _white10),
              ),
              child: const Icon(Icons.audio_file_rounded,
                  color: _greyDark, size: 24),
            ),
            const SizedBox(height: 12),
            Text('TAP TO SELECT MP3',
                style: _t(16, FontWeight.w400, _grey, ls: 1)),
            const SizedBox(height: 4),
            Text('Only .mp3 files are accepted · max 50 MB',
                style: _body(11, FontWeight.w500, _greyDark)),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _FormatPill(label: 'MP3 ✓', accepted: true),
              const SizedBox(width: 6),
              _FormatPill(label: 'WAV ✗', accepted: false),
              const SizedBox(width: 6),
              _FormatPill(label: 'Images ✗', accepted: false),
              const SizedBox(width: 6),
              _FormatPill(label: 'Docs ✗', accepted: false),
            ]),
          ]),
        ),
      ),
      if (error != null) ...[
        const SizedBox(height: 5),
        Row(children: [
          const Icon(Icons.error_outline_rounded, color: _red, size: 11),
          const SizedBox(width: 4),
          Expanded(
              child: Text(error!,
                  style: _body(10, FontWeight.w600, _red))),
        ]),
      ],
    ]);
  }
}

// ── FORMAT PILL ───────────────────────────────────────────────────────
class _FormatPill extends StatelessWidget {
  final String label;
  final bool accepted;
  const _FormatPill({required this.label, required this.accepted});
  @override
  Widget build(BuildContext context) {
    final c = accepted ? _green : _greyDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: accepted ? _greenDim : Colors.transparent,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: accepted ? _greenBorder : _greyDark),
      ),
      child: Text(label,
          style: GoogleFonts.nunito(
              color: c, fontSize: 9, fontWeight: FontWeight.w700)),
    );
  }
}

// ── ADD TRACK BUTTON ──────────────────────────────────────────────────
class _AddTrackButton extends StatefulWidget {
  final VoidCallback onTap;
  const _AddTrackButton({required this.onTap});
  @override
  State<_AddTrackButton> createState() => _AddTrackButtonState();
}

class _AddTrackButtonState extends State<_AddTrackButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _pressed ? _white06 : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _pressed ? _white20 : _white10),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.add_rounded, color: _grey, size: 16),
          const SizedBox(width: 8),
          Text('ADD ANOTHER TRACK',
              style: GoogleFonts.bebasNeue(
                  color: _grey,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 1.5)),
        ]),
      ),
    );
  }
}

// ── SUBMIT BUTTON ─────────────────────────────────────────────────────
class _SubmitButton extends StatefulWidget {
  final bool uploading;
  final int trackCount, completedCount;
  final VoidCallback onTap;
  const _SubmitButton({
    required this.uploading,
    required this.trackCount,
    required this.completedCount,
    required this.onTap,
  });
  @override
  State<_SubmitButton> createState() => _SubmitButtonState();
}

class _SubmitButtonState extends State<_SubmitButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   widget.uploading
          ? null
          : (_) => setState(() => _pressed = true),
      onTapUp:     widget.uploading
          ? null
          : (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 17),
        decoration: BoxDecoration(
          color: widget.uploading
              ? _black3
              : _pressed
              ? const Color(0xFFE0E0E0)
              : _white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: widget.uploading ? _white10 : _white),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (widget.uploading) ...[
            const SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(_grey)),
            ),
            const SizedBox(width: 10),
            Text(
              'Uploading ${widget.completedCount}/${widget.trackCount}…',
              style: GoogleFonts.nunito(
                  color: _grey,
                  fontSize: 13,
                  fontWeight: FontWeight.w700),
            ),
          ] else ...[
            const Icon(Icons.upload_rounded, color: _black, size: 18),
            const SizedBox(width: 9),
            Text(
              'SUBMIT ${widget.trackCount} TRACK'
                  '${widget.trackCount > 1 ? 'S' : ''} TO 444MUSIC',
              style: GoogleFonts.bebasNeue(
                  color: _black,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 1.2),
            ),
          ],
        ]),
      ),
    );
  }
}

// ── PULSING DOT ───────────────────────────────────────────────────────
class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl);
  }
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
          width: 7, height: 7,
          decoration: const BoxDecoration(
              color: _white70, shape: BoxShape.circle)),
    );
  }
}