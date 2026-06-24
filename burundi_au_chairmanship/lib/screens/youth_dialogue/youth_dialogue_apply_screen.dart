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
  bool _hasTriedSubmit = false;

  // Dynamic form state
  final Map<String, TextEditingController> _formControllers = {};
  final Map<String, dynamic> _formValues = {};
  final Map<String, File> _pickedFiles = {};

  // Phone country code state
  String _phoneCountryCode = '+257'; // Default Burundi
  String _phoneCountryFlag = '🇧🇮';

  // International country codes — Africa first, then alphabetical by continent
  static const List<Map<String, String>> _phoneCodes = [
    // ── Africa ──
    {'code': '+257', 'flag': '🇧🇮', 'name': 'Burundi'},
    {'code': '+213', 'flag': '🇩🇿', 'name': 'Algeria'},
    {'code': '+244', 'flag': '🇦🇴', 'name': 'Angola'},
    {'code': '+229', 'flag': '🇧🇯', 'name': 'Benin'},
    {'code': '+267', 'flag': '🇧🇼', 'name': 'Botswana'},
    {'code': '+226', 'flag': '🇧🇫', 'name': 'Burkina Faso'},
    {'code': '+238', 'flag': '🇨🇻', 'name': 'Cabo Verde'},
    {'code': '+237', 'flag': '🇨🇲', 'name': 'Cameroon'},
    {'code': '+236', 'flag': '🇨🇫', 'name': 'Central African Rep.'},
    {'code': '+235', 'flag': '🇹🇩', 'name': 'Chad'},
    {'code': '+269', 'flag': '🇰🇲', 'name': 'Comoros'},
    {'code': '+242', 'flag': '🇨🇬', 'name': 'Congo (Brazzaville)'},
    {'code': '+243', 'flag': '🇨🇩', 'name': 'Congo (DRC)'},
    {'code': '+225', 'flag': '🇨🇮', 'name': "Côte d'Ivoire"},
    {'code': '+253', 'flag': '🇩🇯', 'name': 'Djibouti'},
    {'code': '+20', 'flag': '🇪🇬', 'name': 'Egypt'},
    {'code': '+240', 'flag': '🇬🇶', 'name': 'Equatorial Guinea'},
    {'code': '+291', 'flag': '🇪🇷', 'name': 'Eritrea'},
    {'code': '+268', 'flag': '🇸🇿', 'name': 'Eswatini'},
    {'code': '+251', 'flag': '🇪🇹', 'name': 'Ethiopia'},
    {'code': '+241', 'flag': '🇬🇦', 'name': 'Gabon'},
    {'code': '+220', 'flag': '🇬🇲', 'name': 'Gambia'},
    {'code': '+233', 'flag': '🇬🇭', 'name': 'Ghana'},
    {'code': '+224', 'flag': '🇬🇳', 'name': 'Guinea'},
    {'code': '+245', 'flag': '🇬🇼', 'name': 'Guinea-Bissau'},
    {'code': '+254', 'flag': '🇰🇪', 'name': 'Kenya'},
    {'code': '+266', 'flag': '🇱🇸', 'name': 'Lesotho'},
    {'code': '+231', 'flag': '🇱🇷', 'name': 'Liberia'},
    {'code': '+218', 'flag': '🇱🇾', 'name': 'Libya'},
    {'code': '+261', 'flag': '🇲🇬', 'name': 'Madagascar'},
    {'code': '+265', 'flag': '🇲🇼', 'name': 'Malawi'},
    {'code': '+223', 'flag': '🇲🇱', 'name': 'Mali'},
    {'code': '+222', 'flag': '🇲🇷', 'name': 'Mauritania'},
    {'code': '+230', 'flag': '🇲🇺', 'name': 'Mauritius'},
    {'code': '+212', 'flag': '🇲🇦', 'name': 'Morocco'},
    {'code': '+258', 'flag': '🇲🇿', 'name': 'Mozambique'},
    {'code': '+264', 'flag': '🇳🇦', 'name': 'Namibia'},
    {'code': '+227', 'flag': '🇳🇪', 'name': 'Niger'},
    {'code': '+234', 'flag': '🇳🇬', 'name': 'Nigeria'},
    {'code': '+250', 'flag': '🇷🇼', 'name': 'Rwanda'},
    {'code': '+239', 'flag': '🇸🇹', 'name': 'São Tomé'},
    {'code': '+221', 'flag': '🇸🇳', 'name': 'Senegal'},
    {'code': '+248', 'flag': '🇸🇨', 'name': 'Seychelles'},
    {'code': '+232', 'flag': '🇸🇱', 'name': 'Sierra Leone'},
    {'code': '+252', 'flag': '🇸🇴', 'name': 'Somalia'},
    {'code': '+27', 'flag': '🇿🇦', 'name': 'South Africa'},
    {'code': '+211', 'flag': '🇸🇸', 'name': 'South Sudan'},
    {'code': '+249', 'flag': '🇸🇩', 'name': 'Sudan'},
    {'code': '+255', 'flag': '🇹🇿', 'name': 'Tanzania'},
    {'code': '+228', 'flag': '🇹🇬', 'name': 'Togo'},
    {'code': '+216', 'flag': '🇹🇳', 'name': 'Tunisia'},
    {'code': '+256', 'flag': '🇺🇬', 'name': 'Uganda'},
    {'code': '+260', 'flag': '🇿🇲', 'name': 'Zambia'},
    {'code': '+263', 'flag': '🇿🇼', 'name': 'Zimbabwe'},
    // ── Americas ──
    {'code': '+54', 'flag': '🇦🇷', 'name': 'Argentina'},
    {'code': '+591', 'flag': '🇧🇴', 'name': 'Bolivia'},
    {'code': '+55', 'flag': '🇧🇷', 'name': 'Brazil'},
    {'code': '+1', 'flag': '🇨🇦', 'name': 'Canada'},
    {'code': '+56', 'flag': '🇨🇱', 'name': 'Chile'},
    {'code': '+57', 'flag': '🇨🇴', 'name': 'Colombia'},
    {'code': '+506', 'flag': '🇨🇷', 'name': 'Costa Rica'},
    {'code': '+53', 'flag': '🇨🇺', 'name': 'Cuba'},
    {'code': '+593', 'flag': '🇪🇨', 'name': 'Ecuador'},
    {'code': '+502', 'flag': '🇬🇹', 'name': 'Guatemala'},
    {'code': '+509', 'flag': '🇭🇹', 'name': 'Haiti'},
    {'code': '+504', 'flag': '🇭🇳', 'name': 'Honduras'},
    {'code': '+876', 'flag': '🇯🇲', 'name': 'Jamaica'},
    {'code': '+52', 'flag': '🇲🇽', 'name': 'Mexico'},
    {'code': '+507', 'flag': '🇵🇦', 'name': 'Panama'},
    {'code': '+595', 'flag': '🇵🇾', 'name': 'Paraguay'},
    {'code': '+51', 'flag': '🇵🇪', 'name': 'Peru'},
    {'code': '+1', 'flag': '🇺🇸', 'name': 'United States'},
    {'code': '+598', 'flag': '🇺🇾', 'name': 'Uruguay'},
    {'code': '+58', 'flag': '🇻🇪', 'name': 'Venezuela'},
    // ── Europe ──
    {'code': '+43', 'flag': '🇦🇹', 'name': 'Austria'},
    {'code': '+32', 'flag': '🇧🇪', 'name': 'Belgium'},
    {'code': '+359', 'flag': '🇧🇬', 'name': 'Bulgaria'},
    {'code': '+385', 'flag': '🇭🇷', 'name': 'Croatia'},
    {'code': '+420', 'flag': '🇨🇿', 'name': 'Czech Republic'},
    {'code': '+45', 'flag': '🇩🇰', 'name': 'Denmark'},
    {'code': '+358', 'flag': '🇫🇮', 'name': 'Finland'},
    {'code': '+33', 'flag': '🇫🇷', 'name': 'France'},
    {'code': '+49', 'flag': '🇩🇪', 'name': 'Germany'},
    {'code': '+30', 'flag': '🇬🇷', 'name': 'Greece'},
    {'code': '+36', 'flag': '🇭🇺', 'name': 'Hungary'},
    {'code': '+353', 'flag': '🇮🇪', 'name': 'Ireland'},
    {'code': '+39', 'flag': '🇮🇹', 'name': 'Italy'},
    {'code': '+31', 'flag': '🇳🇱', 'name': 'Netherlands'},
    {'code': '+47', 'flag': '🇳🇴', 'name': 'Norway'},
    {'code': '+48', 'flag': '🇵🇱', 'name': 'Poland'},
    {'code': '+351', 'flag': '🇵🇹', 'name': 'Portugal'},
    {'code': '+40', 'flag': '🇷🇴', 'name': 'Romania'},
    {'code': '+7', 'flag': '🇷🇺', 'name': 'Russia'},
    {'code': '+381', 'flag': '🇷🇸', 'name': 'Serbia'},
    {'code': '+34', 'flag': '🇪🇸', 'name': 'Spain'},
    {'code': '+46', 'flag': '🇸🇪', 'name': 'Sweden'},
    {'code': '+41', 'flag': '🇨🇭', 'name': 'Switzerland'},
    {'code': '+380', 'flag': '🇺🇦', 'name': 'Ukraine'},
    {'code': '+44', 'flag': '🇬🇧', 'name': 'United Kingdom'},
    // ── Asia ──
    {'code': '+93', 'flag': '🇦🇫', 'name': 'Afghanistan'},
    {'code': '+880', 'flag': '🇧🇩', 'name': 'Bangladesh'},
    {'code': '+855', 'flag': '🇰🇭', 'name': 'Cambodia'},
    {'code': '+86', 'flag': '🇨🇳', 'name': 'China'},
    {'code': '+852', 'flag': '🇭🇰', 'name': 'Hong Kong'},
    {'code': '+91', 'flag': '🇮🇳', 'name': 'India'},
    {'code': '+62', 'flag': '🇮🇩', 'name': 'Indonesia'},
    {'code': '+98', 'flag': '🇮🇷', 'name': 'Iran'},
    {'code': '+964', 'flag': '🇮🇶', 'name': 'Iraq'},
    {'code': '+972', 'flag': '🇮🇱', 'name': 'Israel'},
    {'code': '+81', 'flag': '🇯🇵', 'name': 'Japan'},
    {'code': '+962', 'flag': '🇯🇴', 'name': 'Jordan'},
    {'code': '+7', 'flag': '🇰🇿', 'name': 'Kazakhstan'},
    {'code': '+965', 'flag': '🇰🇼', 'name': 'Kuwait'},
    {'code': '+961', 'flag': '🇱🇧', 'name': 'Lebanon'},
    {'code': '+60', 'flag': '🇲🇾', 'name': 'Malaysia'},
    {'code': '+95', 'flag': '🇲🇲', 'name': 'Myanmar'},
    {'code': '+977', 'flag': '🇳🇵', 'name': 'Nepal'},
    {'code': '+968', 'flag': '🇴🇲', 'name': 'Oman'},
    {'code': '+92', 'flag': '🇵🇰', 'name': 'Pakistan'},
    {'code': '+63', 'flag': '🇵🇭', 'name': 'Philippines'},
    {'code': '+974', 'flag': '🇶🇦', 'name': 'Qatar'},
    {'code': '+966', 'flag': '🇸🇦', 'name': 'Saudi Arabia'},
    {'code': '+65', 'flag': '🇸🇬', 'name': 'Singapore'},
    {'code': '+82', 'flag': '🇰🇷', 'name': 'South Korea'},
    {'code': '+94', 'flag': '🇱🇰', 'name': 'Sri Lanka'},
    {'code': '+66', 'flag': '🇹🇭', 'name': 'Thailand'},
    {'code': '+90', 'flag': '🇹🇷', 'name': 'Turkey'},
    {'code': '+971', 'flag': '🇦🇪', 'name': 'UAE'},
    {'code': '+84', 'flag': '🇻🇳', 'name': 'Vietnam'},
    {'code': '+967', 'flag': '🇾🇪', 'name': 'Yemen'},
    // ── Oceania ──
    {'code': '+61', 'flag': '🇦🇺', 'name': 'Australia'},
    {'code': '+679', 'flag': '🇫🇯', 'name': 'Fiji'},
    {'code': '+64', 'flag': '🇳🇿', 'name': 'New Zealand'},
    {'code': '+675', 'flag': '🇵🇬', 'name': 'Papua New Guinea'},
  ];

  // Title options for the title dropdown
  static const List<String> _titleOptions = [
    'Mr.',
    'Mrs.',
    'Ms.',
    'Dr.',
    'Prof.',
    'H.E.',
    'Hon.',
    'Amb.',
  ];

  // Position options for the position dropdown
  static const List<String> _positionOptions = [
    'Moderator',
    'Technician',
    'Scientific Committee',
    'Panelist',
    'Partner',
    'Participant',
    'Guest of Honor',
    'Security',
    'Protocol',
  ];

  // Country list for 'country' field type — international
  static const List<String> _countryList = [
    'Afghanistan', 'Albania', 'Algeria', 'Angola', 'Argentina', 'Australia',
    'Austria', 'Bangladesh', 'Belgium', 'Benin', 'Bolivia', 'Botswana',
    'Brazil', 'Bulgaria', 'Burkina Faso', 'Burundi', 'Cabo Verde',
    'Cambodia', 'Cameroon', 'Canada', 'Central African Republic', 'Chad',
    'Chile', 'China', 'Colombia', 'Comoros', 'Congo (Brazzaville)',
    'Congo (DRC)', 'Costa Rica', "Côte d'Ivoire", 'Croatia', 'Cuba',
    'Czech Republic', 'Denmark', 'Djibouti', 'Ecuador', 'Egypt',
    'Equatorial Guinea', 'Eritrea', 'Eswatini', 'Ethiopia', 'Fiji',
    'Finland', 'France', 'Gabon', 'Gambia', 'Germany', 'Ghana', 'Greece',
    'Guatemala', 'Guinea', 'Guinea-Bissau', 'Haiti', 'Honduras',
    'Hong Kong', 'Hungary', 'India', 'Indonesia', 'Iran', 'Iraq',
    'Ireland', 'Israel', 'Italy', 'Jamaica', 'Japan', 'Jordan',
    'Kazakhstan', 'Kenya', 'Kuwait', 'Lebanon', 'Lesotho', 'Liberia',
    'Libya', 'Madagascar', 'Malawi', 'Malaysia', 'Mali', 'Mauritania',
    'Mauritius', 'Mexico', 'Morocco', 'Mozambique', 'Myanmar', 'Namibia',
    'Nepal', 'Netherlands', 'New Zealand', 'Niger', 'Nigeria', 'Norway',
    'Oman', 'Pakistan', 'Panama', 'Papua New Guinea', 'Paraguay', 'Peru',
    'Philippines', 'Poland', 'Portugal', 'Qatar', 'Romania', 'Russia',
    'Rwanda', 'São Tomé and Príncipe', 'Saudi Arabia', 'Senegal',
    'Serbia', 'Seychelles', 'Sierra Leone', 'Singapore', 'Somalia',
    'South Africa', 'South Korea', 'South Sudan', 'Spain', 'Sri Lanka',
    'Sudan', 'Sweden', 'Switzerland', 'Tanzania', 'Thailand', 'Togo',
    'Tunisia', 'Turkey', 'UAE', 'Uganda', 'Ukraine', 'United Kingdom',
    'United States', 'Uruguay', 'Venezuela', 'Vietnam', 'Yemen',
    'Zambia', 'Zimbabwe', 'Other',
  ];

  /// Converts ISO 3166-1 alpha-2 code to regional indicator flag emoji
  static String _countryCodeToFlag(String code) {
    if (code.length != 2 || code == 'OTHER') return '';
    final upper = code.toUpperCase();
    return String.fromCharCodes([
      upper.codeUnitAt(0) + 0x1F1E6 - 0x41,
      upper.codeUnitAt(1) + 0x1F1E6 - 0x41,
    ]);
  }

  // Nationality list for 'nationality' field type — international
  static const List<Map<String, String>> _nationalities = [
    // ── Africa ──
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
    // ── Americas ──
    {'code': 'AR', 'name': 'Argentina'}, {'code': 'BO', 'name': 'Bolivia'},
    {'code': 'BR', 'name': 'Brazil'}, {'code': 'CA', 'name': 'Canada'},
    {'code': 'CL', 'name': 'Chile'}, {'code': 'CO', 'name': 'Colombia'},
    {'code': 'CR', 'name': 'Costa Rica'}, {'code': 'CU', 'name': 'Cuba'},
    {'code': 'EC', 'name': 'Ecuador'}, {'code': 'GT', 'name': 'Guatemala'},
    {'code': 'HT', 'name': 'Haiti'}, {'code': 'HN', 'name': 'Honduras'},
    {'code': 'JM', 'name': 'Jamaica'}, {'code': 'MX', 'name': 'Mexico'},
    {'code': 'PA', 'name': 'Panama'}, {'code': 'PY', 'name': 'Paraguay'},
    {'code': 'PE', 'name': 'Peru'}, {'code': 'US', 'name': 'United States'},
    {'code': 'UY', 'name': 'Uruguay'}, {'code': 'VE', 'name': 'Venezuela'},
    // ── Europe ──
    {'code': 'AT', 'name': 'Austria'}, {'code': 'BE', 'name': 'Belgium'},
    {'code': 'BG', 'name': 'Bulgaria'}, {'code': 'HR', 'name': 'Croatia'},
    {'code': 'CZ', 'name': 'Czech Republic'}, {'code': 'DK', 'name': 'Denmark'},
    {'code': 'FI', 'name': 'Finland'}, {'code': 'FR', 'name': 'France'},
    {'code': 'DE', 'name': 'Germany'}, {'code': 'GR', 'name': 'Greece'},
    {'code': 'HU', 'name': 'Hungary'}, {'code': 'IE', 'name': 'Ireland'},
    {'code': 'IT', 'name': 'Italy'}, {'code': 'NL', 'name': 'Netherlands'},
    {'code': 'NO', 'name': 'Norway'}, {'code': 'PL', 'name': 'Poland'},
    {'code': 'PT', 'name': 'Portugal'}, {'code': 'RO', 'name': 'Romania'},
    {'code': 'RU', 'name': 'Russia'}, {'code': 'RS', 'name': 'Serbia'},
    {'code': 'ES', 'name': 'Spain'}, {'code': 'SE', 'name': 'Sweden'},
    {'code': 'CH', 'name': 'Switzerland'}, {'code': 'UA', 'name': 'Ukraine'},
    {'code': 'GB', 'name': 'United Kingdom'},
    // ── Asia & Middle East ──
    {'code': 'AF', 'name': 'Afghanistan'}, {'code': 'BD', 'name': 'Bangladesh'},
    {'code': 'KH', 'name': 'Cambodia'}, {'code': 'CN', 'name': 'China'},
    {'code': 'HK', 'name': 'Hong Kong'}, {'code': 'IN', 'name': 'India'},
    {'code': 'ID', 'name': 'Indonesia'}, {'code': 'IR', 'name': 'Iran'},
    {'code': 'IQ', 'name': 'Iraq'}, {'code': 'IL', 'name': 'Israel'},
    {'code': 'JP', 'name': 'Japan'}, {'code': 'JO', 'name': 'Jordan'},
    {'code': 'KZ', 'name': 'Kazakhstan'}, {'code': 'KW', 'name': 'Kuwait'},
    {'code': 'LB', 'name': 'Lebanon'}, {'code': 'MY', 'name': 'Malaysia'},
    {'code': 'MM', 'name': 'Myanmar'}, {'code': 'NP', 'name': 'Nepal'},
    {'code': 'OM', 'name': 'Oman'}, {'code': 'PK', 'name': 'Pakistan'},
    {'code': 'PH', 'name': 'Philippines'}, {'code': 'QA', 'name': 'Qatar'},
    {'code': 'SA', 'name': 'Saudi Arabia'}, {'code': 'SG', 'name': 'Singapore'},
    {'code': 'KR', 'name': 'South Korea'}, {'code': 'LK', 'name': 'Sri Lanka'},
    {'code': 'TH', 'name': 'Thailand'}, {'code': 'TR', 'name': 'Turkey'},
    {'code': 'AE', 'name': 'UAE'}, {'code': 'VN', 'name': 'Vietnam'},
    {'code': 'YE', 'name': 'Yemen'},
    // ── Oceania ──
    {'code': 'AU', 'name': 'Australia'}, {'code': 'FJ', 'name': 'Fiji'},
    {'code': 'NZ', 'name': 'New Zealand'}, {'code': 'PG', 'name': 'Papua New Guinea'},
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
      if (field.fieldName.toLowerCase().contains('motivation')) continue;
      // Title & position fields always use dropdown (_formValues), never a text controller
      if (field.fieldName == 'title' || field.fieldName == 'position') continue;
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
    setState(() => _hasTriedSubmit = true);
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fix the errors highlighted in red below.'),
          backgroundColor: AppColors.burundiRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

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
        if (field.fieldName.toLowerCase().contains('motivation')) continue;
        final name = field.fieldName;
        if (_formControllers.containsKey(name)) {
          var value = _formControllers[name]!.text.trim();
          // Prepend country code for phone fields
          if (field.fieldType == 'phone' && value.isNotEmpty && !value.startsWith('+')) {
            value = '$_phoneCountryCode $value';
          }
          formData[name] = value;
        } else if (_formValues.containsKey(name)) {
          formData[name] = _formValues[name];
        }
      }

      // Always include title and position even if not in backend form fields
      if (!formData.containsKey('title') && _formValues.containsKey('title')) {
        formData['title'] = _formValues['title'];
      }
      if (!formData.containsKey('position') && _formValues.containsKey('position')) {
        formData['position'] = _formValues['position'];
      }

      await ApiService().youthDialogueApply({'form_data': formData});
      if (!mounted) return;
      setState(() => _submitted = true);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showErrorDialog(e.message);
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Split multi-line error messages into bullet points
    final errors = message.split('\n').where((e) => e.trim().isNotEmpty).toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.burundiRed, size: 24),
            const SizedBox(width: 10),
            Text('Submission Error',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Please fix the following issues:',
              style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black54)),
            const SizedBox(height: 12),
            ...errors.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('  \u2022  ', style: TextStyle(color: AppColors.burundiRed, fontWeight: FontWeight.bold)),
                  Expanded(child: Text(e.trim(),
                    style: TextStyle(fontSize: 14, height: 1.4,
                      color: isDark ? Colors.white70 : Colors.black87))),
                ],
              ),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: AppColors.burundiGreen, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final langCode = Localizations.localeOf(context).languageCode;

    if (_submitted) {
      final isFr = langCode == 'fr';
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
        appBar: AppBar(
          title: Text(isFr ? 'Candidature envoyée' : 'Application Submitted'),
          backgroundColor: AppColors.burundiGreen,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              // Success icon
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  color: AppColors.burundiGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, size: 54, color: AppColors.burundiGreen),
              ),
              const SizedBox(height: 24),
              Text(isFr ? 'Candidature envoyée !' : 'Application Submitted!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 12),
              Text(
                isFr
                    ? 'Votre candidature a été reçue avec succès et est en cours de traitement. Nous vous informerons dès qu\'une décision sera prise.'
                    : 'Your application has been successfully received and is being processed. We will notify you as soon as a decision has been made.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, height: 1.6, color: isDark ? Colors.white60 : Colors.black54)),
              const SizedBox(height: 28),
              // Next steps card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.burundiGreen.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.burundiGreen.withValues(alpha: 0.12)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 18, color: AppColors.burundiGreen),
                        const SizedBox(width: 8),
                        Text(isFr ? 'Prochaines étapes' : 'What happens next',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.burundiGreen)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildStepRow('1', isFr ? 'Notre équipe examinera votre candidature' : 'Our team will review your application', isDark),
                    _buildStepRow('2', isFr ? 'Vous recevrez une notification de la décision' : 'You will receive a notification with the decision', isDark),
                    _buildStepRow('3', isFr ? 'Si accepté(e), téléchargez les documents requis' : 'If accepted, upload the required documents', isDark),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Email confirmation note
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF7FAFC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.email_outlined, size: 20, color: isDark ? Colors.white38 : Colors.black38),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isFr
                            ? 'Un email de confirmation a été envoyé à votre adresse email.'
                            : 'A confirmation email has been sent to your email address.',
                        style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black45),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.burundiGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(isFr ? 'Retour au Dialogue des Jeunes' : 'Back to Youth Dialogue',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      );
    }

    final activeFields = widget.formFields
        .where((f) => f.isActive)
        .where((f) => !f.fieldName.toLowerCase().contains('motivation'))
        .toList();

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
        autovalidateMode: _hasTriedSubmit
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildEmailVerificationBanner(isDark),
            const SizedBox(height: 16),

            // Title dropdown (always shown)
            if (!activeFields.any((f) => f.fieldName == 'title'))
              _buildFixedDropdown('title', 'Title', 'Select title', _titleOptions, isDark, isRequired: true),

            // Position dropdown (always shown)
            if (!activeFields.any((f) => f.fieldName == 'position'))
              _buildFixedDropdown('position', 'Position / Role', 'Select position', _positionOptions, isDark, isRequired: true),

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

    // Title field: always render as a dropdown with fixed options
    if (field.fieldName == 'title') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: DropdownButtonFormField<String>(
          key: ValueKey('title_${field.fieldName}'),
          value: _formValues[field.fieldName] as String?,
          decoration: _inputDecoration(label, null, helpText, isDark, field.isRequired),
          hint: Text(placeholder.isNotEmpty ? placeholder : 'Select title'),
          isExpanded: true,
          menuMaxHeight: 300,
          items: _titleOptions
              .map((o) => DropdownMenuItem(value: o, child: Text(o, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (val) => setState(() => _formValues[field.fieldName] = val),
          validator: field.isRequired ? (v) => v == null ? 'Required' : null : null,
        ),
      );
    }

    // Position field: always render as a dropdown with fixed options
    if (field.fieldName == 'position') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: DropdownButtonFormField<String>(
          key: ValueKey('position_${field.fieldName}'),
          value: _formValues[field.fieldName] as String?,
          decoration: _inputDecoration(label, null, helpText, isDark, field.isRequired),
          hint: Text(placeholder.isNotEmpty ? placeholder : 'Select position'),
          isExpanded: true,
          menuMaxHeight: 300,
          items: _positionOptions
              .map((o) => DropdownMenuItem(value: o, child: Text(o, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (val) => setState(() => _formValues[field.fieldName] = val),
          validator: field.isRequired ? (v) => v == null ? 'Required' : null : null,
        ),
      );
    }

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
      case 'dropdown':
        final options = field.options.map((o) => o.toString()).toList();
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: DropdownButtonFormField<String>(
            key: ValueKey('select_${field.fieldName}'),
            value: _formValues[field.fieldName] as String?,
            decoration: _inputDecoration(label, null, helpText, isDark, field.isRequired),
            hint: placeholder.isNotEmpty ? Text(placeholder) : null,
            isExpanded: true,
            menuMaxHeight: 300,
            items: options
                .map((o) => DropdownMenuItem(value: o, child: Text(o, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (val) => setState(() => _formValues[field.fieldName] = val),
            validator: field.isRequired ? (v) => v == null ? 'Required' : null : null,
          ),
        );

      case 'country':
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: DropdownButtonFormField<String>(
            key: ValueKey('country_${field.fieldName}'),
            value: _formValues[field.fieldName] as String?,
            decoration: _inputDecoration(label, null, helpText, isDark, field.isRequired),
            isExpanded: true,
            menuMaxHeight: 300,
            items: _countryList
                .map((o) => DropdownMenuItem(value: o, child: Text(o, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (val) => setState(() => _formValues[field.fieldName] = val),
            validator: field.isRequired ? (v) => v == null ? 'Required' : null : null,
          ),
        );

      case 'nationality':
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: DropdownButtonFormField<String>(
            key: ValueKey('nationality_${field.fieldName}'),
            value: _formValues[field.fieldName] as String?,
            decoration: _inputDecoration(label, null, helpText, isDark, field.isRequired),
            isExpanded: true,
            menuMaxHeight: 300,
            items: _nationalities
                .map((n) {
                  final flag = _countryCodeToFlag(n['code']!);
                  return DropdownMenuItem(
                    value: n['code'],
                    child: Row(
                      children: [
                        if (flag.isNotEmpty) ...[
                          Text(flag, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 10),
                        ],
                        Expanded(child: Text(n['name']!, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  );
                })
                .toList(),
            onChanged: (val) => setState(() => _formValues[field.fieldName] = val),
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

      case 'phone':
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: TextFormField(
            controller: _formControllers[field.fieldName],
            keyboardType: TextInputType.phone,
            decoration: _inputDecoration(label, placeholder.isNotEmpty ? placeholder : 'Phone number', helpText, isDark, field.isRequired).copyWith(
              prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
              prefixIcon: GestureDetector(
                onTap: () => _showPhoneCodePicker(isDark),
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_phoneCountryFlag, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 4),
                      Text(_phoneCountryCode, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87)),
                      Icon(Icons.arrow_drop_down, size: 16, color: isDark ? Colors.white54 : Colors.black45),
                    ],
                  ),
                ),
              ),
            ),
            validator: (v) {
              if (field.isRequired && (v == null || v.trim().isEmpty)) return 'Required';
              return null;
            },
          ),
        );

      case 'email':
        final authProv = context.read<AuthProvider>();
        final isVerified = authProv.isEmailVerified && authProv.userEmail != null && authProv.userEmail!.isNotEmpty;
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _formControllers[field.fieldName],
                keyboardType: TextInputType.emailAddress,
                textCapitalization: TextCapitalization.none,
                readOnly: isVerified,
                enabled: !isVerified,
                style: TextStyle(
                  color: isVerified
                      ? (isDark ? Colors.white38 : Colors.black38)
                      : (isDark ? Colors.white : Colors.black87),
                ),
                decoration: _inputDecoration(label, placeholder.isNotEmpty ? placeholder : 'your.email@example.com', helpText, isDark, field.isRequired).copyWith(
                  suffixIcon: isVerified
                      ? const Icon(Icons.verified, color: AppColors.burundiGreen, size: 20)
                      : null,
                  filled: true,
                  fillColor: isVerified
                      ? (isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF0F0F0))
                      : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
                ),
                validator: (v) {
                  if (field.isRequired && (v == null || v.trim().isEmpty)) return 'Required';
                  if (v != null && v.isNotEmpty) {
                    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                    if (!emailRegex.hasMatch(v.trim())) return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              if (isVerified)
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 4),
                  child: Text(
                    'Email verified',
                    style: TextStyle(fontSize: 12, color: AppColors.burundiGreen, fontWeight: FontWeight.w500),
                  ),
                ),
            ],
          ),
        );

      default:
        // text, number, passport, url
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: TextFormField(
            controller: _formControllers[field.fieldName],
            keyboardType: _getKeyboardType(field.fieldType),
            textCapitalization: field.fieldType == 'text' ? TextCapitalization.words : TextCapitalization.none,
            decoration: _inputDecoration(label, placeholder, helpText, isDark, field.isRequired),
            validator: (v) {
              if (field.isRequired && (v == null || v.trim().isEmpty)) return 'Required';
              if (field.validationRegex.isNotEmpty && v != null && v.isNotEmpty) {
                try {
                  final regex = RegExp(field.validationRegex);
                  if (!regex.hasMatch(v)) return 'Invalid format';
                } catch (_) {
                  // Skip broken regex
                }
              }
              return null;
            },
          ),
        );
    }
  }

  Widget _buildStepRow(String number, String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              color: AppColors.burundiGreen.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(number, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.burundiGreen)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(text, style: TextStyle(fontSize: 13, height: 1.4, color: isDark ? Colors.white70 : Colors.black54)),
            ),
          ),
        ],
      ),
    );
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

  void _showPhoneCodePicker(bool isDark) {
    final searchController = TextEditingController();
    List<Map<String, String>> filtered = List.from(_phoneCodes);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.85,
              expand: false,
              builder: (ctx, scrollController) {
                return Column(
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: 'Search country...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onChanged: (query) {
                          setSheetState(() {
                            final q = query.toLowerCase();
                            filtered = _phoneCodes.where((c) =>
                              c['name']!.toLowerCase().contains(q) ||
                              c['code']!.contains(q)
                            ).toList();
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) {
                          final country = filtered[i];
                          final isSelected = country['code'] == _phoneCountryCode && country['flag'] == _phoneCountryFlag;
                          return ListTile(
                            leading: Text(country['flag']!, style: const TextStyle(fontSize: 24)),
                            title: Text(country['name']!, style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            )),
                            trailing: Text(country['code']!, style: TextStyle(
                              color: isSelected ? AppColors.burundiGreen : (isDark ? Colors.white54 : Colors.black45),
                              fontWeight: FontWeight.w500,
                            )),
                            selected: isSelected,
                            selectedTileColor: AppColors.burundiGreen.withValues(alpha: 0.08),
                            onTap: () {
                              setState(() {
                                _phoneCountryCode = country['code']!;
                                _phoneCountryFlag = country['flag']!;
                              });
                              Navigator.pop(ctx);
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

  Widget _buildFixedDropdown(String fieldName, String label, String hint, List<String> options, bool isDark, {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        key: ValueKey('fixed_$fieldName'),
        value: _formValues[fieldName] as String?,
        decoration: _inputDecoration(label, null, null, isDark, isRequired),
        hint: Text(hint),
        isExpanded: true,
        menuMaxHeight: 300,
        items: options
            .map((o) => DropdownMenuItem(value: o, child: Text(o, overflow: TextOverflow.ellipsis)))
            .toList(),
        onChanged: (val) => setState(() => _formValues[fieldName] = val),
        validator: isRequired ? (v) => v == null ? 'Required' : null : null,
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.burundiRed, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.burundiRed, width: 2),
      ),
      errorStyle: const TextStyle(
        color: AppColors.burundiRed,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      floatingLabelStyle: WidgetStateTextStyle.resolveWith((states) {
        if (states.contains(WidgetState.error)) {
          return const TextStyle(color: AppColors.burundiRed, fontWeight: FontWeight.w600);
        }
        if (states.contains(WidgetState.focused)) {
          return const TextStyle(color: AppColors.burundiGreen, fontWeight: FontWeight.w500);
        }
        return TextStyle(color: isDark ? Colors.white60 : Colors.black54);
      }),
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
