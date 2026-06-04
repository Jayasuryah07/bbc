import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaani/Views/Screens/Bbc/HomeBbc.dart';

// ─── Brand tokens (identical across all BBC screens) ──────────────────────────
const _kBrand      = Color(0xFFB0126B);
const _kBrandDeep  = Color(0xFF8A0D55);
const _kPlum       = Color(0xFF9C3A8B);
const _kBrandLight = Color(0xFFFCE8F3);
const _kBg         = Color(0xFFFAF7F9);
const _kTextPri    = Color(0xFF1A0A13);
const _kTextSec    = Color(0xFF7A5870);
const _kTextMuted  = Color(0xFFB89AAE);
const _kBorder     = Color(0x1FB0126B);
const _kInputBg    = Color(0xFFFDF4F9);

class SignUpPage extends StatefulWidget {
  final String mobile;

  const SignUpPage({super.key, this.mobile = ''});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage>
    with SingleTickerProviderStateMixin {
  // ── Controllers ──────────────────────────────────────────────────────────────
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _referralCtrl = TextEditingController();
  late final TextEditingController _mobileCtrl;

  bool _agreed  = false;
  bool _loading = false;

  late final AnimationController _animCtrl;
  late final Animation<double>   _fade;
  late final Animation<Offset>   _slide;

  @override
  void initState() {
    super.initState();
    _mobileCtrl = TextEditingController(text: widget.mobile);

    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650));
    _fade  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));

    _animCtrl.forward();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _mobileCtrl.dispose();
    _referralCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  // ── API ───────────────────────────────────────────────────────────────────────
  Future<void> _submitSignUp() async {
    final name    = _nameCtrl.text.trim();
    final email   = _emailCtrl.text.trim();
    final mobile  = _mobileCtrl.text.trim();
    final referral = _referralCtrl.text.trim();

    if (name.isEmpty)               { _snack('Please enter your full name'); return; }
    if (email.isEmpty)              { _snack('Please enter your email'); return; }
    if (!_isValidEmail(email))      { _snack('Please enter a valid email address'); return; }
    if (mobile.length != 10)        { _snack('Enter a valid 10-digit mobile number'); return; }
    if (!_agreed)                   { _snack('Please agree to the terms and conditions'); return; }

    setState(() => _loading = true);
    try {
      final res = await http.post(
        Uri.parse('https://businessboosters.club/public/api/sign-up'),
        body: {
          'person_name':      name,
          'person_email':     email,
          'person_mobile':    mobile,
          'person_user_type': 'Business',
          'person_area':      '',
          'referred_by_code': referral,
        },
      );

      debugPrint('SignUp status: ${res.statusCode}  body: ${res.body}');
      final json = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 200) {
        final userData = (json['data'] ?? json) as Map<String, dynamic>;
        final token    = userData['token']?.toString() ?? '';
        if (token.isNotEmpty) {
          await _saveSession(token: token, user: userData);
          _snack('Registration successful!');
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              _fadeRoute(const HomePageBbc()),
              (_) => false,
            );
          }
        } else {
          _snack(json['msg'] ?? 'Registration failed. Please try again.');
        }
      } else {
        _snack(json['msg'] ?? 'Something went wrong. Please try again.');
      }
    } catch (e) {
      _snack('Network error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isValidEmail(String email) =>
      RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$').hasMatch(email);

  Future<void> _saveSession({
    required String token,
    required Map<String, dynamic> user,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bbc_token',     token);
    await prefs.setString('bbc_user_id',   user['id']?.toString()   ?? '');
    await prefs.setString('bbc_user_name', user['name']?.toString() ?? '');
    await prefs.setString('bbc_user_data', jsonEncode(user));
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white)),
      backgroundColor: _kTextPri,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
    ));
  }

  PageRoute _fadeRoute(Widget page) => PageRouteBuilder(
        pageBuilder: (_, a, __) => page,
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 280),
      );

  // ── BUILD ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _kBg,
        body: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildScrollBody()),
          ],
        ),
      ),
    );
  }

  // ── Gradient header ───────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kPlum, _kBrand, Color(0xFFC4156E)],
          stops: [0.0, 0.6, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned(
              top: -50, right: -40,
              child: _circle(180, Colors.white.withOpacity(0.06))),
            Positioned(
              bottom: 8, left: 14,
              child: _circle(90, Colors.white.withOpacity(0.04))),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 46),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status bar row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back button
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.15),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.25),
                                width: 1.5),
                          ),
                          child: const Icon(Icons.arrow_back_rounded,
                              color: Colors.white, size: 16),
                        ),
                      ),
                     
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Brand + logo row
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.15),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.25),
                              width: 1.5),
                        ),
                        child: Center(
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.92),
                            ),
                            child: Center(
                              child: Image.asset(
                                'assets/images/bbclogo.png',
                                width: 24,
                                height: 24,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Icon(
                                    Icons.business_center_rounded,
                                    color: _kBrand, size: 20),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Business Boosters Club',
                              style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                          const SizedBox(height: 2),
                          Text('PREMIUM NETWORK',
                              style: GoogleFonts.dmSans(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2,
                                  color: Colors.white.withOpacity(0.55))),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Title
                  Text('NEW MEMBER',
                      style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                          color: Colors.white.withOpacity(0.6))),
                  const SizedBox(height: 5),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Create\n',
                          style: GoogleFonts.cormorantGaramond(
                              fontSize: 32,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              height: 1.1),
                        ),
                        TextSpan(
                          text: 'Account',
                          style: GoogleFonts.cormorantGaramond(
                              fontSize: 32,
                              fontWeight: FontWeight.w600,
                              fontStyle: FontStyle.italic,
                              color: const Color(0xFFFFDCF0).withOpacity(0.95),
                              height: 1.1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circle(double size, Color color) => Container(
        width: size, height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color));

  // ── Scrollable form body ──────────────────────────────────────────────────────
  Widget _buildScrollBody() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      transform: Matrix4.translationValues(0, -22, 0),
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step progress pills
                _buildStepPills(),
                const SizedBox(height: 20),

                _sectionLabel('Personal Details'),
                const SizedBox(height: 10),

                _buildField(
                  ctrl: _nameCtrl,
                  hint: 'Full Name',
                  icon: Icons.person_outline_rounded,
                  inputType: TextInputType.name,
                ),
                const SizedBox(height: 12),

                _buildField(
                  ctrl: _emailCtrl,
                  hint: 'Email Address',
                  icon: Icons.mail_outline_rounded,
                  inputType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),

                _buildField(
                  ctrl: _mobileCtrl,
                  hint: 'Mobile Number',
                  icon: Icons.phone_android_outlined,
                  inputType: TextInputType.phone,
                  formatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                ),
                const SizedBox(height: 12),

                _buildField(
                  ctrl: _referralCtrl,
                  hint: 'Referral Code',
                  icon: Icons.card_giftcard_outlined,
                  isOptional: true,
                ),

                const SizedBox(height: 18),

                // Terms row
                _buildTermsRow(),

                const SizedBox(height: 20),

                // CTA
                _buildSubmitButton(),

                const SizedBox(height: 16),

                // Sign in row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Already have an account? ',
                        style: GoogleFonts.dmSans(
                            fontSize: 12, color: _kTextMuted)),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text('Sign In',
                          style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _kBrand,
                              decoration: TextDecoration.underline,
                              decorationColor: _kBrand.withOpacity(0.4))),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Security note
                Container(
                  padding: const EdgeInsets.only(top: 14),
                  decoration:
                      const BoxDecoration(border: Border(top: BorderSide(color: _kBorder))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shield_outlined,
                          size: 13, color: _kTextMuted),
                      const SizedBox(width: 5),
                      Text('Secured with 256-bit encryption',
                          style: GoogleFonts.dmSans(
                              fontSize: 11, color: _kTextMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Step pills ────────────────────────────────────────────────────────────────
  Widget _buildStepPills() {
    return Row(
      children: List.generate(3, (i) {
        final active = i < 2;
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: active ? _kBrand : _kBorder,
            ),
          ),
        );
      }),
    );
  }

  // ── Input field ───────────────────────────────────────────────────────────────
  Widget _buildField({
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    TextInputType inputType = TextInputType.text,
    List<TextInputFormatter>? formatters,
    bool readOnly = false,
    bool isOptional = false,
  }) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: _kInputBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder, width: 1.5),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(icon, size: 17, color: _kTextMuted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: ctrl,
              keyboardType: inputType,
              readOnly: readOnly,
              inputFormatters: formatters,
              style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: _kTextPri,
                  fontWeight: FontWeight.w400),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: _kTextMuted,
                    fontWeight: FontWeight.w300),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (isOptional) ...[
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: _kBrandLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('Optional',
                  style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: _kTextSec)),
            ),
          ] else
            const SizedBox(width: 14),
        ],
      ),
    );
  }

  // ── Terms row ─────────────────────────────────────────────────────────────────
  Widget _buildTermsRow() {
    return GestureDetector(
      onTap: () => setState(() => _agreed = !_agreed),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: _agreed ? _kBrandLight.withOpacity(0.5) : _kInputBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: _agreed ? _kBrand.withOpacity(0.32) : _kBorder,
              width: 1.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: _agreed ? _kBrand : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: _agreed ? _kBrand : _kBrand.withOpacity(0.35),
                    width: 1.5),
              ),
              child: _agreed
                  ? const Icon(Icons.check_rounded,
                      size: 13, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: GoogleFonts.dmSans(
                      fontSize: 12, color: _kTextSec, height: 1.5),
                  children: [
                    const TextSpan(text: 'I agree to the '),
                    TextSpan(
                      text: 'Terms & Conditions',
                      style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _kBrand,
                          decoration: TextDecoration.underline,
                          decorationColor: _kBrand.withOpacity(0.35)),
                    ),
                    const TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _kBrand,
                          decoration: TextDecoration.underline,
                          decorationColor: _kBrand.withOpacity(0.35)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Submit button ─────────────────────────────────────────────────────────────
  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _agreed
                ? [_kBrand, _kPlum]
                : [_kBrand.withOpacity(0.4), _kPlum.withOpacity(0.4)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: _agreed
              ? [
                  BoxShadow(
                    color: _kBrand.withOpacity(0.28),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  )
                ]
              : [],
        ),
        child: ElevatedButton(
          onPressed: (_agreed && !_loading) ? _submitSignUp : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            padding: EdgeInsets.zero,
          ),
          child: _loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.2))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Next',
                        style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.5)),
                    const SizedBox(width: 10),
                    const Icon(Icons.arrow_forward_rounded,
                        color: Colors.white, size: 18),
                  ],
                ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────
  Widget _sectionLabel(String text) => Text(
        text.toUpperCase(),
        style: GoogleFonts.dmSans(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
            color: _kTextMuted),
      );
}