import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hafalan_quran/utils/santri_import.dart';

void main() {
  test('memetakan header dan nilai Excel ke payload santri', () {
    final result = parseSantriRows([
      [
        TextCellValue(' Nama '),
        TextCellValue('NIS'),
        TextCellValue('Kelas'),
        TextCellValue('Kamar'),
        TextCellValue('Jenis Kelamin'),
        TextCellValue('Nama Wali'),
        TextCellValue('No HP Wali'),
      ],
      [
        TextCellValue(' Ahmad '),
        IntCellValue(12345),
        TextCellValue('Tahfiz A'),
        DoubleCellValue(7),
        TextCellValue('l'),
        TextCellValue('Budi'),
        IntCellValue(812345),
      ],
    ]);

    expect(result.issues, isEmpty);
    expect(result.rows.single.data, {
      'nama': 'Ahmad',
      'nis': '12345',
      'kelas': 'Tahfiz A',
      'kamar': '7',
      'nama_wali': 'Budi',
      'no_hp_wali': '812345',
      'jenis_kelamin': 'L',
      'orang_tua_id': null,
    });
  });

  test('melaporkan header wajib yang hilang', () {
    final result = parseSantriRows([
      [TextCellValue('nama'), TextCellValue('nis')],
      [TextCellValue('Ahmad'), TextCellValue('123')],
    ]);

    expect(result.rows, isEmpty);
    expect(result.issues, hasLength(1));
    expect(result.issues.single.rowNumber, 1);
    expect(result.issues.single.message, contains('jenis_kelamin'));
  });

  test('memvalidasi nama, jenis kelamin, dan mengabaikan baris kosong', () {
    final result = parseSantriRows([
      [TextCellValue('nama'), TextCellValue('jenis_kelamin')],
      [TextCellValue(''), TextCellValue('L')],
      [TextCellValue('Siti'), TextCellValue('X')],
      [TextCellValue('Budi'), TextCellValue('')],
      [null, null],
    ]);

    expect(result.rows, isEmpty);
    expect(result.issues.map((issue) => issue.rowNumber), [2, 3, 4]);
  });

  test('mengizinkan NIS kosong', () {
    final result = parseSantriRows([
      [
        TextCellValue('nama'),
        TextCellValue('nis'),
        TextCellValue('jenis_kelamin'),
      ],
      [TextCellValue('Ali'), TextCellValue(''), TextCellValue('P')],
    ]);

    expect(result.issues, isEmpty);
    expect(result.rows.single.data['nis'], isEmpty);
  });

  test('melewati NIS duplikat dari database dan file', () {
    final parsed = parseSantriRows([
      [
        TextCellValue('nama'),
        TextCellValue('nis'),
        TextCellValue('jenis_kelamin'),
      ],
      [TextCellValue('Ahmad'), TextCellValue('100'), TextCellValue('L')],
      [TextCellValue('Siti'), TextCellValue('200'), TextCellValue('P')],
      [TextCellValue('Umar'), TextCellValue('200'), TextCellValue('L')],
      [TextCellValue('Ali'), TextCellValue(''), TextCellValue('P')],
    ]);

    final result = filterDuplicateNis(parsed, ['100']);

    expect(result.rows.map((row) => row.data['nama']), ['Siti', 'Ali']);
    expect(result.issues, hasLength(2));
    expect(result.issues.map((issue) => issue.rowNumber), [2, 4]);
    expect(
      result.issues.map((issue) => issue.message),
      everyElement(contains('NIS')),
    );
  });

  test('membuat template dengan header yang kompatibel dengan importer', () {
    final workbook = Excel.decodeBytes(buildSantriTemplate());
    final row = workbook.tables.values.first.rows.first;
    final headers = row.map((cell) {
      final value = cell?.value;
      return value is TextCellValue ? value.value.toString() : value.toString();
    }).toList();

    expect(headers, santriImportHeaders);
  });
}
