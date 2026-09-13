function getBrandBadgeClass(brand, isSelected) {
  if (isSelected) {
    return 'bg-white/20 text-white dark:bg-zinc-900/20 dark:text-zinc-900 font-semibold';
  }
  switch (brand) {
    case 'Bambu Lab':
      return 'bg-emerald-50 text-emerald-700 dark:bg-emerald-950/60 dark:text-emerald-300 border border-emerald-200/80 dark:border-emerald-800/60 font-semibold';
    case 'Prusa':
      return 'bg-amber-50 text-amber-700 dark:bg-amber-950/60 dark:text-amber-300 border border-amber-200/80 dark:border-amber-800/60 font-semibold';
    case 'UltiMaker':
      return 'bg-sky-50 text-sky-700 dark:bg-sky-950/60 dark:text-sky-300 border border-sky-200/80 dark:border-sky-800/60 font-semibold';
    case 'Creality':
      return 'bg-blue-50 text-blue-700 dark:bg-blue-950/60 dark:text-blue-300 border border-blue-200/80 dark:border-blue-800/60 font-semibold';
    case 'Voron':
      return 'bg-purple-50 text-purple-700 dark:bg-purple-950/60 dark:text-purple-300 border border-purple-200/80 dark:border-purple-800/60 font-semibold';
    case 'Elegoo':
      return 'bg-teal-50 text-teal-700 dark:bg-teal-950/60 dark:text-teal-300 border border-teal-200/80 dark:border-teal-800/60 font-semibold';
    default:
      return 'bg-zinc-100 text-zinc-700 dark:bg-zinc-800 dark:text-zinc-300 border border-zinc-200 dark:border-zinc-700 font-semibold';
  }
}

// Vector High-Fidelity SVG Illustrations for All Printer Models
function getPrinterThumbnailSvg(printer) {
  const key = printer.imageKey || printer.id;
  
  if (key === 'bambu-x1c' || key === 'bambu-x1e') {
    return `
      <svg class="w-10 h-10" viewBox="0 0 48 48" fill="none" xmlns="http://www.w3.org/2000/svg">
        <rect x="5" y="5" width="38" height="38" rx="6" fill="#1c1917" stroke="#44403c" stroke-width="1.5"/>
        <rect x="8" y="8" width="32" height="32" rx="4" fill="#0c0a09"/>
        <path d="M9 9 L24 9 L11 38 L9 38 Z" fill="white" fill-opacity="0.08"/>
        <circle cx="24" cy="11.5" r="1.5" fill="#38bdf8"/>
        <line x1="12" y1="14" x2="36" y2="14" stroke="#10b981" stroke-width="1.5" stroke-linecap="round"/>
        <line x1="10" y1="23" x2="38" y2="23" stroke="#57534e" stroke-width="1.5"/>
        <rect x="21" y="19" width="6" height="7" rx="1.5" fill="#f5f5f4" stroke="#292524" stroke-width="0.8"/>
        <rect x="10" y="34" width="28" height="3.5" rx="1" fill="#d97706"/>
        <rect x="33" y="7" width="5" height="3" rx="0.5" fill="#0284c7"/>
      </svg>
    `;
  }
  if (key === 'bambu-p1s') {
    return `
      <svg class="w-10 h-10" viewBox="0 0 48 48" fill="none" xmlns="http://www.w3.org/2000/svg">
        <rect x="5" y="5" width="38" height="38" rx="6" fill="#18181b" stroke="#27272a" stroke-width="1.5"/>
        <rect x="8" y="8" width="32" height="32" rx="4" fill="#09090b"/>
        <path d="M9 9 L22 9 L11 36 L9 36 Z" fill="white" fill-opacity="0.06"/>
        <line x1="10" y1="22" x2="38" y2="22" stroke="#52525b" stroke-width="1.5"/>
        <rect x="21" y="19" width="6" height="7" rx="1.5" fill="#e4e4e7"/>
        <rect x="11" y="34" width="26" height="3" rx="1" fill="#ca8a04"/>
        <rect x="32" y="8" width="6" height="2" rx="0.5" fill="#3f3f46"/>
      </svg>
    `;
  }
  if (key === 'bambu-p1p') {
    return `
      <svg class="w-10 h-10" viewBox="0 0 48 48" fill="none" xmlns="http://www.w3.org/2000/svg">
        <rect x="6" y="6" width="36" height="36" rx="4" fill="#09090b" stroke="#e4e4e7" stroke-width="1.5"/>
        <line x1="6" y1="16" x2="10" y2="16" stroke="#a1a1aa" stroke-width="1"/>
        <line x1="6" y1="24" x2="10" y2="24" stroke="#a1a1aa" stroke-width="1"/>
        <line x1="6" y1="32" x2="10" y2="32" stroke="#a1a1aa" stroke-width="1"/>
        <line x1="38" y1="16" x2="42" y2="16" stroke="#a1a1aa" stroke-width="1"/>
        <line x1="38" y1="24" x2="42" y2="24" stroke="#a1a1aa" stroke-width="1"/>
        <line x1="10" y1="20" x2="38" y2="20" stroke="#71717a" stroke-width="1.5"/>
        <rect x="21" y="17" width="6" height="7" rx="1" fill="#e4e4e7"/>
        <rect x="12" y="34" width="24" height="3" rx="1" fill="#eab308"/>
      </svg>
    `;
  }
  if (key === 'bambu-a1') {
    return `
      <svg class="w-10 h-10" viewBox="0 0 48 48" fill="none" xmlns="http://www.w3.org/2000/svg">
        <rect x="7" y="39" width="34" height="4" rx="2" fill="#27272a"/>
        <line x1="12" y1="10" x2="12" y2="39" stroke="#a1a1aa" stroke-width="3" stroke-linecap="round"/>
        <line x1="36" y1="10" x2="36" y2="39" stroke="#a1a1aa" stroke-width="3" stroke-linecap="round"/>
        <line x1="8" y1="10" x2="40" y2="10" stroke="#71717a" stroke-width="2.5" stroke-linecap="round"/>
        <circle cx="18" cy="7" r="2.5" fill="#a1a1aa" stroke="#71717a"/>
        <circle cx="30" cy="7" r="2.5" fill="#a1a1aa" stroke="#71717a"/>
        <line x1="12" y1="21" x2="36" y2="21" stroke="#52525b" stroke-width="2"/>
        <rect x="21" y="17" width="6" height="8" rx="1" fill="#18181b" stroke="#71717a" stroke-width="0.8"/>
        <rect x="11" y="36" width="26" height="3" rx="1" fill="#eab308"/>
      </svg>
    `;
  }
  if (key === 'bambu-a1mini') {
    return `
      <svg class="w-10 h-10" viewBox="0 0 48 48" fill="none" xmlns="http://www.w3.org/2000/svg">
        <rect x="8" y="39" width="32" height="4" rx="2" fill="#27272a"/>
        <rect x="10" y="8" width="6" height="31" rx="2" fill="#e4e4e7" stroke="#71717a" stroke-width="1"/>
        <rect x="14" y="18" width="22" height="3.5" rx="1" fill="#71717a"/>
        <rect x="23" y="15" width="6" height="8" rx="1" fill="#18181b" stroke="#10b981" stroke-width="0.8"/>
        <rect x="17" y="35" width="19" height="3.5" rx="1" fill="#eab308"/>
      </svg>
    `;
  }
  if (key === 'prusa-mk4s') {
    return `
      <svg class="w-10 h-10" viewBox="0 0 48 48" fill="none" xmlns="http://www.w3.org/2000/svg">
        <rect x="8" y="39" width="32" height="4" rx="1" fill="#1c1917"/>
        <path d="M12 39 L12 12 Q12 9 15 9 L33 9 Q36 9 36 12 L36 39" stroke="#292524" stroke-width="3" fill="none"/>
        <rect x="9" y="8" width="6" height="4" rx="1" fill="#f97316"/>
        <rect x="33" y="8" width="6" height="4" rx="1" fill="#f97316"/>
        <line x1="12" y1="22" x2="36" y2="22" stroke="#78716c" stroke-width="2"/>
        <rect x="20" y="18" width="8" height="9" rx="1" fill="#18181b" stroke="#ea580c" stroke-width="1"/>
        <polygon points="23,28 25,28 24,30" fill="#eab308"/>
        <rect x="11" y="36" width="26" height="3" rx="1" fill="#44403c"/>
        <rect x="29" y="39" width="9" height="4" rx="1" fill="#ea580c"/>
      </svg>
    `;
  }
  if (key === 'prusa-coreone') {
    return `
      <svg class="w-10 h-10" viewBox="0 0 48 48" fill="none" xmlns="http://www.w3.org/2000/svg">
        <rect x="5" y="5" width="38" height="38" rx="5" fill="#1c1917" stroke="#ea580c" stroke-width="1.5"/>
        <rect x="8" y="8" width="32" height="32" rx="3" fill="#0c0a09"/>
        <rect x="6" y="6" width="4" height="4" fill="#f97316"/>
        <rect x="38" y="6" width="4" height="4" fill="#f97316"/>
        <line x1="10" y1="21" x2="38" y2="21" stroke="#78716c" stroke-width="1.5"/>
        <rect x="21" y="17" width="6" height="8" rx="1" fill="#292524" stroke="#ea580c" stroke-width="0.8"/>
        <rect x="11" y="34" width="26" height="3.5" rx="1" fill="#57534e"/>
      </svg>
    `;
  }
  if (key === 'prusa-xl') {
    return `
      <svg class="w-10 h-10" viewBox="0 0 48 48" fill="none" xmlns="http://www.w3.org/2000/svg">
        <rect x="4" y="6" width="40" height="37" rx="4" fill="#18181b" stroke="#3f3f46" stroke-width="1.5"/>
        <line x1="8" y1="12" x2="40" y2="12" stroke="#ea580c" stroke-width="2"/>
        <rect x="10" y="9" width="4" height="4" rx="1" fill="#f97316"/>
        <rect x="16" y="9" width="4" height="4" rx="1" fill="#f97316"/>
        <rect x="22" y="9" width="4" height="4" rx="1" fill="#f97316"/>
        <rect x="28" y="9" width="4" height="4" rx="1" fill="#f97316"/>
        <rect x="8" y="34" width="32" height="4" rx="1" fill="#52525b"/>
      </svg>
    `;
  }
  if (key === 'ultimaker-s7' || key === 'ultimaker-s5' || key === 'ultimaker-s3' || key === 'ultimaker-2p') {
    return `
      <svg class="w-10 h-10" viewBox="0 0 48 48" fill="none" xmlns="http://www.w3.org/2000/svg">
        <rect x="6" y="5" width="36" height="38" rx="7" fill="#f4f4f5" stroke="#d4d4d8" stroke-width="1.5"/>
        <rect x="9" y="8" width="30" height="28" rx="4" fill="#0f172a"/>
        <path d="M10 9 L24 9 L11 34 L10 34 Z" fill="#38bdf8" fill-opacity="0.15"/>
        <rect x="21" y="16" width="6" height="7" rx="1" fill="#ffffff" stroke="#94a3b8" stroke-width="0.8"/>
        <rect x="12" y="31" width="24" height="3" rx="1" fill="#e2e8f0"/>
        <circle cx="24" cy="40" r="2.5" fill="#38bdf8"/>
      </svg>
    `;
  }
  if (key === 'creality-k1' || key === 'creality-k1max') {
    return `
      <svg class="w-10 h-10" viewBox="0 0 48 48" fill="none" xmlns="http://www.w3.org/2000/svg">
        <rect x="5" y="5" width="38" height="38" rx="5" fill="#111827" stroke="#374151" stroke-width="1.5"/>
        <rect x="8" y="8" width="32" height="32" rx="3" fill="#030712"/>
        <path d="M9 9 L24 9 L11 36 L9 36 Z" fill="white" fill-opacity="0.08"/>
        <line x1="10" y1="21" x2="38" y2="21" stroke="#4b5563" stroke-width="1.5"/>
        <rect x="20" y="17" width="8" height="7" rx="1.5" fill="#e5e7eb"/>
        <rect x="11" y="34" width="26" height="3" rx="1" fill="#d97706"/>
      </svg>
    `;
  }
  if (key === 'voron-24' || key === 'voron-trident' || key === 'voron-v0') {
    return `
      <svg class="w-10 h-10" viewBox="0 0 48 48" fill="none" xmlns="http://www.w3.org/2000/svg">
        <rect x="5" y="5" width="38" height="38" rx="3" fill="#09090b" stroke="#262626" stroke-width="1.5"/>
        <rect x="5" y="5" width="4" height="4" fill="#dc2626"/>
        <rect x="39" y="5" width="4" height="4" fill="#dc2626"/>
        <rect x="5" y="39" width="4" height="4" fill="#dc2626"/>
        <rect x="39" y="39" width="4" height="4" fill="#dc2626"/>
        <line x1="8" y1="21" x2="40" y2="21" stroke="#dc2626" stroke-width="1.5"/>
        <rect x="21" y="17" width="6" height="8" rx="1" fill="#171717" stroke="#dc2626" stroke-width="1"/>
        <rect x="10" y="34" width="28" height="3.5" rx="1" fill="#ca8a04"/>
      </svg>
    `;
  }
  if (key.includes('elegoo')) {
    return `
      <svg class="w-10 h-10" viewBox="0 0 48 48" fill="none" xmlns="http://www.w3.org/2000/svg">
        <rect x="8" y="39" width="32" height="4" rx="2" fill="#0f172a"/>
        <line x1="12" y1="10" x2="12" y2="39" stroke="#1e293b" stroke-width="3"/>
        <line x1="36" y1="10" x2="36" y2="39" stroke="#1e293b" stroke-width="3"/>
        <line x1="8" y1="10" x2="40" y2="10" stroke="#0ea5e9" stroke-width="2"/>
        <rect x="8" y="18" width="32" height="3" rx="1" fill="#1e293b" stroke="#0ea5e9" stroke-width="0.8"/>
        <rect x="21" y="15" width="6" height="8" rx="1" fill="#0284c7"/>
        <rect x="11" y="35" width="26" height="3.5" rx="1" fill="#eab308"/>
      </svg>
    `;
  }
  
  // Default / Custom blueprint bed
  return `
    <svg class="w-10 h-10" viewBox="0 0 48 48" fill="none" xmlns="http://www.w3.org/2000/svg">
      <rect x="7" y="10" width="34" height="28" rx="4" fill="#18181b" stroke="#52525b" stroke-width="1.5"/>
      <line x1="7" y1="24" x2="41" y2="24" stroke="#71717a" stroke-width="1" stroke-dasharray="2 2"/>
      <line x1="24" y1="10" x2="24" y2="38" stroke="#71717a" stroke-width="1" stroke-dasharray="2 2"/>
      <circle cx="24" cy="24" r="3" fill="#10b981"/>
      <line x1="12" y1="6" x2="36" y2="6" stroke="#10b981" stroke-width="1.5" stroke-linecap="round"/>
    </svg>
  `;
}

function getPrinterThumbnail(printer, isSelected) {
  const svgThumb = getPrinterThumbnailSvg(printer);
  if (printer.imageUrl) {
    return `
      <div class="relative w-12 h-12 rounded-xl ${isSelected ? 'bg-white/10 dark:bg-zinc-900/10' : 'bg-zinc-100 dark:bg-zinc-800/80 border border-zinc-200/80 dark:border-zinc-700/60'} p-1 flex items-center justify-center shrink-0 overflow-hidden shadow-xs">
        <img 
          src="${printer.imageUrl}" 
          alt="${printer.brand} ${printer.model}"
          class="w-full h-full object-contain drop-shadow-xs transition-transform duration-200"
          onerror="this.style.display='none'; if (this.nextElementSibling) this.nextElementSibling.style.display='flex';"
          loading="lazy"
        />
        <div style="display: none;" class="w-full h-full items-center justify-center">
          ${svgThumb}
        </div>
      </div>
    `;
  }
  return `
    <div class="w-12 h-12 rounded-xl ${isSelected ? 'bg-white/10 dark:bg-zinc-900/10' : 'bg-zinc-100 dark:bg-zinc-800/80 border border-zinc-200/80 dark:border-zinc-700/60'} p-1 flex items-center justify-center shrink-0 shadow-xs">
      ${svgThumb}
    </div>
  `;
}

function updateActivePrinterBanner() {
  const banner = document.getElementById('activePrinterBanner');
  if (!banner) return;
  const p = state.printer;
  banner.innerHTML = `
    <div class="flex items-center gap-3">
      <div class="w-14 h-14 rounded-2xl bg-zinc-100 dark:bg-zinc-800/90 border border-zinc-200 dark:border-zinc-700/80 p-1 flex items-center justify-center shrink-0 overflow-hidden shadow-xs">
        ${p.imageUrl ? `<img src="${p.imageUrl}" alt="${p.brand} ${p.model}" class="w-full h-full object-contain" onerror="this.style.display='none'; if (this.nextElementSibling) this.nextElementSibling.style.display='flex';"><div style="display:none;" class="w-full h-full items-center justify-center">${getPrinterThumbnailSvg(p)}</div>` : getPrinterThumbnailSvg(p)}
      </div>
      <div class="flex-1 min-w-0">
        <div class="flex items-center gap-1.5 mb-0.5">
          <span class="text-[9px] uppercase tracking-wider px-1.5 py-0.5 rounded-md bg-emerald-50 text-emerald-700 dark:bg-emerald-950/60 dark:text-emerald-300 font-semibold border border-emerald-200/80 dark:border-emerald-800/60">Active 3D Bed</span>
          <span class="text-[10px] font-mono text-zinc-500 truncate">${p.tag}</span>
        </div>
        <h3 class="text-sm font-bold text-zinc-900 dark:text-zinc-100 truncate">${p.brand} ${p.model}</h3>
        <p class="text-[11px] font-mono text-zinc-500">${p.width} &times; ${p.height} mm &bull; Max Z: ${p.maxZ || p.height} mm</p>
      </div>
    </div>
  `;
}

function renderPrinterCatalog() {
  const container = document.getElementById('printerCardList');
  const brandChipsContainer = document.getElementById('brandFilterChips');
  if (!container) return;

  updateActivePrinterBanner();

  // Render Brand Filter Chips
  if (brandChipsContainer) {
    const brands = ['All', 'Bambu Lab', 'Prusa', 'UltiMaker', 'Creality', 'Voron', 'Elegoo', 'Custom'];
    brandChipsContainer.innerHTML = '';
    brands.forEach(brand => {
      const chip = document.createElement('button');
      const isActive = state.printerBrandFilter === brand;
      chip.className = `px-2.5 py-1 rounded-xl text-xs transition-all font-medium ${
        isActive
          ? 'bg-zinc-900 text-white dark:bg-zinc-100 dark:text-zinc-900 shadow-sm font-semibold'
          : 'bg-zinc-100/90 dark:bg-zinc-800/80 hover:bg-zinc-200 dark:hover:bg-zinc-700 text-zinc-600 dark:text-zinc-400'
      }`;
      chip.innerText = brand;
      chip.onclick = () => {
        state.printerBrandFilter = brand;
        renderPrinterCatalog();
      };
      brandChipsContainer.appendChild(chip);
    });
  }

  // Filtered List
  const filtered = PRINTER_PROFILES.filter(p => {
    if (state.printerBrandFilter === 'All') return true;
    return p.brand === state.printerBrandFilter;
  });

  container.innerHTML = '';
  filtered.forEach(printer => {
    const isSelected = state.printer.id === printer.id;
    const card = document.createElement('div');
    card.className = `p-3 rounded-2xl border cursor-pointer transition-all flex items-center justify-between interactive-card shadow-xs ${
      isSelected
        ? 'bg-zinc-900 text-white dark:bg-zinc-100 dark:text-zinc-900 border-zinc-900 dark:border-white ring-1 ring-zinc-900 dark:ring-white'
        : 'bg-white dark:bg-zinc-900/80 hover:bg-zinc-50 dark:hover:bg-zinc-850 text-zinc-800 dark:text-zinc-200 border-zinc-200 dark:border-zinc-800'
    }`;

    const badgeStyle = getBrandBadgeClass(printer.brand, isSelected);
    const thumbHtml = getPrinterThumbnail(printer, isSelected);

    card.innerHTML = `
      <div class="flex items-center gap-3 min-w-0 pr-2">
        ${thumbHtml}
        <div class="min-w-0">
          <div class="flex items-center gap-1.5 mb-0.5">
            <span class="text-[9px] uppercase tracking-wider px-1.5 py-0.5 rounded-md ${badgeStyle}">${printer.brand}</span>
            <span class="text-[10px] opacity-75 font-mono truncate">${printer.tag}</span>
          </div>
          <div class="text-xs font-semibold truncate flex items-center gap-1.5">
            <span>${printer.model}</span>
            ${isSelected ? `<svg class="w-3.5 h-3.5 shrink-0 ${isSelected ? 'text-white dark:text-zinc-900' : 'text-emerald-500'}" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"></path></svg>` : ''}
          </div>
          <div class="text-[10px] opacity-60 truncate">${printer.desc || ''}</div>
        </div>
      </div>
      <div class="text-right shrink-0">
        <div class="font-mono text-xs font-bold">${printer.width} &times; ${printer.height}</div>
        <div class="text-[10px] opacity-60 font-mono">mm bed</div>
      </div>
    `;

    card.onclick = () => selectPrinter(printer);
    container.appendChild(card);
  });

  // Custom Bed Size Card Toggle
  const customConfig = document.getElementById('customBedConfig');
  if (customConfig) {
    if (state.printer.id === 'custom-bed') {
      customConfig.classList.remove('hidden');
    } else {
      customConfig.classList.add('hidden');
    }
  }
}

function selectPrinter(printer) {
  state.printer = { ...printer };
  updateHeaderPrinterBadge();
  updateGridColor();
  updateBuildPlate();

  // Auto-fit relief if it exceeds the new bed boundaries
  const maxAllowedW = printer.width - 16;
  const maxAllowedH = printer.height - 16;
  if (state.dimensions.widthMm > maxAllowedW || state.dimensions.heightMm > maxAllowedH) {
    fitReliefToBed();
  }

  renderPrinterCatalog();
  showToast(`Active Bed: ${printer.brand} ${printer.model} (${printer.width}x${printer.height}mm)`);
}

function updateHeaderPrinterBadge() {
  const badge = document.getElementById('headerPrinterBadge');
  if (badge) {
    badge.innerText = `${state.printer.brand} ${state.printer.model} (${state.printer.width}mm)`;
  }
}

function fitReliefToBed() {
  const bedW = (state.printer.width || 256) - 16;
  const bedH = (state.printer.height || 256) - 16;
  const ar = (state.width && state.height) ? (state.width / state.height) : 1.0;

  let w, h;
  if (bedW / ar <= bedH) {
    w = bedW;
    h = Math.round((bedW / ar) * 10) / 10;
  } else {
    h = bedH;
    w = Math.round((bedH * ar) * 10) / 10;
  }

  state.dimensions.widthMm = w;
  state.dimensions.heightMm = h;
  const inputW = document.getElementById('inputWidth');
  const inputH = document.getElementById('inputHeight');
  if (inputW) inputW.value = w;
  if (inputH) inputH.value = h;
  update3DMesh();
  showToast(`Auto-fitted to ${state.printer.model} bed (${w} x ${h} mm)`);
}

function fillMaxWidth() {
  const bedW = (state.printer.width || 256) - 16;
  const ar = (state.width && state.height) ? (state.width / state.height) : 1.0;
  const w = bedW;
  const h = Math.round((w / ar) * 10) / 10;

  state.dimensions.widthMm = w;
  state.dimensions.heightMm = h;
  const inputW = document.getElementById('inputWidth');
  const inputH = document.getElementById('inputHeight');
  if (inputW) inputW.value = w;
  if (inputH) inputH.value = h;
  update3DMesh();
  showToast(`Filled max width: ${w} x ${h} mm`);
}

function setupPrinterManager() {
  renderPrinterCatalog();
  updateHeaderPrinterBadge();

  const fitBtn = document.getElementById('btnFitToBed');
  if (fitBtn) fitBtn.onclick = fitReliefToBed;

  const fillBtn = document.getElementById('btnFillBed');
  if (fillBtn) fillBtn.onclick = fillMaxWidth;

  // Preset Sizes
  document.querySelectorAll('.btnPresetSize').forEach(btn => {
    btn.onclick = (e) => {
      const sizeStr = e.target.dataset.size;
      let targetSize = parseFloat(sizeStr);
      if (sizeStr === 'max') {
        targetSize = Math.min(state.printer.width, state.printer.height) - 16;
      }

      const ar = (state.width && state.height) ? (state.width / state.height) : 1.0;

      let w, h;
      if (ar >= 1.0) {
        w = targetSize;
        h = Math.round((targetSize / ar) * 10) / 10;
      } else {
        h = targetSize;
        w = Math.round((targetSize * ar) * 10) / 10;
      }

      state.dimensions.widthMm = w;
      state.dimensions.heightMm = h;
      const inputW = document.getElementById('inputWidth');
      const inputH = document.getElementById('inputHeight');
      if (inputW) inputW.value = w;
      if (inputH) inputH.value = h;

      document.querySelectorAll('.btnPresetSize').forEach(b => {
        b.className = "btnPresetSize py-1.5 rounded-xl bg-zinc-100 dark:bg-zinc-800 hover:bg-zinc-200 dark:hover:bg-zinc-700 text-zinc-800 dark:text-zinc-200 text-center font-medium border border-zinc-200 dark:border-zinc-700/80";
      });
      e.target.className = "btnPresetSize py-1.5 rounded-xl bg-zinc-900 text-white dark:bg-zinc-100 dark:text-zinc-900 font-semibold text-center shadow-sm";

      update3DMesh();
      showToast(`Sized to preset: ${w} x ${h} mm`);
    };
  });

  // Custom Bed Inputs
  const customW = document.getElementById('customBedW');
  const customH = document.getElementById('customBedH');
  if (customW && customH) {
    const handleCustomChange = () => {
      const w = Math.max(50, Math.min(1000, parseFloat(customW.value) || 200));
      const h = Math.max(50, Math.min(1000, parseFloat(customH.value) || 200));
      state.printer.width = w;
      state.printer.height = h;
      state.printer.model = `Custom (${w}×${h}mm)`;
      updateHeaderPrinterBadge();
      updateGridColor();
      updateBuildPlate();
      showToast(`Set custom bed: ${w} x ${h} mm`);
    };
    customW.onchange = handleCustomChange;
    customH.onchange = handleCustomChange;
  }
}
