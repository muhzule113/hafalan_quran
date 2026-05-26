import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../utils/supabase_client.dart';
import 'kelola_santri_screen.dart';

class DetailSantriScreen extends StatefulWidget {
  final String santriId;
  const DetailSantriScreen({super.key, required this.santriId});

  @override
  State<DetailSantriScreen> createState() => _DetailSantriScreenState();
}

class _DetailSantriScreenState extends State<DetailSantriScreen> {
  Map<String, dynamic>? _santri;
  Map<String, dynamic>? _orangTua;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final santri = await supabase
          .from('santri')
          .select()
          .eq('id', widget.santriId)
          .single();

      Map<String, dynamic>? orangTua;
      if (santri['orang_tua_id'] != null) {
        final ortuData = await supabase
            .from('profiles')
            .select('id, nama, no_hp') // ← hapus email dari sini
            .eq('id', santri['orang_tua_id'])
            .maybeSingle();

        if (ortuData != null) {
          // Fetch email ortu dari auth
          final ortuEmail = await supabase.rpc(
            'get_user_email',
            params: {'user_id': santri['orang_tua_id']},
          );

          orangTua = {...ortuData, 'email': ortuEmail ?? '—'};
        }
      }

      if (mounted) {
        setState(() {
          _santri = santri;
          _orangTua = orangTua;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
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
              : _santri == null
              ? const Center(
                  child: Text(
                    'Data tidak ditemukan',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : Column(
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
                          Expanded(
                            child: Text(
                              'Profil Santri',
                              style: GoogleFonts.dmSerifDisplay(
                                fontSize: 24,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          // Tombol edit → buka FormSantriScreen
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    FormSantriScreen(santri: _santri),
                              ),
                            ).then((_) => _load()),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.gold.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.gold.withOpacity(0.25),
                                ),
                              ),
                              child: const Icon(
                                Icons.edit_outlined,
                                color: AppColors.gold,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                        child: Column(
                          children: [
                            // Avatar & nama
                            Center(
                              child: Column(
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: AppColors.green.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.green.withOpacity(0.3),
                                        width: 2,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        (_santri!['nama'] as String)[0]
                                            .toUpperCase(),
                                        style: GoogleFonts.dmSerifDisplay(
                                          fontSize: 32,
                                          color: AppColors.greenLight,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    _santri!['nama'],
                                    style: GoogleFonts.dmSerifDisplay(
                                      fontSize: 22,
                                      color: AppColors.textPrimary,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    alignment: WrapAlignment.center,
                                    children: [
                                      if (_santri!['kelas'] != null)
                                        _Chip(
                                          label: _santri!['kelas'],
                                          color: AppColors.green,
                                        ),
                                      if (_santri!['kamar'] != null)
                                        _Chip(
                                          label: _santri!['kamar'],
                                          color: AppColors.gold,
                                        ),
                                      _Chip(
                                        label: _santri!['jenis_kelamin'] == 'L'
                                            ? 'Laki-laki'
                                            : 'Perempuan',
                                        color: _santri!['jenis_kelamin'] == 'L'
                                            ? Colors.blue
                                            : Colors.pink,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 28),

                            _InfoCard(
                              title: 'DATA SANTRI',
                              icon: Icons.school_outlined,
                              iconColor: AppColors.greenLight,
                              children: [
                                _InfoRow(
                                  label: 'NIS',
                                  value: _santri!['nis']?.isNotEmpty == true
                                      ? _santri!['nis']
                                      : '—',
                                  icon: Icons.badge_outlined,
                                ),
                                _InfoRow(
                                  label: 'Kelas',
                                  value: _santri!['kelas']?.isNotEmpty == true
                                      ? _santri!['kelas']
                                      : '—',
                                  icon: Icons.class_outlined,
                                ),
                                _InfoRow(
                                  label: 'Kamar',
                                  value: _santri!['kamar']?.isNotEmpty == true
                                      ? _santri!['kamar']
                                      : '—',
                                  icon: Icons.door_back_door_outlined,
                                ),
                                _InfoRow(
                                  label: 'Jenis Kelamin',
                                  value: _santri!['jenis_kelamin'] == 'L'
                                      ? 'Laki-laki'
                                      : 'Perempuan',
                                  icon: Icons.person_outlined,
                                  isLast: true,
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),

                            _InfoCard(
                              title: 'DATA WALI',
                              icon: Icons.family_restroom_outlined,
                              iconColor: AppColors.gold,
                              children: [
                                _InfoRow(
                                  label: 'Nama Wali',
                                  value:
                                      _santri!['nama_wali']?.isNotEmpty == true
                                      ? _santri!['nama_wali']
                                      : '—',
                                  icon: Icons.person_outlined,
                                ),
                                _InfoRow(
                                  label: 'No. HP Wali',
                                  value:
                                      _santri!['no_hp_wali']?.isNotEmpty == true
                                      ? _santri!['no_hp_wali']
                                      : '—',
                                  icon: Icons.phone_outlined,
                                  isLast: true,
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),

                            _InfoCard(
                              title: 'AKUN ORANG TUA',
                              icon: Icons.smartphone_outlined,
                              iconColor: Colors.purpleAccent,
                              children: _orangTua != null
                                  ? [
                                      _InfoRow(
                                        label: 'Nama',
                                        value: _orangTua!['nama'] ?? '—',
                                        icon: Icons.person_outlined,
                                      ),
                                      _InfoRow(
                                        label: 'Email',
                                        value: _orangTua!['email'] ?? '—',
                                        icon: Icons.email_outlined,
                                      ),
                                      _InfoRow(
                                        label: 'No. HP',
                                        value:
                                            _orangTua!['no_hp']?.isNotEmpty ==
                                                true
                                            ? _orangTua!['no_hp']
                                            : '—',
                                        icon: Icons.phone_outlined,
                                        isLast: true,
                                      ),
                                    ]
                                  : [
                                      _InfoRow(
                                        label: 'Status',
                                        value: 'Belum ada akun orang tua',
                                        icon: Icons.info_outline,
                                        isLast: true,
                                        valueColor: AppColors.textMuted,
                                      ),
                                    ],
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

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<Widget> children;
  const _InfoCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 15),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.white.withOpacity(0.06)),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isLast;
  final Color? valueColor;
  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
    this.isLast = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: AppColors.textMuted, size: 16),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 14,
                        color: valueColor ?? AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(height: 1, indent: 44, color: Colors.white.withOpacity(0.05)),
      ],
    );
  }
}
