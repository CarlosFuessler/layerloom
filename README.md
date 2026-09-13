# Layerloom

Layerloom is the product name; `2mf` remains the repository and file-format project identifier.

A high-performance native desktop and web studio in **Zig** that converts 2D images into 3D-printable filament paintings using optical layer blending (**Beer-Lambert law**) and exports color-mapped **3MF** and watertight **STL** files compatible with modern slicers (**Bambu Studio**, **OrcaSlicer**, **PrusaSlicer**).

---

## 🌟 Available Runtimes

### 1. 🎨 HTML5 & Tailwind CSS Studio (Web / Desktop)
An ultra-sleek, modern dark-themed studio styled with **HTML5 and Tailwind CSS**:
- **Interactive 3D Relief Viewport:** WebGL / Three.js with orbit turntable controls, camera snaps (`Iso`, `Top`, `Front`, `Reset`), build plate grid (256x256mm), and wireframe toggle.
- **2D Beer-Lambert Transmission Preview:** Optical color simulation with real-time layer-by-layer scrubber.
- **Filament Palette Manager:** Presets (Bambu CMYK, PolyLite, Monochrome), circular color pickers, physical Transmission Distance (TD in mm) sliders, start/stop Z-height sliders, AMS slot mapping, and 1-click Auto-Distribute Z.
- **Tonal Luminance Histogram:** Live 256-bin histogram with vertical colored layer transition lines.
- **Slicer Schedule Table:** AMS / MMU layer change table with 1-click **Copy to Clipboard**.
- **Production Exports:** Direct download for color-mapped `.3MF` (complete ZIP archive with `<m:colorgroup>`, triangle mapping, and swap schedule text) and watertight binary `.STL`.
- **Drag & Drop:** Drop any image file directly into the interface.

To start the local studio server and auto-open in your default browser:
```bash
zig build server
# Or open web/index.html directly in any browser
```

---

### 2. ⚡ Raylib Native Desktop Application
A blazing-fast native desktop application written in pure Zig using **Raylib 5.5**:
- Zero SDL3, zero cimgui dependencies.
- Hardware-accelerated OpenGL 3D heightfield relief mesh rendering.
- Orbit and pan 3D camera controls with zoom.
- 2D Beer-Lambert optical texture compositor.
- Native OS Drag & Drop (`IsFileDropped`).
- Slicer swap schedule & export buttons.

To run the Raylib native application:
```bash
zig build run
```

## Desktop Releases

The `Build desktop releases` GitHub Actions workflow runs manually or whenever a `v*` tag is pushed. It publishes:

- `Layerloom.exe` for 64-bit Windows
- `Layerloom.dmg` for Apple Silicon macOS

To create a release:

```bash
git tag v1.0.0
git push origin v1.0.0
```

---

## 🧪 Testing & Sample Generation

```bash
# Run all unit and integration tests
zig build test

# Run the headless 3MF and STL exporter
zig build export_sample
```
