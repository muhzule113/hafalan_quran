import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/supabase_client.dart';
import '../../widgets/error_state.dart';

class SetoranDetailScreen extends StatefulWidget {
  final String setoranId;
  final String santriId;

  const SetoranDetailScreen({
    super.key,
    required this.setoranId,
    required this.santriId,
  });

  @override
  State<SetoranDetailScreen> createState() => _SetoranDetailScreenState();
}

class _SetoranDetailScreenState extends State<SetoranDetailScreen> {
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  Map<String, dynamic>? _setoran;
  bool _isLoading = true;
  bool _playerReady = false;
  bool _isPlaying = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
    _loadSetoran();
  }

  Future<void> _initPlayer() async {
    try {
      await _player.openPlayer();
      if (mounted) setState(() => _playerReady = true);
    } catch (_) {}
  }

  Future<void> _loadSetoran() async {
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
    try {
      final data = await supabase
          .from('setoran')
          .select()
          .eq('id', widget.setoranId)
          .eq('santri_id', widget.santriId)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _setoran = data;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadFailed = true;
      });
    }
  }

  Future<void> _togglePlay() async {
    final audioUrl = _setoran?['audio_url']?.toString();
    if (!_playerReady || audioUrl == null || audioUrl.isEmpty) return;

    if (_isPlaying) {
      await _player.stopPlayer();
      if (mounted) setState(() => _isPlaying = false);
      return;
    }

    try {
      setState(() => _isPlaying = true);
      await _player.startPlayer(
        fromURI: audioUrl,
        codec: Codec.aacADTS,
        whenFinished: () {
          if (mounted) setState(() => _isPlaying = false);
        },
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isPlaying = false);
      AppSnackbar.error(context, 'Gagal memutar audio');
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'diterima':
        return AppColors.green;
      case 'diulang':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'diterima':
        return '✅ Diterima';
      case 'diulang':
        return '🔄 Diulang';
      default:
        return '⏳ Menunggu';
    }
  }

  String _timeAgo(Object? value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '-';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }

  @override
  void dispose() {
    _player.closePlayer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D2818), Color(0xFF071510)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 24, 12),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Kembali',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: AppColors.textPrimary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Detail Setoran',
                      style: GoogleFonts.dmSerifDisplay(
                        fontSize: 24,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      );
    }
    if (_loadFailed) {
      return ErrorState(message: 'Gagal memuat setoran', onRetry: _loadSetoran);
    }
    final setoran = _setoran;
    if (setoran == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              'Setoran tidak tersedia',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    final status = setoran['status']?.toString();
    final hasPenilaian =
        setoran['nilai_kelancaran'] != null ||
        setoran['nilai_tajwid'] != null ||
        setoran['nilai_makhraj'] != null;
    final catatan = setoran['catatan']?.toString().trim() ?? '';
    final audioUrl = setoran['audio_url']?.toString() ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${setoran['surah'] ?? '-'} · ${setoran['ayat_mulai'] ?? '-'}-${setoran['ayat_selesai'] ?? '-'}',
              style: GoogleFonts.dmSerifDisplay(
                fontSize: 24,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _timeAgo(setoran['tanggal']),
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _statusColor(status).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _statusColor(status).withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                _statusLabel(status),
                style: TextStyle(
                  color: _statusColor(status),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (hasPenilaian) ...[
              const SizedBox(height: 20),
              Text(
                'PENILAIAN USTADZ',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _Score(
                    label: 'Kelancaran',
                    value: setoran['nilai_kelancaran'],
                  ),
                  const SizedBox(width: 10),
                  _Score(label: 'Tajwid', value: setoran['nilai_tajwid']),
                  const SizedBox(width: 10),
                  _Score(label: 'Makhraj', value: setoran['nilai_makhraj']),
                ],
              ),
            ],
            if (catatan.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'CATATAN',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                catatan,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (audioUrl.isNotEmpty) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _playerReady ? _togglePlay : null,
                  icon: Icon(
                    _isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  ),
                  label: Text(_isPlaying ? 'Hentikan Audio' : 'Putar Bacaan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.bg,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Score extends StatelessWidget {
  final String label;
  final Object? value;

  const _Score({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.purple.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.purple.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              value?.toString() ?? '-',
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
