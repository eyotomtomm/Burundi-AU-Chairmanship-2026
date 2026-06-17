import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../config/app_constants.dart';
import '../../providers/auth_provider.dart';
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
  String _selectedPhoneCountry = 'BI';
  String _selectedPhoneCode = '+257';
  DateTime? _selectedDob;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill with existing data
    final authProvider = context.read<AuthProvider>();
    _nameController.text = authProvider.userName ?? '';
    _selectedGender = authProvider.gender;
    _selectedNationality = authProvider.nationality;
    if (authProvider.dateOfBirth != null && authProvider.dateOfBirth!.isNotEmpty) {
      try { _selectedDob = DateTime.parse(authProvider.dateOfBirth!); } catch (_) {}
    }

    // Sync phone country code from nationality
    if (authProvider.nationality != null &&
        AppConstants.countryDialCodes.containsKey(authProvider.nationality)) {
      _selectedPhoneCountry = authProvider.nationality!;
      _selectedPhoneCode = AppConstants.countryDialCodes[authProvider.nationality!]!;
    }

    // Parse existing phone number: strip dial code prefix if present
    final existingPhone = authProvider.phoneNumber ?? '';
    if (existingPhone.isNotEmpty) {
      bool found = false;
      for (final entry in AppConstants.countryDialCodes.entries) {
        if (existingPhone.startsWith(entry.value)) {
          _selectedPhoneCountry = entry.key;
          _selectedPhoneCode = entry.value;
          _phoneController.text = existingPhone.substring(entry.value.length).trim();
          found = true;
          break;
        }
      }
      if (!found) {
        _phoneController.text = existingPhone;
      }
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


  Widget _buildPhoneField(bool isDark, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Phone Number',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Country code selector with flag
            GestureDetector(
              onTap: () => _showPhoneCountryPicker(isDark),
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppConstants.countryFlag(_selectedPhoneCountry),
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _selectedPhoneCode,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.keyboard_arrow_down, size: 18, color: isDark ? Colors.white54 : Colors.black45),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Phone number input
            Expanded(
              child: TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  hintText: 'Phone number (optional)',
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
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showPhoneCountryPicker(bool isDark) {
    String searchQuery = '';
    final entries = AppConstants.countryDialCodes.entries
        .where((e) => AppConstants.nationalityChoices.containsKey(e.key))
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filtered = entries.where((e) {
              final name = AppConstants.nationalityChoices[e.key]?.toLowerCase() ?? '';
              final code = e.value.toLowerCase();
              final query = searchQuery.toLowerCase();
              return name.contains(query) || code.contains(query) || e.key.toLowerCase().contains(query);
            }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              maxChildSize: 0.85,
              minChildSize: 0.4,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: TextField(
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Search country...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onChanged: (value) => setSheetState(() => searchQuery = value),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final entry = filtered[index];
                          final countryName = AppConstants.nationalityChoices[entry.key] ?? entry.key;
                          final isSelected = entry.key == _selectedPhoneCountry;
                          return ListTile(
                            leading: Text(
                              AppConstants.countryFlag(entry.key),
                              style: const TextStyle(fontSize: 24),
                            ),
                            title: Text(countryName),
                            trailing: Text(
                              entry.value,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isSelected ? AppColors.burundiGreen : null,
                              ),
                            ),
                            selected: isSelected,
                            onTap: () {
                              setState(() {
                                _selectedPhoneCountry = entry.key;
                                _selectedPhoneCode = entry.value;
                              });
                              Navigator.pop(sheetContext);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
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
            final flag = AppConstants.countryFlag(entry.key);
            return DropdownMenuItem<String>(
              value: entry.key,
              child: Text('$flag  ${entry.value}', style: const TextStyle(fontSize: 15)),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedNationality = value;
              // Auto-sync phone country code when nationality changes
              if (value != null && value != 'OTHER' &&
                  AppConstants.countryDialCodes.containsKey(value)) {
                _selectedPhoneCountry = value;
                _selectedPhoneCode = AppConstants.countryDialCodes[value]!;
              }
            });
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

      // Prepend country code to phone number if provided
      final rawPhone = _phoneController.text.trim();
      final fullPhone = rawPhone.isNotEmpty ? '$_selectedPhoneCode$rawPhone' : '';

      final success = await authProvider.updateProfile(
        _nameController.text.trim(),
        gender: _selectedGender,
        nationality: _selectedNationality,
        dateOfBirth: dobString,
        phoneNumber: fullPhone,
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
