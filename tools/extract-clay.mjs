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

const srcFile = path.resolve('c:/AI/gemini/promise-path-next/assets/references/a-clay-cast.png');
const outDir = path.resolve('c:/AI/gemini/promise-path-next/public/clay');
fs.mkdirSync(outDir, { recursive: true });

const img = readPNG(srcFile);
const yTop = 674;
const yBot = 932;

const rowBg = [];
for (let y = yTop; y < yBot; y++) {
  let r = 0, g = 0, b = 0, n = 0;
  for (const x of [4, 6, 8, 1575, 1578, 1580]) {
    const idx = (y * img.width + x) * 4;
    r += img.rgba[idx];
    g += img.rgba[idx + 1];
    b += img.rgba[idx + 2];
    n++;
  }
  rowBg.push([r / n, g / n, b / n]);
}

function bgDist(r, g, b, yLocal) {
  const [br, bg, bb] = rowBg[yLocal];
  return Math.hypot(r - br, g - bg, b - bb);
}

const segments = [
  [ 37, 232 ],
  [ 245, 411 ],
  [ 441, 606 ],
  [ 611, 784 ],
  [ 785, 986 ],
  [ 996, 1174 ],
  [ 1180, 1345 ],
  [ 1370, 1547 ]
];

const mapping = [
  { segIndex: 0, id: 'abram' },
  { segIndex: 1, id: 'mara' },
  { segIndex: 2, id: 'nura' },
  { segIndex: 3, id: 'eli' },
  { segIndex: 4, id: 'asa' },
  { segIndex: 6, id: 'lot' },
  { segIndex: 7, id: 'sarai' },
];

for (const { segIndex, id } of mapping) {
  const seg = segments[segIndex];
  if (!seg) continue;
  const [x0, x1] = seg;
  const w = x1 - x0 + 1;
  const h = yBot - yTop;
  const crop = new Uint8Array(w * h * 4);

  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const si = ((yTop + y) * img.width + (x0 + x)) * 4;
      const di = (y * w + x) * 4;
      crop[di] = img.rgba[si];
      crop[di + 1] = img.rgba[si + 1];
      crop[di + 2] = img.rgba[si + 2];
      crop[di + 3] = 255;
    }
  }

  const visited = new Uint8Array(w * h);
  const queue = new Int32Array(w * h * 2);
  let qHead = 0, qTail = 0;

  function isGroundShadowPixel(r, g, b, y) {
    if (y < h - 22) return false;
    // The baked ground shadow is a soft tan/beige (R>175, G>145, B>115) whereas sandals/wood staff are dark brown (R<155)
    return r > 172 && g > 142 && b > 110 && (r - b) < 72;
  }

  function tryPush(x, y) {
    if (x < 0 || x >= w || y < 0 || y >= h) return;
    const p = y * w + x;
    if (visited[p]) return;
    const di = p * 4;
    const r = crop[di], g = crop[di + 1], b = crop[di + 2];
    const d = bgDist(r, g, b, y);
    if (d <= 22 || isGroundShadowPixel(r, g, b, y)) {
      visited[p] = 1;
      queue[qTail++] = p;
    }
  }

  for (let x = 0; x < w; x++) {
    tryPush(x, 0);
    tryPush(x, h - 1);
  }
  for (let y = 0; y < h; y++) {
    tryPush(0, y);
    tryPush(w - 1, y);
  }

  while (qHead < qTail) {
    const p = queue[qHead++];
    const x = p % w, y = (p / w) | 0;
    tryPush(x - 1, y);
    tryPush(x + 1, y);
    tryPush(x, y - 1);
    tryPush(x, y + 1);
  }

  for (let y = 18; y < h - 6; y++) {
    for (let x = 8; x < w - 8; x++) {
      const p = y * w + x;
      if (visited[p]) continue;
      const di = p * 4;
      const d = bgDist(crop[di], crop[di + 1], crop[di + 2], y);
      if (d < 10.5) visited[p] = 1;
    }
  }

  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const p = y * w + x;
      const di = p * 4;
      if (visited[p]) {
        crop[di + 3] = 0;
      } else {
        let bgNeighbors = 0;
        for (const [dx, dy] of [[-1,0],[1,0],[0,-1],[0,1],[-1,-1],[1,-1],[-1,1],[1,1]]) {
          const nx = x + dx, ny = y + dy;
          if (nx < 0 || nx >= w || ny < 0 || ny >= h || visited[ny * w + nx]) bgNeighbors++;
        }
        if (bgNeighbors > 0) {
          const d = bgDist(crop[di], crop[di + 1], crop[di + 2], y);
          const alpha = Math.min(255, Math.max(0, Math.round((d - 10) * 11)));
          crop[di + 3] = alpha;
        }
      }
    }
  }

  const outFile = path.join(outDir, `character_${id}.png`);
  writePNG(outFile, w, h, crop);
  console.log(`Saved ${outFile} (${w}x${h})`);
}
