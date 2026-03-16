import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/player_engine.dart';
import '../../services/local_storage_service.dart';
import '../providers/auth_provider.dart';
import '../providers/parental_provider.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.watch(playerEngineProvider);
    final bufferProfile = ref.watch(playerBufferProfileProvider);
    final canUseVlc = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    final parental = ref.watch(parentalProvider);
    final session = ref.watch(authControllerProvider).valueOrNull;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF081212), Color(0xFF0A1616)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              _SettingsHeader(onBack: () => context.go('/home')),
              const SizedBox(height: 14),
              _ProfileMatrixCard(
                username: session?.username ?? 'Guest Node',
                status: session?.account.status ?? 'offline',
                onOpenProfile: () => context.go('/profile'),
              ),
              const SizedBox(height: 14),
              _SettingsPanel(
                title: 'Playback Core',
                subtitle:
                    'Tune playback engine, subtitle behavior and media pipeline.',
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.tune_rounded, color: Color(0xFF0DF2F2)),
                        const SizedBox(width: 8),
                        Text(
                          'Preferred player',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
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
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'This platform uses Media Kit for better stability.',
                          style: TextStyle(color: Color(0xFF86A4A4), fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(Icons.network_check_rounded,
                            color: Color(0xFF0DF2F2)),
                        const SizedBox(width: 8),
                        Text(
                          'Buffer profile',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    RadioGroup<PlayerBufferProfile>(
                      groupValue: bufferProfile,
                      onChanged: (value) {
                        if (value != null) {
                          ref
                              .read(playerBufferProfileProvider.notifier)
                              .setProfile(value);
                        }
                      },
                      child: const Column(
                        children: [
                          RadioListTile<PlayerBufferProfile>(
                            value: PlayerBufferProfile.fast,
                            title: Text('Fast (low latency)'),
                            subtitle: Text(
                              'Starts quicker, may buffer more on weak internet.',
                            ),
                          ),
                          RadioListTile<PlayerBufferProfile>(
                            value: PlayerBufferProfile.balanced,
                            title: Text('Balanced (recommended)'),
                            subtitle: Text(
                              'Best overall mix for normal and unstable networks.',
                            ),
                          ),
                          RadioListTile<PlayerBufferProfile>(
                            value: PlayerBufferProfile.stable,
                            title: Text('Stable (high buffer)'),
                            subtitle: Text(
                              'More startup delay, fewer interruptions.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _SettingsPanel(
                title: 'Security Grid',
                subtitle:
                    'Parental lock and profile protection for restricted content.',
                child: Column(
                  children: [
                    SwitchListTile(
                      value: parental.enabled,
                      title: const Text('Enable parental control'),
                      subtitle: const Text('Block adult labels and restricted titles'),
                      onChanged: (value) =>
                          ref.read(parentalProvider.notifier).setEnabled(value),
                    ),
                    ListTile(
                      title: const Text('Configure parental PIN'),
                      subtitle: const Text('4 digit numeric access code'),
                      trailing: const Icon(Icons.lock_outline_rounded),
                      onTap: () async {
                        final pin = await _showPinDialog(context);
                        if (pin != null) {
                          await ref.read(parentalProvider.notifier).setPin(pin);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const _TelemetryPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _showPinDialog(BuildContext context) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configure PIN'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'PIN (4 digits)'),
            validator: (value) {
              if (value == null || value.length != 4) {
                return 'Enter 4 digits';
              }
              final isNumeric = int.tryParse(value) != null;
              return isNumeric ? null : 'Numbers only';
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(controller.text);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    controller.dispose();
    return result;
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
      decoration: const BoxDecoration(
        color: Color(0x80102222),
        border: Border(bottom: BorderSide(color: Color(0x220DF2F2))),
      ),
      child: Row(
        children: [
          IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded)),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CONTROL CENTER',
                  style: TextStyle(
                    color: Color(0xFFE7F8F8),
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Configure your multidimensional viewing experience.',
                  style: TextStyle(color: Color(0xFF7E9B9B), fontSize: 12),
                ),
              ],
            ),
          ),
          _HeaderMicroCard(),
        ],
      ),
    );
  }
}

class _HeaderMicroCard extends StatelessWidget {
  const _HeaderMicroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x220DF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x220DF2F2)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BITRATE',
            style: TextStyle(color: Color(0xFF7E9B9B), fontSize: 10),
          ),
          Text(
            '42.8 MBPS',
            style: TextStyle(
              color: Color(0xFF0DF2F2),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileMatrixCard extends StatelessWidget {
  const _ProfileMatrixCard({
    required this.username,
    required this.status,
    required this.onOpenProfile,
  });

  final String username;
  final String status;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x66102222),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x220DF2F2)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0x220DF2F2),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0x550DF2F2)),
            ),
            child: const Icon(Icons.person_rounded, color: Color(0xFF0DF2F2)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: const TextStyle(
                    color: Color(0xFFE7F8F8),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Status: ${status.toUpperCase()}',
                  style: const TextStyle(color: Color(0xFF7F9D9D), fontSize: 12),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: onOpenProfile,
            icon: const Icon(Icons.rocket_launch_rounded),
            label: const Text('Profile Matrix'),
          ),
        ],
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x66102222),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x220DF2F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFE7F8F8),
              fontSize: 20,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF7E9B9B), fontSize: 12),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _TelemetryPanel extends StatelessWidget {
  const _TelemetryPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x66102222),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x220DF2F2)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hardware Telemetry',
            style: TextStyle(
              color: Color(0xFF0DF2F2),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          SizedBox(height: 8),
          _TelemetryRow(label: 'GPU Acceleration', value: 'NVIDIA GRID 14.1'),
          _TelemetryRow(label: 'Packet Loss', value: '0.0001%'),
          _TelemetryRow(label: 'Engine Version', value: 'v8.4.2-ULTRA'),
        ],
      ),
    );
  }
}

class _TelemetryRow extends StatelessWidget {
  const _TelemetryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF85A3A3), fontSize: 12),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFE7F8F8),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
