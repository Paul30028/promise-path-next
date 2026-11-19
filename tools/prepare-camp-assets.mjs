import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';

function readPNG(file) {
  const buf = fs.readFileSync(file);
  let pos = 8, width = 0, height = 0, colorType = 0;
  const idats = [];
  while (pos < buf.length) {
    const len = buf.readUInt32BE(pos);
    const type = buf.toString('ascii', pos + 4, pos + 8);
    const data = buf.subarray(pos + 8, pos + 8 + len);
    if (type === 'IHDR') {
      width = data.readUInt32BE(0);
      height = data.readUInt32BE(4);
      colorType = data[9];
    } else if (type === 'IDAT') {
      idats.push(data);
    }
    pos += 12 + len;
  }
  const raw = zlib.inflateSync(Buffer.concat(idats));
  const bpp = colorType === 6 ? 4 : 3;
  const stride = width * bpp + 1;
  const rgba = new Uint8Array(width * height * 4);
  const recon = new Uint8Array(width * bpp);
  const prev = new Uint8Array(width * bpp);
  for (let y = 0; y < height; y++) {
    const filter = raw[y * stride];
    const rowStart = y * stride + 1;
    for (let i = 0; i < width * bpp; i++) {
      const x = raw[rowStart + i];
      const a = i >= bpp ? recon[i - bpp] : 0;
      const b = prev[i];
      const c = i >= bpp ? prev[i - bpp] : 0;
      let v = x;
      if (filter === 1) v = (x + a) & 255;
      else if (filter === 2) v = (x + b) & 255;
      else if (filter === 3) v = (x + ((a + b) >> 1)) & 255;
      else if (filter === 4) {
        const p = a + b - c;
        const pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c);
        const pr = (pa <= pb && pa <= pc) ? a : (pb <= pc ? b : c);
        v = (x + pr) & 255;
      }
      recon[i] = v;
    }
    prev.set(recon);
    for (let x = 0; x < width; x++) {
      const si = x * bpp, di = (y * width + x) * 4;
      rgba[di] = recon[si];
      rgba[di + 1] = recon[si + 1];
      rgba[di + 2] = recon[si + 2];
      rgba[di + 3] = bpp === 4 ? recon[si + 3] : 255;
    }
  }
  return { width, height, rgba };
}

function crc32(buf) {
  let c = 0xffffffff;
  for (let i = 0; i < buf.length; i++) {
    c ^= buf[i];
    for (let k = 0; k < 8; k++) c = (c >>> 1) ^ (c & 1 ? 0xedb88320 : 0);
  }
  return (c ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length, 0);
  const t = Buffer.from(type, 'ascii');
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(Buffer.concat([t, data])), 0);
  return Buffer.concat([len, t, data, crc]);
}

function writePNG(file, width, height, rgba) {
  const sig = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8;
  ihdr[9] = 6;
  const raw = Buffer.alloc(height * (width * 4 + 1));
  for (let y = 0; y < height; y++) {
    raw[y * (width * 4 + 1)] = 0;
    const srcOff = y * width * 4;
    const dstOff = y * (width * 4 + 1) + 1;
    raw.set(rgba.subarray(srcOff, srcOff + width * 4), dstOff);
  }
  const idat = zlib.deflateSync(raw, { level: 9 });
  const out = Buffer.concat([sig, chunk('IHDR', ihdr), chunk('IDAT', idat), chunk('IEND', Buffer.alloc(0))]);
  fs.writeFileSync(file, out);
}

const outDir = path.resolve('c:/AI/gemini/promise-path-next/public/clay');
fs.mkdirSync(outDir, { recursive: true });

// 1. Copy clean background plate to public/clay/camp-scene-clean-bg.jpg
const cleanBgSrc = 'C:/Users/holyx/.gemini/antigravity/brain/6e568a4c-bd1a-4b4b-8be5-415b1cddfb8e/camp_scene_clean_bg_1794965475437.jpg';
fs.copyFileSync(cleanBgSrc, path.join(outDir, 'camp-scene-clean-bg.jpg'));
console.log('Copied camp-scene-clean-bg.jpg to public/clay/');

// 2. Make Nura's dress teal in character_nura.png (while keeping pink version as character_sarai_jar if needed)
const nuraRose = readPNG(path.join(outDir, 'character_nura.png'));
const nuraTeal = new Uint8Array(nuraRose.rgba);
for (let y = 0; y < nuraRose.height; y++) {
  for (let x = 0; x < nuraRose.width; x++) {
    const i = (y * nuraRose.width + x) * 4;
    if (nuraTeal[i + 3] === 0) continue;
    const r = nuraTeal[i], g = nuraTeal[i + 1], b = nuraTeal[i + 2];
    const isJarArea = (x > 88 && y > 68 && y < 176);
    const isSkinArea = (y < 92 && x > 45 && x < 105) || (x > 65 && x < 116 && y >= 130 && y <= 165) || (y > 224);
    if (!isJarArea && !isSkinArea && y > 88 && y < 232 && (r - g) > 32 && (r - b) > 42 && r > 120) {
      const lum = (r * 0.35 + g * 0.45 + b * 0.20) / 255;
      nuraTeal[i]     = Math.min(255, Math.round(lum * 115 + 22));
      nuraTeal[i + 1] = Math.min(255, Math.round(lum * 178 + 30));
      nuraTeal[i + 2] = Math.min(255, Math.round(lum * 175 + 32));
    }
  }
}
writePNG(path.join(outDir, 'character_nura.png'), nuraRose.width, nuraRose.height, nuraTeal);
console.log('Updated character_nura.png to teal dress matching camp-scene-v1.png');
