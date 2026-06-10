import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class YouthDialogueApplyScreen extends StatefulWidget {
  const YouthDialogueApplyScreen({super.key});

  @override
  State<YouthDialogueApplyScreen> createState() => _YouthDialogueApplyScreenState();
}

class _YouthDialogueApplyScreenState extends State<YouthDialogueApplyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _organizationController = TextEditingController();
  final _positionController = TextEditingController();
  final _motivationController = TextEditingController();

  String? _selectedTitle;
  String? _selectedNationality;
  String? _selectedGender;
  DateTime? _dateOfBirth;
  bool _isLoading = false;
  bool _submitted = false;

  final List<Map<String, String>> _titles = [
    {'value': 'mr', 'label': 'Mr.'},
    {'value': 'mrs', 'label': 'Mrs.'},
    {'value': 'ms', 'label': 'Ms.'},
    {'value': 'dr', 'label': 'Dr.'},
    {'value': 'prof', 'label': 'Prof.'},
    {'value': 'he', 'label': 'H.E.'},
    {'value': 'amb', 'label': 'Ambassador'},
    {'value': 'hon', 'label': 'Honorable'},
    {'value': 'other', 'label': 'Other'},
  ];

  final List<Map<String, String>> _nationalities = [
    {'code': 'BI', 'name': 'Burundi'}, {'code': 'DZ', 'name': 'Algeria'},
    {'code': 'AO', 'name': 'Angola'}, {'code': 'BJ', 'name': 'Benin'},
    {'code': 'BW', 'name': 'Botswana'}, {'code': 'BF', 'name': 'Burkina Faso'},
    {'code': 'CV', 'name': 'Cabo Verde'}, {'code': 'CM', 'name': 'Cameroon'},
    {'code': 'CF', 'name': 'Central African Republic'}, {'code': 'TD', 'name': 'Chad'},
    {'code': 'KM', 'name': 'Comoros'}, {'code': 'CG', 'name': 'Congo (Brazzaville)'},
    {'code': 'CD', 'name': 'Congo (DRC)'}, {'code': 'CI', 'name': "Côte d'Ivoire"},
    {'code': 'DJ', 'name': 'Djibouti'}, {'code': 'EG', 'name': 'Egypt'},
    {'code': 'GQ', 'name': 'Equatorial Guinea'}, {'code': 'ER', 'name': 'Eritrea'},
    {'code': 'SZ', 'name': 'Eswatini'}, {'code': 'ET', 'name': 'Ethiopia'},
    {'code': 'GA', 'name': 'Gabon'}, {'code': 'GM', 'name': 'Gambia'},
    {'code': 'GH', 'name': 'Ghana'}, {'code': 'GN', 'name': 'Guinea'},
    {'code': 'GW', 'name': 'Guinea-Bissau'}, {'code': 'KE', 'name': 'Kenya'},
    {'code': 'LS', 'name': 'Lesotho'}, {'code': 'LR', 'name': 'Liberia'},
    {'code': 'LY', 'name': 'Libya'}, {'code': 'MG', 'name': 'Madagascar'},
    {'code': 'MW', 'name': 'Malawi'}, {'code': 'ML', 'name': 'Mali'},
    {'code': 'MR', 'name': 'Mauritania'}, {'code': 'MU', 'name': 'Mauritius'},
    {'code': 'MA', 'name': 'Morocco'}, {'code': 'MZ', 'name': 'Mozambique'},
    {'code': 'NA', 'name': 'Namibia'}, {'code': 'NE', 'name': 'Niger'},
    {'code': 'NG', 'name': 'Nigeria'}, {'code': 'RW', 'name': 'Rwanda'},
    {'code': 'ST', 'name': 'São Tomé and Príncipe'}, {'code': 'SN', 'name': 'Senegal'},
    {'code': 'SC', 'name': 'Seychelles'}, {'code': 'SL', 'name': 'Sierra Leone'},
    {'code': 'SO', 'name': 'Somalia'}, {'code': 'ZA', 'name': 'South Africa'},
    {'code': 'SS', 'name': 'South Sudan'}, {'code': 'SD', 'name': 'Sudan'},
    {'code': 'TZ', 'name': 'Tanzania'}, {'code': 'TG', 'name': 'Togo'},
    {'code': 'TN', 'name': 'Tunisia'}, {'code': 'UG', 'name': 'Uganda'},
    {'code': 'ZM', 'name': 'Zambia'}, {'code': 'ZW', 'name': 'Zimbabwe'},
    {'code': 'BE', 'name': 'Belgium'}, {'code': 'BR', 'name': 'Brazil'},
    {'code': 'CA', 'name': 'Canada'}, {'code': 'CN', 'name': 'China'},
    {'code': 'FR', 'name': 'France'}, {'code': 'DE', 'name': 'Germany'},
    {'code': 'IN', 'name': 'India'}, {'code': 'JP', 'name': 'Japan'},
    {'code': 'RU', 'name': 'Russia'}, {'code': 'SA', 'name': 'Saudi Arabia'},
    {'code': 'TR', 'name': 'Turkey'}, {'code': 'AE', 'name': 'UAE'},
    {'code': 'GB', 'name': 'United Kingdom'}, {'code': 'US', 'name': 'United States'},
    {'code': 'OTHER', 'name': 'Other'},
  ];

  @override
  void initState() {
    super.initState();
    _prefillEmail();
    ApiService().youthDialogueLogActivity('form_started', 'youth_dialogue_apply');
  }

  void _prefillEmail() {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.userEmail != null && authProvider.userEmail!.isNotEmpty) {
      _emailController.text = authProvider.userEmail!;
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _organizationController.dispose();
    _positionController.dispose();
    _motivationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Check email verification
    final authProvider = context.read<AuthProvider>();
    final isEmailVerified = authProvider.isEmailVerified;
    if (!isEmailVerified) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please verify your email address before applying.'),
          backgroundColor: AppColors.burundiRed,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final formData = <String, dynamic>{
        'title': _selectedTitle ?? '',
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'nationality': _selectedNationality ?? '',
        'gender': _selectedGender ?? '',
        'organization': _organizationController.text.trim(),
        'position': _positionController.text.trim(),
        'motivation': _motivationController.text.trim(),
      };

      if (_dateOfBirth != null) {
        formData['date_of_birth'] = '${_dateOfBirth!.year}-${_dateOfBirth!.month.toString().padLeft(2, '0')}-${_dateOfBirth!.day.toString().padLeft(2, '0')}';
      }

      await ApiService().youthDialogueApply(formData);
      if (!mounted) return;
      setState(() => _submitted = true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.burundiRed),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong. Please try again.'), backgroundColor: AppColors.burundiRed),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_submitted) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
        appBar: AppBar(
          title: const Text('Application Submitted'),
          backgroundColor: AppColors.burundiGreen,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.burundiGreen.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded, size: 48, color: AppColors.burundiGreen),
                ),
                const SizedBox(height: 24),
                Text('Application Submitted!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 12),
                Text('Your application has been received. We will review it and notify you of the outcome.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, height: 1.5, color: isDark ? Colors.white60 : Colors.black54)),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.burundiGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Back to Youth Dialogue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Apply for Youth Dialogue'),
        backgroundColor: AppColors.burundiGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Email verification gate
            _buildEmailVerificationBanner(isDark),
            const SizedBox(height: 16),

            _sectionLabel('Personal Information', isDark),
            const SizedBox(height: 12),

            // Title
            DropdownButtonFormField<String>(
              value: _selectedTitle,
              decoration: _inputDecoration('Title', isDark),
              items: _titles.map((t) => DropdownMenuItem(value: t['value'], child: Text(t['label']!))).toList(),
              onChanged: (v) => setState(() => _selectedTitle = v),
            ),
            const SizedBox(height: 12),

            // Name row
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _firstNameController,
                    decoration: _inputDecoration('First Name *', isDark),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _lastNameController,
                    decoration: _inputDecoration('Last Name *', isDark),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Date of Birth
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dateOfBirth ?? DateTime(2000, 1, 1),
                  firstDate: DateTime(1950),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _dateOfBirth = picked);
              },
              child: AbsorbPointer(
                child: TextFormField(
                  decoration: _inputDecoration('Date of Birth', isDark).copyWith(
                    suffixIcon: const Icon(Icons.calendar_today, size: 20),
                  ),
                  controller: TextEditingController(
                    text: _dateOfBirth != null
                      ? '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}'
                      : '',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Gender
            DropdownButtonFormField<String>(
              value: _selectedGender,
              decoration: _inputDecoration('Gender', isDark),
              items: const [
                DropdownMenuItem(value: 'male', child: Text('Male')),
                DropdownMenuItem(value: 'female', child: Text('Female')),
              ],
              onChanged: (v) => setState(() => _selectedGender = v),
            ),
            const SizedBox(height: 20),

            _sectionLabel('Contact', isDark),
            const SizedBox(height: 12),

            // Email (pre-filled, read-only)
            TextFormField(
              controller: _emailController,
              decoration: _inputDecoration('Email *', isDark).copyWith(
                suffixIcon: const Icon(Icons.lock_outline, size: 18, color: Colors.grey),
              ),
              readOnly: true,
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _phoneController,
              decoration: _inputDecoration('Phone Number', isDark),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),

            // Nationality
            DropdownButtonFormField<String>(
              value: _selectedNationality,
              decoration: _inputDecoration('Nationality *', isDark),
              isExpanded: true,
              items: _nationalities.map((n) => DropdownMenuItem(value: n['code'], child: Text(n['name']!))).toList(),
              onChanged: (v) => setState(() => _selectedNationality = v),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 20),

            _sectionLabel('Professional Details', isDark),
            const SizedBox(height: 12),

            TextFormField(
              controller: _organizationController,
              decoration: _inputDecoration('Organization', isDark),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _positionController,
              decoration: _inputDecoration('Position / Role', isDark),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 20),

            _sectionLabel('Motivation', isDark),
            const SizedBox(height: 12),

            TextFormField(
              controller: _motivationController,
              decoration: _inputDecoration('Why do you want to participate? *', isDark),
              maxLines: 5,
              minLines: 3,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (v.trim().length < 50) return 'Please write at least 50 characters';
                return null;
              },
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.burundiGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  disabledBackgroundColor: AppColors.burundiGreen.withValues(alpha: 0.5),
                ),
                child: _isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Submit Application', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailVerificationBanner(bool isDark) {
    final authProvider = context.read<AuthProvider>();
    final isEmailVerified = authProvider.isEmailVerified;

    if (isEmailVerified) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.auGold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.auGold.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.email_outlined, color: AppColors.auGold),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Email Not Verified',
                  style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 4),
                Text('Please verify your email address before applying.',
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.black54)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/email-verification'),
            child: const Text('Verify', style: TextStyle(color: AppColors.burundiGreen, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, bool isDark) {
    return Text(text, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
      color: isDark ? Colors.white : Colors.black87));
  }

  InputDecoration _inputDecoration(String label, bool isDark) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.burundiGreen, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
