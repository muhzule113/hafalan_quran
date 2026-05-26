import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../utils/supabase_client.dart';

class ProgressTrackerScreen extends StatefulWidget {
  final Map<String, dynamic> santri;
  const ProgressTrackerScreen({super.key, required this.santri});

  @override
  State<ProgressTrackerScreen> createState() => _ProgressTrackerScreenState();
}

class _ProgressTrackerScreenState extends State<ProgressTrackerScreen> {
  Map<int, String> _progressMap = {};
  bool _isLoading = true;
  bool _isSaving = false;

  // Nama-nama juz

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    setState(() => _isLoading = true);
    try {
      final data = await supabase
          .from('progress_hafalan')
          .select()
          .eq('santri_id', widget.santri['id']);

      final map = <int, String>{};
      for (final row in data as List) {
        map[row['juz'] as int] = row['status'] as String;
      }

      if (mounted) {
        setState(() {
          _progressMap = map;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateJuz(int juz, String status) async {
    setState(() => _isSaving = true);
    try {
      await supabase.from('progress_hafalan').upsert({
        'santri_id': widget.santri['id'],
        'juz': juz,
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'santri_id,juz');

      setState(() => _progressMap[juz] = status);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal update: $e'),
          backgroundColor: Colors.red.shade900,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showJuzPicker(int juz) {
    final current = _progressMap[juz] ?? 'belum';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF122A1E),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
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
            Text('Juz $juz — Update Status',
                style: GoogleFonts.dmSerifDisplay(
                    fontSize: 20, color: AppColors.textPrimary)),
            const SizedBox(height: 20),

            _StatusOption(
              label: 'Belum Hafal',
              icon: Icons.radio_button_unchecked_rounded,
              color: AppColors.textMuted,
              isSelected: current == 'belum',
              onTap: () {
                Navigator.pop(context);
                _updateJuz(juz, 'belum');
              },
            ),
            const SizedBox(height: 10),
            _StatusOption(
              label: 'Sedang Dihafal',
              icon: Icons.pending_rounded,
              color: Colors.amber,
              isSelected: current == 'sedang',
              onTap: () {
                Navigator.pop(context);
                _updateJuz(juz, 'sedang');
              },
            ),
            const SizedBox(height: 10),
            _StatusOption(
              label: 'Sudah Hafal',
              icon: Icons.check_circle_rounded,
              color: AppColors.greenLight,
              isSelected: current == 'hafal',
              onTap: () {
                Navigator.pop(context);
                _updateJuz(juz, 'hafal');
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Color _juzColor(String status) {
    switch (status) {
      case 'hafal': return AppColors.green;
      case 'sedang': return const Color(0xFFB8860B);
      default: return Colors.transparent;
    }
  }

  Color _juzBorderColor(String status) {
    switch (status) {
      case 'hafal': return AppColors.greenLight;
      case 'sedang': return Colors.amber;
      default: return Colors.white.withOpacity(0.1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalHafal = _progressMap.values.where((s) => s == 'hafal').length;
    final totalSedang = _progressMap.values.where((s) => s == 'sedang').length;
    final persen = (totalHafal / 30 * 100).toInt();

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
                          Text('Progress Hafalan',
                              style: GoogleFonts.dmSerifDisplay(
                                  fontSize: 22, color: AppColors.textPrimary)),
                          Text(widget.santri['nama'],
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.gold)),
                        ],
                      ),
                    ),
                    if (_isSaving)
                      const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.gold),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Stats
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.gold.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Progress Al-Qur\'an',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12)),
                          Text('$persen%',
                              style: GoogleFonts.dmSerifDisplay(
                                  fontSize: 22, color: AppColors.gold)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: totalHafal / 30,
                          backgroundColor: Colors.white.withOpacity(0.1),
                          valueColor: const AlwaysStoppedAnimation(
                              AppColors.gold),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _ProgressStat(
                              label: 'Hafal',
                              value: '$totalHafal juz',
                              color: AppColors.greenLight),
                          _ProgressStat(
                              label: 'Sedang',
                              value: '$totalSedang juz',
                              color: Colors.amber),
                          _ProgressStat(
                              label: 'Belum',
                              value: '${30 - totalHafal - totalSedang} juz',
                              color: AppColors.textMuted),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Legend
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    _Legend(color: AppColors.greenLight, label: 'Hafal'),
                    const SizedBox(width: 16),
                    _Legend(color: Colors.amber, label: 'Sedang'),
                    const SizedBox(width: 16),
                    _Legend(
                        color: Colors.white.withOpacity(0.15),
                        label: 'Belum'),
                    const Spacer(),
                    Text('Tap juz untuk update',
                        style: TextStyle(
                            fontSize: 10, color: AppColors.textMuted)),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Grid 30 juz
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(
                    color: AppColors.gold))
                    : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1,
                    ),
                    itemCount: 30,
                    itemBuilder: (_, index) {
                      final juz = index + 1;
                      final status = _progressMap[juz] ?? 'belum';

                      return GestureDetector(
                        onTap: () => _showJuzPicker(juz),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: _juzColor(status).withOpacity(
                                status == 'belum' ? 0.05 : 0.25),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: _juzBorderColor(status),
                                width: status == 'hafal' ? 1.5 : 1),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (status == 'hafal')
                                const Icon(Icons.check_rounded,
                                    color: AppColors.greenLight, size: 16)
                              else if (status == 'sedang')
                                const Icon(Icons.circle,
                                    color: Colors.amber, size: 8),
                              const SizedBox(height: 2),
                              Text('$juz',
                                  style: GoogleFonts.dmSerifDisplay(
                                    fontSize: 18,
                                    color: status == 'hafal'
                                        ? AppColors.greenLight
                                        : status == 'sedang'
                                        ? Colors.amber
                                        : AppColors.textMuted,
                                  )),
                              Text('juz',
                                  style: TextStyle(
                                      fontSize: 8,
                                      color: AppColors.textMuted)),
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
    );
  }
}

class _StatusOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusOption({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color.withOpacity(0.4) : Colors.white.withOpacity(0.08),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 14),
          Text(label,
              style: TextStyle(
                  color: isSelected ? color : AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
          const Spacer(),
          if (isSelected)
            Icon(Icons.check_circle_rounded, color: color, size: 18),
        ]),
      ),
    );
  }
}

class _ProgressStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _ProgressStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value, style: TextStyle(
          color: color, fontSize: 14, fontWeight: FontWeight.w600)),
      Text(label, style: TextStyle(
          color: AppColors.textMuted, fontSize: 10)),
    ]);
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 12, height: 12,
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(3)),
      ),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(
          fontSize: 11, color: AppColors.textSecondary)),
    ]);
  }
}