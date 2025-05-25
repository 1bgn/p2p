class FileEntry {
  final String name;
  String path;
  final bool sent;
  bool saved;

  FileEntry({
    required this.name,
    required this.path,
    required this.sent,
    this.saved = false,
  });

  bool get isImage =>
      RegExp(r'\.(png|jpe?g|gif|webp)$').hasMatch(name.toLowerCase());
}