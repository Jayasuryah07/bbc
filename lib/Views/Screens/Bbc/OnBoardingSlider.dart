import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaani/Views/Screens/Bbc/HomeBbc.dart';
import 'package:yaani/Views/Screens/Bbc/LoginScreen.dart';
import 'package:yaani/Views/Screens/Bbc/Signup.dart';

// ─── Brand tokens (identical to LoginScreen) ─────────────────────────────────
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

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _fade;
  late final Animation<Offset>   _slide;

  @override
  void initState() {
    super.initState();
    _checkLogin();

    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));

    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    _ctrl.forward();
  }

  Future<void> _checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('bbc_token') ?? '';
    if (!mounted) return;
    if (token.isNotEmpty) {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const HomePageBbc()));
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ── Route helper (matches LoginScreen fade transition) ────────────────────
  PageRoute _fade2(Widget page) => PageRouteBuilder(
        pageBuilder: (_, a, __) => page,
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 280),
      );

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _kBg,
        body: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildScrollBody()),
              ],
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  // ── Gradient header with logo ─────────────────────────────────────────────
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
              child: _circle(180, Colors.white.withOpacity(0.06)),
            ),
            Positioned(
              bottom: 8, left: 14,
              child: _circle(90, Colors.white.withOpacity(0.04)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 48),
              child: Column(
                children: [
                  // status bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                    
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Animated logo ring
                  FadeTransition(
                    opacity: _fade,
                    child: Column(
                      children: [
                        Container(
                          width: 104,
                          height: 104,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.15),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.25),
                                width: 1.5),
                          ),
                          child: Center(
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.92),
                              ),
                              child: Center(
                                child: Image.asset(
                                  'assets/images/bbclogo.png',
                                  width: 86,
                                  height: 86,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Icon(
                                      Icons.business_center_rounded,
                                      color: _kBrand,
                                      size: 28),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text('BUSINESS BOOSTER CLUB',
                            style: GoogleFonts.cormorantGaramond(
                                fontSize: 26,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: 0.06)),
                     
                       
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
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );

  // ── Scrollable body ───────────────────────────────────────────────────────
  Widget _buildScrollBody() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      transform: Matrix4.translationValues(0, -20, 0),
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 160),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Greeting
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.cormorantGaramond(
                        fontSize: 30,
                        fontWeight: FontWeight.w600,
                        color: _kTextPri,
                        height: 1.1),
                    children: const [
                      TextSpan(text: 'Hello,\n'),
                      TextSpan(
                        text: 'Entrepreneur!',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: _kBrand,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Ready to take your business to the next level?\nJoin India\'s premium member network.',
                  style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: _kTextSec,
                      height: 1.55),
                ),

                const SizedBox(height: 24),

                // Stats
                Row(
                  children: [
                    _buildStat('500+', 'Members'),
                    const SizedBox(width: 8),
                    _buildStat('50+', 'Experts'),
                    const SizedBox(width: 8),
                    _buildStat('100+', 'Success'),
                  ],
                ),

                const SizedBox(height: 24),

                // Section label
                _sectionLabel("What you'll get"),

                const SizedBox(height: 12),

                _buildFeature(
                  icon: Icons.verified_user_outlined,
                  iconColor: const Color(0xFF10B45A),
                  title: 'Verified Network',
                  subtitle: 'Connect with genuine business leaders',
                ),
                const SizedBox(height: 8),
                _buildFeature(
                  icon: Icons.trending_up_rounded,
                  iconColor: const Color(0xFFEA8300),
                  title: 'Growth Tools',
                  subtitle: 'Access resources & mentorship',
                ),
                const SizedBox(height: 8),
                _buildFeature(
                  icon: Icons.diversity_3_outlined,
                  iconColor: _kPlum,
                  title: 'Community',
                  subtitle: 'Learn with like-minded peers',
                ),

                const SizedBox(height: 16),

                // Testimonial
                _buildTestimonial(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStat(String number, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _kInputBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder, width: 1.5),
        ),
        child: Column(
          children: [
            Text(number,
                style: GoogleFonts.cormorantGaramond(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: _kBrand,
                    height: 1)),
            const SizedBox(height: 4),
            Text(label,
                style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.06,
                    color: _kTextMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildFeature({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.dmSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: _kTextPri)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: GoogleFonts.dmSans(
                        fontSize: 11.5, color: _kTextMuted)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 18, color: _kTextMuted),
        ],
      ),
    );
  }

  Widget _buildTestimonial() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kInputBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _kBrandLight,
              border: Border.all(
                  color: _kBrand.withOpacity(0.2), width: 1.5),
            ),
            child: const Icon(Icons.format_quote_rounded,
                color: _kBrand, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Joined 3 months ago',
                    style: GoogleFonts.dmSans(
                        fontSize: 11, color: _kTextMuted)),
                const SizedBox(height: 3),
                Text('Best decision for my business growth!',
                    style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _kTextPri,
                        height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Floating bottom bar ───────────────────────────────────────────────────
  Widget _buildBottomBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(10),
            topRight: Radius.circular(10),
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withOpacity(0),
              Colors.white,
              _kBg,
            ],
            stops: const [0.0, 0.28, 1.0],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Join Now button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_kBrand, _kPlum],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: _kBrand.withOpacity(0.28),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                        context, _fade2(LoginScreen())),
                    icon: const SizedBox.shrink(),
                    label: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Next',
                            style: GoogleFonts.dmSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: 0.8)),
                        const SizedBox(width: 10),
                        const Icon(Icons.arrow_forward_rounded,
                            color: Colors.white, size: 18),
                      ],
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Sign In row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Already a member? ',
                      style: GoogleFonts.dmSans(
                          fontSize: 13, color: _kTextMuted)),
                  GestureDetector(
                    onTap: () => Navigator.push(
                        context, _fade2(const LoginScreen())),
                    child: Text('Sign In',
                        style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _kBrand,
                            decoration: TextDecoration.underline,
                            decorationColor: _kBrand.withOpacity(0.4))),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Security note
              Row(
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

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ── Section label helper ──────────────────────────────────────────────────
  Widget _sectionLabel(String text) => Text(
        text.toUpperCase(),
        style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
            color: _kTextMuted),
      );
}