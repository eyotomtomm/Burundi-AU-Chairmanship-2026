import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../config/app_constants.dart';
import '../../config/app_ds.dart';
import '../../config/environment.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

/// Who you are on Explore: photo, name, what you do and where you are from.
///
/// The same screen is reached from the settings profile and from your own
/// Explore profile — one editor, so the two can never disagree.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _api = ApiService();
  final _bioCtrl = TextEditingController();
  final _roleCtrl = TextEditingController();
  final _orgCtrl = TextEditingController();
  String? _nationality;
  String? _avatarUrl;
  File? _newAvatar;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _bioCtrl.dispose();
    _roleCtrl.dispose();
    _orgCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final me = await _api.getProfile();
      _bioCtrl.text = me['bio'] as String? ?? '';
      _roleCtrl.text = me['role'] as String? ?? '';
      _orgCtrl.text = me['organization'] as String? ?? '';
      final nat = me['nationality'] as String?;
      _nationality = (nat == null || nat.isEmpty) ? null : nat;
      _avatarUrl = me['profile_picture'] as String?;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 1024);
    if (picked != null) setState(() => _newAvatar = File(picked.path));
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      // The photo goes up as multipart; the text fields as JSON.
      if (_newAvatar != null) {
        await _api.uploadProfilePicture(_newAvatar!);
      }
      await _api.updateProfile({
        'bio': _bioCtrl.text.trim(),
        'role': _roleCtrl.text.trim(),
        'organization': _orgCtrl.text.trim(),
        if (_nationality != null) 'nationality': _nationality,
      });
      if (mounted) {
        await context.read<AuthProvider>().refreshProfile();
        HapticFeedback.lightImpact();
        if (mounted) Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fr = Localizations.localeOf(context).languageCode == 'fr';

    return Scaffold(
      backgroundColor: Ds.bg(context),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(Ds.headerHPad,
                MediaQuery.viewPaddingOf(context).top + 12, Ds.headerHPad, 18),
            decoration: const BoxDecoration(
              color: Ds.green,
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(Ds.rHeader)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context, false),
                  child: const SizedBox(
                    width: 32,
                    height: 32,
                    child: Icon(Icons.arrow_back_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
                const SizedBox(width: 8),
                Text(fr ? 'Modifier le profil' : 'Edit profile',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: Colors.white)),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2, color: Ds.green))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                    children: [
                      Center(child: _avatarPicker(context, fr)),
                      const SizedBox(height: 24),
                      _field(context, 'Bio', _bioCtrl,
                          hint: fr
                              ? 'Une ligne sur vous'
                              : 'One line about you',
                          maxLines: 3,
                          maxLength: 200),
                      _field(context, fr ? 'Rôle' : 'Role', _roleCtrl,
                          hint: fr
                              ? 'ex. Analyste des politiques'
                              : 'e.g. Policy Analyst'),
                      _field(
                          context,
                          fr ? 'Organisation' : 'Organisation',
                          _orgCtrl,
                          hint: fr
                              ? 'ex. Coalition des jeunes pour l\'eau'
                              : 'e.g. Youth Water Coalition'),
                      _countryField(context, fr),
                      const SizedBox(height: 8),
                      Text(
                        fr
                            ? 'Votre bio, rôle, organisation et pays apparaissent sur votre profil Explore. '
                                'Votre nom et votre titre honorifique proviennent de votre vérification.'
                            : 'Your bio, role, organisation and country appear on your Explore profile. '
                                'Your name and any honorific come from your verification.',
                        style: TextStyle(
                            fontSize: 13, height: 1.45, color: Ds.body(context)),
                      ),
                    ],
                  ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, 0, 16, MediaQuery.viewPaddingOf(context).bottom + 16),
            child: GestureDetector(
              onTap: _saving ? null : _save,
              child: Container(
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Ds.green,
                  borderRadius: BorderRadius.circular(Ds.rPill),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(fr ? 'Enregistrer' : 'Save',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarPicker(BuildContext context, bool fr) {
    final url = _avatarUrl;
    Widget image;
    if (_newAvatar != null) {
      image = Image.file(_newAvatar!, fit: BoxFit.cover);
    } else if (url != null && url.isNotEmpty) {
      image = CachedNetworkImage(
        imageUrl: Environment.fixMediaUrl(url),
        fit: BoxFit.cover,
        placeholder: (_, _) => Container(color: Ds.greenTint),
        errorWidget: (_, _, _) => Container(color: Ds.greenTint),
      );
    } else {
      image = Container(
        color: Ds.greenTint,
        alignment: Alignment.center,
        child: const Icon(Icons.person_rounded, size: 44, color: Ds.greenDeep),
      );
    }

    return GestureDetector(
      onTap: _pickAvatar,
      child: Column(
        children: [
          Stack(
            children: [
              ClipOval(child: SizedBox(width: 104, height: 104, child: image)),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Ds.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Ds.bg(context), width: 3),
                  ),
                  child: const Icon(Icons.camera_alt_rounded,
                      size: 16, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(fr ? 'Changer la photo' : 'Change photo',
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: Ds.green)),
        ],
      ),
    );
  }

  Widget _field(BuildContext context, String label, TextEditingController ctrl,
      {String? hint, int maxLines = 1, int? maxLength}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Ds.body(context))),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            maxLines: maxLines,
            maxLength: maxLength,
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: Ds.surface(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Ds.rTile),
                borderSide: BorderSide(color: Ds.outline(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Ds.rTile),
                borderSide: BorderSide(color: Ds.outline(context)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _countryField(BuildContext context, bool fr) {
    final entries = AppConstants.nationalityChoices.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(fr ? 'Pays' : 'Country',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Ds.body(context))),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _nationality,
            isExpanded: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: Ds.surface(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Ds.rTile),
                borderSide: BorderSide(color: Ds.outline(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Ds.rTile),
                borderSide: BorderSide(color: Ds.outline(context)),
              ),
            ),
            items: entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) => setState(() => _nationality = v),
          ),
        ],
      ),
    );
  }
}
