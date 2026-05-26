import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../utils/supabase_client.dart';

class GrafikPerkembangan extends StatefulWidget {
  final String santriId;
  const GrafikPerkembangan({super.key, required this.santriId});

  @override
  State<GrafikPerkembangan> createState() => _GrafikPerkembanganState();
}

class _GrafikPerkembanganState extends State<GrafikPerkembangan> {
  List<Map<String, dynamic>> _setoranList = [];
  bool _isLoading = true;
  String _periode = 'minggu'; // minggu, bulan, semua

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      DateTime? since;
      if (_periode == 'minggu') {
        since = DateTime.now().subtract(const Duration(days: 7));
      } else if (_periode == 'bulan') {
        since = DateTime.now().subtract(const Duration(days: 30));
      }

      var query = supabase
          .from('setoran')
          .select()
          .eq('santri_id', widget.santriId);

      // Filter tanggal SEBELUM order
      if (since != null) {
        query = query.gte('tanggal', since.toIso8601String());
      }

      final data = await query.order('tanggal'); // ← order di sini

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

  // Hitung total ayat per hari
  Map<String, int> _totalAyatPerHari() {
    final map = <String, int>{};
    for (final s in _setoranList) {
      final date = DateTime.parse(s['tanggal']).toLocal();
      final key =
          '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
      final ayatSelesai = (s['ayat_selesai'] ?? 0) as int;
      final ayatMulai = (s['ayat_mulai'] ?? 0) as int;
      final ayat = (ayatSelesai - ayatMulai).abs() + 1;
      map[key] = (map[key] ?? 0) + ayat;
    }
    return map;
  }

  // Rata-rata nilai per hari
  Map<String, double> _avgNilaiPerHari() {
    final sumMap = <String, double>{};
    final countMap = <String, int>{};
    for (final s in _setoranList) {
      if (s['nilai_tajwid'] == null) continue;
      final date = DateTime.parse(s['tanggal']).toLocal();
      final key =
          '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
      final avg =
          ((s['nilai_kelancaran'] ?? 0) +
              (s['nilai_tajwid'] ?? 0) +
              (s['nilai_makhraj'] ?? 0)) /
          3.0;
      sumMap[key] = (sumMap[key] ?? 0) + avg;
      countMap[key] = (countMap[key] ?? 0) + 1;
    }
    return sumMap.map((k, v) => MapEntry(k, v / countMap[k]!));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      );
    }

    final ayatMap = _totalAyatPerHari();
    final nilaiMap = _avgNilaiPerHari();
    final keys = ayatMap.keys.toList();

    // Stats ringkas
    final totalSetoran = _setoranList.length;
    final diterima = _setoranList
        .where((s) => s['status'] == 'diterima')
        .length;
    final totalAyat = ayatMap.values.fold(0, (a, b) => a + b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter periode
        Row(
          children: [
            Text(
              'Grafik Perkembangan',
              style: GoogleFonts.dmSerifDisplay(
                fontSize: 18,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            _PeriodeChip(
              label: '7 Hari',
              isSelected: _periode == 'minggu',
              onTap: () {
                setState(() => _periode = 'minggu');
                _loadData();
              },
            ),
            const SizedBox(width: 6),
            _PeriodeChip(
              label: '30 Hari',
              isSelected: _periode == 'bulan',
              onTap: () {
                setState(() => _periode = 'bulan');
                _loadData();
              },
            ),
            const SizedBox(width: 6),
            _PeriodeChip(
              label: 'Semua',
              isSelected: _periode == 'semua',
              onTap: () {
                setState(() => _periode = 'semua');
                _loadData();
              },
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Stats ringkas
        Row(
          children: [
            _StatBox(
              label: 'Total Setoran',
              value: '$totalSetoran',
              color: AppColors.gold,
            ),
            const SizedBox(width: 10),
            _StatBox(
              label: 'Diterima',
              value: '$diterima',
              color: AppColors.greenLight,
            ),
            const SizedBox(width: 10),
            _StatBox(
              label: 'Total Ayat',
              value: '$totalAyat',
              color: Colors.lightBlue,
            ),
          ],
        ),

        const SizedBox(height: 20),

        if (keys.isEmpty)
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            child: Center(
              child: Text(
                'Belum ada data setoran',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          )
        else ...[
          // Grafik jumlah ayat per hari
          Text(
            'Jumlah Ayat per Hari',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 180,
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY:
                    (ayatMap.values.isEmpty
                            ? 10
                            : ayatMap.values.reduce((a, b) => a > b ? a : b) *
                                  1.3)
                        .toDouble(),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.bgCard,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${rod.toY.toInt()} ayat',
                        TextStyle(
                          color: AppColors.gold,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (val, _) => Text(
                        val.toInt().toString(),
                        style: TextStyle(
                          fontSize: 9,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, _) {
                        final idx = val.toInt();
                        if (idx >= 0 && idx < keys.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              keys[idx],
                              style: TextStyle(
                                fontSize: 8,
                                color: AppColors.textMuted,
                              ),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.white.withOpacity(0.05),
                    strokeWidth: 1,
                  ),
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(show: false),
                barGroups: keys.asMap().entries.map((e) {
                  final val = ayatMap[e.value] ?? 0;
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: val.toDouble(),
                        color: AppColors.gold,
                        width: keys.length > 14 ? 8 : 16,
                        borderRadius: BorderRadius.circular(4),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY:
                              (ayatMap.values.isEmpty
                                      ? 10
                                      : ayatMap.values.reduce(
                                              (a, b) => a > b ? a : b,
                                            ) *
                                            1.3)
                                  .toDouble(),
                          color: Colors.white.withOpacity(0.03),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),

          // Grafik nilai tajwid (kalau ada)
          if (nilaiMap.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Rata-rata Nilai Tajwid',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: 180,
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.07)),
              ),
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 5.5,
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => AppColors.bgCard,
                      getTooltipItems: (spots) => spots
                          .map(
                            (s) => LineTooltipItem(
                              s.y.toStringAsFixed(1),
                              TextStyle(
                                color: AppColors.greenLight,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: 1,
                        getTitlesWidget: (val, _) => Text(
                          val.toInt().toString(),
                          style: TextStyle(
                            fontSize: 9,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (val, _) {
                          final nilaiKeys = nilaiMap.keys.toList();
                          final idx = val.toInt();
                          if (idx >= 0 && idx < nilaiKeys.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                nilaiKeys[idx],
                                style: TextStyle(
                                  fontSize: 8,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: Colors.white.withOpacity(0.05),
                      strokeWidth: 1,
                    ),
                    drawVerticalLine: false,
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: nilaiMap.entries
                          .toList()
                          .asMap()
                          .entries
                          .map((e) => FlSpot(e.key.toDouble(), e.value.value))
                          .toList(),
                      isCurved: true,
                      color: AppColors.greenLight,
                      barWidth: 2.5,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                          radius: 3,
                          color: AppColors.greenLight,
                          strokeWidth: 1.5,
                          strokeColor: AppColors.bg,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.greenLight.withOpacity(0.08),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _PeriodeChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _PeriodeChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.gold.withOpacity(0.15)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.gold.withOpacity(0.4)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isSelected ? AppColors.gold : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
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
              style: TextStyle(fontSize: 9, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
