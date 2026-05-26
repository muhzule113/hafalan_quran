import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import '../../theme/app_theme.dart';
import '../../utils/supabase_client.dart';

class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;

  late TextEditingController _namaController;
  late TextEditingController _noHpController;
  final _passwordBaruController = TextEditingController();
  final _konfirmasiPasswordController = TextEditingController();
  bool _obscurePasswordBaru = true;
  bool _obscureKonfirmasi = true;
  bool _showGantiPassword = false;

  @override
  void initState() {
    super.initState();
    _namaController = TextEditingController();
    _noHpController = TextEditingController();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      final data = await supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      if (mounted) {
        setState(() {
          _profile = data;
          _namaController.text = data['nama'] ?? '';
          _noHpController.text = data['no_hp'] ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadFoto() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      // Validasi ukuran
      final fileSize = result.files.single.size;
      final fileSizeMB = fileSize / (1024 * 1024);
      if (fileSize > 1 * 1024 * 1024) {
        await FilePicker.platform.clearTemporaryFiles(); // ← hapus temp
        _showSnack(
          'Ukuran foto maksimal 1MB (${fileSizeMB.toStringAsFixed(1)}MB).',
        );
        return;
      }

      setState(() => _isUploadingPhoto = true);

      final userId = supabase.auth.currentUser!.id;
      final bytes = result.files.single.bytes!;
      final ext = result.files.single.extension?.toLowerCase() ?? 'jpg';
      final fileName = 'foto/$userId.$ext';

      await supabase.storage
          .from('profil-foto')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(upsert: true),
          );

      final baseUrl = supabase.storage
          .from('profil-foto')
          .getPublicUrl(fileName);
      final url = '$baseUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      await supabase
          .from('profiles')
          .update({'foto_url': url})
          .eq('id', userId);

      await FilePicker.platform.clearTemporaryFiles(); // ← hapus temp
      await _loadProfile();
      _showSnack('Foto profil diperbarui', isSuccess: true);
    } catch (e) {
      await FilePicker.platform.clearTemporaryFiles(); // ← hapus temp
      _showSnack('Gagal: $e');
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _simpanProfil() async {
    if (_namaController.text.isEmpty) {
      _showSnack('Nama tidak boleh kosong');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      await supabase
          .from('profiles')
          .update({
            'nama': _namaController.text.trim(),
            'no_hp': _noHpController.text.trim(),
          })
          .eq('id', userId);

      _showSnack('Profil berhasil diperbarui', isSuccess: true);
    } catch (e) {
      _showSnack('Gagal simpan: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _gantiPassword() async {
    if (_passwordBaruController.text.isEmpty) {
      _showSnack('Password baru tidak boleh kosong');
      return;
    }
    if (_passwordBaruController.text.length < 6) {
      _showSnack('Password minimal 6 karakter');
      return;
    }
    if (_passwordBaruController.text != _konfirmasiPasswordController.text) {
      _showSnack('Konfirmasi password tidak cocok');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await supabase.auth.updateUser(
        UserAttributes(password: _passwordBaruController.text),
      );
      _passwordBaruController.clear();
      _konfirmasiPasswordController.clear();
      setState(() => _showGantiPassword = false);
      _showSnack('Password berhasil diubah', isSuccess: true);
    } catch (e) {
      _showSnack('Gagal ganti password: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess
                  ? Icons.check_circle_rounded
                  : Icons.error_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: isSuccess ? AppColors.green : Colors.red.shade900,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _roleLabel(String? role) {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'ustadz':
        return 'Ustadz';
      case 'orang_tua':
        return 'Orang Tua';
      default:
        return 'User';
    }
  }

  Color _roleColor(String? role) {
    switch (role) {
      case 'admin':
        return AppColors.gold;
      case 'ustadz':
        return Colors.lightBlue;
      case 'orang_tua':
        return Colors.purpleAccent;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
    _noHpController.dispose();
    _passwordBaruController.dispose();
    _konfirmasiPasswordController.dispose();
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
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.08),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: AppColors.textPrimary,
                                  size: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'Profil Saya',
                              style: GoogleFonts.dmSerifDisplay(
                                fontSize: 24,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Foto profil
                      Center(
                        child: Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.gold.withOpacity(0.4),
                                  width: 2,
                                ),
                              ),
                              child: ClipOval(
                                child: _profile?['foto_url'] != null
                                    ? Image.network(
                                        _profile!['foto_url'],
                                        fit: BoxFit.cover,
                                        // Tambahkan ini:
                                        key: ValueKey(_profile!['foto_url']),
                                        headers: const {
                                          'Cache-Control': 'no-cache',
                                        },
                                        errorBuilder: (_, __, ___) =>
                                            _avatarDefault(),
                                      )
                                    : _avatarDefault(),
                              ),
                            ),
                            // Loading overlay
                            if (_isUploadingPhoto)
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black.withOpacity(0.5),
                                ),
                                child: const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.gold,
                                    ),
                                  ),
                                ),
                              ),
                            // Tombol ganti foto
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () {
                                  print(
                                    'DEBUG: tombol kamera ditap',
                                  ); // ← tambahkan ini
                                  if (!_isUploadingPhoto) _uploadFoto();
                                },
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: AppColors.gold,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF0D2818),
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    color: AppColors.bg,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Nama & role
                      Text(
                        _profile?['nama'] ?? 'User',
                        style: GoogleFonts.dmSerifDisplay(
                          fontSize: 22,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _roleColor(
                            _profile?['role'],
                          ).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _roleColor(
                              _profile?['role'],
                            ).withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          _roleLabel(_profile?['role']).toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            color: _roleColor(_profile?['role']),
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Email
                      Text(
                        supabase.auth.currentUser?.email ?? '',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Form edit profil
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Section data pribadi
                            _SectionLabel(label: 'DATA PRIBADI'),
                            const SizedBox(height: 14),

                            TextField(
                              controller: _namaController,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Nama Lengkap',
                                prefixIcon: Icon(
                                  Icons.person_outlined,
                                  color: AppColors.textSecondary,
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            TextField(
                              controller: _noHpController,
                              keyboardType: TextInputType.phone,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'No. HP',
                                prefixIcon: Icon(
                                  Icons.phone_outlined,
                                  color: AppColors.textSecondary,
                                  size: 20,
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Tombol simpan profil
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _simpanProfil,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.gold,
                                  foregroundColor: AppColors.bg,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isSaving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.bg,
                                        ),
                                      )
                                    : Text(
                                        'Simpan Profil',
                                        style: GoogleFonts.dmSans(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Section ganti password
                            _SectionLabel(label: 'KEAMANAN AKUN'),
                            const SizedBox(height: 14),

                            // Toggle ganti password
                            GestureDetector(
                              onTap: () => setState(
                                () => _showGantiPassword = !_showGantiPassword,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: _showGantiPassword
                                      ? Colors.orange.withOpacity(0.08)
                                      : Colors.white.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _showGantiPassword
                                        ? Colors.orange.withOpacity(0.3)
                                        : Colors.white.withOpacity(0.08),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: _showGantiPassword
                                            ? Colors.orange.withOpacity(0.15)
                                            : Colors.white.withOpacity(0.06),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.lock_reset_rounded,
                                        color: _showGantiPassword
                                            ? Colors.orange
                                            : AppColors.textSecondary,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Ganti Password',
                                            style: TextStyle(
                                              color: _showGantiPassword
                                                  ? Colors.orange
                                                  : AppColors.textPrimary,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            'Ubah password akun kamu',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      _showGantiPassword
                                          ? Icons.keyboard_arrow_up_rounded
                                          : Icons.keyboard_arrow_down_rounded,
                                      color: AppColors.textSecondary,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Form ganti password
                            if (_showGantiPassword) ...[
                              const SizedBox(height: 12),
                              TextField(
                                controller: _passwordBaruController,
                                obscureText: _obscurePasswordBaru,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Password Baru',
                                  prefixIcon: const Icon(
                                    Icons.lock_outlined,
                                    color: AppColors.textSecondary,
                                    size: 20,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePasswordBaru
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: AppColors.textSecondary,
                                      size: 18,
                                    ),
                                    onPressed: () => setState(
                                      () => _obscurePasswordBaru =
                                          !_obscurePasswordBaru,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _konfirmasiPasswordController,
                                obscureText: _obscureKonfirmasi,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Konfirmasi Password Baru',
                                  prefixIcon: const Icon(
                                    Icons.lock_outlined,
                                    color: AppColors.textSecondary,
                                    size: 20,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureKonfirmasi
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: AppColors.textSecondary,
                                      size: 18,
                                    ),
                                    onPressed: () => setState(
                                      () => _obscureKonfirmasi =
                                          !_obscureKonfirmasi,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _isSaving ? null : _gantiPassword,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange.shade800,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _isSaving
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          'Simpan Password Baru',
                                          style: GoogleFonts.dmSans(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _avatarDefault() {
    return Container(
      color: AppColors.green.withOpacity(0.2),
      child: Center(
        child: Text(
          (_profile?['nama'] ?? 'U')[0].toUpperCase(),
          style: GoogleFonts.dmSerifDisplay(
            fontSize: 36,
            color: AppColors.greenLight,
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: AppColors.gold,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
