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
  // Data model for user activity (matches the API response structure)
  ActivityData? _activityData;
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
      await _fetchUserProfile(token);

      // Fetch user activity using fetch-user-activity endpoint
      await _fetchUserActivityData(token);
      
    } catch (e) {
      debugPrint('Activity error: $e');
      setState(() {
        _errorMessage = 'Network error: Please check your connection';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchUserProfile(String token) async {
    try {
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
          setState(() {
            _userName = data['name']?.toString() ?? data['person_name']?.toString() ?? 'User';
            _userMobile = data['mobile']?.toString() ?? data['person_mobile']?.toString() ?? '';
            _userEmail = data['email']?.toString() ?? data['person_email']?.toString() ?? '';
            _userCompany = data['company']?.toString() ?? data['person_company']?.toString() ?? '';
            _userOccupation = data['occupation']?.toString() ?? data['person_occupation']?.toString() ?? '';
            _joiningDate = data['created_at']?.toString()?.split('T')[0] ?? data['joining_date']?.toString() ?? 'Not available';
          });
        }
      }
    } catch (e) {
      debugPrint('Profile fetch error: $e');
    }
  }

  Future<void> _fetchUserActivityData(String token) async {
    try {
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
            _activityData = ActivityData.fromJson(json['data']);
            _isLoading = false;
          });
        } else if (json['success'] == true && json['data'] != null) {
          setState(() {
            _activityData = ActivityData.fromJson(json['data']);
            _isLoading = false;
          });
        } else if (json['data'] != null) {
          setState(() {
            _activityData = ActivityData.fromJson(json['data']);
            _isLoading = false;
          });
        } else {
          setState(() {
            _activityData = ActivityData.empty();
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _activityData = ActivityData.empty();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Activity data fetch error: $e');
      setState(() {
        _activityData = ActivityData.empty();
        _isLoading = false;
      });
    }
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
                          padding: const EdgeInsets.only(top: 8, bottom: 20),
                          child: Column(
                            children: [
                              const SizedBox(height: 8),
                              _buildDashboardTitle(),
                              const SizedBox(height: 16),
                              _buildStatsGrid(),
                              const SizedBox(height: 16),
                              _buildGroupWiseAttendanceCard(),
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
              top: -50,
              right: -40,
              child: _circle(180, Colors.white.withOpacity(0.06)),
            ),
            Positioned(
              bottom: 8,
              left: 14,
              child: _circle(90, Colors.white.withOpacity(0.04)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back button
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.15),
                            border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5),
                          ),
                          child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                      // Welcome text
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Welcome back,',
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.8),
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              _userName.isNotEmpty ? _userName : 'Member',
                              style: GoogleFonts.cormorantGaramond(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ],
                        ),
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
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );

  Widget _buildDashboardTitle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: _kBrand,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Dashboard Overview',
            style: GoogleFonts.dmSans(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: _kTextPri,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final oneToOne = _activityData?.oneToOneCount ?? 0;
    final teamPoints = _activityData?.teamPoints ?? 0;
    final visitorCount = _activityData?.visitorCount ?? 0;
    final newJoining = _activityData?.newJoiningCount ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.3,
        children: [
          _statCard('One to One', oneToOne.toString(), Icons.people_alt_rounded, _kInfo),
          _statCard('Team Points', teamPoints.toString(), Icons.groups_rounded, _kSuccess),
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
              fontSize: 22,
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
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // New method to handle group-wise attendance display
  Widget _buildGroupWiseAttendanceCard() {
    final groupWise = _activityData?.groupWise ?? [];
    
    if (groupWise.isEmpty) {
      // Fallback to old single group display if no group-wise data
      return _buildLegacyAttendanceCard();
    }

    // Calculate number of groups for responsive layout
    final groupCount = groupWise.length;
    
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
            
            // Responsive layout based on number of groups
            if (groupCount == 1)
              _buildSingleGroupAttendance(groupWise[0])
            else if (groupCount == 2)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildGroupAttendanceTile(groupWise[0])),
                  const SizedBox(width: 16),
                  Container(
                    width: 1,
                    height: 120,
                    color: _kBorder,
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: _buildGroupAttendanceTile(groupWise[1])),
                ],
              )
            else
              // For 3 or more groups, use responsive grid
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth > 600) {
                    // Tablet/Web: Show in a row
                    return Row(
                      children: List.generate(
                        groupCount > 3 ? 3 : groupCount,
                        (index) => Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: index < (groupCount > 3 ? 3 : groupCount) - 1 ? 16 : 0,
                            ),
                            child: _buildGroupAttendanceTile(groupWise[index]),
                          ),
                        ),
                      ),
                    );
                  } else {
                    // Mobile: Show in a scrollable horizontal list or wrap
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(
                          groupCount,
                          (index) => Container(
                            width: 200,
                            margin: EdgeInsets.only(right: index < groupCount - 1 ? 16 : 0),
                            child: _buildGroupAttendanceTile(groupWise[index]),
                          ),
                        ),
                      ),
                    );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  // Single group display (centered)
  Widget _buildSingleGroupAttendance(GroupWiseData group) {
    final attended = group.attendanceCount;
    final totalMeetings = group.totalMeetings;
    final percentage = totalMeetings > 0 ? (attended / totalMeetings) * 100 : 0;
    
    return Center(
      child: SizedBox(
        width: 280,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _kBrandLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                group.groupName,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _kBrand,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$attended / $totalMeetings',
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

  // Individual group attendance tile for multi-group display
  Widget _buildGroupAttendanceTile(GroupWiseData group) {
    final attended = group.attendanceCount;
    final totalMeetings = group.totalMeetings;
    final percentage = totalMeetings > 0 ? (attended / totalMeetings) * 100 : 0;
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_kBrand, _kPlum],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            _truncateGroupName(group.groupName),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '$attended / $totalMeetings',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _kBrand,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Attended',
          style: GoogleFonts.inter(
            fontSize: 10,
            color: _kTextMuted,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 70,
                height: 70,
                child: CircularProgressIndicator(
                  value: percentage / 100,
                  strokeWidth: 6,
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
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _kBrand,
                    ),
                  ),
                  Text(
                    'Rate',
                    style: GoogleFonts.inter(
                      fontSize: 8,
                      color: _kTextMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _truncateGroupName(String name) {
    if (name.length <= 15) return name;
    return '${name.substring(0, 12)}...';
  }

  // Legacy fallback for backward compatibility
  Widget _buildLegacyAttendanceCard() {
    final attended = _activityData?.attendanceCount ?? 0;
    final totalMeetings = _activityData?.totalMeeting ?? 0;
    final percentage = totalMeetings > 0 ? (attended / totalMeetings) * 100 : 0;
    
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
                      '$attended / $totalMeetings',
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
    final refGiven = _activityData?.refGiven ?? 0;
    final refReceived = _activityData?.refReceived ?? 0;

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
    final chiefGuest = _activityData?.chiefGuestCount ?? 0;
    final bonusPoint = _activityData?.bonusPoint ?? 0;

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
                    'Bonus Point',
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
          Text(_errorMessage!, style: GoogleFonts.inter(fontSize: 14, color: _kTextSec)),
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

// Helper function to safely convert dynamic values to int
int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is String) return int.tryParse(value) ?? 0;
  if (value is double) return value.toInt();
  return 0;
}

// Group-wise data model
class GroupWiseData {
  final String groupName;
  final int totalMeetings;
  final int attendanceCount;

  GroupWiseData({
    required this.groupName,
    required this.totalMeetings,
    required this.attendanceCount,
  });

  factory GroupWiseData.fromJson(Map<String, dynamic> json) {
    return GroupWiseData(
      groupName: json['group_name']?.toString() ?? '',
      totalMeetings: _toInt(json['total_meetings']),
      attendanceCount: _toInt(json['attendance_count']),
    );
  }
}

// Data model class for user activity API response
class ActivityData {
  final int id;
  final String name;
  final String mobile;
  final String userGroup;
  final String category;
  final int attendanceCount;
  final int totalMeeting;
  final int refReceived;
  final int refGiven;
  final int oneToOneCount;
  final int teamPoints;
  final int visitorCount;
  final int chiefGuestCount;
  final int newJoiningCount;
  final int bonusPoint;
  final List<GroupWiseData> groupWise; // New field for group-wise data

  ActivityData({
    required this.id,
    required this.name,
    required this.mobile,
    required this.userGroup,
    required this.category,
    required this.attendanceCount,
    required this.totalMeeting,
    required this.refReceived,
    required this.refGiven,
    required this.oneToOneCount,
    required this.teamPoints,
    required this.visitorCount,
    required this.chiefGuestCount,
    required this.newJoiningCount,
    required this.bonusPoint,
    required this.groupWise,
  });

  factory ActivityData.fromJson(Map<String, dynamic> json) {
    // Parse group_wise array
    List<GroupWiseData> groupWiseList = [];
    if (json['group_wise'] != null && json['group_wise'] is List) {
      groupWiseList = (json['group_wise'] as List)
          .map((group) => GroupWiseData.fromJson(group))
          .toList();
    }
    
    return ActivityData(
      id: _toInt(json['id']),
      name: json['name']?.toString() ?? '',
      mobile: json['mobile']?.toString() ?? '',
      userGroup: json['user_group']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      attendanceCount: _toInt(json['attendance_count']),
      totalMeeting: _toInt(json['total_meeting']),
      refReceived: _toInt(json['ref_received']),
      refGiven: _toInt(json['ref_given']),
      oneToOneCount: _toInt(json['onetoone_count']),
      teamPoints: _toInt(json['team_points']),
      visitorCount: _toInt(json['visitor_count']),
      chiefGuestCount: _toInt(json['chief_guest_count']),
      newJoiningCount: _toInt(json['newjoining_count']),
      bonusPoint: _toInt(json['bonus_point']),
      groupWise: groupWiseList,
    );
  }

  factory ActivityData.empty() {
    return ActivityData(
      id: 0,
      name: '',
      mobile: '',
      userGroup: '',
      category: '',
      attendanceCount: 0,
      totalMeeting: 0,
      refReceived: 0,
      refGiven: 0,
      oneToOneCount: 0,
      teamPoints: 0,
      visitorCount: 0,
      chiefGuestCount: 0,
      newJoiningCount: 0,
      bonusPoint: 0,
      groupWise: [],
    );
  }
}