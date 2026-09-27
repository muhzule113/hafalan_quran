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
import '../../utils/app_snackbar.dart';
import '../../services/notification_service.dart';
import 'setoran_detail_screen.dart';

@visibleForTesting
Map<String, dynamic>? parentSantriById(
  List<Map<String, dynamic>> santriList,
  String? santriId,
) {
  if (santriId == null || santriId.isEmpty) return null;
  for (final santri in santriList) {
    if (santri['id']?.toString() == santriId) return santri;
  }
  return null;
}

@visibleForTesting
Map<String, dynamic>? selectParentSantri(
  List<Map<String, dynamic>> santriList,
  String? selectedId,
) =>
    parentSantriById(santriList, selectedId) ??
    (santriList.isEmpty ? null : santriList.first);

@visibleForTesting
List<Map<String, dynamic>> notificationsWithReadState(
  List<Map<String, dynamic>> notifications,
  Object notificationId,
  bool isRead,
) => [
  for (final notification in notifications)
    notification['id'] == notificationId
        ? {...notification, 'dibaca': isRead}
        : notification,
];

@visibleForTesting
List<Map<String, dynamic>> notificationsWithoutId(
  List<Map<String, dynamic>> notifications,
  Object notificationId,
) => [
  for (final notification in notifications)
    if (notification['id'] != notificationId) notification,
];

@visibleForTesting
Future<void> openAfterNotificationRead({
  required Future<void> Function() markAsRead,
  required Future<void> Function() open,
}) async {
  await markAsRead();
  await open();
}

@visibleForTesting
Map<String, dynamic>? notificationForSetoran(
  List<Map<String, dynamic>> notifications,
  String setoranId,
) {
  for (final notification in notifications) {
    if (notificationSetoranId(notification) == setoranId) return notification;
  }
  return null;
}

@visibleForTesting
String parentTargetStatusLabel(Object? status) {
  switch (status?.toString()) {
    case 'selesai':
      return 'Selesai';
    case 'gagal':
      return 'Gagal';
    default:
      return 'Aktif';
  }
}

@visibleForTesting
String parentTargetDeadlineLabel(Object? rawDeadline, {DateTime? now}) {
  final parsed = DateTime.tryParse(rawDeadline?.toString() ?? '');
  if (parsed == null) return 'Deadline belum diatur';

  final today = now ?? DateTime.now();
  final deadline = DateTime(parsed.year, parsed.month, parsed.day);
  final currentDay = DateTime(today.year, today.month, today.day);
  final daysRemaining = deadline.difference(currentDay).inDays;

  if (daysRemaining < 0) {
    return 'Terlambat ${daysRemaining.abs()} hari';
  }
  if (daysRemaining == 0) return 'Deadline hari ini';
  return '$daysRemaining hari lagi';
}

class NotificationSetoranTapTarget extends StatelessWidget {
  final Map<String, dynamic> notification;
  final ValueChanged<String> onOpen;
  final VoidCallback? onUnavailable;
  final Widget child;

  const NotificationSetoranTapTarget({
    super.key,
    required this.notification,
    required this.onOpen,
    required this.child,
    this.onUnavailable,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      onTapHint: 'Buka detail setoran',
      child: InkWell(
        onTap: () {
          final id = notificationSetoranId(notification);
          if (id == null) {
            onUnavailable?.call();
          } else {
            onOpen(id);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: child,
      ),
    );
  }
}

class SetoranHistoryTapTarget extends StatelessWidget {
  final Map<String, dynamic> setoran;
  final ValueChanged<String> onOpen;
  final Widget child;

  const SetoranHistoryTapTarget({
    super.key,
    required this.setoran,
    required this.onOpen,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      onTapHint: 'Buka detail setoran',
      child: InkWell(
        onTap: () {
          final id = setoran['id']?.toString().trim();
          if (id != null && id.isNotEmpty) onOpen(id);
        },
        borderRadius: BorderRadius.circular(16),
        child: child,
      ),
    );
  }
}

class OrangTuaHomeScreen extends StatefulWidget {
  const OrangTuaHomeScreen({super.key});

  @override
  State<OrangTuaHomeScreen> createState() => _OrangTuaHomeScreenState();
}

class _OrangTuaHomeScreenState extends State<OrangTuaHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _santriList = [];
  Map<String, dynamic>? _santri;
  List<Map<String, dynamic>> _notifList = [];
  List<Map<String, dynamic>> _setoranList = [];
  List<Map<String, dynamic>> _targetList = [];
  Map<int, String> _progressMap = {};
  bool _isLoading = true;
  bool _targetLoading = false;
  String? _targetError;
  String _namaOrtu = 'Orang Tua';
  int _unreadCount = 0;

  static const int _pageSize = 20;
  int _page = 0;
  bool _hasMore = true;
  bool _loadingMore = false;
  String? _deletingNotificationId;
  bool _deletingAllNotifications = false;

  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  bool _playerReady = false;
  String? _playingId;
  bool _isPlaying = false;
  bool _openingSetoran = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    NotificationService.pendingSetoranId.addListener(_onPendingSetoranChanged);
    _initPlayer();
    _loadData();
  }

  Future<void> _initPlayer() async {
    await _player.openPlayer();
    setState(() => _playerReady = true);
  }

  Future<void> _loadData() async {
    if (_deletingNotificationId != null || _deletingAllNotifications) return;
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
          .order('nama');
      final santriList = List<Map<String, dynamic>>.from(santriData);
      final selectedSantri = selectParentSantri(
        santriList,
        _santri?['id']?.toString(),
      );

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
          _santriList = santriList;
          _santri = selectedSantri;
          _setoranList = [];
          _targetList = [];
          _progressMap = {};
          _targetLoading = selectedSantri != null;
          _targetError = null;
          _page = 0;
          _hasMore = true;
          _loadingMore = false;
          _notifList = List<Map<String, dynamic>>.from(notif);
          _unreadCount = _notifList.where((n) => n['dibaca'] == false).length;
          _isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _onPendingSetoranChanged(),
        );
      }

      // Load setoran & progress kalau ada santri
      final santriId = selectedSantri?['id']?.toString();
      if (santriId != null && santriId.isNotEmpty) {
        await _loadSetoran(santriId);
        await _loadProgress(santriId);
        await _loadTarget(santriId);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isCurrentSantri(String santriId) =>
      _santri?['id']?.toString() == santriId;

  Future<void> _changeSantri(String santriId) async {
    final selectedSantri = parentSantriById(_santriList, santriId);
    if (selectedSantri == null || _isCurrentSantri(santriId)) return;

    if (_isPlaying && _playerReady) await _player.stopPlayer();
    if (!mounted) return;

    setState(() {
      _santri = selectedSantri;
      _setoranList = [];
      _targetList = [];
      _progressMap = {};
      _targetLoading = true;
      _targetError = null;
      _page = 0;
      _hasMore = true;
      _loadingMore = false;
      _playingId = null;
      _isPlaying = false;
      _isLoading = true;
    });

    await _loadSetoran(santriId);
    await _loadProgress(santriId);
    await _loadTarget(santriId);

    if (mounted && _isCurrentSantri(santriId)) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markNotificationAsRead(
    Map<String, dynamic> notification,
  ) async {
    if (notification['dibaca'] != false) return;

    final notificationId = notification['id'];
    final userId = supabase.auth.currentUser?.id;
    if (notificationId == null || userId == null) {
      AppSnackbar.error(context, 'Notifikasi tidak dapat diperbarui');
      return;
    }

    setState(() {
      _notifList = notificationsWithReadState(_notifList, notificationId, true);
      _unreadCount = _notifList.where((n) => n['dibaca'] == false).length;
    });

    try {
      final updated = await supabase
          .from('notifikasi')
          .update({'dibaca': true})
          .eq('id', notificationId)
          .eq('orang_tua_id', userId)
          .select('id');
      if (updated.isEmpty) {
        throw StateError(
          'Notifikasi tidak ditemukan atau tidak dapat diperbarui',
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notifList = notificationsWithReadState(
          _notifList,
          notificationId,
          false,
        );
        _unreadCount = _notifList.where((n) => n['dibaca'] == false).length;
      });
      AppSnackbar.error(context, 'Gagal menandai notifikasi sebagai dibaca');
    }
  }

  Future<void> _deleteNotification(Map<String, dynamic> notification) async {
    if (_deletingNotificationId != null || _deletingAllNotifications) return;

    final notificationId = notification['id'];
    final userId = supabase.auth.currentUser?.id;
    if (notificationId == null || userId == null) {
      AppSnackbar.error(context, 'Notifikasi tidak dapat dihapus');
      return;
    }

    final confirm = await KonfirmasiDialog.hapus(
      context,
      judul: 'Hapus notifikasi?',
      pesan: 'Notifikasi ini akan dihapus permanen.',
    );
    if (!confirm || !mounted) return;

    setState(() => _deletingNotificationId = notificationId.toString());
    try {
      final deleted = await supabase
          .from('notifikasi')
          .delete()
          .eq('id', notificationId)
          .eq('orang_tua_id', userId)
          .select('id');
      if (deleted.isEmpty) {
        throw StateError('Notifikasi tidak ditemukan atau tidak dapat dihapus');
      }

      if (!mounted) return;
      setState(() {
        _notifList = notificationsWithoutId(_notifList, notificationId);
        _unreadCount = _notifList.where((n) => n['dibaca'] == false).length;
        _deletingNotificationId = null;
      });
      AppSnackbar.sukses(context, 'Notifikasi berhasil dihapus');
    } catch (_) {
      if (!mounted) return;
      setState(() => _deletingNotificationId = null);
      AppSnackbar.error(context, 'Gagal menghapus notifikasi');
    }
  }

  Future<void> _deleteAllNotifications() async {
    if (_notifList.isEmpty ||
        _deletingNotificationId != null ||
        _deletingAllNotifications) {
      return;
    }

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      AppSnackbar.error(context, 'Notifikasi tidak dapat dihapus');
      return;
    }

    final confirm = await KonfirmasiDialog.hapus(
      context,
      judul: 'Hapus semua notifikasi?',
      pesan: 'Semua notifikasi akan dihapus permanen.',
    );
    if (!confirm || !mounted) return;

    setState(() => _deletingAllNotifications = true);
    try {
      final deleted = await supabase
          .from('notifikasi')
          .delete()
          .eq('orang_tua_id', userId)
          .select('id');
      if (deleted.isEmpty) {
        throw StateError('Notifikasi tidak ditemukan atau tidak dapat dihapus');
      }

      if (!mounted) return;
      setState(() {
        _notifList = [];
        _unreadCount = 0;
        _deletingAllNotifications = false;
      });
      AppSnackbar.sukses(context, 'Semua notifikasi berhasil dihapus');
    } catch (_) {
      if (!mounted) return;
      setState(() => _deletingAllNotifications = false);
      AppSnackbar.error(context, 'Gagal menghapus semua notifikasi');
    }
  }

  void _onPendingSetoranChanged() {
    if (!mounted ||
        _isLoading ||
        _openingSetoran ||
        NotificationService.pendingSetoranId.value == null) {
      return;
    }
    final id = NotificationService.takePendingSetoranId();
    if (id != null) _handlePendingSetoran(id);
  }

  Future<void> _handlePendingSetoran(String setoranId) async {
    final notification = notificationForSetoran(_notifList, setoranId);
    if (notification != null) {
      await _openNotification(notification, setoranId);
      return;
    }

    if (!mounted) return;
    if (_santri == null || _santriList.length != 1) {
      AppSnackbar.error(context, 'Setoran tidak tersedia');
      return;
    }
    await _openSetoran(setoranId);
  }

  Future<void> _openSetoran(String setoranId, {String? santriId}) async {
    final resolvedSantriId = santriId ?? _santri?['id']?.toString();
    if (!mounted ||
        resolvedSantriId == null ||
        resolvedSantriId.isEmpty ||
        _openingSetoran) {
      return;
    }

    _openingSetoran = true;
    await Navigator.push(
      context,
      SlideRoute(
        page: SetoranDetailScreen(
          setoranId: setoranId,
          santriId: resolvedSantriId,
        ),
      ),
    );
    _openingSetoran = false;
    _onPendingSetoranChanged();
  }

  Future<void> _openNotification(
    Map<String, dynamic> notification,
    String setoranId,
  ) async {
    final rawSantriId = notification['santri_id']?.toString().trim();
    final santriId = rawSantriId == null || rawSantriId.isEmpty
        ? null
        : rawSantriId;
    final hasUnknownSantri =
        _santriList.isEmpty ||
        (santriId != null
            ? parentSantriById(_santriList, santriId) == null
            : _santriList.length > 1);

    if (hasUnknownSantri) {
      await _notificationUnavailable(notification);
      return;
    }

    await openAfterNotificationRead(
      markAsRead: () => _markNotificationAsRead(notification),
      open: () async {
        if (santriId != null) await _changeSantri(santriId);
        await _openSetoran(setoranId, santriId: santriId);
      },
    );
  }

  Future<void> _notificationUnavailable(
    Map<String, dynamic> notification,
  ) async {
    await _markNotificationAsRead(notification);
    if (!mounted) return;
    AppSnackbar.error(context, 'Setoran tidak tersedia');
  }

  Future<void> _loadSetoran(String santriId, {bool loadMore = false}) async {
    if (loadMore &&
        (!_hasMore || _loadingMore || !_isCurrentSantri(santriId))) {
      return;
    }

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

      if (mounted && _isCurrentSantri(santriId)) {
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
      if (mounted && _isCurrentSantri(santriId)) {
        setState(() => _loadingMore = false);
      }
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
      if (mounted && _isCurrentSantri(santriId)) {
        setState(() => _progressMap = map);
      }
    } catch (e) {
      print('Error load progress: $e');
    }
  }

  Future<void> _loadTarget(String santriId) async {
    if (mounted && _isCurrentSantri(santriId)) {
      setState(() {
        _targetLoading = true;
        _targetError = null;
      });
    }

    try {
      final data = await supabase
          .from('target_hafalan')
          .select(
            'judul, deskripsi, juz_target, surah_target, deadline, status',
          )
          .eq('santri_id', santriId)
          .order('deadline');

      if (mounted && _isCurrentSantri(santriId)) {
        setState(() {
          _targetList = List<Map<String, dynamic>>.from(data);
          _targetLoading = false;
          _targetError = null;
        });
      }
    } catch (_) {
      if (mounted && _isCurrentSantri(santriId)) {
        setState(() {
          _targetList = [];
          _targetLoading = false;
          _targetError = 'Target belum dapat dimuat';
        });
      }
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
    NotificationService.pendingSetoranId.removeListener(
      _onPendingSetoranChanged,
    );
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
                              if (_santriList.length > 1) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _santri!['id'].toString(),
                                      isDense: true,
                                      isExpanded: true,
                                      dropdownColor: AppColors.bgCard,
                                      icon: const Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: AppColors.gold,
                                        size: 18,
                                      ),
                                      style: const TextStyle(
                                        color: AppColors.gold,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      items: [
                                        for (final santri in _santriList)
                                          DropdownMenuItem<String>(
                                            value: santri['id'].toString(),
                                            child: Text(
                                              santri['nama']?.toString() ??
                                                  'Tanpa nama',
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                      ],
                                      onChanged: _isLoading
                                          ? null
                                          : (value) {
                                              if (value != null) {
                                                _changeSantri(value);
                                              }
                                            },
                                    ),
                                  ),
                                ),
                              ],
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
                      fontSize: 11,
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
                            Icon(Icons.flag_outlined, size: 14),
                            SizedBox(width: 4),
                            Text('Target'),
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
                          // Tab 3: Target Hafalan
                          _buildTargetTab(),
                          // Tab 4: Progress Hafalan
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
        itemCount: _notifList.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, index) {
          if (index == 0) {
            return Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed:
                    _deletingNotificationId != null || _deletingAllNotifications
                    ? null
                    : _deleteAllNotifications,
                icon: _deletingAllNotifications
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.redAccent,
                        ),
                      )
                    : const Icon(Icons.delete_sweep_outlined, size: 18),
                label: const Text('Hapus semua'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              ),
            );
          }

          final notif = _notifList[index - 1];
          final belumDibaca = notif['dibaca'] == false;
          return Material(
            color: belumDibaca
                ? AppColors.gold.withOpacity(0.06)
                : Colors.white.withOpacity(0.03),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: belumDibaca
                    ? AppColors.gold.withOpacity(0.25)
                    : Colors.white.withOpacity(0.07),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: NotificationSetoranTapTarget(
                    notification: notif,
                    onOpen: (id) => _openNotification(notif, id),
                    onUnavailable: () => _notificationUnavailable(notif),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 4, 16),
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
                                    color: AppColors.textPrimary.withValues(
                                      alpha: 0.72,
                                    ),
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _timeAgo(notif['created_at']),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textPrimary.withValues(
                                      alpha: 0.65,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  belumDibaca
                                      ? 'Ketuk untuk buka setoran'
                                      : 'Ketuk untuk buka kembali',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: belumDibaca
                                        ? AppColors.gold
                                        : AppColors.textPrimary.withValues(
                                            alpha: 0.65,
                                          ),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8, right: 4),
                  child: IconButton(
                    tooltip: 'Hapus notifikasi',
                    onPressed:
                        _deletingNotificationId != null ||
                            _deletingAllNotifications
                        ? null
                        : () => _deleteNotification(notif),
                    icon: _deletingNotificationId == notif['id']?.toString()
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.redAccent,
                            ),
                          )
                        : const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.redAccent,
                            size: 20,
                          ),
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
            GrafikPerkembangan(
              key: ValueKey(_santri!['id']),
              santriId: _santri!['id'],
            ),
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
                  return SetoranHistoryTapTarget(
                    setoran: s,
                    onOpen: _openSetoran,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.07),
                        ),
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

  Widget _buildTargetTab() {
    final santriId = _santri?['id']?.toString();
    if (santriId == null || santriId.isEmpty) {
      return Center(
        child: Text(
          'Belum ada data santri',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    if (_targetLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      );
    }

    if (_targetError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 42,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              _targetError!,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _loadTarget(santriId),
              child: const Text('Coba lagi'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.bgCard,
      onRefresh: () => _loadTarget(santriId),
      child: _targetList.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 80, 24, 40),
              children: [
                Icon(Icons.flag_outlined, size: 48, color: AppColors.textMuted),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'Belum ada target hafalan',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    'Ustadz belum membuat target untuk santri ini.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              itemCount: _targetList.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, index) {
                final target = _targetList[index];
                final status = target['status']?.toString();
                final statusColor = switch (status) {
                  'selesai' => AppColors.greenLight,
                  'gagal' => Colors.redAccent,
                  _ => AppColors.gold,
                };
                final details = <String>[
                  if (target['juz_target'] != null)
                    'Juz ${target['juz_target']}',
                  if (target['surah_target'] != null &&
                      target['surah_target'].toString().trim().isNotEmpty)
                    target['surah_target'].toString().trim(),
                ];
                final description = target['deskripsi']?.toString().trim();

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: status == 'aktif'
                          ? AppColors.gold.withOpacity(0.2)
                          : Colors.white.withOpacity(0.07),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              target['judul']?.toString() ?? 'Target hafalan',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              parentTargetStatusLabel(status),
                              style: TextStyle(
                                fontSize: 10,
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (description != null && description.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                      if (details.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(
                              Icons.menu_book_rounded,
                              size: 15,
                              color: AppColors.greenLight,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                details.join(', '),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.greenLight,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.event_outlined,
                            size: 15,
                            color: statusColor,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              parentTargetDeadlineLabel(target['deadline']),
                              style: TextStyle(
                                fontSize: 12,
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            target['deadline']?.toString().split('T').first ??
                                'Tanggal belum diatur',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildProgressTab() {
    if (_santri == null) {
      return Center(
        child: Text(
          'Belum ada data santri',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

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
