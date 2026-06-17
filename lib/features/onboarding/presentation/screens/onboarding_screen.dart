// First-run questionnaire (disabled in navigation; see kOnboardingFlowEnabled
// in lib/core/feature_flags.dart).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/firebase_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/constants/onboarding_questions.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const int _n = 7;
  late final PageController _pageController;
  late final List<TextEditingController> _controllers;
  int _index = 0;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _controllers = List.generate(_n, (_) => TextEditingController());
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _finish() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) throw StateError('No signed-in user');

      final answers = <String, String>{};
      for (var i = 0; i < _n; i++) {
        answers[openAnswerKeyAt(i)] = _controllers[i].text.trim();
      }

      final db = ref.read(firestoreProvider);
      await db.collection('users').doc(user.uid).set({
        'onboardingCompleted': true,
        'onboardingOpenAnswers': answers,
        'onboardingQuestionsVersion': 1,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _next() {
    final text = _controllers[_index].text.trim();
    if (text.isEmpty) {
      setState(
        () => _error =
            'Please write a short answer (you can edit it later in Settings → Train AI).',
      );
      return;
    }
    setState(() => _error = null);
    if (_index < _n - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    _finish();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Question ${_index + 1} of $_n',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _n,
                      onPageChanged: (i) => setState(() => _index = i),
                      itemBuilder: (context, i) {
                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  openQuestionLabelAt(i),
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: TextField(
                                    controller: _controllers[i],
                                    maxLines: null,
                                    expands: true,
                                    textAlignVertical: TextAlignVertical.top,
                                    decoration: const InputDecoration(
                                      alignLabelWithHint: true,
                                      hintText: 'Your answer…',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.danger),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (_index > 0)
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () {
                                  _pageController.previousPage(
                                    duration: const Duration(milliseconds: 280),
                                    curve: Curves.easeOutCubic,
                                  );
                                },
                          child: const Text('Back'),
                        ),
                      const Spacer(),
                      FilledButton(
                        onPressed: _busy ? null : _next,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: AppColors.white,
                        ),
                        child: _busy
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(_index < _n - 1 ? 'Next' : 'Finish'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
