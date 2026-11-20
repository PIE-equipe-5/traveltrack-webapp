# TravelTrack

> "Donnez un score à votre curiosité." Turns exploring a city into a real-world game — users discover geolocated cultural/food/history quests, validate them with a photo + GPS check, and track their progress across the city.

Flutter frontend (MVVM) + Node.js/Express backend, backed by Supabase.

## Structure

```
traveltrack-webapp/
├── frontend/                    Flutter app (MVVM)
│   └── lib/src/
│       ├── models/               # Quest, FeedItem, ...
│       ├── viewmodels/           # AuthViewModel, ...
│       ├── views/                # Home, Map, Feed, QuestsList, Search, Profile, AddQuest, TripDetail
│       │   └── auth/              # Login, Register
│       ├── widgets/               # Shared widgets (QuestCard, ...)
│       ├── navigation/            # go_router config + tab shell
│       └── services/
│           ├── auth_service.dart
│           ├── supabase_client.dart
│           └── data/               # Mock data (pre-backend-integration)
└── backend/                     Node.js/Express — Supabase (service role) + Render deployment
    └── src/
        ├── routes/                # trips, ...
        ├── middleware/            # requireAuth
        └── lib/                    # Supabase client
```

## Getting started

### Prerequisites
- Node.js 18+
- Flutter SDK (stable channel) + Android Studio / Xcode (for device/emulator)
- A [Supabase](https://supabase.com) project

### Backend

```bash
cd backend
cp .env.example .env   # fill in your Supabase credentials
npm install
npm run dev
```

### Frontend

```bash
cd frontend
cp .env.example .env   # fill in your Supabase credentials + API URL
flutter pub get
flutter run   # pick an Android/iOS device or emulator
```

## Map

The map is rendered natively with [flutter_map](https://pub.dev/packages/flutter_map) (`latlong2` for coordinates) — no WebView involved.

## Environment variables

| Variable | Where | Description |
|---|---|---|
| `SUPABASE_URL` | backend + frontend | Supabase project URL |
| `SUPABASE_SERVICE_ROLE_KEY` | backend only | Service role key (never expose to client) |
| `SUPABASE_ANON_KEY` | frontend only | Public anon key |
| `ALLOWED_ORIGIN` | backend | CORS allowed origin |
| `PORT` | backend | Backend listen port (defaults to `3000`) |

## Deploy (backend → Render)

Push the repo and connect `backend/` as a Render Web Service. Set env vars in the Render dashboard. The `render.yaml` in `backend/` documents the expected configuration.

The frontend reads quests directly from Supabase using the signed-in user's
session; it does not need the Express backend for quest list or detail pages.
Configure `SUPABASE_URL` and `SUPABASE_ANON_KEY` in Vercel and redeploy after
changes. Never put the service role key in the frontend.

Before enabling direct access, inspect the existing `quests` grants and RLS
policies in Supabase. Authenticated users need `SELECT` permission and a
matching RLS policy. For a table intended to expose all quests to every
authenticated user, the following SQL can be applied in the Supabase SQL
editor after checking for conflicting existing policies:

```sql
alter table public.quests enable row level security;
grant select on public.quests to authenticated;
create policy "Authenticated users can read quests"
  on public.quests for select to authenticated using (true);
```

This policy grants read access to every row, not write access. Other existing
permissive policies and grants can still allow anonymous access or writes;
review them separately. Enabling RLS may affect other existing clients.
If authenticated users see no quests, check the table data and RLS policies;
an empty response can also mean the current user cannot see any rows.
