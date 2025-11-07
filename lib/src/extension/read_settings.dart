class DocumentReaderSettings {
  final Set<String> skipDataGroups;

  const DocumentReaderSettings({
    this.skipDataGroups = const {},
  });

  // Helper to check if a DG should be skipped
  bool shouldSkip(String dgName) => skipDataGroups.contains(dgName);
}