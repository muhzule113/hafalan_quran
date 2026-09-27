alter table public.santri
  add column if not exists ustadz_id uuid;

create index if not exists santri_ustadz_id_idx
  on public.santri (ustadz_id);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.santri'::regclass
      and conname = 'santri_ustadz_id_fkey'
  ) then
    alter table public.santri
      add constraint santri_ustadz_id_fkey
      foreign key (ustadz_id)
      references public.profiles(id)
      on delete set null
      not valid;
  end if;
end
$$;

create or replace function public.auth_user_has_role(required_role text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and role = required_role
  );
$$;

revoke all on function public.auth_user_has_role(text) from public;
grant execute on function public.auth_user_has_role(text) to authenticated;

alter table public.santri enable row level security;
alter table public.setoran enable row level security;
alter table public.target_hafalan enable row level security;
alter table public.progress_hafalan enable row level security;

drop policy if exists "santri_assignment_select_restriction" on public.santri;
create policy "santri_assignment_select_restriction"
on public.santri
as restrictive
for select
to authenticated
using (
  public.auth_user_has_role('admin')
  or orang_tua_id = auth.uid()
  or (
    public.auth_user_has_role('ustadz')
    and ustadz_id = auth.uid()
  )
);

drop policy if exists "santri_assignment_insert_restriction" on public.santri;
create policy "santri_assignment_insert_restriction"
on public.santri
as restrictive
for insert
to authenticated
with check (public.auth_user_has_role('admin'));

drop policy if exists "santri_assignment_update_restriction" on public.santri;
create policy "santri_assignment_update_restriction"
on public.santri
as restrictive
for update
to authenticated
using (public.auth_user_has_role('admin'))
with check (public.auth_user_has_role('admin'));

drop policy if exists "santri_assignment_delete_restriction" on public.santri;
create policy "santri_assignment_delete_restriction"
on public.santri
as restrictive
for delete
to authenticated
using (public.auth_user_has_role('admin'));

drop policy if exists "setoran_assignment_select_restriction" on public.setoran;
create policy "setoran_assignment_select_restriction"
on public.setoran
as restrictive
for select
to authenticated
using (
  public.auth_user_has_role('admin')
  or exists (
    select 1
    from public.santri
    where santri.id = setoran.santri_id
      and santri.orang_tua_id = auth.uid()
  )
  or (
    public.auth_user_has_role('ustadz')
    and exists (
      select 1
      from public.santri
      where santri.id = setoran.santri_id
        and santri.ustadz_id = auth.uid()
    )
  )
);

drop policy if exists "setoran_assignment_insert_restriction" on public.setoran;
create policy "setoran_assignment_insert_restriction"
on public.setoran
as restrictive
for insert
to authenticated
with check (
  public.auth_user_has_role('admin')
  or (
    public.auth_user_has_role('ustadz')
    and ustadz_id = auth.uid()
    and exists (
      select 1
      from public.santri
      where santri.id = setoran.santri_id
        and santri.ustadz_id = auth.uid()
    )
  )
);

drop policy if exists "setoran_assignment_update_restriction" on public.setoran;
create policy "setoran_assignment_update_restriction"
on public.setoran
as restrictive
for update
to authenticated
using (
  public.auth_user_has_role('admin')
  or exists (
    select 1
    from public.santri
    where santri.id = setoran.santri_id
      and santri.ustadz_id = auth.uid()
  )
)
with check (
  public.auth_user_has_role('admin')
  or exists (
    select 1
    from public.santri
    where santri.id = setoran.santri_id
      and santri.ustadz_id = auth.uid()
  )
);

drop policy if exists "setoran_assignment_delete_restriction" on public.setoran;
create policy "setoran_assignment_delete_restriction"
on public.setoran
as restrictive
for delete
to authenticated
using (
  public.auth_user_has_role('admin')
  or exists (
    select 1
    from public.santri
    where santri.id = setoran.santri_id
      and santri.ustadz_id = auth.uid()
  )
);

drop policy if exists "target_assignment_select_restriction" on public.target_hafalan;
create policy "target_assignment_select_restriction"
on public.target_hafalan
as restrictive
for select
to authenticated
using (
  public.auth_user_has_role('admin')
  or exists (
    select 1
    from public.santri
    where santri.id = target_hafalan.santri_id
      and (
        santri.orang_tua_id = auth.uid()
        or santri.ustadz_id = auth.uid()
      )
  )
);

drop policy if exists "target_assignment_insert_restriction" on public.target_hafalan;
create policy "target_assignment_insert_restriction"
on public.target_hafalan
as restrictive
for insert
to authenticated
with check (
  public.auth_user_has_role('admin')
  or (
    public.auth_user_has_role('ustadz')
    and ustadz_id = auth.uid()
    and exists (
      select 1
      from public.santri
      where santri.id = target_hafalan.santri_id
        and santri.ustadz_id = auth.uid()
    )
  )
);

drop policy if exists "target_assignment_update_restriction" on public.target_hafalan;
create policy "target_assignment_update_restriction"
on public.target_hafalan
as restrictive
for update
to authenticated
using (
  public.auth_user_has_role('admin')
  or exists (
    select 1
    from public.santri
    where santri.id = target_hafalan.santri_id
      and santri.ustadz_id = auth.uid()
  )
)
with check (
  public.auth_user_has_role('admin')
  or exists (
    select 1
    from public.santri
    where santri.id = target_hafalan.santri_id
      and santri.ustadz_id = auth.uid()
  )
);

drop policy if exists "target_assignment_delete_restriction" on public.target_hafalan;
create policy "target_assignment_delete_restriction"
on public.target_hafalan
as restrictive
for delete
to authenticated
using (
  public.auth_user_has_role('admin')
  or exists (
    select 1
    from public.santri
    where santri.id = target_hafalan.santri_id
      and santri.ustadz_id = auth.uid()
  )
);

drop policy if exists "progress_assignment_select_restriction" on public.progress_hafalan;
create policy "progress_assignment_select_restriction"
on public.progress_hafalan
as restrictive
for select
to authenticated
using (
  public.auth_user_has_role('admin')
  or exists (
    select 1
    from public.santri
    where santri.id = progress_hafalan.santri_id
      and (
        santri.orang_tua_id = auth.uid()
        or santri.ustadz_id = auth.uid()
      )
  )
);

drop policy if exists "progress_assignment_insert_restriction" on public.progress_hafalan;
create policy "progress_assignment_insert_restriction"
on public.progress_hafalan
as restrictive
for insert
to authenticated
with check (
  public.auth_user_has_role('admin')
  or exists (
    select 1
    from public.santri
    where santri.id = progress_hafalan.santri_id
      and santri.ustadz_id = auth.uid()
  )
);

drop policy if exists "progress_assignment_update_restriction" on public.progress_hafalan;
create policy "progress_assignment_update_restriction"
on public.progress_hafalan
as restrictive
for update
to authenticated
using (
  public.auth_user_has_role('admin')
  or exists (
    select 1
    from public.santri
    where santri.id = progress_hafalan.santri_id
      and santri.ustadz_id = auth.uid()
  )
)
with check (
  public.auth_user_has_role('admin')
  or exists (
    select 1
    from public.santri
    where santri.id = progress_hafalan.santri_id
      and santri.ustadz_id = auth.uid()
  )
);

drop policy if exists "progress_assignment_delete_restriction" on public.progress_hafalan;
create policy "progress_assignment_delete_restriction"
on public.progress_hafalan
as restrictive
for delete
to authenticated
using (
  public.auth_user_has_role('admin')
  or exists (
    select 1
    from public.santri
    where santri.id = progress_hafalan.santri_id
      and santri.ustadz_id = auth.uid()
  )
);
