// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import '../../theme/app_theme.dart';
// import '../../utils/supabase_client.dart';
// import 'form_user_screen.dart';

// class KelolaOrangTuaScreen extends StatefulWidget {
//   const KelolaOrangTuaScreen({super.key});

//   @override
//   State<KelolaOrangTuaScreen> createState() => _KelolaOrangTuaScreenState();
// }

// class _KelolaOrangTuaScreenState extends State<KelolaOrangTuaScreen> {
//   List<Map<String, dynamic>> _list = [];
//   bool _isLoading = true;

//   @override
//   void initState() {
//     super.initState();
//     _load();
//   }

//   Future<void> _load() async {
//   setState(() => _isLoading = true);
//   try {
//     final data = await supabase
//         .from('profiles')
//         .select('*, santri(id, nama, kelas, kamar)')
//         .eq('role', 'orang_tua')
//         .order('nama');

//     print('=== ORANG TUA DATA ===');
//     print('Raw data: $data');
//     print('Length: ${(data as List).length}');

//     if (mounted) {
//       setState(() {
//         _list = List<Map<String, dynamic>>.from(data);
//         _isLoading = false;
//       });
//     }
//   } catch (e) {
//     print('=== ERROR LOAD ORANG TUA ===');
//     print('Error: $e');
//     if (mounted) setState(() => _isLoading = false);
//   }
// }

//   Future<void> _hapus(Map<String, dynamic> item) async {
//     final confirm = await showDialog<bool>(
//       context: context,
//       builder: (_) => AlertDialog(
//         backgroundColor: AppColors.bgCard,
//         shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(20)),
//         title: Text('Hapus Orang Tua',
//             style: GoogleFonts.dmSerifDisplay(
//                 color: AppColors.textPrimary)),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('Yakin ingin menghapus akun:',
//                 style: TextStyle(
//                     color: AppColors.textSecondary, fontSize: 13)),
//             const SizedBox(height: 8),
//             Container(
//               padding: const EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 color: Colors.red.withOpacity(0.08),
//                 borderRadius: BorderRadius.circular(10),
//                 border: Border.all(color: Colors.red.withOpacity(0.2)),
//               ),
//               child: Row(children: [
//                 const Icon(Icons.person_rounded,
//                     color: Colors.red, size: 16),
//                 const SizedBox(width: 8),
//                 Expanded(
//                   child: Text(item['nama'],
//                       style: const TextStyle(
//                           color: AppColors.textPrimary,
//                           fontWeight: FontWeight.w600)),
//                 ),
//               ]),
//             ),
//             const SizedBox(height: 8),
//             Text(
//               'Santri yang terhubung akan otomatis terputus.',
//               style: TextStyle(color: Colors.orange.shade300, fontSize: 11)),
//             const SizedBox(height: 4),
//             Text('Tindakan ini tidak dapat dibatalkan.',
//                 style: TextStyle(
//                     color: Colors.red.shade300, fontSize: 11)),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context, false),
//             child: Text('Batal',
//                 style: TextStyle(color: AppColors.textSecondary)),
//           ),
//           ElevatedButton(
//             onPressed: () => Navigator.pop(context, true),
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.red.shade900,
//               foregroundColor: Colors.white,
//               shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(10)),
//             ),
//             child: const Text('Hapus'),
//           ),
//         ],
//       ),
//     );

//     if (confirm != true) return;

//     try {
//       // Putuskan hubungan santri dulu
//       await supabase
//           .from('santri')
//           .update({'orang_tua_id': null})
//           .eq('orang_tua_id', item['id']);

//       // Hapus user
//       await supabase.rpc('delete_user', params: {'user_id': item['id']});

//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//           content: Text('Akun ${item['nama']} berhasil dihapus'),
//           backgroundColor: AppColors.green,
//           behavior: SnackBarBehavior.floating,
//           shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(12)),
//         ));
//         _load();
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//           content: Text('Gagal: ${e.toString()
//               .replaceAll('Exception: ', '')}'),
//           backgroundColor: Colors.red.shade900,
//           behavior: SnackBarBehavior.floating,
//           shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(12)),
//         ));
//       }
//     }
//   }

//   void _showEditSheet(Map<String, dynamic> item) {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (_) => EditOrangTuaSheet(item: item, onSaved: _load),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Container(
//         decoration: const BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//             colors: [Color(0xFF0D2818), Color(0xFF071510)],
//           ),
//         ),
//         child: SafeArea(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // Header
//               Padding(
//                 padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
//                 child: Row(
//                   children: [
//                     GestureDetector(
//                       onTap: () => Navigator.pop(context),
//                       child: Container(
//                         width: 38, height: 38,
//                         decoration: BoxDecoration(
//                           color: Colors.white.withOpacity(0.06),
//                           borderRadius: BorderRadius.circular(12),
//                           border: Border.all(
//                               color: Colors.white.withOpacity(0.08)),
//                         ),
//                         child: const Icon(
//                             Icons.arrow_back_ios_new_rounded,
//                             color: AppColors.textPrimary, size: 16),
//                       ),
//                     ),
//                     const SizedBox(width: 16),
//                     Expanded(
//                       child: Text('Kelola Orang Tua',
//                           style: GoogleFonts.dmSerifDisplay(
//                               fontSize: 24,
//                               color: AppColors.textPrimary)),
//                     ),
//                     Container(
//                       padding: const EdgeInsets.symmetric(
//                           horizontal: 10, vertical: 4),
//                       decoration: BoxDecoration(
//                         color: AppColors.purple.withOpacity(0.15),
//                         borderRadius: BorderRadius.circular(20),
//                         border: Border.all(
//                             color: AppColors.purple.withOpacity(0.3)),
//                       ),
//                       child: Text('${_list.length} ortu',
//                           style: const TextStyle(
//                               fontSize: 11,
//                               color: Colors.purpleAccent,
//                               fontWeight: FontWeight.w600)),
//                     ),
//                   ],
//                 ),
//               ),

//               const SizedBox(height: 20),

//               // List
//               Expanded(
//                 child: _isLoading
//                     ? const Center(child: CircularProgressIndicator(
//                     color: AppColors.gold))
//                     : _list.isEmpty
//                     ? Center(
//                     child: Column(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         Icon(Icons.family_restroom_outlined,
//                             size: 48, color: AppColors.textMuted),
//                         const SizedBox(height: 12),
//                         Text('Belum ada orang tua terdaftar',
//                             style: TextStyle(
//                                 color: AppColors.textSecondary)),
//                       ],
//                     ))
//                     : RefreshIndicator(
//                   color: AppColors.gold,
//                   backgroundColor: AppColors.bgCard,
//                   onRefresh: _load,
//                   child: ListView.separated(
//                     padding: const EdgeInsets.fromLTRB(
//                         24, 0, 24, 100),
//                     itemCount: _list.length,
//                     separatorBuilder: (_, _) =>
//                     const SizedBox(height: 10),
//                     itemBuilder: (_, index) {
//                       final item = _list[index];
//                       final santriList = item['santri'] as List? ?? [];
//                       final santri = santriList.isNotEmpty
//                           ? santriList.first
//                           : null;

//                       return Container(
//                         padding: const EdgeInsets.all(16),
//                         decoration: BoxDecoration(
//                           color: Colors.white.withOpacity(0.03),
//                           borderRadius: BorderRadius.circular(16),
//                           border: Border.all(
//                               color: Colors.white.withOpacity(0.07)),
//                         ),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Row(
//                               children: [
//                                 // Avatar
//                                 Container(
//                                   width: 44, height: 44,
//                                   decoration: BoxDecoration(
//                                     color: AppColors.purple
//                                         .withOpacity(0.2),
//                                     borderRadius:
//                                     BorderRadius.circular(14),
//                                   ),
//                                   child: Center(
//                                     child: Text(
//                                         item['nama'][0].toUpperCase(),
//                                         style: GoogleFonts.dmSerifDisplay(
//                                             fontSize: 18,
//                                             color: Colors.purpleAccent)),
//                                   ),
//                                 ),
//                                 const SizedBox(width: 14),

//                                 // Info
//                                 Expanded(
//                                   child: Column(
//                                     crossAxisAlignment:
//                                     CrossAxisAlignment.start,
//                                     children: [
//                                       Text(item['nama'],
//                                           style: const TextStyle(
//                                               color: AppColors.textPrimary,
//                                               fontWeight: FontWeight.w600,
//                                               fontSize: 14)),
//                                       const SizedBox(height: 3),
//                                       Text(
//                                           item['no_hp'] ??
//                                               'Belum ada no. HP',
//                                           style: TextStyle(
//                                               fontSize: 12,
//                                               color:
//                                               AppColors.textSecondary)),
//                                     ],
//                                   ),
//                                 ),

//                                 // Action buttons
//                                 Row(
//                                   mainAxisSize: MainAxisSize.min,
//                                   children: [
//                                     GestureDetector(
//                                       onTap: () => _showEditSheet(item),
//                                       child: Container(
//                                         width: 34, height: 34,
//                                         decoration: BoxDecoration(
//                                           color: AppColors.purple
//                                               .withOpacity(0.15),
//                                           borderRadius:
//                                           BorderRadius.circular(10),
//                                         ),
//                                         child: const Icon(
//                                             Icons.edit_outlined,
//                                             color: Colors.purpleAccent,
//                                             size: 16),
//                                       ),
//                                     ),
//                                     const SizedBox(width: 8),
//                                     GestureDetector(
//                                       onTap: () => _hapus(item),
//                                       child: Container(
//                                         width: 34, height: 34,
//                                         decoration: BoxDecoration(
//                                           color: Colors.red
//                                               .withOpacity(0.12),
//                                           borderRadius:
//                                           BorderRadius.circular(10),
//                                         ),
//                                         child: const Icon(
//                                             Icons.delete_outline_rounded,
//                                             color: Colors.red,
//                                             size: 16),
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ],
//                             ),

//                             // Info santri terhubung
//                             if (santri != null) ...[
//                               const SizedBox(height: 10),
//                               Container(
//                                 padding: const EdgeInsets.symmetric(
//                                     horizontal: 10, vertical: 8),
//                                 decoration: BoxDecoration(
//                                   color: AppColors.green.withOpacity(0.08),
//                                   borderRadius: BorderRadius.circular(10),
//                                   border: Border.all(
//                                       color: AppColors.green
//                                           .withOpacity(0.2)),
//                                 ),
//                                 child: Row(children: [
//                                   Icon(Icons.link_rounded,
//                                       color: AppColors.greenLight,
//                                       size: 14),
//                                   const SizedBox(width: 8),
//                                   Text(
//                                     'Santri: ${santri['nama']} · ${santri['kelas'] ?? '-'}',
//                                     style: TextStyle(
//                                         fontSize: 11,
//                                         color: AppColors.greenLight,
//                                         fontWeight: FontWeight.w500),
//                                   ),
//                                 ]),
//                               ),
//                             ] else ...[
//                               const SizedBox(height: 10),
//                               Container(
//                                 padding: const EdgeInsets.symmetric(
//                                     horizontal: 10, vertical: 8),
//                                 decoration: BoxDecoration(
//                                   color: Colors.orange.withOpacity(0.06),
//                                   borderRadius: BorderRadius.circular(10),
//                                   border: Border.all(
//                                       color: Colors.orange.withOpacity(0.15)),
//                                 ),
//                                 child: Row(children: [
//                                   Icon(Icons.link_off_rounded,
//                                       color: Colors.orange.shade300,
//                                       size: 14),
//                                   const SizedBox(width: 8),
//                                   Text('Belum terhubung ke santri',
//                                       style: TextStyle(
//                                           fontSize: 11,
//                                           color: Colors.orange.shade300)),
//                                 ]),
//                               ),
//                             ],
//                           ],
//                         ),
//                       );
//                     },
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//       floatingActionButton: FloatingActionButton.extended(
//         onPressed: () async {
//           await Navigator.push(context,
//               MaterialPageRoute(
//                   builder: (_) =>
//                   const FormUserScreen(role: 'orang_tua')));
//           _load();
//         },
//         backgroundColor: AppColors.gold,
//         foregroundColor: AppColors.bg,
//         icon: const Icon(Icons.add_rounded),
//         label: Text('Tambah Orang Tua',
//             style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
//       ),
//     );
//   }
// }

// // Bottom Sheet Edit Orang Tua
// class EditOrangTuaSheet extends StatefulWidget {
//   final Map<String, dynamic> item;
//   final VoidCallback onSaved;

//   const EditOrangTuaSheet({
//     super.key,
//     required this.item,
//     required this.onSaved,
//   });

//   @override
//   State<EditOrangTuaSheet> createState() => _EditOrangTuaSheetState();
// }

// class _EditOrangTuaSheetState extends State<EditOrangTuaSheet> {
//   late TextEditingController _namaController;
//   late TextEditingController _noHpController;
//   final _passwordController = TextEditingController();
//   final _confirmPasswordController = TextEditingController();

//   List<Map<String, dynamic>> _santriList = [];
//   String? _selectedSantriId;
//   bool _isLoading = false;
//   bool _showResetPassword = false;
//   bool _obscurePass = true;
//   bool _obscureConfirm = true;

//   @override
//   void initState() {
//     super.initState();
//     _namaController = TextEditingController(
//         text: widget.item['nama'] ?? '');
//     _noHpController = TextEditingController(
//         text: widget.item['no_hp'] ?? '');

//     // Set santri yang sudah terhubung
//     final santriList = widget.item['santri'] as List? ?? [];
//     _selectedSantriId = santriList.isNotEmpty
//         ? santriList.first['id']
//         : null;

//     _loadSantri();
//   }

//   Future<void> _loadSantri() async {
//     try {
//       // Ambil semua santri yang belum punya ortu ATAU santri ini sendiri
//       final data = await supabase
//           .from('santri')
//           .select('id, nama, kelas, kamar, orang_tua_id')
//           .eq('aktif', true)
//           .order('nama');

//       if (mounted) {
//         setState(() {
//           // Tampilkan santri yang belum punya ortu + santri yang sudah terhubung ke ortu ini
//           _santriList = List<Map<String, dynamic>>.from(data)
//               .where((s) =>
//                   s['orang_tua_id'] == null ||
//                   s['orang_tua_id'] == widget.item['id'])
//               .toList();
//         });
//       }
//     } catch (e) {
//       print('Error load santri: $e');
//     }
//   }

//   Future<void> _simpan() async {
//     if (_namaController.text.isEmpty) {
//       _showSnack('Nama tidak boleh kosong');
//       return;
//     }

//     if (_showResetPassword) {
//       if (_passwordController.text.isEmpty) {
//         _showSnack('Password baru tidak boleh kosong');
//         return;
//       }
//       if (_passwordController.text.length < 6) {
//         _showSnack('Password minimal 6 karakter');
//         return;
//       }
//       if (_passwordController.text != _confirmPasswordController.text) {
//         _showSnack('Konfirmasi password tidak cocok');
//         return;
//       }
//     }

//     setState(() => _isLoading = true);

//     try {
//       // Update profil
//       await supabase.from('profiles').update({
//         'nama': _namaController.text.trim(),
//         'no_hp': _noHpController.text.trim(),
//       }).eq('id', widget.item['id']);

//       // Reset password
//       if (_showResetPassword && _passwordController.text.isNotEmpty) {
//         await supabase.rpc('reset_user_password', params: {
//           'user_id': widget.item['id'],
//           'new_password': _passwordController.text,
//         });
//       }

//       // Update hubungan santri
//       // Putuskan santri lama dulu
//       await supabase
//           .from('santri')
//           .update({'orang_tua_id': null})
//           .eq('orang_tua_id', widget.item['id']);

//       // Hubungkan ke santri baru
//       if (_selectedSantriId != null) {
//         await supabase
//             .from('santri')
//             .update({'orang_tua_id': widget.item['id']})
//             .eq('id', _selectedSantriId!);
//       }

//       if (mounted) {
//         _showSnack('Data orang tua berhasil diperbarui', isSuccess: true);
//         widget.onSaved();
//         Navigator.pop(context);
//       }
//     } catch (e) {
//       if (mounted) {
//         _showSnack('Gagal: ${e.toString().replaceAll('Exception: ', '')}');
//       }
//     } finally {
//       if (mounted) setState(() => _isLoading = false);
//     }
//   }

//   void _showSnack(String msg, {bool isSuccess = false}) {
//     ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//       content: Text(msg),
//       backgroundColor: isSuccess ? AppColors.green : Colors.red.shade900,
//       behavior: SnackBarBehavior.floating,
//       shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(12)),
//     ));
//   }

//   @override
//   void dispose() {
//     _namaController.dispose();
//     _noHpController.dispose();
//     _passwordController.dispose();
//     _confirmPasswordController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: EdgeInsets.fromLTRB(
//           24, 24, 24,
//           MediaQuery.of(context).viewInsets.bottom + 32),
//       decoration: BoxDecoration(
//         color: const Color(0xFF122A1E),
//         borderRadius: const BorderRadius.vertical(
//             top: Radius.circular(24)),
//         border: Border.all(color: Colors.white.withOpacity(0.08)),
//       ),
//       child: SingleChildScrollView(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             // Handle
//             Center(
//               child: Container(
//                 width: 40, height: 4,
//                 decoration: BoxDecoration(
//                     color: Colors.white.withOpacity(0.15),
//                     borderRadius: BorderRadius.circular(2)),
//               ),
//             ),
//             const SizedBox(height: 20),

//             // Title
//             Row(
//               children: [
//                 Container(
//                   width: 40, height: 40,
//                   decoration: BoxDecoration(
//                     color: AppColors.purple.withOpacity(0.2),
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   child: const Icon(Icons.edit_outlined,
//                       color: Colors.purpleAccent, size: 18),
//                 ),
//                 const SizedBox(width: 12),
//                 Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text('Edit Orang Tua',
//                         style: GoogleFonts.dmSerifDisplay(
//                             fontSize: 20,
//                             color: AppColors.textPrimary)),
//                     Text(widget.item['nama'],
//                         style: TextStyle(
//                             fontSize: 11,
//                             color: AppColors.textSecondary)),
//                   ],
//                 ),
//               ],
//             ),

//             const SizedBox(height: 24),

//             // Nama
//             TextField(
//               controller: _namaController,
//               style: const TextStyle(color: AppColors.textPrimary),
//               decoration: const InputDecoration(
//                 labelText: 'Nama Lengkap',
//                 prefixIcon: Icon(Icons.person_outlined,
//                     color: AppColors.textSecondary, size: 20),
//               ),
//             ),
//             const SizedBox(height: 12),

//             // No HP
//             TextField(
//               controller: _noHpController,
//               keyboardType: TextInputType.phone,
//               style: const TextStyle(color: AppColors.textPrimary),
//               decoration: const InputDecoration(
//                 labelText: 'No. HP',
//                 prefixIcon: Icon(Icons.phone_outlined,
//                     color: AppColors.textSecondary, size: 20),
//               ),
//             ),

//             const SizedBox(height: 16),

//             // Pilih santri
//             _SectionLabel(label: 'HUBUNGKAN KE SANTRI'),
//             const SizedBox(height: 10),

//             Container(
//               padding: const EdgeInsets.symmetric(horizontal: 16),
//               decoration: BoxDecoration(
//                 color: Colors.white.withOpacity(0.05),
//                 border: Border.all(
//                     color: Colors.white.withOpacity(0.08)),
//                 borderRadius: BorderRadius.circular(14),
//               ),
//               child: DropdownButtonHideUnderline(
//                 child: DropdownButton<String>(
//                   value: _selectedSantriId,
//                   dropdownColor: AppColors.bgCard,
//                   isExpanded: true,
//                   hint: Text('Pilih santri',
//                       style: TextStyle(
//                           color: AppColors.textSecondary,
//                           fontSize: 14)),
//                   items: [
//                     DropdownMenuItem(
//                       value: null,
//                       child: Text('Tidak dihubungkan',
//                           style: TextStyle(
//                               color: AppColors.textSecondary)),
//                     ),
//                     ..._santriList.map((s) => DropdownMenuItem(
//                       value: s['id'],
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           Text(s['nama'],
//                               style: const TextStyle(
//                                   color: AppColors.textPrimary,
//                                   fontSize: 14)),
//                           Text(
//                             '${s['kelas'] ?? '-'} · ${s['kamar'] ?? '-'}',
//                             style: TextStyle(
//                                 color: AppColors.textSecondary,
//                                 fontSize: 11),
//                           ),
//                         ],
//                       ),
//                     )),
//                   ],
//                   onChanged: (v) =>
//                       setState(() => _selectedSantriId = v),
//                 ),
//               ),
//             ),

//             const SizedBox(height: 16),

//             // Toggle reset password
//             GestureDetector(
//               onTap: () => setState(
//                       () => _showResetPassword = !_showResetPassword),
//               child: Container(
//                 padding: const EdgeInsets.all(14),
//                 decoration: BoxDecoration(
//                   color: _showResetPassword
//                       ? Colors.orange.withOpacity(0.1)
//                       : Colors.white.withOpacity(0.04),
//                   borderRadius: BorderRadius.circular(12),
//                   border: Border.all(
//                     color: _showResetPassword
//                         ? Colors.orange.withOpacity(0.3)
//                         : Colors.white.withOpacity(0.08),
//                   ),
//                 ),
//                 child: Row(
//                   children: [
//                     Icon(
//                       _showResetPassword
//                           ? Icons.lock_open_rounded
//                           : Icons.lock_reset_rounded,
//                       color: _showResetPassword
//                           ? Colors.orange
//                           : AppColors.textSecondary,
//                       size: 18,
//                     ),
//                     const SizedBox(width: 10),
//                     Expanded(
//                       child: Text(
//                         _showResetPassword
//                             ? 'Batalkan reset password'
//                             : 'Reset password orang tua ini',
//                         style: TextStyle(
//                           fontSize: 13,
//                           color: _showResetPassword
//                               ? Colors.orange
//                               : AppColors.textSecondary,
//                           fontWeight: FontWeight.w500,
//                         ),
//                       ),
//                     ),
//                     Icon(
//                       _showResetPassword
//                           ? Icons.keyboard_arrow_up_rounded
//                           : Icons.keyboard_arrow_down_rounded,
//                       color: AppColors.textSecondary,
//                       size: 18,
//                     ),
//                   ],
//                 ),
//               ),
//             ),

//             if (_showResetPassword) ...[
//               const SizedBox(height: 12),
//               TextField(
//                 controller: _passwordController,
//                 obscureText: _obscurePass,
//                 style: const TextStyle(color: AppColors.textPrimary),
//                 decoration: InputDecoration(
//                   labelText: 'Password Baru',
//                   prefixIcon: const Icon(Icons.lock_outlined,
//                       color: AppColors.textSecondary, size: 20),
//                   suffixIcon: IconButton(
//                     icon: Icon(
//                       _obscurePass
//                           ? Icons.visibility_off_outlined
//                           : Icons.visibility_outlined,
//                       color: AppColors.textSecondary, size: 18,
//                     ),
//                     onPressed: () =>
//                         setState(() => _obscurePass = !_obscurePass),
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 12),
//               TextField(
//                 controller: _confirmPasswordController,
//                 obscureText: _obscureConfirm,
//                 style: const TextStyle(color: AppColors.textPrimary),
//                 decoration: InputDecoration(
//                   labelText: 'Konfirmasi Password Baru',
//                   prefixIcon: const Icon(Icons.lock_outlined,
//                       color: AppColors.textSecondary, size: 20),
//                   suffixIcon: IconButton(
//                     icon: Icon(
//                       _obscureConfirm
//                           ? Icons.visibility_off_outlined
//                           : Icons.visibility_outlined,
//                       color: AppColors.textSecondary, size: 18,
//                     ),
//                     onPressed: () => setState(
//                             () => _obscureConfirm = !_obscureConfirm),
//                   ),
//                 ),
//               ),
//             ],

//             const SizedBox(height: 24),

//             SizedBox(
//               height: 52,
//               child: ElevatedButton(
//                 onPressed: _isLoading ? null : _simpan,
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: AppColors.gold,
//                   foregroundColor: AppColors.bg,
//                   shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(14)),
//                   elevation: 0,
//                 ),
//                 child: _isLoading
//                     ? const SizedBox(
//                     width: 20, height: 20,
//                     child: CircularProgressIndicator(
//                         strokeWidth: 2, color: AppColors.bg))
//                     : Text('Simpan Perubahan',
//                     style: GoogleFonts.dmSans(
//                         fontSize: 15,
//                         fontWeight: FontWeight.w600)),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _SectionLabel extends StatelessWidget {
//   final String label;
//   const _SectionLabel({required this.label});

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       children: [
//         Container(
//           width: 3, height: 14,
//           decoration: BoxDecoration(
//               color: AppColors.gold,
//               borderRadius: BorderRadius.circular(2)),
//         ),
//         const SizedBox(width: 8),
//         Text(label,
//             style: TextStyle(
//                 fontSize: 10,
//                 color: AppColors.textSecondary,
//                 letterSpacing: 1.5,
//                 fontWeight: FontWeight.w600)),
//       ],
//     );
//   }
// }