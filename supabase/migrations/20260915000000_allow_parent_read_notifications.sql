grant update (dibaca) on table public.notifikasi to authenticated;

create policy "orang_tua_update_notifikasi_sendiri"
on public.notifikasi
for update
to authenticated
using (auth.uid() = orang_tua_id)
with check (auth.uid() = orang_tua_id);
