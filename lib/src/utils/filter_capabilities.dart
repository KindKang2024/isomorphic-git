List<String> filterCapabilities(List<String> server, List<String> client) {
  final serverNames = server.map((cap) => cap.split('=')[0]).toList();
  return client.where((cap) {
    final name = cap.split('=')[0];
    return serverNames.contains(name);
  }).toList();
}
