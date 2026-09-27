import 'package:excel/excel.dart';

const santriImportHeaders = <String>[
  'nama',
  'nis',
  'kelas',
  'kamar',
  'jenis_kelamin',
  'nama_wali',
  'no_hp_wali',
];

const _requiredHeaders = {'nama', 'jenis_kelamin'};

class SantriImportIssue {
  const SantriImportIssue({required this.rowNumber, required this.message});

  final int rowNumber;
  final String message;
}

class SantriImportRow {
  const SantriImportRow({required this.rowNumber, required this.data});

  final int rowNumber;
  final Map<String, dynamic> data;
}

class SantriImportResult {
  const SantriImportResult({required this.rows, required this.issues});

  final List<SantriImportRow> rows;
  final List<SantriImportIssue> issues;
}

SantriImportResult parseSantriRows(Iterable<Iterable<CellValue?>> sourceRows) {
  final rows = sourceRows.map((row) => List<CellValue?>.from(row)).toList();
  if (rows.isEmpty) {
    return const SantriImportResult(
      rows: [],
      issues: [
        SantriImportIssue(
          rowNumber: 1,
          message: 'File Excel tidak memiliki header.',
        ),
      ],
    );
  }

  final columnIndexes = <String, int>{};
  for (var index = 0; index < rows.first.length; index++) {
    final header = _normalizeHeader(rows.first[index]);
    if (header.isEmpty || !santriImportHeaders.contains(header)) continue;
    if (columnIndexes.containsKey(header)) {
      return SantriImportResult(
        rows: const [],
        issues: [
          SantriImportIssue(
            rowNumber: 1,
            message: 'Kolom "$header" muncul lebih dari sekali.',
          ),
        ],
      );
    }
    columnIndexes[header] = index;
  }

  final missingHeaders = _requiredHeaders
      .where((header) => !columnIndexes.containsKey(header))
      .toList();
  if (missingHeaders.isNotEmpty) {
    return SantriImportResult(
      rows: const [],
      issues: [
        SantriImportIssue(
          rowNumber: 1,
          message: 'Kolom wajib tidak ditemukan: ${missingHeaders.join(', ')}.',
        ),
      ],
    );
  }

  final parsedRows = <SantriImportRow>[];
  final issues = <SantriImportIssue>[];

  for (var index = 1; index < rows.length; index++) {
    final row = rows[index];
    final values = <String, String>{
      for (final header in santriImportHeaders)
        header: _valueAt(row, columnIndexes[header]),
    };

    if (values.values.every((value) => value.isEmpty)) continue;

    final rowNumber = index + 1;
    final nama = values['nama']!;
    final jenisKelamin = values['jenis_kelamin']!.toUpperCase();

    if (nama.isEmpty) {
      issues.add(
        SantriImportIssue(rowNumber: rowNumber, message: 'Nama wajib diisi.'),
      );
      continue;
    }

    if (jenisKelamin != 'L' && jenisKelamin != 'P') {
      issues.add(
        SantriImportIssue(
          rowNumber: rowNumber,
          message: 'Jenis kelamin harus L atau P.',
        ),
      );
      continue;
    }

    parsedRows.add(
      SantriImportRow(
        rowNumber: rowNumber,
        data: {
          'nama': nama,
          'nis': values['nis'],
          'kelas': values['kelas'],
          'kamar': values['kamar'],
          'nama_wali': values['nama_wali'],
          'no_hp_wali': values['no_hp_wali'],
          'jenis_kelamin': jenisKelamin,
          'orang_tua_id': null,
        },
      ),
    );
  }

  return SantriImportResult(rows: parsedRows, issues: issues);
}

SantriImportResult filterDuplicateNis(
  SantriImportResult result,
  Iterable<String?> existingNis,
) {
  final seenNis = existingNis
      .map((nis) => nis?.trim() ?? '')
      .where((nis) => nis.isNotEmpty)
      .toSet();
  final rows = <SantriImportRow>[];
  final issues = [...result.issues];

  for (final row in result.rows) {
    final nis = (row.data['nis']?.toString() ?? '').trim();
    if (nis.isNotEmpty && !seenNis.add(nis)) {
      issues.add(
        SantriImportIssue(
          rowNumber: row.rowNumber,
          message: 'NIS "$nis" sudah terdaftar atau duplikat.',
        ),
      );
      continue;
    }
    rows.add(row);
  }

  return SantriImportResult(rows: rows, issues: issues);
}

List<int> buildSantriTemplate() {
  final workbook = Excel.createExcel();
  final sheetName = workbook.getDefaultSheet();
  if (sheetName == null) {
    throw StateError('Template Excel tidak memiliki sheet.');
  }

  workbook[sheetName].appendRow(
    santriImportHeaders.map((header) => TextCellValue(header)).toList(),
  );

  return workbook.save(fileName: 'template_santri.xlsx') ??
      (throw StateError('Template Excel gagal dibuat.'));
}

String _normalizeHeader(CellValue? value) {
  return _cellToText(value)
      .replaceFirst('\uFEFF', '')
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\s-]+'), '_');
}

String _valueAt(List<CellValue?> row, int? index) {
  if (index == null || index >= row.length) return '';
  return _cellToText(row[index]).trim();
}

String _cellToText(CellValue? value) {
  if (value == null) return '';
  if (value is TextCellValue) return value.value.toString();
  if (value is IntCellValue) return value.value.toString();
  if (value is DoubleCellValue) {
    final number = value.value;
    return number == number.truncateToDouble()
        ? number.toInt().toString()
        : number.toString();
  }
  if (value is BoolCellValue) return value.value.toString();
  return value.toString();
}
