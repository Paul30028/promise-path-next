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

const srcFile = path.resolve('c:/AI/gemini/promise-path-next/design/codex-level1/level1-props-and-cards.png');
const outDir = path.resolve('c:/AI/gemini/promise-path-next/public/clay');
fs.mkdirSync(outDir, { recursive: true });

const sheet = readPNG(srcFile);
const bgR = sheet.rgba[(15 * sheet.width + 15) * 4];
const bgG = sheet.rgba[(15 * sheet.width + 15) * 4 + 1];
const bgB = sheet.rgba[(15 * sheet.width + 15) * 4 + 2];
const bgDist = (r, g, b) => Math.hypot(r - bgR, g - bgG, b - bgB);

// Top row (y: 10..485): 3 transparent props
const propBoxes = [
  { name: 'prop_tent_ready', x0: 15, x1: 500, y0: 15, y1: 485 },
  { name: 'prop_altar_lit', x0: 515, x1: 1015, y0: 15, y1: 485 },
  { name: 'prop_wolves', x0: 1020, x1: 1525, y0: 15, y1: 485 },
];

for (const box of propBoxes) {
  let minX = box.x1, maxX = box.x0, minY = box.y1, maxY = box.y0;
  for (let y = box.y0; y <= box.y1; y++) {
    for (let x = box.x0; x <= box.x1; x++) {
      const i = (y * sheet.width + x) * 4;
      if (bgDist(sheet.rgba[i], sheet.rgba[i + 1], sheet.rgba[i + 2]) > 22) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  minX = Math.max(box.x0, minX - 4);
  maxX = Math.min(box.x1, maxX + 4);
  minY = Math.max(box.y0, minY - 4);
  maxY = Math.min(box.y1, maxY + 4);

  const w = maxX - minX + 1;
  const h = maxY - minY + 1;
  const crop = new Uint8Array(w * h * 4);
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const si = ((minY + y) * sheet.width + (minX + x)) * 4;
      const di = (y * w + x) * 4;
      crop[di] = sheet.rgba[si];
      crop[di + 1] = sheet.rgba[si + 1];
      crop[di + 2] = sheet.rgba[si + 2];
      crop[di + 3] = 255;
    }
  }

  const visited = new Uint8Array(w * h);
  const queue = new Int32Array(w * h * 2);
  let qHead = 0, qTail = 0;
  function tryPush(x, y) {
    if (x < 0 || x >= w || y < 0 || y >= h) return;
    const p = y * w + x;
    if (visited[p]) return;
    const di = p * 4;
    const r = crop[di], g = crop[di + 1], b = crop[di + 2];
    const tol = y > h - 28 ? 26 : 18;
    if (bgDist(r, g, b) <= tol) {
      visited[p] = 1;
      queue[qTail++] = p;
    }
  }
  for (let x = 0; x < w; x++) { tryPush(x, 0); tryPush(x, h - 1); }
  for (let y = 0; y < h; y++) { tryPush(0, y); tryPush(w - 1, y); }
  while (qHead < qTail) {
    const p = queue[qHead++];
    const x = p % w, y = (p / w) | 0;
    tryPush(x - 1, y); tryPush(x + 1, y);
    tryPush(x, y - 1); tryPush(x, y + 1);
  }
  // Seed flood-fill from strictly pure cream background pixels (bgDist <= 8) inside enclosed pockets
  for (let y = 12; y < h - 12; y++) {
    for (let x = 12; x < w - 12; x++) {
      const p = y * w + x;
      if (visited[p]) continue;
      const di = p * 4;
      if (bgDist(crop[di], crop[di + 1], crop[di + 2]) <= 8) {
        visited[p] = 1;
        queue[qTail++] = p;
      }
    }
  }
  while (qHead < qTail) {
    const p = queue[qHead++];
    const x = p % w, y = (p / w) | 0;
    tryPush(x - 1, y); tryPush(x + 1, y);
    tryPush(x, y - 1); tryPush(x, y + 1);
  }
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const p = y * w + x;
      const di = p * 4;
      if (visited[p]) {
        crop[di + 3] = 0;
      } else {
        let bgN = 0;
        for (const [dx, dy] of [[-1,0],[1,0],[0,-1],[0,1]]) {
          const nx = x + dx, ny = y + dy;
          if (nx < 0 || nx >= w || ny < 0 || ny >= h || visited[ny * w + nx]) bgN++;
        }
        if (bgN > 0) {
          const d = bgDist(crop[di], crop[di + 1], crop[di + 2]);
          crop[di + 3] = Math.min(255, Math.max(0, Math.round((d - 9) * 11)));
        }
      }
    }
  }
  writePNG(path.join(outDir, `${box.name}.png`), w, h, crop);
  console.log(`Saved ${box.name}.png (${w}x${h})`);
}

// Bottom row (y: 500..1010): 3 opaque rounded-square card illustrations
const cardBoxes = [
  { name: 'card_defend', x0: 40, x1: 485, y0: 515, y1: 985 },
  { name: 'card_torch', x0: 540, x1: 990, y0: 515, y1: 985 },
  { name: 'card_retreat', x0: 1045, x1: 1495, y0: 515, y1: 985 },
];

for (const box of cardBoxes) {
  let minX = box.x1, maxX = box.x0, minY = box.y1, maxY = box.y0;
  for (let y = box.y0; y <= box.y1; y++) {
    for (let x = box.x0; x <= box.x1; x++) {
      const i = (y * sheet.width + x) * 4;
      if (bgDist(sheet.rgba[i], sheet.rgba[i + 1], sheet.rgba[i + 2]) > 20) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  // Inset slightly by 4px to avoid cream anti-aliasing border
  minX += 4; maxX -= 4; minY += 4; maxY -= 4;
  const w = maxX - minX + 1;
  const h = maxY - minY + 1;
  const crop = new Uint8Array(w * h * 4);
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const si = ((minY + y) * sheet.width + (minX + x)) * 4;
      const di = (y * w + x) * 4;
      crop[di] = sheet.rgba[si];
      crop[di + 1] = sheet.rgba[si + 1];
      crop[di + 2] = sheet.rgba[si + 2];
      crop[di + 3] = 255;
    }
  }
  writePNG(path.join(outDir, `${box.name}.png`), w, h, crop);
  console.log(`Saved ${box.name}.png (${w}x${h})`);
}
