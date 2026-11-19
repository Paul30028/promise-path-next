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

/**
 * Studio-Grade Alpha Matting:
 * 1. Outer border flood-fill only (NEVER punches holes in sunlit limestone or linen!)
 * 2. Targeted window aperture clearing ONLY for watchtower's upper timber frame (y in 26%..45%)
 * 3. Bottom sandal-gap floor-shadow clearing for characters
 * 4. Inward RGB Erosion: boundary pixels pull their RGB from 2-3px INSIDE the foreground silhouette,
 *    completely eliminating 100% of white/cream outline halos!
 * 5. Smooth 16px earth-toned ground-apron feathering on building bases so buildings blend into terrain
 */
function sliceGridStudio(sheetPath, rows, cols, names, outDir, previewList, isBuildingSheet = false) {
  const sheet = readPNG(sheetPath);
  const bgR = sheet.rgba[(10 * sheet.width + 10) * 4];
  const bgG = sheet.rgba[(10 * sheet.width + 10) * 4 + 1];
  const bgB = sheet.rgba[(10 * sheet.width + 10) * 4 + 2];
  const bgDist = (r, g, b) => Math.hypot(r - bgR, g - bgG, b - bgB);

  const cellW = Math.floor(sheet.width / cols);
  const cellH = Math.floor(sheet.height / rows);

  for (let r = 0; r < rows; r++) {
    const cy0 = r * cellH + 4;
    const cy1 = (r + 1) * cellH - 5;

    const splits = [4];
    for (let c = 1; c < cols; c++) {
      const idealX = c * cellW;
      let bestX = idealX;
      let bestScore = 1e9;
      for (let x = idealX - 45; x <= idealX + 45; x++) {
        let count = 0;
        for (let y = cy0; y <= cy1; y++) {
          const i = (y * sheet.width + x) * 4;
          if (bgDist(sheet.rgba[i], sheet.rgba[i + 1], sheet.rgba[i + 2]) > 26) count++;
        }
        const score = count * 10 + Math.abs(x - idealX) * 0.1;
        if (score < bestScore) {
          bestScore = score;
          bestX = x;
        }
      }
      splits.push(bestX);
    }
    splits.push(sheet.width - 5);

    for (let c = 0; c < cols; c++) {
      const name = names[r * cols + c];
      if (!name) continue;
      const cx0 = splits[c];
      const cx1 = splits[c + 1];

      const rawW = cx1 - cx0 + 1;
      const rawH = cy1 - cy0 + 1;
      const crop = new Uint8Array(rawW * rawH * 4);
      for (let y = 0; y < rawH; y++) {
        for (let x = 0; x < rawW; x++) {
          const si = ((cy0 + y) * sheet.width + (cx0 + x)) * 4;
          const di = (y * rawW + x) * 4;
          crop[di] = sheet.rgba[si];
          crop[di + 1] = sheet.rgba[si + 1];
          crop[di + 2] = sheet.rgba[si + 2];
          crop[di + 3] = 255;
        }
      }

      const isBg = new Uint8Array(rawW * rawH);
      const queue = new Int32Array(rawW * rawH * 2);
      let qHead = 0, qTail = 0;

      const isOuterBg = (x, y) => {
        const di = (y * rawW + x) * 4;
        const pr = crop[di], pg = crop[di + 1], pb = crop[di + 2];
        const d = bgDist(pr, pg, pb);
        if (d <= 23) return true;

        const sat = Math.max(pr, pg, pb) - Math.min(pr, pg, pb);
        const lum = (pr + pg + pb) / 3;
        // Studio floor contact shadow below characters' sandals (low saturation neutral grey-beige)
        if (!isBuildingSheet && y > rawH * 0.88 && sat <= 36 && lum >= 118) {
          return true;
        }
        // Soft studio shadow around building perimeter
        if (isBuildingSheet && sat <= 24 && lum >= 188 && d <= 46) {
          return true;
        }
        return false;
      };

      const tryPush = (x, y) => {
        if (x < 0 || x >= rawW || y < 0 || y >= rawH) return;
        const p = y * rawW + x;
        if (isBg[p]) return;
        if (isOuterBg(x, y)) {
          isBg[p] = 1;
          queue[qTail++] = p;
        }
      };

      // 1. Seed ONLY from outer perimeter (protects 100% of internal sunlit stones & linen!)
      for (let x = 0; x < rawW; x++) { tryPush(x, 0); tryPush(x, rawH - 1); }
      for (let y = 0; y < rawH; y++) { tryPush(0, y); tryPush(rawW - 1, y); }

      // 2. For characters: seed the gap between the two ankles/sandals (y in 78%..98%, x near center)
      if (!isBuildingSheet) {
        for (let y = Math.floor(rawH * 0.75); y < rawH - 2; y++) {
          for (let x = Math.floor(rawW * 0.30); x <= Math.floor(rawW * 0.70); x++) {
            const p = y * rawW + x;
            if (isBg[p]) continue;
            const di = p * 4;
            const pr = crop[di], pg = crop[di + 1], pb = crop[di + 2];
            const sat = Math.max(pr, pg, pb) - Math.min(pr, pg, pb);
            const lum = (pr + pg + pb) / 3;
            if (bgDist(pr, pg, pb) <= 22 || (y > rawH * 0.87 && sat <= 35 && lum >= 122)) {
              isBg[p] = 1;
              queue[qTail++] = p;
            }
          }
        }
      }

      // 3. For watchtower ONLY: clear the open sky windows between the upper wooden crossbeams (y in 26%..44%)
      if (name === 'bldg_watchtower') {
        for (let y = Math.floor(rawH * 0.26); y <= Math.floor(rawH * 0.44); y++) {
          for (let x = Math.floor(rawW * 0.22); x <= Math.floor(rawW * 0.72); x++) {
            const p = y * rawW + x;
            if (isBg[p]) continue;
            const di = p * 4;
            if (bgDist(crop[di], crop[di + 1], crop[di + 2]) <= 18) {
              isBg[p] = 1;
              queue[qTail++] = p;
            }
          }
        }
      }

      // 3b. For slinger ONLY: clear the enclosed loop between the two leather sling cords above his head (y in 2%..22%)
      if (name === 'unit_slinger') {
        for (let y = Math.floor(rawH * 0.02); y <= Math.floor(rawH * 0.22); y++) {
          for (let x = Math.floor(rawW * 0.05); x <= Math.floor(rawW * 0.55); x++) {
            const p = y * rawW + x;
            if (isBg[p]) continue;
            const di = p * 4;
            if (bgDist(crop[di], crop[di + 1], crop[di + 2]) <= 20) {
              isBg[p] = 1;
              queue[qTail++] = p;
            }
          }
        }
      }

      while (qHead < qTail) {
        const p = queue[qHead++];
        const x = p % rawW, y = (p / rawW) | 0;
        tryPush(x - 1, y); tryPush(x + 1, y);
        tryPush(x, y - 1); tryPush(x, y + 1);
      }

      // 4. Keep only the main foreground connected component
      const compId = new Int32Array(rawW * rawH);
      let nextComp = 1, mainComp = 1, mainSize = 0;
      for (let p0 = 0; p0 < rawW * rawH; p0++) {
        if (isBg[p0] || compId[p0]) continue;
        const cid = nextComp++;
        let head = 0, tail = 0;
        queue[tail++] = p0;
        compId[p0] = cid;
        while (head < tail) {
          const p = queue[head++];
          const x = p % rawW, y = (p / rawW) | 0;
          for (const [dx, dy] of [[-1,0],[1,0],[0,-1],[0,1],[-1,-1],[1,-1],[-1,1],[1,1]]) {
            const nx = x + dx, ny = y + dy;
            if (nx < 0 || nx >= rawW || ny < 0 || ny >= rawH) continue;
            const np = ny * rawW + nx;
            if (!isBg[np] && !compId[np]) {
              compId[np] = cid;
              queue[tail++] = np;
            }
          }
        }
        if (tail > mainSize) {
          mainSize = tail;
          mainComp = cid;
        }
      }
      for (let p = 0; p < rawW * rawH; p++) {
        if (!isBg[p] && compId[p] !== mainComp) isBg[p] = 1;
      }

      // 5. Compute BFS distance field from background into foreground
      const distFromBg = new Int16Array(rawW * rawH);
      distFromBg.fill(999);
      let dHead = 0, dTail = 0;
      for (let p = 0; p < rawW * rawH; p++) {
        if (isBg[p]) {
          distFromBg[p] = 0;
          queue[dTail++] = p;
        }
      }
      while (dHead < dTail) {
        const p = queue[dHead++];
        const d = distFromBg[p];
        if (d >= 24) continue;
        const x = p % rawW, y = (p / rawW) | 0;
        for (const [dx, dy] of [[-1,0],[1,0],[0,-1],[0,1]]) {
          const nx = x + dx, ny = y + dy;
          if (nx < 0 || nx >= rawW || ny < 0 || ny >= rawH) continue;
          const np = ny * rawW + nx;
          if (distFromBg[np] > d + 1) {
            distFromBg[np] = d + 1;
            queue[dTail++] = np;
          }
        }
      }

      // 6. Inward RGB Erosion: for boundary pixels (distFromBg in 1..3), replace their cream-contaminated RGB
      // with the darkest/purest interior pixel at distFromBg >= 3 within a 3px radius!
      const cleanRgb = new Uint8Array(crop);
      for (let y = 0; y < rawH; y++) {
        for (let x = 0; x < rawW; x++) {
          const p = y * rawW + x;
          const d = distFromBg[p];
          if (d >= 1 && d <= 3) {
            let bestR = crop[p * 4], bestG = crop[p * 4 + 1], bestB = crop[p * 4 + 2];
            let bestDist = d;
            let bestDarkness = -bgDist(bestR, bestG, bestB);
            for (let dy = -3; dy <= 3; dy++) {
              for (let dx = -3; dx <= 3; dx++) {
                const nx = x + dx, ny = y + dy;
                if (nx < 0 || nx >= rawW || ny < 0 || ny >= rawH) continue;
                const np = ny * rawW + nx;
                const nd = distFromBg[np];
                if (nd > bestDist) {
                  const nr = crop[np * 4], ng = crop[np * 4 + 1], nb = crop[np * 4 + 2];
                  const score = nd * 20 + bgDist(nr, ng, nb);
                  if (score > bestDarkness) {
                    bestDarkness = score;
                    bestDist = nd;
                    bestR = nr;
                    bestG = ng;
                    bestB = nb;
                  }
                }
              }
            }
            cleanRgb[p * 4] = bestR;
            cleanRgb[p * 4 + 1] = bestG;
            cleanRgb[p * 4 + 2] = bestB;
          }
        }
      }

      // 7. Apply smooth anti-aliased alpha & building ground-skirt feathering
      for (let y = 0; y < rawH; y++) {
        for (let x = 0; x < rawW; x++) {
          const p = y * rawW + x;
          const di = p * 4;
          const dist = distFromBg[p];
          if (dist === 0) {
            cleanRgb[di + 3] = 0;
            continue;
          }

          // Erode 1px outer fringe where cream blending happens, then 2px smooth anti-aliased ramp
          const isBuildingBase = isBuildingSheet && y > rawH * 0.60;
          let alpha = 1.0;
          if (isBuildingBase) {
            // 16px smooth ground skirt fade so the building's dirt apron melts seamlessly into the 3D terrain
            const t = Math.min(1, Math.max(0, (dist - 1.0) / 15.0));
            alpha = t * t * (3 - 2 * t);
            // Warm-darken pale sand apron toward natural earth tone near the outer fade edge
            const earthBlend = 0.72 + 0.28 * alpha;
            cleanRgb[di] = Math.round(cleanRgb[di] * earthBlend);
            cleanRgb[di + 1] = Math.round(cleanRgb[di + 1] * earthBlend);
            cleanRgb[di + 2] = Math.round(cleanRgb[di + 2] * earthBlend * 0.92);
          } else if (dist === 1) {
            // Very outer 1px anti-aliasing edge
            const cd = bgDist(crop[di], crop[di + 1], crop[di + 2]);
            alpha = cd > 48 ? 0.55 : 0.0;
          } else if (dist === 2) {
            alpha = 0.88;
          }

          cleanRgb[di + 3] = Math.round(alpha * 255);
        }
      }

      // 8. Tight bounding box
      let x0 = rawW - 1, x1 = 0, y0 = rawH - 1, y1 = 0;
      for (let y = 0; y < rawH; y++) {
        for (let x = 0; x < rawW; x++) {
          if (cleanRgb[(y * rawW + x) * 4 + 3] > 8) {
            if (x < x0) x0 = x;
            if (x > x1) x1 = x;
            if (y < y0) y0 = y;
            if (y > y1) y1 = y;
          }
        }
      }
      x0 = Math.max(0, x0 - 2);
      x1 = Math.min(rawW - 1, x1 + 2);
      y0 = Math.max(0, y0 - 2);
      y1 = Math.min(rawH - 1, y1 + 2);

      const w = x1 - x0 + 1;
      const h = y1 - y0 + 1;
      const finalRgba = new Uint8Array(w * h * 4);
      for (let y = 0; y < h; y++) {
        for (let x = 0; x < w; x++) {
          const si = ((y0 + y) * rawW + (x0 + x)) * 4;
          const di = (y * w + x) * 4;
          finalRgba[di] = cleanRgb[si];
          finalRgba[di + 1] = cleanRgb[si + 1];
          finalRgba[di + 2] = cleanRgb[si + 2];
          finalRgba[di + 3] = cleanRgb[si + 3];
        }
      }

      // 9. Outward 3px RGB bleed into transparent pixels
      for (let pass = 0; pass < 3; pass++) {
        const copy = new Uint8Array(finalRgba);
        for (let y = 0; y < h; y++) {
          for (let x = 0; x < w; x++) {
            const di = (y * w + x) * 4;
            if (copy[di + 3] > 0) continue;
            let sr = 0, sg = 0, sb = 0, cnt = 0;
            for (const [dx, dy] of [[-1,0],[1,0],[0,-1],[0,1],[-1,-1],[1,-1],[-1,1],[1,1]]) {
              const nx = x + dx, ny = y + dy;
              if (nx < 0 || nx >= w || ny < 0 || ny >= h) continue;
              const ndi = (ny * w + nx) * 4;
              if (copy[ndi + 3] > 64) {
                sr += copy[ndi];
                sg += copy[ndi + 1];
                sb += copy[ndi + 2];
                cnt++;
              }
            }
            if (cnt > 0) {
              finalRgba[di] = Math.round(sr / cnt);
              finalRgba[di + 1] = Math.round(sg / cnt);
              finalRgba[di + 2] = Math.round(sb / cnt);
            }
          }
        }
      }

      writePNG(path.join(outDir, `${name}.png`), w, h, finalRgba);
      previewList.push({ name, w, h, rgba: finalRgba });
      console.log(`Studio-sliced ${name}.png (${w}x${h})`);
    }
  }
}

const srcDir = path.resolve('c:/AI/gemini/promise-path-next/design/codex-v5-aoe');
const outDir = path.resolve('c:/AI/gemini/promise-path-next/public/clay');
fs.mkdirSync(outDir, { recursive: true });

const previews = [];

sliceGridStudio(
  path.join(srcDir, 'aoe-v5-units-sheet.png'),
  2,
  4,
  [
    'character_abram',
    'character_sarai',
    'character_lot',
    'character_eli',
    'character_asa',
    'character_nura',
    'unit_spearman',
    'unit_slinger',
  ],
  outDir,
  previews,
  false
);

sliceGridStudio(
  path.join(srcDir, 'aoe-v5-buildings-sheet.png'),
  2,
  3,
  [
    'bldg_main_tent',
    'bldg_altar',
    'bldg_house',
    'bldg_depot',
    'bldg_watchtower',
    'bldg_barracks',
  ],
  outDir,
  previews,
  true
);

// Build dark-olive QA contact sheet
const cell = 200, cols = 7, rows = 2;
const cw = cols * cell, ch = rows * cell;
const contact = new Uint8Array(cw * ch * 4);
for (let y = 0; y < ch; y++) {
  for (let x = 0; x < cw; x++) {
    const di = (y * cw + x) * 4;
    const checker = (((x >> 4) + (y >> 4)) & 1) === 0;
    contact[di] = checker ? 68 : 88;
    contact[di + 1] = checker ? 78 : 96;
    contact[di + 2] = checker ? 46 : 58;
    contact[di + 3] = 255;
  }
}

previews.forEach((sp, idx) => {
  const gx = (idx % cols) * cell;
  const gy = Math.floor(idx / cols) * cell;
  const scale = Math.min((cell - 16) / sp.w, (cell - 16) / sp.h);
  const dw = Math.round(sp.w * scale);
  const dh = Math.round(sp.h * scale);
  const ox = gx + Math.floor((cell - dw) / 2);
  const oy = gy + Math.floor((cell - dh) / 2);

  for (let y = 0; y < dh; y++) {
    for (let x = 0; x < dw; x++) {
      const sx = Math.min(sp.w - 1, Math.floor(x / scale));
      const sy = Math.min(sp.h - 1, Math.floor(y / scale));
      const si = (sy * sp.w + sx) * 4;
      const a = sp.rgba[si + 3] / 255;
      if (a <= 0) continue;
      const di = ((oy + y) * cw + (ox + x)) * 4;
      contact[di] = Math.round(sp.rgba[si] * a + contact[di] * (1 - a));
      contact[di + 1] = Math.round(sp.rgba[si + 1] * a + contact[di + 1] * (1 - a));
      contact[di + 2] = Math.round(sp.rgba[si + 2] * a + contact[di + 2] * (1 - a));
    }
  }
});

writePNG(path.join(outDir, '_qa_contact_sheet.png'), cw, ch, contact);
console.log('Wrote studio QA contact sheet: public/clay/_qa_contact_sheet.png');
