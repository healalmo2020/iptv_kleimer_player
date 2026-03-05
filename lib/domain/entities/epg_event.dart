class EpgEvent {
  const EpgEvent({
    required this.title,
    required this.description,
    this.start,
    this.end,
  });

  final String title;
  final String description;
  final DateTime? start;
  final DateTime? end;
}
