import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/search_utils.dart';

class SantriFilterButton extends StatelessWidget {
  final List<Map<String, dynamic>> santriList;
  final SantriFilterValues filters;
  final ValueChanged<SantriFilterValues> onChanged;

  const SantriFilterButton({
    super.key,
    required this.santriList,
    required this.filters,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: filters.isActive
              ? AppColors.gold.withOpacity(0.15)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: filters.isActive
                ? AppColors.gold.withOpacity(0.55)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              tooltip: 'Filter santri',
              onPressed: () async {
                final result = await showSantriFilterSheet(
                  context,
                  santriList: santriList,
                  initial: filters,
                );
                if (result != null) onChanged(result);
              },
              icon: Icon(
                Icons.filter_list_rounded,
                color: filters.isActive
                    ? AppColors.goldLight
                    : AppColors.textSecondary,
                size: 21,
              ),
            ),
            if (filters.isActive)
              Positioned(
                top: -6,
                right: -4,
                child: Container(
                  width: 17,
                  height: 17,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.gold,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${[filters.kelas, filters.kamar, filters.jenisKelamin].where((value) => value?.trim().isNotEmpty == true).length}',
                    style: const TextStyle(
                      color: AppColors.bgDark,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
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

Future<SantriFilterValues?> showSantriFilterSheet(
  BuildContext context, {
  required List<Map<String, dynamic>> santriList,
  SantriFilterValues initial = const SantriFilterValues(),
}) {
  final kelasOptions = _uniqueValues(santriList, 'kelas');
  final kamarOptions = _uniqueValues(santriList, 'kamar');

  return showModalBottomSheet<SantriFilterValues>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _SantriFilterSheet(
      kelasOptions: kelasOptions,
      kamarOptions: kamarOptions,
      initial: initial,
    ),
  );
}

class _SantriFilterSheet extends StatefulWidget {
  final List<String> kelasOptions;
  final List<String> kamarOptions;
  final SantriFilterValues initial;

  const _SantriFilterSheet({
    required this.kelasOptions,
    required this.kamarOptions,
    required this.initial,
  });

  @override
  State<_SantriFilterSheet> createState() => _SantriFilterSheetState();
}

class _SantriFilterSheetState extends State<_SantriFilterSheet> {
  late String _kelas;
  late String _kamar;
  late String _jenisKelamin;

  @override
  void initState() {
    super.initState();
    _kelas = _validInitial(widget.initial.kelas, widget.kelasOptions);
    _kamar = _validInitial(widget.initial.kamar, widget.kamarOptions);
    _jenisKelamin = _validInitial(widget.initial.jenisKelamin, const [
      'L',
      'P',
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          decoration: const BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Filter Santri',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              _dropdown(
                label: 'Kelas',
                emptyLabel: 'Semua kelas',
                value: _kelas,
                options: widget.kelasOptions,
                onChanged: (value) => setState(() => _kelas = value ?? ''),
              ),
              const SizedBox(height: 12),
              _dropdown(
                label: 'Kamar',
                emptyLabel: 'Semua kamar',
                value: _kamar,
                options: widget.kamarOptions,
                onChanged: (value) => setState(() => _kamar = value ?? ''),
              ),
              const SizedBox(height: 12),
              _dropdown(
                label: 'Jenis kelamin',
                emptyLabel: 'Semua jenis kelamin',
                value: _jenisKelamin,
                options: const ['L', 'P'],
                optionLabels: const {'L': 'Laki-laki', 'P': 'Perempuan'},
                onChanged: (value) =>
                    setState(() => _jenisKelamin = value ?? ''),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.pop(context, const SantriFilterValues()),
                      child: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(
                        context,
                        SantriFilterValues(
                          kelas: _kelas.isEmpty ? null : _kelas,
                          kamar: _kamar.isEmpty ? null : _kamar,
                          jenisKelamin: _jenisKelamin.isEmpty
                              ? null
                              : _jenisKelamin,
                        ),
                      ),
                      child: const Text('Terapkan'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String emptyLabel,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
    Map<String, String> optionLabels = const {},
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      dropdownColor: AppColors.bgCard,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(labelText: label),
      items: [
        DropdownMenuItem(value: '', child: Text(emptyLabel)),
        ...options.map(
          (option) => DropdownMenuItem(
            value: option,
            child: Text(optionLabels[option] ?? option),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

String _validInitial(String? value, List<String> options) {
  return value != null && options.contains(value) ? value : '';
}

List<String> _uniqueValues(List<Map<String, dynamic>> records, String field) {
  final values = records
      .map((record) => record[field]?.toString().trim() ?? '')
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList();
  values.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return values;
}
