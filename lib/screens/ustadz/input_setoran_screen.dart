import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../theme/app_theme.dart';
import '../../utils/supabase_client.dart';
import '../../widgets/surah_picker.dart';
import '../../data/surah_data.dart';

class InputSetoranScreen extends StatefulWidget {
  final Map<String, dynamic> santri;
  const InputSetoranScreen({super.key, required this.santri});

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
  Duration _recordDuration = Duration.zero;

  String _status = 'menunggu';

  @override
  void initState() {
    super.initState();
    _initRecorder();
  }

  Future<void> _initRecorder() async {
    final micStatus = await Permission.microphone.request();
    if (micStatus != PermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Izin mikrofon diperlukan'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    await _recorder.openRecorder();
    setState(() => _recorderReady = true);
  }

  Future<void> _toggleRecording() async {
    if (!_recorderReady) return;

    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    final dir = await getTemporaryDirectory();
    _audioPath =
        '${dir.path}/setoran_${DateTime.now().millisecondsSinceEpoch}.aac';

    await _recorder.setSubscriptionDuration(const Duration(milliseconds: 500));

    _recorder.onProgress!.listen((e) {
      if (mounted) {
        setState(() => _recordDuration = e.duration);
      }
    });

    await _recorder.startRecorder(toFile: _audioPath, codec: Codec.aacADTS);

    setState(() {
      _isRecording = true;
      _isRecorded = false;
      _recordDuration = Duration.zero;
    });
  }

  Future<void> _stopRecording() async {
    await _recorder.stopRecorder();
    setState(() {
      _isRecording = false;
      _isRecorded = true;
    });
  }

  Future<void> _simpanSetoran() async {
    if (_selectedSurah == null || // ← ubah ini
        _ayatMulaiController.text.isEmpty ||
        _ayatSelesaiController.text.isEmpty) {
      _showSnack('Surah dan ayat wajib diisi');
      return;
    }
    if (!_isRecorded || _audioPath == null) {
      _showSnack('Rekam audio hafalan terlebih dahulu');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final userId = supabase.auth.currentUser!.id;
      final ustadzProfile = await supabase
          .from('profiles')
          .select('nama')
          .eq('id', userId)
          .single();

      // Upload audio ke Supabase Storage
      final audioFile = File(_audioPath!);
      final fileName =
          'setoran/${widget.santri['id']}/${DateTime.now().millisecondsSinceEpoch}.aac';

      await supabase.storage.from('audio-setoran').upload(fileName, audioFile);

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
        _showSnack(
          'Setoran berhasil disimpan & notifikasi terkirim!',
          isSuccess: true,
        );
        Navigator.pop(context);
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
