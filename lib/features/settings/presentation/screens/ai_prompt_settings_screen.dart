import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/firebase_providers.dart';
import '../../../../shared/ui_feedback.dart';
import '../../../auth/domain/entities/user_ai_profile.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/providers/user_ai_profile_providers.dart';

/// Settings: user-editable text sent to the AI (period analysis, etc.).
/// Full onboarding quiz is currently disabled in the router (`feature_flags.dart`).
class AiPromptSettingsScreen extends ConsumerStatefulWidget {
  const AiPromptSettingsScreen({super.key});

  @override
  ConsumerState<AiPromptSettingsScreen> createState() =>
      _AiPromptSettingsScreenState();
}

class _AiPromptSettingsScreenState
    extends ConsumerState<AiPromptSettingsScreen> {
  late final TextEditingController _custom;
  String _tone = UserAiProfile.friendlyTone;
  bool _seeded = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _custom = TextEditingController();
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  void _seedFromProfile(UserAiProfile p) {
    if (_seeded) return;
    _custom.text = p.aiCustomPrompt;
    _tone = p.aiTone;
    _seeded = true;
  }

  Future<void> _save() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final custom = _custom.text.trim();
      final db = ref.read(firestoreProvider);
      await db.collection('users').doc(user.uid).set({
        'aiCustomPrompt': custom,
        'aiTone': _tone,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Saved. This text is sent with the next AI analysis.',
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _error = userFacingErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(userAiProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('AI instructions')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorState(
          error: e,
          title: 'Couldn’t load your settings',
          onRetry: () => ref.invalidate(userAiProfileProvider),
        ),
        data: (profile) {
          _seedFromProfile(profile);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('AI tone', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Choose the default voice for the next period analysis.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: UserAiProfile.friendlyTone,
                    label: Text('Friendly'),
                    icon: Icon(Icons.favorite_border),
                  ),
                  ButtonSegment(
                    value: UserAiProfile.criticTone,
                    label: Text('Critic'),
                    icon: Icon(Icons.psychology_alt_outlined),
                  ),
                ],
                selected: {_tone},
                onSelectionChanged: _saving
                    ? null
                    : (next) => setState(() => _tone = next.first),
              ),
              const SizedBox(height: 8),
              Text(
                _tone == UserAiProfile.criticTone
                    ? 'Critic is direct and pattern-focused, but still respectful.'
                    : 'Friendly is warmer, gentler, and more supportive.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Prompt for the model',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Optional. Added to the next period analysis. Describe tone '
                'and wishes — not a list of facts.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Examples:\n'
                '• Address me as «ты», no formal report style\n'
                '• Notice small joys more\n'
                '• No medical advice\n'
                '• One gentle idea for next week at the end',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _custom,
                maxLines: 10,
                minLines: 5,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                  hintText:
                      'be as understanding and attentive as possible, no formal report style...',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}
