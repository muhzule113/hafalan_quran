import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hafalan_quran/screens/auth/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'token Turnstile yang sudah diterima dipakai sekali sebelum refresh',
    () {
      final cache = TurnstileTokenCache();

      cache.store('  pre-issued-token  ');

      expect(cache.take(), 'pre-issued-token');
      expect(cache.take(), isNull);
    },
  );

  const challenge = CaptchaChallenge(
    id: 'challenge-1',
    svg:
        '<svg xmlns="http://www.w3.org/2000/svg" width="320" height="80">'
        '<path d="M0 0h320v80H0z" fill="#ffffff"/></svg>',
  );

  Future<void> pumpLogin(
    WidgetTester tester, {
    Future<CaptchaChallenge> Function()? captchaChallengeProvider,
    Future<bool> Function({
      required String challengeId,
      required String answer,
    })?
    captchaVerifier,
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
          captchaChallengeProvider:
              captchaChallengeProvider ?? () async => challenge,
          captchaVerifier:
              captchaVerifier ??
              ({required challengeId, required answer}) async => true,
          captchaTokenProvider: captchaTokenProvider,
          signInWithPassword: signInWithPassword,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> enterCredentials(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).at(0), 'user@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
  }

  Future<void> tapLogin(WidgetTester tester) async {
    final button = find.byType(ElevatedButton);
    await tester.ensureVisible(button);
    await tester.tap(button);
  }

  testWidgets('form tidak valid tidak meminta CAPTCHA atau token', (
    tester,
  ) async {
    var verifyCalls = 0;
    var captchaCalls = 0;
    var signInCalls = 0;

    await pumpLogin(
      tester,
      captchaVerifier: ({required challengeId, required answer}) async {
        verifyCalls++;
        return true;
      },
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

    await tapLogin(tester);
    await tester.pump();

    expect(verifyCalls, 0);
    expect(captchaCalls, 0);
    expect(signInCalls, 0);
    expect(find.text('Email tidak boleh kosong'), findsOneWidget);
  });

  testWidgets('kode CAPTCHA kosong menghentikan login', (tester) async {
    var verifyCalls = 0;
    var signInCalls = 0;

    await pumpLogin(
      tester,
      captchaVerifier: ({required challengeId, required answer}) async {
        verifyCalls++;
        return true;
      },
      captchaTokenProvider: () async => 'turnstile-token',
      signInWithPassword:
          ({required email, required password, required captchaToken}) async {
            signInCalls++;
            return AuthResponse();
          },
    );

    await enterCredentials(tester);
    await tapLogin(tester);
    await tester.pump();

    expect(verifyCalls, 0);
    expect(signInCalls, 0);
    expect(
      find.text('Masukkan kode CAPTCHA tidak boleh kosong'),
      findsOneWidget,
    );
  });

  testWidgets(
    'kode CAPTCHA salah menghentikan login dan memuat ulang challenge',
    (tester) async {
      var loadCalls = 0;
      var signInCalls = 0;

      await pumpLogin(
        tester,
        captchaChallengeProvider: () async {
          loadCalls++;
          return challenge;
        },
        captchaVerifier: ({required challengeId, required answer}) async =>
            false,
        captchaTokenProvider: () async => 'turnstile-token',
        signInWithPassword:
            ({required email, required password, required captchaToken}) async {
              signInCalls++;
              return AuthResponse();
            },
      );

      await enterCredentials(tester);
      await tester.enterText(find.byType(TextField).at(2), 'wrong');
      await tapLogin(tester);
      await tester.pumpAndSettle();

      expect(loadCalls, 2);
      expect(signInCalls, 0);
      expect(find.text('Kode CAPTCHA salah, coba lagi'), findsOneWidget);
    },
  );

  testWidgets('CAPTCHA benar meneruskan token Turnstile ke Supabase', (
    tester,
  ) async {
    String? receivedToken;
    String? receivedChallengeId;
    String? receivedAnswer;

    await pumpLogin(
      tester,
      captchaVerifier: ({required challengeId, required answer}) async {
        receivedChallengeId = challengeId;
        receivedAnswer = answer;
        return true;
      },
      captchaTokenProvider: () async => 'turnstile-token',
      signInWithPassword:
          ({required email, required password, required captchaToken}) async {
            receivedToken = captchaToken;
            return AuthResponse();
          },
    );

    await enterCredentials(tester);
    await tester.enterText(find.byType(TextField).at(2), 'aB2cD');
    await tapLogin(tester);
    await tester.pumpAndSettle();

    expect(receivedChallengeId, 'challenge-1');
    expect(receivedAnswer, 'aB2cD');
    expect(receivedToken, 'turnstile-token');
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

    await enterCredentials(tester);
    await tester.enterText(find.byType(TextField).at(2), 'aB2cD');
    await tapLogin(tester);
    await tester.pump();

    expect(signInCalls, 0);
    expect(find.text('Verifikasi keamanan gagal, coba lagi'), findsOneWidget);
  });

  testWidgets('token Turnstile kedaluwarsa menghentikan login', (tester) async {
    var signInCalls = 0;

    await pumpLogin(
      tester,
      captchaTokenProvider: () async => null,
      signInWithPassword:
          ({required email, required password, required captchaToken}) async {
            signInCalls++;
            return AuthResponse();
          },
    );

    await enterCredentials(tester);
    await tester.enterText(find.byType(TextField).at(2), 'aB2cD');
    await tapLogin(tester);
    await tester.pump();

    expect(signInCalls, 0);
    expect(find.text('Verifikasi keamanan gagal, coba lagi'), findsOneWidget);
  });

  testWidgets('konfigurasi CAPTCHA yang hilang menghentikan login', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pump();

    await enterCredentials(tester);
    await tapLogin(tester);
    await tester.pump();

    expect(
      find.text('Verifikasi keamanan belum dikonfigurasi'),
      findsOneWidget,
    );
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

    await enterCredentials(tester);
    await tester.enterText(find.byType(TextField).at(2), 'aB2cD');
    await tapLogin(tester);
    await tester.pump();

    expect(find.text('Verifikasi keamanan gagal, coba lagi'), findsOneWidget);
  });

  testWidgets('rapid tap hanya menjalankan satu verifikasi CAPTCHA', (
    tester,
  ) async {
    final verifyCompleter = Completer<bool>();
    var verifyCalls = 0;

    await pumpLogin(
      tester,
      captchaVerifier: ({required challengeId, required answer}) {
        verifyCalls++;
        return verifyCompleter.future;
      },
      captchaTokenProvider: () async => 'turnstile-token',
      signInWithPassword:
          ({required email, required password, required captchaToken}) async =>
              AuthResponse(),
    );

    await enterCredentials(tester);
    await tester.enterText(find.byType(TextField).at(2), 'aB2cD');
    final button = find.byType(ElevatedButton);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.tap(button);
    await tester.pump();

    expect(verifyCalls, 1);

    verifyCompleter.complete(true);
    await tester.pumpAndSettle();
  });
}
