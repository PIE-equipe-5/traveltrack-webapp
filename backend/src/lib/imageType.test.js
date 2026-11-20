const test = require('node:test');
const assert = require('node:assert/strict');

const { detectImageType } = require('./imageType');

test('reconnaît un JPEG', () => {
  const jpegHeader = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10]);
  assert.deepEqual(detectImageType(jpegHeader), { extension: 'jpg', contentType: 'image/jpeg' });
});

test('reconnaît un PNG', () => {
  const pngHeader = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00]);
  assert.deepEqual(detectImageType(pngHeader), { extension: 'png', contentType: 'image/png' });
});

test('reconnaît un WebP', () => {
  const webpHeader = Buffer.concat([Buffer.from('RIFF'), Buffer.from([0, 0, 0, 0]), Buffer.from('WEBPVP8 ')]);
  assert.deepEqual(detectImageType(webpHeader), { extension: 'webp', contentType: 'image/webp' });
});

test('reconnaît un HEIC (photo iPhone)', () => {
  const heicHeader = Buffer.concat([Buffer.from([0, 0, 0, 0x18]), Buffer.from('ftypheic'), Buffer.alloc(4)]);
  assert.deepEqual(detectImageType(heicHeader), { extension: 'heic', contentType: 'image/heic' });
});

test('refuse un fichier qui n\'est pas une image acceptée', () => {
  assert.equal(detectImageType(Buffer.from('%PDF-1.7')), null);
  assert.equal(detectImageType(Buffer.from('GIF89a')), null);
  assert.equal(detectImageType(Buffer.alloc(0)), null);
  assert.equal(detectImageType('pas un buffer'), null);
});
