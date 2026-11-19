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
const sheet = readPNG(path.join(outDir, '_sheet_v1.png'));

// Copy clean camp background plate
const cleanBgSrc = 'C:/Users/holyx/.gemini/antigravity/brain/6e568a4c-bd1a-4b4b-8be5-415b1cddfb8e/camp_scene_clean_bg_1794965475437.jpg';
fs.copyFileSync(cleanBgSrc, path.join(outDir, 'camp-scene-clean-bg.jpg'));

const yTop = 382;
const yBot = 755;

function whiteDist(r, g, b) {
  return Math.hypot(255 - r, 255 - g, 255 - b);
}

const colActive = new Uint8Array(sheet.width);
for (let x = 0; x < sheet.width; x++) {
  let nonWhite = 0;
  for (let y = yTop; y < yBot; y++) {
    const idx = (y * sheet.width + x) * 4;
    if (whiteDist(sheet.rgba[idx], sheet.rgba[idx + 1], sheet.rgba[idx + 2]) > 20) {
      nonWhite++;
    }
  }
  if (nonWhite > 3) colActive[x] = 1;
}

const segments = [
  [ 46, 244 ],
  [ 248, 406 ],
  [ 420, 590 ],
  [ 595, 768 ],
  [ 772, 972 ],
  [ 976, 1152 ],
  [ 1156, 1340 ]
];

console.log('Detected 7 bottom-row segments:', segments);

const ids = ['abram', 'sarai', 'lot', 'eli', 'asa', 'nura', 'mara'];

for (let idx = 0; idx < ids.length; idx++) {
  const id = ids[idx];
  const seg = segments[idx];
  if (!seg) continue;
  const [x0, x1] = seg;

  // Find tight vertical bounds y0..y1 for this character so feet sit right at bottom
  let charY0 = yBot, charY1 = yTop;
  for (let y = yTop; y < yBot; y++) {
    for (let x = x0; x <= x1; x++) {
      const p = (y * sheet.width + x) * 4;
      if (whiteDist(sheet.rgba[p], sheet.rgba[p + 1], sheet.rgba[p + 2]) > 24) {
        if (y < charY0) charY0 = y;
        if (y > charY1) charY1 = y;
      }
    }
  }
  charY0 = Math.max(yTop, charY0 - 4);
  charY1 = Math.min(yBot, charY1 + 2);

  const w = x1 - x0 + 1;
  const h = charY1 - charY0 + 1;
  const crop = new Uint8Array(w * h * 4);

  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const si = ((charY0 + y) * sheet.width + (x0 + x)) * 4;
      const di = (y * w + x) * 4;
      crop[di] = sheet.rgba[si];
      crop[di + 1] = sheet.rgba[si + 1];
      crop[di + 2] = sheet.rgba[si + 2];
      crop[di + 3] = 255;
    }
  }

  // Flood fill pure white background from border + interior enclosed pure-white gaps
  const visited = new Uint8Array(w * h);
  const queue = new Int32Array(w * h * 2);
  let qHead = 0, qTail = 0;

  function tryPush(x, y) {
    if (x < 0 || x >= w || y < 0 || y >= h) return;
    const p = y * w + x;
    if (visited[p]) return;
    const di = p * 4;
    const d = whiteDist(crop[di], crop[di + 1], crop[di + 2]);
    if (d <= 22) {
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

  // Clear interior pure-white holes (e.g. between staff and arm/robe, between legs)
  for (let y = 10; y < h - 5; y++) {
    for (let x = 6; x < w - 6; x++) {
      const p = y * w + x;
      if (visited[p]) continue;
      const di = p * 4;
      if (whiteDist(crop[di], crop[di + 1], crop[di + 2]) <= 12) {
        visited[p] = 1;
      }
    }
  }

  // Apply anti-aliased edge feathering
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const p = y * w + x;
      const di = p * 4;
      if (visited[p]) {
        crop[di + 3] = 0;
      } else {
        let bgN = 0;
        for (const [dx, dy] of [[-1,0],[1,0],[0,-1],[0,1],[-1,-1],[1,-1],[-1,1],[1,1]]) {
          const nx = x + dx, ny = y + dy;
          if (nx < 0 || nx >= w || ny < 0 || ny >= h || visited[ny * w + nx]) bgN++;
        }
        if (bgN > 0) {
          const d = whiteDist(crop[di], crop[di + 1], crop[di + 2]);
          crop[di + 3] = Math.min(255, Math.max(0, Math.round((d - 10) * 10)));
        }
      }
    }
  }

  const outFile = path.join(outDir, `character_${id}.png`);
  writePNG(outFile, w, h, crop);
  console.log(`Saved ${id}: ${w}x${h}`);
}
