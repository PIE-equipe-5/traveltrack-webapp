# TravelTrack (Flutter)

Flutter frontend for TravelTrack — bottom-tab navigation, a FlutterMap view with OpenFreeMap vector tiles, and Supabase auth/data via [supabase_flutter](https://pub.dev/packages/supabase_flutter).

The map style is defined in `assets/map_style.json`. It shows roads, street and city names, water and green areas without buildings or points of interest. Labels appear at different zoom levels. OpenFreeMap uses OpenStreetMap data and does not require an API key.

## Getting started

```bash
cp .env.example .env   # fill in your Supabase credentials + API URL
flutter pub get
flutter run
```

## Structure

```
lib/
└── src/
    ├── services/     # Supabase client
    ├── navigation/   # go_router config + tab shell
    ├── models/
    ├── viewmodels/
    └── views/        # Home, Map, TripDetail
```
