import 'dart:convert';
import 'dart:typed_data';

/// A minimal store-only (no compression) ZIP archive writer.
///
/// Implements the PKZIP APPNOTE format subset required for OOXML packages:
/// local file headers, a central directory and the end-of-central-directory
/// record. Entries are stored uncompressed (`method 0`), which keeps the
/// writer dependency-free and simple; `.xlsx` consumers accept stored
/// entries.
///
/// Output is deterministic: timestamps are fixed to the DOS epoch minimum
/// (1980-01-01 00:00:00) so identical inputs produce identical bytes.
final class ZipWriter {
  final List<_ZipEntrySpec> _entries = <_ZipEntrySpec>[];

  /// Adds a file entry with the given [name] and raw [bytes] payload.
  void add(String name, List<int> bytes) {
    _entries.add(
      _ZipEntrySpec(
        name: name,
        data: Uint8List.fromList(bytes),
        crc: zipCrc32(bytes),
      ),
    );
  }

  /// Builds the archive bytes.
  ///
  /// Layout: local headers + data for each entry, then the central
  /// directory, then the end-of-central-directory record.
  Uint8List build() {
    final writer = _ByteWriter();
    final localOffsets = List<int>.filled(_entries.length, 0);

    for (var i = 0; i < _entries.length; i++) {
      final entry = _entries[i];
      localOffsets[i] = writer.length;
      _writeLocalHeader(writer, entry);
      writer.writeBytes(entry.data);
    }

    final centralDirectoryOffset = writer.length;
    for (var i = 0; i < _entries.length; i++) {
      _writeCentralDirectoryEntry(writer, _entries[i], localOffsets[i]);
    }
    final centralDirectorySize = writer.length - centralDirectoryOffset;

    _writeEndOfCentralDirectory(
      writer,
      _entries.length,
      centralDirectorySize,
      centralDirectoryOffset,
    );

    return writer.take();
  }

  void _writeLocalHeader(_ByteWriter writer, _ZipEntrySpec entry) {
    final nameBytes = utf8.encode(entry.name);
    writer
      ..writeUint32(0x04034b50)
      ..writeUint16(20) // version needed to extract (2.0)
      ..writeUint16(0x0800) // general purpose flags: UTF-8 names
      ..writeUint16(0) // compression method: stored
      ..writeUint16(0) // last mod time (DOS): 00:00:00
      ..writeUint16(_dosDate)
      ..writeUint32(entry.crc)
      ..writeUint32(entry.data.length) // compressed size
      ..writeUint32(entry.data.length) // uncompressed size
      ..writeUint16(nameBytes.length)
      ..writeUint16(0) // extra field length
      ..writeBytes(nameBytes);
  }

  void _writeCentralDirectoryEntry(
    _ByteWriter writer,
    _ZipEntrySpec entry,
    int localOffset,
  ) {
    final nameBytes = utf8.encode(entry.name);
    writer
      ..writeUint32(0x02014b50)
      ..writeUint16(20) // version made by
      ..writeUint16(20) // version needed to extract
      ..writeUint16(0x0800) // general purpose flags: UTF-8 names
      ..writeUint16(0) // compression method: stored
      ..writeUint16(0) // last mod time (DOS): 00:00:00
      ..writeUint16(_dosDate)
      ..writeUint32(entry.crc)
      ..writeUint32(entry.data.length) // compressed size
      ..writeUint32(entry.data.length) // uncompressed size
      ..writeUint16(nameBytes.length)
      ..writeUint16(0) // extra field length
      ..writeUint16(0) // comment length
      ..writeUint16(0) // disk number start
      ..writeUint16(0) // internal file attributes
      ..writeUint32(0) // external file attributes
      ..writeUint32(localOffset)
      ..writeBytes(nameBytes);
  }

  void _writeEndOfCentralDirectory(
    _ByteWriter writer,
    int entryCount,
    int centralDirectorySize,
    int centralDirectoryOffset,
  ) {
    writer
      ..writeUint32(0x06054b50)
      ..writeUint16(0) // number of this disk
      ..writeUint16(0) // disk with start of central directory
      ..writeUint16(entryCount) // entries on this disk
      ..writeUint16(entryCount) // total entries
      ..writeUint32(centralDirectorySize)
      ..writeUint32(centralDirectoryOffset)
      ..writeUint16(0); // comment length
  }
}

final class _ZipEntrySpec {
  const _ZipEntrySpec({
    required this.name,
    required this.data,
    required this.crc,
  });

  final String name;
  final Uint8List data;
  final int crc;
}

/// DOS date constant for 1980-01-01 — the earliest representable date.
const int _dosDate = 0x0021;

/// Computes the CRC-32 checksum (IEEE 802.3, reflected polynomial
/// `0xEDB88320`) used by the ZIP format.
int zipCrc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final byte in bytes) {
    crc = _crc32Table[(crc ^ byte) & 0xFF] ^ (crc >> 8);
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

final List<int> _crc32Table = _buildCrc32Table();

List<int> _buildCrc32Table() {
  final table = List<int>.filled(256, 0);
  for (var i = 0; i < 256; i++) {
    var value = i;
    for (var bit = 0; bit < 8; bit++) {
      value = (value & 1) == 1 ? (0xEDB88320 ^ (value >> 1)) : value >> 1;
    }
    table[i] = value;
  }
  return table;
}

/// A growable little-endian byte buffer with fixed-width integer writers.
final class _ByteWriter {
  Uint8List _buffer = Uint8List(64);
  int _length = 0;

  int get length => _length;

  void _ensureCapacity(int additional) {
    final required = _length + additional;
    if (required <= _buffer.length) return;
    var capacity = _buffer.length;
    while (capacity < required) {
      capacity *= 2;
    }
    final grown = Uint8List(capacity);
    grown.setRange(0, _length, _buffer);
    _buffer = grown;
  }

  void writeByte(int value) {
    _ensureCapacity(1);
    _buffer[_length++] = value & 0xFF;
  }

  void writeUint16(int value) {
    _ensureCapacity(2);
    _buffer[_length++] = value & 0xFF;
    _buffer[_length++] = (value >> 8) & 0xFF;
  }

  void writeUint32(int value) {
    _ensureCapacity(4);
    _buffer[_length++] = value & 0xFF;
    _buffer[_length++] = (value >> 8) & 0xFF;
    _buffer[_length++] = (value >> 16) & 0xFF;
    _buffer[_length++] = (value >> 24) & 0xFF;
  }

  void writeBytes(List<int> bytes) {
    if (bytes.isEmpty) return;
    _ensureCapacity(bytes.length);
    _buffer.setRange(_length, _length + bytes.length, bytes);
    _length += bytes.length;
  }

  Uint8List take() =>
      Uint8List.fromList(Uint8List.sublistView(_buffer, 0, _length));
}
