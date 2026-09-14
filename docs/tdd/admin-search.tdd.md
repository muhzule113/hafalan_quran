# TDD Evidence: Admin Search

## Source plan

Tidak ada `*.plan.md`; user journey diturunkan dari permintaan fitur.

## User journeys

- Sebagai admin, saya ingin mencari santri berdasarkan nama atau metadata yang tampil agar daftar lebih cepat ditemukan.
- Sebagai admin, saya ingin mencari ustadz berdasarkan nama atau nomor HP agar akun lebih cepat ditemukan.
- Sebagai admin, saya ingin melihat keadaan kosong saat tidak ada kecocokan agar tahu bahwa pencarian tidak menghasilkan data.

## Validation

| Guarantee | Test/command | Type | Result |
|---|---|---|---|
| Query kosong atau hanya spasi mengembalikan seluruh data. | `test/admin_search_test.dart` | Unit | PASS |
| Pencarian menggunakan substring dan tidak membedakan huruf besar-kecil. | `test/admin_search_test.dart` | Unit | PASS |
| Field nullable tidak menyebabkan error dan field tambahan dapat dicari. | `test/admin_search_test.dart` | Unit | PASS |
| Tidak ada kecocokan menghasilkan daftar kosong. | `test/admin_search_test.dart` | Unit | PASS |
| Tes baru pertama kali gagal karena helper belum tersedia. | `rtk proxy flutter test test/admin_search_test.dart` | RED | PASS |
| Seluruh suite lulus setelah implementasi. | `rtk proxy flutter test` | GREEN | PASS — 9 tests |
| Coverage command selesai tanpa test failure. | `rtk proxy flutter test --coverage` | Coverage | PASS — global line coverage 1,05% |

## Checkpoint evidence

- `dcaf97c test: add admin search behavior` — RED checkpoint.
- `5616a12 fix: add search to admin student and ustadz lists` — GREEN checkpoint.

## Coverage and known gaps

Coverage global masih 1,05% karena suite yang ada hanya mencakup helper pencarian dan sebagian alur notifikasi. Belum ada mock integration Supabase atau harness E2E Flutter di repository ini; keduanya tidak ditambahkan karena tidak diperlukan untuk pencarian lokal.

`flutter analyze` tidak menemukan error kompilasi pada file yang diubah, tetapi command berakhir non-zero karena laporan lint/info lama di proyek (target file melaporkan 66 info, terutama penggunaan `withOpacity` yang deprecated).
