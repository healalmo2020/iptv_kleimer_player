class Account {
  const Account({
    required this.username,
    required this.status,
    this.expirationDate,
    required this.activeConnections,
    required this.maxConnections,
  });

  final String username;
  final String status;
  final DateTime? expirationDate;
  final int activeConnections;
  final int maxConnections;
}
