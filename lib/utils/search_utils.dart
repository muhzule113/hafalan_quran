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
