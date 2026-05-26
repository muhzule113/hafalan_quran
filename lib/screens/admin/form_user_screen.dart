import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../utils/supabase_client.dart';

class FormUserScreen extends StatefulWidget {
  final String role;
  const FormUserScreen({super.key, required this.role});

  @override
  State<FormUserScreen> createState() => _FormUserScreenState();
}

class _FormUserScreenState extends State<FormUserScreen> {
  final _namaController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _noHpController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Untuk orang tua — pilih santri
  List<Map<String, dynamic>> _santriList = [];
  String? _selectedSantriId;

  bool get _isUstadz => widget.role == 'ustadz';
  Color get _accentColor =>
      _isUstadz ? AppColors.blue : AppColors.purple;
  String get _roleLabel => _isUstadz ? 'Ustadz' : 'Orang Tua';

  @override
  void initState() {
    super.initState();
    if (!_isUstadz) _loadSantri();
  }

  Future<void> _loadSantri() async {
    try {
      final data = await supabase
          .from('santri')
          .select('id, nama, kelas, kamar')
          .eq('aktif', true)
          .filter('orang_tua_id', 'is', null) // hanya santri yang belum punya ortu
          .order('nama');
      if (mounted) {
        setState(() {
          _santriList = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      print('Error load santri: $e');
    }
  }

  Future<void> _simpan() async {
  if (_namaController.text.isEmpty ||
      _emailController.text.isEmpty ||
      _passwordController.text.isEmpty) {
    _showSnack('Nama, email, dan password wajib diisi');
    return;
  }
  if (_passwordController.text.length < 6) {
    _showSnack('Password minimal 6 karakter');
    return;
  }

  setState(() => _isLoading = true);

  try {
    // Kirim dengan access token admin yang sedang login
    final session = supabase.auth.currentSession;
    if (session == null) throw Exception('Sesi tidak valid, silakan login ulang');

    final response = await supabase.functions.invoke(
      'buat-user',
      body: {
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        'nama': _namaController.text.trim(),
        'role': widget.role,
      },
    );

    if (response.status != 200) {
      final error = response.data['error'] ?? 'Gagal membuat akun';
      throw Exception(error);
    }

    final userId = response.data['id'] as String?;
    if (userId == null) throw Exception('Gagal mendapatkan ID user');

    // Update no_hp
    if (_noHpController.text.isNotEmpty) {
      await supabase
          .from('profiles')
          .update({'no_hp': _noHpController.text.trim()})
          .eq('id', userId);
    }

    // Hubungkan orang tua ke santri
    if (!_isUstadz && _selectedSantriId != null) {
      await supabase
          .from('santri')
          .update({'orang_tua_id': userId})
          .eq('id', _selectedSantriId!);
    }

    if (mounted) {
      _showSnack('$_roleLabel berhasil ditambahkan!', isSuccess: true);
      Navigator.pop(context);
    }
  } catch (e) {
    if (mounted) {
      _showSnack('Gagal: ${e.toString().replaceAll('Exception: ', '')}');
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  void _showSnack(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isSuccess ? AppColors.green : Colors.red.shade900,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  void dispose() {
    _namaController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _noHpController.dispose();
    super.dispose();
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    TextInputType type = TextInputType.text,
    IconData? icon,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      obscureText: obscure,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null
            ? Icon(icon, color: AppColors.textSecondary, size: 20)
            : null,
        suffixIcon: suffix,
      ),
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
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.08)),
                        ),
                        child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: AppColors.textPrimary,
                            size: 16),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tambah $_roleLabel',
                              style: GoogleFonts.dmSerifDisplay(
                                  fontSize: 24,
                                  color: AppColors.textPrimary)),
                          Text('Akun akan otomatis terdaftar',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _accentColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: _accentColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        _roleLabel.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          color: _isUstadz
                              ? Colors.lightBlue
                              : Colors.purpleAccent,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // DATA PRIBADI
                      _SectionLabel(label: 'DATA PRIBADI'),
                      const SizedBox(height: 14),
                      _field('Nama Lengkap', _namaController,
                          icon: Icons.person_outlined),
                      const SizedBox(height: 12),
                      _field('No. HP (opsional)', _noHpController,
                          type: TextInputType.phone,
                          icon: Icons.phone_outlined),

                      const SizedBox(height: 24),

                      // DATA AKUN
                      _SectionLabel(label: 'DATA AKUN LOGIN'),
                      const SizedBox(height: 14),
                      _field('Alamat Email', _emailController,
                          type: TextInputType.emailAddress,
                          icon: Icons.email_outlined),
                      const SizedBox(height: 12),
                      _field('Password', _passwordController,
                          icon: Icons.lock_outlined,
                          obscure: _obscurePassword,
                          suffix: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                            onPressed: () => setState(() =>
                                _obscurePassword = !_obscurePassword),
                          )),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text('* Password minimal 6 karakter',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted)),
                      ),

                      // LINK SANTRI (khusus orang tua)
                      if (!_isUstadz) ...[
                        const SizedBox(height: 24),
                        _SectionLabel(label: 'HUBUNGKAN KE SANTRI'),
                        const SizedBox(height: 14),

                        _santriList.isEmpty
                            ? Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: Colors.orange.withOpacity(0.2)),
                                ),
                                child: Row(children: [
                                  const Icon(Icons.info_outline,
                                      color: Colors.orange, size: 16),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Semua santri sudah memiliki orang tua, atau belum ada data santri.',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary),
                                    ),
                                  ),
                                ]),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.08)),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedSantriId,
                                    dropdownColor: AppColors.bgCard,
                                    hint: Text(
                                      'Pilih santri (opsional)',
                                      style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 14),
                                    ),
                                    isExpanded: true,
                                    items: [
                                      DropdownMenuItem(
                                        value: null,
                                        child: Text('Tidak dihubungkan',
                                            style: TextStyle(
                                                color: AppColors.textSecondary)),
                                      ),
                                      ..._santriList.map((s) =>
                                          DropdownMenuItem(
                                            value: s['id'],
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(s['nama'],
                                                    style: const TextStyle(
                                                        color: AppColors
                                                            .textPrimary,
                                                        fontSize: 14)),
                                                Text(
                                                  '${s['kelas'] ?? '-'} · ${s['kamar'] ?? '-'}',
                                                  style: TextStyle(
                                                      color: AppColors
                                                          .textSecondary,
                                                      fontSize: 11),
                                                ),
                                              ],
                                            ),
                                          )),
                                    ],
                                    onChanged: (v) =>
                                        setState(() => _selectedSantriId = v),
                                  ),
                                ),
                              ),

                        if (_selectedSantriId != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.green.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: AppColors.green.withOpacity(0.2)),
                            ),
                            child: Row(children: [
                              Icon(Icons.link_rounded,
                                  color: AppColors.greenLight, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'Orang tua akan otomatis terhubung ke santri ini',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary),
                              ),
                            ]),
                          ),
                        ],
                      ],

                      const SizedBox(height: 24),

                      // Info box
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _accentColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: _accentColor.withOpacity(0.2)),
                        ),
                        child: Row(children: [
                          Icon(Icons.info_outline_rounded,
                              color: _isUstadz
                                  ? Colors.lightBlue
                                  : Colors.purpleAccent,
                              size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '$_roleLabel akan langsung bisa login dengan email & password ini.',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                  height: 1.5),
                            ),
                          ),
                        ]),
                      ),

                      const SizedBox(height: 28),

                      SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _simpan,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: AppColors.bg,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.bg))
                              : Text('Buat Akun $_roleLabel',
                                  style: GoogleFonts.dmSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
          width: 3, height: 14,
          decoration: BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}