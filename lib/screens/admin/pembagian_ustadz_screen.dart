import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../../utils/search_utils.dart';
import '../../utils/supabase_client.dart';

const _allFilterValue = '__all__';
const _unassignedFilterValue = '__unassigned__';

class PembagianUstadzScreen extends StatefulWidget {
  const PembagianUstadzScreen({super.key});

  @override
  State<PembagianUstadzScreen> createState() => _PembagianUstadzScreenState();
}

class _PembagianUstadzScreenState extends State<PembagianUstadzScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _santriList = [];
  List<Map<String, dynamic>> _ustadzList = [];
  String _searchQuery = '';
  String _kelasFilter = _allFilterValue;
  String _assignmentFilter = _allFilterValue;
  String? _bulkTarget;
  String? _savingStudentId;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final result = await Future.wait([
        supabase
            .from('santri')
            .select('id, nama, kelas, kamar, ustadz_id')
            .eq('aktif', true)
            .order('nama'),
        supabase
            .from('profiles')
            .select('id, nama')
            .eq('role', 'ustadz')
            .order('nama'),
      ]);
      final santri = List<Map<String, dynamic>>.from(result[0] as List);
      final ustadz = List<Map<String, dynamic>>.from(result[1] as List);
      final kelasOptions = _kelasOptionsFor(santri);

      if (!mounted) return;
      setState(() {
        _santriList = santri;
        _ustadzList = ustadz;
        _isLoading = false;
        if (_kelasFilter != _allFilterValue &&
            !kelasOptions.contains(_kelasFilter)) {
          _kelasFilter = _allFilterValue;
        }
        if (_assignmentFilter != _allFilterValue &&
            _assignmentFilter != _unassignedFilterValue &&
            !ustadz.any(
              (item) => item['id']?.toString() == _assignmentFilter,
            )) {
          _assignmentFilter = _allFilterValue;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  List<String> _kelasOptionsFor(List<Map<String, dynamic>> records) {
    final values = records
        .map((record) => record['kelas']?.toString().trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    values.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }

  List<String> get _kelasOptions => _kelasOptionsFor(_santriList);

  List<Map<String, dynamic>> get _visibleSantri {
    final filtered = filterSantriRecords(
      _santriList,
      _searchQuery,
      filters: SantriFilterValues(
        kelas: _kelasFilter == _allFilterValue ? null : _kelasFilter,
      ),
      getSearchFields: (santri) => [
        santri['nama']?.toString(),
        santri['kelas']?.toString(),
        santri['kamar']?.toString(),
        _ustadzName(santri['ustadz_id']?.toString()),
      ],
    );

    if (_assignmentFilter == _unassignedFilterValue) {
      return filterUnassignedSantri(filtered);
    }
    if (_assignmentFilter != _allFilterValue) {
      return filterAssignedSantri(filtered, _assignmentFilter);
    }
    return filtered;
  }

  List<Map<String, dynamic>> get _selectedClassSantri {
    if (_kelasFilter == _allFilterValue) return [];
    return _santriList
        .where(
          (santri) =>
              santri['kelas']?.toString().trim().toLowerCase() ==
              _kelasFilter.trim().toLowerCase(),
        )
        .toList();
  }

  String _ustadzName(String? id) {
    if (id == null || id.isEmpty) return 'Belum dibagi';
    for (final ustadz in _ustadzList) {
      if (ustadz['id']?.toString() == id) {
        return ustadz['nama']?.toString() ?? 'Ustadz';
      }
    }
    return 'Ustadz tidak tersedia';
  }

  String _assignmentValue(dynamic ustadzId) {
    final id = ustadzId?.toString();
    if (id == null || id.isEmpty) return _unassignedFilterValue;
    if (_ustadzList.any((ustadz) => ustadz['id']?.toString() == id)) {
      return id;
    }
    return _unassignedFilterValue;
  }

  Future<void> _updateAssignment(String santriId, String? ustadzId) async {
    setState(() => _savingStudentId = santriId);
    try {
      await supabase
          .from('santri')
          .update({'ustadz_id': ustadzId})
          .eq('id', santriId);

      if (!mounted) return;
      final index = _santriList.indexWhere(
        (santri) => santri['id'] == santriId,
      );
      if (index >= 0) {
        setState(() {
          _santriList[index] = {..._santriList[index], 'ustadz_id': ustadzId};
        });
      }
      _showSnack(
        ustadzId == null
            ? 'Santri dikembalikan menjadi belum dibagi'
            : 'Assignment ustadz diperbarui',
        isSuccess: true,
      );
    } catch (error) {
      if (mounted) {
        _showSnack('Gagal memperbarui assignment: $error');
      }
    } finally {
      if (mounted) setState(() => _savingStudentId = null);
    }
  }

  Future<void> _applyBulkAssignment() async {
    if (_kelasFilter == _allFilterValue || _bulkTarget == null) {
      _showSnack('Pilih kelas dan ustadz terlebih dahulu');
      return;
    }

    final selectedKelas = _kelasFilter;
    final selectedCount = _selectedClassSantri.length;
    if (selectedCount == 0) {
      _showSnack('Tidak ada santri aktif pada kelas ini');
      return;
    }

    final targetId = _bulkTarget == _unassignedFilterValue ? null : _bulkTarget;
    final targetName = targetId == null
        ? 'Belum dibagi'
        : _ustadzName(targetId);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Text(
          'Terapkan Assignment',
          style: GoogleFonts.dmSerifDisplay(color: AppColors.textPrimary),
        ),
        content: Text(
          'Tetapkan $selectedCount santri kelas $selectedKelas kepada $targetName? Assignment ustadz lama akan ditimpa.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Terapkan'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() => _isSaving = true);

    try {
      await supabase
          .from('santri')
          .update({'ustadz_id': targetId})
          .eq('aktif', true)
          .eq('kelas', selectedKelas);

      if (!mounted) return;
      setState(() {
        _santriList = applyClassAssignment(
          _santriList,
          selectedKelas,
          targetId,
        );
      });
      _showSnack(
        '$selectedCount santri berhasil dibagi ke $targetName',
        isSuccess: true,
      );
    } catch (error) {
      if (mounted) _showSnack('Gagal menerapkan assignment: $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? AppColors.green : Colors.red.shade900,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
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
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: AppColors.textPrimary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pembagian Santri',
                            style: GoogleFonts.dmSerifDisplay(
                              fontSize: 24,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Atur ustadz penerima setoran',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${_santriList.length} santri',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Cari santri atau ustadz...',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.textSecondary,
                    ),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            icon: const Icon(
                              Icons.clear_rounded,
                              color: AppColors.textSecondary,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _kelasFilter,
                        isExpanded: true,
                        dropdownColor: AppColors.bgCard,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(labelText: 'Kelas'),
                        items: [
                          const DropdownMenuItem(
                            value: _allFilterValue,
                            child: Text('Semua kelas'),
                          ),
                          ..._kelasOptions.map(
                            (kelas) => DropdownMenuItem(
                              value: kelas,
                              child: Text(kelas),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _kelasFilter = value;
                            _bulkTarget = null;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _assignmentFilter,
                        isExpanded: true,
                        dropdownColor: AppColors.bgCard,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(labelText: 'Ustadz'),
                        items: [
                          const DropdownMenuItem(
                            value: _allFilterValue,
                            child: Text('Semua ustadz'),
                          ),
                          const DropdownMenuItem(
                            value: _unassignedFilterValue,
                            child: Text('Belum dibagi'),
                          ),
                          ..._ustadzList.map(
                            (ustadz) => DropdownMenuItem(
                              value: ustadz['id'].toString(),
                              child: Text(ustadz['nama']?.toString() ?? '-'),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _assignmentFilter = value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              if (_kelasFilter != _allFilterValue) ...[
                const SizedBox(height: 12),
                _BulkAssignmentCard(
                  selectedKelas: _kelasFilter,
                  studentCount: _selectedClassSantri.length,
                  ustadzList: _ustadzList,
                  target: _bulkTarget,
                  isSaving: _isSaving,
                  onTargetChanged: (value) =>
                      setState(() => _bulkTarget = value),
                  onApply: _applyBulkAssignment,
                ),
              ],
              const SizedBox(height: 12),
              Expanded(child: _buildList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      );
    }
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Gagal memuat data assignment',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _loadData,
              child: const Text('Coba lagi'),
            ),
          ],
        ),
      );
    }

    final santri = _visibleSantri;
    if (santri.isEmpty) {
      return Center(
        child: Text(
          'Santri tidak ditemukan',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.bgCard,
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        itemCount: santri.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, index) => _SantriAssignmentTile(
          santri: santri[index],
          ustadzList: _ustadzList,
          saving: _savingStudentId == santri[index]['id'] || _isSaving,
          assignmentValue: _assignmentValue(santri[index]['ustadz_id']),
          onChanged: (value) => _updateAssignment(
            santri[index]['id'].toString(),
            value == _unassignedFilterValue ? null : value,
          ),
        ),
      ),
    );
  }
}

class _BulkAssignmentCard extends StatelessWidget {
  final String selectedKelas;
  final int studentCount;
  final List<Map<String, dynamic>> ustadzList;
  final String? target;
  final bool isSaving;
  final ValueChanged<String?> onTargetChanged;
  final VoidCallback onApply;

  const _BulkAssignmentCard({
    required this.selectedKelas,
    required this.studentCount,
    required this.ustadzList,
    required this.target,
    required this.isSaving,
    required this.onTargetChanged,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'ATUR PER KELAS',
            style: TextStyle(
              color: AppColors.gold,
              fontSize: 10,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$studentCount santri · $selectedKelas',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: target,
            isExpanded: true,
            dropdownColor: AppColors.bgCard,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(labelText: 'Tetapkan kepada'),
            hint: const Text('Pilih ustadz'),
            items: [
              ...ustadzList.map(
                (ustadz) => DropdownMenuItem(
                  value: ustadz['id'].toString(),
                  child: Text(ustadz['nama']?.toString() ?? '-'),
                ),
              ),
              const DropdownMenuItem(
                value: _unassignedFilterValue,
                child: Text('Belum dibagi'),
              ),
            ],
            onChanged: isSaving ? null : onTargetChanged,
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: isSaving || target == null ? null : onApply,
            icon: const Icon(Icons.group_add_rounded, size: 18),
            label: const Text('Terapkan ke kelas'),
          ),
        ],
      ),
    );
  }
}

class _SantriAssignmentTile extends StatelessWidget {
  final Map<String, dynamic> santri;
  final List<Map<String, dynamic>> ustadzList;
  final bool saving;
  final String assignmentValue;
  final ValueChanged<String?> onChanged;

  const _SantriAssignmentTile({
    required this.santri,
    required this.ustadzList,
    required this.saving,
    required this.assignmentValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Text(
              (santri['nama']?.toString().trim().isNotEmpty == true
                      ? santri['nama'].toString().trim()[0]
                      : '?')
                  .toUpperCase(),
              style: GoogleFonts.dmSerifDisplay(
                fontSize: 18,
                color: AppColors.greenLight,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  santri['nama']?.toString() ?? '-',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${santri['kelas'] ?? '-'} · ${santri['kamar'] ?? '-'}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 145,
            child: saving
                ? const Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.gold,
                      ),
                    ),
                  )
                : DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: assignmentValue,
                      isExpanded: true,
                      dropdownColor: AppColors.bgCard,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 11,
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: _unassignedFilterValue,
                          child: Text('Belum dibagi'),
                        ),
                        ...ustadzList.map(
                          (ustadz) => DropdownMenuItem(
                            value: ustadz['id'].toString(),
                            child: Text(
                              ustadz['nama']?.toString() ?? '-',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: onChanged,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
