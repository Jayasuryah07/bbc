import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yaani/Views/Screens/Bbc/BoosterClub.dart';
import 'package:yaani/Views/Screens/Bbc/JoinBBc.dart';
import 'package:yaani/Views/Screens/Bbc/PersonalInfoPage.dart';
import 'package:yaani/Views/Screens/Bbc/profilebbc.dart';


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

// Birthday & Anniversary theme colors
const _kBirthdayGold = Color(0xFFFFD700);
const _kBirthdayOrange = Color(0xFFFF8C42);
const _kBirthdayPink = Color(0xFFFF6B6B);
const _kAnniversaryPurple = Color(0xFF9B59B6);
const _kAnniversaryRose = Color(0xFFE84393);

// Base URL for images
const String _imageBaseUrl = 'http://businessboosters.club/public/images/user_images/';

class HomePageBbc extends StatefulWidget {
  const HomePageBbc({super.key});

  @override
  State<HomePageBbc> createState() => _HomePageBbcState();
}

class _HomePageBbcState extends State<HomePageBbc> {
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _birthdayMembers = [];
  List<Map<String, dynamic>> _anniversaryMembers = [];
  bool _isLoading = true;
  bool _isLoadingDetails = false;
  String? _errorMessage;
  String _searchQuery = '';
  String? _userId;
  String? _userName;
  
  // Lead creation dialog controllers
  final TextEditingController _leadAmountController = TextEditingController();
  String? _selectedMemberId;
  Map<String, dynamic>? _selectedMember;

  // Cache for member details
  final Map<String, Map<String, dynamic>> _memberDetailsCache = {};
  
  // Track loading states for individual members
  final Map<String, bool> _memberLoadingStates = {};

  // Scroll controller for collapsible header
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _getUserIdAndFetchMembers();
    _scrollController.addListener(() {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
    });
  }

  @override
  void dispose() {
    _leadAmountController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

 Future<void> _getUserIdAndFetchMembers() async {
  final prefs = await SharedPreferences.getInstance();
  _userId = prefs.getString('bbc_user_id');
  _userName = prefs.getString('bbc_user_name');
  
  // ✅ ADD THIS LINE - Debug token status
  _debugTokenStatus();
  
  await _fetchMembers();
}
  // Check if today is member's birthday
  bool _isBirthdayToday(String? dob) {
    if (dob == null || dob.isEmpty) return false;
    
    try {
      final today = DateTime.now();
      String dateStr = dob;
      
      if (dateStr.contains('-') && dateStr.length == 10) {
        final parts = dateStr.split('-');
        if (parts.length == 3) {
          final month = int.parse(parts[1]);
          final day = int.parse(parts[2]);
          return today.month == month && today.day == day;
        }
      }
      
      if (dateStr.contains('/')) {
        final parts = dateStr.split('/');
        if (parts.length == 3) {
          final month = int.parse(parts[1]);
          final day = int.parse(parts[0]);
          return today.month == month && today.day == day;
        }
      }
    } catch (e) {
      debugPrint('Error parsing birthday: $e');
    }
    return false;
  }

  // Check if today is member's anniversary
  bool _isAnniversaryToday(String? doa) {
    if (doa == null || doa.isEmpty) return false;
    
    try {
      final today = DateTime.now();
      String dateStr = doa;
      
      if (dateStr.contains('-') && dateStr.length == 10) {
        final parts = dateStr.split('-');
        if (parts.length == 3) {
          final month = int.parse(parts[1]);
          final day = int.parse(parts[2]);
          return today.month == month && today.day == day;
        }
      }
      
      if (dateStr.contains('/')) {
        final parts = dateStr.split('/');
        if (parts.length == 3) {
          final month = int.parse(parts[1]);
          final day = int.parse(parts[0]);
          return today.month == month && today.day == day;
        }
      }
    } catch (e) {
      debugPrint('Error parsing anniversary: $e');
    }
    return false;
  }

 Future<void> _fetchMembers() async {
  setState(() {
    _isLoading = true;
    _errorMessage = null;
    _birthdayMembers.clear();
    _anniversaryMembers.clear();
  });

  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('bbc_token');

    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('📡 FETCHING MEMBERS - API CALL DEBUG');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('Token value: ${token ?? "NULL"}');
    debugPrint('Token length: ${token?.length ?? 0}');

    if (token == null || token.isEmpty) {
      debugPrint('❌ TOKEN IS NULL OR EMPTY!');
      setState(() {
        _errorMessage = 'Please login again';
        _isLoading = false;
      });
      return;
    }

    List<Map<String, dynamic>> allMembers = [];
    
    try {
      debugPrint('📤 Making API call to: https://businessboosters.club/public/api/fetch-active-member');
      debugPrint('📤 Headers: Authorization: Bearer ${token.substring(0, token.length > 20 ? 20 : token.length)}...');
      
      final response = await http.get(
        Uri.parse('https://businessboosters.club/public/api/fetch-active-member'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      
      debugPrint('📥 Response Status Code: ${response.statusCode}');
      debugPrint('📥 Response Body (first 500 chars): ${response.body.length > 500 ? response.body.substring(0, 500) : response.body}');
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final membersData = json['data'] ?? [];
        debugPrint('✅ Success! Found ${membersData.length} members in response');
        
        if (membersData is List) {
          for (var member in membersData) {
            if (member['id'].toString() == _userId) continue;
            
            final parsed = {
              'id': member['id']?.toString() ?? '',
              'name': member['name']?.toString() ?? 'Unknown User',
              'mobile': member['mobile']?.toString() ?? '',
              'company': 'Loading...',
              'occupation': 'Loading...',
              'email': '',
              'address': '',
              'product_services': '',
              'profile_image': '',
              'image_loaded': false,
              'dob': '',
              'doa': '',
            };
            allMembers.add(parsed);
            _memberLoadingStates[member['id'].toString()] = false;
          }
          debugPrint('Found ${membersData.length} active members');
        }
      } else if (response.statusCode == 401 || response.body.contains('Route [login]')) {
        debugPrint('❌ AUTHENTICATION FAILED! Token may be expired.');
        debugPrint('❌ Response contains "Route [login]": ${response.body.contains('Route [login]')}');
        setState(() {
          _errorMessage = 'Session expired. Please login again.';
          _isLoading = false;
        });
        return;
      } else {
        debugPrint('⚠️ Unexpected status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching active members: $e');
    }
    
    if (allMembers.isEmpty) {
      setState(() {
        _members = [];
        _isLoading = false;
        _errorMessage = 'No active members found in your network';
      });
      return;
    }
    
    setState(() {
      _members = allMembers;
      _isLoading = false;
    });
    
    await _loadMemberDetailsSequentially(token!);
    
  } catch (e) {
    debugPrint('Fetch members error: $e');
    setState(() {
      _errorMessage = 'Network error: $e';
      _isLoading = false;
    });
  }
}

  Future<Map<String, dynamic>?> _fetchMemberDetails(String memberId, String token) async {
  try {
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('📡 FETCH USER BY ID DEBUG');
    debugPrint('Member ID: $memberId');
    debugPrint('Token being used: ${token.substring(0, token.length > 30 ? 30 : token.length)}...');
    
    final response = await http.post(
      Uri.parse('https://businessboosters.club/public/api/fetch-user-by-id'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'user_id': memberId}),
    ).timeout(const Duration(seconds: 15));
    
    debugPrint('Response Status: ${response.statusCode}');
    debugPrint('Response Body Preview: ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}');
    
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['code'] == 200 && json['data'] != null) {
        debugPrint('✅ Successfully fetched details for member $memberId');
        return _parseMemberData(json['data']);
      } else {
        debugPrint('⚠️ API returned code: ${json['code']}, message: ${json['message']}');
      }
    } else if (response.statusCode == 401 || response.body.contains('Route [login]')) {
      debugPrint('❌ AUTHENTICATION FAILED for fetch-user-by-id!');
    }
  } catch (e) {
    debugPrint('Error fetching member details for $memberId: $e');
  }
  return null;
}
  Map<String, dynamic> _parseMemberData(dynamic data) {
    String profileImage = '';
    final imageFileName = data['profile_image']?.toString() ?? data['image']?.toString() ?? '';
    if (imageFileName.isNotEmpty && imageFileName != 'no_images.png' && imageFileName != 'null') {
      profileImage = '$_imageBaseUrl$imageFileName';
    }
    
    String dob = data['person_dob']?.toString() ?? data['dob']?.toString() ?? '';
    String doa = data['person_doa']?.toString() ?? data['anniversary']?.toString() ?? data['doa']?.toString() ?? '';
    
    return {
      'id': data['id']?.toString() ?? '',
      'name': data['person_name']?.toString() ?? data['name']?.toString() ?? 'Unknown',
      'mobile': data['person_mobile']?.toString() ?? data['mobile']?.toString() ?? '',
      'company': data['person_company']?.toString() ?? data['company']?.toString() ?? 'Business Professional',
      'occupation': data['person_occupation']?.toString() ?? data['occupation']?.toString() ?? 'Member',
      'email': data['person_email']?.toString() ?? data['email']?.toString() ?? '',
      'address': data['person_address']?.toString() ?? data['address']?.toString() ?? '',
      'product_services': data['person_service']?.toString() ?? data['product']?.toString() ?? data['product_services']?.toString() ?? '',
      'profile_image': profileImage,
      'dob': dob,
      'doa': doa,
    };
  }

  Future<void> _loadMemberDetailsSequentially(String token) async {
    setState(() {
      _isLoadingDetails = true;
    });
    
    for (int i = 0; i < _members.length; i++) {
      final memberId = _members[i]['id'];
      
      if (_memberDetailsCache.containsKey(memberId)) continue;
      
      setState(() {
        _memberLoadingStates[memberId] = true;
      });
      
      try {
        final details = await _fetchMemberDetails(memberId, token);
        if (details != null && mounted) {
          _memberDetailsCache[memberId] = details;
          
          final hasBirthday = _isBirthdayToday(details['dob']);
          final hasAnniversary = _isAnniversaryToday(details['doa']);
          
          setState(() {
            final index = _members.indexWhere((m) => m['id'] == memberId);
            if (index != -1) {
              _members[index]['company'] = details['company'] ?? 'Business Professional';
              _members[index]['occupation'] = details['occupation'] ?? 'Member';
              _members[index]['email'] = details['email'] ?? '';
              _members[index]['address'] = details['address'] ?? '';
              _members[index]['product_services'] = details['product_services'] ?? '';
              _members[index]['profile_image'] = details['profile_image'] ?? '';
              _members[index]['image_loaded'] = true;
              _members[index]['dob'] = details['dob'] ?? '';
              _members[index]['doa'] = details['doa'] ?? '';
              _memberLoadingStates[memberId] = false;
            }
            
            if (hasBirthday) {
              final memberData = {..._members[index]};
              if (!_birthdayMembers.any((m) => m['id'] == memberId)) {
                _birthdayMembers.add(memberData);
              }
            }
            
            if (hasAnniversary) {
              final memberData = {..._members[index]};
              if (!_anniversaryMembers.any((m) => m['id'] == memberId)) {
                _anniversaryMembers.add(memberData);
              }
            }
          });
        }
      } catch (e) {
        debugPrint('Error loading member $memberId: $e');
        setState(() {
          _memberLoadingStates[memberId] = false;
        });
      }
      
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    setState(() {
      _isLoadingDetails = false;
    });
  }

  void _addTestCelebrationMembers() {
    final today = DateTime.now();
    final todayFormatted = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
    
    final testBirthdayMember = {
      'id': 'test_birthday_1',
      'name': '🎂 TEST - Birthday Today',
      'mobile': '9999999991',
      'company': 'Birthday Test Company',
      'occupation': 'Celebrating Birthday',
      'email': 'test@birthday.com',
      'address': 'Test Address',
      'product_services': 'Birthday Celebration Services',
      'profile_image': '',
      'image_loaded': false,
      'dob': todayFormatted,
      'doa': '',
    };
    
    final testAnniversaryMember = {
      'id': 'test_anniversary_1',
      'name': '💕 TEST - Anniversary Today',
      'mobile': '9999999993',
      'company': 'Anniversary Test Company',
      'occupation': 'Celebrating Anniversary',
      'email': 'test@anniversary.com',
      'address': 'Test Address',
      'product_services': 'Anniversary Celebration Services',
      'profile_image': '',
      'image_loaded': false,
      'dob': '',
      'doa': todayFormatted,
    };
    
    setState(() {
      _birthdayMembers.add(testBirthdayMember);
      _anniversaryMembers.add(testAnniversaryMember);
    });
  }

  Future<void> _createLead(String toUserId) async {
    if (_leadAmountController.text.trim().isEmpty) {
      _showSnackBar('Please enter lead amount');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('bbc_token');
      final userId = prefs.getString('bbc_user_id');

      if (token == null || userId == null) {
        _showSnackBar('Please login again');
        setState(() => _isLoading = false);
        return;
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://businessboosters.club/public/api/create-lead'),
      );
      
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['lead_date'] = DateTime.now().toIso8601String().split('T')[0];
      request.fields['lead_from_id'] = userId;
      request.fields['lead_to_id'] = toUserId;
      request.fields['lead_amount'] = _leadAmountController.text.trim();
      
      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();
      
      if (streamedResponse.statusCode == 200 || streamedResponse.statusCode == 201) {
        _showSnackBar('Lead sent successfully!');
        if (mounted) Navigator.pop(context);
        _leadAmountController.clear();
        _selectedMember = null;
        _selectedMemberId = null;
      } else {
        try {
          final json = jsonDecode(responseBody);
          _showSnackBar(json['msg'] ?? 'Failed to send lead');
        } catch (e) {
          _showSnackBar('Lead sent successfully!');
          if (mounted) Navigator.pop(context);
        }
      }
    } catch (e) {
      _showSnackBar('Network error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showLeadDialog(Map<String, dynamic> member) {
    setState(() {
      _selectedMember = member;
      _selectedMemberId = member['id'];
    });
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_kBrand, _kPlum],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Send Lead',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: _kTextPri,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _kBrandLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.close, size: 18, color: _kBrand),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _kBrandLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    _buildSmallAvatar(member['name'], member['profile_image'], member['image_loaded'] ?? false),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member['name'],
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _kTextPri,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            member['company'],
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: _kTextSec,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Lead Amount',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _kTextSec,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: _kInputBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _kBorder, width: 1.5),
                ),
                child: TextFormField(
                  controller: _leadAmountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: GoogleFonts.inter(fontSize: 16, color: _kTextPri),
                  decoration: InputDecoration(
                    hintText: 'Enter amount in INR',
                    hintStyle: GoogleFonts.inter(fontSize: 14, color: _kTextMuted),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    prefixIcon: Icon(Icons.currency_rupee, size: 20, color: _kBrand),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _leadAmountController.clear();
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kTextSec,
                        side: BorderSide(color: _kBorder),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _createLead(member['id']),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kBrand,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Send Lead',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmallAvatar(String name, String? imageUrl, bool imageLoaded) {
    if (imageLoaded && imageUrl != null && imageUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          imageUrl,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildSmallTextAvatar(name);
          },
        ),
      );
    }
    return _buildSmallTextAvatar(name);
  }

  Widget _buildSmallTextAvatar(String name) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kPlum.withOpacity(0.8), _kBrand.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'U',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(fontSize: 13, color: Colors.white)),
        backgroundColor: _kTextPri,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        duration: const Duration(seconds: 3),
      ),
    );
  }
// Add this method right after the class starts
void _debugTokenStatus() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('bbc_token');
  final userId = prefs.getString('bbc_user_id');
  final userName = prefs.getString('bbc_user_name');
  
  debugPrint('═══════════════════════════════════════════');
  debugPrint('🔍 BBC TOKEN DEBUG INFORMATION');
  debugPrint('═══════════════════════════════════════════');
  debugPrint('📱 User ID: $userId');
  debugPrint('👤 User Name: $userName');
  debugPrint('🔑 Token exists: ${token != null}');
  debugPrint('🔑 Token is empty: ${token == ""}');
  debugPrint('🔑 Token length: ${token?.length ?? 0}');
  
  if (token != null && token.isNotEmpty) {
    debugPrint('🔑 Token preview: ${token.substring(0, token.length > 50 ? 50 : token.length)}...');
    debugPrint('🔑 Token starts with "Bearer "? ${token.startsWith('Bearer ')}');
    
    // Try to decode JWT token to check expiration
    try {
      final parts = token.split('.');
      if (parts.length == 3) {
        final payload = jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))
        );
        debugPrint('📅 Token expiration: ${DateTime.fromMillisecondsSinceEpoch(payload['exp'] * 1000)}');
        debugPrint('⏰ Is token expired? ${DateTime.now().isAfter(DateTime.fromMillisecondsSinceEpoch(payload['exp'] * 1000))}');
      }
    } catch (e) {
      debugPrint('⚠️ Could not decode token (might not be JWT): $e');
    }
  } else {
    debugPrint('❌ NO TOKEN FOUND! User needs to login again.');
  }
  debugPrint('═══════════════════════════════════════════');
}
  List<Map<String, dynamic>> get _filteredMembers {
    if (_searchQuery.isEmpty) return _members;
    return _members.where((member) {
      return member['name'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
             member['company'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
             (member['mobile']?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isHeaderCollapsed = _scrollOffset > 80;
    
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _kBg,
        body: Column(
          children: [
            // Collapsible Header
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: isHeaderCollapsed ? 90 : 220,
              child: _buildHeader(isHeaderCollapsed),
            ),
            // Birthday Section
            _buildBirthdaySection(),
            // Anniversary Section
            _buildAnniversarySection(),
            // Search Bar (always visible)
            _buildSearchBar(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(_kBrand),
                      ),
                    )
                  : _errorMessage != null
                      ? _buildErrorView()
                      : _filteredMembers.isEmpty
                          ? _buildEmptyView()
                          : RefreshIndicator(
                              onRefresh: _fetchMembers,
                              color: _kBrand,
                              child: ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.only(top: 8, bottom: 80),
                                itemCount: _filteredMembers.length,
                                itemBuilder: (context, index) {
                                  final member = _filteredMembers[index];
                                  return _buildMemberCard(member, index);
                                },
                              ),
                            ),
            ),
            _buildBottomNav(context),
          ],
        ),
      ),
    );
  }

  // Collapsible Header
  Widget _buildHeader(bool isCollapsed) {
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
              child: _circle(180, Colors.white.withOpacity(0.06))),
            Positioned(
              bottom: 8,
              left: 14,
              child: _circle(90, Colors.white.withOpacity(0.04))),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, isCollapsed ? 12 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          // Logo - shrink when collapsed
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: isCollapsed ? 36 : 52,
                            height: isCollapsed ? 36 : 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.15),
                              border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5),
                            ),
                            child: Center(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: isCollapsed ? 24 : 38,
                                height: isCollapsed ? 24 : 38,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.92),
                                ),
                                child: Center(
                                  child: Image.asset(
                                    'assets/images/bbclogo.png',
                                    width: isCollapsed ? 14 : 24,
                                    height: isCollapsed ? 14 : 24,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => Icon(Icons.business_center_rounded, color: _kBrand, size: isCollapsed ? 14 : 20),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Text - hide when collapsed
                        
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Business Boosters Club',
                                    style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white)),
                                const SizedBox(height: 2),
                                Text('PREMIUM NETWORK',
                                    style: GoogleFonts.inter(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1.2,
                                        color: Colors.white.withOpacity(0.55))),
                              ],
                            ),
                        ],
                      ),
                      // Member count - always visible
                    
                    ],
                  ),
                  // Expanded content - hide when collapsed
                  if (!isCollapsed) ...[
                    const SizedBox(height: 16),
                    Text('NETWORK',
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                            color: Colors.white.withOpacity(0.6))),
                    const SizedBox(height: 5),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Connect with\n',
                            style: GoogleFonts.playfairDisplay(
                                fontSize: 28,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                height: 1.1),
                          ),
                          TextSpan(
                            text: 'Business Leaders',
                            style: GoogleFonts.playfairDisplay(
                                fontSize: 28,
                                fontWeight: FontWeight.w600,
                                fontStyle: FontStyle.italic,
                                color: const Color(0xFFFFDCF0).withOpacity(0.95),
                                height: 1.1),
                          ),
                        ],
                      ),
                    ),
                  ],
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

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                style: GoogleFonts.inter(fontSize: 14, color: _kTextPri),
                decoration: InputDecoration(
                  hintText: 'Search by name, company or mobile...',
                  hintStyle: GoogleFonts.inter(fontSize: 14, color: _kTextMuted),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  prefixIcon: Icon(Icons.search_rounded, size: 22, color: _kTextMuted),
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              IconButton(
                onPressed: () => setState(() => _searchQuery = ''),
                icon: Icon(Icons.close_rounded, size: 20, color: _kTextMuted),
              ),
          ],
        ),
      ),
    );
  }

  // Birthday Section
  Widget _buildBirthdaySection() {
    if (_birthdayMembers.isEmpty) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_kBirthdayOrange, _kBirthdayPink],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.cake_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Birthday Celebrations 🎂',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _kTextPri,
                      ),
                    ),
                    Text(
                      'Wish our members on their special day',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: _kTextMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _birthdayMembers.length,
              itemBuilder: (context, index) {
                final member = _birthdayMembers[index];
                return _buildBirthdayCard(member);
              },
            ),
          ),
        ],
      ),
    );
  }

  // Anniversary Section
  Widget _buildAnniversarySection() {
    if (_anniversaryMembers.isEmpty) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_kAnniversaryPurple, _kAnniversaryRose],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Anniversary Celebrations 💕',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _kTextPri,
                      ),
                    ),
                    Text(
                      'Celebrating love and commitment',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: _kTextMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _anniversaryMembers.length,
              itemBuilder: (context, index) {
                final member = _anniversaryMembers[index];
                return _buildAnniversaryCard(member);
              },
            ),
          ),
        ],
      ),
    );
  }

  // Birthday Card
  Widget _buildBirthdayCard(Map<String, dynamic> member) {
    final imageLoaded = member['image_loaded'] ?? false;
    
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _kBirthdayGold.withOpacity(0.15),
            _kBirthdayOrange.withOpacity(0.1),
            _kBirthdayPink.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _kBirthdayGold.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _kBirthdayOrange.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _kBirthdayGold.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _kBirthdayPink.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _kBirthdayGold,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _kBirthdayOrange.withOpacity(0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: imageLoaded && member['profile_image'] != null && member['profile_image'].toString().isNotEmpty
                            ? Image.network(
                                member['profile_image'],
                                width: 70,
                                height: 70,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _buildBirthdayAvatarText(member['name']),
                              )
                            : _buildBirthdayAvatarText(member['name']),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_kBirthdayGold, _kBirthdayOrange],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.cake_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  member['name'].length > 15 ? '${member['name'].substring(0, 12)}...' : member['name'],
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _kTextPri,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  member['occupation'] == 'Loading...' ? 'Business Professional' : member['occupation'],
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: _kBirthdayOrange,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    _showBirthdayWishDialog(member);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_kBirthdayGold, _kBirthdayOrange],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.celebration_rounded, size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          'Wish',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Anniversary Card
  Widget _buildAnniversaryCard(Map<String, dynamic> member) {
    final imageLoaded = member['image_loaded'] ?? false;
    
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _kAnniversaryPurple.withOpacity(0.15),
            _kAnniversaryRose.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _kAnniversaryPurple.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _kAnniversaryPurple.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _kAnniversaryPurple.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _kAnniversaryRose.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _kAnniversaryPurple,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _kAnniversaryPurple.withOpacity(0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: imageLoaded && member['profile_image'] != null && member['profile_image'].toString().isNotEmpty
                            ? Image.network(
                                member['profile_image'],
                                width: 70,
                                height: 70,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _buildAnniversaryAvatarText(member['name']),
                              )
                            : _buildAnniversaryAvatarText(member['name']),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_kAnniversaryPurple, _kAnniversaryRose],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  member['name'].length > 15 ? '${member['name'].substring(0, 12)}...' : member['name'],
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _kTextPri,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  member['occupation'] == 'Loading...' ? 'Business Professional' : member['occupation'],
                  style: GoogleFonts.inter(
                    fontSize: 8,
                    color: _kAnniversaryPurple,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    _showAnniversaryWishDialog(member);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_kAnniversaryPurple, _kAnniversaryRose],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.favorite_rounded, size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          'Wish',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBirthdayAvatarText(String name) {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kBirthdayGold, _kBirthdayOrange],
        ),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'U',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildAnniversaryAvatarText(String name) {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kAnniversaryPurple, _kAnniversaryRose],
        ),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'U',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  void _showBirthdayWishDialog(Map<String, dynamic> member) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.white,
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [_kBirthdayGold, _kBirthdayOrange],
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.cake_rounded, size: 40, color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Happy Birthday!',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _kBirthdayOrange,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                member['name'],
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _kTextPri,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: _kBirthdayGold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Wish ${member['name']} a very happy birthday! Send your warm wishes and celebrate their special day.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: _kTextSec,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _kBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text('Close', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _sendWish(member, 'birthday');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kBirthdayOrange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                          const SizedBox(width: 6),
                          Text('Send Wish', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAnniversaryWishDialog(Map<String, dynamic> member) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.white,
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [_kAnniversaryPurple, _kAnniversaryRose],
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.favorite_rounded, size: 40, color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Happy Anniversary!',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _kAnniversaryPurple,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                member['name'],
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _kTextPri,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: _kAnniversaryPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Wish ${member['name']} a very happy anniversary! Send your warm wishes and celebrate their special day.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: _kTextSec,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _kBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text('Close', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _sendWish(member, 'anniversary');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kAnniversaryPurple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                          const SizedBox(width: 6),
                          Text('Send Wish', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _sendWish(Map<String, dynamic> member, String type) {
    final mobile = member['mobile'];
    if (mobile.isNotEmpty) {
      String cleanMobile = mobile.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanMobile.startsWith('0')) cleanMobile = cleanMobile.substring(1);
      if (!cleanMobile.startsWith('91')) cleanMobile = '91$cleanMobile';
      
      String message;
      if (type == 'birthday') {
        message = Uri.encodeComponent('🎂 Happy Birthday ${member['name']}! 🎉🥳\n\nWishing you a fantastic year ahead filled with success, happiness, and prosperity.\n\nWarm Regards,\nBusiness Boosters Club');
      } else {
        message = Uri.encodeComponent('💕 Happy Anniversary ${member['name']}! 💑\n\nWishing you both a lifetime of love, happiness, and togetherness.\n\nWarm Regards,\nBusiness Boosters Club');
      }
      
      final Uri whatsappUri = Uri.parse('https://wa.me/$cleanMobile?text=$message');
      
      canLaunchUrl(whatsappUri).then((canLaunch) {
        if (canLaunch) {
          launchUrl(whatsappUri);
        } else {
          _showSnackBar('WhatsApp not installed');
        }
      });
    } else {
      _showSnackBar('No mobile number available');
    }
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
            onPressed: _fetchMembers,
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

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: _kTextMuted),
          const SizedBox(height: 16),
          Text('No members found', style: GoogleFonts.inter(fontSize: 14, color: _kTextSec)),
          const SizedBox(height: 8),
          Text('Pull down to refresh', style: GoogleFonts.inter(fontSize: 12, color: _kTextMuted)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchMembers,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kBrand,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Refresh', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Member Avatar with Square shape
  Widget _buildMemberAvatar(String name, String? imageUrl, bool imageLoaded) {
    if (imageLoaded && imageUrl != null && imageUrl.isNotEmpty) {
      return Container(
        width: 80,
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: _kBrand.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.network(
            imageUrl,
            width: 70,
            height: 70,
            fit: BoxFit.fill,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_kPlum.withOpacity(0.8), _kBrand.withOpacity(0.8)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return _buildMemberTextAvatar(name);
            },
          ),
        ),
      );
    }
    return _buildMemberTextAvatar(name);
  }

  Widget _buildMemberTextAvatar(String name) {
    return Container(
      width: 80,
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kPlum, _kBrand],
        ),
        border: Border.all(
          color: Colors.white,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: _kBrand.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'U',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // Member Card
  Widget _buildMemberCard(Map<String, dynamic> member, int index) {
  final isLoading = _memberLoadingStates[member['id']] ?? false;
  final imageLoaded = member['image_loaded'] ?? false;
  
  return GestureDetector(
    onTap: () async {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileDetailPage(
            memberData: member,
          ),
        ),
      );
    },
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: _kBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top section: Avatar + Info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar - Left
              _buildMemberAvatar(member['name'], member['profile_image'], imageLoaded),
              const SizedBox(width: 14),
              
              // Info - Middle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      member['name'],
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: _kTextPri,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    
                    // Company
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: _kBrandLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(Icons.business_center_rounded, size: 12, color: _kBrand),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  member['company'] == 'Loading...' ? 'Loading...' : member['company'],
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: member['company'] == 'Loading...' ? _kTextMuted : _kBrand,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isLoading) ...[
                                const SizedBox(width: 6),
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: _kBrand),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    
                    // Occupation
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: _kBrandLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(Icons.work_outline, size: 12, color: _kBrand),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            member['occupation'] == 'Loading...' ? 'Business Professional' : member['occupation'],
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: _kTextSec,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    
                    // Mobile
                  Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
               GestureDetector(
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileDetailPage(
          memberData: member,
        ),
      ),
    );
  },
  child: Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: _kBrand,
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Icon(
      Icons.remove_red_eye_outlined,
      color: Colors.white,
      size: 18,
    ),
  ),
),
              
                  ],
                ),
                  ],
              ),
              ),
            ],
          ),
          
      
          
          // Bottom section: Send Lead Button - Right aligned
          
        ],
      ),
    ),
  );
}
  Widget _buildBottomNav(BuildContext context) {
    return Container(
      height: 65,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.home_filled, color: _kBrand, size: 22),
              const SizedBox(height: 4),
              Text('Home', style: GoogleFonts.inter(fontSize: 10, color: _kBrand, fontWeight: FontWeight.w500)),
            ],
          ),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const JoinAsMemberPage(),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/bbclogo.png',
                  width: 30,
                  height: 30,
                ),
                const SizedBox(height: 4),
                Text(
                  'Member',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: _kTextMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutUsPage()),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.link, color: _kTextMuted, size: 22),
                const SizedBox(height: 4),
                Text('About', style: GoogleFonts.inter(fontSize: 10, color: _kTextMuted, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfilePageBBcc()),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_outline, color: _kTextMuted, size: 22),
                const SizedBox(height: 4),
                Text('Profile', style: GoogleFonts.inter(fontSize: 10, color: _kTextMuted, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}