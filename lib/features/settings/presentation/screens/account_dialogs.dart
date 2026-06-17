import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../shared/app_dialogs.dart';
import '../../../../shared/ui_feedback.dart';

Future<void> showChangeEmailDialog(
  BuildContext context,
  FirebaseAuth auth,
) async {
  final user = auth.currentUser;
  if (user == null || user.email == null) return;

  final parentContext = context;
  await showDialog<void>(
    context: context,
    builder: (ctx) =>
        _ChangeEmailDialog(user: user, parentContext: parentContext),
  );
}

Future<void> showChangePasswordDialog(
  BuildContext context,
  FirebaseAuth auth,
) async {
  final user = auth.currentUser;
  if (user == null || user.email == null) return;

  final parentContext = context;
  await showDialog<void>(
    context: context,
    builder: (ctx) =>
        _ChangePasswordDialog(user: user, parentContext: parentContext),
  );
}

class _AccountPasswordField extends StatelessWidget {
  const _AccountPasswordField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggleVisibility,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggleVisibility;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      autofillHints: const [AutofillHints.password],
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: IconButton(
          tooltip: obscure ? 'Show password' : 'Hide password',
          onPressed: onToggleVisibility,
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
        ),
      ),
      validator: validator,
    );
  }
}

class _ChangeEmailDialog extends StatefulWidget {
  const _ChangeEmailDialog({required this.user, required this.parentContext});

  final User user;
  final BuildContext parentContext;

  @override
  State<_ChangeEmailDialog> createState() => _ChangeEmailDialogState();
}

class _ChangeEmailDialogState extends State<_ChangeEmailDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _newEmail;
  late final TextEditingController _currentPassword;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _newEmail = TextEditingController(text: widget.user.email);
    _currentPassword = TextEditingController();
  }

  @override
  void dispose() {
    _newEmail.dispose();
    _currentPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final pwd = _currentPassword.text;
    final email = _newEmail.text.trim();
    if (email == widget.user.email) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That is already your email.')),
      );
      return;
    }

    try {
      final cred = EmailAuthProvider.credential(
        email: widget.user.email!,
        password: pwd,
      );
      await widget.user.reauthenticateWithCredential(cred);
      await widget.user.verifyBeforeUpdateEmail(email);
      if (!mounted) return;
      Navigator.of(context).pop();
      if (!widget.parentContext.mounted) return;
      ScaffoldMessenger.of(widget.parentContext).showSnackBar(
        const SnackBar(
          content: Text('Check your new inbox to confirm the email change.'),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingErrorMessage(e))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change email'),
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _newEmail,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'New email'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (!v.contains('@')) return 'Invalid email';
                return null;
              },
            ),
            const SizedBox(height: 12),
            _AccountPasswordField(
              controller: _currentPassword,
              label: 'Current password (re-auth)',
              obscure: _obscurePassword,
              onToggleVisibility: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Required for security' : null,
            ),
            const SizedBox(height: 8),
            const Text(
              'You will get a confirmation link at the new address.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      actions: centeredDialogActions(
        dialogContext: context,
        confirmLabel: 'Send link',
        onConfirm: _submit,
      ),
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog({
    required this.user,
    required this.parentContext,
  });

  final User user;
  final BuildContext parentContext;

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNext = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_next.text != _confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New passwords do not match.')),
      );
      return;
    }

    try {
      final cred = EmailAuthProvider.credential(
        email: widget.user.email!,
        password: _current.text,
      );
      await widget.user.reauthenticateWithCredential(cred);
      await widget.user.updatePassword(_next.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      if (!widget.parentContext.mounted) return;
      ScaffoldMessenger.of(
        widget.parentContext,
      ).showSnackBar(const SnackBar(content: Text('Password updated.')));
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingErrorMessage(e))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change password'),
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AccountPasswordField(
                controller: _current,
                label: 'Current password',
                obscure: _obscureCurrent,
                onToggleVisibility: () =>
                    setState(() => _obscureCurrent = !_obscureCurrent),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              _AccountPasswordField(
                controller: _next,
                label: 'New password',
                obscure: _obscureNext,
                onToggleVisibility: () =>
                    setState(() => _obscureNext = !_obscureNext),
                validator: (v) {
                  if (v == null || v.length < 6) return 'At least 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _AccountPasswordField(
                controller: _confirm,
                label: 'Confirm new password',
                obscure: _obscureConfirm,
                onToggleVisibility: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v != _next.text) return 'Passwords do not match';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: centeredDialogActions(
        dialogContext: context,
        confirmLabel: 'Save',
        onConfirm: _submit,
      ),
    );
  }
}
