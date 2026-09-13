/**
 * 2MF Studio — Three.js Viewport, 3D Mesh Generation & Slicer Layer Scrubber
 */

let scene, camera, renderer, controls, meshGroup, gridHelper;
let renderFrame = 0;

function init3D() {
  const container = document.getElementById('canvasContainer');
  if (!container) return;

  scene = new THREE.Scene();
  updateSceneBg();

  camera = new THREE.PerspectiveCamera(45, container.clientWidth / container.clientHeight, 0.5, 2000);
  camera.position.set(130, 160, 180);

  renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, powerPreference: "high-performance" });
  renderer.setSize(container.clientWidth, container.clientHeight);
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  renderer.shadowMap.enabled = true;
  container.appendChild(renderer.domElement);

  controls = new THREE.OrbitControls(camera, renderer.domElement);
  controls.enableDamping = false;
  controls.addEventListener('change', requestRender);

  const ambientLight = new THREE.AmbientLight(0xffffff, 0.9);
  scene.add(ambientLight);

  const dirLight1 = new THREE.DirectionalLight(0xffffff, 0.65);
  dirLight1.position.set(120, 220, 150);
  scene.add(dirLight1);

  const dirLight2 = new THREE.DirectionalLight(0xffffff, 0.35);
  dirLight2.position.set(-120, 120, -100);
  scene.add(dirLight2);

  updateGridColor();
  updateBuildPlate();

  meshGroup = new THREE.Group();
  scene.add(meshGroup);

  window.addEventListener('resize', onWindowResize);
  requestRender();
}

function updateSceneBg() {
  if (!scene) return;
  scene.background = new THREE.Color(state.isDark ? 0x09090b : 0xf4f4f5);
  requestRender();
}

function updateGridColor() {
  if (gridHelper) scene.remove(gridHelper);
  const c1 = state.isDark ? 0x71717a : 0xa1a1aa;
  const c2 = state.isDark ? 0x27272a : 0xe4e4e7;
  const bedSize = state.printer ? Math.max(state.printer.width, state.printer.height) : 256;
  const gridDivisions = Math.round(bedSize / 10);
  gridHelper = new THREE.GridHelper(bedSize, gridDivisions, c1, c2);
  gridHelper.position.y = -1.30; // Underneath the 1.25mm build plate stack
  gridHelper.material.depthWrite = false;
  gridHelper.visible = state.showGrid;
  scene.add(gridHelper);
  requestRender();
}

function onWindowResize() {
  const container = document.getElementById('canvasContainer');
  if (!container || !camera || !renderer) return;
  camera.aspect = container.clientWidth / container.clientHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(container.clientWidth, container.clientHeight);
  requestRender();
}

function requestRender() {
  if (renderFrame || !renderer || !scene || !camera) return;
  renderFrame = requestAnimationFrame(() => {
    renderFrame = 0;
    renderer.render(scene, camera);
  });
}

// Calibrated 3D Camera Snaps (Top-Down 3D, Isometric 3D, and Front)
function setCameraView(mode) {
  if (!camera || !controls) return;
  const bw = state.printer.width || 256;
  const bh = state.printer.height || 256;
  const maxBed = Math.max(bw, bh);

  controls.target.set(0, 0, 0);

  if (mode === 'top') {
    // Top-down 3D view: directly looking straight down from above the bed
    // Using 45° FOV, calculate exact altitude needed so full bed + 25% margin fits in view
    const fovRad = (camera.fov * Math.PI) / 360;
    const dist = (maxBed * 1.25) / (2 * Math.tan(fovRad));
    // Tiny +Z offset (0.01) avoids camera gimbal lock with OrbitControls,
    // ensuring screen UP is -Z (bed rear), screen DOWN is +Z (bed front branding)
    camera.position.set(0, dist, 0.01);
    camera.lookAt(0, 0, 0);
    controls.update();
  } else if (mode === 'iso') {
    camera.position.set(maxBed * 0.72, maxBed * 0.90, maxBed * 1.05);
    camera.lookAt(0, 0, 0);
    controls.update();
  } else if (mode === 'front') {
    const fovRad = (camera.fov * Math.PI) / 360;
    const dist = (maxBed * 1.35) / (2 * Math.tan(fovRad));
    camera.position.set(0, maxBed * 0.15, dist);
    camera.lookAt(0, 0, 0);
    controls.update();
  }
  requestRender();
}

// 3D Watertight Solid Object with Walls and Bottom Base
function update3DMesh() {
  if (!state.luminance || state.filaments.length === 0 || !meshGroup) return;
  while (meshGroup.children.length > 0) {
    meshGroup.remove(meshGroup.children[0]);
  }

  const gridRes = 180; // High resolution smooth grid
  const w_mm = state.dimensions.widthMm;
  const h_mm = state.dimensions.heightMm;
  const maxScrubZ = state.scrubLayer > 0 ? getLayerZ(state.scrubLayer) : state.dimensions.maxZ;
  const zScale = state.zScaleVisual;
  const yBot = 0.02; // Bottom resting flush on build plate

  const filRgbFloats = getFilamentRgb();
  const baseColor = filRgbFloats[0] || { r: 0.1, g: 0.1, b: 0.1 };

  // Pre-sample top Y values for each grid point
  const topY = new Float32Array(gridRes * gridRes);
  for (let j = 0; j < gridRes; j++) {
    const v = j / (gridRes - 1);
    for (let i = 0; i < gridRes; i++) {
      const u = i / (gridRes - 1);
      const lum = sampleLuminanceBilinear(u, v);
      let z = calculateZFromLum(lum);
      z = Math.min(z, maxScrubZ);
      topY[j * gridRes + i] = yBot + z * (zScale * 0.4);
    }
  }

  // Pre-calculate smooth normals for top surface
  const topNormals = new Float32Array(gridRes * gridRes * 3);
  const stepX = w_mm / (gridRes - 1);
  const stepZ = h_mm / (gridRes - 1);

  for (let j = 0; j < gridRes; j++) {
    for (let i = 0; i < gridRes; i++) {
      const idx = j * gridRes + i;
      const idxL = j * gridRes + Math.max(0, i - 1);
      const idxR = j * gridRes + Math.min(gridRes - 1, i + 1);
      const idxD = Math.max(0, j - 1) * gridRes + i;
      const idxU = Math.min(gridRes - 1, j + 1) * gridRes + i;

      const yL = topY[idxL];
      const yR = topY[idxR];
      const yD = topY[idxD];
      const yU = topY[idxU];

      const dxX = (Math.min(gridRes - 1, i + 1) - Math.max(0, i - 1)) * stepX;
      const dyZ = (Math.min(gridRes - 1, j + 1) - Math.max(0, j - 1)) * stepZ;

      const nx = -(yR - yL) * dyZ;
      const ny = dxX * dyZ;
      const nz = -(yU - yD) * dxX;
      const len = Math.sqrt(nx * nx + ny * ny + nz * nz) || 1.0;

      topNormals[idx * 3 + 0] = nx / len;
      topNormals[idx * 3 + 1] = ny / len;
      topNormals[idx * 3 + 2] = nz / len;
    }
  }

  const positions = [];
  const colors = [];
  const normals = [];
  const indices = [];

  let vertCount = 0;

  // 1. TOP SURFACE
  const topOffset = vertCount;
  for (let j = 0; j < gridRes; j++) {
    const v = j / (gridRes - 1);
    const zPos = (v - 0.5) * h_mm;
    for (let i = 0; i < gridRes; i++) {
      const u = i / (gridRes - 1);
      const xPos = (u - 0.5) * w_mm;
      const yPos = topY[j * gridRes + i];

      positions.push(xPos, yPos, zPos);

      const filIdx = sampleColorAtUV(u, v);
      const filColor = filRgbFloats[filIdx] || filRgbFloats[0];
      colors.push(filColor.r, filColor.g, filColor.b);

      const nIdx = (j * gridRes + i) * 3;
      normals.push(topNormals[nIdx], topNormals[nIdx + 1], topNormals[nIdx + 2]);
    }
  }
  vertCount += gridRes * gridRes;

  for (let j = 0; j < gridRes - 1; j++) {
    for (let i = 0; i < gridRes - 1; i++) {
      const p00 = topOffset + j * gridRes + i;
      const p10 = topOffset + j * gridRes + (i + 1);
      const p01 = topOffset + (j + 1) * gridRes + i;
      const p11 = topOffset + (j + 1) * gridRes + (i + 1);

      indices.push(p00, p11, p10);
      indices.push(p00, p01, p11);
    }
  }

  // 2. BOTTOM BASE (y = yBot, normals pointing down: 0, -1, 0)
  const botOffset = vertCount;
  for (let j = 0; j < gridRes; j++) {
    const v = j / (gridRes - 1);
    const zPos = (v - 0.5) * h_mm;
    for (let i = 0; i < gridRes; i++) {
      const u = i / (gridRes - 1);
      const xPos = (u - 0.5) * w_mm;

      positions.push(xPos, yBot, zPos);
      colors.push(baseColor.r, baseColor.g, baseColor.b);
      normals.push(0, -1, 0);
    }
  }
  vertCount += gridRes * gridRes;

  for (let j = 0; j < gridRes - 1; j++) {
    for (let i = 0; i < gridRes - 1; i++) {
      const p00 = botOffset + j * gridRes + i;
      const p10 = botOffset + j * gridRes + (i + 1);
      const p01 = botOffset + (j + 1) * gridRes + i;
      const p11 = botOffset + (j + 1) * gridRes + (i + 1);

      // Reversed winding for downward normal
      indices.push(p00, p10, p11);
      indices.push(p00, p11, p01);
    }
  }

  // 3. NORTH WALL (v = 0, z = -h_mm/2, normal = 0, 0, -1)
  const northOffset = vertCount;
  const zNorth = -0.5 * h_mm;
  for (let i = 0; i < gridRes; i++) {
    const u = i / (gridRes - 1);
    const xPos = (u - 0.5) * w_mm;
    const yTopVal = topY[0 * gridRes + i];

    const filIdx = sampleColorAtUV(u, 0);
    const topCol = filRgbFloats[filIdx] || baseColor;

    // Top vertex
    positions.push(xPos, yTopVal, zNorth);
    colors.push(topCol.r, topCol.g, topCol.b);
    normals.push(0, 0, -1);

    // Bottom vertex
    positions.push(xPos, yBot, zNorth);
    colors.push(baseColor.r, baseColor.g, baseColor.b);
    normals.push(0, 0, -1);
  }
  vertCount += gridRes * 2;

  for (let i = 0; i < gridRes - 1; i++) {
    const t0 = northOffset + i * 2;
    const b0 = northOffset + i * 2 + 1;
    const t1 = northOffset + (i + 1) * 2;
    const b1 = northOffset + (i + 1) * 2 + 1;

    indices.push(t0, t1, b0);
    indices.push(t1, b1, b0);
  }

  // 4. SOUTH WALL (v = 1, z = +h_mm/2, normal = 0, 0, 1)
  const southOffset = vertCount;
  const zSouth = 0.5 * h_mm;
  for (let i = 0; i < gridRes; i++) {
    const u = i / (gridRes - 1);
    const xPos = (u - 0.5) * w_mm;
    const yTopVal = topY[(gridRes - 1) * gridRes + i];

    const filIdx = sampleColorAtUV(u, 1);
    const topCol = filRgbFloats[filIdx] || baseColor;

    positions.push(xPos, yTopVal, zSouth);
    colors.push(topCol.r, topCol.g, topCol.b);
    normals.push(0, 0, 1);

    positions.push(xPos, yBot, zSouth);
    colors.push(baseColor.r, baseColor.g, baseColor.b);
    normals.push(0, 0, 1);
  }
  vertCount += gridRes * 2;

  for (let i = 0; i < gridRes - 1; i++) {
    const t0 = southOffset + i * 2;
    const b0 = southOffset + i * 2 + 1;
    const t1 = southOffset + (i + 1) * 2;
    const b1 = southOffset + (i + 1) * 2 + 1;

    indices.push(t0, b0, t1);
    indices.push(t1, b0, b1);
  }

  // 5. WEST WALL (u = 0, x = -w_mm/2, normal = -1, 0, 0)
  const westOffset = vertCount;
  const xWest = -0.5 * w_mm;
  for (let j = 0; j < gridRes; j++) {
    const v = j / (gridRes - 1);
    const zPos = (v - 0.5) * h_mm;
    const yTopVal = topY[j * gridRes + 0];

    const filIdx = sampleColorAtUV(0, v);
    const topCol = filRgbFloats[filIdx] || baseColor;

    positions.push(xWest, yTopVal, zPos);
    colors.push(topCol.r, topCol.g, topCol.b);
    normals.push(-1, 0, 0);

    positions.push(xWest, yBot, zPos);
    colors.push(baseColor.r, baseColor.g, baseColor.b);
    normals.push(-1, 0, 0);
  }
  vertCount += gridRes * 2;

  for (let j = 0; j < gridRes - 1; j++) {
    const t0 = westOffset + j * 2;
    const b0 = westOffset + j * 2 + 1;
    const t1 = westOffset + (j + 1) * 2;
    const b1 = westOffset + (j + 1) * 2 + 1;

    indices.push(t0, b0, t1);
    indices.push(t1, b0, b1);
  }

  // 6. EAST WALL (u = 1, x = +w_mm/2, normal = 1, 0, 0)
  const eastOffset = vertCount;
  const xEast = 0.5 * w_mm;
  for (let j = 0; j < gridRes; j++) {
    const v = j / (gridRes - 1);
    const zPos = (v - 0.5) * h_mm;
    const yTopVal = topY[j * gridRes + (gridRes - 1)];

    const filIdx = sampleColorAtUV(1, v);
    const topCol = filRgbFloats[filIdx] || baseColor;

    positions.push(xEast, yTopVal, zPos);
    colors.push(topCol.r, topCol.g, topCol.b);
    normals.push(1, 0, 0);

    positions.push(xEast, yBot, zPos);
    colors.push(baseColor.r, baseColor.g, baseColor.b);
    normals.push(1, 0, 0);
  }
  vertCount += gridRes * 2;

  for (let j = 0; j < gridRes - 1; j++) {
    const t0 = eastOffset + j * 2;
    const b0 = eastOffset + j * 2 + 1;
    const t1 = eastOffset + (j + 1) * 2;
    const b1 = eastOffset + (j + 1) * 2 + 1;

    indices.push(t0, t1, b0);
    indices.push(t1, b1, b0);
  }

  const geom = new THREE.BufferGeometry();
  geom.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
  geom.setAttribute('color', new THREE.Float32BufferAttribute(colors, 3));
  geom.setAttribute('normal', new THREE.Float32BufferAttribute(normals, 3));
  geom.setIndex(indices);

  const mat = new THREE.MeshStandardMaterial({
    vertexColors: true,
    roughness: 0.45,
    metalness: 0.05,
    wireframe: state.showWire,
    side: state.showWire ? THREE.DoubleSide : THREE.FrontSide,
  });

  const mesh = new THREE.Mesh(geom, mat);
  meshGroup.add(mesh);
  requestRender();
}

// 2D Quantized Slicer Preview
function update2DPreview() {
  const map = state.cleanColorMap || state.colorMapIndices;
  const canvas = document.getElementById('opticalCanvas');
  if (!map || state.filaments.length === 0 || !canvas) return;

  canvas.width = state.width;
  canvas.height = state.height;
  const ctx = canvas.getContext('2d');
  const imgData = ctx.createImageData(state.width, state.height);

  const filRgbBytes = getFilamentRgb().map(rgb => {
    return { r: Math.round(rgb.r * 255), g: Math.round(rgb.g * 255), b: Math.round(rgb.b * 255) };
  });

  for (let i = 0; i < state.width * state.height; i++) {
    const filIdx = map[i];
    const col = filRgbBytes[filIdx] || filRgbBytes[0];
    const outIdx = i * 4;
    imgData.data[outIdx] = col.r;
    imgData.data[outIdx + 1] = col.g;
    imgData.data[outIdx + 2] = col.b;
    imgData.data[outIdx + 3] = 255;
  }
  ctx.putImageData(imgData, 0, 0);
}

// Histogram Visualizer
function updateHistogram() {
  if (!state.luminance) return;
  const canvas = document.getElementById('histCanvas');
  if (!canvas) return;
  const ctx = canvas.getContext('2d');
  canvas.width = (canvas.clientWidth || 340) * 2;
  canvas.height = (canvas.clientHeight || 70) * 2;
  ctx.clearRect(0, 0, canvas.width, canvas.height);

  const bins = new Uint32Array(256);
  for (let i = 0; i < state.luminance.length; i++) {
    const bin = Math.min(255, Math.floor(state.luminance[i] * 255.5));
    bins[bin]++;
  }
  let maxBin = 1;
  for (let i = 0; i < 256; i++) if (bins[i] > maxBin) maxBin = bins[i];

  const barW = canvas.width / 256;
  ctx.fillStyle = state.isDark ? '#71717a88' : '#a1a1aa99';
  for (let i = 0; i < 256; i++) {
    const h = (bins[i] / maxBin) * canvas.height;
    ctx.fillRect(i * barW, canvas.height - h, barW, h);
  }

  const zRange = state.dimensions.maxZ - state.dimensions.minZ;
  state.filaments.forEach(fil => {
    const normZ = Math.min(Math.max((fil.endZ - state.dimensions.minZ) / zRange, 0.0), 1.0);
    const x = normZ * canvas.width;
    ctx.strokeStyle = fil.color;
    ctx.lineWidth = 2.5;
    ctx.beginPath();
    ctx.moveTo(x, 0);
    ctx.lineTo(x, canvas.height);
    ctx.stroke();
  });
}

// Slicer Swap Schedule Table
function updateSwapTable() {
  const tbody = document.getElementById('swapTableBody');
  if (!tbody) return;
  tbody.innerHTML = '';
  let prevLayer = 1;

  state.filaments.forEach((fil, idx) => {
    const endL = Math.max(1, Math.round((fil.endZ - state.dimensions.firstLayerHeight) / state.dimensions.layerHeight) + 1);
    const row = document.createElement('tr');
    row.className = 'hover:bg-zinc-100 dark:hover:bg-zinc-900/50';
    row.innerHTML = `
      <td class="p-1.5 font-bold text-zinc-700 dark:text-zinc-300">#${fil.slot}</td>
      <td class="p-1.5 flex items-center gap-1.5 truncate">
        <span class="w-3 h-3 rounded-full border border-zinc-400 dark:border-zinc-700 inline-block shrink-0" style="background-color: ${fil.color}"></span>
        <span class="truncate text-zinc-800 dark:text-zinc-200 font-medium">${fil.name}</span>
      </td>
      <td class="p-1.5 text-zinc-600 dark:text-zinc-400">${idx === 0 ? `1 &rarr; ${endL}` : `${prevLayer} &rarr; ${endL}`}</td>
      <td class="p-1.5 text-zinc-500 font-mono text-[10px]">${fil.startZ.toFixed(2)}-${fil.endZ.toFixed(2)}mm</td>
    `;
    tbody.appendChild(row);
    prevLayer = endL;
  });

  const maxL = Math.max(1, Math.round((state.dimensions.maxZ - state.dimensions.firstLayerHeight) / state.dimensions.layerHeight) + 1);
  const scrubber = document.getElementById('scrubberSlider');
  if (scrubber) {
    scrubber.max = maxL;
    const scrubLabel = document.getElementById('scrubberLabel');
    if (scrubLabel && state.scrubLayer === 0) {
      scrubLabel.innerText = `Layer All (${state.dimensions.maxZ.toFixed(2)} mm)`;
    }
  }
}
