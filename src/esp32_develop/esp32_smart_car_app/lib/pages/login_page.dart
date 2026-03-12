import 'package:flutter/material.dart';
import 'main_screen.dart';
import '../l10n/app_localizations.dart';
import '../utils/ui_utils.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameFocusNode = FocusNode();
  bool _isLogin = true;
  bool _obscurePassword = true;
  bool _isLoading = false;

  // Mock history account data
  final List<Map<String, String>> _historyAccounts = [
    {"username": "admin", "password": "123456"},
    {"username": "guest", "password": "guest123"},
  ];

  @override
  void initState() {
    super.initState();
    _usernameFocusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _usernameFocusNode.removeListener(_onFocusChange);
    _usernameFocusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_usernameFocusNode.hasFocus && _isLogin) {
      _showAccountSelection();
    }
  }

  void _showAccountSelection() {
    if (_historyAccounts.isEmpty) return;
    
    UIUtils.showAppBottomSheet(
      context: context,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white, // Light background
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Saved Accounts", 
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF333333), letterSpacing: 0.5)
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  ..._historyAccounts.asMap().entries.map((entry) {
                    final index = entry.key;
                    final account = entry.value;
                    return Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.person_rounded, color: Theme.of(context).colorScheme.primary),
                          ),
                          title: Text(account["username"]!, style: const TextStyle(color: Color(0xFF333333), fontWeight: FontWeight.bold)),
                          subtitle: const Text("Saved Password", style: TextStyle(color: Color(0xFF999999), fontSize: 12)),
                          onTap: () async {
                            _onAccountSelected(account);
                            // Close the bottom sheet first
                            Navigator.of(context).pop();
                            // Unfocus to prevent keyboard/focus issues during transition
                            FocusScope.of(context).unfocus();
                            // Wait for bottom sheet closing animation to complete
                            await Future.delayed(const Duration(milliseconds: 350));
                            if (context.mounted) _submit();
                          },
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                        if (index < _historyAccounts.length - 1)
                          Divider(height: 1, color: Colors.black.withValues(alpha: 0.05), indent: 20, endIndent: 20),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onAccountSelected(Map<String, String> account) {
    setState(() {
      _usernameController.text = account["username"]!;
      _passwordController.text = account["password"]!;
    });
  }

  void _submit() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      final username = _usernameController.text.trim();
      final password = _passwordController.text;

      // Simulate network delay for "Pro" feel
      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted) return;
      if (_isLogin) {
        // Validate fixed accounts
        bool isValid = false;
        if (username == 'admin' && password == '123456') isValid = true;
        if (username == 'guest' && password == 'guest123') isValid = true;

        setState(() => _isLoading = false);

        if (isValid) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainScreen()),
          );
        } else {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: Text(l10n.invalidCredentials),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
        }
      } else {
        setState(() => _isLoading = false);
        // Registration not handled in demo version
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(l10n.regDisabled),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Hero(
                  tag: 'app_icon',
                  child: Center(
                    child: Container(
                      width: 120,
                      height: 120,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.15),
                            blurRadius: 30,
                            spreadRadius: 2,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/icon.png', 
                          fit: BoxFit.contain, // Show full logo
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  _isLogin ? l10n.login : l10n.register,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 48),
                _buildInputCard([
                  TextFormField(
                    controller: _usernameController,
                    focusNode: _usernameFocusNode,
                    style: const TextStyle(color: Color(0xFF333333)),
                    decoration: InputDecoration(
                      labelText: l10n.username,
                      prefixIcon: Icon(Icons.person_rounded, color: primaryColor),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return l10n.enterUsername;
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: Color(0xFF333333)),
                    decoration: InputDecoration(
                      labelText: l10n.password,
                      prefixIcon: Icon(Icons.lock_rounded, color: primaryColor),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          color: const Color(0xFF999999),
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.length < 6) return l10n.enterPassword;
                      return null;
                    },
                  ),
                ]),
                const SizedBox(height: 48),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                    shadowColor: primaryColor.withValues(alpha: 0.4),
                  ),
                  child: _isLoading 
                    ? const SizedBox(
                        height: 24, 
                        width: 24, 
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)
                      )
                    : Text(
                        (_isLogin ? l10n.login : l10n.register).toUpperCase(),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                      ),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => setState(() => _isLogin = !_isLogin),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF666666)),
                  child: Text(_isLogin ? l10n.dontHaveAccount : l10n.alreadyHaveAccount),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputCard(List<Widget> children) {
    return Column(children: children);
  }
}
