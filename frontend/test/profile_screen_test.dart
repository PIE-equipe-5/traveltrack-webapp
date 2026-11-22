import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:traveltrack/src/services/auth_service.dart';
import 'package:traveltrack/src/viewmodels/auth_viewmodel.dart';
import 'package:traveltrack/src/views/profile_screen.dart';

class _FakeAuthService extends AuthService {
  final changes = StreamController<AuthState>.broadcast();
  User? user;

  @override
  User? get currentUser => user;

  @override
  Stream<AuthState> get authStateChanges => changes.stream;

  void setUser(User? value) {
    user = value;
    changes.add(
      AuthState(
        value == null ? AuthChangeEvent.signedOut : AuthChangeEvent.signedIn,
        value == null
            ? null
            : Session(accessToken: 'test', tokenType: 'bearer', user: value),
      ),
    );
  }
}

User _user(String id, String email, Map<String, dynamic>? metadata) => User(
  id: id,
  email: email,
  userMetadata: metadata,
  appMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-01-01T00:00:00Z',
);

void main() {
  testWidgets('affiche le compte courant et suit les changements de session', (
    tester,
  ) async {
    final service = _FakeAuthService()
      ..user = _user('1', 'alice@example.com', {
        'first_name': 'Alice',
        'last_name': 'Martin',
      });
    final auth = AuthViewModel(authService: service);
    addTearDown(() async {
      auth.dispose();
      await service.changes.close();
    });

    await tester.pumpWidget(MaterialApp(home: ProfileScreen(auth: auth)));
    expect(find.text('Alice Martin'), findsOneWidget);
    expect(find.text('alice@example.com'), findsOneWidget);
    expect(find.text('Yacine B.'), findsNothing);
    expect(find.text('Statistiques non disponibles'), findsOneWidget);

    service.setUser(_user('2', 'bob@example.com', {'full_name': 'Bob Dupont'}));
    await tester.pumpAndSettle();
    expect(find.text('Bob Dupont'), findsOneWidget);
    expect(find.text('bob@example.com'), findsOneWidget);
    expect(find.text('Alice Martin'), findsNothing);
    expect(find.text('alice@example.com'), findsNothing);

    service.setUser(_user('3', 'sans-nom@example.com', null));
    await tester.pumpAndSettle();
    expect(find.text('Mon profil'), findsOneWidget);
    expect(find.text('sans-nom@example.com'), findsOneWidget);
    expect(find.byIcon(Icons.person), findsOneWidget);

    service.setUser(null);
    await tester.pumpAndSettle();
    expect(find.text('Aucun compte connecté.'), findsOneWidget);
    expect(find.text('sans-nom@example.com'), findsNothing);
  });
}
