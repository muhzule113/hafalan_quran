alter table public.notifikasi enable row level security;

grant delete on table public.notifikasi to authenticated;

drop policy if exists "orang_tua_delete_notifikasi_sendiri" on public.notifikasi;
create policy "orang_tua_delete_notifikasi_sendiri"
on public.notifikasi
for delete
to authenticated
using (auth.uid() = orang_tua_id);
