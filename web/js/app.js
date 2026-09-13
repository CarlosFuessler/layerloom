/**
 * 2MF Studio — Application Entrypoint, Event Listeners & Lifecycle Setup
 */

let recomputeTimer = 0;

function scheduleRecomputeLuminance() {
  window.clearTimeout(recomputeTimer);
  recomputeTimer = window.setTimeout(() => {
    recomputeTimer = 0;
    recomputeLuminance();
  }, 120);
}

function processImageFile(file) {
  if (!file) return;
  const reader = new FileReader();
  reader.onload = (e) => {
    const img = new Image();
    img.onload = () => {
      const maxDim = 1024;
      let w = img.width;
      let h = img.height;
      if (w > maxDim || h > maxDim) {
        if (w > h) {
          h = Math.round((h * maxDim) / w);
          w = maxDim;
        } else {
          w = Math.round((w * maxDim) / h);
          h = maxDim;
        }
      }

      const canvas = document.createElement('canvas');
      canvas.width = w;
      canvas.height = h;
      const ctx = canvas.getContext('2d');
      ctx.drawImage(img, 0, 0, w, h);

      state.sourceCanvas = canvas;
      state.image = ctx.getImageData(0, 0, w, h);
      state.width = w;
      state.height = h;

      const thumbImg = document.getElementById('thumbImg');
      const statusText = document.getElementById('imageStatusText');
      const dimText = document.getElementById('imageDimText');
      if (thumbImg) thumbImg.src = canvas.toDataURL();
      if (statusText) statusText.innerText = file.name || "Custom Image";
      if (dimText) dimText.innerText = `${img.width} x ${img.height} px`;

      // Auto fit to active bed
      const ar = w / h;
      const bedW = (state.printer.width || 256) - 16;
      const bedH = (state.printer.height || 256) - 16;
      if (ar >= 1.0) {
        state.dimensions.widthMm = Math.min(150, bedW);
        state.dimensions.heightMm = Math.round((state.dimensions.widthMm / ar) * 10) / 10;
      } else {
        state.dimensions.heightMm = Math.min(150, bedH);
        state.dimensions.widthMm = Math.round((state.dimensions.heightMm * ar) * 10) / 10;
      }
      const inputW = document.getElementById('inputWidth');
      const inputH = document.getElementById('inputHeight');
      if (inputW) inputW.value = state.dimensions.widthMm;
      if (inputH) inputH.value = state.dimensions.heightMm;

      // Extract colors from uploaded image
      autoExtractFilaments(state.maxColorCount);
      showToast(`Imported & extracted ${state.maxColorCount} filament colors!`);
    };
    img.src = e.target.result;
  };
  reader.readAsDataURL(file);
}

function generateSampleArt(w = 512, h = 512) {
  const canvas = document.createElement('canvas');
  canvas.width = w;
  canvas.height = h;
  const ctx = canvas.getContext('2d');

  const grad = ctx.createLinearGradient(0, 0, 0, h);
  grad.addColorStop(0, '#1e1b4b');
  grad.addColorStop(0.3, '#be185d');
  grad.addColorStop(0.6, '#f97316');
  grad.addColorStop(0.8, '#fde047');
  grad.addColorStop(1, '#0f172a');
  ctx.fillStyle = grad;
  ctx.fillRect(0, 0, w, h);

  ctx.fillStyle = '#ffffff';
  ctx.beginPath();
  ctx.arc(w * 0.5, h * 0.42, 45, 0, Math.PI * 2);
  ctx.fill();

  ctx.fillStyle = '#312e81';
  ctx.beginPath();
  ctx.moveTo(0, h * 0.7);
  ctx.lineTo(w * 0.3, h * 0.48);
  ctx.lineTo(w * 0.6, h * 0.68);
  ctx.lineTo(w, h * 0.52);
  ctx.lineTo(w, h);
  ctx.lineTo(0, h);
  ctx.fill();

  ctx.fillStyle = '#09090b';
  ctx.beginPath();
  ctx.moveTo(0, h * 0.82);
  ctx.quadraticCurveTo(w * 0.4, h * 0.72, w * 0.7, h * 0.88);
  ctx.quadraticCurveTo(w * 0.85, h * 0.95, w, h * 0.84);
  ctx.lineTo(w, h);
  ctx.lineTo(0, h);
  ctx.fill();

  state.sourceCanvas = canvas;
  state.image = ctx.getImageData(0, 0, w, h);
  state.width = w;
  state.height = h;

  const thumbImg = document.getElementById('thumbImg');
  const statusText = document.getElementById('imageStatusText');
  const dimText = document.getElementById('imageDimText');
  if (thumbImg) thumbImg.src = canvas.toDataURL();
  if (statusText) statusText.innerText = "Sample Sunset";
  if (dimText) dimText.innerText = `${w} x ${h} px`;

  autoExtractFilaments(state.maxColorCount);
}

function switchTab(tab) {
  const tabs = ['Filaments', 'Relief', 'Printers'];
  tabs.forEach(t => {
    const btn = document.getElementById(`tabBtn${t}`);
    const content = document.getElementById(`tabContent${t}`);
    if (!btn || !content) return;
    if (t.toLowerCase() === tab.toLowerCase() || t === tab) {
      btn.className = "flex-1 py-1.5 px-2.5 rounded-lg text-zinc-900 dark:text-zinc-100 bg-white dark:bg-zinc-800 shadow-sm transition font-semibold text-xs";
      content.classList.remove('hidden');
    } else {
      btn.className = "flex-1 py-1.5 px-2.5 rounded-lg text-zinc-500 dark:text-zinc-400 hover:text-zinc-900 dark:hover:text-zinc-100 transition font-medium text-xs";
      content.classList.add('hidden');
    }
  });
  if (tab.toLowerCase() === 'filaments') {
    requestAnimationFrame(() => updateHistogram());
  }
}

window.onload = () => {
  init3D();
  generateSampleArt(512, 512);
  setupPrinterManager();

  // Color Count Switcher (2..16 colors, supporting up to 4x Bambu AMS daisy-chain)
  function setColorCount(count, notify = false) {
    const clamped = Math.max(2, Math.min(16, parseInt(count) || 4));
    state.maxColorCount = clamped;

    const slider = document.getElementById('sliderColorCount');
    if (slider && parseInt(slider.value) !== clamped) {
      slider.value = clamped;
    }

    const label = document.getElementById('slotCountLabel');
    if (label) {
      let amsInfo = "";
      if (clamped === 4) amsInfo = " • 1 AMS";
      else if (clamped === 8) amsInfo = " • 2 AMS";
      else if (clamped === 12) amsInfo = " • 3 AMS";
      else if (clamped === 16) amsInfo = " • 4 AMS (Max)";
      else if (clamped === 5) amsInfo = " • MMU / Toolhead";
      else if (clamped === 2) amsInfo = " • Dual Extrusion";
      else {
        const amsUnits = Math.ceil(clamped / 4);
        if (amsUnits > 1) amsInfo = ` • ${amsUnits} AMS Units`;
      }
      label.innerText = `${clamped} Colors${amsInfo}`;
    }

    document.querySelectorAll('.btnColorCount').forEach(b => {
      const bCount = parseInt(b.dataset.count);
      if (bCount === clamped) {
        b.className = "btnColorCount py-1.5 rounded-xl bg-zinc-900 text-white dark:bg-zinc-100 dark:text-zinc-900 font-semibold shadow-xs text-center border border-zinc-900 dark:border-zinc-100 transition active:scale-95";
      } else {
        b.className = "btnColorCount py-1.5 rounded-xl bg-zinc-100 dark:bg-zinc-800/80 text-zinc-600 dark:text-zinc-400 hover:text-zinc-900 dark:hover:text-zinc-100 border border-zinc-200 dark:border-zinc-700/80 text-center font-medium transition active:scale-95";
      }
    });

    autoExtractFilaments(clamped);
    if (notify) {
      showToast(`Palette configured to ${clamped} filament colors!`);
    }
  }

  // Stepper & Range Slider bindings
  const sliderColorCount = document.getElementById('sliderColorCount');
  if (sliderColorCount) {
    sliderColorCount.oninput = (e) => {
      setColorCount(e.target.value, false);
    };
    sliderColorCount.onchange = (e) => {
      showToast(`Configured ${state.maxColorCount} filament colors!`);
    };
  }

  const btnColorMinus = document.getElementById('btnColorMinus');
  if (btnColorMinus) {
    btnColorMinus.onclick = () => {
      if (state.maxColorCount > 2) {
        setColorCount(state.maxColorCount - 1, true);
      }
    };
  }

  const btnColorPlus = document.getElementById('btnColorPlus');
  if (btnColorPlus) {
    btnColorPlus.onclick = () => {
      if (state.maxColorCount < 16) {
        setColorCount(state.maxColorCount + 1, true);
      }
    };
  }

  // Quick Hardware Preset Buttons
  document.querySelectorAll('.btnColorCount').forEach(btn => {
    btn.onclick = (e) => {
      const count = parseInt(btn.dataset.count || e.currentTarget.dataset.count);
      setColorCount(count, true);
    };
  });

  setColorCount(state.maxColorCount, false);

  const reExtractBtn = document.getElementById('btnReExtract');
  if (reExtractBtn) {
    reExtractBtn.onclick = () => {
      autoExtractFilaments(state.maxColorCount);
      showToast(`Auto-detected ${state.maxColorCount} colors!`);
    };
  }

  // Z-Scale Exaggeration Slider
  const zScaleSlider = document.getElementById('sliderZScale');
  if (zScaleSlider) {
    zScaleSlider.oninput = (e) => {
      state.zScaleVisual = parseFloat(e.target.value);
      const valLabel = document.getElementById('valZScale');
      if (valLabel) valLabel.innerText = `${state.zScaleVisual.toFixed(1)}x`;
      update3DMesh();
    };
  }

  // Theme toggle
  const themeToggleBtn = document.getElementById('btnToggleTheme');
  if (themeToggleBtn) {
    themeToggleBtn.onclick = () => {
      state.isDark = !state.isDark;
      if (state.isDark) {
        document.documentElement.classList.add('dark');
      } else {
        document.documentElement.classList.remove('dark');
      }
      updateSceneBg();
      updateGridColor();
      updateBuildPlate();
      updateHistogram();
    };
  }

  // Tabs
  const tabFil = document.getElementById('tabBtnFilaments');
  if (tabFil) tabFil.onclick = () => switchTab('Filaments');
  const tabRel = document.getElementById('tabBtnRelief');
  if (tabRel) tabRel.onclick = () => switchTab('Relief');
  const tabPri = document.getElementById('tabBtnPrinters');
  if (tabPri) tabPri.onclick = () => switchTab('Printers');
  const headerPriBadge = document.getElementById('headerPrinterBadgeBtn');
  if (headerPriBadge) headerPriBadge.onclick = () => switchTab('Printers');

  // File input & Drag/Drop
  const fileInput = document.getElementById('fileInput');
  if (fileInput) {
    fileInput.onchange = (e) => {
      if (e.target.files && e.target.files[0]) processImageFile(e.target.files[0]);
    };
  }

  const dropzone = document.getElementById('dropzone');
  if (dropzone && fileInput) dropzone.onclick = () => fileInput.click();

  window.addEventListener('dragover', (e) => e.preventDefault());
  window.addEventListener('drop', (e) => {
    e.preventDefault();
    if (e.dataTransfer.files && e.dataTransfer.files[0]) processImageFile(e.dataTransfer.files[0]);
  });

  window.addEventListener('paste', (e) => {
    const items = (e.clipboardData || e.originalEvent.clipboardData)?.items;
    if (!items) return;
    for (let index in items) {
      const item = items[index];
      if (item.kind === 'file' && item.type.startsWith('image/')) {
        const blob = item.getAsFile();
        processImageFile(blob);
        break;
      }
    }
  });

  const autoDistBtn = document.getElementById('btnAutoDistribute');
  if (autoDistBtn) autoDistBtn.onclick = autoDistributeZ;

  // Depth Presets
  document.querySelectorAll('.btnDepthPreset').forEach(btn => {
    btn.onclick = (e) => {
      const maxZ = parseFloat(e.target.dataset.maxz);
      const minZ = parseFloat(e.target.dataset.minz);
      state.dimensions.maxZ = maxZ;
      state.dimensions.minZ = minZ;

      const sliderMaxZ = document.getElementById('sliderMaxZ');
      const valMaxZ = document.getElementById('valMaxZ');
      const sliderMinZ = document.getElementById('sliderMinZ');
      const valMinZ = document.getElementById('valMinZ');
      if (sliderMaxZ) sliderMaxZ.value = maxZ;
      if (valMaxZ) valMaxZ.innerText = `${maxZ.toFixed(2)} mm`;
      if (sliderMinZ) sliderMinZ.value = minZ;
      if (valMinZ) valMinZ.innerText = `${minZ.toFixed(2)} mm`;

      document.querySelectorAll('.btnDepthPreset').forEach(b => {
        b.className = "btnDepthPreset py-1.5 rounded-xl bg-zinc-100 dark:bg-zinc-800 text-zinc-700 dark:text-zinc-300 border border-zinc-200 dark:border-zinc-700 text-center font-medium";
      });
      e.target.className = "btnDepthPreset py-1.5 rounded-xl bg-zinc-900 text-white dark:bg-zinc-100 dark:text-zinc-900 font-semibold shadow-sm text-center";

      const presetLabel = document.getElementById('presetDepthLabel');
      if (presetLabel) presetLabel.innerText = `${maxZ.toFixed(1)}mm (${maxZ >= 6.5 ? 'Sculpt' : maxZ >= 4.0 ? 'Deep' : 'Standard'})`;

      autoDistributeZ();
      showToast(`Set relief depth to ${maxZ.toFixed(1)} mm!`);
    };
  });

  // Sliders
  const sliderMaxZ = document.getElementById('sliderMaxZ');
  if (sliderMaxZ) {
    sliderMaxZ.oninput = (e) => {
      state.dimensions.maxZ = parseFloat(e.target.value);
      const v = document.getElementById('valMaxZ');
      if (v) v.innerText = `${state.dimensions.maxZ.toFixed(2)} mm`;
      autoDistributeZ();
    };
  }

  const sliderMinZ = document.getElementById('sliderMinZ');
  if (sliderMinZ) {
    sliderMinZ.oninput = (e) => {
      state.dimensions.minZ = parseFloat(e.target.value);
      const v = document.getElementById('valMinZ');
      if (v) v.innerText = `${state.dimensions.minZ.toFixed(2)} mm`;
      autoDistributeZ();
    };
  }

  const sliderContrast = document.getElementById('sliderContrast');
  if (sliderContrast) {
    sliderContrast.oninput = (e) => {
      state.adjustments.contrast = parseFloat(e.target.value);
      const v = document.getElementById('valContrast');
      if (v) v.innerText = state.adjustments.contrast.toFixed(2);
      scheduleRecomputeLuminance();
    };
  }

  const sliderSmoothing = document.getElementById('sliderSmoothing');
  if (sliderSmoothing) {
    sliderSmoothing.oninput = (e) => {
      state.smoothingRadius = parseFloat(e.target.value);
      const v = document.getElementById('valSmoothing');
      if (v) v.innerText = state.smoothingRadius.toFixed(1);
      scheduleRecomputeLuminance();
    };
  }

  const checkDespike = document.getElementById('checkDespike');
  if (checkDespike) {
    checkDespike.onchange = (e) => {
      state.despike = e.target.checked;
      applySmoothingAndDenoise();
      update3DMesh();
      update2DPreview();
    };
  }

  const checkSmoothTerraces = document.getElementById('checkSmoothTerraces');
  if (checkSmoothTerraces) {
    checkSmoothTerraces.onchange = (e) => {
      state.smoothTerraces = e.target.checked;
      update3DMesh();
    };
  }

  const checkInvert = document.getElementById('checkInvert');
  if (checkInvert) {
    checkInvert.onchange = (e) => {
      state.adjustments.invert = e.target.checked;
      recomputeLuminance();
    };
  }

  const checkQuantize = document.getElementById('checkQuantize');
  if (checkQuantize) {
    checkQuantize.onchange = (e) => {
      state.quantizeLayers = e.target.checked;
      update3DMesh();
    };
  }

  // Dimensions
  const inputWidth = document.getElementById('inputWidth');
  if (inputWidth) {
    inputWidth.onchange = (e) => {
      state.dimensions.widthMm = parseFloat(e.target.value);
      update3DMesh();
    };
  }

  const inputHeight = document.getElementById('inputHeight');
  if (inputHeight) {
    inputHeight.onchange = (e) => {
      state.dimensions.heightMm = parseFloat(e.target.value);
      update3DMesh();
    };
  }

  // Layer step presets
  document.querySelectorAll('.btnLayerPreset').forEach(btn => {
    btn.onclick = (e) => {
      state.dimensions.layerHeight = parseFloat(e.target.dataset.layer);
      document.querySelectorAll('.btnLayerPreset').forEach(b => {
        b.className = "btnLayerPreset bg-white dark:bg-zinc-800 hover:bg-zinc-100 dark:hover:bg-zinc-700 text-xs py-1.5 rounded-xl border border-zinc-300 dark:border-zinc-700 text-zinc-800 dark:text-zinc-200";
      });
      e.target.className = "btnLayerPreset bg-zinc-900 text-white dark:bg-zinc-100 dark:text-zinc-900 font-medium text-xs py-1.5 rounded-xl";
      updateSwapTable();
    };
  });

  // View Modes (3D Perspective, Top-Down 3D, and 2D Slices)
  const btn3D = document.getElementById('btnView3D');
  const btnTop = document.getElementById('btnViewTop');
  const btn2D = document.getElementById('btnView2D');

  function updateViewModeButtons(activeBtn) {
    [btn3D, btnTop, btn2D].forEach(b => {
      if (!b) return;
      if (b === activeBtn) {
        b.className = "px-3 py-1.5 text-xs font-semibold rounded-xl bg-zinc-900 dark:bg-zinc-100 text-white dark:text-zinc-900 transition shadow-sm";
      } else {
        b.className = "px-3 py-1.5 text-xs font-medium rounded-xl text-zinc-500 dark:text-zinc-400 hover:text-zinc-900 dark:hover:text-zinc-100 transition";
      }
    });
  }

  if (btn3D) {
    btn3D.onclick = () => {
      document.getElementById('canvasContainer')?.classList.remove('hidden');
      document.getElementById('preview2DContainer')?.classList.add('hidden');
      updateViewModeButtons(btn3D);
      setCameraView('iso');
    };
  }

  if (btnTop) {
    btnTop.onclick = () => {
      document.getElementById('canvasContainer')?.classList.remove('hidden');
      document.getElementById('preview2DContainer')?.classList.add('hidden');
      updateViewModeButtons(btnTop);
      setCameraView('top');
    };
  }

  if (btn2D) {
    btn2D.onclick = () => {
      document.getElementById('canvasContainer')?.classList.add('hidden');
      document.getElementById('preview2DContainer')?.classList.remove('hidden');
      updateViewModeButtons(btn2D);
    };
  }

  // Camera Snaps with Calibrated Framing
  const camIso = document.getElementById('btnCamIso');
  if (camIso) {
    camIso.onclick = () => {
      document.getElementById('canvasContainer')?.classList.remove('hidden');
      document.getElementById('preview2DContainer')?.classList.add('hidden');
      updateViewModeButtons(btn3D);
      setCameraView('iso');
    };
  }
  const camTop = document.getElementById('btnCamTop');
  if (camTop) {
    camTop.onclick = () => {
      document.getElementById('canvasContainer')?.classList.remove('hidden');
      document.getElementById('preview2DContainer')?.classList.add('hidden');
      updateViewModeButtons(btnTop);
      setCameraView('top');
    };
  }
  const camFront = document.getElementById('btnCamFront');
  if (camFront) {
    camFront.onclick = () => {
      document.getElementById('canvasContainer')?.classList.remove('hidden');
      document.getElementById('preview2DContainer')?.classList.add('hidden');
      setCameraView('front');
    };
  }
  const camReset = document.getElementById('btnCamReset');
  if (camReset) {
    camReset.onclick = () => {
      document.getElementById('canvasContainer')?.classList.remove('hidden');
      document.getElementById('preview2DContainer')?.classList.add('hidden');
      updateViewModeButtons(btn3D);
      setCameraView('iso');
    };
  }

  // Viewport Toggles
  const checkPlate = document.getElementById('checkBuildPlate');
  if (checkPlate) {
    checkPlate.onchange = (e) => {
      state.showBuildPlate = e.target.checked;
      if (buildPlateGroup) buildPlateGroup.visible = state.showBuildPlate;
      requestRender();
    };
  }

  const checkGrid = document.getElementById('checkGrid');
  if (checkGrid) {
    checkGrid.onchange = (e) => {
      if (gridHelper) gridHelper.visible = e.target.checked;
      requestRender();
    };
  }

  const checkWire = document.getElementById('checkWire');
  if (checkWire) {
    checkWire.onchange = (e) => {
      state.showWire = e.target.checked;
      update3DMesh();
    };
  }

  // Layer Scrubber
  const scrubber = document.getElementById('scrubberSlider');
  const scrubLabel = document.getElementById('scrubberLabel');
  if (scrubber) {
    scrubber.oninput = (e) => {
      state.scrubLayer = parseInt(e.target.value);
      const z = state.scrubLayer === 0 ? state.dimensions.maxZ : getLayerZ(state.scrubLayer);
      if (scrubLabel) {
        scrubLabel.innerText = state.scrubLayer === 0 ? `Layer All (${z.toFixed(2)} mm)` : `Layer ${state.scrubLayer} (${z.toFixed(2)} mm)`;
      }
      update2DPreview();
      update3DMesh();
    };
  }

  const prevLayerBtn = document.getElementById('btnPrevLayer');
  if (prevLayerBtn && scrubber) {
    prevLayerBtn.onclick = () => {
      if (state.scrubLayer > 0) {
        scrubber.value = state.scrubLayer - 1;
        scrubber.dispatchEvent(new Event('input'));
      }
    };
  }

  const nextLayerBtn = document.getElementById('btnNextLayer');
  if (nextLayerBtn && scrubber) {
    nextLayerBtn.onclick = () => {
      if (state.scrubLayer < parseInt(scrubber.max)) {
        scrubber.value = state.scrubLayer + 1;
        scrubber.dispatchEvent(new Event('input'));
      }
    };
  }

  const allLayersBtn = document.getElementById('btnAllLayers');
  if (allLayersBtn && scrubber) {
    allLayersBtn.onclick = () => {
      scrubber.value = 0;
      scrubber.dispatchEvent(new Event('input'));
    };
  }

  // Copy Instructions
  const copyInstrBtn = document.getElementById('btnCopyInstructions');
  if (copyInstrBtn) {
    copyInstrBtn.onclick = () => {
      let text = "=== Layerloom Slicer Layer Swap Schedule ===\n";
      let prevL = 1;
      state.filaments.forEach((fil, idx) => {
        const endL = Math.max(1, Math.round((fil.endZ - state.dimensions.firstLayerHeight) / state.dimensions.layerHeight) + 1);
        if (idx === 0) text += `• Start: Slot #${fil.slot} (${fil.name}) [${fil.color}] -> Layers 1-${endL} (0.00-${fil.endZ.toFixed(2)}mm)\n`;
        else text += `• Swap: Slot #${fil.slot} (${fil.name}) [${fil.color}] -> Layer ${prevL} (${fil.startZ.toFixed(2)}mm) to ${endL} (${fil.endZ.toFixed(2)}mm)\n`;
        prevL = endL;
      });
      navigator.clipboard.writeText(text);
      showToast("Copied swap schedule to clipboard");
    };
  }

  // Export triggers
  const exp3mf = document.getElementById('btnExport3MF');
  if (exp3mf) exp3mf.onclick = export3MF;

  const expStl = document.getElementById('btnExportSTL');
  if (expStl) expStl.onclick = exportSTL;
};
