import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:new_version_plus/new_version_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yaani/Views/Screens/Bbc/BoosterClub.dart';
import 'package:yaani/Views/Screens/Bbc/JoinBBc.dart';
import 'package:yaani/Views/Screens/Bbc/PersonalInfoPage.dart';
import 'package:yaani/Views/Screens/Bbc/profilebbc.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:io';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

// ─── Brand tokens ──────────────────────────────────────────────────────────────
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
const _kBirthdayGold   = Color(0xFFFFD700);
const _kBirthdayOrange = Color(0xFFFF8C42);
const _kBirthdayPink   = Color(0xFFFF6B6B);
const _kAnniversaryPurple = Color(0xFF9B59B6);
const _kAnniversaryRose   = Color(0xFFE84393);

// Base URL for images
const String _imageBaseUrl =
    'http://businessboosters.club/public/images/user_images/';

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
  bool _isRefreshing = false;
  String? _errorMessage;
  String _searchQuery = '';
  String? _userId;
  String? _userName;
  bool _showUpdateBar = false;
 
  // Lead creation dialog controllers
  final TextEditingController _leadAmountController = TextEditingController();
  String? _selectedMemberId;
  Map<String, dynamic>? _selectedMember;

  // Cache for member details
  final Map<String, Map<String, dynamic>> _memberDetailsCache = {};

  // Scroll controller
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;
  
  // Slider data
  List<Map<String, dynamic>> _sliderItems = [];
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  
  // Carousel/Slider variables
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _autoSlideTimer;


Future<void> _checkForUpdate() async {
  final newVersion = NewVersionPlus(
    androidId: "com.bbc.agsolutions",
  );

  final status = await newVersion.getVersionStatus();

  if (status == null) return;

  if (status.canUpdate && mounted) {
    setState(() {
      _showUpdateBar = true;
    });
  }
}

  @override
  void initState() {
    super.initState();

    // ✅ Initialize PageController here
    _pageController = PageController();
    
    _getUserIdAndFetchMembers();
    _fetchSliders();



  WidgetsBinding.instance.addPostFrameCallback((_) {
    _checkForUpdate();
  });

    _scrollController.addListener(() {
      if (mounted) {
        setState(() {
          _scrollOffset = _scrollController.offset;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _leadAmountController.dispose();
    _scrollController.dispose();
    _pageController.dispose(); // ✅ Dispose the page controller
    _stopAutoSlide();
    _searchController.dispose();
    super.dispose();
  }

  void _startAutoSlide() {
    _stopAutoSlide();
    if (_sliderItems.isEmpty) return;
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_sliderItems.isNotEmpty && mounted && _pageController.hasClients) {
        final nextPage = (_currentPage + 1) % _sliderItems.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _stopAutoSlide() {
    _autoSlideTimer?.cancel();
    _autoSlideTimer = null;
  }

  void _closeSearch() {
    _searchFocusNode.unfocus();
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });
  }

  Future<void> _getUserIdAndFetchMembers() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('bbc_user_id');
    _userName = prefs.getString('bbc_user_name');
    await _fetchMembers();
  }

  // New method to clear all cache and refresh
  Future<void> _clearCacheAndRefresh() async {
    setState(() {
      _isRefreshing = true;
    });

    try {
      // Clear local memory cache
      _memberDetailsCache.clear();

      // Clear Flutter image cache
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      // Clear CachedNetworkImage cache
      await DefaultCacheManager().emptyCache();

      // Clear temporary files
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }

      _showSnackBar('Cache cleared successfully');

      // Reload data
      await _fetchMembers();
      await _fetchSliders();

      setState(() {
        _searchQuery = '';
      });

      _searchController.clear();

      _stopAutoSlide();
      _startAutoSlide();

      _showSnackBar('Fresh data loaded');
    } catch (e) {
      debugPrint('Cache clear error: $e');
      _showSnackBar('Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  bool _isBirthdayToday(String? dob) {
    if (dob == null || dob.isEmpty) return false;
    try {
      final today = DateTime.now();
      if (dob.contains('-') && dob.length == 10) {
        final parts = dob.split('-');
        if (parts.length == 3) {
          return today.month == int.parse(parts[1]) &&
              today.day == int.parse(parts[2]);
        }
      }
      if (dob.contains('/')) {
        final parts = dob.split('/');
        if (parts.length == 3) {
          return today.month == int.parse(parts[1]) &&
              today.day == int.parse(parts[0]);
        }
      }
    } catch (e) {
      debugPrint('Error parsing birthday: $e');
    }
    return false;
  }

  bool _isAnniversaryToday(String? doa) {
    if (doa == null || doa.isEmpty) return false;
    try {
      final today = DateTime.now();
      if (doa.contains('-') && doa.length == 10) {
        final parts = doa.split('-');
        if (parts.length == 3) {
          return today.month == int.parse(parts[1]) &&
              today.day == int.parse(parts[2]);
        }
      }
      if (doa.contains('/')) {
        final parts = doa.split('/');
        if (parts.length == 3) {
          return today.month == int.parse(parts[1]) &&
              today.day == int.parse(parts[0]);
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

      if (token == null || token.isEmpty) {
        setState(() {
          _errorMessage = 'Please login again';
          _isLoading = false;
        });
        return;
      }

      List<Map<String, dynamic>> allMembers = [];

      try {
        final response = await http.post(
          Uri.parse('https://businessboosters.club/public/api/fetch-user'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          final membersData = json['data'] ?? [];

          if (membersData is List) {
            for (var member in membersData) {
              final cached =
                  _memberDetailsCache[member['id'].toString()];

              allMembers.add({
                'id': member['id']?.toString() ?? '',
                'name': member['name']?.toString() ?? 'Unknown User',
                'mobile': member['mobile']?.toString() ?? '',
                'whatsapp_number':
                    member['whatsapp_number']?.toString() ??
                        member['mobile']?.toString() ??
                        '',
                'email': member['email']?.toString() ?? '',
                'company': cached?['company'] ??
                    member['company']?.toString() ??
                    'Loading...',
                'occupation': cached?['occupation'] ??
                    member['occupation']?.toString() ??
                    'Loading...',
                'product_services': cached?['product_services'] ??
                    member['product']?.toString() ??
                    '',
                'profile_image': cached?['profile_image'] ?? '',
                'image_loaded': cached != null,
                'dob': cached?['dob'] ?? '',
                'doa': cached?['doa'] ?? '',
                'wishes': member['wishes']?.toString() ?? '',
                'address': cached?['address'] ?? '',
                'area': member['area']?.toString() ?? '',
                'company_short':
                    member['company_short']?.toString() ?? '',
                'profile_tag': member['profile_tag']?.toString() ?? '',
                'referral_code':
                    member['referral_code']?.toString() ?? '',
                'is_current_user':
                    member['id'].toString() == _userId,
              });
            }
            debugPrint(
                'Found ${membersData.length} members from fetch-user API');
          }
        } else {
          debugPrint('API Error: ${response.statusCode}');
          debugPrint('Response body: ${response.body}');
        }
      } catch (e) {
        debugPrint('Error fetching members: $e');
      }

      if (allMembers.isEmpty) {
        setState(() {
          _members = [];
          _isLoading = false;
          _errorMessage = 'No members found';
        });
        return;
      }

      setState(() {
        _members = allMembers;
        _isLoading = false;
      });

      _loadMissingDetails(token);
    } catch (e) {
      debugPrint('Fetch members error: $e');
      setState(() {
        _errorMessage = 'Network error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMissingDetails(String token) async {
    for (int i = 0; i < _members.length; i++) {
      final memberId = _members[i]['id'];

      if (_memberDetailsCache.containsKey(memberId)) continue;

      try {
        final details = await _fetchMemberDetails(memberId, token);
        if (details != null && mounted) {
          _memberDetailsCache[memberId] = details;

          final hasBirthday = _isBirthdayToday(details['dob']);
          final hasAnniversary = _isAnniversaryToday(details['doa']);

          setState(() {
            final index =
                _members.indexWhere((m) => m['id'] == memberId);
            if (index != -1) {
              _members[index]['company'] =
                  details['company'] ?? 'Business Professional';
              _members[index]['occupation'] =
                  details['occupation'] ?? 'Member';
              _members[index]['email'] = details['email'] ?? '';
              _members[index]['address'] = details['address'] ?? '';
              _members[index]['product_services'] =
                  details['product_services'] ?? '';
              _members[index]['profile_image'] =
                  details['profile_image'] ?? '';
              _members[index]['image_loaded'] = true;
              _members[index]['dob'] = details['dob'] ?? '';
              _members[index]['doa'] = details['doa'] ?? '';
            }

            if (hasBirthday) {
              final memberData = {..._members[index]};
              if (!_birthdayMembers.any((m) => m['id'] == memberId)) {
                _birthdayMembers.add(memberData);
              }
            }

            if (hasAnniversary) {
              final memberData = {..._members[index]};
              if (!_anniversaryMembers
                  .any((m) => m['id'] == memberId)) {
                _anniversaryMembers.add(memberData);
              }
            }
          });
        }
      } catch (e) {
        debugPrint('Error loading member $memberId: $e');
      }

      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  Future<Map<String, dynamic>?> _fetchMemberDetails(
      String memberId, String token) async {
    try {
      final response = await http.post(
        Uri.parse(
            'https://businessboosters.club/public/api/fetch-user-by-id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'user_id': memberId}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['code'] == 200 && json['data'] != null) {
          final data = json['data'];

          String profileImage = '';
          final imageFileName =
              data['profile_image']?.toString() ??
                  data['image']?.toString() ??
                  '';
          if (imageFileName.isNotEmpty &&
              imageFileName != 'no_images.png' &&
              imageFileName != 'null') {
            profileImage = '$_imageBaseUrl$imageFileName';
          }

          return {
            'id': data['id']?.toString() ?? memberId,
            'name': data['person_name']?.toString() ??
                data['name']?.toString() ??
                'Unknown',
            'mobile': data['person_mobile']?.toString() ??
                data['mobile']?.toString() ??
                '',
            'company': data['person_company']?.toString() ??
                data['company']?.toString() ??
                'Business Professional',
            'occupation': data['person_occupation']?.toString() ??
                data['occupation']?.toString() ??
                'Member',
            'email': data['person_email']?.toString() ??
                data['email']?.toString() ??
                '',
            'address': data['person_address']?.toString() ??
                data['address']?.toString() ??
                '',
            'product_services': data['person_service']?.toString() ??
                data['product']?.toString() ??
                data['product_services']?.toString() ??
                '',
            'profile_image': profileImage,
            'dob': data['person_dob']?.toString() ??
                data['dob']?.toString() ??
                '',
            'doa': data['person_doa']?.toString() ??
                data['anniversary']?.toString() ??
                '',
          };
        }
      }
    } catch (e) {
      debugPrint('Error fetching member details for $memberId: $e');
    }
    return null;
  }

  Future<void> _refreshMembers() async {
    setState(() => _isRefreshing = true);
    await _fetchMembers();
    setState(() => _isRefreshing = false);
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
        Uri.parse(
            'https://businessboosters.club/public/api/create-lead'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.fields['lead_date'] =
          DateTime.now().toIso8601String().split('T')[0];
      request.fields['lead_from_id'] = userId;
      request.fields['lead_to_id'] = toUserId;
      request.fields['lead_amount'] =
          _leadAmountController.text.trim();

      final streamedResponse = await request.send();
      await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200 ||
          streamedResponse.statusCode == 201) {
        _showSnackBar('Lead sent successfully!');
        if (mounted) Navigator.pop(context);
        _leadAmountController.clear();
        _selectedMember = null;
        _selectedMemberId = null;
      } else {
        _showSnackBar('Failed to send lead. Please try again.');
      }
    } catch (e) {
      _showSnackBar('Network error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchSliders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('bbc_token');

      final response = await http.post(
        Uri.parse(
            'https://businessboosters.club/public/api/fetch-slider'),
        headers: {'Authorization': 'Bearer $token'},
      );

      debugPrint('Slider Response Status: ${response.statusCode}');
      debugPrint('Slider Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final data = json['data'] ?? [];

        setState(() {
          _sliderItems = List<Map<String, dynamic>>.from(
            data.map((e) => {
              'imageUrl': 'https://businessboosters.club/public/images/slider_images/${e['slider_image']}',
              'link': e['slider_link']?.toString() ?? '',
              'heading': e['slider_heading']?.toString() ?? '',
              'buttonText': e['slider_button_text']?.toString() ?? '',
            }),
          );
        });
        
        _stopAutoSlide();
        _startAutoSlide();
      }
    } catch (e) {
      debugPrint('Slider Error: $e');
    }
  }

  Future<void> _launchUrl(String url) async {
    if (url.isEmpty) {
      _showSnackBar('No link available for this banner');
      return;
    }
    
    try {
      // Fix the URL if needed
      String finalUrl = url;
      if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
        finalUrl = 'https://$finalUrl';
      }
      
      final Uri uri = Uri.parse(finalUrl);
      
      // Use launchUrl with forceWebView for better compatibility
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
          webViewConfiguration: const WebViewConfiguration(
            enableJavaScript: true,
            enableDomStorage: true,
          ),
        );
      } else {
        // Fallback: Try to launch with webview
        if (await canLaunchUrl(uri)) {
          await launchUrl(
            uri,
            mode: LaunchMode.inAppWebView,
          );
        } else {
          _showSnackBar('Cannot open link. Please check your connection.');
        }
      }
    } catch (e) {
      debugPrint('URL Launch Error: $e');
      _showSnackBar('Unable to open link: ${e.toString()}');
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                      gradient: const LinearGradient(
                        colors: [_kBrand, _kPlum],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.send_rounded,
                        color: Colors.white, size: 24),
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
                      child:
                          const Icon(Icons.close, size: 18, color: _kBrand),
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
                    _buildSmallAvatar(member['name'],
                        member['profile_image'], member['image_loaded'] ?? false),
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
                                fontSize: 12, color: _kTextSec),
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
                  style:
                      GoogleFonts.inter(fontSize: 16, color: _kTextPri),
                  decoration: InputDecoration(
                    hintText: 'Enter amount in INR',
                    hintStyle: GoogleFonts.inter(
                        fontSize: 14, color: _kTextMuted),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    prefixIcon: const Icon(Icons.currency_rupee,
                        size: 20, color: _kBrand),
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
                        side: const BorderSide(color: _kBorder),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('Cancel',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w500)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _createLead(member['id']),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kBrand,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: Text('Send Lead',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
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

  Widget _buildSmallAvatar(
      String name, String? imageUrl, bool imageLoaded) {
    if (imageLoaded && imageUrl != null && imageUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          imageUrl,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildSmallTextAvatar(name),
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
          colors: [
            _kPlum.withOpacity(0.8),
            _kBrand.withOpacity(0.8)
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'U',
          style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white),
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white)),
        backgroundColor: _kTextPri,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredMembers {
    if (_searchQuery.isEmpty) return _members;
    return _members.where((member) {
      return member['name']
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          member['company']
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          member['product_services']
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          (member['mobile']
                  ?.toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ??
              false);
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
            _buildHeader(isHeaderCollapsed),
            _buildBirthdaySection(),
            _buildAnniversarySection(),
            _buildSearchBar(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: _kBrand))
                  : _errorMessage != null
                      ? _buildErrorView()
                      : _filteredMembers.isEmpty
                          ? _buildEmptyView()
                          : RefreshIndicator(
                              onRefresh: _refreshMembers,
                              color: _kBrand,
                              child: ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.only(
                                    top: 8, bottom: 80),
                                itemCount: _filteredMembers.length +
                                    (_filteredMembers.length ~/ 5),
                                itemBuilder: (context, index) {
                                  if ((index + 1) % 6 == 0 &&
                                      _sliderItems.isNotEmpty) {
                                    return _buildBannerCarousel();
                                  }
                                  final memberIndex =
                                      index - (index ~/ 6);
                                  final member =
                                      _filteredMembers[memberIndex];
                                  return _buildMemberCard(
                                      member, memberIndex);
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
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              20, 12, 20, isCollapsed ? 12 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: isCollapsed ? 50 : 70,
                    height: isCollapsed ? 50 : 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/images/bbclogo.png',
                        width: isCollapsed ? 40 : 55,
                        height: isCollapsed ? 40 : 55,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.business_center_rounded,
                          color: _kBrand,
                          size: isCollapsed ? 30 : 40,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Business Boosters Club',
                          style: GoogleFonts.poppins(
                            fontSize: isCollapsed ? 14 : 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'PREMIUM BUSINESS NETWORK',
                            style: GoogleFonts.inter(
                              fontSize: isCollapsed ? 8 : 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Refresh Button
                  GestureDetector(
                    onTap: _isRefreshing ? null : _clearCacheAndRefresh,
                    child: Container(
                      width: isCollapsed ? 40 : 45,
                      height: isCollapsed ? 40 : 45,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.2),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: _isRefreshing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              Icons.refresh_rounded,
                              color: Colors.white,
                              size: isCollapsed ? 20 : 24,
                            ),
                    ),
                  ),
                ],
              ),
              if (!isCollapsed) ...[
               
               
              ],
            ],
          ),
        ),
      ),
    );
  }

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
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: (value) =>
                    setState(() => _searchQuery = value),
                style:
                    GoogleFonts.inter(fontSize: 14, color: _kTextPri),
                decoration: InputDecoration(
                  hintText:
                      'Search by name, company, products or mobile...',
                  hintStyle: GoogleFonts.inter(
                      fontSize: 14, color: _kTextMuted),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  prefixIcon: Icon(Icons.search_rounded,
                      size: 22, color: _kTextMuted),
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              IconButton(
                onPressed: () => setState(() => _searchQuery = ''),
                icon: Icon(Icons.close_rounded,
                    size: 20, color: _kTextMuted),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBirthdaySection() {
    if (_birthdayMembers.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [_kBirthdayOrange, _kBirthdayPink]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.cake_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Birthday Celebrations 🎂',
                        style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _kTextPri)),
                    Text('Wish our members on their special day',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: _kTextMuted)),
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
              itemBuilder: (context, index) =>
                  _buildBirthdayCard(_birthdayMembers[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnniversarySection() {
    if (_anniversaryMembers.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [
                      _kAnniversaryPurple,
                      _kAnniversaryRose
                    ]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.favorite_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Anniversary Celebrations 💕',
                        style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _kTextPri)),
                    Text('Celebrating love and commitment',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: _kTextMuted)),
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
              itemBuilder: (context, index) =>
                  _buildAnniversaryCard(_anniversaryMembers[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBirthdayCard(Map<String, dynamic> member) =>
      _buildCelebrationCard(member, true);

  Widget _buildAnniversaryCard(Map<String, dynamic> member) =>
      _buildCelebrationCard(member, false);

  Widget _buildCelebrationCard(
      Map<String, dynamic> member, bool isBirthday) {
    final imageLoaded = member['image_loaded'] ?? false;
    final colors = isBirthday
        ? [_kBirthdayGold, _kBirthdayOrange, _kBirthdayPink]
        : [_kAnniversaryPurple, _kAnniversaryRose];

    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors[0].withOpacity(0.15),
            colors[1].withOpacity(0.1)
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: colors[0].withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: colors[1].withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 4))
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
                color: colors[0].withOpacity(0.2),
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
                color: colors[2 < colors.length ? 2 : 1]
                    .withOpacity(0.15),
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
                        border: Border.all(color: colors[0], width: 2),
                        boxShadow: [
                          BoxShadow(
                              color: colors[1].withOpacity(0.3),
                              blurRadius: 8)
                        ],
                      ),
                      child: ClipOval(
                        child: imageLoaded &&
                                member['profile_image'] != null &&
                                member['profile_image']
                                    .toString()
                                    .isNotEmpty
                            ? Image.network(
                                member['profile_image'],
                                width: 70,
                                height: 70,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _buildCelebrationAvatarText(
                                        member['name'], isBirthday),
                              )
                            : _buildCelebrationAvatarText(
                                member['name'], isBirthday),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: colors),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white, width: 1.5),
                      ),
                      child: Icon(
                        isBirthday
                            ? Icons.cake_rounded
                            : Icons.favorite_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  member['name'].length > 15
                      ? '${member['name'].substring(0, 12)}...'
                      : member['name'],
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _kTextPri),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  member['occupation'] == 'Loading...'
                      ? 'Business Professional'
                      : member['occupation'],
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      color: colors[0],
                      fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => isBirthday
                      ? _showBirthdayWishDialog(member)
                      : _showAnniversaryWishDialog(member),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: colors),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                            isBirthday
                                ? Icons.celebration_rounded
                                : Icons.favorite_rounded,
                            size: 12,
                            color: Colors.white),
                        const SizedBox(width: 4),
                        Text('Wish',
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
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

  Widget _buildCelebrationAvatarText(String name, bool isBirthday) {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isBirthday
              ? [_kBirthdayGold, _kBirthdayOrange]
              : [_kAnniversaryPurple, _kAnniversaryRose],
        ),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'U',
          style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: Colors.white),
        ),
      ),
    );
  }

  void _showBirthdayWishDialog(Map<String, dynamic> member) =>
      _showWishDialog(member, true);

  void _showAnniversaryWishDialog(Map<String, dynamic> member) =>
      _showWishDialog(member, false);

  void _showWishDialog(Map<String, dynamic> member, bool isBirthday) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28)),
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
                    colors: isBirthday
                        ? [_kBirthdayGold, _kBirthdayOrange]
                        : [_kAnniversaryPurple, _kAnniversaryRose],
                  ),
                ),
                child: Center(
                  child: Icon(
                    isBirthday
                        ? Icons.cake_rounded
                        : Icons.favorite_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isBirthday ? 'Happy Birthday!' : 'Happy Anniversary!',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: isBirthday
                      ? _kBirthdayOrange
                      : _kAnniversaryPurple,
                ),
              ),
              const SizedBox(height: 8),
              Text(member['name'],
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: _kTextPri)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: (isBirthday
                          ? _kBirthdayGold
                          : _kAnniversaryPurple)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Wish ${member['name']} a very ${isBirthday ? 'happy birthday' : 'happy anniversary'}! Send your warm wishes and celebrate their special day.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 13, color: _kTextSec, height: 1.4),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _kBorder),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('Close',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w500)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _sendWish(member, isBirthday);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isBirthday
                            ? _kBirthdayOrange
                            : _kAnniversaryPurple,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.send_rounded,
                              size: 18, color: Colors.white),
                          const SizedBox(width: 6),
                          Text('Send Wish',
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
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

  void _sendWish(Map<String, dynamic> member, bool isBirthday) {
    final mobile = member['whatsapp_number'] ?? member['mobile'];
    if (mobile != null && mobile.isNotEmpty) {
      String cleanMobile = mobile.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanMobile.startsWith('0'))
        cleanMobile = cleanMobile.substring(1);
      if (!cleanMobile.startsWith('91'))
        cleanMobile = '91$cleanMobile';

      final message = isBirthday
          ? Uri.encodeComponent(
              '🎂 Happy Birthday ${member['name']}! 🎉🥳\n\nWishing you a fantastic year ahead filled with success, happiness, and prosperity.\n\nWarm Regards,\nBusiness Boosters Club')
          : Uri.encodeComponent(
              '💕 Happy Anniversary ${member['name']}! 💑\n\nWishing you both a lifetime of love, happiness, and togetherness.\n\nWarm Regards,\nBusiness Boosters Club');

      final Uri whatsappUri =
          Uri.parse('https://wa.me/$cleanMobile?text=$message');
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
          Text(_errorMessage!,
              style:
                  GoogleFonts.inter(fontSize: 14, color: _kTextSec)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchMembers,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kBrand,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Retry',
                style: GoogleFonts.inter(color: Colors.white)),
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
          Text('No members found',
              style:
                  GoogleFonts.inter(fontSize: 14, color: _kTextSec)),
          const SizedBox(height: 8),
          Text('Pull down to refresh',
              style: GoogleFonts.inter(
                  fontSize: 12, color: _kTextMuted)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchMembers,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kBrand,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Refresh',
                style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member, int index) {
    final isLoading = member['company'] == 'Loading...';
    final imageLoaded = member['image_loaded'] ?? false;
    final isCurrentUser = member['id'] == _userId;
    final wishes =
        member['wishes']?.toString().toLowerCase() ?? '';
    final isAnniversaryWish = wishes.contains('anniversary');
    final isBirthdayWish = wishes.contains('birthday');

    final bool showBirthdayRibbon = isBirthdayWish;
    final bool showAnniversaryRibbon =
        !isBirthdayWish && isAnniversaryWish;

    return GestureDetector(
      onTap: () {
        _closeSearch();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ProfileDetailPage(memberData: member),
          ),
        );
      },
      child: Container(
        margin:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
          border: Border.all(color: _kBorder, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 80,
                height: 158,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        width: 90,
                        height: 160,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: _kBrand.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: imageLoaded &&
                                  member['profile_image'] != null &&
                                  member['profile_image']
                                      .toString()
                                      .isNotEmpty
                              ? Image.network(
                                  member['profile_image'],
                                  width: 80,
                                  height: 140,
                                  fit: BoxFit.cover,
                                  loadingBuilder:
                                      (context, child, progress) =>
                                          progress == null
                                              ? child
                                              : Container(
                                                  decoration:
                                                      BoxDecoration(
                                                    gradient:
                                                        LinearGradient(
                                                      colors: [
                                                        _kPlum
                                                            .withOpacity(
                                                                0.8),
                                                        _kBrand
                                                            .withOpacity(
                                                                0.8),
                                                      ],
                                                    ),
                                                    borderRadius:
                                                        BorderRadius
                                                            .circular(
                                                                14),
                                                  ),
                                                  child: const Center(
                                                    child: SizedBox(
                                                      width: 24,
                                                      height: 24,
                                                      child:
                                                          CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color:
                                                            Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                  errorBuilder:
                                      (context, error, stackTrace) =>
                                          _buildAvatarInitials(
                                              member['name']),
                                )
                              : _buildAvatarInitials(member['name']),
                        ),
                      ),
                    ),
                    if (showBirthdayRibbon)
                      Positioned(
                        bottom: 0,
                        left: -12,
                        right: -15,
                        child: Image.asset(
                          'assets/images/bd.png',
                          height: 60,
                          errorBuilder: (_, __, ___) =>
                              _buildFallbackRibbon(true),
                        ),
                      ),
                    if (showAnniversaryRibbon)
                      Positioned(
                        bottom: 0,
                        left: -12,
                        right: -15,
                        child: Image.asset(
                          'assets/images/anni.png',
                          height: 60,
                          errorBuilder: (_, __, ___) =>
                              _buildFallbackRibbon(false),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            member['name'],
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: _kTextPri,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCurrentUser)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _kBrand,
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                            child: Text(
                              'You',
                              style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _infoRow(
                      Icons.business_center_rounded,
                      isLoading ? 'Loading...' : member['company'],
                      isLoading ? _kTextMuted : _kBrand,
                    ),
                    const SizedBox(height: 6),
                    _infoRow(
                      Icons.work_outline,
                      isLoading
                          ? 'Business Professional'
                          : member['occupation'],
                      _kTextSec,
                    ),
                    const SizedBox(height: 6),
                    _infoRow(
                      Icons.inventory_2_outlined,
                      isLoading ||
                              member['product_services']
                                  .toString()
                                  .isEmpty
                          ? 'No services listed'
                          : (member['product_services']
                                          .toString()
                                          .length >
                                      40
                              ? '${member['product_services'].toString().substring(0, 40)}...'
                              : member['product_services']
                                  .toString()),
                      _kTextMuted,
                      maxLines: 2,
                      fontSize: 11,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.topRight,
                      child: GestureDetector(
                        onTap: () {
                          _closeSearch();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProfileDetailPage(
                                  memberData: member),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [_kBrand, _kPlum]),
                            borderRadius:
                                BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: _kBrand.withOpacity(0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              )
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.visibility,
                                  color: Colors.white, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                'View',
                                style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String text,
    Color textColor, {
    int maxLines = 1,
    double fontSize = 12,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _kBrandLight,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 12, color: _kBrand),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarInitials(String name) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kPlum, _kBrand],
        ),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'U',
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackRibbon(bool isBirthday) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isBirthday
              ? [_kBirthdayGold, _kBirthdayOrange]
              : [_kAnniversaryPurple, _kAnniversaryRose],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(14),
          bottomRight: Radius.circular(14),
        ),
      ),
      child: Center(
        child: Text(
          isBirthday ? '🎂 Birthday' : '💕 Anniversary',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
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
          )
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
              Text('Home',
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      color: _kBrand,
                      fontWeight: FontWeight.w500)),
            ],
          ),
          GestureDetector(
            onTap: () {
              _closeSearch();
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const JoinAsMemberPage()),
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/images/bbclogo.png',
                    width: 30, height: 30),
                const SizedBox(height: 4),
                Text('Member',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        color: _kTextMuted,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              _closeSearch();
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AboutUsPage()),
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.link, color: _kTextMuted, size: 22),
                const SizedBox(height: 4),
                Text('About',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        color: _kTextMuted,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              _closeSearch();
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ProfilePageBBcc()),
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_outline,
                    color: _kTextMuted, size: 22),
                const SizedBox(height: 4),
                Text('Profile',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        color: _kTextMuted,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerCarousel() {
    if (_sliderItems.isEmpty) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (int page) {
              setState(() {
                _currentPage = page;
              });
            },
            itemCount: _sliderItems.length,
            itemBuilder: (context, index) {
              final sliderItem = _sliderItems[index];
              final imageUrl = sliderItem['imageUrl'] ?? '';
              final link = sliderItem['link'] ?? '';
              
              return GestureDetector(
                onTap: () => _launchUrl(link),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (_, __) => Container(
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: _kBrand,
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: Icon(
                          Icons.broken_image,
                          size: 50,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          
          if (_sliderItems.length > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _sliderItems.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPage == index
                          ? Colors.white
                          : Colors.white.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}