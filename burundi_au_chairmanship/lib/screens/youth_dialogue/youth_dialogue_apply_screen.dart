import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../config/app_colors.dart';
import '../../models/event_registration_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class YouthDialogueApplyScreen extends StatefulWidget {
  final List<RegistrationFormField> formFields;

  const YouthDialogueApplyScreen({super.key, required this.formFields});

  @override
  State<YouthDialogueApplyScreen> createState() => _YouthDialogueApplyScreenState();
}

class _YouthDialogueApplyScreenState extends State<YouthDialogueApplyScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _submitted = false;

  // Dynamic form state
  final Map<String, TextEditingController> _formControllers = {};
  final Map<String, dynamic> _formValues = {};
  final Map<String, File> _pickedFiles = {};

  // Country list for 'country' field type
  static const List<String> _countryList = [
    'Afghanistan', 'Albania', 'Algeria', 'Angola', 'Argentina', 'Australia',
    'Austria', 'Bangladesh', 'Belgium', 'Benin', 'Botswana', 'Brazil',
    'Burkina Faso', 'Burundi', 'Cabo Verde', 'Cameroon', 'Canada',
    'Central African Republic', 'Chad', 'China', 'Colombia', 'Comoros',
    'Congo (Brazzaville)', 'Congo (DRC)', "Côte d'Ivoire", 'Djibouti',
    'Egypt', 'Equatorial Guinea', 'Eritrea', 'Eswatini', 'Ethiopia',
    'France', 'Gabon', 'Gambia', 'Germany', 'Ghana', 'Guinea',
    'Guinea-Bissau', 'India', 'Japan', 'Kenya', 'Lesotho', 'Liberia',
    'Libya', 'Madagascar', 'Malawi', 'Mali', 'Mauritania', 'Mauritius',
    'Morocco', 'Mozambique', 'Namibia', 'Niger', 'Nigeria', 'Rwanda',
    'São Tomé and Príncipe', 'Saudi Arabia', 'Senegal', 'Seychelles',
    'Sierra Leone', 'Somalia', 'South Africa', 'South Sudan', 'Sudan',
    'Tanzania', 'Togo', 'Tunisia', 'Turkey', 'UAE', 'Uganda',
    'United Kingdom', 'United States', 'Zambia', 'Zimbabwe', 'Other',
  ];

  // Nationality list for 'nationality' field type
  static const List<Map<String, String>> _nationalities = [
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
    _initFormState();
    ApiService().youthDialogueLogActivity('form_started', 'youth_dialogue_apply');
  }

  void _initFormState() {
    final authProvider = context.read<AuthProvider>();
    for (final field in widget.formFields) {
      if (!field.isActive) continue;
      // Create controllers for text-based fields
      switch (field.fieldType) {
        case 'text':
        case 'email':
        case 'phone':
        case 'number':
        case 'passport':
        case 'url':
        case 'textarea':
        case 'date':
        case 'time':
          final controller = TextEditingController();
          // Auto-fill email from auth provider
          if (field.fieldName == 'email' && authProvider.userEmail != null && authProvider.userEmail!.isNotEmpty) {
            controller.text = authProvider.userEmail!;
          }
          _formControllers[field.fieldName] = controller;
          break;
        case 'multi_checkbox':
          _formValues[field.fieldName] = <String>[];
          break;
        case 'checkbox':
          _formValues[field.fieldName] = false;
          break;
      }
    }
  }

  @override
  void dispose() {
    for (final c in _formControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isEmailVerified) {
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
      // Collect all form data
      final formData = <String, dynamic>{};
      for (final field in widget.formFields) {
        if (!field.isActive) continue;
        final name = field.fieldName;
        if (_formControllers.containsKey(name)) {
          formData[name] = _formControllers[name]!.text.trim();
        } else if (_formValues.containsKey(name)) {
          formData[name] = _formValues[name];
        }
      }

      await ApiService().youthDialogueApply({'form_data': formData});
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
    final langCode = Localizations.localeOf(context).languageCode;

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

    final activeFields = widget.formFields.where((f) => f.isActive).toList();

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
            _buildEmailVerificationBanner(isDark),
            const SizedBox(height: 16),

            ...activeFields.map((field) => _buildFormField(field, langCode, isDark)),

            const SizedBox(height: 16),

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

  Widget _buildFormField(RegistrationFormField field, String langCode, bool isDark) {
    final label = field.getLabel(langCode);
    final placeholder = field.getPlaceholder(langCode);
    final helpText = field.getHelpText(langCode);
    final textColor = isDark ? Colors.white70 : Colors.black87;

    switch (field.fieldType) {
      case 'textarea':
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: TextFormField(
            controller: _formControllers[field.fieldName],
            maxLines: 5,
            minLines: 3,
            maxLength: field.maxLength,
            textCapitalization: TextCapitalization.sentences,
            decoration: _inputDecoration(label, placeholder, helpText, isDark, field.isRequired),
            validator: (v) {
              if (field.isRequired && (v == null || v.trim().isEmpty)) return 'Required';
              if (field.minLength != null && v != null && v.isNotEmpty && v.length < field.minLength!) {
                return 'Minimum ${field.minLength} characters required';
              }
              return null;
            },
          ),
        );

      case 'select':
        final options = field.options.map((o) => o.toString()).toList();
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: DropdownButtonFormField<String>(
            decoration: _inputDecoration(label, null, helpText, isDark, field.isRequired),
            hint: placeholder.isNotEmpty ? Text(placeholder) : null,
            isExpanded: true,
            menuMaxHeight: 300,
            items: options
                .map((o) => DropdownMenuItem(value: o, child: Text(o, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (val) => _formValues[field.fieldName] = val,
            validator: field.isRequired ? (v) => v == null ? 'Required' : null : null,
          ),
        );

      case 'country':
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: DropdownButtonFormField<String>(
            decoration: _inputDecoration(label, null, helpText, isDark, field.isRequired),
            isExpanded: true,
            menuMaxHeight: 300,
            items: _countryList
                .map((o) => DropdownMenuItem(value: o, child: Text(o, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (val) => _formValues[field.fieldName] = val,
            validator: field.isRequired ? (v) => v == null ? 'Required' : null : null,
          ),
        );

      case 'nationality':
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: DropdownButtonFormField<String>(
            decoration: _inputDecoration(label, null, helpText, isDark, field.isRequired),
            isExpanded: true,
            menuMaxHeight: 300,
            items: _nationalities
                .map((n) => DropdownMenuItem(value: n['code'], child: Text(n['name']!, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (val) => _formValues[field.fieldName] = val,
            validator: field.isRequired ? (v) => v == null ? 'Required' : null : null,
          ),
        );

      case 'radio':
        final options = field.options.map((o) => o.toString()).toList();
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: FormField<String>(
            initialValue: _formValues[field.fieldName] as String?,
            validator: field.isRequired ? (v) => (v == null || v.isEmpty) ? 'Required' : null : null,
            builder: (state) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    field.isRequired ? '$label *' : label,
                    style: TextStyle(fontSize: 14, color: textColor, fontWeight: FontWeight.w500),
                  ),
                  if (helpText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(helpText, style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38)),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: options.map((option) {
                      final selected = _formValues[field.fieldName] == option;
                      return ChoiceChip(
                        label: Text(option),
                        selected: selected,
                        onSelected: (_) {
                          setState(() => _formValues[field.fieldName] = option);
                          state.didChange(option);
                        },
                        selectedColor: AppColors.burundiGreen.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: selected ? AppColors.burundiGreen : textColor,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                        ),
                        side: BorderSide(
                          color: selected ? AppColors.burundiGreen : (isDark ? const Color(0xFF444444) : const Color(0xFFCCCCCC)),
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      );
                    }).toList(),
                  ),
                  if (state.hasError)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, top: 4),
                      child: Text(state.errorText!, style: const TextStyle(color: AppColors.burundiRed, fontSize: 12)),
                    ),
                ],
              );
            },
          ),
        );

      case 'multi_checkbox':
        final options = field.options.map((o) => o.toString()).toList();
        final selected = (_formValues[field.fieldName] as List<String>?) ?? [];
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: FormField<List<String>>(
            initialValue: selected,
            validator: field.isRequired ? (v) => (v == null || v.isEmpty) ? 'Select at least one' : null : null,
            builder: (state) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    field.isRequired ? '$label *' : label,
                    style: TextStyle(fontSize: 14, color: textColor, fontWeight: FontWeight.w500),
                  ),
                  if (helpText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(helpText, style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38)),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: options.map((option) {
                      final isChecked = selected.contains(option);
                      return FilterChip(
                        label: Text(option),
                        selected: isChecked,
                        onSelected: (val) {
                          setState(() {
                            final list = List<String>.from(selected);
                            if (val) { list.add(option); } else { list.remove(option); }
                            _formValues[field.fieldName] = list;
                          });
                          state.didChange(_formValues[field.fieldName] as List<String>);
                        },
                        selectedColor: AppColors.burundiGreen.withValues(alpha: 0.2),
                        checkmarkColor: AppColors.burundiGreen,
                        labelStyle: TextStyle(
                          color: isChecked ? AppColors.burundiGreen : textColor,
                          fontWeight: isChecked ? FontWeight.w600 : FontWeight.normal,
                        ),
                        side: BorderSide(
                          color: isChecked ? AppColors.burundiGreen : (isDark ? const Color(0xFF444444) : const Color(0xFFCCCCCC)),
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      );
                    }).toList(),
                  ),
                  if (state.hasError)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, top: 4),
                      child: Text(state.errorText!, style: const TextStyle(color: AppColors.burundiRed, fontSize: 12)),
                    ),
                ],
              );
            },
          ),
        );

      case 'checkbox':
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: CheckboxListTile(
            title: Text(label, style: TextStyle(color: textColor)),
            value: _formValues[field.fieldName] == true,
            onChanged: (val) => setState(() => _formValues[field.fieldName] = val ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.burundiGreen,
          ),
        );

      case 'date':
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: TextFormField(
            controller: _formControllers[field.fieldName],
            readOnly: true,
            decoration: _inputDecoration(label, placeholder, helpText, isDark, field.isRequired).copyWith(
              suffixIcon: const Icon(Icons.calendar_today, size: 18),
            ),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime(2000, 1, 1),
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                _formControllers[field.fieldName]?.text =
                    '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
              }
            },
            validator: field.isRequired ? (v) => (v == null || v.isEmpty) ? 'Required' : null : null,
          ),
        );

      case 'time':
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: TextFormField(
            controller: _formControllers[field.fieldName],
            readOnly: true,
            decoration: _inputDecoration(label, placeholder, helpText, isDark, field.isRequired).copyWith(
              suffixIcon: const Icon(Icons.access_time, size: 18),
            ),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.now(),
              );
              if (picked != null && mounted) {
                _formControllers[field.fieldName]?.text =
                    '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
              }
            },
            validator: field.isRequired ? (v) => (v == null || v.isEmpty) ? 'Required' : null : null,
          ),
        );

      case 'file':
      case 'image':
        final pickedFile = _pickedFiles[field.fieldName];
        final isImage = field.fieldType == 'image';
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: FormField<File>(
            validator: field.isRequired ? (v) => v == null ? 'Required' : null : null,
            initialValue: pickedFile,
            builder: (state) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    field.isRequired ? '$label *' : label,
                    style: TextStyle(fontSize: 14, color: textColor, fontWeight: FontWeight.w500),
                  ),
                  if (helpText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(helpText, style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38)),
                    ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      File? file;
                      if (isImage) {
                        final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
                        if (picked != null) file = File(picked.path);
                      } else {
                        final result = await FilePicker.platform.pickFiles();
                        if (result != null && result.files.single.path != null) {
                          file = File(result.files.single.path!);
                        }
                      }
                      if (file != null) {
                        setState(() => _pickedFiles[field.fieldName] = file!);
                        state.didChange(file);
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: state.hasError
                              ? AppColors.burundiRed
                              : (isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isImage ? Icons.image_outlined : Icons.attach_file,
                            color: pickedFile != null ? AppColors.burundiGreen : (isDark ? Colors.white38 : Colors.black38),
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              pickedFile != null
                                  ? pickedFile.path.split('/').last
                                  : (isImage ? 'Tap to select image' : 'Tap to select file'),
                              style: TextStyle(
                                color: pickedFile != null ? textColor : (isDark ? Colors.white38 : Colors.black38),
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (pickedFile != null)
                            GestureDetector(
                              onTap: () {
                                setState(() => _pickedFiles.remove(field.fieldName));
                                state.didChange(null);
                              },
                              child: Icon(Icons.close, size: 18, color: isDark ? Colors.white38 : Colors.black38),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (state.hasError)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, top: 4),
                      child: Text(state.errorText!, style: const TextStyle(color: AppColors.burundiRed, fontSize: 12)),
                    ),
                ],
              );
            },
          ),
        );

      default:
        // text, email, phone, number, passport, url
        final isEmailField = field.fieldName == 'email';
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: TextFormField(
            controller: _formControllers[field.fieldName],
            keyboardType: _getKeyboardType(field.fieldType),
            readOnly: isEmailField,
            textCapitalization: field.fieldType == 'text' ? TextCapitalization.words : TextCapitalization.none,
            decoration: _inputDecoration(label, placeholder, helpText, isDark, field.isRequired).copyWith(
              suffixIcon: isEmailField ? const Icon(Icons.lock_outline, size: 18, color: Colors.grey) : null,
            ),
            validator: (v) {
              if (field.isRequired && (v == null || v.trim().isEmpty)) return 'Required';
              if (field.validationRegex.isNotEmpty && v != null && v.isNotEmpty) {
                final regex = RegExp(field.validationRegex);
                if (!regex.hasMatch(v)) return 'Invalid format';
              }
              return null;
            },
          ),
        );
    }
  }

  Widget _buildEmailVerificationBanner(bool isDark) {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.isEmailVerified) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 4),
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

  InputDecoration _inputDecoration(String label, String? placeholder, String? helpText, bool isDark, bool required) {
    return InputDecoration(
      labelText: required ? '$label *' : label,
      hintText: placeholder,
      helperText: (helpText != null && helpText.isNotEmpty) ? helpText : null,
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

  TextInputType _getKeyboardType(String fieldType) {
    switch (fieldType) {
      case 'email':
        return TextInputType.emailAddress;
      case 'phone':
        return TextInputType.phone;
      case 'number':
        return TextInputType.number;
      case 'url':
        return TextInputType.url;
      default:
        return TextInputType.text;
    }
  }
}
