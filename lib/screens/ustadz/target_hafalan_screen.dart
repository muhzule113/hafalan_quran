import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../utils/supabase_client.dart';

class TargetHafalanScreen extends StatefulWidget {
  final Map<String, dynamic> santri;
  const TargetHafalanScreen({super.key, required this.santri});

  @override
  State<TargetHafalanScreen> createState() => _TargetHafalanScreenState();
}

class _TargetHafalanScreenState extends State<TargetHafalanScreen> {
  List<Map<String, dynamic>> _targetList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTarget();
  }

  Future<void> _loadTarget() async {
    setState(() => _isLoading = true);
    try {
      final data = await supabase
          .from('target_hafalan')
          .select()
          .eq('santri_id', widget.santri['id'])
          .order('deadline');
      if (mounted) {
        setState(() {
          _targetList = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(String id, String status) async {
    try {
      await supabase
          .from('target_hafalan')
          .update({'status': status})
          .eq('id', id);
      _loadTarget();
      _showSnack(
        status == 'selesai'
            ? 'Target selesai! Alhamdulillah 🎉'
            : 'Status target diperbarui',
        isSuccess: true,
      );
    } catch (e) {
      _showSnack('Gagal update: $e');
    }
  }

  Future<void> _hapusTarget(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('Hapus Target',
            style: GoogleFonts.dmSerifDisplay(
                color: AppColors.textPrimary)),
        content: Text('Yakin ingin menghapus target ini?',
            style: TextStyle(color: AppColors.textSecondary)),
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
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await supabase.from('target_hafalan').delete().eq('id', id);
    _loadTarget();
    _showSnack('Target berhasil dihapus', isSuccess: true);
  }

  void _showSnack(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isSuccess ? AppColors.green : Colors.red.shade900,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'selesai': return AppColors.green;
      case 'gagal': return Colors.red;
      default: return AppColors.gold;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'selesai': return '✅ Selesai';
      case 'gagal': return '❌ Gagal';
      default: return '🎯 Aktif';
    }
  }

  int _sisaHari(String deadline) {
    final d = DateTime.parse(deadline);
    return d.difference(DateTime.now()).inDays;
  }

  Color _deadlineColor(int sisaHari) {
    if (sisaHari < 0) return Colors.red;
    if (sisaHari <= 7) return Colors.orange;
    return AppColors.greenLight;
  }

  String _deadlineLabel(int sisaHari) {
    if (sisaHari < 0) return 'Terlambat ${sisaHari.abs()} hari';
    if (sisaHari == 0) return 'Deadline hari ini!';
    return '$sisaHari hari lagi';
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
                        width: 38, height: 38,
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Target Hafalan',
                              style: GoogleFonts.dmSerifDisplay(
                                  fontSize: 22,
                                  color: AppColors.textPrimary)),
                          Text(widget.santri['nama'],
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.gold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(
                    color: AppColors.gold))
                    : _targetList.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.flag_outlined,
                          size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      Text('Belum ada target',
                          style: TextStyle(
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      Text('Tap + untuk tambah target',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted)),
                    ],
                  ),
                )
                    : RefreshIndicator(
                  color: AppColors.gold,
                  backgroundColor: AppColors.bgCard,
                  onRefresh: _loadTarget,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                    itemCount: _targetList.length,
                    separatorBuilder: (_, _) =>
                    const SizedBox(height: 12),
                    itemBuilder: (_, index) {
                      final t = _targetList[index];
                      final sisaHari = _sisaHari(t['deadline']);
                      final isAktif = t['status'] == 'aktif';

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isAktif
                                ? AppColors.gold.withOpacity(0.2)
                                : Colors.white.withOpacity(0.07),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(t['judul'],
                                      style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _statusColor(t['status'])
                                        .withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: _statusColor(t['status'])
                                            .withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    _statusLabel(t['status']),
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: _statusColor(t['status']),
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),

                            if (t['deskripsi'] != null &&
                                t['deskripsi'].toString().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(t['deskripsi'],
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                            ],

                            const SizedBox(height: 12),

                            // Info target
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (t['juz_target'] != null)
                                  _InfoChip(
                                    icon: Icons.menu_book_rounded,
                                    label: 'Juz ${t['juz_target']}',
                                    color: AppColors.purple,
                                  ),
                                if (t['surah_target'] != null)
                                  _InfoChip(
                                    icon: Icons.bookmark_rounded,
                                    label: t['surah_target'],
                                    color: AppColors.blue,
                                  ),
                                _InfoChip(
                                  icon: Icons.calendar_today_rounded,
                                  label:
                                  t['deadline'].toString().substring(0, 10),
                                  color: _deadlineColor(sisaHari),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // Sisa hari
                            if (isAktif)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _deadlineColor(sisaHari)
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: _deadlineColor(sisaHari)
                                          .withOpacity(0.3)),
                                ),
                                child: Row(children: [
                                  Icon(
                                    sisaHari < 0
                                        ? Icons.warning_rounded
                                        : Icons.timer_rounded,
                                    color: _deadlineColor(sisaHari),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _deadlineLabel(sisaHari),
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: _deadlineColor(sisaHari),
                                        fontWeight: FontWeight.w600),
                                  ),
                                ]),
                              ),

                            const SizedBox(height: 12),

                            // Action buttons
                            Row(
                              children: [
                                if (isAktif) ...[
                                  GestureDetector(
                                    onTap: () =>
                                        _updateStatus(t['id'], 'selesai'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: AppColors.green
                                            .withOpacity(0.15),
                                        borderRadius:
                                        BorderRadius.circular(10),
                                        border: Border.all(
                                            color: AppColors.green
                                                .withOpacity(0.3)),
                                      ),
                                      child: Row(children: [
                                        const Icon(Icons.check_rounded,
                                            color: AppColors.greenLight,
                                            size: 14),
                                        const SizedBox(width: 5),
                                        Text('Selesai',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color:
                                                AppColors.greenLight)),
                                      ]),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () =>
                                        _updateStatus(t['id'], 'gagal'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 7),
                                      decoration: BoxDecoration(
                                        color:
                                        Colors.red.withOpacity(0.1),
                                        borderRadius:
                                        BorderRadius.circular(10),
                                        border: Border.all(
                                            color: Colors.red
                                                .withOpacity(0.3)),
                                      ),
                                      child: Row(children: [
                                        const Icon(Icons.close_rounded,
                                            color: Colors.red, size: 14),
                                        const SizedBox(width: 5),
                                        const Text('Gagal',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.red)),
                                      ]),
                                    ),
                                  ),
                                ],
                                const Spacer(),
                                GestureDetector(
                                  onTap: () => _hapusTarget(t['id']),
                                  child: Container(
                                    width: 32, height: 32,
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius:
                                      BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: Colors.red,
                                        size: 16),
                                  ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => FormTargetSheet(
              santri: widget.santri,
              onSaved: _loadTarget,
            ),
          );
        },
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.bg,
        icon: const Icon(Icons.add_rounded),
        label: Text('Tambah Target',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// Chip info
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

// Form tambah target
class FormTargetSheet extends StatefulWidget {
  final Map<String, dynamic> santri;
  final VoidCallback onSaved;
  const FormTargetSheet(
      {super.key, required this.santri, required this.onSaved});

  @override
  State<FormTargetSheet> createState() => _FormTargetSheetState();
}

class _FormTargetSheetState extends State<FormTargetSheet> {
  final _judulController = TextEditingController();
  final _deskripsiController = TextEditingController();
  final _surahController = TextEditingController();
  int? _juzTarget;
  DateTime _deadline = DateTime.now().add(const Duration(days: 30));
  bool _isLoading = false;

  Future<void> _simpan() async {
    if (_judulController.text.isEmpty) {
      _showSnack('Judul target wajib diisi');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = supabase.auth.currentUser!.id;
      await supabase.from('target_hafalan').insert({
        'santri_id': widget.santri['id'],
        'ustadz_id': userId,
        'judul': _judulController.text.trim(),
        'deskripsi': _deskripsiController.text.trim(),
        'juz_target': _juzTarget,
        'surah_target': _surahController.text.trim().isEmpty
            ? null
            : _surahController.text.trim(),
        'deadline': _deadline.toIso8601String().substring(0, 10),
        'status': 'aktif',
      });

      if (mounted) {
        _showSnack('Target berhasil ditambahkan', isSuccess: true);
        widget.onSaved();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _showSnack('Gagal: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isSuccess ? AppColors.green : Colors.red.shade900,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.gold,
            surface: Color(0xFF122A1E),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  @override
  void dispose() {
    _judulController.dispose();
    _deskripsiController.dispose();
    _surahController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 32),
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
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),

            Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.flag_rounded,
                    color: AppColors.gold, size: 20),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Tambah Target',
                    style: GoogleFonts.dmSerifDisplay(
                        fontSize: 20, color: AppColors.textPrimary)),
                Text(widget.santri['nama'],
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ]),
            ]),

            const SizedBox(height: 20),

            // Judul
            TextField(
              controller: _judulController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Judul Target',
                prefixIcon: Icon(Icons.flag_outlined,
                    color: AppColors.textSecondary, size: 20),
              ),
            ),
            const SizedBox(height: 12),

            // Deskripsi
            TextField(
              controller: _deskripsiController,
              maxLines: 2,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Deskripsi (opsional)',
                prefixIcon: Icon(Icons.notes_rounded,
                    color: AppColors.textSecondary, size: 20),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),

            // Juz target
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _juzTarget,
                  dropdownColor: AppColors.bgCard,
                  isExpanded: true,
                  hint: Text('Pilih Juz Target (opsional)',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 14)),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text('Tidak spesifik juz',
                          style:
                          TextStyle(color: AppColors.textSecondary)),
                    ),
                    ...List.generate(
                        30,
                        (i) => DropdownMenuItem(
                              value: i + 1,
                              child: Text('Juz ${i + 1}',
                                  style: const TextStyle(
                                      color: AppColors.textPrimary)),
                            )),
                  ],
                  onChanged: (v) => setState(() => _juzTarget = v),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Surah target
            TextField(
              controller: _surahController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Surah Target (opsional)',
                prefixIcon: Icon(Icons.bookmark_outlined,
                    color: AppColors.textSecondary, size: 20),
              ),
            ),
            const SizedBox(height: 12),

            // Deadline picker
            GestureDetector(
              onTap: _pickDeadline,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  border:
                      Border.all(color: Colors.white.withOpacity(0.08)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today_rounded,
                      color: AppColors.textSecondary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Deadline',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                        Text(
                          _deadline.toIso8601String().substring(0, 10),
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Ubah',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.gold,
                            fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _simpan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.bg,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.bg))
                    : Text('Simpan Target',
                        style: GoogleFonts.dmSans(
                            fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}