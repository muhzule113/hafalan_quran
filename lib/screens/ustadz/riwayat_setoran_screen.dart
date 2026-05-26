import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../utils/supabase_client.dart';
import 'input_setoran_screen.dart';
import 'progress_tracker_screen.dart';
import 'target_hafalan_screen.dart';

class RiwayatSetoranScreen extends StatefulWidget {
  final Map<String, dynamic> santri;
  const RiwayatSetoranScreen({super.key, required this.santri});

  @override
  State<RiwayatSetoranScreen> createState() => _RiwayatSetoranScreenState();
}

class _RiwayatSetoranScreenState extends State<RiwayatSetoranScreen> {
  List<Map<String, dynamic>> _setoranList = [];
  bool _isLoading = true;
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  bool _playerReady = false;
  String? _playingId;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
    _loadSetoran();
  }

  Future<void> _initPlayer() async {
    await _player.openPlayer();
    setState(() => _playerReady = true);
  }

  Future<void> _loadSetoran() async {
    setState(() => _isLoading = true);
    try {
      final data = await supabase
          .from('setoran')
          .select()
          .eq('santri_id', widget.santri['id'])
          .order('tanggal', ascending: false);
      if (mounted) {
        setState(() {
          _setoranList = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _togglePlay(String setoranId, String audioUrl) async {
    if (!_playerReady) return;
    if (_isPlaying && _playingId == setoranId) {
      await _player.stopPlayer();
      setState(() {
        _isPlaying = false;
        _playingId = null;
      });
      return;
    }
    if (_isPlaying) await _player.stopPlayer();
    try {
      setState(() {
        _isPlaying = true;
        _playingId = setoranId;
      });
      await _player.startPlayer(
        fromURI: audioUrl,
        codec: Codec.aacADTS,
        whenFinished: () {
          if (mounted) {
            setState(() {
              _isPlaying = false;
              _playingId = null;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _playingId = null;
        });
        _showSnack('Gagal memutar audio: $e');
      }
    }
  }

  Future<void> _hapusAudio(Map<String, dynamic> setoran) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Hapus Audio',
          style: GoogleFonts.dmSerifDisplay(color: AppColors.textPrimary),
        ),
        content: Text(
          'Hapus rekaman audio setoran ini? Data setoran tetap tersimpan.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Batal',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade900,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Hapus Audio'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Stop player kalau sedang play
      if (_playingId == setoran['id']) {
        await _player.stopPlayer();
        setState(() {
          _isPlaying = false;
          _playingId = null;
        });
      }

      // Hapus file dari storage
      if (setoran['audio_url'] != null) {
        final url = setoran['audio_url'] as String;
        final path = url.split('/audio-setoran/').last;
        print('Menghapus path: $path');
        final result = await supabase.storage.from('audio-setoran').remove([
          path,
        ]);
        print('Hasil hapus: $result');
      }

      // Update setoran — set audio_url jadi null
      await supabase
          .from('setoran')
          .update({'audio_url': null})
          .eq('id', setoran['id']);

      _showSnack('Audio berhasil dihapus', isSuccess: true);
      _loadSetoran();
    } catch (e) {
      _showSnack('Gagal hapus audio: $e');
    }
  }

  Future<void> _hapusSetoran(Map<String, dynamic> setoran) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Hapus Setoran',
          style: GoogleFonts.dmSerifDisplay(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hapus seluruh data setoran ini?',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.menu_book_rounded,
                    color: Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${setoran['surah']} · ${setoran['ayat_mulai']}-${setoran['ayat_selesai']}',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Audio dan semua penilaian akan ikut terhapus.',
              style: TextStyle(color: Colors.orange.shade300, fontSize: 11),
            ),
            const SizedBox(height: 4),
            Text(
              'Tindakan ini tidak dapat dibatalkan.',
              style: TextStyle(color: Colors.red.shade300, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Batal',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade900,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Hapus Semua'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Stop player kalau sedang play
      if (_playingId == setoran['id']) {
        await _player.stopPlayer();
        setState(() {
          _isPlaying = false;
          _playingId = null;
        });
      }

      // Hapus audio dari storage dulu
      if (setoran['audio_url'] != null) {
        try {
          final url = setoran['audio_url'] as String;
          final path = url.split('/audio-setoran/').last;
          await supabase.storage.from('audio-setoran').remove([path]);
        } catch (e) {
          print('Storage delete error (non-fatal): $e');
        }
      }

      // Hapus data setoran dari database
      await supabase.from('setoran').delete().eq('id', setoran['id']);

      _showSnack('Setoran berhasil dihapus', isSuccess: true);
      _loadSetoran();
    } catch (e) {
      _showSnack('Gagal hapus setoran: $e');
    }
  }

  Future<void> _updateStatus(String setoranId, String status) async {
    try {
      await supabase
          .from('setoran')
          .update({'status': status})
          .eq('id', setoranId);
      _loadSetoran();
      _showSnack('Status diperbarui', isSuccess: true);
    } catch (e) {
      _showSnack('Gagal update status: $e');
    }
  }

  void _showPenilaianSheet(Map<String, dynamic> setoran) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PenilaianSheet(setoran: setoran, onSaved: _loadSetoran),
    );
  }

  void _showSnack(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isSuccess ? AppColors.green : Colors.red.shade900,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'diterima':
        return AppColors.green;
      case 'diulang':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'diterima':
        return '✅ Diterima';
      case 'diulang':
        return '🔄 Diulang';
      default:
        return '⏳ Menunggu';
    }
  }

  String _timeAgo(String dateStr) {
    final date = DateTime.parse(dateStr).toLocal();
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
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: AppColors.textPrimary,
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.santri['nama'],
                            style: GoogleFonts.dmSerifDisplay(
                              fontSize: 22,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '${widget.santri['kelas'] ?? '-'} · ${widget.santri['kamar'] ?? '-'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Progress tracker button
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ProgressTrackerScreen(santri: widget.santri),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.green.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.map_rounded,
                              color: AppColors.greenLight,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Progress',
                              style: TextStyle(
                                color: AppColors.greenLight,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              TargetHafalanScreen(santri: widget.santri),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.gold.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.flag_rounded,
                              color: AppColors.gold,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Target',
                              style: TextStyle(
                                color: AppColors.gold,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Setor baru
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              InputSetoranScreen(santri: widget.santri),
                        ),
                      ).then((_) => _loadSetoran()),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.gold.withOpacity(0.3),
                          ),
                        ),
                        child: const Icon(
                          Icons.mic_rounded,
                          color: AppColors.gold,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Stats
              if (!_isLoading)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Row(
                    children: [
                      _MiniStat(
                        label: 'Total',
                        value: '${_setoranList.length}',
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      _MiniStat(
                        label: 'Diterima',
                        value:
                            '${_setoranList.where((s) => s['status'] == 'diterima').length}',
                        color: AppColors.greenLight,
                      ),
                      const SizedBox(width: 10),
                      _MiniStat(
                        label: 'Diulang',
                        value:
                            '${_setoranList.where((s) => s['status'] == 'diulang').length}',
                        color: Colors.orange,
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.gold),
                      )
                    : _setoranList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.menu_book_outlined,
                              size: 48,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Belum ada setoran',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: AppColors.gold,
                        backgroundColor: AppColors.bgCard,
                        onRefresh: _loadSetoran,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                          itemCount: _setoranList.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, index) {
                            final s = _setoranList[index];
                            final isThisPlaying =
                                _isPlaying && _playingId == s['id'];
                            final hasAudio = s['audio_url'] != null;
                            final hasPenilaian = s['nilai_tajwid'] != null;

                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isThisPlaying
                                    ? AppColors.gold.withOpacity(0.06)
                                    : Colors.white.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isThisPlaying
                                      ? AppColors.gold.withOpacity(0.3)
                                      : Colors.white.withOpacity(0.07),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Baris 1: Info + Status
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${s['surah']} · ${s['ayat_mulai']}-${s['ayat_selesai']}',
                                              style: const TextStyle(
                                                color: AppColors.textPrimary,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              _timeAgo(s['tanggal']),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _statusColor(
                                            s['status'],
                                          ).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: _statusColor(
                                              s['status'],
                                            ).withOpacity(0.3),
                                          ),
                                        ),
                                        child: Text(
                                          _statusLabel(s['status']),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: _statusColor(s['status']),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Penilaian tajwid (kalau sudah dinilai)
                                  if (hasPenilaian) ...[
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        _NilaiChip(
                                          label: 'Kelancaran',
                                          nilai: s['nilai_kelancaran'] ?? 0,
                                        ),
                                        const SizedBox(width: 8),
                                        _NilaiChip(
                                          label: 'Tajwid',
                                          nilai: s['nilai_tajwid'] ?? 0,
                                        ),
                                        const SizedBox(width: 8),
                                        _NilaiChip(
                                          label: 'Makhraj',
                                          nilai: s['nilai_makhraj'] ?? 0,
                                        ),
                                      ],
                                    ),
                                  ],

                                  if (s['catatan'] != null &&
                                      s['catatan'].toString().isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      s['catatan'],
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 12),

                                  // Baris aksi
                                  Row(
                                    children: [
                                      // Play audio
                                      if (hasAudio)
                                        GestureDetector(
                                          onTap: () => _togglePlay(
                                            s['id'],
                                            s['audio_url'],
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 7,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isThisPlaying
                                                  ? AppColors.gold.withOpacity(
                                                      0.2,
                                                    )
                                                  : Colors.white.withOpacity(
                                                      0.06,
                                                    ),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: isThisPlaying
                                                    ? AppColors.gold
                                                          .withOpacity(0.4)
                                                    : Colors.white.withOpacity(
                                                        0.1,
                                                      ),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  isThisPlaying
                                                      ? Icons.stop_rounded
                                                      : Icons
                                                            .play_arrow_rounded,
                                                  color: isThisPlaying
                                                      ? AppColors.gold
                                                      : AppColors.textSecondary,
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 5),
                                                Text(
                                                  isThisPlaying
                                                      ? 'Stop'
                                                      : 'Putar',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: isThisPlaying
                                                        ? AppColors.gold
                                                        : AppColors
                                                              .textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),

                                      // Nilai tajwid
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () => _showPenilaianSheet(s),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 7,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.purple.withOpacity(
                                              0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color: AppColors.purple
                                                  .withOpacity(0.3),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.star_rounded,
                                                color: Colors.purpleAccent,
                                                size: 14,
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                hasPenilaian
                                                    ? 'Edit Nilai'
                                                    : 'Nilai',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.purpleAccent,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      const Spacer(),

                                      // Menu (ubah status + hapus audio)
                                      PopupMenuButton<String>(
                                        color: AppColors.bgCard,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        icon: Icon(
                                          Icons.more_horiz_rounded,
                                          color: AppColors.textSecondary,
                                          size: 20,
                                        ),
                                        itemBuilder: (_) => [
                                          PopupMenuItem(
                                            value: 'diterima',
                                            child: Text(
                                              '✅ Terima setoran',
                                              style: TextStyle(
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'diulang',
                                            child: Text(
                                              '🔄 Minta diulang',
                                              style: TextStyle(
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'menunggu',
                                            child: Text(
                                              '⏳ Tandai menunggu',
                                              style: TextStyle(
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                          if (hasAudio)
                                            const PopupMenuItem(
                                              value: 'hapus_audio',
                                              child: Text(
                                                '🔇 Hapus audio saja',
                                                style: TextStyle(
                                                  color: Colors.orange,
                                                ),
                                              ),
                                            ),
                                          const PopupMenuItem(
                                            value: 'hapus_setoran',
                                            child: Text(
                                              '🗑️ Hapus seluruh setoran',
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                          ),
                                        ],
                                        onSelected: (val) {
                                          if (val == 'hapus_audio') {
                                            _hapusAudio(s);
                                          } else if (val == 'hapus_setoran') {
                                            _hapusSetoran(s);
                                          } else {
                                            _updateStatus(s['id'], val);
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Widget chip nilai
class _NilaiChip extends StatelessWidget {
  final String label;
  final int nilai;
  const _NilaiChip({required this.label, required this.nilai});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 9, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 4),
          ...List.generate(
            5,
            (i) => Icon(
              i < nilai ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 10,
              color: i < nilai ? AppColors.gold : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// Bottom sheet penilaian tajwid
class PenilaianSheet extends StatefulWidget {
  final Map<String, dynamic> setoran;
  final VoidCallback onSaved;
  const PenilaianSheet({
    super.key,
    required this.setoran,
    required this.onSaved,
  });

  @override
  State<PenilaianSheet> createState() => _PenilaianSheetState();
}

class _PenilaianSheetState extends State<PenilaianSheet> {
  int _kelancaran = 0;
  int _tajwid = 0;
  int _makhraj = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _kelancaran = widget.setoran['nilai_kelancaran'] ?? 0;
    _tajwid = widget.setoran['nilai_tajwid'] ?? 0;
    _makhraj = widget.setoran['nilai_makhraj'] ?? 0;
  }

  Future<void> _simpan() async {
    if (_kelancaran == 0 || _tajwid == 0 || _makhraj == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Semua nilai wajib diisi'),
          backgroundColor: Colors.red.shade900,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await supabase
          .from('setoran')
          .update({
            'nilai_kelancaran': _kelancaran,
            'nilai_tajwid': _tajwid,
            'nilai_makhraj': _makhraj,
            'status': 'diterima',
          })
          .eq('id', widget.setoran['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Penilaian berhasil disimpan'),
            backgroundColor: AppColors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        widget.onSaved();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal: $e'),
            backgroundColor: Colors.red.shade900,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _starRating(String label, int value, Function(int) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(
            5,
            (i) => GestureDetector(
              onTap: () => onChanged(i + 1),
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  i < value ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 36,
                  color: i < value ? AppColors.gold : AppColors.textMuted,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value == 0
              ? 'Belum dinilai'
              : value == 1
              ? 'Perlu banyak perbaikan'
              : value == 2
              ? 'Kurang'
              : value == 3
              ? 'Cukup'
              : value == 4
              ? 'Baik'
              : 'Sangat baik',
          style: TextStyle(
            fontSize: 11,
            color: value >= 4
                ? AppColors.greenLight
                : value >= 3
                ? AppColors.gold
                : Colors.orange,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF122A1E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.purple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    color: Colors.purpleAccent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Penilaian Tajwid',
                      style: GoogleFonts.dmSerifDisplay(
                        fontSize: 20,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${widget.setoran['surah']} · ${widget.setoran['ayat_mulai']}-${widget.setoran['ayat_selesai']}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            _starRating(
              'Kelancaran',
              _kelancaran,
              (v) => setState(() => _kelancaran = v),
            ),
            const SizedBox(height: 20),
            _starRating('Tajwid', _tajwid, (v) => setState(() => _tajwid = v)),
            const SizedBox(height: 20),
            _starRating(
              'Makhraj',
              _makhraj,
              (v) => setState(() => _makhraj = v),
            ),

            const SizedBox(height: 24),

            // Rata-rata
            if (_kelancaran > 0 && _tajwid > 0 && _makhraj > 0)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.gold.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Rata-rata nilai',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '${((_kelancaran + _tajwid + _makhraj) / 3).toStringAsFixed(1)} / 5.0',
                      style: GoogleFonts.dmSerifDisplay(
                        fontSize: 20,
                        color: AppColors.gold,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _simpan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.bg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.bg,
                        ),
                      )
                    : Text(
                        'Simpan Penilaian',
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.dmSerifDisplay(fontSize: 20, color: color),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
