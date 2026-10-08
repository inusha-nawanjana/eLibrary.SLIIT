import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../library_state.dart';
import '../models.dart';
import 'common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final id = TextEditingController(), password = TextEditingController();
  final form = GlobalKey<FormState>();
  bool hidden = true, remember = false, busy = false;
  @override
  void dispose() {
    id.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await LibraryScope.of(context)
          .signIn(id.text, password.text, rememberMe: remember);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> reset() async {
    if (id.text.trim().isEmpty) {
      showError(
        context,
        const LibraryException('Enter your student ID or email first.'),
      );
      return;
    }
    try {
      await LibraryScope.of(context).resetPassword(id.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'If your account exists, a password reset email will arrive shortly.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext c) {
    final state = LibraryScope.of(c);
    return Screen(
      title: '',
      back: true,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Form(
        key: form,
        child: Column(
          children: [
            const SizedBox(height: 28),
            Art(
              asset('d3851.png'),
              width: 120,
              height: 120,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 32),
            const Brand(
              center: true,
              subtitleSize: 13,
              subtitle: 'Use your student portal credentials',
            ),
            const SizedBox(height: 36),
            Field(
              'Student / Lecturer ID',
              controller: id,
              hint: 'e.g. IT2104523',
              validator: requiredValue,
            ),
            const SizedBox(height: 20),
            Field(
              'Password',
              controller: password,
              hint: '••••••••',
              obscure: hidden,
              validator: requiredValue,
              suffix: IconButton(
                tooltip: hidden ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => hidden = !hidden),
                icon: const Glyph('a1240.svg', size: 18),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 24,
                      child: Checkbox(
                        value: remember,
                        onChanged: (v) => setState(() => remember = v!),
                        activeColor: orange,
                        side: const BorderSide(color: line),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('Remember me', style: txt(12, color: muted)),
                  ],
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: busy ? null : reset,
                  child: Text(
                    'Forgot Password?',
                    style: txt(12, weight: semi, color: orange),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            PrimaryButton('Login', onTap: login, busy: busy),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                Text('Trouble logging in? ', style: txt(12, color: muted)),
                InkWell(
                  onTap: () => showDialog<void>(
                    context: c,
                    builder: (d) => AlertDialog(
                      title: const Text('Contact IT Support'),
                      content: Text(
                        state.demo
                            ? 'This is a local demonstration. Use IT21234567 with password Demo@12345. Real campus login requires an authorised SLIIT integration.'
                            : 'Contact your university IT help desk or library administrator using your campus portal. This app does not collect your password for a third-party portal.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(d),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ),
                  child: Text(
                    'Contact IT Support',
                    style: txt(12, weight: semi, color: orange),
                  ),
                ),
              ],
            ),
            if (state.demo) ...[
              const SizedBox(height: 28),
              Panel(
                color: surface,
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Text('Demo account', style: txt(12, weight: bold)),
                    const SizedBox(height: 4),
                    SelectableText(
                      'IT21234567  ·  Demo@12345',
                      style: txt(12, color: muted),
                    ),
                    TextButton(
                      onPressed: () {
                        id.text = 'IT21234567';
                        password.text = 'Demo@12345';
                      },
                      child: Text(
                        'Fill demo credentials',
                        style: txt(12, color: orange, weight: semi),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});
  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordState();
}

class _ResetPasswordState extends State<ResetPasswordScreen> {
  final password = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => Screen(
    title: 'Reset Password',
    back: true,
    child: Column(
      children: [
        const SizedBox(height: 24),
        Field('New password', controller: password, obscure: true),
        const SizedBox(height: 24),
        PrimaryButton(
          'Save password',
          busy: busy,
          onTap: () async {
            if (password.text.length < 8) {
              showError(
                c,
                const LibraryException('Use at least 8 characters.'),
              );
              return;
            }
            setState(() => busy = true);
            try {
              await LibraryScope.of(c).client!.auth
                  .updateUser(UserAttributes(password: password.text));
              if (c.mounted) Navigator.pop(c);
            } catch (e) {
              if (c.mounted) showError(c, e);
            } finally {
              if (mounted) setState(() => busy = false);
            }
          },
        ),
      ],
    ),
  );
}
