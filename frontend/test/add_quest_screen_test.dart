import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:traveltrack/src/models/quest.dart';
import 'package:traveltrack/src/services/auth_service.dart';
import 'package:traveltrack/src/viewmodels/auth_viewmodel.dart';
import 'package:traveltrack/src/views/add_quest_screen.dart';

class _FakeAuthService extends AuthService {
  final changes = StreamController<AuthState>.broadcast();
  Session? session;

  @override
  User? get currentUser => session?.user;
  @override
  Session? get currentSession => session;
  @override
  Stream<AuthState> get authStateChanges => changes.stream;
}

Finder _field(String label) => find.widgetWithText(TextFormField, label);

Future<void> _enter(WidgetTester tester, String label, String value) async {
  final finder = _field(label);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.enterText(finder, value);
}

Future<void> _submit(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Ajouter la quête'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ajouter la quête'));
  await tester.pumpAndSettle();
}

GoRouter _router(
  Future<void> Function(NewQuest) create, {
  String initialLocation = '/new',
}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => Scaffold(
        body: TextButton(
          onPressed: () => context.push('/new'),
          child: const Text('Ouvrir'),
        ),
      ),
    ),
    GoRoute(
      path: '/new',
      builder: (context, state) => AddQuestScreen(createQuest: create),
    ),
    GoRoute(
      path: '/quests',
      builder: (context, state) => const Scaffold(body: Text('Liste')),
    ),
  ],
);

void main() {
  test(
    'le rôle admin provient uniquement des métadonnées applicatives',
    () async {
      final service = _FakeAuthService();
      final auth = AuthViewModel(authService: service);
      User user(Map<String, dynamic> app, Map<String, dynamic> metadata) =>
          User(
            id: 'id',
            appMetadata: app,
            userMetadata: metadata,
            aud: 'authenticated',
            createdAt: '2026-01-01',
          );
      Session session(User user) =>
          Session(accessToken: 'test', tokenType: 'bearer', user: user);

      expect(auth.isAdmin, isFalse);
      service.session = session(user({}, {'role': 'admin'}));
      expect(auth.isAdmin, isFalse);
      service.session = session(user({'role': 'admin'}, {}));
      expect(auth.isAdmin, isTrue);
      auth.dispose();
      await service.changes.close();
    },
  );

  testWidgets('valide les champs et envoie les valeurs correctes', (
    tester,
  ) async {
    NewQuest? sent;
    final router = _router((quest) async => sent = quest);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await _submit(tester);
    expect(sent, isNull);
    expect(find.text('Ce champ est obligatoire.'), findsWidgets);

    await _enter(tester, 'Titre *', '  Nouvelle quête  ');
    await _enter(tester, 'Adresse de départ *', '  Paris  ');
    await _enter(tester, 'Latitude *', '91');
    await _enter(tester, 'Longitude *', '2,5');
    await _enter(tester, 'Rayon de validation en mètres *', '0');
    await _submit(tester);
    expect(sent, isNull);
    expect(find.text('Saisis un nombre entre -90.0 et 90.0.'), findsOneWidget);
    expect(
      find.text('Saisis un entier entre 1 et 2147483647.'),
      findsOneWidget,
    );

    await _enter(tester, 'Latitude *', '48,5');
    await _enter(tester, 'Rayon de validation en mètres *', '125');
    await _enter(tester, 'XP *', '50');
    await _enter(tester, 'Description (facultatif)', 'Description');
    await _enter(
      tester,
      'URL de l’image (facultatif)',
      'https://example.com/image.jpg',
    );
    await _submit(tester);
    expect(find.text('Liste'), findsOneWidget);
    expect(sent?.toJson(), {
      'title': 'Nouvelle quête',
      'category': 'histoire',
      'description': 'Description',
      'xp': 50,
      'image_url': 'https://example.com/image.jpg',
      'lat': 48.5,
      'lng': 2.5,
      'start_address': 'Paris',
      'validation_radius_meters': 125,
    });
  });

  testWidgets('une erreur de sauvegarde laisse le formulaire et les données', (
    tester,
  ) async {
    final router = _router((quest) async => throw StateError('refusé'));
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await _enter(tester, 'Titre *', 'Quête');
    await _enter(tester, 'Adresse de départ *', 'Paris');
    await _enter(tester, 'Latitude *', '48');
    await _enter(tester, 'Longitude *', '2');
    await _submit(tester);
    expect(
      find.text(
        'Impossible d’ajouter la quête. Vérifie tes droits et réessaie.',
      ),
      findsOneWidget,
    );
    expect(find.text('Quête'), findsOneWidget);
    expect(find.text('Ajouter la quête'), findsOneWidget);
  });

  testWidgets('empêche les doubles envois et revient à la liste', (
    tester,
  ) async {
    final pending = Completer<void>();
    var calls = 0;
    final router = _router((quest) {
      calls++;
      return pending.future;
    }, initialLocation: '/');
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    await _enter(tester, 'Titre *', 'Quête');
    await _enter(tester, 'Adresse de départ *', 'Paris');
    await _enter(tester, 'Latitude *', '48');
    await _enter(tester, 'Longitude *', '2');
    await _submit(tester);
    expect(calls, 1);
    expect(find.text('Enregistrement...'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Ouvrir'), findsOneWidget);
  });
}
