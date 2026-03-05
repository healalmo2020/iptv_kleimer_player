import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/local_storage_service.dart';
import '../providers/parental_provider.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.watch(playerEngineProvider);
    final canUseVlc = !kIsWeb && defaultTargetPlatform != TargetPlatform.linux;
    final parental = ref.watch(parentalProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }
            context.go('/home');
          },
        ),
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Reproductor preferido',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          RadioGroup<PlayerEngine>(
            groupValue: engine,
            onChanged: (value) {
              if (value != null) {
                ref.read(playerEngineProvider.notifier).setEngine(value);
              }
            },
            child: Column(
              children: [
                if (canUseVlc)
                  const RadioListTile<PlayerEngine>(
                    value: PlayerEngine.vlc,
                    title: Text('VLC Player'),
                  ),
                const RadioListTile<PlayerEngine>(
                  value: PlayerEngine.mediaKit,
                  title: Text('Media Kit'),
                ),
              ],
            ),
          ),
          if (!canUseVlc)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'En Linux se utiliza Media Kit para mayor estabilidad.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          else
            const SizedBox(height: 16),
          Text(
            'Control parental',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SwitchListTile(
            value: parental.enabled,
            title: const Text('Habilitar control parental'),
            onChanged: (value) =>
                ref.read(parentalProvider.notifier).setEnabled(value),
          ),
          ListTile(
            title: const Text('Configurar PIN parental'),
            subtitle: const Text('PIN numérico de 4 dígitos'),
            trailing: const Icon(Icons.lock_outline),
            onTap: () async {
              final pin = await _showPinDialog(context);
              if (pin != null) {
                await ref.read(parentalProvider.notifier).setPin(pin);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<String?> _showPinDialog(BuildContext context) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configurar PIN'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'PIN (4 dígitos)'),
            validator: (value) {
              if (value == null || value.length != 4) {
                return 'Ingresa 4 dígitos';
              }
              final isNumeric = int.tryParse(value) != null;
              return isNumeric ? null : 'Solo números';
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(controller.text);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    controller.dispose();
    return result;
  }
}
