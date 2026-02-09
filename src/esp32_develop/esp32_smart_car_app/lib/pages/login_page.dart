import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'main_screen.dart';
import '../l10n/app_localizations.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  bool _obscurePassword = true;

  // Mock history account data
  final List<Map<String, String>> _historyAccounts = [
    {"username": "admin", "password": "123456"},
    {"username": "guest", "password": "guest123"},
  ];

  void _onAccountSelected(Map<String, String> account) {
    setState(() {
      _usernameController.text = account["username"]!;
      _passwordController.text = account["password"]!;
    });
  }

  void _submit() {
    final l10n = AppLocalizations.of(context)!;
    if (_formKey.currentState!.validate()) {
      final username = _usernameController.text.trim();
      final password = _passwordController.text;

      if (_isLogin) {
        // Validate fixed accounts
        bool isValid = false;
        if (username == 'admin' && password == '123456') isValid = true;
        if (username == 'guest' && password == 'guest123') isValid = true;

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
                backgroundColor: Colors.red,
              ),
            );
        }
      } else {
        // Registration not handled in demo version
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(content: Text(l10n.regDisabled)),
          );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset('assets/icon.png', height: 80, width: 80),
                const SizedBox(height: 16),
                Text(
                  _isLogin ? l10n.login : l10n.register,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.orbitron(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 40),
                Stack(
                  alignment: Alignment.centerRight,
                  children: [
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: l10n.username,
                        prefixIcon: const Icon(Icons.person, color: Color(0xFF00F0FF)),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return l10n.enterUsername;
                        return null;
                      },
                    ),
                    if (_isLogin)
                      PopupMenuButton<Map<String, String>>(
                        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF00F0FF)),
                        onSelected: _onAccountSelected,
                        itemBuilder: (context) => _historyAccounts.map((account) {
                          return PopupMenuItem(
                            value: account,
                            child: Row(
                              children: [
                                const Icon(Icons.history, size: 18, color: Colors.grey),
                                const SizedBox(width: 10),
                                Text(account["username"]!),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: l10n.password,
                    prefixIcon: const Icon(Icons.lock, color: Color(0xFF00F0FF)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: const Color(0xFF00F0FF),
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
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _submit,
                  child: Text(_isLogin ? l10n.login : l10n.register),
                ),
                TextButton(
                  onPressed: () => setState(() => _isLogin = !_isLogin),
                  child: Text(_isLogin ? l10n.dontHaveAccount : l10n.alreadyHaveAccount),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
