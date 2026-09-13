/**
 * 2MF Studio — Heightfield Computation, Bilateral Denoising & Layer Quantization
 */

function recomputeLuminance() {
  if (!state.image || state.filaments.length === 0) return;
  const count = state.width * state.height;
  state.luminance = new Float32Array(count);
  state.colorMapIndices = new Uint8Array(count);
  const data = state.image.data;
  const adj = state.adjustments;
  const invGamma = adj.gamma > 0.01 ? 1.0 / adj.gamma : 1.0;
  const filCount = state.filaments.length;
  const filamentRgb = getFilamentRgb();

  for (let i = 0; i < count; i++) {
    const idx = i * 4;
    const r = data[idx];
    const g = data[idx + 1];
    const b = data[idx + 2];

    // 1. Find nearest matching filament color strictly from the auto-chosen palette
    let bestDist = Infinity;
    let bestFilIdx = 0;
    for (let f = 0; f < filCount; f++) {
      const filRgb = filamentRgb[f];
      const dr = (r - filRgb.r * 255);
      const dg = (g - filRgb.g * 255);
      const db = (b - filRgb.b * 255);
      // Perceptually weighted color distance
      const dist = 0.299 * dr * dr + 0.587 * dg * dg + 0.114 * db * db;
      if (dist < bestDist) {
        bestDist = dist;
        bestFilIdx = f;
      }
    }
    state.colorMapIndices[i] = bestFilIdx;

    // 2. Compute Physical Height from tone
    const rLin = srgbToLinear(r / 255.0);
    const gLin = srgbToLinear(g / 255.0);
    const bLin = srgbToLinear(b / 255.0);
    let l = 0.2126 * rLin + 0.7152 * gLin + 0.0722 * bLin;

    // Contrast & Brightness
    l = (l - 0.5) * adj.contrast + 0.5;
    l = l + adj.brightness;
    l = Math.max(0.0, Math.min(1.0, l));
    l = Math.pow(l, invGamma);

    if (adj.invert) l = 1.0 - l;
    state.luminance[i] = l;
  }

  applySmoothingAndDenoise();
  updateHistogram();
  update2DPreview();
  update3DMesh();
  updateSwapTable();
}

// Edge-Preserving Bilateral Smoothing, Outlier Despeckling, and Color Modal Filter
function applySmoothingAndDenoise() {
  if (!state.luminance) return;
  const w = state.width;
  const h = state.height;
  const count = w * h;

  let current = new Float32Array(state.luminance);
  let temp = new Float32Array(count);

  // 1. Spike / Outlier Despeckling (removes single-pixel needle spikes and digital sensor grain)
  if (state.despike) {
    for (let y = 1; y < h - 1; y++) {
      const row = y * w;
      for (let x = 1; x < w - 1; x++) {
        const idx = row + x;
        const center = current[idx];

        const n0 = current[idx - w - 1];
        const n1 = current[idx - w];
        const n2 = current[idx - w + 1];
        const n3 = current[idx - 1];
        const n4 = current[idx + 1];
        const n5 = current[idx + w - 1];
        const n6 = current[idx + w];
        const n7 = current[idx + w + 1];

        const minN = Math.min(n0, n1, n2, n3, n4, n5, n6, n7);
        const maxN = Math.max(n0, n1, n2, n3, n4, n5, n6, n7);
        const avgN = (n0 + n1 + n2 + n3 + n4 + n5 + n6 + n7) * 0.125;

        // If center is an extreme outlier spike, clamp towards local neighborhood mean
        if (center > maxN + 0.035) {
          temp[idx] = maxN * 0.7 + avgN * 0.3;
        } else if (center < minN - 0.035) {
          temp[idx] = minN * 0.7 + avgN * 0.3;
        } else {
          temp[idx] = center;
        }
      }
    }
    for (let x = 0; x < w; x++) { temp[x] = current[x]; temp[(h - 1) * w + x] = current[(h - 1) * w + x]; }
    for (let y = 0; y < h; y++) { temp[y * w] = current[y * w]; temp[y * w + w - 1] = current[y * w + w - 1]; }
    current.set(temp);
  }

  // 2. Multi-Pass Edge-Preserving Bilateral Smoothing
  const passes = Math.round(state.smoothingRadius * 2);
  const sigmaRangeSq = 0.07 * 0.07; // Edge preservation threshold

  for (let p = 0; p < passes; p++) {
    // Horizontal pass
    for (let y = 0; y < h; y++) {
      const row = y * w;
      for (let x = 0; x < w; x++) {
        const idx = row + x;
        const cVal = current[idx];
        let sum = cVal * 0.5;
        let weightSum = 0.5;

        if (x > 0) {
          const lVal = current[idx - 1];
          const diff = lVal - cVal;
          const wL = Math.exp(-(diff * diff) / sigmaRangeSq) * 0.25;
          sum += lVal * wL;
          weightSum += wL;
        }
        if (x < w - 1) {
          const rVal = current[idx + 1];
          const diff = rVal - cVal;
          const wR = Math.exp(-(diff * diff) / sigmaRangeSq) * 0.25;
          sum += rVal * wR;
          weightSum += wR;
        }
        temp[idx] = sum / weightSum;
      }
    }

    // Vertical pass
    for (let y = 0; y < h; y++) {
      const row = y * w;
      for (let x = 0; x < w; x++) {
        const idx = row + x;
        const cVal = temp[idx];
        let sum = cVal * 0.5;
        let weightSum = 0.5;

        if (y > 0) {
          const tVal = temp[idx - w];
          const diff = tVal - cVal;
          const wT = Math.exp(-(diff * diff) / sigmaRangeSq) * 0.25;
          sum += tVal * wT;
          weightSum += wT;
        }
        if (y < h - 1) {
          const bVal = temp[idx + w];
          const diff = bVal - cVal;
          const wB = Math.exp(-(diff * diff) / sigmaRangeSq) * 0.25;
          sum += bVal * wB;
          weightSum += wB;
        }
        current[idx] = sum / weightSum;
      }
    }
  }

  state.smoothedLuminance = current;

  // 3. Color Map Modal Filter (Eliminates isolated 1-pixel color speckling)
  if (state.colorMapIndices && state.despike) {
    const rawMap = state.colorMapIndices;
    const cleanMap = new Uint8Array(rawMap.length);
    const k = state.filaments.length;

    for (let y = 1; y < h - 1; y++) {
      const row = y * w;
      for (let x = 1; x < w - 1; x++) {
        const idx = row + x;
        const centerCol = rawMap[idx];

        let counts = new Uint8Array(k);
        counts[centerCol]++;
        counts[rawMap[idx - w - 1]]++;
        counts[rawMap[idx - w]]++;
        counts[rawMap[idx - w + 1]]++;
        counts[rawMap[idx - 1]]++;
        counts[rawMap[idx + 1]]++;
        counts[rawMap[idx + w - 1]]++;
        counts[rawMap[idx + w]]++;
        counts[rawMap[idx + w + 1]]++;

        let maxCount = 0;
        let bestCol = centerCol;
        for (let c = 0; c < k; c++) {
          if (counts[c] > maxCount) {
            maxCount = counts[c];
            bestCol = c;
          }
        }
        cleanMap[idx] = (maxCount >= 5) ? bestCol : centerCol;
      }
    }
    for (let x = 0; x < w; x++) { cleanMap[x] = rawMap[x]; cleanMap[(h - 1) * w + x] = rawMap[(h - 1) * w + x]; }
    for (let y = 0; y < h; y++) { cleanMap[y * w] = rawMap[y * w]; cleanMap[y * w + w - 1] = rawMap[y * w + w - 1]; }
    state.cleanColorMap = cleanMap;
  } else {
    state.cleanColorMap = state.colorMapIndices;
  }
}

function sampleLuminanceBilinear(u, v) {
  const lum = state.smoothedLuminance || state.luminance;
  if (!lum) return 0;
  const x = Math.max(0, Math.min(state.width - 1, u * (state.width - 1)));
  const y = Math.max(0, Math.min(state.height - 1, v * (state.height - 1)));
  const x0 = Math.floor(x);
  const x1 = Math.min(state.width - 1, x0 + 1);
  const y0 = Math.floor(y);
  const y1 = Math.min(state.height - 1, y0 + 1);
  const fx = x - x0;
  const fy = y - y0;

  const v00 = lum[y0 * state.width + x0];
  const v10 = lum[y0 * state.width + x1];
  const v01 = lum[y1 * state.width + x0];
  const v11 = lum[y1 * state.width + x1];

  return (v00 * (1.0 - fx) + v10 * fx) * (1.0 - fy) + (v01 * (1.0 - fx) + v11 * fx) * fy;
}

function sampleColorAtUV(u, v) {
  const map = state.cleanColorMap || state.colorMapIndices;
  if (!map) return 0;
  const x = Math.round(Math.max(0, Math.min(state.width - 1, u * (state.width - 1))));
  const y = Math.round(Math.max(0, Math.min(state.height - 1, v * (state.height - 1))));
  return map[y * state.width + x] || 0;
}

function calculateZFromLum(lum) {
  const zRange = state.dimensions.maxZ - state.dimensions.minZ;
  let z = state.dimensions.minZ + lum * zRange;

  if (state.quantizeLayers && z > state.dimensions.firstLayerHeight) {
    const extra = z - state.dimensions.firstLayerHeight;
    const stepSize = state.dimensions.layerHeight;
    const stepFloat = extra / stepSize;

    if (state.smoothTerraces) {
      const baseStep = Math.floor(stepFloat);
      const frac = stepFloat - baseStep;
      // Smoothstep curve: 3*x^2 - 2*x^3 eliminates micro-cliff spikes
      const smoothFrac = frac * frac * (3.0 - 2.0 * frac);
      const smoothedStep = baseStep + smoothFrac;
      z = state.dimensions.firstLayerHeight + smoothedStep * stepSize;
    } else {
      const steps = Math.round(stepFloat);
      z = state.dimensions.firstLayerHeight + steps * stepSize;
    }
  }

  return Math.min(Math.max(z, state.dimensions.minZ), state.dimensions.maxZ);
}
