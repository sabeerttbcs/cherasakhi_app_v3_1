import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/gold_button.dart';
import '../providers/auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  final _adminId = TextEditingController();
  final _pin = TextEditingController();

  bool _adminMode = false;
  bool _busy = false;
  String? _verificationId;
  int? _resendToken;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _otp.dispose();
    _adminId.dispose();
    _pin.dispose();
    super.dispose();
  }

  void _setBusy(bool v, [String? error]) {
    if (!mounted) return;
    setState(() {
      _busy = v;
      _error = error;
    });
  }

  Future<void> _sendOtp() async {
    final phone = normalizePhone(_phone.text);
    if (phone.length < 11) {
      _setBusy(false, 'Enter a valid mobile number');
      return;
    }
    _setBusy(true);
    try {
      await ref.read(authRepositoryProvider).sendOtp(
            phone: phone,
            resendToken: _resendToken,
            onCodeSent: (id, token) {
              if (!mounted) return;
              setState(() {
                _verificationId = id;
                _resendToken = token;
                _busy = false;
              });
            },
            onError: (msg) => _setBusy(false, msg),
          );
    } catch (e) {
      _setBusy(false, '$e');
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otp.text.trim();
    if (_verificationId == null || code.length < 6) {
      _setBusy(false, 'Enter the 6-digit code');
      return;
    }
    _setBusy(true);
    try {
      await ref.read(authRepositoryProvider).verifyOtp(_verificationId!, code);
    } on FirebaseAuthException catch (e) {
      _setBusy(false, e.message ?? 'Invalid code');
    }
  }

  Future<void> _adminLogin() async {
    if (_adminId.text.trim().isEmpty || _pin.text.trim().length < 6) {
      _setBusy(false, 'Enter admin ID and 6-digit PIN');
      return;
    }
    _setBusy(true);
    try {
      await ref.read(authRepositoryProvider).adminPinLogin(adminId: _adminId.text, pin: _pin.text);
    } on FirebaseAuthException catch (e) {
      _setBusy(false, e.message ?? 'Login failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.berryGradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            children: [
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: AppColors.roseGoldLight.withOpacity(0.45), blurRadius: 40)],
                  ),
                  child: Image.asset('assets/brand/logo.png', width: 200, height: 200),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                AppConstants.appName,
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(fontSize: 34, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                AppConstants.fullName.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.roseGoldPale, fontSize: 11.5, letterSpacing: 2),
              ),
              const SizedBox(height: 6),
              Text(
                AppConstants.tagline,
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(color: Colors.white70, fontStyle: FontStyle.italic, fontSize: 15),
              ),
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
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, icon: Icon(Icons.sms_rounded), label: Text('Member OTP')),
                        ButtonSegment(value: true, icon: Icon(Icons.admin_panel_settings_rounded), label: Text('Admin PIN')),
                      ],
                      selected: {_adminMode},
                      onSelectionChanged: (s) => setState(() {
                        _adminMode = s.first;
                        _error = null;
                      }),
                    ),
                    const SizedBox(height: 20),
                    if (!_adminMode) ..._memberFields() else ..._adminFields(),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _memberFields() {
    final codeSent = _verificationId != null;
    return [
      TextField(
        controller: _phone,
        enabled: !codeSent,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(
          labelText: 'Mobile number',
          hintText: '98765 43210',
          prefixIcon: Icon(Icons.phone_iphone_rounded),
          prefixText: '+${AppConstants.defaultCountryCode} ',
        ),
      ),
      if (codeSent) ...[
        const SizedBox(height: 12),
        TextField(
          controller: _otp,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(letterSpacing: 8, fontWeight: FontWeight.w700, fontSize: 20),
          decoration: const InputDecoration(labelText: 'OTP code', counterText: '', prefixIcon: Icon(Icons.lock_rounded)),
        ),
      ],
      const SizedBox(height: 20),
      GoldButton(
        label: codeSent ? 'VERIFY & ENTER' : 'SEND OTP',
        icon: codeSent ? Icons.verified_rounded : Icons.send_rounded,
        loading: _busy,
        expand: true,
        onPressed: codeSent ? _verifyOtp : _sendOtp,
      ),
      if (codeSent)
        TextButton(
          onPressed: _busy ? null : _sendOtp,
          child: const Text('Resend code'),
        ),
    ];
  }

  List<Widget> _adminFields() => [
        TextField(
          controller: _adminId,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Admin ID (email)', prefixIcon: Icon(Icons.badge_rounded)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pin,
          obscureText: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'Admin PIN', prefixIcon: Icon(Icons.pin_rounded)),
        ),
        const SizedBox(height: 20),
        GoldButton(
          label: 'UNLOCK ADMIN',
          icon: Icons.lock_open_rounded,
          loading: _busy,
          expand: true,
          onPressed: _adminLogin,
        ),
      ];
}
