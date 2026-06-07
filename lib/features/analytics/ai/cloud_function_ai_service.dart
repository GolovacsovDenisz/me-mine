import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'ai_service.dart';

class CloudFunctionAiService implements AiService {
  CloudFunctionAiService({FirebaseFunctions? functions})
    : _functions =
          functions ??
          FirebaseFunctions.instanceFor(
            app: Firebase.app(),
            region: 'europe-west1',
          );

  final FirebaseFunctions _functions;

  static Map<String, dynamic> _payload(PeriodAiInput input) => {
    'periodId': input.periodId,
    'periodType': input.periodType,
    'fromDateId': input.fromDateId,
    'toDateId': input.toDateId,
    'force': input.force,
  };

  static PeriodAiOutput _parseResult(Map<String, dynamic>? data) {
    final ok = data?['ok'] == true;
    if (!ok) {
      throw StateError('Function returned ok=false');
    }
    return const PeriodAiOutput(model: 'server', summary: '');
  }

  /// Transient / cold-start / token edge cases — retry with fresh ID token.
  static bool _retriable(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'unauthenticated':
      case 'unavailable':
      case 'deadline-exceeded':
      case 'internal':
      case 'aborted':
      case 'unknown':
        return true;
      default:
        return false;
    }
  }

  @override
  Future<PeriodAiOutput> analyzePeriod(PeriodAiInput input) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'Sign in again, then try generating the summary.',
      );
    }

    final payload = _payload(input);
    final callable = _functions.httpsCallable(
      'analyzePeriod',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
    );

    for (var attempt = 0; attempt < 3; attempt++) {
      await user.getIdToken(true);

      try {
        final res = await callable.call<Map<String, dynamic>>(payload);
        return _parseResult(res.data);
      } on FirebaseFunctionsException catch (e, st) {
        final canRetry = _retriable(e) && attempt < 2;
        if (!canRetry) {
          Error.throwWithStackTrace(e, st);
        }
        await Future<void>.delayed(
          Duration(milliseconds: 350 * (1 << attempt)),
        );
      }
    }
    // Satisfies flow analysis; loop always returns or throws.
    throw StateError('analyzePeriod: exhausted retries');
  }
}
