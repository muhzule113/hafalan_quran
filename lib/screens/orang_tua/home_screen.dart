import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_sound/flutter_sound.dart';
import '../../theme/app_theme.dart';
import '../../utils/supabase_client.dart';
import '../auth/login_screen.dart';
import '../profil/profil_screen.dart';
import '../../widgets/grafik_perkembangan.dart';
import '../../widgets/konfirmasi_dialog.dart';
import '../../utils/app_routes.dart';

class OrangTuaHomeScreen extends StatefulWidget {
  const OrangTuaHomeScreen({super.key});

  @override
  State<OrangTuaHomeScreen> createState() => _OrangTuaHomeScreenState();
}

class _OrangTuaHomeScreenState extends State<OrangTuaHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _santri;
  List<Map<String, dynamic>> _notifList = [];
  List<Map<String, dynamic>> _setoranList = [];
  Map<int, String> _progressMap = {};
  bool _isLoading = true;
  String _namaOrtu = 'Orang Tua';
  int _unreadCount = 0;

  static const int _pageSize = 20;
  int _page = 0;
  bool _hasMore = true;
  bool _loadingMore = false;

  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  bool _playerReady = false;
  String? _playingId;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initPlayer();
    _loadData();
  }

  Future<void> _initPlayer() async {
    await _player.openPlayer();
    setState(() => _playerReady = true);
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser!.id;

      // Profil ortu
      final profile = await supabase
          .from('profiles')
          .select('nama')
          .eq('id', userId)
          .single();

      // Data santri
      final santriData = await supabase
          .from('santri')
          .select()
          .eq('orang_tua_id', userId)
          .maybeSingle();

      // Notifikasi
      final notif = await supabase
          .from('notifikasi')
          .select()
          .eq('orang_tua_id', userId)
          .order('created_at', ascending: false)
          .limit(30);

      if (mounted) {
        setState(() {
          _namaOrtu = profile['nama'] ?? 'Orang Tua';
          _santri = santriData;
          _notifList = List<Map<String, dynamic>>.from(notif);
          _unreadCount = _notifList.where((n) => n['dibaca'] == false).length;
          _isLoading = false;
        });
      }

      // Load setoran & progress kalau ada santri
      if (santriData != null) {
        await _loadSetoran(santriData['id']);
        await _loadProgress(santriData['id']);
      }

      // Tandai semua notif dibaca
      await supabase
          .from('notifikasi')
          .update({'dibaca': true})
          .eq('orang_tua_id', userId)
          .eq('dibaca', false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSetoran(String santriId, {bool loadMore = false}) async {
    if (loadMore && (!_hasMore || _loadingMore)) return;

    if (loadMore) {
      setState(() => _loadingMore = true);
    }

    try {
      final from = loadMore ? _page * _pageSize : 0;
      final to = from + _pageSize - 1;

      final data = await supabase
          .from('setoran')
          .select()
          .eq('santri_id', santriId)
          .order('tanggal', ascending: false)
          .range(from, to);

      final newData = List<Map<String, dynamic>>.from(data);

      if (mounted) {
        setState(() {
          if (loadMore) {
            _setoranList.addAll(newData);
            _page++;
          } else {
            _setoranList = newData;
            _page = 1;
          }
          _hasMore = newData.length == _pageSize;
          _loadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _togglePlay(String setoranId, String audioUrl) async {
    if (!_playerReady) return;
    if (_isPlaying && _playingId == setoranId) {
      await _player.stopPlayer();
      setState(() {
        _isPlaying = false;
        _playingId = null;
      });
      return;
    }
    if (_isPlaying) await _player.stopPlayer();
    try {
      setState(() {
        _isPlaying = true;
        _playingId = setoranId;
      });
      await _player.startPlayer(
        fromURI: audioUrl,
        codec: Codec.aacADTS,
        whenFinished: () {
          if (mounted)
            setState(() {
              _isPlaying = false;
              _playingId = null;
            });
        },
      );
    } catch (e) {
      if (mounted)
        setState(() {
          _isPlaying = false;
          _playingId = null;
        });
    }
  }

  Future<void> _loadProgress(String santriId) async {
    try {
      final data = await supabase
          .from('progress_hafalan')
          .select()
          .eq('santri_id', santriId);
      final map = <int, String>{};
      for (final row in data as List) {
        map[row['juz'] as int] = row['status'] as String;
      }
      if (mounted) setState(() => _progressMap = map);
    } catch (e) {
      print('Error load progress: $e');
    }
  }

  String _timeAgo(String dateStr) {
    final date = DateTime.parse(dateStr).toLocal();
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'diterima':
        return AppColors.green;
      case 'diulang':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'diterima':
        return '✅ Diterima';
      case 'diulang':
        return '🔄 Diulang';
      default:
        return '⏳ Menunggu';
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _player.closePlayer();
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
          child: Column(
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
                            ),
                          ),
                          Text(
                            _namaOrtu,
                            style: GoogleFonts.dmSerifDisplay(
                              fontSize: 24,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.purple.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.purple.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Colors.purpleAccent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'ORANG TUA',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.purpleAccent,
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
                    // Notif badge + logout
                    Stack(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.notifications_outlined,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () => _tabController.animateTo(0),
                        ),
                        if (_unreadCount > 0)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '$_unreadCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.person_rounded,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ProfilScreen()),
                      ),
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

              const SizedBox(height: 16),

              // Info santri
              if (_santri != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.gold.withOpacity(0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.gold.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(
                              _santri!['nama'][0].toUpperCase(),
                              style: GoogleFonts.dmSerifDisplay(
                                fontSize: 20,
                                color: AppColors.gold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _santri!['nama'],
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${_santri!['kelas'] ?? '-'} · Kamar ${_santri!['kamar'] ?? '-'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Progress ringkas
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${_progressMap.values.where((s) => s == 'hafal').length}/30',
                              style: GoogleFonts.dmSerifDisplay(
                                fontSize: 18,
                                color: AppColors.gold,
                              ),
                            ),
                            Text(
                              'juz hafal',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

              if (_santri == null && !_isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.orange.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.orange,
                          size: 16,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Akun belum terhubung ke santri. Hubungi admin.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Tab bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.07)),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: AppColors.gold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.gold.withOpacity(0.3),
                      ),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: AppColors.gold,
                    unselectedLabelColor: AppColors.textSecondary,
                    labelStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    dividerColor: Colors.transparent,
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.notifications_outlined, size: 14),
                            const SizedBox(width: 4),
                            const Text('Notifikasi'),
                            if (_unreadCount > 0) ...[
                              const SizedBox(width: 4),
                              Container(
                                width: 16,
                                height: 16,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '$_unreadCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history_rounded, size: 14),
                            SizedBox(width: 4),
                            Text('Setoran'),
                          ],
                        ),
                      ),
                      const Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.map_rounded, size: 14),
                            SizedBox(width: 4),
                            Text('Progress'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Tab content
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.gold),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          // Tab 1: Notifikasi
                          _buildNotifTab(),
                          // Tab 2: Riwayat Setoran
                          _buildSetoranTab(),
                          // Tab 3: Progress Hafalan
                          _buildProgressTab(),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotifTab() {
    if (_notifList.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 48,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              'Belum ada notifikasi',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.bgCard,
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
        itemCount: _notifList.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, index) {
          final notif = _notifList[index];
          final belumDibaca = notif['dibaca'] == false;
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: belumDibaca
                  ? AppColors.gold.withOpacity(0.06)
                  : Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: belumDibaca
                    ? AppColors.gold.withOpacity(0.25)
                    : Colors.white.withOpacity(0.07),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    color: AppColors.greenLight,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notif['judul'],
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: belumDibaca
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          if (belumDibaca)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.gold,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notif['pesan'],
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _timeAgo(notif['created_at']),
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSetoranTab() {
    if (_santri == null) {
      return Center(
        child: Text(
          'Belum ada data santri',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.bgCard,
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
        child: Column(
          children: [
            // ← Tambahkan grafik di sini
            GrafikPerkembangan(santriId: _santri!['id']),
            const SizedBox(height: 24),

            // Section label
            Row(
              children: [
                Text(
                  'RIWAYAT SETORAN',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // List setoran
            if (_setoranList.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Column(
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      size: 48,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Belum ada riwayat setoran',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _setoranList.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, index) {
                  final s = _setoranList[index];
                  final hasPenilaian = s['nilai_tajwid'] != null;
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.07)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${s['surah']} · ${s['ayat_mulai']}-${s['ayat_selesai']}',
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _timeAgo(s['tanggal']),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _statusColor(
                                  s['status'],
                                ).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _statusColor(
                                    s['status'],
                                  ).withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                _statusLabel(s['status']),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _statusColor(s['status']),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (hasPenilaian) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.purple.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.purple.withOpacity(0.2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Penilaian Ustadz',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _NilaiRow(
                                      label: 'Kelancaran',
                                      nilai: s['nilai_kelancaran'] ?? 0,
                                    ),
                                    const SizedBox(width: 12),
                                    _NilaiRow(
                                      label: 'Tajwid',
                                      nilai: s['nilai_tajwid'] ?? 0,
                                    ),
                                    const SizedBox(width: 12),
                                    _NilaiRow(
                                      label: 'Makhraj',
                                      nilai: s['nilai_makhraj'] ?? 0,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Rata-rata',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    Text(
                                      '${(((s['nilai_kelancaran'] ?? 0) + (s['nilai_tajwid'] ?? 0) + (s['nilai_makhraj'] ?? 0)) / 3).toStringAsFixed(1)} / 5.0',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.gold,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (s['catatan'] != null &&
                            s['catatan'].toString().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            s['catatan'],
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                        // Setelah bagian catatan (if s['catatan']...)
                        // ← Tambahkan tombol audio di sini
                        if (s['audio_url'] != null) ...[
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: () => _togglePlay(s['id'], s['audio_url']),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: _playingId == s['id']
                                    ? AppColors.gold.withOpacity(0.15)
                                    : Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _playingId == s['id']
                                      ? AppColors.gold.withOpacity(0.4)
                                      : Colors.white.withOpacity(0.1),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _playingId == s['id'] && _isPlaying
                                        ? Icons.stop_rounded
                                        : Icons.play_arrow_rounded,
                                    color: _playingId == s['id']
                                        ? AppColors.gold
                                        : AppColors.textSecondary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _playingId == s['id'] && _isPlaying
                                        ? 'Hentikan Audio'
                                        : 'Putar Bacaan',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _playingId == s['id']
                                          ? AppColors.gold
                                          : AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Spacer(),
                                  Icon(
                                    Icons.headphones_rounded,
                                    color: AppColors.textMuted,
                                    size: 14,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            // Setelah ListView.separated, tambahkan:
            if (_hasMore && _setoranList.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: GestureDetector(
                  onTap: () => _loadSetoran(_santri!['id'], loadMore: true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Center(
                      child: _loadingMore
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.gold,
                              ),
                            )
                          : Text(
                              'Muat lebih banyak',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressTab() {
    final totalHafal = _progressMap.values.where((s) => s == 'hafal').length;
    final totalSedang = _progressMap.values.where((s) => s == 'sedang').length;
    final persen = (totalHafal / 30 * 100).toInt();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
      child: Column(
        children: [
          // Progress bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.gold.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progress Al-Qur\'an',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '$persen%',
                      style: GoogleFonts.dmSerifDisplay(
                        fontSize: 24,
                        color: AppColors.gold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: totalHafal / 30,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ProgressStat(
                      label: 'Hafal',
                      value: '$totalHafal juz',
                      color: AppColors.greenLight,
                    ),
                    _ProgressStat(
                      label: 'Sedang',
                      value: '$totalSedang juz',
                      color: Colors.amber,
                    ),
                    _ProgressStat(
                      label: 'Belum',
                      value: '${30 - totalHafal - totalSedang} juz',
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Legend
          Row(
            children: [
              _Legend(color: AppColors.greenLight, label: 'Hafal'),
              const SizedBox(width: 16),
              _Legend(color: Colors.amber, label: 'Sedang'),
              const SizedBox(width: 16),
              _Legend(color: Colors.white.withOpacity(0.15), label: 'Belum'),
            ],
          ),

          const SizedBox(height: 12),

          // Grid 30 juz (read only)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1,
            ),
            itemCount: 30,
            itemBuilder: (_, index) {
              final juz = index + 1;
              final status = _progressMap[juz] ?? 'belum';

              Color fillColor;
              Color borderColor;
              Color textColor;

              if (status == 'hafal') {
                fillColor = AppColors.green.withOpacity(0.25);
                borderColor = AppColors.greenLight;
                textColor = AppColors.greenLight;
              } else if (status == 'sedang') {
                fillColor = Colors.amber.withOpacity(0.2);
                borderColor = Colors.amber;
                textColor = Colors.amber;
              } else {
                fillColor = Colors.white.withOpacity(0.04);
                borderColor = Colors.white.withOpacity(0.1);
                textColor = AppColors.textMuted;
              }

              return Container(
                decoration: BoxDecoration(
                  color: fillColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor, width: 1),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (status == 'hafal')
                      const Icon(
                        Icons.check_rounded,
                        color: AppColors.greenLight,
                        size: 14,
                      )
                    else if (status == 'sedang')
                      const Icon(Icons.circle, color: Colors.amber, size: 7),
                    const SizedBox(height: 2),
                    Text(
                      '$juz',
                      style: GoogleFonts.dmSerifDisplay(
                        fontSize: 16,
                        color: textColor,
                      ),
                    ),
                    Text(
                      'juz',
                      style: TextStyle(fontSize: 8, color: AppColors.textMuted),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// Widget helper
class _NilaiRow extends StatelessWidget {
  final String label;
  final int nilai;
  const _NilaiRow({required this.label, required this.nilai});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 9, color: AppColors.textMuted),
          ),
          const SizedBox(height: 3),
          Row(
            children: List.generate(
              5,
              (i) => Icon(
                i < nilai ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 11,
                color: i < nilai ? AppColors.gold : AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _ProgressStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
