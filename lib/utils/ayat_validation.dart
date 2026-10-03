import 'package:flutter/services.dart';

String? validateAyatValue(String rawValue, int maxAyat) {
  if (rawValue.isEmpty) return null;

  final value = int.tryParse(rawValue);
  if (value == null) return 'Nomor ayat tidak valid';
  if (value > maxAyat) return 'Ayat tidak boleh lebih dari $maxAyat';

  return null;
}

class AyatLimitInputFormatter extends TextInputFormatter {
  final int maxAyat;

  const AyatLimitInputFormatter({required this.maxAyat});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty ||
        validateAyatValue(newValue.text, maxAyat) == null) {
      return newValue;
    }

    return oldValue;
  }
}
