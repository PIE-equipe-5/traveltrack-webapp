-- Migration 002 — à exécuter dans le SQL editor de Supabase, APRÈS quests_table.sql.
--
-- Contenu :
--   1. Quêtes : adresse de départ, rayon de validation, catégorie « art », suppression
--      du statut global (la progression devient propre à chaque joueur).
--   2. Roadmap : table quest_steps (une ligne par étape, nombre d'étapes libre) et
--      fonctions insert_quest_step / delete_quest_step qui renumérotent les positions.
--   3. Validation : table quest_completions (une ligne par joueur et par quête).
--   4. Stockage : bucket privé quest-proofs pour les photos de preuve.
--   5. Sécurité : RLS activée partout. L'app passe par l'API Node (clé service role),
--      la clé anon n'a donc accès à rien.
--
-- Le script est rejouable et s'exécute dans une seule transaction : en cas d'erreur,
-- rien n'est modifié.

begin;

-- ============================================================================
-- 1. Quêtes
-- ============================================================================

alter table quests add column if not exists start_address text;
alter table quests add column if not exists validation_radius_meters integer not null default 100;

alter table quests drop constraint if exists quests_validation_radius_meters_positive;
alter table quests add constraint quests_validation_radius_meters_positive
  check (validation_radius_meters > 0);

alter table quests drop constraint if exists quests_category_check;
alter table quests add constraint quests_category_check
  check (category in ('histoire', 'gastro', 'social', 'sport', 'nature', 'culture', 'art'));

-- Le statut était partagé par tous les joueurs : il est remplacé par quest_completions.
alter table quests drop column if exists status;

comment on column quests.start_address is
  'Point de départ de la quête, en texte (rue, lieu...). Pas de coordonnées.';
comment on column quests.lat is
  'Latitude du point de validation : le joueur doit s''y trouver pour valider la quête.';
comment on column quests.lng is
  'Longitude du point de validation : le joueur doit s''y trouver pour valider la quête.';
comment on column quests.validation_radius_meters is
  'Distance maximale, en mètres, entre le joueur et le point de validation.';

-- Contenu des 5 quêtes de test (seed de quests_table.sql). Textes à relire par l'équipe.
update quests set start_address = 'Place du Trocadéro, 75016 Paris', validation_radius_meters = 150
  where title = 'Découvre la Tour Eiffel';
update quests set start_address = 'Jardin du Palais-Royal, 75001 Paris', validation_radius_meters = 150
  where title = 'Balade au Louvre';
update quests set start_address = 'Place de la Concorde, 75008 Paris', validation_radius_meters = 300
  where title = 'Pique-nique aux Tuileries';
update quests set start_address = 'Place Saint-Michel, 75006 Paris', validation_radius_meters = 200
  where title = 'Croissant chez le boulanger';
update quests set start_address = 'Place Saint-Pierre, 75018 Paris', validation_radius_meters = 150
  where title = 'Coucher de soleil à Montmartre';

do $$
declare
  quest_titles_without_address text;
begin
  select string_agg(title, ', ') into quest_titles_without_address
  from quests where start_address is null;

  if quest_titles_without_address is not null then
    raise exception 'Ces quêtes n''ont pas d''adresse de départ : %. Ajoute un « update quests set start_address = ... » pour chacune, puis relance le script.',
      quest_titles_without_address;
  end if;
end $$;

alter table quests alter column start_address set not null;

-- ============================================================================
-- 2. Roadmap : étapes des quêtes
-- ============================================================================

create table if not exists quest_steps (
  id          uuid primary key default gen_random_uuid(),
  quest_id    uuid not null references quests (id) on delete cascade,
  position    integer not null check (position >= 1),
  description text not null check (length(btrim(description)) > 0),
  created_at  timestamptz not null default now(),
  -- Différable : les décalages de positions (insertion / suppression) passent
  -- temporairement par des doublons, vérifiés seulement à la fin de la transaction.
  constraint quest_steps_quest_position_unique
    unique (quest_id, position) deferrable initially deferred
);

-- Ajoute une étape. Sans position, elle est placée en dernier ; sinon les étapes
-- suivantes sont décalées d'un cran.
create or replace function insert_quest_step(
  target_quest_id uuid,
  step_description text,
  requested_position integer default null
)
returns quest_steps
language plpgsql
set search_path = public
as $$
declare
  current_step_count integer;
  final_position integer;
  inserted_step quest_steps;
begin
  -- Verrou sur la quête : deux modifications simultanées de sa roadmap
  -- s'exécutent l'une après l'autre.
  perform 1 from quests where id = target_quest_id for update;
  if not found then
    raise exception 'quest_not_found' using errcode = 'P0002';
  end if;

  select count(*) into current_step_count from quest_steps where quest_id = target_quest_id;
  final_position := coalesce(requested_position, current_step_count + 1);

  if final_position < 1 or final_position > current_step_count + 1 then
    raise exception 'invalid_step_position' using errcode = '22023';
  end if;

  update quest_steps
    set position = position + 1
    where quest_id = target_quest_id and position >= final_position;

  insert into quest_steps (quest_id, position, description)
    values (target_quest_id, final_position, btrim(step_description))
    returning * into inserted_step;

  return inserted_step;
end;
$$;

-- Supprime une étape et resserre les positions des étapes suivantes.
create or replace function delete_quest_step(target_quest_id uuid, target_step_id uuid)
returns void
language plpgsql
set search_path = public
as $$
declare
  deleted_position integer;
begin
  perform 1 from quests where id = target_quest_id for update;
  if not found then
    raise exception 'quest_not_found' using errcode = 'P0002';
  end if;

  delete from quest_steps
    where id = target_step_id and quest_id = target_quest_id
    returning position into deleted_position;

  if deleted_position is null then
    raise exception 'step_not_found' using errcode = 'P0002';
  end if;

  update quest_steps
    set position = position - 1
    where quest_id = target_quest_id and position > deleted_position;
end;
$$;

-- Seules les routes admin de l'API (clé service role) modifient la roadmap.
revoke execute on function insert_quest_step(uuid, text, integer) from public, anon, authenticated;
revoke execute on function delete_quest_step(uuid, uuid) from public, anon, authenticated;
grant execute on function insert_quest_step(uuid, text, integer) to service_role;
grant execute on function delete_quest_step(uuid, uuid) to service_role;

-- Étapes des quêtes de test, ajoutées seulement si la quête n'en a encore aucune.
insert into quest_steps (quest_id, position, description)
select quest.id, seed_step.position, seed_step.description
from quests quest
join (values
  ('Découvre la Tour Eiffel', 1, 'Rejoins le parvis du Trocadéro et repère la Tour Eiffel en face de toi.'),
  ('Découvre la Tour Eiffel', 2, 'Descends les jardins du Trocadéro et traverse le pont d''Iéna.'),
  ('Découvre la Tour Eiffel', 3, 'Arrive au pied de la Tour Eiffel et prends ta photo sous la structure.'),
  ('Balade au Louvre', 1, 'Pars du jardin du Palais-Royal et traverse ses arcades.'),
  ('Balade au Louvre', 2, 'Traverse la rue de Rivoli et passe sous le passage Richelieu.'),
  ('Balade au Louvre', 3, 'Rejoins la cour Napoléon et photographie la pyramide.'),
  ('Pique-nique aux Tuileries', 1, 'Entre dans le jardin par la grille de la place de la Concorde.'),
  ('Pique-nique aux Tuileries', 2, 'Longe le grand bassin octogonal et choisis un coin à l''ombre.'),
  ('Pique-nique aux Tuileries', 3, 'Installe-toi pour ton pique-nique et prends une photo de ton spot.'),
  ('Croissant chez le boulanger', 1, 'Pars de la fontaine Saint-Michel.'),
  ('Croissant chez le boulanger', 2, 'Traverse le pont Saint-Michel vers l''île de la Cité.'),
  ('Croissant chez le boulanger', 3, 'Trouve une boulangerie près du parvis de Notre-Dame et photographie ton croissant.'),
  ('Coucher de soleil à Montmartre', 1, 'Rejoins le square Louise-Michel, au pied de la butte.'),
  ('Coucher de soleil à Montmartre', 2, 'Monte les marches, ou prends le funiculaire, jusqu''au Sacré-Cœur.'),
  ('Coucher de soleil à Montmartre', 3, 'Installe-toi sur les marches et photographie le coucher de soleil sur Paris.')
) as seed_step (quest_title, position, description) on seed_step.quest_title = quest.title
where not exists (
  select 1 from quest_steps existing_step where existing_step.quest_id = quest.id
);

-- ============================================================================
-- 3. Validation des quêtes par joueur
-- ============================================================================

create table if not exists quest_completions (
  id                       uuid primary key default gen_random_uuid(),
  user_id                  uuid not null references auth.users (id) on delete cascade,
  quest_id                 uuid not null references quests (id) on delete cascade,
  status                   text not null check (status in ('location_verified', 'completed')),
  -- Seule la distance au point de validation est conservée, jamais la position
  -- du joueur (minimisation des données, RGPD).
  location_distance_meters double precision not null check (location_distance_meters >= 0),
  -- Chemin dans le bucket quest-proofs : {user_id}/{quest_id}.{extension}
  proof_photo_path         text,
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now(),
  constraint quest_completions_user_quest_unique unique (user_id, quest_id),
  constraint quest_completions_completed_requires_photo
    check (status <> 'completed' or proof_photo_path is not null)
);

create index if not exists quest_completions_quest_id_idx on quest_completions (quest_id);

-- ============================================================================
-- 4. Stockage des photos de preuve (privé, 5 Mo max)
-- ============================================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'quest-proofs',
  'quest-proofs',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif']
)
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- ============================================================================
-- 5. Sécurité : aucune policy, donc aucun accès avec la clé anon
-- ============================================================================

alter table quests enable row level security;
alter table quest_steps enable row level security;
alter table quest_completions enable row level security;

commit;
