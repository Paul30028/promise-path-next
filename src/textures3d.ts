import * as THREE from 'three';

/**
 * Deterministic 3D Terrain Heightmap across the expanded 80x60 Canaan Valley (5 Biomes):
 * 1. North-Central Sacred Altar High Place (x in [-8, 6], z in [-22, -10]) -> elevated plateau y = +1.35
 * 2. Northeast & East Ai Limestone Escarpment (x > 6, z < -4) -> rocky ridge y = +1.15 .. +1.75
 * 3. Central-West Bethel Camp Terrace (x in [-18, 2], z in [-4, 12]) -> gentle terrace y = +0.22
 * 4. Western Spring Gorge & Oasis Basin (x < -18, z in [-10, 10]) -> sunken water basin y = -0.32
 * 5. Southeast Jordan Plain Pasture (x > 4, z > 4) -> lush flat meadow y = 0.0
 */
export function getTerrainHeight(x: number, z: number): number {
  let h = 0;

  // 1. Sacred Altar High Place (North-Central plateau around (-2, -14))
  const dAltar = Math.hypot((x + 2) * 0.85, z + 14.5);
  if (dAltar < 8.5) {
    const t = Math.max(0, Math.min(1, (8.5 - dAltar) / 3.2));
    h = Math.max(h, t * t * (3 - 2 * t) * 1.35);
  }

  // 2. Northeast Ai Limestone Ridge & Wolf Escarpment (z < -5, x > 3)
  if (z < -3.5 && x > 1.0) {
    const tz = Math.max(0, Math.min(1, (-3.5 - z) / 5.0));
    const tx = Math.max(0, Math.min(1, (x - 1.0) / 5.0));
    const s = tz * tx;
    const ridgeH = s * s * (3 - 2 * s) * 1.25 + Math.sin(x * 0.35) * Math.cos(z * 0.35) * 0.18 * s;
    h = Math.max(h, ridgeH);
  }

  // 3. Central Bethel Camp Terrace around (-8, 4)
  const dCamp = Math.hypot((x + 8) * 0.7, (z - 4) * 0.85);
  if (dCamp < 12.0) {
    const t = Math.max(0, Math.min(1, (12.0 - dCamp) / 4.0));
    h = Math.max(h, t * t * (3 - 2 * t) * 0.24);
  }

  // 4. Western Oasis Water Gorge around (-22, 0)
  const dOasis = Math.hypot((x + 22) * 0.8, (z - 0.5) * 0.65);
  if (dOasis < 7.5) {
    const t = Math.max(0, Math.min(1, (7.5 - dOasis) / 2.8));
    h -= t * t * (3 - 2 * t) * 0.36;
  }

  // Subtle natural rolling micro-relief across the whole 80x60 valley
  h += Math.sin(x * 0.18) * Math.cos(z * 0.22) * 0.06;
  return Number(h.toFixed(3));
}

let cachedMaterials: {
  limestone: THREE.MeshStandardMaterial;
  cedarWood: THREE.MeshStandardMaterial;
  goatHairCloth: THREE.MeshStandardMaterial;
  healingCloth: THREE.MeshStandardMaterial;
  tekheletTapestry: THREE.MeshStandardMaterial;
  terracotta: THREE.MeshStandardMaterial;
  bronze: THREE.MeshStandardMaterial;
  thatch: THREE.MeshStandardMaterial;
} | null = null;

function makeCanvasTex(
  w: number,
  h: number,
  draw: (ctx: CanvasRenderingContext2D, w: number, h: number) => void,
  repeatX = 1,
  repeatY = 1
): THREE.CanvasTexture {
  const c = document.createElement('canvas');
  c.width = w;
  c.height = h;
  const ctx = c.getContext('2d')!;
  draw(ctx, w, h);
  const tex = new THREE.CanvasTexture(c);
  tex.colorSpace = THREE.SRGBColorSpace;
  tex.wrapS = THREE.RepeatWrapping;
  tex.wrapT = THREE.RepeatWrapping;
  tex.repeat.set(repeatX, repeatY);
  return tex;
}

/**
 * Shared Procedural PBR Materials with High-Detail Masonry, Timber Grain, Goat-Hair Weave & Tekhelet Embroidery
 */
export function getSharedMaterials() {
  if (cachedMaterials) return cachedMaterials;

  // 1. Jerusalem / Bethel Coursed Limestone Masonry
  const stoneTex = makeCanvasTex(
    256,
    256,
    (ctx, w, h) => {
      ctx.fillStyle = '#bfb096';
      ctx.fillRect(0, 0, w, h);
      const rows = 6;
      const rowH = h / rows;
      for (let r = 0; r < rows; r++) {
        const y = r * rowH;
        const cols = r % 2 === 0 ? 4 : 5;
        const colW = w / cols;
        for (let c = 0; c < cols; c++) {
          const x = c * colW + ((r % 2) * 14);
          const shade = 175 + ((r * 19 + c * 31) % 36);
          ctx.fillStyle = `rgb(${shade}, ${shade - 14}, ${shade - 34})`;
          ctx.fillRect((x % w) + 2, y + 2, colW - 4, rowH - 4);
          // Highlight top edge, shadow bottom edge
          ctx.fillStyle = 'rgba(255,250,235,0.28)';
          ctx.fillRect((x % w) + 2, y + 2, colW - 4, 3);
          ctx.fillStyle = 'rgba(45,32,18,0.35)';
          ctx.fillRect((x % w) + 2, y + rowH - 5, colW - 4, 3);
        }
      }
    },
    2,
    2
  );

  // 2. Cedar & Acacia Wood Grain
  const woodTex = makeCanvasTex(
    128,
    256,
    (ctx, w, h) => {
      ctx.fillStyle = '#6e4323';
      ctx.fillRect(0, 0, w, h);
      for (let i = 0; i < 60; i++) {
        ctx.fillStyle = i % 2 === 0 ? 'rgba(40,22,10,0.25)' : 'rgba(155,105,62,0.18)';
        ctx.fillRect((i * 13) % w, 0, 3, h);
      }
    },
    1,
    1
  );

  // 3. Dark Woven Goat-Hair Tent Fabric
  const clothTex = makeCanvasTex(
    256,
    256,
    (ctx, w, h) => {
      ctx.fillStyle = '#38291d';
      ctx.fillRect(0, 0, w, h);
      // Horizontal woven stripes
      for (let y = 0; y < h; y += 8) {
        ctx.fillStyle = y % 32 === 0 ? '#785a3c' : y % 16 === 0 ? '#4d3928' : '#2d2016';
        ctx.fillRect(0, y, w, 5);
      }
      // Vertical warp threads
      ctx.fillStyle = 'rgba(215, 190, 150, 0.08)';
      for (let x = 0; x < w; x += 6) {
        ctx.fillRect(x, 0, 2, h);
      }
    },
    2,
    2
  );

  // 4. Cream & Olive Herbal Healing Tent Fabric
  const healClothTex = makeCanvasTex(
    256,
    256,
    (ctx, w, h) => {
      ctx.fillStyle = '#e7dec8';
      ctx.fillRect(0, 0, w, h);
      for (let y = 0; y < h; y += 16) {
        ctx.fillStyle = y % 32 === 0 ? '#4d7c2b' : '#d6c7a9';
        ctx.fillRect(0, y, w, 6);
      }
    },
    2,
    2
  );

  // 5. Tekhelet Blue & Pomegranate Gold Covenant Tapestry
  const tapestryTex = makeCanvasTex(
    128,
    128,
    (ctx, w, h) => {
      ctx.fillStyle = '#1e3a8a';
      ctx.fillRect(0, 0, w, h);
      ctx.strokeStyle = '#fbbf24';
      ctx.lineWidth = 4;
      ctx.strokeRect(6, 6, w - 12, h - 12);
      ctx.fillStyle = '#dc2626';
      ctx.fillRect(12, h - 22, w - 24, 10);
      // Olive / Menorah motif in center
      ctx.strokeStyle = '#fde68a';
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.moveTo(w / 2, 26);
      ctx.lineTo(w / 2, 86);
      ctx.arc(w / 2, 48, 18, 0.2, Math.PI - 0.2);
      ctx.arc(w / 2, 44, 28, 0.2, Math.PI - 0.2);
      ctx.stroke();
    },
    1,
    1
  );

  // 6. Thatched Reed Roof
  const thatchTex = makeCanvasTex(
    128,
    128,
    (ctx, w, h) => {
      ctx.fillStyle = '#bfa065';
      ctx.fillRect(0, 0, w, h);
      for (let i = 0; i < 160; i++) {
        ctx.fillStyle = i % 2 === 0 ? '#9c7e46' : '#d8bc82';
        ctx.fillRect((i * 23) % w, (i * 17) % h, 3, 18);
      }
    },
    2,
    2
  );

  cachedMaterials = {
    limestone: new THREE.MeshStandardMaterial({ map: stoneTex, bumpMap: stoneTex, bumpScale: 0.04, roughness: 0.9 }),
    cedarWood: new THREE.MeshStandardMaterial({ map: woodTex, bumpMap: woodTex, bumpScale: 0.03, roughness: 0.85 }),
    goatHairCloth: new THREE.MeshStandardMaterial({
      map: clothTex,
      bumpMap: clothTex,
      bumpScale: 0.03,
      roughness: 0.92,
      side: THREE.DoubleSide,
    }),
    healingCloth: new THREE.MeshStandardMaterial({
      map: healClothTex,
      bumpMap: healClothTex,
      bumpScale: 0.02,
      roughness: 0.88,
      side: THREE.DoubleSide,
    }),
    tekheletTapestry: new THREE.MeshStandardMaterial({
      map: tapestryTex,
      roughness: 0.78,
      side: THREE.DoubleSide,
    }),
    terracotta: new THREE.MeshStandardMaterial({ color: '#b45309', roughness: 0.68 }),
    bronze: new THREE.MeshStandardMaterial({ color: '#d97706', metalness: 0.65, roughness: 0.32 }),
    thatch: new THREE.MeshStandardMaterial({ map: thatchTex, bumpMap: thatchTex, bumpScale: 0.04, roughness: 0.92 }),
  };

  return cachedMaterials;
}

/**
 * Create a realistic draped Ridge-Pole Nomad Pavilion Tent Roof Geometry (Catenary sag instead of a pyramid cone!)
 */
export function createDrapedTentGeometry(width: number, depth: number, ridgeHeight: number, eaveHeight: number): THREE.BufferGeometry {
  const segX = 16;
  const segZ = 10;
  const geom = new THREE.PlaneGeometry(width, depth, segX, segZ);
  geom.rotateX(-Math.PI / 2);
  const pos = geom.attributes.position as THREE.BufferAttribute;

  for (let i = 0; i < pos.count; i++) {
    const x = pos.getX(i);
    const z = pos.getZ(i);
    const nx = Math.abs(x) / (width / 2); // 0 at center ridge, 1 at side eaves
    const nz = Math.abs(z) / (depth / 2);
    // Catenary drape from central ridge beam down to side eaves
    const catenary = Math.pow(1 - nx, 1.45);
    // Subtle sag between tent poles along z
    const poleWave = Math.cos(nz * Math.PI * 2) * 0.05 * (1 - nx * 0.5);
    const y = eaveHeight + (ridgeHeight - eaveHeight) * catenary + poleWave;
    pos.setY(i, y);
  }
  geom.computeVertexNormals();
  return geom;
}
