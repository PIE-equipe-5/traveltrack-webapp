-- À appliquer après vérification des droits et politiques existants.
-- Les politiques permissives s'additionnent : toute autre politique INSERT
-- permissive peut autoriser des utilisateurs non administrateurs.
alter table public.quests enable row level security;

grant insert on public.quests to authenticated;

create policy "Admins can create quests"
  on public.quests for insert to authenticated
  with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');
