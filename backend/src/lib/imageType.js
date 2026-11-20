// Détecte le format d'une image à partir de ses premiers octets plutôt que du
// type annoncé par le client, qui n'est pas fiable.
// Renvoie { extension, contentType } ou null si le format n'est pas accepté.

const HEIF_FAMILY_BRANDS = new Set(['heic', 'heix', 'hevc', 'hevx', 'heim', 'heis', 'mif1', 'msf1']);

function bytesMatch(fileBuffer, offset, expectedBytes) {
  if (fileBuffer.length < offset + expectedBytes.length) return false;
  return expectedBytes.every((expectedByte, index) => fileBuffer[offset + index] === expectedByte);
}

function asciiAt(fileBuffer, offset, length) {
  if (fileBuffer.length < offset + length) return '';
  return fileBuffer.toString('ascii', offset, offset + length);
}

function detectImageType(fileBuffer) {
  if (!Buffer.isBuffer(fileBuffer)) return null;

  if (bytesMatch(fileBuffer, 0, [0xff, 0xd8, 0xff])) {
    return { extension: 'jpg', contentType: 'image/jpeg' };
  }
  if (bytesMatch(fileBuffer, 0, [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) {
    return { extension: 'png', contentType: 'image/png' };
  }
  if (asciiAt(fileBuffer, 0, 4) === 'RIFF' && asciiAt(fileBuffer, 8, 4) === 'WEBP') {
    return { extension: 'webp', contentType: 'image/webp' };
  }
  if (asciiAt(fileBuffer, 4, 4) === 'ftyp' && HEIF_FAMILY_BRANDS.has(asciiAt(fileBuffer, 8, 4))) {
    return { extension: 'heic', contentType: 'image/heic' };
  }
  return null;
}

module.exports = { detectImageType };
