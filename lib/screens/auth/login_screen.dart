import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloudflare_turnstile/cloudflare_turnstile.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../utils/supabase_client.dart';
import '../admin/home_screen.dart';
import '../ustadz/home_screen.dart';
import '../orang_tua/home_screen.dart';
import '../../services/notification_service.dart';

typedef CaptchaTokenProvider = Future<String?> Function();

class CaptchaChallenge {
  const CaptchaChallenge({required this.id, required this.svg});

  final String id;
  final String svg;
}

class TurnstileTokenCache {
  String? _token;

  void store(String token) {
    final normalizedToken = token.trim();
    _token = normalizedToken.isEmpty ? null : normalizedToken;
  }

  String? take() {
    final token = _token;
    _token = null;
    return token;
  }

  void clear() => _token = null;
}

typedef CaptchaChallengeProvider = Future<CaptchaChallenge> Function();

typedef CaptchaVerifier =
    Future<bool> Function({
      required String challengeId,
      required String answer,
    });

typedef PasswordSignIn =
    Future<AuthResponse> Function({
      required String email,
      required String password,
      required String captchaToken,
    });

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.captchaChallengeProvider,
    this.captchaVerifier,
    this.captchaTokenProvider,
    this.signInWithPassword,
  });

  final CaptchaChallengeProvider? captchaChallengeProvider;
  final CaptchaVerifier? captchaVerifier;
  final CaptchaTokenProvider? captchaTokenProvider;
  final PasswordSignIn? signInWithPassword;

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
  String? _captchaInputError;
  String? _captchaLoadError;
  bool _isCaptchaLoading = false;
  CaptchaChallenge? _captchaChallenge;
  final _captchaAnswerController = TextEditingController();
  CloudflareTurnstile? _invisibleTurnstile;
  Completer<String?>? _captchaCompleter;
  final _turnstileTokenCache = TurnstileTokenCache();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();

    if (_shouldRenderCaptcha) {
      _initializeInvisibleTurnstile();
      unawaited(_loadCaptchaChallenge());
    }
  }

  Future<void> _login() async {
    if (_isLoading) return;

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

    if (widget.captchaTokenProvider == null && !_isCaptchaConfigured) {
      _showError('Verifikasi keamanan belum dikonfigurasi');
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_shouldRenderCaptcha) {
        final challenge = _captchaChallenge;
        final answer = _captchaAnswerController.text.trim();
        if (challenge == null || _isCaptchaLoading) {
          _showError('CAPTCHA belum siap, coba lagi');
          return;
        }
        if (answer.isEmpty) {
          setState(
            () =>
                _captchaInputError = 'Masukkan kode CAPTCHA tidak boleh kosong',
          );
          return;
        }

        bool captchaValid;
        try {
          captchaValid = await (widget.captchaVerifier ?? _verifyCaptcha)(
            challengeId: challenge.id,
            answer: answer,
          );
        } catch (_) {
          if (!mounted) return;
          _showError('Verifikasi keamanan gagal, coba lagi');
          unawaited(_loadCaptchaChallenge());
          return;
        }
        if (!mounted) return;
        if (!captchaValid) {
          setState(() => _captchaInputError = 'Kode CAPTCHA salah, coba lagi');
          unawaited(_loadCaptchaChallenge(clearInputError: false));
          return;
        }
      }

      String? captchaToken;
      try {
        captchaToken =
            await (widget.captchaTokenProvider ?? _requestTurnstileToken)();
      } catch (_) {
        if (!mounted) return;
        _showError('Verifikasi keamanan gagal, coba lagi');
        if (_shouldRenderCaptcha) unawaited(_loadCaptchaChallenge());
        return;
      }
      if (!mounted) return;
      if (captchaToken == null || captchaToken.trim().isEmpty) {
        _showError('Verifikasi keamanan gagal, coba lagi');
        if (_shouldRenderCaptcha) unawaited(_loadCaptchaChallenge());
        return;
      }

      final response = await (widget.signInWithPassword ?? _signInWithPassword)(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        captchaToken: captchaToken,
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
        if (!mounted) return;
        final role = profile['role'];
        Widget home;
        if (role == 'admin') {
          home = const AdminHomeScreen();
        } else if (role == 'ustadz') {
          home = const UstadzHomeScreen();
        } else {
          home = const OrangTuaHomeScreen();
        }
        if (role != 'orang_tua') {
          NotificationService.clearPendingSetoranId();
        }
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => home),
        );
      }
    } on AuthException catch (e) {
      _showError(e.message, code: e.code);
      if ((e.code == 'captcha_failed' ||
              e.message.toLowerCase().contains('captcha')) &&
          _shouldRenderCaptcha) {
        unawaited(_loadCaptchaChallenge());
      }
    } catch (_) {
      _showError('Terjadi kesalahan, coba lagi');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get _isCaptchaConfigured {
    if (!dotenv.isInitialized) return false;

    final siteKey = dotenv.env['TURNSTILE_SITE_KEY']?.trim();
    final baseUrl = dotenv.env['TURNSTILE_BASE_URL']?.trim();
    return siteKey?.isNotEmpty == true && baseUrl?.isNotEmpty == true;
  }

  Future<CaptchaChallenge> _createCaptchaChallenge() async {
    final response = await supabase.functions.invoke(
      'captcha-challenge',
      body: const {'action': 'create'},
    );
    final data = response.data;
    if (data is! Map) throw const FormatException('Invalid CAPTCHA response');

    final id = data['challenge_id'];
    final svg = data['svg'];
    if (id is! String || svg is! String || id.isEmpty || svg.isEmpty) {
      throw const FormatException('Invalid CAPTCHA challenge');
    }
    return CaptchaChallenge(id: id, svg: svg);
  }

  Future<bool> _verifyCaptcha({
    required String challengeId,
    required String answer,
  }) async {
    final response = await supabase.functions.invoke(
      'captcha-challenge',
      body: {'action': 'verify', 'challenge_id': challengeId, 'answer': answer},
    );
    final data = response.data;
    return data is Map && data['valid'] == true;
  }

  Future<void> _loadCaptchaChallenge({bool clearInputError = true}) async {
    if (!_shouldRenderCaptcha) return;
    if (mounted) {
      setState(() {
        _isCaptchaLoading = true;
        _captchaLoadError = null;
        _captchaChallenge = null;
        _captchaAnswerController.clear();
        if (clearInputError) _captchaInputError = null;
      });
    }

    try {
      final challenge =
          await (widget.captchaChallengeProvider ?? _createCaptchaChallenge)();
      if (!mounted) return;
      setState(() {
        _captchaChallenge = challenge;
        _isCaptchaLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isCaptchaLoading = false;
        _captchaLoadError = 'CAPTCHA gagal dimuat';
      });
    }
  }

  void _initializeInvisibleTurnstile() {
    if (widget.captchaTokenProvider != null || !_isCaptchaConfigured) return;
    if (_invisibleTurnstile != null) return;

    try {
      _invisibleTurnstile = CloudflareTurnstile.invisible(
        siteKey: dotenv.env['TURNSTILE_SITE_KEY']!.trim(),
        baseUrl: dotenv.env['TURNSTILE_BASE_URL']!.trim(),
        action: 'login',
        onTokenReceived: _handleCaptchaToken,
        onTokenExpired: _handleCaptchaExpired,
        onTimeout: _handleCaptchaTimeout,
      );
    } catch (_) {
      _invisibleTurnstile = null;
    }
  }

  Future<String?> _requestTurnstileToken() async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final token = await _requestTurnstileTokenOnce();
        if (token != null && token.trim().isNotEmpty) return token.trim();
      } catch (_) {
        // Recreate the widget below so a transient WebView/Turnstile failure
        // does not permanently poison the login screen.
      }

      _resetInvisibleTurnstile();
    }

    return null;
  }

  Future<String?> _requestTurnstileTokenOnce() async {
    final pending = _captchaCompleter;
    if (pending != null) return pending.future;

    final cachedToken = _turnstileTokenCache.take();
    if (cachedToken != null) return cachedToken;

    _initializeInvisibleTurnstile();
    final turnstile = _invisibleTurnstile;
    final widgetToken = turnstile?.token?.trim();
    if (widgetToken?.isNotEmpty == true) return widgetToken;
    if (turnstile == null) return null;

    final completer = Completer<String?>();
    _captchaCompleter = completer;

    try {
      final token = await Future.any<String?>([
        turnstile.getToken(),
        completer.future,
        Future<String?>.delayed(const Duration(seconds: 10)),
      ]);
      _turnstileTokenCache.clear();
      if (!completer.isCompleted) completer.complete(token);
    } catch (error, stackTrace) {
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
    } finally {
      if (identical(_captchaCompleter, completer)) _captchaCompleter = null;
    }

    return completer.future;
  }

  void _resetInvisibleTurnstile() {
    _turnstileTokenCache.clear();
    final turnstile = _invisibleTurnstile;
    _invisibleTurnstile = null;
    if (turnstile != null) unawaited(turnstile.dispose());
  }

  void _handleCaptchaToken(String token) {
    _turnstileTokenCache.store(token);
    final completer = _captchaCompleter;
    _captchaCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(token);
    }
  }

  void _handleCaptchaExpired() {
    _turnstileTokenCache.clear();
    final completer = _captchaCompleter;
    _captchaCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(null);
    }
  }

  void _handleCaptchaTimeout() {
    _resetInvisibleTurnstile();
    final completer = _captchaCompleter;
    _captchaCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(null);
    }
  }

  Future<AuthResponse> _signInWithPassword({
    required String email,
    required String password,
    required String captchaToken,
  }) {
    return supabase.auth.signInWithPassword(
      email: email,
      password: password,
      captchaToken: captchaToken,
    );
  }

  void _showError(String message, {String? code}) {
    String pesan = message;
    final lowerMessage = message.toLowerCase();
    if (code == 'captcha_failed' || lowerMessage.contains('captcha')) {
      pesan = 'Verifikasi keamanan gagal, coba lagi';
    } else if (message.contains('Invalid login credentials')) {
      pesan = 'Email atau password salah';
    } else if (message.contains('Email not confirmed')) {
      pesan = 'Email belum dikonfirmasi';
    } else if (message.contains('Too many requests')) {
      pesan = 'Terlalu banyak percobaan, coba lagi nanti';
    } else if (lowerMessage.contains('network')) {
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
    _captchaCompleter?.complete(null);
    _resetInvisibleTurnstile();
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _captchaAnswerController.dispose();
    super.dispose();
  }

  bool get _shouldRenderCaptcha =>
      widget.captchaChallengeProvider != null || _isCaptchaConfigured;

  Widget _buildCaptchaWidget() {
    final challenge = _captchaChallenge;
    if (_isCaptchaLoading) {
      return Container(
        height: 84,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (challenge == null) {
      return Row(
        children: [
          Expanded(
            child: Text(
              _captchaLoadError ?? 'CAPTCHA belum tersedia',
              style: TextStyle(color: Colors.red.shade300, fontSize: 12),
            ),
          ),
          IconButton(
            tooltip: 'Muat ulang CAPTCHA',
            onPressed: _isLoading ? null : _loadCaptchaChallenge,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Semantics(
                label: 'Gambar CAPTCHA',
                image: true,
                child: Container(
                  height: 84,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SvgPicture.string(challenge.svg, fit: BoxFit.fill),
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Muat ulang CAPTCHA',
              onPressed: _isLoading ? null : _loadCaptchaChallenge,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _captchaAnswerController,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          enableSuggestions: false,
          maxLength: 5,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
          ],
          style: const TextStyle(color: Colors.black87),
          onChanged: (_) {
            if (_captchaInputError != null) {
              setState(() => _captchaInputError = null);
            }
          },
          decoration: InputDecoration(
            hintText: 'Masukkan kode CAPTCHA di atas',
            errorText: _captchaInputError,
            filled: true,
            fillColor: Colors.white,
            hintStyle: const TextStyle(color: Colors.black54),
            counterText: '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
            ),
          ),
        ),
      ],
    );
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
                          color: AppColors.gold.withValues(alpha: 0.4),
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
                          color: AppColors.gold.withValues(alpha: 0.3),
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

                  if (_shouldRenderCaptcha) ...[
                    const SizedBox(height: 20),
                    _buildCaptchaWidget(),
                  ],

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
