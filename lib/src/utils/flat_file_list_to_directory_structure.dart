import 'package:path/path.dart' as p;

// Represents a node in the file system tree (either a directory or a file).
class Node {
  String type; // 'tree' (directory) or 'blob' (file)
  String fullpath; // The full path of the node
  String
  basename; // The base name of the node (e.g., 'file.txt' from 'dir/file.txt')
  Map<String, dynamic>
  metadata; // Metadata associated with the node (e.g., mode, oid for files)
  Node?
  parent; // The parent node in the tree; null for the root or unattached nodes initially
  List<Node> children; // List of child nodes; empty for files

  Node({
    required this.type,
    required this.fullpath,
    required this.basename,
    required this.metadata,
    this.parent,
    List<Node>? children,
  }) : children =
           children ??
           []; // Initialize children to an empty list if not provided
}

/// Converts a flat list of file entries into a hierarchical directory structure.
///
/// Each entry in the `files` list should be a `Map<String, dynamic>` containing
/// at least a 'path' key with a string value representing the file's path.
/// The entire file entry map is used as metadata for 'blob' (file) nodes.
///
/// Returns a map where keys are full paths and values are the corresponding `Node` objects.
Map<String, Node> flatFileListToDirectoryStructure(
  List<Map<String, dynamic>> files,
) {
  final inodes =
      <String, Node>{}; // Stores all created nodes, keyed by their fullpath

  // Declaring localMkdir with a specific function type for recursive use.
  late Node Function(String) localMkdir;

  // Creates a directory node and its ancestors if they don't already exist.
  localMkdir = (String name) {
    // If the node already exists, return it.
    if (inodes.containsKey(name)) {
      return inodes[name]!;
    }

    // Create the new directory node.
    final dirNode = Node(
      type: 'tree',
      fullpath: name,
      basename: p.basename(name), // Uses posix.basename
      metadata: {}, // Directories created by this function have empty metadata
      children: [],
    );
    // Add to inodes map *before* recursive call for parent to handle cycles (e.g. root dir).
    inodes[name] = dirNode;

    String parentDirName = p.dirname(name); // Uses posix.dirname

    // Recursively ensure the parent directory exists.
    // If 'name' is a root like '.' or '/', parentDirName will be the same as 'name'.
    // In such cases, parentNode will become dirNode itself.
    Node parentNode = localMkdir(parentDirName);
    dirNode.parent = parentNode;

    // Add this directory to its parent's children list,
    // unless the parent is itself (which is true for root nodes like '.', '/').
    if (dirNode.parent != dirNode) {
      // parentNode is dirNode.parent; children list is guaranteed to exist.
      dirNode.parent!.children.add(dirNode);
    }

    return dirNode;
  };

  // Creates a file node and its parent directories if they don't already exist.
  Node localMkfile(String filePath, Map<String, dynamic> fileMetadata) {
    // If the node already exists (e.g. duplicate path), return it.
    if (inodes.containsKey(filePath)) {
      return inodes[filePath]!;
    }

    // Create the new file node.
    final fileNode = Node(
      type: 'blob',
      fullpath: filePath,
      basename: p.basename(filePath),
      metadata:
          fileMetadata, // The entire input fileData map is used as metadata
      children: [], // Files do not have children
    );

    // Ensure parent directory exists by calling localMkdir.
    String parentDirName = p.dirname(filePath);
    Node parentNode = localMkdir(parentDirName);
    fileNode.parent = parentNode;

    // Add this file to its parent's children list.
    // parentNode is guaranteed to exist and not be null due to localMkdir's behavior.
    parentNode.children.add(fileNode);

    // Add the newly created file node to the inodes map.
    // This matches the JavaScript version's behavior of adding to inodes after parent linking for files.
    inodes[filePath] = fileNode;

    return fileNode;
  }

  // Initialize the root directory ('.') to anchor relative paths.
  // This ensures that dirname('somefile') which results in '.' will find a node.
  localMkdir('.');

  // Process all file entries from the input list.
  for (final fileData in files) {
    // Assumes fileData is a Map<String, dynamic> and always contains a 'path' key with a String value.
    // If 'path' could be null or missing, additional error handling or checks would be needed here.
    final String filePath = fileData['path'] as String;
    localMkfile(filePath, fileData);
  }

  return inodes;
}
