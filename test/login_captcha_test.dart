import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hafalan_quran/screens/auth/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  Future<void> pumpLogin(
    WidgetTester tester, {
    required Future<String?> Function() captchaTokenProvider,
    required Future<AuthResponse> Function({
      required String email,
      required String password,
      required String captchaToken,
    })
    signInWithPassword,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          captchaTokenProvider: captchaTokenProvider,
          signInWithPassword: signInWithPassword,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('form tidak valid tidak meminta token CAPTCHA', (tester) async {
    var captchaCalls = 0;
    var signInCalls = 0;

    await pumpLogin(
      tester,
      captchaTokenProvider: () async {
        captchaCalls++;
        return 'token';
      },
      signInWithPassword:
          ({required email, required password, required captchaToken}) async {
            signInCalls++;
            return AuthResponse();
          },
    );

    await tester.tap(find.text('Masuk'));
    await tester.pump();

    expect(captchaCalls, 0);
    expect(signInCalls, 0);
    expect(find.text('Email tidak boleh kosong'), findsOneWidget);
  });

  testWidgets('token CAPTCHA kosong menghentikan login', (tester) async {
    var signInCalls = 0;

    await pumpLogin(
      tester,
      captchaTokenProvider: () async => '  ',
      signInWithPassword:
          ({required email, required password, required captchaToken}) async {
            signInCalls++;
            return AuthResponse();
          },
    );

    await tester.enterText(find.byType(TextField).at(0), 'user@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.text('Masuk'));
    await tester.pump();

    expect(signInCalls, 0);
    expect(find.text('Verifikasi keamanan gagal, coba lagi'), findsOneWidget);
  });

  testWidgets('konfigurasi CAPTCHA yang hilang menghentikan login', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pump();

    await tester.enterText(find.byType(TextField).at(0), 'user@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.text('Masuk'));
    await tester.pump();

    expect(
      find.text('Verifikasi keamanan belum dikonfigurasi'),
      findsOneWidget,
    );
  });

  testWidgets('token CAPTCHA diteruskan ke Supabase', (tester) async {
    String? receivedToken;

    await pumpLogin(
      tester,
      captchaTokenProvider: () async => 'turnstile-token',
      signInWithPassword:
          ({required email, required password, required captchaToken}) async {
            receivedToken = captchaToken;
            return AuthResponse();
          },
    );

    await tester.enterText(find.byType(TextField).at(0), 'user@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();

    expect(receivedToken, 'turnstile-token');
  });

  testWidgets('captcha_failed menampilkan pesan verifikasi generik', (
    tester,
  ) async {
    await pumpLogin(
      tester,
      captchaTokenProvider: () async => 'turnstile-token',
      signInWithPassword:
          ({required email, required password, required captchaToken}) async {
            throw const AuthException(
              'CAPTCHA verification failed',
              code: 'captcha_failed',
            );
          },
    );

    await tester.enterText(find.byType(TextField).at(0), 'user@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.text('Masuk'));
    await tester.pump();

    expect(find.text('Verifikasi keamanan gagal, coba lagi'), findsOneWidget);
  });

  testWidgets('rapid tap hanya menjalankan satu verifikasi CAPTCHA', (
    tester,
  ) async {
    final tokenCompleter = Completer<String?>();
    var captchaCalls = 0;

    await pumpLogin(
      tester,
      captchaTokenProvider: () {
        captchaCalls++;
        return tokenCompleter.future;
      },
      signInWithPassword:
          ({required email, required password, required captchaToken}) async =>
              AuthResponse(),
    );

    await tester.enterText(find.byType(TextField).at(0), 'user@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    final button = find.byType(ElevatedButton);
    await tester.tap(button);
    await tester.pump();
    await tester.tap(button);
    await tester.pump();

    expect(captchaCalls, 1);

    tokenCompleter.complete('turnstile-token');
    await tester.pumpAndSettle();
  });
}
