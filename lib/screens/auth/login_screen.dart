import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../utils/supabase_client.dart';
import '../admin/home_screen.dart';
import '../ustadz/home_screen.dart';
import '../orang_tua/home_screen.dart';
import '../../services/notification_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  String? _emailError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  Future<void> _login() async {
    setState(() {
      _emailError = null;
      _passwordError = null;
    });

    bool valid = true;
    if (_emailController.text.isEmpty) {
      setState(() => _emailError = 'Email tidak boleh kosong');
      valid = false;
    } else if (!_emailController.text.contains('@')) {
      setState(() => _emailError = 'Format email tidak valid');
      valid = false;
    }
    if (_passwordController.text.isEmpty) {
      setState(() => _passwordError = 'Password tidak boleh kosong');
      valid = false;
    } else if (_passwordController.text.length < 6) {
      setState(() => _passwordError = 'Password minimal 6 karakter');
      valid = false;
    }
    if (!valid) return;

    setState(() => _isLoading = true);
    try {
      final response = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (response.user != null) {
        final profile = await supabase
            .from('profiles')
            .select('role')
            .eq('id', response.user!.id)
            .single();
        if (!mounted) return;
        try {
          await NotificationService.init();
        } catch (_) {}
        final role = profile['role'];
        Widget home;
        if (role == 'admin')
          home = const AdminHomeScreen();
        else if (role == 'ustadz')
          home = const UstadzHomeScreen();
        else
          home = const OrangTuaHomeScreen();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => home),
        );
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Terjadi kesalahan, coba lagi');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    String pesan = message;
    if (message.contains('Invalid login credentials')) {
      pesan = 'Email atau password salah';
    } else if (message.contains('Email not confirmed')) {
      pesan = 'Email belum dikonfirmasi';
    } else if (message.contains('Too many requests')) {
      pesan = 'Terlalu banyak percobaan, coba lagi nanti';
    } else if (message.contains('network')) {
      pesan = 'Tidak ada koneksi internet';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(pesan)),
          ],
        ),
        backgroundColor: Colors.red.shade900,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
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
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 64),

                  // Badge arab
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.gold.withOpacity(0.4),
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '✦  بسم الله الرحمن الرحيم  ✦',
                        style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 11,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Icon
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1A5C2E), Color(0xFF0F3D1E)],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: AppColors.gold.withOpacity(0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.menu_book_rounded,
                        color: AppColors.gold,
                        size: 32,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Judul
                  Text(
                    'Hafalan\nQur\'an',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSerifDisplay(
                      fontSize: 36,
                      color: AppColors.textPrimary,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'OPTIMALISASI SETORAN SANTRI',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                      letterSpacing: 2,
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Form email
                  TextField(
                    controller: _emailController,
                    onChanged: (val) {
                      if (_emailError != null) {
                        setState(() => _emailError = null);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Alamat Email',
                      prefixIcon: const Icon(Icons.email_outlined),
                      errorText: _emailError,
                      errorStyle: TextStyle(
                        color: Colors.red.shade300,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Form password
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword, // ← tambahkan ini
                    onChanged: (val) {
                      if (_passwordError != null) {
                        setState(() => _passwordError = null);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        // ← tambahkan ini
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                      errorText: _passwordError,
                      errorStyle: TextStyle(
                        color: Colors.red.shade300,
                        fontSize: 11,
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Tombol login
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.bg,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.bg,
                              ),
                            )
                          : Text(
                              'Masuk',
                              style: GoogleFonts.dmSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  Text(
                    'Hubungi admin pesantren\nuntuk mendapatkan akun',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
