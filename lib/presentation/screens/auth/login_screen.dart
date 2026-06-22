import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../../core/theme/app_theme.dart';
import '../../../data/services/auth_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import 'register_screen.dart';
import '../home/home_screen.dart';
import '../../../data/services/session_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
          'message': 'Ваш одноразовый код подтверждения для входа в аккаунт: $code. Не сообщайте его никому.',
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
      return errorMessage ?? 'Не удалось отправить код подтверждения. Статус: ${response.statusCode}';
    } catch (e) {
      debugPrint('Error sending 2FA login email: $e');
      return 'Ошибка сети: $e';
    }
  }

  Future<void> _show2faVerificationSheet({
    required String email,
    required String target2faEmail,
    required VoidCallback onSuccess,
    required VoidCallback onFailure,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final emailKey = email.toLowerCase();
    final backupCodes = prefs.getStringList('2fa_backup_codes_$emailKey') ?? 
                        prefs.getStringList('2fa_backup_codes') ?? [];

    String generatedCode = (100000 + Random().nextInt(900000)).toString();
    bool sending = true;
    bool codeSent = false;
    String errorMessage = '';
    bool verified = false;

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardBackground,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final codeController = TextEditingController();

        return StatefulBuilder(
          builder: (context, setModalState) {
            if (!codeSent && sending) {
              codeSent = true;
              _send2faEmail(target2faEmail, generatedCode).then((error) {
                if (mounted) {
                  setModalState(() {
                    sending = false;
                    if (error != null) {
                      errorMessage = error;
                      debugPrint('2FA CODE GENERATED: $generatedCode');
                    }
                  });
                }
              }).catchError((e) {
                if (mounted) {
                  setModalState(() {
                    sending = false;
                    errorMessage = 'Ошибка сети. Будет использован резервный код.';
                    debugPrint('2FA CODE GENERATED (Error case): $generatedCode');
                  });
                }
              });
            }

            return Padding(
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
                    const Text(
                      'Двухфакторная проверка',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (sending) ...[
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Column(
                            children: [
                              CircularProgressIndicator(color: AppTheme.primaryGreen),
                              SizedBox(height: 16),
                              Text(
                                'Отправка кода на почту...',
                                style: TextStyle(color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      Text(
                        'Код подтверждения был отправлен на почту $target2faEmail.',
                        style: const TextStyle(color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Введите 6-значный код из письма или один из ваших резервных кодов.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: codeController,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        keyboardType: TextInputType.text,
                        decoration: InputDecoration(
                          labelText: 'Код подтверждения / Резервный код',
                          labelStyle: const TextStyle(color: AppTheme.textSecondary),
                          filled: true,
                          fillColor: AppTheme.surfaceColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      if (errorMessage.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          errorMessage,
                          style: const TextStyle(color: AppTheme.errorColor, fontSize: 12),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text(
                              'Отмена',
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.black,
                            ),
                            onPressed: () {
                              final entered = codeController.text.trim();
                              final isCodeMatch = entered == generatedCode;
                              final isBackupMatch = backupCodes.contains(entered);

                              if (isCodeMatch || isBackupMatch) {
                                verified = true;
                                if (isBackupMatch) {
                                  backupCodes.remove(entered);
                                  prefs.setStringList('2fa_backup_codes_$emailKey', backupCodes);
                                  prefs.setStringList('2fa_backup_codes', backupCodes);
                                }
                                Navigator.pop(context);
                              } else {
                                setModalState(() {
                                  errorMessage = 'Неверный код подтверждения или резервный код';
                                });
                              }
                            },
                            child: const Text('Подтвердить'),
                          ),
                        ],
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

    if (verified) {
      onSuccess();
    } else {
      onFailure();
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final email = _emailController.text.trim();
      final result = await authProvider.login(
        email: email,
        password: _passwordController.text,
      );

      if (result.success && mounted) {
        // Check if 2FA is enabled for this email
        final prefs = await SharedPreferences.getInstance();
        final emailKey = email.toLowerCase();
        final is2faEnabled = prefs.getBool('2fa_enabled_$emailKey') ?? prefs.getBool('2fa_enabled') ?? false;
        final target2faEmail = prefs.getString('2fa_email_$emailKey') ?? prefs.getString('2fa_email') ?? email;

        if (is2faEnabled) {
          // Temporarily stop loading spinner so user can interact
          setState(() {
            _isLoading = false;
          });
          
          bool verified = false;
          await _show2faVerificationSheet(
            email: email,
            target2faEmail: target2faEmail,
            onSuccess: () {
              verified = true;
            },
            onFailure: () {
              verified = false;
            },
          );

          if (verified) {
            await SessionService.instance.registerNewSession(email);
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
            }
          } else {
            // Logout user from auth provider
            await authProvider.logout();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Вход отменен или неверный код 2FA'),
                  backgroundColor: AppTheme.errorColor,
                ),
              );
            }
          }
        } else {
          await SessionService.instance.registerNewSession(email);
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          }
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при входе: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final brightness = baseTheme.brightness;
    final textScale = baseTheme.textTheme.bodyLarge != null
        ? (baseTheme.textTheme.bodyLarge!.fontSize ?? 16) / 16
        : 1.0;
    return Theme(
      data: AppTheme.getThemeData(brightness, AppTheme.primaryGreen, textScale),
      child: Builder(
        builder: (context) => _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo and Title
                        Icon(
                      Icons.music_note,
                      size: 80,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Welcome Back',
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onBackground,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to continue listening',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),

                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        hintText: 'Enter your email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'Enter your password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),

                    // Login Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                              ),
                            )
                          : const Text(
                              'Sign In',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    const SizedBox(height: 24),

                    // Divider
                    Row(
                      children: [
                        Expanded(child: Divider(color: Theme.of(context).dividerColor)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'OR',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).textTheme.bodySmall?.color,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Theme.of(context).dividerColor)),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Register Button
                    OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const RegisterScreen()),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Theme.of(context).colorScheme.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);
}
}
