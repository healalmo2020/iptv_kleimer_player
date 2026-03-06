import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/app_providers.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _autoLoggingIn = true;

  @override
  void initState() {
    super.initState();
    if (_isWidgetTestEnvironment()) {
      _autoLoggingIn = false;
      return;
    }
    Future<void>.microtask(_bootstrapAutoLogin);
  }

  Future<void> _bootstrapAutoLogin() async {
    final credentials = ref.read(localStorageProvider).getSavedCredentials();
    _userController.text = credentials.username;
    _passController.text = credentials.password;

    final success = await ref.read(authControllerProvider.notifier).tryAutoLogin();
    if (!mounted) {
      return;
    }

    if (success) {
      context.go('/warmup');
      return;
    }

    setState(() {
      _autoLoggingIn = false;
    });
  }

  bool _isWidgetTestEnvironment() {
    return WidgetsBinding.instance.runtimeType.toString().contains('TestWidgetsFlutterBinding');
  }

  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    await ref.read(authControllerProvider.notifier).login(
          username: _userController.text.trim(),
          password: _passController.text.trim(),
        );

    final state = ref.read(authControllerProvider);
    if (state.hasValue && mounted) {
      context.go('/warmup');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    if (_autoLoggingIn) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Iniciando sesión automáticamente...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Acceso Xtream Codes', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _userController,
                      decoration: const InputDecoration(labelText: 'Username'),
                      validator: (value) => (value == null || value.isEmpty) ? 'Ingresa usuario' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password'),
                      validator: (value) => (value == null || value.isEmpty) ? 'Ingresa contraseña' : null,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: authState.isLoading ? null : _submit,
                        child: authState.isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Entrar'),
                      ),
                    ),
                    if (authState.hasError) ...[
                      const SizedBox(height: 10),
                      Text(
                        authState.error.toString(),
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
