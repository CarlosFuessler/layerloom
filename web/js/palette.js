/**
 * 2MF Studio — Automatic K-Means Color Clustering & Slicer Filament Palette
 */

// K-Means Dominant Color Clustering (Up to 16 Filament Colors / 4x AMS)
function autoExtractFilaments(targetCount = 4) {
  if (!state.image) return;
  const data = state.image.data;
  const count = state.width * state.height;

  // Sample pixels evenly
  const samples = [];
  const step = Math.max(1, Math.floor(count / 2500)); // Sample ~2500 pixels for fast, robust clustering
  for (let i = 0; i < count; i += step) {
    const idx = i * 4;
    const r = data[idx];
    const g = data[idx + 1];
    const b = data[idx + 2];
    const lum = 0.2126 * r + 0.7152 * g + 0.0722 * b;
    samples.push({ r, g, b, lum });
  }

  if (samples.length === 0) return;

  // Initialize K centroids evenly spread across luminance (clamped to 2..16)
  samples.sort((a, b) => a.lum - b.lum);
  const k = Math.min(16, Math.max(2, targetCount));
  let centroids = [];
  for (let i = 0; i < k; i++) {
    const sampleIdx = Math.min(samples.length - 1, Math.floor((i + 0.5) * (samples.length / k)));
    const s = samples[sampleIdx];
    centroids.push({ r: s.r, g: s.g, b: s.b });
  }

  // K-Means clustering iterations
  for (let iter = 0; iter < 4; iter++) {
    const clusters = Array.from({ length: k }, () => ({ sumR: 0, sumG: 0, sumB: 0, count: 0 }));
    for (let s of samples) {
      let bestDist = Infinity;
      let bestCluster = 0;
      for (let c = 0; c < k; c++) {
        const dr = s.r - centroids[c].r;
        const dg = s.g - centroids[c].g;
        const db = s.b - centroids[c].b;
        const dist = dr * dr + dg * dg + db * db;
        if (dist < bestDist) {
          bestDist = dist;
          bestCluster = c;
        }
      }
      clusters[bestCluster].sumR += s.r;
      clusters[bestCluster].sumG += s.g;
      clusters[bestCluster].sumB += s.b;
      clusters[bestCluster].count++;
    }

    for (let c = 0; c < k; c++) {
      if (clusters[c].count > 0) {
        centroids[c] = {
          r: Math.round(clusters[c].sumR / clusters[c].count),
          g: Math.round(clusters[c].sumG / clusters[c].count),
          b: Math.round(clusters[c].sumB / clusters[c].count),
        };
      }
    }
  }

  // Sort centroids strictly from Darkest (Base 1) to Lightest (Highlight K)
  centroids.sort((a, b) => {
    const lumA = 0.2126 * a.r + 0.7152 * a.g + 0.0722 * a.b;
    const lumB = 0.2126 * b.r + 0.7152 * b.g + 0.0722 * b.b;
    return lumA - lumB;
  });

  // Build Filament List
  state.filaments = centroids.map((c, idx) => {
    const hex = rgbToHex(c.r, c.g, c.b);
    const name = idx === 0 ? "Base Dark" : idx === k - 1 ? "Top Highlight" : `Layer Color ${idx + 1}`;
    return {
      name: name,
      color: hex,
      rgb: c,
      td: idx === 0 ? 0.6 : (2.0 + idx * 1.2),
      startZ: 0,
      endZ: 0,
      slot: idx + 1,
    };
  });

  autoDistributeZ();
  renderFilamentCards();
}

function renderFilamentCards() {
  const container = document.getElementById('filamentList');
  if (!container) return;
  container.innerHTML = '';

  const totalDepth = Math.max(0.01, state.dimensions.maxZ - state.dimensions.minZ);
  const k = state.filaments.length;

  state.filaments.forEach((fil, idx) => {
    const card = document.createElement('div');
    card.className = 'bg-white dark:bg-zinc-900/80 p-3 rounded-2xl border border-zinc-200 dark:border-zinc-800 shadow-xs space-y-2.5 interactive-card';
    
    const layerThickness = Math.max(0, fil.endZ - fil.startZ);
    const layerPercent = Math.round((layerThickness / totalDepth) * 100);

    // If more than 4 filaments, show AMS unit tray tag (e.g. A1..A4, B1..B4, C1..C4, D1..D4)
    const amsUnit = String.fromCharCode(65 + Math.floor((fil.slot - 1) / 4));
    const amsTray = ((fil.slot - 1) % 4) + 1;
    const amsTag = k > 4 ? ` · ${amsUnit}${amsTray}` : '';

    card.innerHTML = `
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-2.5">
          <div class="relative flex items-center justify-center">
            <input type="color" value="${fil.color}" data-idx="${idx}" class="colorPicker w-7 h-7 rounded-xl cursor-pointer bg-transparent border-0 shadow-xs">
          </div>
          <div>
            <input type="text" value="${fil.name}" data-idx="${idx}" class="nameInput bg-transparent hover:bg-zinc-50 dark:hover:bg-zinc-800/60 focus:bg-zinc-50 dark:focus:bg-zinc-800 border border-transparent focus:border-zinc-300 dark:focus:border-zinc-700 rounded-lg px-1.5 py-0.5 text-xs text-zinc-900 dark:text-zinc-100 font-semibold w-32 transition">
            <span class="text-[10px] font-mono text-zinc-400 block px-1.5">${fil.color.toUpperCase()}</span>
          </div>
        </div>
        <div class="flex flex-col items-end gap-0.5">
          <span class="text-[10px] bg-zinc-100 dark:bg-zinc-800 text-zinc-700 dark:text-zinc-300 px-2 py-0.5 rounded-md font-mono font-semibold">Slot ${fil.slot}${amsTag}</span>
          <span class="text-[9px] text-zinc-400 font-mono">${layerPercent}% vol</span>
        </div>
      </div>
      <div class="grid grid-cols-2 gap-2 text-[11px] pt-1 border-t border-zinc-100 dark:border-zinc-800/60">
        <div>
          <span class="text-zinc-400 block text-[10px] mb-0.5">Start Height</span>
          <div class="relative">
            <input type="number" step="0.08" value="${fil.startZ.toFixed(2)}" data-idx="${idx}" class="startZInput w-full bg-zinc-50 dark:bg-zinc-950/70 border border-zinc-200 dark:border-zinc-800 rounded-xl px-2.5 py-1.5 font-mono text-zinc-800 dark:text-zinc-200 text-xs focus:ring-1 focus:ring-zinc-400 dark:focus:ring-zinc-600 focus:outline-none">
            <span class="absolute right-2.5 top-1.5 text-[10px] text-zinc-400 pointer-events-none">mm</span>
          </div>
        </div>
        <div>
          <span class="text-zinc-400 block text-[10px] mb-0.5">End Height</span>
          <div class="relative">
            <input type="number" step="0.08" value="${fil.endZ.toFixed(2)}" data-idx="${idx}" class="endZInput w-full bg-zinc-50 dark:bg-zinc-950/70 border border-zinc-200 dark:border-zinc-800 rounded-xl px-2.5 py-1.5 font-mono text-zinc-800 dark:text-zinc-200 text-xs focus:ring-1 focus:ring-zinc-400 dark:focus:ring-zinc-600 focus:outline-none">
            <span class="absolute right-2.5 top-1.5 text-[10px] text-zinc-400 pointer-events-none">mm</span>
          </div>
        </div>
      </div>
    `;
    container.appendChild(card);
  });

  container.querySelectorAll('.colorPicker').forEach(el => {
    el.oninput = (e) => {
      state.filaments[e.target.dataset.idx].color = e.target.value;
      recomputeLuminance();
    };
  });
  container.querySelectorAll('.nameInput').forEach(el => {
    el.onchange = (e) => {
      state.filaments[e.target.dataset.idx].name = e.target.value;
      updateSwapTable();
    };
  });
  container.querySelectorAll('.startZInput').forEach(el => {
    el.onchange = (e) => {
      state.filaments[e.target.dataset.idx].startZ = parseFloat(e.target.value);
      recomputeLuminance();
    };
  });
  container.querySelectorAll('.endZInput').forEach(el => {
    el.onchange = (e) => {
      state.filaments[e.target.dataset.idx].endZ = parseFloat(e.target.value);
      recomputeLuminance();
    };
  });
}

function autoDistributeZ() {
  const minZ = state.dimensions.minZ;
  const maxZ = state.dimensions.maxZ;
  const count = state.filaments.length;
  if (count === 0) return;
  const step = (maxZ - minZ) / count;
  state.filaments.forEach((fil, idx) => {
    fil.startZ = minZ + idx * step;
    fil.endZ = minZ + (idx + 1) * step;
  });
  renderFilamentCards();
  recomputeLuminance();
}
