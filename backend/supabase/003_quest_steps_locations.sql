-- Migration 003 — à exécuter UNE FOIS dans le SQL editor de Supabase, APRÈS 002.
--
-- Chaque étape de la roadmap devient un point à atteindre :
--   quest_steps : step_number → title → description → position (lat, lng, rayon)
--   quest_step_completions : étapes validées au GPS par chaque joueur, dans l'ordre.
--
-- La table quest_steps est reconstruite pour afficher ses colonnes dans cet ordre
-- dans Supabase (Postgres ne sait pas réordonner des colonnes existantes). Les
-- étapes existantes sont conservées, avec leur identifiant.
--
-- Une seule transaction : en cas d'erreur, rien n'est modifié.

begin;

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'quest_steps' and column_name = 'step_number'
  ) then
    raise exception 'La migration 003 a déjà été appliquée.';
  end if;
end $$;

-- ============================================================================
-- 1. Nouvelle table des étapes
-- ============================================================================

create table quest_steps_rebuilt (
  id                       uuid primary key default gen_random_uuid(),
  quest_id                 uuid not null references quests (id) on delete cascade,
  -- Ordre de l'étape dans la roadmap, à partir de 1.
  step_number              integer not null check (step_number >= 1),
  title                    text not null check (length(btrim(title)) > 0),
  description              text not null check (length(btrim(description)) > 0),
  -- Position à atteindre pour valider l'étape.
  lat                      double precision not null check (lat between -90 and 90),
  lng                      double precision not null check (lng between -180 and 180),
  validation_radius_meters integer not null default 100 check (validation_radius_meters > 0),
  created_at               timestamptz not null default now(),
  -- Différable : les décalages de numéros (insertion / suppression) passent
  -- temporairement par des doublons, vérifiés seulement à la fin de la transaction.
  constraint quest_steps_rebuilt_quest_step_number_unique
    unique (quest_id, step_number) deferrable initially deferred
);

-- Étapes existantes : en attendant leurs vraies valeurs, le titre reprend le
-- numéro et la position reprend le point de validation de la quête.
insert into quest_steps_rebuilt (
  id, quest_id, step_number, title, description, lat, lng, validation_radius_meters, created_at
)
select
  step.id,
  step.quest_id,
  step.position,
  'Étape ' || step.position,
  step.description,
  quest.lat,
  quest.lng,
  quest.validation_radius_meters,
  step.created_at
from quest_steps step
join quests quest on quest.id = step.quest_id;

-- Les fonctions renvoient le type de l'ancienne table : on les supprime avant elle.
drop function if exists insert_quest_step(uuid, text, integer);
drop function if exists delete_quest_step(uuid, uuid);
drop table quest_steps;

alter table quest_steps_rebuilt rename to quest_steps;
alter table quest_steps rename constraint quest_steps_rebuilt_pkey to quest_steps_pkey;
alter table quest_steps rename constraint quest_steps_rebuilt_quest_id_fkey to quest_steps_quest_id_fkey;
alter table quest_steps rename constraint quest_steps_rebuilt_quest_step_number_unique
  to quest_steps_quest_step_number_unique;

-- ============================================================================
-- 2. Titres et positions des étapes des quêtes de test (à relire par l'équipe)
-- ============================================================================

update quest_steps step
set title = seed_step.title, lat = seed_step.lat, lng = seed_step.lng
from quests quest, (values
  ('Découvre la Tour Eiffel', 1, 'Parvis du Trocadéro', 48.8616, 2.2893),
  ('Découvre la Tour Eiffel', 2, 'Pont d''Iéna', 48.8597, 2.2925),
  ('Découvre la Tour Eiffel', 3, 'Pied de la Tour Eiffel', 48.8584, 2.2945),
  ('Balade au Louvre', 1, 'Jardin du Palais-Royal', 48.8650, 2.3376),
  ('Balade au Louvre', 2, 'Passage Richelieu', 48.8618, 2.3363),
  ('Balade au Louvre', 3, 'Pyramide du Louvre', 48.8606, 2.3376),
  ('Pique-nique aux Tuileries', 1, 'Grille de la Concorde', 48.8656, 2.3226),
  ('Pique-nique aux Tuileries', 2, 'Grand bassin octogonal', 48.8641, 2.3247),
  ('Pique-nique aux Tuileries', 3, 'Ton spot de pique-nique', 48.8634, 2.3275),
  ('Croissant chez le boulanger', 1, 'Fontaine Saint-Michel', 48.8532, 2.3440),
  ('Croissant chez le boulanger', 2, 'Pont Saint-Michel', 48.8536, 2.3456),
  ('Croissant chez le boulanger', 3, 'Parvis de Notre-Dame', 48.8530, 2.3499),
  ('Coucher de soleil à Montmartre', 1, 'Square Louise-Michel', 48.8838, 2.3431),
  ('Coucher de soleil à Montmartre', 2, 'Escaliers de la butte', 48.8852, 2.3427),
  ('Coucher de soleil à Montmartre', 3, 'Marches du Sacré-Cœur', 48.8867, 2.3431)
) as seed_step (quest_title, step_number, title, lat, lng)
where quest.id = step.quest_id
  and quest.title = seed_step.quest_title
  and step.step_number = seed_step.step_number;

comment on column quest_steps.step_number is 'Ordre de l''étape dans la roadmap, à partir de 1.';
comment on column quest_steps.lat is 'Latitude du point à atteindre pour valider l''étape.';
comment on column quest_steps.lng is 'Longitude du point à atteindre pour valider l''étape.';
comment on column quest_steps.validation_radius_meters is
  'Distance maximale, en mètres, entre le joueur et le point de l''étape.';

-- ============================================================================
-- 3. Fonctions d'ajout et de suppression d'étape (renumérotation automatique)
-- ============================================================================

-- Ajoute une étape. Sans numéro, elle est placée en dernier ; sinon les étapes
-- suivantes sont décalées d'un cran.
create function insert_quest_step(
  target_quest_id uuid,
  step_title text,
  step_description text,
  step_lat double precision,
  step_lng double precision,
  step_validation_radius_meters integer default 100,
  requested_step_number integer default null
)
returns quest_steps
language plpgsql
set search_path = public
as $$
declare
  current_step_count integer;
  final_step_number integer;
  inserted_step quest_steps;
begin
  -- Verrou sur la quête : deux modifications simultanées de sa roadmap
  -- s'exécutent l'une après l'autre.
  perform 1 from quests where id = target_quest_id for update;
  if not found then
    raise exception 'quest_not_found' using errcode = 'P0002';
  end if;

  select count(*) into current_step_count from quest_steps where quest_id = target_quest_id;
  final_step_number := coalesce(requested_step_number, current_step_count + 1);

  if final_step_number < 1 or final_step_number > current_step_count + 1 then
    raise exception 'invalid_step_number' using errcode = '22023';
  end if;

  update quest_steps
    set step_number = step_number + 1
    where quest_id = target_quest_id and step_number >= final_step_number;

  insert into quest_steps (quest_id, step_number, title, description, lat, lng, validation_radius_meters)
    values (
      target_quest_id,
      final_step_number,
      btrim(step_title),
      btrim(step_description),
      step_lat,
      step_lng,
      coalesce(step_validation_radius_meters, 100)
    )
    returning * into inserted_step;

  return inserted_step;
end;
$$;

-- Supprime une étape et resserre les numéros des étapes suivantes.
create function delete_quest_step(target_quest_id uuid, target_step_id uuid)
returns void
language plpgsql
set search_path = public
as $$
declare
  deleted_step_number integer;
begin
  perform 1 from quests where id = target_quest_id for update;
  if not found then
    raise exception 'quest_not_found' using errcode = 'P0002';
  end if;

  delete from quest_steps
    where id = target_step_id and quest_id = target_quest_id
    returning step_number into deleted_step_number;

  if deleted_step_number is null then
    raise exception 'step_not_found' using errcode = 'P0002';
  end if;

  update quest_steps
    set step_number = step_number - 1
    where quest_id = target_quest_id and step_number > deleted_step_number;
end;
$$;

-- Seules les routes admin de l'API (clé service role) modifient la roadmap.
revoke execute on function insert_quest_step(uuid, text, text, double precision, double precision, integer, integer)
  from public, anon, authenticated;
revoke execute on function delete_quest_step(uuid, uuid) from public, anon, authenticated;
grant execute on function insert_quest_step(uuid, text, text, double precision, double precision, integer, integer)
  to service_role;
grant execute on function delete_quest_step(uuid, uuid) to service_role;

-- ============================================================================
-- 4. Étapes validées par chaque joueur
-- ============================================================================

create table quest_step_completions (
  id                       uuid primary key default gen_random_uuid(),
  user_id                  uuid not null references auth.users (id) on delete cascade,
  quest_id                 uuid not null references quests (id) on delete cascade,
  step_id                  uuid not null references quest_steps (id) on delete cascade,
  -- Seule la distance au point de l'étape est conservée, jamais la position
  -- du joueur (minimisation des données, RGPD).
  location_distance_meters double precision not null check (location_distance_meters >= 0),
  created_at               timestamptz not null default now(),
  constraint quest_step_completions_user_step_unique unique (user_id, step_id)
);

create index quest_step_completions_user_quest_idx on quest_step_completions (user_id, quest_id);

-- ============================================================================
-- 5. Sécurité : aucune policy, donc aucun accès avec la clé anon
-- ============================================================================

alter table quest_steps enable row level security;
alter table quest_step_completions enable row level security;

commit;
