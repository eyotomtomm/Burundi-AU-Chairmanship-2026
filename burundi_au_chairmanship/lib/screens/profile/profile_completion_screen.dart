import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../config/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../l10n/app_localizations.dart';

class ProfileCompletionScreen extends StatefulWidget {
  const ProfileCompletionScreen({super.key});

  @override
  State<ProfileCompletionScreen> createState() => _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _selectedGender;
  String? _selectedNationality;
  DateTime? _selectedDob;
  bool _isLoading = false;
  bool _phoneVerified = false;
  String _selectedCountryCode = '+257';
  bool _isSendingOtp = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill with existing data
    final authProvider = context.read<AuthProvider>();
    _nameController.text = authProvider.userName ?? '';
    _phoneController.text = authProvider.phoneNumber ?? '';
    _selectedGender = authProvider.gender;
    _selectedNationality = authProvider.nationality;
    if (authProvider.dateOfBirth != null && authProvider.dateOfBirth!.isNotEmpty) {
      try { _selectedDob = DateTime.parse(authProvider.dateOfBirth!); } catch (_) {}
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => _confirmSkip(context),
        ),
        title: Text(
          'Complete Profile',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                _buildHeader(isDark),
                const SizedBox(height: 32),

                // Name Field
                _buildNameField(isDark, l10n),
                const SizedBox(height: 20),

                // Phone Number Field
                _buildPhoneField(isDark, l10n),
                const SizedBox(height: 20),

                // Gender Selector
                _buildGenderSelector(isDark, l10n),
                const SizedBox(height: 20),

                // Nationality Dropdown
                _buildNationalityField(isDark),
                const SizedBox(height: 20),

                // Date of Birth Picker
                _buildDobField(isDark),
                const SizedBox(height: 32),

                // Submit Button
                _buildSubmitButton(isDark),
                const SizedBox(height: 16),

                // Skip Button
                _buildSkipButton(isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.burundiGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.person_add_rounded,
            size: 48,
            color: AppColors.burundiGreen,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Tell us about yourself',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppColors.darkBackground,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Complete your profile to get personalized content and exclusive features.',
          style: TextStyle(
            fontSize: 15,
            height: 1.5,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildNameField(bool isDark, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Full Name',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            hintText: 'Enter your full name',
            prefixIcon: Icon(Icons.person_outline),
            filled: true,
            fillColor: isDark ? AppColors.darkSurface : AppColors.lightBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.burundiGreen, width: 2),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your name';
            }
            if (value.trim().length < 2) {
              return 'Name must be at least 2 characters';
            }
            return null;
          },
        ),
      ],
    );
  }

  static const _countryCodes = [
    // Burundi first (host country)
    ('+257', '🇧🇮', 'Burundi'),
    // African Union member states
    ('+213', '🇩🇿', 'Algeria'),
    ('+244', '🇦🇴', 'Angola'),
    ('+229', '🇧🇯', 'Benin'),
    ('+267', '🇧🇼', 'Botswana'),
    ('+226', '🇧🇫', 'Burkina Faso'),
    ('+238', '🇨🇻', 'Cabo Verde'),
    ('+237', '🇨🇲', 'Cameroon'),
    ('+236', '🇨🇫', 'Central African Republic'),
    ('+235', '🇹🇩', 'Chad'),
    ('+269', '🇰🇲', 'Comoros'),
    ('+242', '🇨🇬', 'Congo (Brazzaville)'),
    ('+243', '🇨🇩', 'Congo (DRC)'),
    ('+225', '🇨🇮', "Côte d'Ivoire"),
    ('+253', '🇩🇯', 'Djibouti'),
    ('+20', '🇪🇬', 'Egypt'),
    ('+240', '🇬🇶', 'Equatorial Guinea'),
    ('+291', '🇪🇷', 'Eritrea'),
    ('+268', '🇸🇿', 'Eswatini'),
    ('+251', '🇪🇹', 'Ethiopia'),
    ('+241', '🇬🇦', 'Gabon'),
    ('+220', '🇬🇲', 'Gambia'),
    ('+233', '🇬🇭', 'Ghana'),
    ('+224', '🇬🇳', 'Guinea'),
    ('+245', '🇬🇼', 'Guinea-Bissau'),
    ('+254', '🇰🇪', 'Kenya'),
    ('+266', '🇱🇸', 'Lesotho'),
    ('+231', '🇱🇷', 'Liberia'),
    ('+218', '🇱🇾', 'Libya'),
    ('+261', '🇲🇬', 'Madagascar'),
    ('+265', '🇲🇼', 'Malawi'),
    ('+223', '🇲🇱', 'Mali'),
    ('+222', '🇲🇷', 'Mauritania'),
    ('+230', '🇲🇺', 'Mauritius'),
    ('+212', '🇲🇦', 'Morocco'),
    ('+258', '🇲🇿', 'Mozambique'),
    ('+264', '🇳🇦', 'Namibia'),
    ('+227', '🇳🇪', 'Niger'),
    ('+234', '🇳🇬', 'Nigeria'),
    ('+250', '🇷🇼', 'Rwanda'),
    ('+239', '🇸🇹', 'São Tomé and Príncipe'),
    ('+221', '🇸🇳', 'Senegal'),
    ('+248', '🇸🇨', 'Seychelles'),
    ('+232', '🇸🇱', 'Sierra Leone'),
    ('+252', '🇸🇴', 'Somalia'),
    ('+27', '🇿🇦', 'South Africa'),
    ('+211', '🇸🇸', 'South Sudan'),
    ('+249', '🇸🇩', 'Sudan'),
    ('+255', '🇹🇿', 'Tanzania'),
    ('+228', '🇹🇬', 'Togo'),
    ('+216', '🇹🇳', 'Tunisia'),
    ('+256', '🇺🇬', 'Uganda'),
    ('+260', '🇿🇲', 'Zambia'),
    ('+263', '🇿🇼', 'Zimbabwe'),
    // Major international countries
    ('+93', '🇦🇫', 'Afghanistan'),
    ('+54', '🇦🇷', 'Argentina'),
    ('+61', '🇦🇺', 'Australia'),
    ('+43', '🇦🇹', 'Austria'),
    ('+880', '🇧🇩', 'Bangladesh'),
    ('+32', '🇧🇪', 'Belgium'),
    ('+55', '🇧🇷', 'Brazil'),
    ('+1', '🇨🇦', 'Canada'),
    ('+86', '🇨🇳', 'China'),
    ('+57', '🇨🇴', 'Colombia'),
    ('+53', '🇨🇺', 'Cuba'),
    ('+45', '🇩🇰', 'Denmark'),
    ('+358', '🇫🇮', 'Finland'),
    ('+33', '🇫🇷', 'France'),
    ('+49', '🇩🇪', 'Germany'),
    ('+30', '🇬🇷', 'Greece'),
    ('+91', '🇮🇳', 'India'),
    ('+62', '🇮🇩', 'Indonesia'),
    ('+98', '🇮🇷', 'Iran'),
    ('+964', '🇮🇶', 'Iraq'),
    ('+353', '🇮🇪', 'Ireland'),
    ('+972', '🇮🇱', 'Israel'),
    ('+39', '🇮🇹', 'Italy'),
    ('+81', '🇯🇵', 'Japan'),
    ('+962', '🇯🇴', 'Jordan'),
    ('+965', '🇰🇼', 'Kuwait'),
    ('+961', '🇱🇧', 'Lebanon'),
    ('+60', '🇲🇾', 'Malaysia'),
    ('+52', '🇲🇽', 'Mexico'),
    ('+31', '🇳🇱', 'Netherlands'),
    ('+64', '🇳🇿', 'New Zealand'),
    ('+47', '🇳🇴', 'Norway'),
    ('+968', '🇴🇲', 'Oman'),
    ('+92', '🇵🇰', 'Pakistan'),
    ('+970', '🇵🇸', 'Palestine'),
    ('+51', '🇵🇪', 'Peru'),
    ('+63', '🇵🇭', 'Philippines'),
    ('+48', '🇵🇱', 'Poland'),
    ('+351', '🇵🇹', 'Portugal'),
    ('+974', '🇶🇦', 'Qatar'),
    ('+40', '🇷🇴', 'Romania'),
    ('+7', '🇷🇺', 'Russia'),
    ('+966', '🇸🇦', 'Saudi Arabia'),
    ('+65', '🇸🇬', 'Singapore'),
    ('+82', '🇰🇷', 'South Korea'),
    ('+34', '🇪🇸', 'Spain'),
    ('+94', '🇱🇰', 'Sri Lanka'),
    ('+46', '🇸🇪', 'Sweden'),
    ('+41', '🇨🇭', 'Switzerland'),
    ('+66', '🇹🇭', 'Thailand'),
    ('+90', '🇹🇷', 'Turkey'),
    ('+971', '🇦🇪', 'UAE'),
    ('+44', '🇬🇧', 'UK'),
    ('+380', '🇺🇦', 'Ukraine'),
    ('+1', '🇺🇸', 'USA'),
    ('+58', '🇻🇪', 'Venezuela'),
    ('+84', '🇻🇳', 'Vietnam'),
    ('+967', '🇾🇪', 'Yemen'),
  ];

  Widget _buildPhoneField(bool isDark, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Phone Number',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
            if (_phoneVerified)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.burundiGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified, size: 14, color: AppColors.burundiGreen),
                    const SizedBox(width: 4),
                    Text(
                      'Verified',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.burundiGreen,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Country code dropdown
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCountryCode,
                  isDense: true,
                  items: _countryCodes.map((c) {
                    return DropdownMenuItem(
                      value: c.$1,
                      child: Text('${c.$2} ${c.$1}', style: const TextStyle(fontSize: 14)),
                    );
                  }).toList(),
                  onChanged: _phoneVerified ? null : (value) {
                    if (value != null) setState(() => _selectedCountryCode = value);
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Phone number input
            Expanded(
              child: TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  hintText: 'XX XXX XXX',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurface : AppColors.lightBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.burundiGreen, width: 2),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your phone number';
                  }
                  if (value.trim().length < 6) {
                    return 'Invalid phone number';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: (_phoneVerified || _isSendingOtp) ? null : () => _verifyPhone(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: _phoneVerified ? Colors.grey : AppColors.auGold,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSendingOtp
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _phoneVerified ? 'Verified' : 'Verify',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'We\'ll send you a verification code via SMS',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white38 : Colors.black45,
          ),
        ),
      ],
    );
  }

  Widget _buildGenderSelector(bool isDark, AppLocalizations l10n) {
    final genderOptions = [
      {'value': 'male', 'label': 'Male', 'icon': Icons.male},
      {'value': 'female', 'label': 'Female', 'icon': Icons.female},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gender',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: genderOptions.map((option) {
            final isSelected = _selectedGender == option['value'];
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedGender = option['value'] as String;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.burundiGreen.withValues(alpha: 0.1)
                      : (isDark ? AppColors.darkSurface : AppColors.lightBackground),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.burundiGreen
                        : (isDark ? AppColors.darkDivider : AppColors.lightDivider),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      option['icon'] as IconData,
                      size: 18,
                      color: isSelected
                          ? AppColors.burundiGreen
                          : (isDark ? Colors.white60 : Colors.black54),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      option['label'] as String,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? AppColors.burundiGreen
                            : (isDark ? Colors.white : Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildNationalityField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nationality',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedNationality != null && _selectedNationality!.isNotEmpty
              ? _selectedNationality
              : null,
          decoration: InputDecoration(
            hintText: 'Select your nationality',
            prefixIcon: const Icon(Icons.flag_outlined),
            filled: true,
            fillColor: isDark ? AppColors.darkSurface : AppColors.lightBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.burundiGreen, width: 2),
            ),
          ),
          items: AppConstants.nationalityChoices.entries.map((entry) {
            return DropdownMenuItem<String>(
              value: entry.key,
              child: Text(entry.value),
            );
          }).toList(),
          onChanged: (value) {
            setState(() => _selectedNationality = value);
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select your nationality';
            }
            return null;
          },
          isExpanded: true,
          menuMaxHeight: 300,
        ),
      ],
    );
  }

  Widget _buildDobField(bool isDark) {
    String dobText = 'Select your date of birth';
    if (_selectedDob != null) {
      dobText = '${_selectedDob!.day}/${_selectedDob!.month}/${_selectedDob!.year}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date of Birth',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _selectedDob ?? DateTime(2000, 1, 1),
              firstDate: DateTime(1920),
              lastDate: DateTime.now(),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: Theme.of(context).colorScheme.copyWith(
                      primary: AppColors.burundiGreen,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              setState(() => _selectedDob = picked);
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.cake_outlined,
                    color: isDark ? Colors.white60 : Colors.black54),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    dobText,
                    style: TextStyle(
                      fontSize: 16,
                      color: _selectedDob != null
                          ? (isDark ? Colors.white : Colors.black87)
                          : (isDark ? Colors.white38 : Colors.black38),
                    ),
                  ),
                ),
                Icon(Icons.calendar_today_outlined,
                    size: 18, color: isDark ? Colors.white38 : Colors.black38),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.burundiGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text(
                    'Save Profile',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.check_circle_outline, size: 20),
                ],
              ),
      ),
    );
  }

  Widget _buildSkipButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: () => _confirmSkip(context),
        child: Text(
          'I\'ll do this later',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
      ),
    );
  }

  Future<void> _verifyPhone(BuildContext context) async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showSnackBar(context, 'Please enter a phone number', isError: true);
      return;
    }

    setState(() => _isSendingOtp = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final api = ApiService();
      await api.sendPhoneOtp(_selectedCountryCode, phone);

      if (!mounted) return;
      setState(() => _isSendingOtp = false);

      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Verification code sent via SMS')),
      );

      // Show OTP entry dialog
      if (mounted) _showPhoneOtpDialog(phone);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSendingOtp = false);
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Failed to send SMS: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  void _showPhoneOtpDialog(String phoneNumber) {
    final otpController = TextEditingController();
    bool isVerifying = false;
    final parentScaffold = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.sms_outlined, color: AppColors.auGold),
                  const SizedBox(width: 8),
                  const Text('Enter SMS Code'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'We sent a 6-digit code to\n$_selectedCountryCode $phoneNumber',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    autofocus: true,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '000000',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white24 : Colors.black26,
                        letterSpacing: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.auGold, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: isVerifying
                        ? null
                        : () async {
                            try {
                              setDialogState(() {});
                              final api = ApiService();
                              await api.sendPhoneOtp(_selectedCountryCode, phoneNumber);
                              parentScaffold.showSnackBar(
                                const SnackBar(content: Text('New code sent')),
                              );
                            } catch (e) {
                              parentScaffold.showSnackBar(
                                SnackBar(content: Text('Failed to resend: $e'), backgroundColor: AppColors.error),
                              );
                            }
                          },
                    child: const Text('Resend Code'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isVerifying ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isVerifying
                      ? null
                      : () async {
                          final code = otpController.text.trim();
                          if (code.length != 6) return;

                          setDialogState(() => isVerifying = true);
                          final navigator = Navigator.of(dialogContext);

                          try {
                            final api = ApiService();
                            await api.verifyPhoneOtp(
                              _selectedCountryCode,
                              phoneNumber,
                              code,
                            );

                            navigator.pop();
                            if (mounted) {
                              setState(() => _phoneVerified = true);
                            }
                            parentScaffold.showSnackBar(
                              const SnackBar(content: Text('Phone number verified!')),
                            );
                          } catch (e) {
                            setDialogState(() => isVerifying = false);
                            parentScaffold.showSnackBar(
                              SnackBar(content: Text('$e'), backgroundColor: AppColors.error),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.auGold,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isVerifying
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Verify'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedGender == null) {
      _showSnackBar(context, 'Please select your gender', isError: true);
      return;
    }
    if (_selectedNationality == null || _selectedNationality!.isEmpty) {
      _showSnackBar(context, 'Please select your nationality', isError: true);
      return;
    }
    if (_selectedDob == null) {
      _showSnackBar(context, 'Please select your date of birth', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final dobString = '${_selectedDob!.year}-${_selectedDob!.month.toString().padLeft(2, '0')}-${_selectedDob!.day.toString().padLeft(2, '0')}';

      final success = await authProvider.updateProfile(
        _nameController.text.trim(),
        gender: _selectedGender,
        nationality: _selectedNationality,
        dateOfBirth: dobString,
        phoneNumber: _phoneController.text.trim(),
      );

      if (success && mounted) {
        _showSnackBar(context, 'Profile updated successfully!');
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      } else if (mounted && authProvider.errorMessage != null) {
        _showSnackBar(context, authProvider.errorMessage!, isError: true);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(context, 'Failed to update profile: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _confirmSkip(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Skip Profile Completion?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          'You can complete your profile anytime from the settings.',
          style: TextStyle(
            fontSize: 15,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).pushReplacementNamed('/home');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.burundiGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Skip'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.burundiRed : AppColors.burundiGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
