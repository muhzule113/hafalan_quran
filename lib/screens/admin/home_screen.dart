import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../utils/supabase_client.dart';
import '../auth/login_screen.dart';
import '../profil/profil_screen.dart';
import 'kelola_santri_screen.dart';
import 'kelola_ustadz_screen.dart';
import '../../widgets/konfirmasi_dialog.dart';
import '../../utils/app_routes.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _totalSantri = 0;
  int _totalUstadz = 0;
  bool _isLoading = true;
  String _namaAdmin = 'Admin';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final profile = await supabase
          .from('profiles')
          .select('nama')
          .eq('id', userId)
          .single();
      final santri = await supabase
          .from('santri')
          .select('id')
          .eq('aktif', true);
      final ustadz = await supabase
          .from('profiles')
          .select('id')
          .eq('role', 'ustadz');

      if (mounted) {
        setState(() {
          _namaAdmin = profile['nama'] ?? 'Admin';
          _totalSantri = (santri as List).length;
          _totalUstadz = (ustadz as List).length;
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
          child: RefreshIndicator(
            color: AppColors.gold,
            backgroundColor: AppColors.bgCard,
            onRefresh: _loadData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Assalamu\'alaikum',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _namaAdmin,
                                style: GoogleFonts.dmSerifDisplay(
                                  fontSize: 26,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.gold.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppColors.gold.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: AppColors.gold,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'ADMIN',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.gold,
                                        letterSpacing: 1.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.person_rounded,
                              color: AppColors.textSecondary),
                          onPressed: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const ProfilScreen())),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.logout_rounded,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () async {
                            final confirm = await KonfirmasiDialog.logout(context);
                            if (confirm && context.mounted) {
                              await supabase.auth.signOut();
                              Navigator.pushReplacement(
                                context,
                                FadeRoute(page: const LoginScreen()),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Stats
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.gold,
                            ),
                          )
                        : Row(
                            children: [
                              _StatCard(
                                label: 'Santri',
                                value: '$_totalSantri',
                                isGold: true,
                              ),
                              const SizedBox(width: 10),
                              _StatCard(
                                label: 'Ustadz',
                                value: '$_totalUstadz',
                              ),
                            ],
                          ),
                  ),

                  const SizedBox(height: 32),

                  // Section label
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'KELOLA DATA',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Menu items
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        _MenuCard(
                          icon: Icons.school_rounded,
                          title: 'Kelola Santri',
                          subtitle: 'Tambah, edit, dan hapus data santri',
                          accentColor: AppColors.green,
                          onTap: () => Navigator.push(
                            context,
                            FadeRoute(page: const KelolaSantriScreen()),
                          ).then((_) => _loadData()),
                        ),
                        const SizedBox(height: 10),
                        _MenuCard(
                          icon: Icons.person_rounded,
                          title: 'Kelola Ustadz',
                          subtitle: 'Manajemen akun ustadz pengajar',
                          accentColor: AppColors.blue,
                          onTap: () => Navigator.push(
                            context,
                            FadeRoute(page: const KelolaUstadzScreen()),
                          ).then((_) => _loadData()),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final bool isGold;

  const _StatCard({
    required this.label,
    required this.value,
    this.isGold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: isGold
              ? AppColors.gold.withOpacity(0.1)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isGold
                ? AppColors.gold.withOpacity(0.35)
                : Colors.white.withOpacity(0.07),
          ),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.dmSerifDisplay(
                fontSize: 26,
                color: isGold ? AppColors.gold : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Row(
          children: [
            // Left accent bar
            Container(
              width: 3,
              height: 40,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 14),
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accentColor, size: 20),
            ),
            const SizedBox(width: 14),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: Colors.white.withOpacity(0.2),
            ),
          ],
        ),
      ),
    );
  }
}
