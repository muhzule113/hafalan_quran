import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppSnackbar {
  static void sukses(BuildContext context, String pesan) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_rounded,
            color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(pesan)),
      ]),
      backgroundColor: AppColors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
  }

  static void error(BuildContext context, String pesan) {
    // Terjemahkan error umum
    String msg = pesan
        .replaceAll('Exception: ', '')
        .replaceAll('Invalid login credentials', 'Email atau password salah')
        .replaceAll('Email not confirmed', 'Email belum dikonfirmasi')
        .replaceAll('User already registered', 'Email sudah terdaftar')
        .replaceAll('Password should be at least 6 characters',
            'Password minimal 6 karakter');

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline_rounded,
            color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: Colors.red.shade900,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ));
  }

  static void info(BuildContext context, String pesan) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.info_outline_rounded,
            color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(pesan)),
      ]),
      backgroundColor: AppColors.blue,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
  }
}