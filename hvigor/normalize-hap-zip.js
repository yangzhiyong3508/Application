const fs = require('fs');
const zlib = require('zlib');

function writeUInt16(value) {
  const buffer = Buffer.alloc(2);
  buffer.writeUInt16LE(value, 0);
  return buffer;
}

function writeUInt32(value) {
  const buffer = Buffer.alloc(4);
  buffer.writeUInt32LE(value >>> 0, 0);
  return buffer;
}

function findEndOfCentralDirectory(data) {
  const minOffset = Math.max(0, data.length - 65557);
  for (let offset = data.length - 22; offset >= minOffset; offset--) {
    if (data.readUInt32LE(offset) === 0x06054b50) {
      return offset;
    }
  }
  throw new Error('End of central directory not found.');
}

function parseZipEntries(data) {
  const endOffset = findEndOfCentralDirectory(data);
  const totalEntries = data.readUInt16LE(endOffset + 10);
  let centralOffset = data.readUInt32LE(endOffset + 16);
  const entries = [];

  for (let index = 0; index < totalEntries; index++) {
    if (data.readUInt32LE(centralOffset) !== 0x02014b50) {
      throw new Error(`Invalid central directory header at ${centralOffset}.`);
    }

    const method = data.readUInt16LE(centralOffset + 10);
    const modifiedTime = data.readUInt16LE(centralOffset + 12);
    const modifiedDate = data.readUInt16LE(centralOffset + 14);
    const crc32 = data.readUInt32LE(centralOffset + 16);
    const compressedSize = data.readUInt32LE(centralOffset + 20);
    const uncompressedSize = data.readUInt32LE(centralOffset + 24);
    const nameLength = data.readUInt16LE(centralOffset + 28);
    const extraLength = data.readUInt16LE(centralOffset + 30);
    const commentLength = data.readUInt16LE(centralOffset + 32);
    const externalAttributes = data.readUInt32LE(centralOffset + 38);
    const localOffset = data.readUInt32LE(centralOffset + 42);
    const name = data.subarray(centralOffset + 46, centralOffset + 46 + nameLength);

    if (data.readUInt32LE(localOffset) !== 0x04034b50) {
      throw new Error(`Invalid local file header at ${localOffset}.`);
    }

    const localNameLength = data.readUInt16LE(localOffset + 26);
    const localExtraLength = data.readUInt16LE(localOffset + 28);
    const payloadOffset = localOffset + 30 + localNameLength + localExtraLength;
    const payload = data.subarray(payloadOffset, payloadOffset + compressedSize);

    let content;
    if (method === 0) {
      content = Buffer.from(payload);
    } else if (method === 8) {
      content = zlib.inflateRawSync(payload);
    } else {
      throw new Error(`Unsupported ZIP compression method ${method} for ${name.toString()}.`);
    }

    if (content.length !== uncompressedSize) {
      throw new Error(`ZIP entry size mismatch for ${name.toString()}.`);
    }

    entries.push({
      name,
      content,
      crc32,
      modifiedTime,
      modifiedDate,
      externalAttributes
    });

    centralOffset += 46 + nameLength + extraLength + commentLength;
  }

  return entries;
}

function buildCleanZip(entries) {
  if (entries.length >= 0xffff) {
    throw new Error('Too many ZIP entries to normalize without ZIP64.');
  }

  const localParts = [];
  const centralParts = [];
  let offset = 0;

  for (const entry of entries) {
    const compressed = zlib.deflateRawSync(entry.content, { level: 6 });
    if (compressed.length >= 0xffffffff || entry.content.length >= 0xffffffff || offset >= 0xffffffff) {
      throw new Error('ZIP entry is too large to normalize without ZIP64.');
    }

    const localOffset = offset;
    const localHeader = Buffer.concat([
      writeUInt32(0x04034b50),
      writeUInt16(20),
      writeUInt16(0),
      writeUInt16(8),
      writeUInt16(entry.modifiedTime),
      writeUInt16(entry.modifiedDate),
      writeUInt32(entry.crc32),
      writeUInt32(compressed.length),
      writeUInt32(entry.content.length),
      writeUInt16(entry.name.length),
      writeUInt16(0),
      entry.name,
      compressed
    ]);

    localParts.push(localHeader);
    offset += localHeader.length;

    centralParts.push(Buffer.concat([
      writeUInt32(0x02014b50),
      writeUInt16(20),
      writeUInt16(20),
      writeUInt16(0),
      writeUInt16(8),
      writeUInt16(entry.modifiedTime),
      writeUInt16(entry.modifiedDate),
      writeUInt32(entry.crc32),
      writeUInt32(compressed.length),
      writeUInt32(entry.content.length),
      writeUInt16(entry.name.length),
      writeUInt16(0),
      writeUInt16(0),
      writeUInt16(0),
      writeUInt16(0),
      writeUInt32(entry.externalAttributes),
      writeUInt32(localOffset),
      entry.name
    ]));
  }

  const centralOffset = offset;
  const centralDirectory = Buffer.concat(centralParts);
  const endOfCentralDirectory = Buffer.concat([
    writeUInt32(0x06054b50),
    writeUInt16(0),
    writeUInt16(0),
    writeUInt16(entries.length),
    writeUInt16(entries.length),
    writeUInt32(centralDirectory.length),
    writeUInt32(centralOffset),
    writeUInt16(0)
  ]);

  return Buffer.concat([...localParts, centralDirectory, endOfCentralDirectory]);
}

function normalizeHapZip(hapPath) {
  if (!fs.existsSync(hapPath)) {
    return;
  }

  const normalizedPath = `${hapPath}.normalized`;
  const entries = parseZipEntries(fs.readFileSync(hapPath));
  fs.writeFileSync(normalizedPath, buildCleanZip(entries));
  fs.unlinkSync(hapPath);
  fs.renameSync(normalizedPath, hapPath);
}

module.exports = {
  normalizeHapZip
};
