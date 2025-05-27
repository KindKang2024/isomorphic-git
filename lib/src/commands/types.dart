/// Enum for Git object types
enum GitObjectType { commit, tree, blob, tag, ofsDelta, refDelta }

const Map<GitObjectType, int> gitObjectTypeValues = {
  GitObjectType.commit: 0x10, // 0b0010000
  GitObjectType.tree: 0x20, // 0b0100000
  GitObjectType.blob: 0x30, // 0b0110000
  GitObjectType.tag: 0x40, // 0b1000000
  GitObjectType.ofsDelta: 0x60, // 0b1100000
  GitObjectType.refDelta: 0x70, // 0b1110000
};
