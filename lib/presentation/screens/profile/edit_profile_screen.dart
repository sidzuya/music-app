import 'dart:io' if (dart.library.html) 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _usernameController;
  late TextEditingController _emailController;
  late TextEditingController _bioController;
  final List<Map<String, String>> _socialLinks = [];
  XFile? _selectedProfileImage;
  XFile? _selectedBannerImage;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    
    _usernameController = TextEditingController(text: user?.username ?? "");
    _emailController = TextEditingController(text: user?.email ?? "");
    _bioController = TextEditingController(text: user?.bio ?? "");
    if (user?.socialLinks != null) {
      final nonPrivacyLinks = user!.socialLinks!.where((e) => e['type'] != 'privacy_settings');
      _socialLinks.addAll(nonPrivacyLinks.map((e) => e.map((key, value) => MapEntry(key, value.toString()))).toList());
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, child) {
        return Scaffold(
          backgroundColor: AppTheme.darkBackground,
          appBar: AppBar(
            backgroundColor: AppTheme.darkBackground,
            elevation: 0,
            title: Text(
              localeProvider.getString('edit_profile'),
              style: const TextStyle(color: AppTheme.textPrimary),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              TextButton(
                onPressed: _isLoading ? null : _saveProfile,
                child: Text(
                  localeProvider.getString('save'),
                  style: TextStyle(
                    color: _isLoading 
                        ? AppTheme.textSecondary 
                        : Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Profile Banner
                _buildProfileBanner(context),
                const SizedBox(height: 16),
                // Profile Picture
                _buildProfilePicture(context),
                const SizedBox(height: 32),

                // Form Fields
                _buildTextField(
                  controller: _usernameController,
                  label: localeProvider.getString("username"),
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _emailController,
                  label: localeProvider.getString("email"),
                  icon: Icons.email_outlined,
                  enabled: false, // Email typically can\"t be changed
                  helperText: localeProvider.getString("email_cannot_be_changed"),
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _bioController,
                  label: localeProvider.getString("bio"),
                  icon: Icons.description_outlined,
                  maxLines: 3,
                ),
                const SizedBox(height: 32),

                // Social Links
                _buildSocialLinksSection(localeProvider),
                const SizedBox(height: 32),

                // Additional Info
                _buildInfoCard(localeProvider),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfilePicture(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    final username = user?.username ?? 'U';
    final profileImage = user?.profileImage;

    ImageProvider? imageProvider;
    if (_selectedProfileImage != null) {
      imageProvider = kIsWeb
          ? NetworkImage(_selectedProfileImage!.path)
          : FileImage(File(_selectedProfileImage!.path));
    } else if (profileImage != null && profileImage.isNotEmpty) {
      imageProvider = NetworkImage(profileImage);
    }

    return Stack(
      children: [
        CircleAvatar(
          radius: 60,
          backgroundColor: Theme.of(context).colorScheme.primary,
          backgroundImage: imageProvider,
          child: imageProvider == null
              ? Text(
                  username.isNotEmpty ? username[0].toUpperCase() : "U",
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                )
              : null,
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.darkBackground,
                width: 2,
              ),
            ),
            child: IconButton(
              icon: Icon(
                Icons.camera_alt,
                color: Theme.of(context).colorScheme.primary,
                size: 18,
              ),
              onPressed: () {
                _showImagePickerOptions(context, ImageType.profile);
              },
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileBanner(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    final bannerImage = user?.bannerImage;

    ImageProvider? imageProvider;
    if (_selectedBannerImage != null) {
      imageProvider = kIsWeb
          ? NetworkImage(_selectedBannerImage!.path)
          : FileImage(File(_selectedBannerImage!.path));
    } else if (bannerImage != null && bannerImage.isNotEmpty) {
      imageProvider = NetworkImage(bannerImage);
    }

    return GestureDetector(
      onTap: () => _showImagePickerOptions(context, ImageType.banner),
      child: Container(
        height: 150,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(12),
          image: imageProvider != null
              ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
              : null,
        ),
        child: imageProvider == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo, color: Theme.of(context).colorScheme.primary, size: 40),
                  const SizedBox(height: 8),
                  Text(
                    Provider.of<LocaleProvider>(context, listen: false).getString("add_banner"),
                    style: TextStyle(color: Theme.of(context).colorScheme.primary),
                  ),
                ],
              )
            : null,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    String? helperText,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged, // Add this line
      enabled: enabled,
      maxLines: maxLines,
      style: TextStyle(
        color: enabled ? AppTheme.textPrimary : AppTheme.textSecondary,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textSecondary),
        helperText: helperText,
        helperStyle: const TextStyle(
          color: AppTheme.textTertiary,
          fontSize: 12,
        ),
        prefixIcon: Icon(icon, color: AppTheme.textSecondary),
        filled: true,
        fillColor: AppTheme.cardBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildInfoCard(LocaleProvider localeProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                localeProvider.getString("profile_info"),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            localeProvider.getString("profile_info_description"),
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialLinksSection(LocaleProvider localeProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localeProvider.getString("social_links"),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
          ..._socialLinks.asMap().entries.map((entry) {
            final index = entry.key;
            final link = entry.value;
            return _SocialLinkRow(
              key: ValueKey('social_link_$index'),
              link: link,
              onRemove: () {
                setState(() {
                  _socialLinks.removeAt(index);
                });
              },
              onChanged: (updatedLink) {
                _socialLinks[index] = updatedLink;
              },
            );
          }),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _addSocialLink,
              icon: Icon(Icons.add, color: Theme.of(context).colorScheme.primary),
              label: Text(
                localeProvider.getString("add_social_link"),
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addSocialLink() {
    setState(() {
      _socialLinks.add({"platform": "", "url": ""}); // Default empty link
    });
  }

  void _showImagePickerOptions(BuildContext context, ImageType imageType) {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              decoration: BoxDecoration(
                color: AppTheme.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera, color: AppTheme.textPrimary),
              title: Text(
                localeProvider.getString("take_photo"),
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera, imageType);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppTheme.textPrimary),
              title: Text(
                localeProvider.getString("choose_from_gallery"),
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery, imageType);
              },
            ),
            if ((imageType == ImageType.profile && _selectedProfileImage != null) ||
                (imageType == ImageType.banner && _selectedBannerImage != null))
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
                title: Text(
                  localeProvider.getString("remove_photo"),
                  style: const TextStyle(color: AppTheme.errorColor),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    if (imageType == ImageType.profile) {
                      _selectedProfileImage = null;
                    } else {
                      _selectedBannerImage = null;
                    }
                  });
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source, ImageType imageType) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          if (imageType == ImageType.profile) {
            _selectedProfileImage = pickedFile;
          } else {
            _selectedBannerImage = pickedFile;
          }
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to pick image")),
      );
    }
  }

  void _saveProfile() async {
    final username = _usernameController.text.trim();
    final bio = _bioController.text.trim();
    
    if (username.isEmpty) {
      final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localeProvider.getString("username_required")),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
      
      final user = authProvider.currentUser;
      final List<Map<String, dynamic>> updatedSocialLinks = _socialLinks
          .where((link) => link["url"]?.isNotEmpty == true)
          .map<Map<String, dynamic>>((link) => {
                "platform": link["platform"] ?? "",
                "url": link["url"] ?? "",
              })
          .toList();

      if (user?.socialLinks != null) {
        final privacyEntry = user!.socialLinks!.firstWhere(
          (l) => l['type'] == 'privacy_settings',
          orElse: () => <String, dynamic>{},
        );
        if (privacyEntry.isNotEmpty) {
          updatedSocialLinks.add(privacyEntry);
        }
      }

      // Update profile in Supabase
      final profileFile = _selectedProfileImage != null && !kIsWeb
          ? File(_selectedProfileImage!.path)
          : null;
      final bannerFile = _selectedBannerImage != null && !kIsWeb
          ? File(_selectedBannerImage!.path)
          : null;
      await authProvider.updateProfile(
        username: username,
        bio: bio,
        socialLinks: updatedSocialLinks,
        profileImageFile: profileFile,
        bannerImageFile: bannerFile,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localeProvider.getString("profile_updated")),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString()}"),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

enum ImageType {
  profile,
  banner,
}

class _SocialLinkRow extends StatefulWidget {
  final Map<String, String> link;
  final VoidCallback onRemove;
  final ValueChanged<Map<String, String>> onChanged;

  const _SocialLinkRow({
    super.key,
    required this.link,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  State<_SocialLinkRow> createState() => _SocialLinkRowState();
}

class _SocialLinkRowState extends State<_SocialLinkRow> {
  late final TextEditingController _platformController;
  late final TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    _platformController = TextEditingController(text: widget.link["platform"]);
    _urlController = TextEditingController(text: widget.link["url"]);
  }

  @override
  void dispose() {
    _platformController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              controller: _platformController,
              onChanged: (value) {
                widget.link["platform"] = value;
                widget.onChanged(widget.link);
              },
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: "Платформа (напр. Twitch)",
                labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                prefixIcon: Icon(Icons.label_outline, color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.cardBackground,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: TextField(
              controller: _urlController,
              onChanged: (value) {
                widget.link["url"] = value;
                widget.onChanged(widget.link);
              },
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: "Ссылка (URL)",
                labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                prefixIcon: Icon(Icons.link, color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.cardBackground,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: AppTheme.errorColor),
            onPressed: widget.onRemove,
          ),
        ],
      ),
    );
  }
}
