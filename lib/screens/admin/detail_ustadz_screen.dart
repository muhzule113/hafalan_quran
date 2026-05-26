import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../utils/supabase_client.dart';
import 'kelola_ustadz_screen.dart';

class DetailUstadzScreen extends StatefulWidget {
  final String ustadzId;
  const DetailUstadzScreen({super.key, required this.ustadzId});

  @override
  State<DetailUstadzScreen> createState() => _DetailUstadzScreenState();
}

class _DetailUstadzScreenState extends State<DetailUstadzScreen> {
  Map<String, dynamic>? _ustadz;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      // Fetch profil dari tabel profiles
      final data = await supabase
          .from('profiles')
          .select('id, nama, no_hp, created_at')
          .eq('id', widget.ustadzId)
          .single();

      // Fetch email dari auth.users via RPC
      final email = await supabase.rpc(
        'get_user_email',
        params: {'user_id': widget.ustadzId},
      );

      if (mounted) {
        setState(() {
          _ustadz = {...data, 'email': email ?? '—'};
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatTanggal(String? iso) {
    if (iso == null) return '—';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '—';
    const bulan = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${dt.day} ${bulan[dt.month]} ${dt.year}';
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
              : _ustadz == null
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
                              'Profil Ustadz',
                              style: GoogleFonts.dmSerifDisplay(
                                fontSize: 24,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          // Tombol edit
                          GestureDetector(
                            onTap: () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => EditUstadzSheet(
                                item: _ustadz!,
                                onSaved: _load,
                              ),
                            ),
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
                                      color: AppColors.blue.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.blue.withOpacity(0.3),
                                        width: 2,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        (_ustadz!['nama'] as String)[0]
                                            .toUpperCase(),
                                        style: GoogleFonts.dmSerifDisplay(
                                          fontSize: 32,
                                          color: Colors.lightBlue,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    _ustadz!['nama'],
                                    style: GoogleFonts.dmSerifDisplay(
                                      fontSize: 22,
                                      color: AppColors.textPrimary,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  _Chip(
                                    label: 'Ustadz',
                                    color: Colors.lightBlue,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 28),

                            // Kartu data akun
                            _InfoCard(
                              title: 'DATA AKUN',
                              icon: Icons.manage_accounts_outlined,
                              iconColor: Colors.lightBlue,
                              children: [
                                _InfoRow(
                                  label: 'Nama Lengkap',
                                  value: _ustadz!['nama'] ?? '—',
                                  icon: Icons.person_outlined,
                                ),
                                _InfoRow(
                                  label: 'Email',
                                  value: _ustadz!['email'] ?? '—',
                                  icon: Icons.email_outlined,
                                ),
                                _InfoRow(
                                  label: 'No. HP',
                                  value: _ustadz!['no_hp']?.isNotEmpty == true
                                      ? _ustadz!['no_hp']
                                      : '—',
                                  icon: Icons.phone_outlined,
                                ),
                                _InfoRow(
                                  label: 'Bergabung',
                                  value: _formatTanggal(_ustadz!['created_at']),
                                  icon: Icons.calendar_today_outlined,
                                  isLast: true,
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

// ═══════════════════════════════════════════
// Reusable widgets
// ═══════════════════════════════════════════

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
  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
    this.isLast = false,
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
                        color: AppColors.textPrimary,
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
