String translateSSHtoHTTP(String url) {
  // Handle "shorter scp-like syntax"
  // Example: git@github.com:owner/repo.git -> https://github.com/owner/repo.git
  url = url.replaceFirstMapped(RegExp(r'^git@([^:]+):'), (match) {
    return 'https://${match.group(1)}/';
  });

  // Handle proper SSH URLs
  // Example: ssh://git@github.com/owner/repo.git -> https://git@github.com/owner/repo.git
  // Note: The original JS replaces `ssh://` with `https://` directly.
  // If the `git@` part needs to be preserved or handled differently, this might need adjustment.
  // The JS version would produce `https://git@domain/path` from `ssh://git@domain/path`.
  url = url.replaceFirst(RegExp(r'^ssh://'), 'https://');

  return url;
}
