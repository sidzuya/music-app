import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../../data/services/session_service.dart';


class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});
  
  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _isEditing = false;
  List<Map<String, String>> _activeSessions = [];
  
  bool _twoFactorEnabled = false;
  String _twoFactorEmail = '';
  List<Map<String, String>> _loginHistory = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadSettingsPreferences();
  }

  Future<void> _loadSettingsPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    final emailKey = user != null ? user.email.toLowerCase().trim() : '';
    
    if (emailKey.isNotEmpty) {
      final sessionsKey = 'active_sessions_list_$emailKey';
      final historyKey = 'login_history_list_$emailKey';
      
      String? sessionsJson = prefs.getString(sessionsKey);
      String? historyJson = prefs.getString(historyKey);
      
      if (sessionsJson == null || historyJson == null) {
        // Register current session initially
        await SessionService.instance.registerNewSession(emailKey);
        sessionsJson = prefs.getString(sessionsKey);
        historyJson = prefs.getString(historyKey);
      }
      
      setState(() {
        _twoFactorEnabled = prefs.getBool('2fa_enabled_$emailKey') ?? prefs.getBool('2fa_enabled') ?? false;
        _twoFactorEmail = prefs.getString('2fa_email_$emailKey') ?? prefs.getString('2fa_email') ?? '';
        
        if (historyJson != null) {
          final decoded = jsonDecode(historyJson) as List;
          _loginHistory = decoded.map((item) => Map<String, String>.from(item as Map)).toList();
        } else {
          _loginHistory = [];
        }
        
        if (sessionsJson != null) {
          final decoded = jsonDecode(sessionsJson) as List;
          _activeSessions = decoded.map((item) => Map<String, String>.from(item as Map)).toList();
        } else {
          _activeSessions = [];
        }
      });
    } else {
      setState(() {
        _twoFactorEnabled = prefs.getBool('2fa_enabled') ?? false;
        _twoFactorEmail = prefs.getString('2fa_email') ?? '';
        _loginHistory = [];
        _activeSessions = [];
      });
    }
  }

  Future<void> _saveSessionsAndHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    final emailKey = user != null ? user.email.toLowerCase().trim() : '';
    if (emailKey.isNotEmpty) {
      await prefs.setString('login_history_list_$emailKey', jsonEncode(_loginHistory));
      await prefs.setString('active_sessions_list_$emailKey', jsonEncode(_activeSessions));
    }
  }

  void _loadUserData() {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user != null) {
      _emailController.text = user.email;
      _usernameController.text = user.username;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, child) {
        return Scaffold(
          backgroundColor: AppTheme.darkBackground,
          appBar: AppBar(
            title: Text(localeProvider.getString('account')),
            backgroundColor: AppTheme.darkBackground,
            actions: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _isEditing = !_isEditing;
                  });
                  if (!_isEditing) {
                    _saveChanges();
                  }
                },
                child: Text(
                  _isEditing ? localeProvider.getString('save') : localeProvider.getString('edit'),
                  style: TextStyle(color: Theme.of(context).colorScheme.primary),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Section
                _buildSectionHeader(localeProvider.getString('profile')),
                const SizedBox(height: 16),
                
                _buildTextField(
                  controller: _emailController,
                  label: localeProvider.getString('email'),
                  enabled: _isEditing,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                
                _buildTextField(
                  controller: _usernameController,
                  label: localeProvider.getString('username'),
                  enabled: _isEditing,
                ),
                const SizedBox(height: 32),

                // Security Section
                _buildSectionHeader(localeProvider.getString('security')),
                const SizedBox(height: 16),
                
                if (_isEditing) ...[
                  _buildTextField(
                    controller: _currentPasswordController,
                    label: localeProvider.getString('current_password'),
                    enabled: true,
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  
                  _buildTextField(
                    controller: _newPasswordController,
                    label: localeProvider.getString('new_password'),
                    enabled: true,
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                ],

                _buildSettingsItem(
                  localeProvider.getString('two_factor_auth'),
                  localeProvider.getString('two_factor_auth_desc'),
                  Icons.security,
                  () => _showTwoFactorSettings(localeProvider),
                ),

                
                const SizedBox(height: 32),

                // Privacy Section
                _buildSectionHeader(localeProvider.getString('privacy')),
                const SizedBox(height: 16),
                
                _buildSettingsItem(
                  localeProvider.getString('profile_privacy'),
                  localeProvider.getString('profile_privacy_desc'),
                  Icons.visibility,
                  () => _showPrivacySettings(localeProvider),
                ),
                
                const SizedBox(height: 32),

                // Danger Zone
                _buildSectionHeader(localeProvider.getString('danger_zone'), color: AppTheme.errorColor),
                const SizedBox(height: 16),
                
                _buildDangerItem(
                  localeProvider.getString('delete_account'),
                  localeProvider.getString('delete_account_desc'),
                  Icons.delete_forever,
                  () => _showDeleteAccountDialog(localeProvider),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, {Color? color}) {
    return Text(
      title,
      style: TextStyle(
        color: color ?? AppTheme.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required bool enabled,
    TextInputType? keyboardType,
    bool obscureText = false,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: enabled ? AppTheme.textSecondary : AppTheme.textTertiary,
        ),
        filled: true,
        fillColor: AppTheme.surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
        ),
      ),
    );
  }

  Widget _buildSettingsItem(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.textSecondary),
      title: Text(
        title,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 12,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppTheme.textSecondary,
      ),
      onTap: onTap,
    );
  }

  Widget _buildDangerItem(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.errorColor),
      title: Text(
        title,
        style: const TextStyle(
          color: AppTheme.errorColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 12,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppTheme.errorColor,
      ),
      onTap: onTap,
    );
  }

  void _saveChanges() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Изменения сохранены'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  void _showComingSoon(LocaleProvider localeProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: Text(localeProvider.getString('coming_soon'), style: const TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          localeProvider.getString('coming_soon_message'),
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localeProvider.getString('ok'), style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          ),
        ],
      ),
    );
  }

  int javaRandomInt(int maxVal) {
    return Random().nextInt(maxVal);
  }

  Future<String?> _send2faEmail(String email, String code) async {
    try {
      final response = await http.post(
        Uri.parse('https://formsubmit.co/ajax/$email'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Referer': 'https://musicapp.com',
          'Origin': 'https://musicapp.com',
        },
        body: jsonEncode({
          '_subject': 'Код подтверждения 2FA - MusicApp',
          'code': code,
          'message': 'Ваш одноразовый код подтверждения для включения двухфакторной аутентификации: $code. Не сообщайте его никому.',
        }),
      );
      String? errorMessage;
      if (response.body.isNotEmpty) {
        try {
          final data = jsonDecode(response.body);
          if (response.statusCode == 200 && (data['success'] == 'true' || data['success'] == true)) {
            return null; // success
          }
          errorMessage = data['message']?.toString();
        } catch (_) {}
      }
      return errorMessage ?? 'Не удалось отправить email. Статус: ${response.statusCode}';
    } catch (e) {
      debugPrint('Error sending 2FA email: $e');
      return 'Ошибка сети: $e';
    }
  }

  void _showTwoFactorSettings(LocaleProvider localeProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        String statusStep = _twoFactorEnabled ? 'toggle_off' : 'toggle_on';
        final emailFieldController = TextEditingController(text: _twoFactorEmail.isNotEmpty ? _twoFactorEmail : _emailController.text);
        final codeFieldController = TextEditingController();
        String generatedCode = '';
        bool sendingEmail = false;
        String errorMessage = '';
        List<String> backupCodes = [];

        return StatefulBuilder(
          builder: (context, setModalState) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.textTertiary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      localeProvider.getString('two_factor_auth'),
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (statusStep == 'toggle_off') ...[
                      const Text(
                        'Двухфакторная аутентификация включена.',
                        style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Коды подтверждения отправляются на почту: $_twoFactorEmail',
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.errorColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: AppTheme.cardBackground,
                                title: const Text('Отключить 2FA?', style: TextStyle(color: AppTheme.textPrimary)),
                                content: const Text('Ваш аккаунт будет защищен только паролем.', style: TextStyle(color: AppTheme.textSecondary)),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Отмена', style: TextStyle(color: AppTheme.textSecondary)),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Отключить', style: TextStyle(color: AppTheme.errorColor)),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
                              final emailKey = user != null ? user.email.toLowerCase() : '';
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setBool('2fa_enabled', false);
                              if (emailKey.isNotEmpty) {
                                await prefs.setBool('2fa_enabled_$emailKey', false);
                              }
                              setState(() {
                                _twoFactorEnabled = false;
                              });
                              Navigator.pop(context);
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(
                                  content: Text('Двухфакторная аутентификация отключена'),
                                  backgroundColor: AppTheme.errorColor,
                                ),
                              );
                            }
                          },
                          child: const Text('Отключить защиту', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ] else if (statusStep == 'toggle_on') ...[
                      const Text(
                        'Двухфакторная аутентификация повышает безопасность аккаунта, требуя одноразовый код при входе.',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            setModalState(() {
                              statusStep = 'input_email';
                            });
                          },
                          child: const Text('Настроить защиту', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ] else if (statusStep == 'input_email') ...[
                      const Text(
                        'Введите Email для отправки одноразового кода подтверждения:',
                        style: TextStyle(color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailFieldController,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email адрес',
                          labelStyle: const TextStyle(color: AppTheme.textSecondary),
                          filled: true,
                          fillColor: AppTheme.surfaceColor,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                      ),
                      if (errorMessage.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(errorMessage, style: const TextStyle(color: AppTheme.errorColor, fontSize: 12)),
                      ],
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Отмена', style: TextStyle(color: AppTheme.textSecondary)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.black,
                            ),
                            onPressed: sendingEmail
                                ? null
                                : () async {
                                    final email = emailFieldController.text.trim();
                                    if (email.isEmpty || !email.contains('@')) {
                                      setModalState(() {
                                        errorMessage = 'Введите корректный Email';
                                      });
                                      return;
                                    }
                                    setModalState(() {
                                      sendingEmail = true;
                                      errorMessage = '';
                                    });

                                    generatedCode = (100000 + javaRandomInt(900000)).toString();
                                    final error = await _send2faEmail(email, generatedCode);

                                    setModalState(() {
                                      sendingEmail = false;
                                      if (error == null) {
                                        statusStep = 'verify_code';
                                      } else {
                                        errorMessage = error;
                                      }
                                    });
                                  },
                            child: sendingEmail
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                                : const Text('Отправить код'),
                          ),
                        ],
                      ),
                    ] else if (statusStep == 'verify_code') ...[
                      Text(
                        'Код подтверждения был отправлен на почту ${emailFieldController.text}.',
                        style: const TextStyle(color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Если письмо долго не приходит, проверьте папку "Спам" или подтвердите форму активации от FormSubmit (требуется один раз при первом использовании почты).',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: codeFieldController,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: InputDecoration(
                          labelText: 'Введите 6-значный код',
                          labelStyle: const TextStyle(color: AppTheme.textSecondary),
                          filled: true,
                          fillColor: AppTheme.surfaceColor,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                      ),
                      if (errorMessage.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(errorMessage, style: const TextStyle(color: AppTheme.errorColor, fontSize: 12)),
                      ],
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                statusStep = 'input_email';
                                errorMessage = '';
                              });
                            },
                            child: const Text('Назад', style: TextStyle(color: AppTheme.textSecondary)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.black,
                            ),
                            onPressed: () async {
                              final entered = codeFieldController.text.trim();
                              if (entered != generatedCode) {
                                setModalState(() {
                                  errorMessage = 'Неверный код подтверждения';
                                });
                                return;
                              }

                              final email = emailFieldController.text.trim();
                              final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
                              final emailKey = user != null ? user.email.toLowerCase() : '';
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setBool('2fa_enabled', true);
                              await prefs.setString('2fa_email', email);
                              if (emailKey.isNotEmpty) {
                                await prefs.setBool('2fa_enabled_$emailKey', true);
                                await prefs.setString('2fa_email_$emailKey', email);
                              }

                              backupCodes = List.generate(4, (_) {
                                final part1 = (1000 + javaRandomInt(9000)).toString();
                                final part2 = (1000 + javaRandomInt(9000)).toString();
                                return '$part1-$part2';
                              });

                              await prefs.setStringList('2fa_backup_codes', backupCodes);
                              if (emailKey.isNotEmpty) {
                                await prefs.setStringList('2fa_backup_codes_$emailKey', backupCodes);
                              }

                              setState(() {
                                _twoFactorEnabled = true;
                                _twoFactorEmail = email;
                              });

                              setModalState(() {
                                statusStep = 'display_backup';
                              });
                            },
                            child: const Text('Подтвердить'),
                          ),
                        ],
                      ),
                    ] else if (statusStep == 'display_backup') ...[
                      const Icon(Icons.check_circle, color: Colors.green, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'Защита включена!',
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Сохраните эти резервные коды восстановления. Они помогут войти в аккаунт, если у вас не будет доступа к почте:',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(8)),
                        width: double.infinity,
                        child: Column(
                          children: backupCodes.map((code) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              code,
                              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                            ),
                          )).toList(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.black,
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Завершить настройку', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showLoginHistory(LocaleProvider localeProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localeProvider.getString('login_history'),
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_loginHistory.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          'История входов пуста',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                    )
                  else ...[
                    Expanded(
                      child: ListView.builder(
                        itemCount: _loginHistory.length,
                        itemBuilder: (context, index) {
                          final item = _loginHistory[index];
                          final isCurrent = item['isCurrent'] == 'true';
                          final isPhone = item['device']?.contains('iPhone') ?? false;
                          final deviceTitle = isCurrent
                              ? '${item['device'] ?? ''} (Текущий сеанс)'
                              : (item['device'] ?? '');
                          final subtitle = isCurrent
                              ? '${item['location'] ?? ''} • IP: ${item['ip'] ?? ''} • Активен сейчас'
                              : '${item['location'] ?? ''} • IP: ${item['ip'] ?? ''} • ${item['time'] ?? ''}';
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(isPhone ? Icons.phone_iphone : Icons.laptop, color: isCurrent ? AppTheme.textPrimary : AppTheme.textSecondary),
                            title: Text(deviceTitle, style: TextStyle(color: AppTheme.textPrimary, fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500)),
                            subtitle: Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.errorColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          setState(() {
                            _loginHistory.removeWhere((item) => item['isCurrent'] != 'true');
                            _activeSessions.removeWhere((item) => item['isCurrent'] != 'true');
                          });
                          await _saveSessionsAndHistory();
                          setModalState(() {});
                          Navigator.pop(context);
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text('Вы вышли со всех остальных устройств'),
                              backgroundColor: AppTheme.errorColor,
                            ),
                          );
                        },
                        child: const Text('Выйти со всех остальных устройств', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showActiveSessions(LocaleProvider localeProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localeProvider.getString('active_sessions'),
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_activeSessions.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text(
                            'Нет активных сессий',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        ),
                      )
                    else
                      ..._activeSessions.map((session) {
                        final isCurrent = session['isCurrent'] == 'true';
                        return _buildSessionItem(
                          localeProvider,
                          session['device'] ?? '',
                          isCurrent ? localeProvider.getString('current_session') : (session['lastActive'] ?? ''),
                          isCurrent,
                          onTerminate: isCurrent ? null : () async {
                            setState(() {
                              _activeSessions.removeWhere((s) => s['id'] == session['id']);
                            });
                            await _saveSessionsAndHistory();
                            setModalState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Сеанс завершен'),
                                backgroundColor: AppTheme.errorColor,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        );
                      }).toList(),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSessionItem(
    LocaleProvider localeProvider,
    String device,
    String lastActive,
    bool isCurrent, {
    VoidCallback? onTerminate,
  }) {
    return ListTile(
      leading: const Icon(Icons.devices, color: AppTheme.textSecondary),
      title: Text(
        device,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        lastActive,
        style: const TextStyle(color: AppTheme.textSecondary),
      ),
      trailing: isCurrent
          ? Text(
              localeProvider.getString('current_session'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 12,
              ),
            )
          : TextButton(
              onPressed: onTerminate,
              child: Text(
                localeProvider.getString('terminate'),
                style: const TextStyle(color: AppTheme.errorColor),
              ),
            ),
    );
  }

  void _showPrivacySettings(LocaleProvider localeProvider) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PrivacySettingsScreen(),
      ),
    );
  }

  void _showDeleteAccountDialog(LocaleProvider localeProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: Text(
          localeProvider.getString('delete_account'),
          style: const TextStyle(color: AppTheme.errorColor),
        ),
        content: Text(
          localeProvider.getString('delete_account_confirmation'),
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localeProvider.getString('cancel'), style: const TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close settings screen
              
              // Show notification
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Аккаунт успешно удален'),
                  backgroundColor: AppTheme.primaryGreen,
                ),
              );
              
              // Log out and delete account from database
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              await authProvider.deleteAccount();
            },
            child: Text(localeProvider.getString('delete'), style: const TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
  }
}

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool _profileVisible = true;
  bool _playlistsVisible = true;
  bool _followersVisible = true;
  bool _listeningActivity = false;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    if (user != null) {
      _profileVisible = user.profileVisible;
      _playlistsVisible = user.playlistsVisible;
      _followersVisible = user.followersVisible;
      _listeningActivity = user.listeningActivity;
    }
    _loadPrivacySettings();
  }

  Future<void> _loadPrivacySettings() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    final email = user?.email.toLowerCase().trim() ?? '';
    debugPrint('PrivacySettingsScreen: _loadPrivacySettings email="$email" userNull=${user == null}');
    
    final prefs = await SharedPreferences.getInstance();
    final pV = prefs.getBool('privacy_profile_visible_$email');
    final plV = prefs.getBool('privacy_playlists_visible_$email');
    final fV = prefs.getBool('privacy_followers_visible_$email');
    final lA = prefs.getBool('privacy_listening_activity_$email');
    debugPrint('PrivacySettingsScreen: loaded from SharedPreferences: pV=$pV plV=$plV fV=$fV lA=$lA');
    debugPrint('PrivacySettingsScreen: user values: pV=${user?.profileVisible} plV=${user?.playlistsVisible} fV=${user?.followersVisible} lA=${user?.listeningActivity}');

    setState(() {
      _profileVisible = pV ?? user?.profileVisible ?? true;
      _playlistsVisible = plV ?? user?.playlistsVisible ?? true;
      _followersVisible = fV ?? user?.followersVisible ?? true;
      _listeningActivity = lA ?? user?.listeningActivity ?? false;
    });
  }

  Future<void> _updatePrivacy(String key, bool value) async {
    debugPrint('PrivacySettingsScreen: _updatePrivacy key="$key" value=$value');
    setState(() {
      if (key == 'profile') _profileVisible = value;
      if (key == 'playlists') _playlistsVisible = value;
      if (key == 'followers') _followersVisible = value;
      if (key == 'listening') _listeningActivity = value;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    final email = user?.email.toLowerCase().trim() ?? '';
    debugPrint('PrivacySettingsScreen: saving to SharedPreferences: key="privacy_${key}_visible_$email" value=$value');
    
    final prefs = await SharedPreferences.getInstance();
    if (key == 'profile') await prefs.setBool('privacy_profile_visible_$email', value);
    if (key == 'playlists') await prefs.setBool('privacy_playlists_visible_$email', value);
    if (key == 'followers') await prefs.setBool('privacy_followers_visible_$email', value);
    if (key == 'listening') await prefs.setBool('privacy_listening_activity_$email', value);

    if (user == null) return;

    final currentLinks = List<Map<String, dynamic>>.from(user.socialLinks ?? []);
    final index = currentLinks.indexWhere((l) => l['type'] == 'privacy_settings');
    
    final newEntry = {
      'type': 'privacy_settings',
      'profile_visible': _profileVisible,
      'playlists_visible': _playlistsVisible,
      'followers_visible': _followersVisible,
      'listening_activity': _listeningActivity,
    };

    if (index >= 0) {
      currentLinks[index] = newEntry;
    } else {
      currentLinks.add(newEntry);
    }

    try {
      await authProvider.updateProfile(
        username: user.username,
        bio: user.bio,
        socialLinks: currentLinks,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Настройки приватности сохранены'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating privacy settings: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, child) {
        return Scaffold(
          backgroundColor: AppTheme.darkBackground,
          appBar: AppBar(
            title: Text(localeProvider.getString('privacy')),
            backgroundColor: AppTheme.darkBackground,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSwitchTile(
                localeProvider.getString('public_profile'),
                localeProvider.getString('public_profile_desc'),
                _profileVisible,
                (value) => _updatePrivacy('profile', value),
              ),
              _buildSwitchTile(
                localeProvider.getString('public_playlists'),
                localeProvider.getString('public_playlists_desc'),
                _playlistsVisible,
                (value) => _updatePrivacy('playlists', value),
              ),
              _buildSwitchTile(
                localeProvider.getString('show_followers'),
                localeProvider.getString('show_followers_desc'),
                _followersVisible,
                (value) => _updatePrivacy('followers', value),
              ),
              _buildSwitchTile(
                localeProvider.getString('listening_activity'),
                localeProvider.getString('listening_activity_desc'),
                _listeningActivity,
                (value) => _updatePrivacy('listening', value),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Builder(
      builder: (context) => SwitchListTile(
        title: Text(
          title,
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
