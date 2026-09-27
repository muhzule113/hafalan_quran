class SantriFilterValues {
  final String? kelas;
  final String? kamar;
  final String? jenisKelamin;

  const SantriFilterValues({this.kelas, this.kamar, this.jenisKelamin});

  bool get isActive => [
    kelas,
    kamar,
    jenisKelamin,
  ].any((value) => value?.trim().isNotEmpty == true);
}

List<Map<String, dynamic>> filterAdminRecords(
  List<Map<String, dynamic>> records,
  String query, {
  required Iterable<String?> Function(Map<String, dynamic> record)
  getSearchFields,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) return records;

  return records
      .where(
        (record) => getSearchFields(record).any(
          (field) => field?.toLowerCase().contains(normalizedQuery) ?? false,
        ),
      )
      .toList();
}

List<Map<String, dynamic>> filterSantriRecords(
  List<Map<String, dynamic>> records,
  String query, {
  required Iterable<String?> Function(Map<String, dynamic> record)
  getSearchFields,
  SantriFilterValues filters = const SantriFilterValues(),
}) {
  final searchResults = filterAdminRecords(
    records,
    query,
    getSearchFields: getSearchFields,
  );

  if (!filters.isActive) return searchResults;

  return searchResults
      .where(
        (record) =>
            _matchesFilter(record['kelas'], filters.kelas) &&
            _matchesFilter(record['kamar'], filters.kamar) &&
            _matchesFilter(record['jenis_kelamin'], filters.jenisKelamin),
      )
      .toList();
}

List<Map<String, dynamic>> filterAssignedSantri(
  List<Map<String, dynamic>> records,
  String ustadzId,
) {
  return records
      .where((record) => record['ustadz_id']?.toString() == ustadzId)
      .toList();
}

List<Map<String, dynamic>> filterUnassignedSantri(
  List<Map<String, dynamic>> records,
) {
  return records
      .where((record) => (record['ustadz_id']?.toString().trim() ?? '').isEmpty)
      .toList();
}

List<Map<String, dynamic>> applyClassAssignment(
  List<Map<String, dynamic>> records,
  String kelas,
  String? ustadzId,
) {
  final normalizedKelas = kelas.trim().toLowerCase();
  return records.map((record) {
    final recordKelas = record['kelas']?.toString().trim().toLowerCase();
    if (recordKelas != normalizedKelas) return record;
    return {...record, 'ustadz_id': ustadzId};
  }).toList();
}

bool _matchesFilter(dynamic value, String? selectedValue) {
  if (selectedValue == null || selectedValue.trim().isEmpty) return true;

  return value?.toString().trim().toLowerCase() ==
      selectedValue.trim().toLowerCase();
}
