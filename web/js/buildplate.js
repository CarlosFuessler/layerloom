/**
 * 2MF Studio — Universal High-Detail Print Bed Generator & Three.js Mesh
 */

let buildPlateGroup, buildPlateMesh;

function createUniversalPlateTexture(printer, isDark = true) {
  const canvas = document.createElement('canvas');
  canvas.width = 1024;
  canvas.height = 1024;
  const ctx = canvas.getContext('2d');
  const w = canvas.width;
  const h = canvas.height;

  const bw = printer.width || 256;
  const bh = printer.height || 256;
  const brand = printer.brand || 'Universal';
  const model = printer.model || '3D Printer Bed';

  // 1. Base Plate Background (Textured Spring Steel PEI Surface)
  ctx.fillStyle = isDark ? '#16161a' : '#1c1c21';
  ctx.fillRect(0, 0, w, h);

  // Micro-stipple PEI powder-coated grain
  const imgData = ctx.getImageData(0, 0, w, h);
  const data = imgData.data;
  const noiseScale = 24;
  for (let i = 0; i < data.length; i += 4) {
    const noise = (Math.random() - 0.5) * noiseScale;
    data[i] = Math.max(0, Math.min(255, data[i] + noise + 2));
    data[i + 1] = Math.max(0, Math.min(255, data[i + 1] + noise + 2));
    data[i + 2] = Math.max(0, Math.min(255, data[i + 2] + noise + 4));
  }
  ctx.putImageData(imgData, 0, 0);

  // 2. Outer Perimeter Border
  ctx.strokeStyle = '#2d2d34';
  ctx.lineWidth = 6;
  ctx.strokeRect(8, 8, w - 16, h - 16);

  // Printable margin zone (8mm margin)
  const marginPx = Math.max(16, (8 / bw) * w);
  const printAreaW = w - marginPx * 2;
  const printAreaH = h - marginPx * 2;

  ctx.strokeStyle = 'rgba(255, 255, 255, 0.15)';
  ctx.lineWidth = 1.5;
  ctx.strokeRect(marginPx, marginPx, printAreaW, printAreaH);

  // 3. Coordinate Grid Lines (10mm minor, 50mm major)
  const pxPerMmX = w / bw;
  const pxPerMmY = h / bh;

  // Minor 10mm grid
  ctx.strokeStyle = 'rgba(255, 255, 255, 0.06)';
  ctx.lineWidth = 1;
  for (let xMm = 10; xMm < bw; xMm += 10) {
    if (xMm % 50 === 0) continue;
    const x = xMm * pxPerMmX;
    ctx.beginPath();
    ctx.moveTo(x, marginPx);
    ctx.lineTo(x, h - marginPx);
    ctx.stroke();
  }
  for (let yMm = 10; yMm < bh; yMm += 10) {
    if (yMm % 50 === 0) continue;
    const y = yMm * pxPerMmY;
    ctx.beginPath();
    ctx.moveTo(marginPx, y);
    ctx.lineTo(w - marginPx, y);
    ctx.stroke();
  }

  // Major 50mm grid with tick marks and metric labels
  ctx.strokeStyle = 'rgba(255, 255, 255, 0.22)';
  ctx.lineWidth = 1.5;
  ctx.fillStyle = 'rgba(255, 255, 255, 0.55)';
  ctx.font = '13px "JetBrains Mono", Menlo, monospace';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';

  for (let xMm = 50; xMm < bw; xMm += 50) {
    const x = xMm * pxPerMmX;
    ctx.beginPath();
    ctx.moveTo(x, marginPx);
    ctx.lineTo(x, h - marginPx);
    ctx.stroke();

    ctx.fillText(`${xMm}`, x, marginPx + 14);
    ctx.fillText(`${xMm}`, x, h - marginPx - 14);
  }

  for (let yMm = 50; yMm < bh; yMm += 50) {
    const y = yMm * pxPerMmY;
    ctx.beginPath();
    ctx.moveTo(marginPx, y);
    ctx.lineTo(w - marginPx, y);
    ctx.stroke();

    ctx.save();
    ctx.translate(marginPx + 14, y);
    ctx.rotate(-Math.PI / 2);
    ctx.fillText(`${yMm}`, 0, 0);
    ctx.restore();

    ctx.save();
    ctx.translate(w - marginPx - 14, y);
    ctx.rotate(Math.PI / 2);
    ctx.fillText(`${yMm}`, 0, 0);
    ctx.restore();
  }

  // 4. Center Crosshair (Bed Origin Center)
  const cx = w / 2;
  const cy = h / 2;
  ctx.strokeStyle = 'rgba(255, 255, 255, 0.45)';
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(cx - 24, cy);
  ctx.lineTo(cx + 24, cy);
  ctx.moveTo(cx, cy - 24);
  ctx.lineTo(cx, cy + 24);
  ctx.stroke();

  ctx.beginPath();
  ctx.arc(cx, cy, 12, 0, Math.PI * 2);
  ctx.stroke();

  // 5. Corner Alignment L-Brackets
  const bracketSize = 28;
  ctx.strokeStyle = 'rgba(255, 255, 255, 0.4)';
  ctx.lineWidth = 2.5;
  // Top-left
  ctx.beginPath();
  ctx.moveTo(marginPx, marginPx + bracketSize);
  ctx.lineTo(marginPx, marginPx);
  ctx.lineTo(marginPx + bracketSize, marginPx);
  ctx.stroke();
  // Top-right
  ctx.beginPath();
  ctx.moveTo(w - marginPx - bracketSize, marginPx);
  ctx.lineTo(w - marginPx, marginPx);
  ctx.lineTo(w - marginPx, marginPx + bracketSize);
  ctx.stroke();
  // Bottom-left
  ctx.beginPath();
  ctx.moveTo(marginPx, h - marginPx - bracketSize);
  ctx.lineTo(marginPx, h - marginPx);
  ctx.lineTo(marginPx + bracketSize, h - marginPx);
  ctx.stroke();
  // Bottom-right
  ctx.beginPath();
  ctx.moveTo(w - marginPx - bracketSize, h - marginPx);
  ctx.lineTo(w - marginPx, h - marginPx);
  ctx.lineTo(w - marginPx, h - marginPx - bracketSize);
  ctx.stroke();

  // 6. Bottom Edge Printer Model Branding Banner
  ctx.fillStyle = '#1e1e24';
  const bannerW = Math.min(w * 0.75, 600);
  const bannerX = (w - bannerW) / 2;
  ctx.fillRect(bannerX, h - 38, bannerW, 30);
  ctx.strokeStyle = '#3f3f46';
  ctx.lineWidth = 1;
  ctx.strokeRect(bannerX, h - 38, bannerW, 30);

  // Status Indicator Dot
  ctx.fillStyle = '#10b981'; // Emerald dot
  ctx.beginPath();
  ctx.arc(bannerX + 16, h - 23, 5, 0, Math.PI * 2);
  ctx.fill();

  // Typography
  ctx.fillStyle = '#f4f4f5';
  ctx.font = 'bold 12px Inter, -apple-system, sans-serif';
  ctx.textAlign = 'left';
  ctx.fillText(`${brand.toUpperCase()} • ${model}`, bannerX + 28, h - 24);

  ctx.fillStyle = '#a1a1aa';
  ctx.font = '10px "JetBrains Mono", Menlo, monospace';
  ctx.fillText(`${bw} × ${bh} mm Bed`, bannerX + 28, h - 12);

  // Top Edge Caution
  ctx.fillStyle = '#71717a';
  ctx.font = '10px Inter, -apple-system, sans-serif';
  ctx.textAlign = 'center';
  ctx.fillText('SPRING STEEL PEI BUILD PLATE • KEEP SURFACE CLEAN & OIL-FREE', w / 2, 22);

  return canvas;
}

function updateBuildPlate() {
  if (!scene) return;
  if (buildPlateGroup) {
    scene.remove(buildPlateGroup);
  }
  buildPlateGroup = new THREE.Group();

  const bw = state.printer.width || 256;
  const bh = state.printer.height || 256;

  const canvas = createUniversalPlateTexture(state.printer, state.isDark);
  const texture = new THREE.CanvasTexture(canvas);
  texture.needsUpdate = true;
  if (renderer) texture.anisotropy = renderer.capabilities.getMaxAnisotropy() || 8;

  // Build plate top surface with polygonOffset to guarantee zero depth-fighting
  const plateGeom = new THREE.PlaneGeometry(bw, bh);
  plateGeom.rotateX(-Math.PI / 2);

  const plateMat = new THREE.MeshStandardMaterial({
    map: texture,
    roughness: 0.82,
    metalness: 0.15,
    side: THREE.FrontSide,
    polygonOffset: true,
    polygonOffsetFactor: -2.0,
    polygonOffsetUnits: -4.0,
  });

  buildPlateMesh = new THREE.Mesh(plateGeom, plateMat);
  buildPlateMesh.position.y = 0.0; // Top surface strictly at y = 0
  buildPlateMesh.receiveShadow = true;
  buildPlateGroup.add(buildPlateMesh);

  // Spring steel metallic sheet underneath — strictly below top surface (y = -0.05 to y = -1.25)
  const sheetThickness = 1.2;
  const baseEdgeGeom = new THREE.BoxGeometry(bw + 1.2, sheetThickness, bh + 1.2);
  const baseEdgeMat = new THREE.MeshStandardMaterial({
    color: 0x27272a,
    roughness: 0.35,
    metalness: 0.85,
  });
  const baseEdgeMesh = new THREE.Mesh(baseEdgeGeom, baseEdgeMat);
  // Positioned so top of box is at y = -0.05 (strictly below y = 0.0), eliminating coplanar Z-fighting
  baseEdgeMesh.position.y = -(sheetThickness / 2) - 0.05;
  baseEdgeMesh.receiveShadow = true;
  buildPlateGroup.add(baseEdgeMesh);

  buildPlateGroup.visible = state.showBuildPlate;
  scene.add(buildPlateGroup);
  requestRender();
}
