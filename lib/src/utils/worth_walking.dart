bool worthWalking(String filepath, String? root) {
  if (filepath == '.' || root == null || root.isEmpty || root == '.') {
    return true;
  }
  if (root.length >= filepath.length) {
    return root.startsWith(filepath);
  } else {
    return filepath.startsWith(root);
  }
}
