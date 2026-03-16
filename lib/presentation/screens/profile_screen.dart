import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                        return;
                      }
                      context.go('/home');
                    },
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'PROFILE MATRIX',
                    style: TextStyle(
                      color: Color(0xFFE7F8F8),
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0x66102222),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0x220DF2F2)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: const Color(0x220DF2F2),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: const Color(0x660DF2F2),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: Color(0xFF0DF2F2),
                        size: 38,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session?.username ?? 'Guest node',
                            style: const TextStyle(
                              color: Color(0xFFE7F8F8),
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Status: ${(session?.account.status ?? 'offline').toUpperCase()}',
                            style: const TextStyle(
                              color: Color(0xFF7E9B9B),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (session != null)
                      const Icon(
                        Icons.verified_rounded,
                        color: Color(0xFF0DF2F2),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _ProfileInfoBlock(
                title: 'Account Telemetry',
                rows: [
                  _InfoRow(
                    'Active connections',
                    '${session?.account.activeConnections ?? 0}',
                  ),
                  _InfoRow(
                    'Max connections',
                    '${session?.account.maxConnections ?? 0}',
                  ),
                  _InfoRow(
                    'Expiration',
                    session?.account.expirationDate?.toIso8601String() ?? 'N/A',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _ProfileInfoBlock(
                title: 'Node Actions',
                rows: const [
                  _InfoRow('Region', 'Sector-7'),
                  _InfoRow('Engine', 'Kleimer Core'),
                  _InfoRow('Encryption', 'ENABLED'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileInfoBlock extends StatelessWidget {
  const _ProfileInfoBlock({required this.title, required this.rows});

  final String title;
  final List<_InfoRow> rows;

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
              color: Color(0xFF0DF2F2),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.label,
                      style: const TextStyle(
                        color: Color(0xFF84A1A1),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    row.value,
                    style: const TextStyle(
                      color: Color(0xFFE7F8F8),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;
}
