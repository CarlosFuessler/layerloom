/**
 * 2MF Studio — Central Application State, Printer Profiles & Utilities
 */

// Popular 3D Printer Profiles with Real Web Product Images
const PRINTER_PROFILES = [
  // Bambu Lab — Separated Models with Real Web Images
  { id: 'bambu-x1c', brand: 'Bambu Lab', model: 'X1 Carbon', width: 256, height: 256, maxZ: 256, tag: 'Enclosed CoreXY', imageUrl: 'assets/printers/bambu-x1c.png', desc: 'Micro Lidar, 1080p Cam & Dual PEI' },
  { id: 'bambu-x1e', brand: 'Bambu Lab', model: 'X1E Enterprise', width: 256, height: 256, maxZ: 256, tag: 'Heated Chamber', imageUrl: 'assets/printers/bambu-x1e.png', desc: 'Active Heated Chamber & Ethernet' },
  { id: 'bambu-p1s', brand: 'Bambu Lab', model: 'P1S', width: 256, height: 256, maxZ: 256, tag: 'Enclosed CoreXY', imageUrl: 'assets/printers/bambu-p1s.png', desc: 'Enclosed High-Speed Multi-Color' },
  { id: 'bambu-p1p', brand: 'Bambu Lab', model: 'P1P', width: 256, height: 256, maxZ: 256, tag: 'Open CoreXY', imageUrl: 'assets/printers/bambu-p1p.png', desc: 'Modular Open-Frame High-Speed' },
  { id: 'bambu-a1', brand: 'Bambu Lab', model: 'A1', width: 256, height: 256, maxZ: 256, tag: 'Full Bed Slinger', imageUrl: 'assets/printers/bambu-a1.png', desc: 'Active Flow Rate & 256mm Bed' },
  { id: 'bambu-a1mini', brand: 'Bambu Lab', model: 'A1 mini', width: 180, height: 180, maxZ: 180, tag: 'Cantilever Mini', imageUrl: 'assets/printers/bambu-a1mini.png', desc: 'Compact Plug & Play Multi-Color' },

  // Prusa Research
  { id: 'prusa-mk4s', brand: 'Prusa', model: 'MK4S', width: 250, height: 210, maxZ: 220, tag: 'Bed Slinger', imageUrl: 'assets/printers/prusa-mk4s.jpg', desc: 'Nextruder 360° Fan & High Precision' },
  { id: 'prusa-coreone', brand: 'Prusa', model: 'Core One', width: 250, height: 220, maxZ: 270, tag: 'Enclosed CoreXY', imageUrl: 'assets/printers/prusa-mk4s.jpg', desc: 'Active Chamber Temperature Control' },
  { id: 'prusa-xl', brand: 'Prusa', model: 'Prusa XL', width: 360, height: 360, maxZ: 360, tag: 'Multi-Toolhead', imageUrl: 'assets/printers/prusa-mk4s.jpg', desc: 'Modular Toolchanger 1-5 Heads' },
  { id: 'prusa-mini', brand: 'Prusa', model: 'MINI+', width: 180, height: 180, maxZ: 180, tag: 'Cantilever Mini', imageUrl: 'assets/printers/prusa-mini.png', desc: 'Compact Workhorse Magnetic Bed' },

  // UltiMaker
  { id: 'ultimaker-s7', brand: 'UltiMaker', model: 'S7', width: 330, height: 240, maxZ: 300, tag: 'Dual Extrusion', imageUrl: 'assets/printers/ultimaker.jpg', desc: 'Integrated Air Manager & Flexible Plate' },
  { id: 'ultimaker-s5', brand: 'UltiMaker', model: 'S5', width: 330, height: 240, maxZ: 300, tag: 'Dual Extrusion', imageUrl: 'assets/printers/ultimaker.jpg', desc: 'Large Volume Dual Material Chamber' },
  { id: 'ultimaker-s3', brand: 'UltiMaker', model: 'S3', width: 230, height: 190, maxZ: 200, tag: 'Precision Dual', imageUrl: 'assets/printers/ultimaker.jpg', desc: 'Compact Dual Extrusion Core System' },

  // Creality
  { id: 'creality-k1c', brand: 'Creality', model: 'K1C', width: 220, height: 220, maxZ: 250, tag: 'Enclosed CoreXY', imageUrl: 'assets/printers/creality-ender3.jpg', desc: 'Carbon-Fiber Ready 600mm/s CoreXY' },
  { id: 'creality-k1max', brand: 'Creality', model: 'K1 Max', width: 300, height: 300, maxZ: 300, tag: 'Large CoreXY', imageUrl: 'assets/printers/creality-ender3.jpg', desc: 'Dual AI Lidar & 300mm Cube Bed' },
  { id: 'creality-e3v3', brand: 'Creality', model: 'Ender-3 V3', width: 220, height: 220, maxZ: 250, tag: 'CoreXZ Slinger', imageUrl: 'assets/printers/creality-ender3.jpg', desc: '600mm/s High-Speed CoreXZ' },

  // Voron Design
  { id: 'voron-24', brand: 'Voron', model: 'Voron 2.4 (300mm)', width: 300, height: 300, maxZ: 300, tag: 'Flying Gantry', imageUrl: 'assets/printers/voron.jpg', desc: 'Quad Z Belts & High-Speed CoreXY' },
  { id: 'voron-trident', brand: 'Voron', model: 'Voron Trident', width: 250, height: 250, maxZ: 250, tag: 'Triple LeadScrew', imageUrl: 'assets/printers/voron.jpg', desc: 'Fixed Gantry 3-Point Bed Leveling' },
  { id: 'voron-v0', brand: 'Voron', model: 'Voron V0.2', width: 120, height: 120, maxZ: 120, tag: 'Ultra-Compact', imageUrl: 'assets/printers/voron.jpg', desc: '120mm Enclosed Desktop Rocket' },

  // Elegoo
  { id: 'elegoo-n4pro', brand: 'Elegoo', model: 'Neptune 4 Pro', width: 225, height: 225, maxZ: 265, tag: 'High Speed', imageUrl: 'assets/printers/creality-ender3.jpg', desc: 'Klipper Direct Drive & Dual Bed Zones' },
  { id: 'elegoo-n4plus', brand: 'Elegoo', model: 'Neptune 4 Plus', width: 320, height: 320, maxZ: 385, tag: 'Large Format', imageUrl: 'assets/printers/creality-ender3.jpg', desc: '320x320mm High-Speed Large Bed' },

  // Custom
  { id: 'custom-bed', brand: 'Custom', model: 'Custom Dimensions', width: 200, height: 200, maxZ: 200, tag: 'User Defined', imageUrl: '', desc: 'Configure Any Slicer Build Plate Size' },
];

// Global Reactive State
const state = {
  image: null,
  sourceCanvas: null,
  width: 512,
  height: 512,
  luminance: null,
  smoothedLuminance: null,
  colorMapIndices: null,
  cleanColorMap: null,
  maxColorCount: 4,
  adjustments: {
    brightness: 0.0,
    contrast: 1.1,
    gamma: 1.0,
    invert: false,
  },
  smoothingRadius: 1.5,
  despike: true,
  smoothTerraces: true,
  dimensions: {
    widthMm: 150.0,
    heightMm: 150.0,
    minZ: 0.80,
    maxZ: 4.00,
    firstLayerHeight: 0.16,
    layerHeight: 0.08,
  },
  filaments: [],
  printer: {
    id: 'bambu-x1c',
    brand: 'Bambu Lab',
    model: 'X1 Carbon',
    width: 256,
    height: 256,
    maxZ: 256,
    tag: 'Enclosed CoreXY',
    imageUrl: 'assets/printers/bambu-x1c.png',
    desc: 'Micro Lidar, 1080p Cam & Dual PEI',
  },
  printerBrandFilter: 'All',
  viewMode: '3d',
  scrubLayer: 0,
  showGrid: true,
  showWire: false,
  showBuildPlate: true,
  quantizeLayers: true,
  zScaleVisual: 10.0,
  isDark: true,
};

let filamentColorCacheKey = '';
let filamentColorCache = [];

function getFilamentRgb() {
  const key = state.filaments.map(f => f.color).join('|');
  if (key !== filamentColorCacheKey) {
    filamentColorCacheKey = key;
    filamentColorCache = state.filaments.map(f => hexToRgb(f.color));
  }
  return filamentColorCache;
}

// Color Conversion Helpers
function srgbToLinear(c) {
  return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
}

function linearToSrgb(c) {
  return c <= 0.0031308 ? c * 12.92 : 1.055 * Math.pow(c, 1.0 / 2.4) - 0.055;
}

function hexToRgb(hex) {
  const bigint = parseInt(hex.replace('#', ''), 16);
  return {
    r: ((bigint >> 16) & 255) / 255.0,
    g: ((bigint >> 8) & 255) / 255.0,
    b: (bigint & 255) / 255.0,
  };
}

function rgbToHex(r, g, b) {
  return '#' + ((1 << 24) + (r << 16) + (g << 8) + b).toString(16).slice(1);
}

function getLayerZ(layerNum) {
  if (layerNum === 0) return state.dimensions.maxZ;
  if (layerNum === 1) return state.dimensions.firstLayerHeight;
  return state.dimensions.firstLayerHeight + (layerNum - 1) * state.dimensions.layerHeight;
}

function showToast(msg) {
  const toast = document.getElementById('toast');
  const toastMsg = document.getElementById('toastMsg');
  if (!toast || !toastMsg) return;
  toastMsg.innerText = msg;
  toast.classList.remove('translate-y-20', 'opacity-0');
  setTimeout(() => {
    toast.classList.add('translate-y-20', 'opacity-0');
  }, 3000);
}

function downloadBlob(blob, filename) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}
