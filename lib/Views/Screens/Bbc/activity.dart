import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

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
const _kSuccess    = Color(0xFF10B981);
const _kWarning    = Color(0xFFF59E0B);
const _kInfo       = Color(0xFF3B82F6);

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  Map<String, dynamic> _activityData = {};
  bool _isLoading = true;
  String? _errorMessage;
  String _userName = '';
  String _userMobile = '';
  String _userEmail = '';
  String _userCompany = '';
  String _userOccupation = '';
  String _joiningDate = '';

  @override
  void initState() {
    super.initState();
    _fetchUserActivity();
  }

  Future<void> _fetchUserActivity() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('bbc_token');

      if (token == null || token.isEmpty) {
        setState(() {
          _errorMessage = 'Please login again';
          _isLoading = false;
        });
        return;
      }

      // First fetch user profile to get basic info
      final profileResponse = await http.post(
        Uri.parse('https://businessboosters.club/public/api/fetch-profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('Profile Response: ${profileResponse.body}');

      if (profileResponse.statusCode == 200) {
        final profileJson = jsonDecode(profileResponse.body);
        if (profileJson['code'] == 200 && profileJson['data'] != null) {
          final data = profileJson['data'];
          _userName = data['name']?.toString() ?? data['person_name']?.toString() ?? 'User';
          _userMobile = data['mobile']?.toString() ?? data['person_mobile']?.toString() ?? '';
          _userEmail = data['email']?.toString() ?? data['person_email']?.toString() ?? '';
          _userCompany = data['company']?.toString() ?? data['person_company']?.toString() ?? '';
          _userOccupation = data['occupation']?.toString() ?? data['person_occupation']?.toString() ?? '';
          _joiningDate = data['created_at']?.toString()?.split('T')[0] ?? data['joining_date']?.toString() ?? 'Not available';
        }
      }

      // Fetch user activity using fetch-user-activity endpoint
      final activityResponse = await http.get(
        Uri.parse('https://businessboosters.club/public/api/fetch-user-activity'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));

      debugPrint('Activity Response Status: ${activityResponse.statusCode}');
      debugPrint('Activity Response Body: ${activityResponse.body}');

      if (activityResponse.statusCode == 200) {
        final json = jsonDecode(activityResponse.body);
        if (json['code'] == 200 && json['data'] != null) {
          setState(() {
            _activityData = json['data'];
            _isLoading = false;
          });
        } else if (json['success'] == true && json['data'] != null) {
          setState(() {
            _activityData = json['data'];
            _isLoading = false;
          });
        } else {
          await _fetchAttendanceReport(token);
        }
      } else {
        await _fetchAttendanceReport(token);
      }
    } catch (e) {
      debugPrint('Activity error: $e');
      setState(() {
        _errorMessage = 'Network error: Please check your connection';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchAttendanceReport(String token) async {
    try {
      final response = await http.get(
        Uri.parse('https://businessboosters.club/public/api/fetch-user-attendance-report'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['code'] == 200 && json['data'] != null) {
          setState(() {
            _activityData = json['data'];
            _isLoading = false;
          });
        } else {
          setState(() {
            _activityData = _getMockActivityData();
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _activityData = _getMockActivityData();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Attendance report error: $e');
      setState(() {
        _activityData = _getMockActivityData();
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _getMockActivityData() {
    return {
      'onetoone_count': 1,
      'team_points': 0,
      'visitor_count': 0,
      'chief_guest_count': 0,
      'bonus_point': 0,
      'newjoining_count': 0,
      'ref_given': 0,
      'ref_received': 6000,
      'attendance_count': 2,
      'total_meetings': 5,
    };
  }

  int _getValue(String key) {
    return _activityData[key]?.toInt() ?? _activityData[key] ?? 0;
  }

  String _getStringValue(String key) {
    return _activityData[key]?.toString() ?? '0';
  }

  double _getAttendancePercentage() {
    final attended = _getValue('attendance_count');
    final total = _getValue('total_meetings') != 0 ? _getValue('total_meetings') : 5;
    if (total == 0) return 0;
    return (attended / total) * 100;
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _kBg,
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: _kBrand))
                  : _errorMessage != null
                      ? _buildErrorView()
                      : SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            children: [
                             
                              _buildStatsGrid(),
                              const SizedBox(height: 16),
                              _buildAttendanceCard(),
                              const SizedBox(height: 16),
                              _buildReferralCard(),
                              const SizedBox(height: 16),
                              _buildAdditionalStats(),
                              const SizedBox(height: 30),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

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
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                    
                      Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.15),
                          border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5),
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
                                errorBuilder: (_, __, ___) => Icon(Icons.business_center_rounded, color: _kBrand, size: 20),
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
                          Text('ACTIVITY DASHBOARD',
                              style: GoogleFonts.dmSans(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2,
                                  color: Colors.white.withOpacity(0.55))),
                        ],
                      ),
                    ],
                  ),
                    
                    ],
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

  Widget _buildProfileCard() {
    return Transform.translate(
      offset: const Offset(0, -20),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_kPlum, _kBrand],
                  ),
                ),
                child: Center(
                  child: Text(
                    _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _userName,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _kTextPri,
                ),
              ),
              const SizedBox(height: 4),
              if (_userOccupation.isNotEmpty)
                Text(
                  _userOccupation,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: _kBrand,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_userMobile.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _kBrandLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.phone_android_rounded, size: 14, color: _kBrand),
                          const SizedBox(width: 6),
                          Text(
                            _userMobile,
                            style: GoogleFonts.inter(fontSize: 12, color: _kBrand),
                          ),
                        ],
                      ),
                    ),
                  if (_userEmail.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _kBrandLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.email_outlined, size: 14, color: _kBrand),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _userEmail.length > 20 ? '${_userEmail.substring(0, 18)}...' : _userEmail,
                              style: GoogleFonts.inter(fontSize: 12, color: _kBrand),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Joined: $_joiningDate',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: _kTextMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    final oneToOne = _getValue('onetoone_count');
    final teamPoints = _getValue('team_points');
    final visitorCount = _getValue('visitor_count');
    final newJoining = _getValue('newjoining_count');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.2,
        children: [
          _statCard('One to One', oneToOne.toString(), Icons.people_alt_rounded, _kInfo),
          _statCard('Team', teamPoints.toString(), Icons.groups_rounded, _kSuccess),
          _statCard('Visitor', visitorCount.toString(), Icons.visibility_rounded, _kWarning),
          _statCard('New Joining', newJoining.toString(), Icons.person_add_rounded, Colors.teal),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _kTextPri,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: _kTextMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard() {
    final attended = _getValue('attendance_count');
    final total = _getValue('total_meetings') != 0 ? _getValue('total_meetings') : 5;
    final percentage = _getAttendancePercentage();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kBorder, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: _kBrand,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Attendance Overview',
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _kTextPri,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$attended / $total',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: _kBrand,
                      ),
                    ),
                    Text(
                      'Meetings Attended',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: _kTextMuted,
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  width: 100,
                  height: 100,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 90,
                        height: 90,
                        child: CircularProgressIndicator(
                          value: percentage / 100,
                          strokeWidth: 8,
                          backgroundColor: _kBrandLight,
                          valueColor: AlwaysStoppedAnimation<Color>(_kBrand),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${percentage.toInt()}%',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: _kBrand,
                            ),
                          ),
                          Text(
                            'Rate',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: _kTextMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferralCard() {
    final refGiven = _getValue('ref_given');
    final refReceived = _getValue('ref_received');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_kBrand, _kPlum],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _kBrand.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.share_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  'Referral Network',
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _referralItem('Ref Given', refGiven.toString()),
                ),
                Container(
                  width: 1,
                  height: 60,
                  color: Colors.white.withOpacity(0.3),
                ),
                Expanded(
                  child: _referralItem('Ref Received', refReceived.toString()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _referralItem(String title, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildAdditionalStats() {
    final chiefGuest = _getValue('chief_guest_count');
    final bonusPoint = _getValue('bonus_point');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kBorder, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _kBrand.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.star_rounded, size: 22, color: _kBrand),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    chiefGuest.toString(),
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _kTextPri,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Chief Guest',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: _kTextMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kBorder, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.card_giftcard_rounded, size: 22, color: Colors.purple),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    bonusPoint.toString(),
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _kTextPri,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Bonus',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: _kTextMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: _kTextMuted),
          const SizedBox(height: 16),
          Text(_errorMessage!, style: GoogleFonts.inter(fontSize: 14, color: _kTextSec, )),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchUserActivity,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kBrand,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Retry', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}