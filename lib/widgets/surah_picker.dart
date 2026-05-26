import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/surah_data.dart';
import '../theme/app_theme.dart';

class SurahPicker extends StatefulWidget {
  final String? initialValue;
  final Function(SurahData) onSelected;

  const SurahPicker({
    super.key,
    this.initialValue,
    required this.onSelected,
  });

  @override
  State<SurahPicker> createState() => _SurahPickerState();
}

class _SurahPickerState extends State<SurahPicker> {
  final _searchController = TextEditingController();
  List<SurahData> _filtered = daftarSurah;

  void _filter(String query) {
    setState(() {
      _filtered = daftarSurah.where((s) =>
        s.namaLatin.toLowerCase().contains(query.toLowerCase()) ||
        s.nama.contains(query) ||
        s.nomor.toString() == query ||
        s.arti.toLowerCase().contains(query.toLowerCase())
      ).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2818),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Text('Pilih Surah',
                    style: GoogleFonts.dmSerifDisplay(
                        fontSize: 22, color: AppColors.textPrimary)),
                const Spacer(),
                Text('114 surah',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Search box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary),
              onChanged: _filter,
              decoration: InputDecoration(
                hintText: 'Cari nama surah, nomor, atau arti...',
                hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.textSecondary, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded,
                            color: AppColors.textSecondary, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _filter('');
                        },
                      )
                    : null,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // List surah
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Text('Surah tidak ditemukan',
                        style: TextStyle(color: AppColors.textSecondary)))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                    itemCount: _filtered.length,
                    itemBuilder: (_, index) {
                      final s = _filtered[index];
                      final isSelected =
                          widget.initialValue == s.namaLatin;
                      return GestureDetector(
                        onTap: () {
                          widget.onSelected(s);
                          Navigator.pop(context);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.gold.withOpacity(0.1)
                                : Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.gold.withOpacity(0.4)
                                  : Colors.white.withOpacity(0.06),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Nomor
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.gold.withOpacity(0.2)
                                      : Colors.white.withOpacity(0.06),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text('${s.nomor}',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: isSelected
                                              ? AppColors.gold
                                              : AppColors.textSecondary,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Nama latin + arti
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s.namaLatin,
                                        style: TextStyle(
                                            color: isSelected
                                                ? AppColors.gold
                                                : AppColors.textPrimary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14)),
                                    Text(s.arti,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary)),
                                  ],
                                ),
                              ),

                              // Nama arab + jumlah ayat
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(s.nama,
                                      style: TextStyle(
                                          fontSize: 16,
                                          color: isSelected
                                              ? AppColors.gold
                                              : AppColors.textSecondary,
                                          fontFamily: 'serif')),
                                  Text('${s.jumlahAyat} ayat',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textMuted)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}