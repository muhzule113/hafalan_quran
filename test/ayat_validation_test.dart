import 'package:flutter_test/flutter_test.dart';
import 'package:hafalan_quran/data/surah_data.dart';
import 'package:hafalan_quran/utils/ayat_validation.dart';

void main() {
  group('validateAyatValue', () {
    test('mengikuti jumlah ayat Al-Fatihah dari data surah', () {
      final alFatihah = daftarSurah.firstWhere(
        (surah) => surah.namaLatin == 'Al-Fatihah',
      );

      expect(alFatihah.jumlahAyat, 7);
      expect(validateAyatValue('7', alFatihah.jumlahAyat), isNull);
      expect(
        validateAyatValue('8', alFatihah.jumlahAyat),
        'Ayat tidak boleh lebih dari 7',
      );
    });

    test('mengizinkan nilai kosong dan batas maksimum', () {
      expect(validateAyatValue('', 7), isNull);
      expect(validateAyatValue('7', 7), isNull);
    });

    test('menolak nilai yang melebihi jumlah ayat surah', () {
      expect(validateAyatValue('8', 7), 'Ayat tidak boleh lebih dari 7');
      expect(validateAyatValue('287', 286), 'Ayat tidak boleh lebih dari 286');
    });

    test('menandai input numerik yang tidak dapat diparsing', () {
      expect(validateAyatValue('9' * 100, 7), 'Nomor ayat tidak valid');
    });
  });

  group('AyatLimitInputFormatter', () {
    const formatter = AyatLimitInputFormatter(maxAyat: 7);

    TextEditingValue apply(String oldText, String newText) {
      return formatter.formatEditUpdate(
        TextEditingValue(text: oldText),
        TextEditingValue(text: newText),
      );
    }

    test('menerima nilai valid sampai batas maksimum', () {
      expect(apply('', '7').text, '7');
    });

    test('mempertahankan nilai lama saat input melewati batas', () {
      expect(apply('', '8').text, '');
      expect(apply('7', '78').text, '7');
    });

    test('mengizinkan penghapusan nilai', () {
      expect(apply('7', '').text, '');
    });
  });
}
