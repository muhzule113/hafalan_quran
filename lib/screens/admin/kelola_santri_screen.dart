import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../utils/supabase_client.dart';
import 'detail_santri_screen.dart'; // ← TAMBAHAN

class KelolaSantriScreen extends StatefulWidget {
  const KelolaSantriScreen({super.key});

  @override
  State<KelolaSantriScreen> createState() => _KelolaSantriScreenState();
}

class _KelolaSantriScreenState extends State<KelolaSantriScreen> {
  List<Map<String, dynamic>> _santriList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSantri();
  }

  Future<void> _loadSantri() async {
    setState(() => _isLoading = true);
    try {
      final data = await supabase
          .from('santri')
          .select()
          .eq('aktif', true)
          .order('nama');
      if (mounted) {
        setState(() {
          _santriList = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _hapusSantri(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Hapus Santri',
            style: GoogleFonts.dmSerifDisplay(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Yakin ingin menghapus santri ini?',
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_rounded,
                          color: Colors.red, size: 14),
                      const SizedBox(width: 6),
                      Text('Semua data akan dihapus:',
                          style: TextStyle(
                              color: Colors.red.shade300,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• Semua riwayat setoran\n• Semua rekaman audio\n• Progress hafalan\n• Target hafalan\n• Akun orang tua',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text('Tindakan ini tidak dapat dibatalkan.',
                style:
                    TextStyle(color: Colors.red.shade300, fontSize: 11)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade900,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Hapus Permanen'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final santriData = await supabase
          .from('santri')
          .select('orang_tua_id')
          .eq('id', id)
          .single();

      final orangTuaId = santriData['orang_tua_id'];

      final setoranList = await supabase
          .from('setoran')
          .select('id, audio_url')
          .eq('santri_id', id);

      final audioPaths = (setoranList as List)
          .where((s) => s['audio_url'] != null)
          .map((s) =>
              (s['audio_url'] as String).split('/audio-setoran/').last)
          .toList();

      if (audioPaths.isNotEmpty) {
        await supabase.storage.from('audio-setoran').remove(audioPaths);
      }

      await supabase.from('santri').delete().eq('id', id);

      if (orangTuaId != null) {
        try {
          await supabase
              .rpc('delete_user', params: {'user_id': orangTuaId});
        } catch (e) {
          // Tidak perlu throw — santri sudah terhapus
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Santri & semua datanya berhasil dihapus'),
          backgroundColor: AppColors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        _loadSantri();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Gagal hapus: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red.shade900,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
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
            crossAxisAlignment: CrossAxisAlignment.start,
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
                              color: Colors.white.withOpacity(0.08)),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: AppColors.textPrimary, size: 16),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text('Kelola Santri',
                          style: GoogleFonts.dmSerifDisplay(
                              fontSize: 24, color: AppColors.textPrimary)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.green.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.green.withOpacity(0.3)),
                      ),
                      child: Text('${_santriList.length} santri',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.greenLight,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Expanded(
                child: _isLoading
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: AppColors.gold))
                    : _santriList.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.school_outlined,
                                    size: 48, color: AppColors.textMuted),
                                const SizedBox(height: 12),
                                Text('Belum ada data santri',
                                    style: TextStyle(
                                        color: AppColors.textSecondary)),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            color: AppColors.gold,
                            backgroundColor: AppColors.bgCard,
                            onRefresh: _loadSantri,
                            child: ListView.separated(
                              padding:
                                  const EdgeInsets.fromLTRB(24, 0, 24, 100),
                              itemCount: _santriList.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final s = _santriList[index];
                                // ↓ DIMODIFIKASI: bungkus dengan GestureDetector
                                return GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DetailSantriScreen(
                                          santriId: s['id']),
                                    ),
                                  ).then((_) => _loadSantri()),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.03),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                          color:
                                              Colors.white.withOpacity(0.07)),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: AppColors.green
                                                .withOpacity(0.2),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                          child: Center(
                                            child: Text(
                                              s['nama'][0].toUpperCase(),
                                              style: GoogleFonts.dmSerifDisplay(
                                                  fontSize: 18,
                                                  color:
                                                      AppColors.greenLight),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                s['nama'],
                                                style: const TextStyle(
                                                    color:
                                                        AppColors.textPrimary,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                    fontSize: 14),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  if (s['kelas'] != null)
                                                    _MetaBadge(
                                                        label: s['kelas'],
                                                        color:
                                                            AppColors.green),
                                                  if (s['kelas'] != null)
                                                    const SizedBox(width: 6),
                                                  if (s['kamar'] != null)
                                                    _MetaBadge(
                                                        label: s['kamar'],
                                                        color: AppColors.gold),
                                                ],
                                              ),
                                              if (s['nama_wali'] != null)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 4),
                                                  child: Text(
                                                    'Wali: ${s['nama_wali']}',
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        color: AppColors
                                                            .textSecondary),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        PopupMenuButton(
                                          icon: Icon(Icons.more_vert_rounded,
                                              color: AppColors.textSecondary,
                                              size: 20),
                                          color: AppColors.bgCard,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14)),
                                          itemBuilder: (_) => [
                                            PopupMenuItem(
                                              value: 'edit',
                                              child: Row(children: [
                                                Icon(Icons.edit_outlined,
                                                    size: 16,
                                                    color: AppColors
                                                        .textSecondary),
                                                const SizedBox(width: 8),
                                                Text('Edit',
                                                    style: TextStyle(
                                                        color: AppColors
                                                            .textPrimary)),
                                              ]),
                                            ),
                                            PopupMenuItem(
                                              value: 'hapus',
                                              child: Row(children: const [
                                                Icon(Icons.delete_outline,
                                                    size: 16,
                                                    color: Colors.red),
                                                SizedBox(width: 8),
                                                Text('Hapus',
                                                    style: TextStyle(
                                                        color: Colors.red)),
                                              ]),
                                            ),
                                          ],
                                          onSelected: (val) {
                                            if (val == 'edit') {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      FormSantriScreen(
                                                          santri: s),
                                                ),
                                              ).then((_) => _loadSantri());
                                            } else {
                                              _hapusSantri(s['id']);
                                            }
                                          },
                                        ),
                                      ],
                                    ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => const FormSantriScreen()));
          _loadSantri();
        },
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.bg,
        icon: const Icon(Icons.add_rounded),
        label: Text('Tambah Santri',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _MetaBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _MetaBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, color: color, fontWeight: FontWeight.w500)),
    );
  }
}

// ─── Form Santri ──────────────────────────────────────────────────────────────

class FormSantriScreen extends StatefulWidget {
  final Map<String, dynamic>? santri;
  const FormSantriScreen({super.key, this.santri});

  @override
  State<FormSantriScreen> createState() => _FormSantriScreenState();
}

class _FormSantriScreenState extends State<FormSantriScreen> {
  final _namaController = TextEditingController();
  final _nisController = TextEditingController();
  final _kelasController = TextEditingController();
  final _kamarController = TextEditingController();
  final _namaWaliController = TextEditingController();
  final _noHpWaliController = TextEditingController();
  String _jenisKelamin = 'L';

  final _namaOrangTuaController = TextEditingController();
  final _emailOrangTuaController = TextEditingController();
  final _passwordOrangTuaController = TextEditingController();
  bool _buatAkunOrangTua = false;
  bool _obscurePass = true;

  List<Map<String, dynamic>> _orangTuaList = [];
  String? _selectedOrangTuaId;

  bool _isLoading = false;
  bool get _isEdit => widget.santri != null;

  @override
  void initState() {
    super.initState();
    _loadOrangTua();
    if (_isEdit) {
      final s = widget.santri!;
      _namaController.text = s['nama'] ?? '';
      _nisController.text = s['nis'] ?? '';
      _kelasController.text = s['kelas'] ?? '';
      _kamarController.text = s['kamar'] ?? '';
      _namaWaliController.text = s['nama_wali'] ?? '';
      _noHpWaliController.text = s['no_hp_wali'] ?? '';
      _jenisKelamin = s['jenis_kelamin'] ?? 'L';
      _selectedOrangTuaId = s['orang_tua_id'];
    }
  }

  Future<void> _hapusHubunganOrangTua() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Putuskan Orang Tua',
            style: GoogleFonts.dmSerifDisplay(color: AppColors.textPrimary)),
        content: Text(
          'Yakin ingin memutuskan hubungan orang tua dari santri ini? Akun orang tua tidak akan dihapus.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade900,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Putuskan'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _selectedOrangTuaId = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            const Text('Hubungan orang tua akan diputus saat simpan'),
        backgroundColor: AppColors.green,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  void _showEditOrangTuaSheet() {
    if (_selectedOrangTuaId == null) return;
    final ortu = _orangTuaList.firstWhere(
      (o) => o['id'] == _selectedOrangTuaId,
      orElse: () => {},
    );
    if (ortu.isEmpty) return;

    final namaCtrl = TextEditingController(text: ortu['nama'] ?? '');
    final noHpCtrl = TextEditingController(text: ortu['no_hp'] ?? '');
    final newPassCtrl = TextEditingController();
    bool saving = false;
    bool obscureNewPass = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 32),
          decoration: BoxDecoration(
            color: const Color(0xFF122A1E),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
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
                    child: const Icon(Icons.edit_outlined,
                        color: Colors.purpleAccent, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Edit Orang Tua',
                          style: GoogleFonts.dmSerifDisplay(
                              fontSize: 20, color: AppColors.textPrimary)),
                      Text(ortu['nama'] ?? '',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: namaCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Nama Lengkap',
                  prefixIcon: Icon(Icons.person_outlined,
                      color: AppColors.textSecondary, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noHpCtrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'No. HP',
                  prefixIcon: Icon(Icons.phone_outlined,
                      color: AppColors.textSecondary, size: 20),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (namaCtrl.text.isEmpty) return;
                          setModalState(() => saving = true);
                          try {
                            await supabase
                                .from('profiles')
                                .update({
                                  'nama': namaCtrl.text.trim(),
                                  'no_hp': noHpCtrl.text.trim(),
                                })
                                .eq('id', _selectedOrangTuaId!);
                            await _loadOrangTua();
                            if (context.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
                                content: const Text(
                                    'Data orang tua diperbarui'),
                                backgroundColor: AppColors.green,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                              ));
                            }
                          } catch (e) {
                            setModalState(() => saving = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.bg,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.bg))
                      : Text('Simpan Perubahan',
                          style: GoogleFonts.dmSans(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 10),

              // ─── RESET SANDI ───
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          newPassCtrl.clear();
                          final confirmed = await showDialog<bool>(
                            context: ctx,
                            builder: (_) => StatefulBuilder(
                              builder: (dCtx, setDialog) => AlertDialog(
                                backgroundColor: AppColors.bgCard,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                                title: Text('Reset Sandi',
                                    style: GoogleFonts.dmSerifDisplay(
                                        color: AppColors.textPrimary)),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        'Buat sandi baru untuk ${ortu['nama']}',
                                        style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 13)),
                                    const SizedBox(height: 14),
                                    TextField(
                                      controller: newPassCtrl,
                                      obscureText: obscureNewPass,
                                      style: const TextStyle(
                                          color: AppColors.textPrimary),
                                      decoration: InputDecoration(
                                        labelText: 'Sandi Baru',
                                        prefixIcon: const Icon(
                                            Icons.lock_outline_rounded,
                                            color: AppColors.textSecondary,
                                            size: 20),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            obscureNewPass
                                                ? Icons
                                                    .visibility_off_outlined
                                                : Icons.visibility_outlined,
                                            color: AppColors.textSecondary,
                                            size: 18,
                                          ),
                                          onPressed: () => setDialog(() =>
                                              obscureNewPass =
                                                  !obscureNewPass),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text('Minimal 6 karakter',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textMuted)),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dCtx, false),
                                    child: Text('Batal',
                                        style: TextStyle(
                                            color:
                                                AppColors.textSecondary)),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      if (newPassCtrl.text.length < 6)
                                        return;
                                      Navigator.pop(dCtx, true);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.gold,
                                      foregroundColor: AppColors.bg,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                    ),
                                    child: const Text('Reset'),
                                  ),
                                ],
                              ),
                            ),
                          );

                          if (confirmed != true) return;
                          if (newPassCtrl.text.length < 6) return;

                          setModalState(() => saving = true);
                          try {
                            final res = await supabase.functions.invoke(
                              'reset-password-user',
                              body: {
                                'user_id': _selectedOrangTuaId,
                                'new_password': newPassCtrl.text,
                              },
                            );
                            if (res.status != 200) {
                              throw Exception(res.data['error'] ??
                                  'Gagal reset sandi');
                            }
                            if (context.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
                                content: Text(
                                    'Sandi ${ortu['nama']} berhasil direset'),
                                backgroundColor: AppColors.green,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                              ));
                            }
                          } catch (e) {
                            setModalState(() => saving = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
                                content: Text('Gagal: $e'),
                                backgroundColor: Colors.red.shade900,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                              ));
                            }
                          }
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.gold,
                    side:
                        BorderSide(color: AppColors.gold.withOpacity(0.4)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_reset_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Reset Sandi',
                          style:
                              TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // ─── HAPUS AKUN ORANG TUA ───
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final confirm = await showDialog<bool>(
                            context: ctx,
                            builder: (_) => AlertDialog(
                              backgroundColor: AppColors.bgCard,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                              title: Text('Hapus Akun Orang Tua',
                                  style: GoogleFonts.dmSerifDisplay(
                                      color: AppColors.textPrimary)),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.08),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                      border: Border.all(
                                          color:
                                              Colors.red.withOpacity(0.2)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.warning_rounded,
                                            color: Colors.red, size: 16),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Akun ${ortu['nama']} akan dihapus permanen. Santri akan terputus dari orang tua ini.',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: AppColors
                                                    .textSecondary),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                      'Tindakan ini tidak dapat dibatalkan.',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.red.shade300)),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(ctx, false),
                                  child: Text('Batal',
                                      style: TextStyle(
                                          color:
                                              AppColors.textSecondary)),
                                ),
                                ElevatedButton(
                                  onPressed: () =>
                                      Navigator.pop(ctx, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade900,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                  child: const Text('Hapus Permanen'),
                                ),
                              ],
                            ),
                          );

                          if (confirm != true) return;

                          setModalState(() => saving = true);
                          try {
                            await supabase
                                .from('santri')
                                .update({'orang_tua_id': null}).eq(
                                    'orang_tua_id', _selectedOrangTuaId!);
                            await supabase.rpc('delete_user',
                                params: {'user_id': _selectedOrangTuaId});
                            if (context.mounted) {
                              setState(() => _selectedOrangTuaId = null);
                              await _loadOrangTua();
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
                                content: const Text(
                                    'Akun orang tua berhasil dihapus'),
                                backgroundColor: AppColors.green,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                              ));
                            }
                          } catch (e) {
                            setModalState(() => saving = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
                                content: Text('Gagal hapus: $e'),
                                backgroundColor: Colors.red.shade900,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                              ));
                            }
                          }
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: BorderSide(color: Colors.red.withOpacity(0.4)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.delete_outline_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Hapus Akun Orang Tua',
                          style:
                              TextStyle(fontWeight: FontWeight.w600)),
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

  Future<void> _loadOrangTua() async {
    try {
      final data = await supabase
          .from('profiles')
          .select('id, nama')
          .eq('role', 'orang_tua')
          .order('nama');
      if (mounted) {
        setState(() {
          _orangTuaList = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _simpan() async {
    if (_namaController.text.isEmpty) {
      _showSnack('Nama santri wajib diisi');
      return;
    }
    if (_buatAkunOrangTua) {
      if (_namaOrangTuaController.text.isEmpty ||
          _emailOrangTuaController.text.isEmpty ||
          _passwordOrangTuaController.text.isEmpty) {
        _showSnack('Data akun orang tua wajib diisi semua');
        return;
      }
      if (_passwordOrangTuaController.text.length < 6) {
        _showSnack('Password orang tua minimal 6 karakter');
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      String? orangTuaId = _selectedOrangTuaId;

      if (_buatAkunOrangTua) {
        final response = await supabase.functions.invoke(
          'buat-user',
          body: {
            'email': _emailOrangTuaController.text.trim(),
            'password': _passwordOrangTuaController.text,
            'nama': _namaOrangTuaController.text.trim(),
            'role': 'orang_tua',
          },
        );
        if (response.status != 200) {
          throw Exception(
              response.data['error'] ?? 'Gagal buat akun orang tua');
        }
        orangTuaId = response.data['id'] as String?;
      }

      final data = {
        'nama': _namaController.text.trim(),
        'nis': _nisController.text.trim(),
        'kelas': _kelasController.text.trim(),
        'kamar': _kamarController.text.trim(),
        'nama_wali': _namaWaliController.text.trim(),
        'no_hp_wali': _noHpWaliController.text.trim(),
        'jenis_kelamin': _jenisKelamin,
        'orang_tua_id': orangTuaId,
      };

      if (_isEdit) {
        await supabase
            .from('santri')
            .update(data)
            .eq('id', widget.santri!['id']);
      } else {
        await supabase.from('santri').insert(data);
      }

      if (mounted) {
        _showSnack(
          _isEdit ? 'Data santri diperbarui' : 'Santri berhasil ditambahkan',
          isSuccess: true,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Gagal: ${e.toString().replaceAll('Exception: ', '')}');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isSuccess ? AppColors.green : Colors.red.shade900,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  void dispose() {
    _namaController.dispose();
    _nisController.dispose();
    _kelasController.dispose();
    _kamarController.dispose();
    _namaWaliController.dispose();
    _noHpWaliController.dispose();
    _namaOrangTuaController.dispose();
    _emailOrangTuaController.dispose();
    _passwordOrangTuaController.dispose();
    super.dispose();
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    TextInputType type = TextInputType.text,
    IconData? icon,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      obscureText: obscure,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null
            ? Icon(icon, color: AppColors.textSecondary, size: 20)
            : null,
        suffixIcon: suffix,
      ),
    );
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
                              color: Colors.white.withOpacity(0.08)),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: AppColors.textPrimary, size: 16),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      _isEdit ? 'Edit Santri' : 'Tambah Santri',
                      style: GoogleFonts.dmSerifDisplay(
                          fontSize: 24, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SectionLabel(label: 'DATA SANTRI'),
                      const SizedBox(height: 14),
                      _field('Nama Lengkap', _namaController,
                          icon: Icons.person_outlined),
                      const SizedBox(height: 12),
                      _field('NIS', _nisController,
                          icon: Icons.badge_outlined),
                      const SizedBox(height: 12),
                      _field('Kelas', _kelasController,
                          icon: Icons.class_outlined),
                      const SizedBox(height: 12),
                      _field('Kamar', _kamarController,
                          icon: Icons.door_back_door_outlined),
                      const SizedBox(height: 12),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.08)),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _jenisKelamin,
                            dropdownColor: AppColors.bgCard,
                            style: const TextStyle(
                                color: AppColors.textPrimary),
                            items: const [
                              DropdownMenuItem(
                                  value: 'L', child: Text('Laki-laki')),
                              DropdownMenuItem(
                                  value: 'P', child: Text('Perempuan')),
                            ],
                            onChanged: (v) =>
                                setState(() => _jenisKelamin = v!),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _SectionLabel(label: 'DATA WALI'),
                      const SizedBox(height: 14),
                      _field('Nama Wali', _namaWaliController,
                          icon: Icons.family_restroom_outlined),
                      const SizedBox(height: 12),
                      _field('No. HP Wali', _noHpWaliController,
                          type: TextInputType.phone,
                          icon: Icons.phone_outlined),
                      const SizedBox(height: 20),
                      _SectionLabel(label: 'AKUN ORANG TUA'),
                      const SizedBox(height: 14),
                      if (_isEdit && _selectedOrangTuaId != null) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.green.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: AppColors.green.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.green.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                    Icons.family_restroom_rounded,
                                    color: AppColors.greenLight,
                                    size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _orangTuaList.firstWhere(
                                        (o) =>
                                            o['id'] == _selectedOrangTuaId,
                                        orElse: () =>
                                            {'nama': 'Orang Tua'},
                                      )['nama'],
                                      style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14),
                                    ),
                                    Text('Terhubung ke santri ini',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color:
                                                AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _showEditOrangTuaSheet(),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.blue.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: AppColors.blue
                                            .withOpacity(0.3)),
                                  ),
                                  child: const Text('Edit',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.lightBlue,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _hapusHubunganOrangTua(),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                      Icons.link_off_rounded,
                                      color: Colors.red,
                                      size: 16),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: Text('— atau ganti dengan —',
                              style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11)),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (!_buatAkunOrangTua)
                        _orangTuaList.isEmpty
                            ? Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color:
                                          Colors.orange.withOpacity(0.2)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline,
                                        color: Colors.orange, size: 16),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                          'Belum ada akun orang tua tersedia.',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color:
                                                  AppColors.textSecondary)),
                                    ),
                                  ],
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  border: Border.all(
                                      color:
                                          Colors.white.withOpacity(0.08)),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedOrangTuaId,
                                    dropdownColor: AppColors.bgCard,
                                    isExpanded: true,
                                    hint: Text('Pilih akun orang tua',
                                        style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 14)),
                                    items: [
                                      DropdownMenuItem(
                                        value: null,
                                        child: Text('Tidak dihubungkan',
                                            style: TextStyle(
                                                color: AppColors
                                                    .textSecondary)),
                                      ),
                                      ..._orangTuaList.map(
                                        (o) => DropdownMenuItem(
                                          value: o['id'],
                                          child: Text(o['nama'],
                                              style: const TextStyle(
                                                  color: AppColors
                                                      .textPrimary)),
                                        ),
                                      ),
                                    ],
                                    onChanged: (v) => setState(
                                        () => _selectedOrangTuaId = v),
                                  ),
                                ),
                              ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => setState(() {
                          _buatAkunOrangTua = !_buatAkunOrangTua;
                          if (_buatAkunOrangTua)
                            _selectedOrangTuaId = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _buatAkunOrangTua
                                ? AppColors.purple.withOpacity(0.1)
                                : Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _buatAkunOrangTua
                                  ? AppColors.purple.withOpacity(0.3)
                                  : Colors.white.withOpacity(0.08),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _buatAkunOrangTua
                                    ? Icons.person_add_rounded
                                    : Icons.person_add_outlined,
                                color: _buatAkunOrangTua
                                    ? Colors.purpleAccent
                                    : AppColors.textSecondary,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _buatAkunOrangTua
                                      ? 'Batalkan buat akun baru'
                                      : 'Buat akun orang tua baru',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _buatAkunOrangTua
                                        ? Colors.purpleAccent
                                        : AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Icon(
                                _buatAkunOrangTua
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                color: AppColors.textSecondary,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_buatAkunOrangTua) ...[
                        const SizedBox(height: 12),
                        _field('Nama Orang Tua', _namaOrangTuaController,
                            icon: Icons.person_outlined),
                        const SizedBox(height: 12),
                        _field('Email', _emailOrangTuaController,
                            type: TextInputType.emailAddress,
                            icon: Icons.email_outlined),
                        const SizedBox(height: 12),
                        _field(
                          'Password',
                          _passwordOrangTuaController,
                          icon: Icons.lock_outlined,
                          obscure: _obscurePass,
                          suffix: IconButton(
                            icon: Icon(
                              _obscurePass
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AppColors.textSecondary,
                              size: 18,
                            ),
                            onPressed: () => setState(
                                () => _obscurePass = !_obscurePass),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.purple.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: AppColors.purple.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded,
                                  color: Colors.purpleAccent, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Orang tua bisa login dengan email & password ini',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _simpan,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: AppColors.bg,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: AppColors.bg))
                              : Text(
                                  _isEdit
                                      ? 'Simpan Perubahan'
                                      : 'Tambah Santri',
                                  style: GoogleFonts.dmSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600),
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
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