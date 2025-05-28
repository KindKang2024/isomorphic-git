import 'dart:typed_data';
import 'dart:convert';

import 'package:collection/collection.dart'; // For ListEquality
import 'package:crypto/crypto.dart'; // For sha1

import '../errors/internal_error.dart'; // Placeholder
import '../errors/unsafe_filepath_error.dart'; // Placeholder
import '../utils/buffer_cursor.dart'; // Placeholder

class CacheEntryFlags {
  bool assumeValid;
  bool extended; // Must be zero in version 2
  int stage; // 2-bit merge stage
  int nameLength; // 12-bit path length, 0xFFF if longer

  CacheEntryFlags({
    this.assumeValid = false,
    this.extended = false,
    this.stage = 0,
    this.nameLength = 0,
  });

  static CacheEntryFlags parse(int bits) {
    return CacheEntryFlags(
      assumeValid: (bits & 0x8000) != 0,
      extended: (bits & 0x4000) != 0, // Should be 0 for v2
      stage: (bits & 0x3000) >> 12,
      nameLength: bits & 0x0FFF,
    );
  }

  int render() {
    // Ensure extended is false for version 2
    extended = false;
    // nameLength is set based on actual path length before rendering
    return (assumeValid ? 0x8000 : 0) |
           (extended ? 0x4000 : 0) |
           ((stage & 0x3) << 12) |
           (nameLength & 0x0FFF);
  }
}

class CacheEntry {
  int ctimeSeconds;
  int ctimeNanoseconds;
  int mtimeSeconds;
  int mtimeNanoseconds;
  int dev;
  int ino;
  int mode;
  int uid;
  int gid;
  int size;
  String oid; // hex string
  CacheEntryFlags flags;
  String path;
  List<CacheEntry?> stages; // For unmerged entries

  CacheEntry({
    required this.ctimeSeconds,
    required this.ctimeNanoseconds,
    required this.mtimeSeconds,
    required this.mtimeNanoseconds,
    required this.dev,
    required this.ino,
    required this.mode,
    required this.uid,
    required this.gid,
    required this.size,
    required this.oid,
    required this.flags,
    required this.path,
  }) : stages = List<CacheEntry?>.filled(4, null, growable: false) {
    if (flags.stage < stages.length) {
        stages[flags.stage] = this;
    }
  }
  
  // Helper to get a Map representation of stats, similar to Node.js Stats object
  Map<String, int> get stats => {
    'ctimeSeconds': ctimeSeconds,
    'ctimeNanoseconds': ctimeNanoseconds,
    'mtimeSeconds': mtimeSeconds,
    'mtimeNanoseconds': mtimeNanoseconds,
    'dev': dev,
    'ino': ino,
    'mode': mode,
    'uid': uid,
    'gid': gid,
    'size': size,
  };
}

class GitIndex {
  final Map<String, CacheEntry> _entries = {};
  final Set<String> _unmergedPaths = {};
  // bool _dirty = false; // To track if needs saving

  GitIndex.empty();

  GitIndex._internal(Map<String, CacheEntry> entries, Set<String> unmergedPaths) {
    _entries.addAll(entries);
    _unmergedPaths.addAll(unmergedPaths);
  }

  void _addEntry(CacheEntry entry) {
    if (entry.flags.stage == 0) {
      // For stage 0, this entry replaces any existing unmerged entries for this path.
      _entries[entry.path] = entry;
      _unmergedPaths.remove(entry.path);
      entry.stages = List<CacheEntry?>.filled(4, null); // Reset stages
      entry.stages[0] = entry;
    } else {
      var existingRootEntry = _entries[entry.path];
      if (existingRootEntry == null || existingRootEntry.flags.stage != 0) {
        // If no stage 0 entry exists, or the existing one is also unmerged,
        // create a new root entry to hold the stages.
        // This new root entry might be minimal or based on one of the stages.
        // For simplicity, let's base it on the current entry but mark as stage 0 conceptually.
        // The actual stage 0 entry might be missing.
        existingRootEntry = CacheEntry(
          ctimeSeconds: entry.ctimeSeconds, // Or some default/average
          ctimeNanoseconds: entry.ctimeNanoseconds,
          mtimeSeconds: entry.mtimeSeconds,
          mtimeNanoseconds: entry.mtimeNanoseconds,
          dev: entry.dev,
          ino: entry.ino,
          mode: entry.mode, // Or a default mode
          uid: entry.uid,
          gid: entry.gid,
          size: entry.size,
          oid: entry.oid, // This OID might not be meaningful for a 'container' stage 0
          flags: CacheEntryFlags(stage: 0, nameLength: entry.flags.nameLength, assumeValid: entry.flags.assumeValid),
          path: entry.path,
        );
        _entries[entry.path] = existingRootEntry;
      }
      // Ensure stages list is initialized
      if(existingRootEntry.stages[0] == null && existingRootEntry.flags.stage == 0){
          existingRootEntry.stages[0] = existingRootEntry; // if it was a real stage 0
      }
      existingRootEntry.stages[entry.flags.stage] = entry;
      _unmergedPaths.add(entry.path);
    }
    // _dirty = true;
  }

  static Future<GitIndex> from(Uint8List? buffer) async {
    if (buffer == null) {
      return GitIndex.empty();
    }
    return GitIndex.fromBuffer(buffer);
  }

  static Future<GitIndex> fromBuffer(Uint8List buffer) async {
    if (buffer.isEmpty) {
      throw InternalError('Index file is empty (.git/index)');
    }

    final index = GitIndex.empty();
    final reader = BufferCursor(buffer);

    final magic = utf8.decode(reader.read(4));
    if (magic != 'DIRC') {
      throw InternalError('Invalid dircache magic file number: $magic');
    }

    final version = reader.readUInt32BE();
    if (version != 2) {
      // Support for V3 and V4 would require handling extended flags and additional data.
      throw InternalError('Unsupported dircache version: $version. Only version 2 is supported.');
    }

    // Verify checksum
    final contentForSha = buffer.sublist(0, buffer.length - 20);
    final shaClaimed = ByteUtils.toHexString(buffer.sublist(buffer.length - 20));
    final shaComputed = sha1.convert(contentForSha).toString();
    if (shaClaimed != shaComputed) {
      throw InternalError('Invalid checksum in GitIndex buffer: expected $shaClaimed but saw $shaComputed');
    }

    final numEntries = reader.readUInt32BE();
    for (int i = 0; i < numEntries; i++) {
      if (reader.eof()) throw InternalError('Unexpected EOF while reading entries');

      final ctimeSeconds = reader.readUInt32BE();
      final ctimeNanoseconds = reader.readUInt32BE();
      final mtimeSeconds = reader.readUInt32BE();
      final mtimeNanoseconds = reader.readUInt32BE();
      final dev = reader.readUInt32BE();
      final ino = reader.readUInt32BE();
      final mode = reader.readUInt32BE();
      final uid = reader.readUInt32BE();
      final gid = reader.readUInt32BE();
      final size = reader.readUInt32BE();
      final oid = ByteUtils.toHexString(reader.read(20));
      final flagsInt = reader.readUInt16BE();
      final flags = CacheEntryFlags.parse(flagsInt);

      // Path reading is tricky due to variable length and padding.
      // The 'nameLength' in flags is a hint, but if 0xFFF, path is null-terminated.
      // For v2, extended flag is 0, so no extra data based on that.
      
      int pathStartOffset = reader.offset;
      int pathEndOffset = pathStartOffset;
      while(pathEndOffset < buffer.length && buffer[pathEndOffset] != 0){
          pathEndOffset++;
      }
      if(pathEndOffset == buffer.length && buffer[pathEndOffset-1] != 0) {
          throw InternalError('Index entry path not null-terminated and extends to EOF');
      }
      
      final pathBytes = reader.read(pathEndOffset - pathStartOffset);
      final path = utf8.decode(pathBytes);
      reader.read(1); // Read the null terminator itself

      // Prevent malicious paths
      if (path.contains('..\\') || path.contains('../')) {
        throw UnsafeFilepathError(path);
      }

      // Padding: entries are padded with nulls to be a multiple of 8 bytes.
      // Total length of fixed fields: 62 bytes (ctime to flags)
      // Path length + 1 (for null terminator)
      // Total entry size so far = 62 + pathBytes.length + 1
      int currentEntrySize = 62 + pathBytes.length + 1;
      int padding = (8 - (currentEntrySize % 8)) % 8;
      for (int p = 0; p < padding; p++) {
        if (reader.eof() || reader.readUInt8() != 0) {
          throw InternalError('Invalid padding or unexpected EOF after path $path');
        }
      }
      
      final entry = CacheEntry(
        ctimeSeconds: ctimeSeconds,
        ctimeNanoseconds: ctimeNanoseconds,
        mtimeSeconds: mtimeSeconds,
        mtimeNanoseconds: mtimeNanoseconds,
        dev: dev,
        ino: ino,
        mode: mode,
        uid: uid,
        gid: gid,
        size: size,
        oid: oid,
        flags: flags, // nameLength will be updated if path length > 0xFFF on render
        path: path,
      );
      index._addEntry(entry);
    }
    return index;
  }

  List<String> get unmergedPaths => _unmergedPaths.toList();

  List<CacheEntry> get entries {
    var sortedEntries = _entries.values.toList();
    // Assuming comparePath is available and works like JS: (a,b) => a.path < b.path ? -1 : (a.path > b.path ? 1 : 0)
    // And then by stage for unmerged entries
    sortedEntries.sort((a, b) {
        int pathComparison = comparePath(a.path, b.path);
        if (pathComparison != 0) return pathComparison;
        return a.flags.stage.compareTo(b.flags.stage);
    });
    return sortedEntries;
  }
  
  Map<String, CacheEntry> get entriesMap => Map.unmodifiable(_entries);

  List<CacheEntry> get entriesFlat {
      final result = <CacheEntry>[];
      for (var entry in entries) {
          if (entry.stages.any((s) => s != null && s != entry)) { // Unmerged
              for (var stageEntry in entry.stages) {
                  if (stageEntry != null) result.add(stageEntry);
              }
          } else {
              result.add(entry); // Stage 0 or only entry
          }
      }
      return result;
  }

  Iterable<CacheEntry> get iterableEntries sync* {
    for (final entry in entries) {
      yield entry;
    }
  }

  void insert({
    required String filepath,
    required Map<String, int> stats, // Using the stats map from CacheEntry
    required String oid,
    int stage = 0,
    bool assumeValid = false,
  }) {
    final normalizedStats = normalizeStats(stats); // Assumes normalizeStats handles Map<String,int>
    final pathBytes = utf8.encode(filepath);

    final flags = CacheEntryFlags(
      assumeValid: assumeValid,
      extended: false, // v2 index
      stage: stage,
      nameLength: pathBytes.length < 0xFFF ? pathBytes.length : 0xFFF,
    );

    final entry = CacheEntry(
      ctimeSeconds: normalizedStats['ctimeSeconds']!,
      ctimeNanoseconds: normalizedStats['ctimeNanoseconds']!,
      mtimeSeconds: normalizedStats['mtimeSeconds']!,
      mtimeNanoseconds: normalizedStats['mtimeNanoseconds']!,
      dev: normalizedStats['dev']!,
      ino: normalizedStats['ino']!,
      mode: normalizedStats['mode'] ?? 0o100644, // Default if not present
      uid: normalizedStats['uid']!,
      gid: normalizedStats['gid']!,
      size: normalizedStats['size']!,
      oid: oid,
      flags: flags,
      path: filepath,
    );
    _addEntry(entry);
    // _dirty = true;
  }

  void remove({required String filepath, int stage = -1}) {
    final entry = _entries[filepath];
    if (entry != null) {
      if (stage == -1) { // Remove all stages
        _entries.remove(filepath);
        _unmergedPaths.remove(filepath);
      } else if (stage >=0 && stage < entry.stages.length) {
        entry.stages[stage] = null;
        // If all non-stage-0 are removed, it's no longer unmerged
        bool stillUnmerged = false;
        for(int i=1; i<entry.stages.length; i++){
            if(entry.stages[i] != null) {
                stillUnmerged = true;
                break;
            }
        }
        if(!stillUnmerged) _unmergedPaths.remove(filepath);
        // If stage 0 is removed and it was the main entry, remove the whole thing
        if(stage == 0 && entry == _entries[filepath]) _entries.remove(filepath);
      }
    }
    // _dirty = true;
  }

  Future<Uint8List> toBuffer() async {
    final List<CacheEntry> sortedEntriesFlat = entriesFlat; // Use flat list for writing
    // sortedEntriesFlat.sort((a,b) => comparePath(a.path, b.path)); // Already sorted by path, then stage

    final builder = BytesBuilder(copy: false);

    // Header (12 bytes)
    builder.add(utf8.encode('DIRC')); // Magic
    builder.add(ByteUtils.uint32be(2)); // Version 2
    builder.add(ByteUtils.uint32be(sortedEntriesFlat.length)); // Number of entries

    for (final entry in sortedEntriesFlat) {
      builder.add(ByteUtils.uint32be(entry.ctimeSeconds));
      builder.add(ByteUtils.uint32be(entry.ctimeNanoseconds));
      builder.add(ByteUtils.uint32be(entry.mtimeSeconds));
      builder.add(ByteUtils.uint32be(entry.mtimeNanoseconds));
      builder.add(ByteUtils.uint32be(entry.dev));
      builder.add(ByteUtils.uint32be(entry.ino));
      builder.add(ByteUtils.uint32be(entry.mode));
      builder.add(ByteUtils.uint32be(entry.uid));
      builder.add(ByteUtils.uint32be(entry.gid));
      builder.add(ByteUtils.uint32be(entry.size));
      builder.add(ByteUtils.fromHexString(entry.oid));
      
      final pathBytes = utf8.encode(entry.path);
      entry.flags.nameLength = pathBytes.length < 0xFFF ? pathBytes.length : 0xFFF;
      builder.add(ByteUtils.uint16be(entry.flags.render()));
      
      builder.add(pathBytes);
      builder.addByte(0); // Null terminator for path

      // Padding
      int currentEntrySize = 62 + pathBytes.length + 1;
      int paddingCount = (8 - (currentEntrySize % 8)) % 8;
      builder.add(Uint8List(paddingCount)); // Adds `paddingCount` null bytes
    }

    final contentBeforeSha = builder.toBytes();
    final sha = sha1.convert(contentBeforeSha).bytes;
    builder.add(sha);

    return builder.toBytes();
  }
}

// Placeholder for ByteUtils - assumed to provide hex string and BE int conversions
class ByteUtils {
  static Uint8List uint32be(int val) {
    final bytes = ByteData(4)..setUint32(0, val, Endian.big);
    return bytes.buffer.asUint8List();
  }
  static Uint8List uint16be(int val) {
    final bytes = ByteData(2)..setUint16(0, val, Endian.big);
    return bytes.buffer.asUint8List();
  }
  static String toHexString(Uint8List bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
  static Uint8List fromHexString(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (int i = 0; i < hex.length; i += 2) {
      result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return result;
  }
}