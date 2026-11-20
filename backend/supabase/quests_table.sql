-- Schéma pour une nouvelle table quests. Cette commande ne modifie pas une
-- table existante ; une migration séparée est nécessaire dans ce cas.
create table if not exists quests (
  id          uuid primary key default gen_random_uuid(),
  title       text not null,
  category    text not null check (category in ('histoire', 'gastro', 'social', 'sport', 'nature', 'culture', 'art')),
  description text,
  xp          integer not null default 0,
  image_url   text,
  lat         double precision not null,
  lng         double precision not null,
  created_at  timestamptz not null default now(),
  start_address text not null,
  validation_radius_meters integer not null default 100 check (validation_radius_meters > 0)
);

-- Index pour les requêtes de type "quêtes visibles dans le viewport de la map"
create index if not exists quests_lat_lng_idx on quests (lat, lng);

-- Quelques quêtes de test (mêmes coordonnées que le mock frontend, Paris)
insert into quests (title, category, description, xp, image_url, lat, lng, start_address) values
  ('Découvre la Tour Eiffel', 'histoire', 'Rends-toi au pied de la Tour Eiffel et prends une photo.', 50, 'https://picsum.photos/seed/eiffel/400/300', 48.8584, 2.2945, 'Tour Eiffel, Paris'),
  ('Balade au Louvre', 'histoire', 'Visite la pyramide du Louvre et explore ses environs.', 40, 'https://picsum.photos/seed/louvre/400/300', 48.8606, 2.3376, 'Musée du Louvre, Paris'),
  ('Pique-nique aux Tuileries', 'nature', 'Profite d''un moment de calme dans le jardin des Tuileries.', 30, 'https://picsum.photos/seed/tuileries/400/300', 48.8634, 2.3275, 'Jardin des Tuileries, Paris'),
  ('Croissant chez le boulanger', 'gastro', 'Goûte un authentique croissant parisien.', 20, 'https://picsum.photos/seed/croissant/400/300', 48.8530, 2.3499, 'Paris'),
  ('Coucher de soleil à Montmartre', 'social', 'Admire la vue depuis les marches du Sacré-Cœur.', 60, 'https://picsum.photos/seed/montmartre/400/300', 48.8867, 2.3431, 'Sacré-Cœur, Paris');
