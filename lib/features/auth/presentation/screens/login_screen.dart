import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/gold_button.dart';
import '../providers/auth_providers.dart';
import 'invite_acceptance_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  String? get _inviteToken {
    final token = Uri.base.queryParameters['invite']?.trim();
    return token == null || token.isEmpty ? null : token;
  }

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final phone = normalizePhone(_phone.text);
    if (phone.length < 11) {
      setState(() => _error = 'Enter a valid mobile number');
      return;
    }
    if (_password.text.trim().length < 6) {
      setState(() => _error = 'Enter your password (at least 6 characters)');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).loginWithPhone(phone: phone, password: _password.text);
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = e.message ?? 'Login failed');
    } on Object catch (e) {
      if (mounted) setState(() => _error = '$e'.replaceFirst('FormatException: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final invite = _inviteToken;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.berryGradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            children: [
              Center(child: Image.asset('assets/brand/logo.png', width: 190, height: 190)),
              const SizedBox(height: 24),
              Text(AppConstants.appName,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.playfairDisplay(fontSize: 34, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 4),
              Text(AppConstants.fullName.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.roseGoldPale, fontSize: 11.5, letterSpacing: 2)),
              const SizedBox(height: 6),
              Text(AppConstants.tagline,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.playfairDisplay(color: Colors.white70, fontStyle: FontStyle.italic, fontSize: 15)),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withOpacity(0.96),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 30)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Sign in', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 6),
                    Text('Use the mobile number and password given to you by the admin.', style: theme.textTheme.bodySmall),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Mobile number',
                        hintText: '98765 43210',
                        prefixIcon: Icon(Icons.phone_iphone_rounded),
                        prefixText: '+${AppConstants.defaultCountryCode} ',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      onSubmitted: (_) => _login(),
                      decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_rounded)),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                    ],
                    const SizedBox(height: 20),
                    GoldButton(
                      label: 'SIGN IN',
                      icon: Icons.login_rounded,
                      loading: _busy,
                      expand: true,
                      onPressed: _login,
                    ),
                    if (invite != null) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => InviteAcceptanceScreen(token: invite)),
                                ),
                        icon: const Icon(Icons.mark_email_read_rounded),
                        label: const Text('ACCEPT INVITATION'),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text('No SMS OTP, Google sign-in, or public registration.',
                        textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
