import '../../domain/entities/account.dart';

class AccountModel extends Account {
  const AccountModel({
    required super.username,
    required super.status,
    required super.expirationDate,
    required super.activeConnections,
    required super.maxConnections,
  });

  factory AccountModel.fromXtreamResponse(Map<String, dynamic> json) {
    final userInfo = (json['user_info'] as Map<String, dynamic>? ?? {});

    final expDateRaw = userInfo['exp_date']?.toString();
    DateTime? expirationDate;
    if (expDateRaw != null && expDateRaw.isNotEmpty) {
      final epoch = int.tryParse(expDateRaw);
      if (epoch != null) {
        expirationDate = DateTime.fromMillisecondsSinceEpoch(epoch * 1000);
      }
    }

    return AccountModel(
      username: userInfo['username']?.toString() ?? '',
      status: userInfo['status']?.toString() ?? 'unknown',
      expirationDate: expirationDate,
      activeConnections: int.tryParse(userInfo['active_cons']?.toString() ?? '0') ?? 0,
      maxConnections: int.tryParse(userInfo['max_connections']?.toString() ?? '1') ?? 1,
    );
  }
}
