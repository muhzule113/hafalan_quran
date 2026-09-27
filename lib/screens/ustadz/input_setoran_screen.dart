import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../theme/app_theme.dart';
import '../../utils/supabase_client.dart';
import '../../widgets/surah_picker.dart';
import '../../data/surah_data.dart';

class InputSetoranScreen extends StatefulWidget {
  final Map<String, dynamic> santri;
  final VoidCallback onOpenHistory;

  const InputSetoranScreen({
    super.key,
    required this.santri,
    required this.onOpenHistory,
  });

  @override
  State<InputSetoranScreen> createState() => _InputSetoranScreenState();
}

class _InputSetoranScreenState extends State<InputSetoranScreen> {
  final _recorder = FlutterSoundRecorder();
  SurahData? _selectedSurah;
  final _ayatMulaiController = TextEditingController();
  final _ayatSelesaiController = TextEditingController();
  final _catatanController = TextEditingController();

  bool _isRecording = false;
  bool _isRecorded = false;
  bool _isSaving = false;
  bool _recorderReady = false;
  String? _audioPath;
  String? _audioUrl;
  Duration _recordDuration = Duration.zero;

  String _status = 'menunggu';
  List<Map<String, dynamic>> _riwayatList = [];
  bool _isLoadingRiwayat = true;
  String? _riwayatError;

  @override
  void initState() {
    super.initState();
    _initRecorder();
    _loadRiwayat();
  }

  Future<void> _loadRiwayat() async {
    if (mounted) {
      setState(() {
        _isLoadingRiwayat = true;
        _riwayatError = null;
      });
    }

    try {
      final data = await supabase
          .from('setoran')
          .select('id, surah, ayat_mulai, ayat_selesai, status, tanggal')
          .eq('santri_id', widget.santri['id'])
          .order('tanggal', ascending: false)
          .limit(5);

      if (!mounted) return;
      setState(() {
        _riwayatList = List<Map<String, dynamic>>.from(data);
        _isLoadingRiwayat = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingRiwayat = false;
        _riwayatError = 'Riwayat tidak dapat dimuat';
      });
    }
  }

  Future<void> _initRecorder() async {
    if (!kIsWeb) {
      final micStatus = await Permission.microphone.request();
      if (micStatus != PermissionStatus.granted) {
        if (mounted) _showSnack('Izin mikrofon diperlukan');
        return;
      }
    }

    try {
      await _recorder.openRecorder();
      if (mounted) setState(() => _recorderReady = true);
    } catch (e) {
      if (mounted) _showSnack('Gagal menyiapkan perekam: $e');
    }
  }

  Future<void> _toggleRecording() async {
    if (!_recorderReady) {
      _showSnack('Perekam belum siap, coba lagi');
      return;
    }

    try {
      if (_isRecording) {
        await _stopRecording();
      } else {
        await _startRecording();
      }
    } catch (e) {
      if (mounted) _showSnack('Gagal merekam: $e');
    }
  }

  Future<void> _startRecording() async {
    final extension = kIsWeb ? 'webm' : 'aac';
    if (kIsWeb) {
      _audioPath =
          'setoran_${DateTime.now().millisecondsSinceEpoch}.$extension';
    } else {
      final dir = await getTemporaryDirectory();
      _audioPath =
          '${dir.path}/setoran_${DateTime.now().millisecondsSinceEpoch}.$extension';
    }

    await _recorder.setSubscriptionDuration(const Duration(milliseconds: 500));

    _recorder.onProgress!.listen((e) {
      if (mounted) {
        setState(() => _recordDuration = e.duration);
      }
    });

    await _recorder.startRecorder(
      toFile: _audioPath,
      codec: kIsWeb ? Codec.opusWebM : Codec.aacADTS,
    );

    setState(() {
      _isRecording = true;
      _isRecorded = false;
      _audioUrl = null;
      _recordDuration = Duration.zero;
    });
  }

  Future<void> _stopRecording() async {
    final audioUrl = await _recorder.stopRecorder();
    setState(() {
      _isRecording = false;
      _isRecorded = true;
      _audioUrl = kIsWeb ? audioUrl : null;
    });
  }

  Future<void> _simpanSetoran() async {
    if (_selectedSurah == null || // ← ubah ini
        _ayatMulaiController.text.isEmpty ||
        _ayatSelesaiController.text.isEmpty) {
      _showSnack('Surah dan ayat wajib diisi');
      return;
    }
    if (!_isRecorded || (kIsWeb ? _audioUrl == null : _audioPath == null)) {
      _showSnack('Rekam audio hafalan terlebih dahulu');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final userId = supabase.auth.currentUser!.id;
      final assignment = await supabase
          .from('santri')
          .select('ustadz_id')
          .eq('id', widget.santri['id'])
          .eq('aktif', true)
          .maybeSingle();
      if (assignment == null || assignment['ustadz_id'] != userId) {
        throw Exception('Santri sudah tidak ditugaskan kepada ustadz ini');
      }

      final ustadzProfile = await supabase
          .from('profiles')
          .select('nama')
          .eq('id', userId)
          .single();

      // Upload audio ke Supabase Storage
      final extension = kIsWeb ? 'webm' : 'aac';
      final fileName =
          'setoran/${widget.santri['id']}/${DateTime.now().millisecondsSinceEpoch}.$extension';

      if (kIsWeb) {
        final response = await http.get(Uri.parse(_audioUrl!));
        if (response.statusCode != 200) {
          throw Exception('Gagal membaca hasil rekaman');
        }
        await supabase.storage
            .from('audio-setoran')
            .uploadBinary(fileName, response.bodyBytes);
      } else {
        await supabase.storage
            .from('audio-setoran')
            .upload(fileName, File(_audioPath!));
      }

      final audioUrl = supabase.storage
          .from('audio-setoran')
          .getPublicUrl(fileName);

      // Simpan data setoran
      final setoran = await supabase
          .from('setoran')
          .insert({
            'santri_id': widget.santri['id'],
            'ustadz_id': userId,
            'surah': _selectedSurah!.namaLatin,
            'ayat_mulai': int.parse(_ayatMulaiController.text),
            'ayat_selesai': int.parse(_ayatSelesaiController.text),
            'audio_url': audioUrl,
            'status': _status,
            'catatan': _catatanController.text.trim(),
          })
          .select()
          .single();

      // Trigger notifikasi ke orang tua via Edge Function
      await supabase.functions.invoke(
        'kirim-notifikasi',
        body: {
          'setoran_id': setoran['id'],
          'santri_id': widget.santri['id'],
          'surah': _selectedSurah!.namaLatin,
          'ustadz_nama': ustadzProfile['nama'],
          'ayat_mulai': int.parse(_ayatMulaiController.text),
          'ayat_selesai': int.parse(_ayatSelesaiController.text),
        },
      );

      if (mounted) {
        _resetForm();
        _showSnack(
          'Setoran berhasil disimpan & notifikasi terkirim!',
          isSuccess: true,
        );
        await _loadRiwayat();
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Gagal: ${e.toString().replaceAll('Exception: ', '')}');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _resetForm() {
    _ayatMulaiController.clear();
    _ayatSelesaiController.clear();
    _catatanController.clear();
    setState(() {
      _selectedSurah = null;
      _isRecording = false;
      _isRecorded = false;
      _audioPath = null;
      _audioUrl = null;
      _recordDuration = Duration.zero;
      _status = 'menunggu';
    });
  }

  Color _riwayatStatusColor(String? status) {
    switch (status) {
      case 'diterima':
        return AppColors.green;
      case 'diulang':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _riwayatStatusLabel(String? status) {
    switch (status) {
      case 'diterima':
        return 'Diterima';
      case 'diulang':
        return 'Diulang';
      default:
        return 'Menunggu';
    }
  }

  String _timeAgo(String? dateStr) {
    final date = dateStr == null ? null : DateTime.tryParse(dateStr)?.toLocal();
    if (date == null) return 'Tanggal tidak tersedia';

    final diff = DateTime.now().difference(date);
    if (diff.isNegative || diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }

  Widget _buildRiwayatSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const _SectionLabel(label: 'RIWAYAT SETORAN'),
            TextButton(
              onPressed: widget.onOpenHistory,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.gold,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                minimumSize: const Size(0, 44),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Lihat semua'),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios_rounded, size: 12),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoadingRiwayat)
          const SizedBox(
            height: 56,
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.gold,
                strokeWidth: 2,
              ),
            ),
          )
        else if (_riwayatError != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  color: AppColors.textSecondary,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _riwayatError!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _loadRiwayat,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.gold,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 44),
                  ),
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
          )
        else if (_riwayatList.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  color: AppColors.textMuted,
                  size: 20,
                ),
                SizedBox(width: 10),
                Text(
                  'Belum ada riwayat setoran',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          )
        else ...[
          for (var index = 0; index < _riwayatList.length; index++) ...[
            _buildRiwayatCard(_riwayatList[index]),
            if (index < _riwayatList.length - 1) const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }

  Widget _buildRiwayatCard(Map<String, dynamic> setoran) {
    final status = setoran['status']?.toString();
    final statusColor = _riwayatStatusColor(status);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.menu_book_outlined,
              color: AppColors.greenLight,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${setoran['surah'] ?? '-'} - ${setoran['ayat_mulai'] ?? '-'}-${setoran['ayat_selesai'] ?? '-'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _timeAgo(setoran['tanggal']?.toString()),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withOpacity(0.3)),
            ),
            child: Text(
              _riwayatStatusLabel(status),
              style: TextStyle(
                color: statusColor,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    _ayatMulaiController.dispose();
    _ayatSelesaiController.dispose();
    _catatanController.dispose();
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
                            'Input Setoran',
                            style: GoogleFonts.dmSerifDisplay(
                              fontSize: 22,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            widget.santri['nama'],
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.gold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Rekam audio
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _isRecording
                                ? AppColors.gold.withOpacity(0.5)
                                : Colors.white.withOpacity(0.07),
                          ),
                        ),
                        child: Column(
                          children: [
                            // Visualizer / status
                            Container(
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Center(
                                child: _isRecording
                                    ? Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 10,
                                            height: 10,
                                            decoration: const BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            _formatDuration(_recordDuration),
                                            style: GoogleFonts.dmSerifDisplay(
                                              fontSize: 32,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ],
                                      )
                                    : _isRecorded
                                    ? Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.check_circle_rounded,
                                            color: AppColors.greenLight,
                                            size: 24,
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            'Rekaman selesai',
                                            style: TextStyle(
                                              color: AppColors.greenLight,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Text(
                                        'Siap merekam',
                                        style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 14,
                                        ),
                                      ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Tombol rekam
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_isRecorded)
                                  GestureDetector(
                                    onTap: () => setState(() {
                                      _isRecorded = false;
                                      _audioPath = null;
                                      _audioUrl = null;
                                    }),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.06),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.1),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.refresh_rounded,
                                            color: AppColors.textSecondary,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Ulang',
                                            style: TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                if (_isRecorded) const SizedBox(width: 12),
                                GestureDetector(
                                  onTap: _toggleRecording,
                                  child: Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _isRecording
                                          ? Colors.red
                                          : AppColors.gold,
                                      boxShadow: [
                                        BoxShadow(
                                          color:
                                              (_isRecording
                                                      ? Colors.red
                                                      : AppColors.gold)
                                                  .withOpacity(0.4),
                                          blurRadius: 16,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      _isRecording
                                          ? Icons.stop_rounded
                                          : Icons.mic_rounded,
                                      color: _isRecording
                                          ? Colors.white
                                          : AppColors.bg,
                                      size: 28,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),
                            Text(
                              _isRecording
                                  ? 'Tap untuk berhenti'
                                  : _isRecorded
                                  ? 'Audio siap disimpan'
                                  : 'Tap untuk mulai rekam',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Data setoran
                      _SectionLabel(label: 'DATA SETORAN'),
                      const SizedBox(height: 14),

                      // Ganti TextField surah dengan ini
                      GestureDetector(
                        onTap: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => SurahPicker(
                            initialValue: _selectedSurah?.namaLatin,
                            onSelected: (surah) {
                              setState(() {
                                _selectedSurah = surah;
                                // Auto update max ayat
                                _ayatSelesaiController.text = '';
                              });
                            },
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            border: Border.all(
                              color: _selectedSurah != null
                                  ? AppColors.gold.withOpacity(0.4)
                                  : Colors.white.withOpacity(0.08),
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.menu_book_outlined,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _selectedSurah == null
                                    ? Text(
                                        'Pilih Surah',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 14,
                                        ),
                                      )
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _selectedSurah!.namaLatin,
                                            style: const TextStyle(
                                              color: AppColors.textPrimary,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            '${_selectedSurah!.arti} · ${_selectedSurah!.jumlahAyat} ayat',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                              if (_selectedSurah != null)
                                Text(
                                  _selectedSurah!.nama,
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: AppColors.gold,
                                    fontFamily: 'serif',
                                  ),
                                ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _ayatMulaiController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Ayat Mulai',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _ayatSelesaiController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Ayat Selesai',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Status setoran
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _status,
                            dropdownColor: AppColors.bgCard,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'diterima',
                                child: Text('✅ Diterima'),
                              ),
                              DropdownMenuItem(
                                value: 'diulang',
                                child: Text('🔄 Perlu Diulang'),
                              ),
                              DropdownMenuItem(
                                value: 'menunggu',
                                child: Text('⏳ Menunggu Review'),
                              ),
                            ],
                            onChanged: (v) => setState(() => _status = v!),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: _catatanController,
                        maxLines: 3,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Catatan (opsional)',
                          prefixIcon: Icon(
                            Icons.notes_rounded,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                          alignLabelWithHint: true,
                        ),
                      ),

                      const SizedBox(height: 28),

                      SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _simpanSetoran,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: AppColors.bg,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.bg,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.save_rounded, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Simpan & Kirim Notifikasi',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      _buildRiwayatSection(),
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
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: AppColors.gold,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
