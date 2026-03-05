class VodStream {
  const VodStream({
    required this.id,
    required this.name,
    required this.categoryId,
    this.coverUrl,
    this.containerExtension,
  });

  final String id;
  final String name;
  final String categoryId;
  final String? coverUrl;
  final String? containerExtension;
}
