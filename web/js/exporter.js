/**
 * 2MF Studio — Production Slicer Exporters (.3MF Multi-Color & Binary .STL)
 */

async function export3MF() {
  const zip = new JSZip();

  zip.file(
    "[Content_Types].xml",
    `<?xml version="1.0" encoding="UTF-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="model" ContentType="application/vnd.ms-package.3dmanufacturing-3dmodel+xml"/>
</Types>`
  );

  zip.file(
    "_rels/.rels",
    `<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Target="/3D/3dmodel.model" Id="rel0" Type="http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel"/>
</Relationships>`
  );

  const gridRes = 160;
  const gw = gridRes;
  const gh = gridRes;
  const wMm = state.dimensions.widthMm;
  const hMm = state.dimensions.heightMm;

  const vertsXmlChunks = [];
  const trisXmlChunks = [];

  // 1. Top grid vertices
  for (let j = 0; j < gh; j++) {
    const v = j / (gh - 1);
    const y = (v - 0.5) * hMm;
    for (let i = 0; i < gw; i++) {
      const u = i / (gw - 1);
      const x = (u - 0.5) * wMm;
      const lum = sampleLuminanceBilinear(u, v);
      const z = calculateZFromLum(lum);
      vertsXmlChunks.push(`          <vertex x="${x.toFixed(3)}" y="${y.toFixed(3)}" z="${z.toFixed(3)}" />\n`);
    }
  }

  // 2. Bottom grid vertices at z = 0.000
  const bOffset = gw * gh;
  for (let j = 0; j < gh; j++) {
    const v = j / (gh - 1);
    const y = (v - 0.5) * hMm;
    for (let i = 0; i < gw; i++) {
      const u = i / (gw - 1);
      const x = (u - 0.5) * wMm;
      vertsXmlChunks.push(`          <vertex x="${x.toFixed(3)}" y="${y.toFixed(3)}" z="0.000" />\n`);
    }
  }

  // 3. Top surface triangles
  for (let j = 0; j < gh - 1; j++) {
    const vMid = (j + 0.5) / (gh - 1);
    for (let i = 0; i < gw - 1; i++) {
      const uMid = (i + 0.5) / (gw - 1);
      const filSlot = sampleColorAtUV(uMid, vMid);

      const idx00 = j * gw + i;
      const idx10 = j * gw + (i + 1);
      const idx01 = (j + 1) * gw + i;
      const idx11 = (j + 1) * gw + (i + 1);

      trisXmlChunks.push(`          <triangle v1="${idx00}" v2="${idx10}" v3="${idx11}" pid="1" p1="${filSlot}" />\n`);
      trisXmlChunks.push(`          <triangle v1="${idx00}" v2="${idx11}" v3="${idx01}" pid="1" p1="${filSlot}" />\n`);
    }
  }

  // 4. Bottom surface triangles (Z = 0, outward normal facing -Z, base color p1="0")
  for (let j = 0; j < gh - 1; j++) {
    for (let i = 0; i < gw - 1; i++) {
      const idx00 = bOffset + j * gw + i;
      const idx10 = bOffset + j * gw + (i + 1);
      const idx01 = bOffset + (j + 1) * gw + i;
      const idx11 = bOffset + (j + 1) * gw + (i + 1);

      trisXmlChunks.push(`          <triangle v1="${idx00}" v2="${idx11}" v3="${idx10}" pid="1" p1="0" />\n`);
      trisXmlChunks.push(`          <triangle v1="${idx00}" v2="${idx01}" v3="${idx11}" pid="1" p1="0" />\n`);
    }
  }

  // 5. 4 Vertical Side Walls (connecting top edge to bottom edge at Z = 0, p1="0")
  // Wall 1: Bottom Edge (j = 0, y = -h/2)
  for (let i = 0; i < gw - 1; i++) {
    const top0 = 0 * gw + i;
    const top1 = 0 * gw + (i + 1);
    const bot0 = bOffset + top0;
    const bot1 = bOffset + top1;

    trisXmlChunks.push(`          <triangle v1="${top0}" v2="${bot0}" v3="${top1}" pid="1" p1="0" />\n`);
    trisXmlChunks.push(`          <triangle v1="${top1}" v2="${bot0}" v3="${bot1}" pid="1" p1="0" />\n`);
  }

  // Wall 2: Top Edge (j = gh - 1, y = +h/2)
  const lastJ = gh - 1;
  for (let i = 0; i < gw - 1; i++) {
    const top0 = lastJ * gw + i;
    const top1 = lastJ * gw + (i + 1);
    const bot0 = bOffset + top0;
    const bot1 = bOffset + top1;

    trisXmlChunks.push(`          <triangle v1="${top0}" v2="${top1}" v3="${bot0}" pid="1" p1="0" />\n`);
    trisXmlChunks.push(`          <triangle v1="${top1}" v2="${bot1}" v3="${bot0}" pid="1" p1="0" />\n`);
  }

  // Wall 3: Left Edge (i = 0, x = -w/2)
  for (let j = 0; j < gh - 1; j++) {
    const top0 = j * gw + 0;
    const top1 = (j + 1) * gw + 0;
    const bot0 = bOffset + top0;
    const bot1 = bOffset + top1;

    trisXmlChunks.push(`          <triangle v1="${top0}" v2="${top1}" v3="${bot0}" pid="1" p1="0" />\n`);
    trisXmlChunks.push(`          <triangle v1="${top1}" v2="${bot1}" v3="${bot0}" pid="1" p1="0" />\n`);
  }

  // Wall 4: Right Edge (i = gw - 1, x = +w/2)
  const lastI = gw - 1;
  for (let j = 0; j < gh - 1; j++) {
    const top0 = j * gw + lastI;
    const top1 = (j + 1) * gw + lastI;
    const bot0 = bOffset + top0;
    const bot1 = bOffset + top1;

    trisXmlChunks.push(`          <triangle v1="${top0}" v2="${bot0}" v3="${top1}" pid="1" p1="0" />\n`);
    trisXmlChunks.push(`          <triangle v1="${top1}" v2="${bot0}" v3="${bot1}" pid="1" p1="0" />\n`);
  }

  let colorGroupXml = '';
  state.filaments.forEach(fil => {
    colorGroupXml += `      <m:color color="${fil.color}" />\n`;
  });

  const modelXml = `<?xml version="1.0" encoding="UTF-8"?>
<model unit="millimeter" xml:lang="en-US" xmlns="http://schemas.microsoft.com/3dmanufacturing/core/2015/02" xmlns:m="http://schemas.microsoft.com/3dmanufacturing/material/2015/02">
  <metadata name="Title">Layerloom Multi-Color Filament Relief</metadata>
  <metadata name="Application">Layerloom Studio</metadata>
  <resources>
    <m:colorgroup id="1">
${colorGroupXml}    </m:colorgroup>
    <object id="2" type="model">
      <mesh>
        <vertices>
${vertsXmlChunks.join('')}        </vertices>
        <triangles>
${trisXmlChunks.join('')}        </triangles>
      </mesh>
    </object>
  </resources>
  <build>
    <item objectid="2" />
  </build>
</model>`;
  zip.file("3D/3dmodel.model", modelXml);

  let swapGuide = `=====================================================\n       LAYERLOOM FILAMENT SWAP INSTRUCTIONS           \n=====================================================\n\n`;
  let prevL = 1;
  state.filaments.forEach((fil, idx) => {
    const endL = Math.max(1, Math.round((fil.endZ - state.dimensions.firstLayerHeight) / state.dimensions.layerHeight) + 1);
    if (idx === 0) {
      swapGuide += `Start with Spool #${fil.slot} (${fil.name}) [${fil.color}]\n  -> Layers 1 - ${endL} (0.00mm - ${fil.endZ.toFixed(2)}mm)\n\n`;
    } else {
      swapGuide += `Swap to Spool #${fil.slot} (${fil.name}) [${fil.color}]\n  -> At Layer ${prevL} (${fil.startZ.toFixed(2)}mm) up to Layer ${endL} (${fil.endZ.toFixed(2)}mm)\n\n`;
    }
    prevL = endL;
  });
  zip.file("Metadata/filament_swap_guide.txt", swapGuide);

  const blob = await zip.generateAsync({ type: "blob" });
  downloadBlob(blob, "filament_painting.3mf");
  showToast("Downloaded watertight solid .3MF with walls");
}

function calcTriNormal(v1, v2, v3) {
  const e1x = v2.x - v1.x, e1y = v2.y - v1.y, e1z = v2.z - v1.z;
  const e2x = v3.x - v1.x, e2y = v3.y - v1.y, e2z = v3.z - v1.z;
  const nx = e1y * e2z - e1z * e2y;
  const ny = e1z * e2x - e1x * e2z;
  const nz = e1x * e2y - e1y * e2x;
  const l = Math.sqrt(nx * nx + ny * ny + nz * nz) || 1.0;
  return { x: nx / l, y: ny / l, z: nz / l };
}

function exportSTL() {
  const gridRes = 160;
  const gw = gridRes;
  const gh = gridRes;
  const wMm = state.dimensions.widthMm;
  const hMm = state.dimensions.heightMm;

  // Total Triangles: Top (quads*2) + Bottom (quads*2) + 4 Walls (edgeQuads*2)
  const topQuads = (gw - 1) * (gh - 1);
  const wallQuads = ((gw - 1) + (gh - 1)) * 2;
  const triCount = (topQuads * 2 + wallQuads) * 2;

  const bufferSize = 84 + triCount * 50;
  const buffer = new ArrayBuffer(bufferSize);
  const view = new DataView(buffer);

  const headerStr = "Layerloom - Watertight Binary STL";
  for (let i = 0; i < 80; i++) {
    view.setUint8(i, i < headerStr.length ? headerStr.charCodeAt(i) : 0);
  }
  view.setUint32(80, triCount, true);

  // Pre-sample Z values for the grid
  const zGrid = new Float32Array(gw * gh);
  for (let j = 0; j < gh; j++) {
    const v = j / (gh - 1);
    for (let i = 0; i < gw; i++) {
      const u = i / (gw - 1);
      zGrid[j * gw + i] = calculateZFromLum(sampleLuminanceBilinear(u, v));
    }
  }

  let offset = 84;

  // 1. TOP SURFACE TRIANGLES
  for (let j = 0; j < gh - 1; j++) {
    const v0 = j / (gh - 1);
    const v1 = (j + 1) / (gh - 1);
    const y0 = (v0 - 0.5) * hMm;
    const y1 = (v1 - 0.5) * hMm;

    for (let i = 0; i < gw - 1; i++) {
      const u0 = i / (gw - 1);
      const u1 = (i + 1) / (gw - 1);
      const x0 = (u0 - 0.5) * wMm;
      const x1 = (u1 - 0.5) * wMm;

      const z00 = zGrid[j * gw + i];
      const z10 = zGrid[j * gw + (i + 1)];
      const z01 = zGrid[(j + 1) * gw + i];
      const z11 = zGrid[(j + 1) * gw + (i + 1)];

      const pt00 = { x: x0, y: y0, z: z00 };
      const pt10 = { x: x1, y: y0, z: z10 };
      const pt11 = { x: x1, y: y1, z: z11 };
      const pt01 = { x: x0, y: y1, z: z01 };

      const n1 = calcTriNormal(pt00, pt10, pt11);
      writeStlTri(view, offset, n1, pt00, pt10, pt11);
      offset += 50;

      const n2 = calcTriNormal(pt00, pt11, pt01);
      writeStlTri(view, offset, n2, pt00, pt11, pt01);
      offset += 50;
    }
  }

  // 2. BOTTOM BASE SURFACE TRIANGLES (Z = 0, normal facing down {0, 0, -1})
  const normDown = { x: 0, y: 0, z: -1 };
  for (let j = 0; j < gh - 1; j++) {
    const v0 = j / (gh - 1);
    const v1 = (j + 1) / (gh - 1);
    const y0 = (v0 - 0.5) * hMm;
    const y1 = (v1 - 0.5) * hMm;

    for (let i = 0; i < gw - 1; i++) {
      const u0 = i / (gw - 1);
      const u1 = (i + 1) / (gw - 1);
      const x0 = (u0 - 0.5) * wMm;
      const x1 = (u1 - 0.5) * wMm;

      const bot00 = { x: x0, y: y0, z: 0.0 };
      const bot10 = { x: x1, y: y0, z: 0.0 };
      const bot11 = { x: x1, y: y1, z: 0.0 };
      const bot01 = { x: x0, y: y1, z: 0.0 };

      // Reversed winding for downward facing normal
      writeStlTri(view, offset, normDown, bot00, bot11, bot10);
      offset += 50;

      writeStlTri(view, offset, normDown, bot00, bot01, bot11);
      offset += 50;
    }
  }

  // 3. 4 VERTICAL SIDE WALLS
  // Wall 1: Bottom Edge (j = 0, y = -hMm/2, normal {0, -1, 0})
  const yNorth = -0.5 * hMm;
  const normNorth = { x: 0, y: -1, z: 0 };
  for (let i = 0; i < gw - 1; i++) {
    const u0 = i / (gw - 1);
    const u1 = (i + 1) / (gw - 1);
    const x0 = (u0 - 0.5) * wMm;
    const x1 = (u1 - 0.5) * wMm;

    const t0 = { x: x0, y: yNorth, z: zGrid[0 * gw + i] };
    const t1 = { x: x1, y: yNorth, z: zGrid[0 * gw + (i + 1)] };
    const b0 = { x: x0, y: yNorth, z: 0.0 };
    const b1 = { x: x1, y: yNorth, z: 0.0 };

    writeStlTri(view, offset, normNorth, t0, b0, t1);
    offset += 50;
    writeStlTri(view, offset, normNorth, t1, b0, b1);
    offset += 50;
  }

  // Wall 2: Top Edge (j = gh - 1, y = +hMm/2, normal {0, 1, 0})
  const ySouth = 0.5 * hMm;
  const normSouth = { x: 0, y: 1, z: 0 };
  for (let i = 0; i < gw - 1; i++) {
    const u0 = i / (gw - 1);
    const u1 = (i + 1) / (gw - 1);
    const x0 = (u0 - 0.5) * wMm;
    const x1 = (u1 - 0.5) * wMm;

    const t0 = { x: x0, y: ySouth, z: zGrid[(gh - 1) * gw + i] };
    const t1 = { x: x1, y: ySouth, z: zGrid[(gh - 1) * gw + (i + 1)] };
    const b0 = { x: x0, y: ySouth, z: 0.0 };
    const b1 = { x: x1, y: ySouth, z: 0.0 };

    writeStlTri(view, offset, normSouth, t0, t1, b0);
    offset += 50;
    writeStlTri(view, offset, normSouth, t1, b1, b0);
    offset += 50;
  }

  // Wall 3: Left Edge (i = 0, x = -wMm/2, normal {-1, 0, 0})
  const xWest = -0.5 * wMm;
  const normWest = { x: -1, y: 0, z: 0 };
  for (let j = 0; j < gh - 1; j++) {
    const v0 = j / (gh - 1);
    const v1 = (j + 1) / (gh - 1);
    const y0 = (v0 - 0.5) * hMm;
    const y1 = (v1 - 0.5) * hMm;

    const t0 = { x: xWest, y: y0, z: zGrid[j * gw + 0] };
    const t1 = { x: xWest, y: y1, z: zGrid[(j + 1) * gw + 0] };
    const b0 = { x: xWest, y: y0, z: 0.0 };
    const b1 = { x: xWest, y: y1, z: 0.0 };

    writeStlTri(view, offset, normWest, t0, t1, b0);
    offset += 50;
    writeStlTri(view, offset, normWest, t1, b1, b0);
    offset += 50;
  }

  // Wall 4: Right Edge (i = gw - 1, x = +wMm/2, normal {1, 0, 0})
  const xEast = 0.5 * wMm;
  const normEast = { x: 1, y: 0, z: 0 };
  for (let j = 0; j < gh - 1; j++) {
    const v0 = j / (gh - 1);
    const v1 = (j + 1) / (gh - 1);
    const y0 = (v0 - 0.5) * hMm;
    const y1 = (v1 - 0.5) * hMm;

    const t0 = { x: xEast, y: y0, z: zGrid[j * gw + (gw - 1)] };
    const t1 = { x: xEast, y: y1, z: zGrid[(j + 1) * gw + (gw - 1)] };
    const b0 = { x: xEast, y: y0, z: 0.0 };
    const b1 = { x: xEast, y: y1, z: 0.0 };

    writeStlTri(view, offset, normEast, t0, b0, t1);
    offset += 50;
    writeStlTri(view, offset, normEast, t1, b0, b1);
    offset += 50;
  }

  const blob = new Blob([buffer], { type: "application/octet-stream" });
  downloadBlob(blob, "filament_painting.stl");
  showToast("Downloaded watertight solid STL with walls");
}

function writeStlTri(view, offset, n, v1, v2, v3) {
  view.setFloat32(offset, n.x, true);
  view.setFloat32(offset + 4, n.y, true);
  view.setFloat32(offset + 8, n.z, true);
  view.setFloat32(offset + 12, v1.x, true);
  view.setFloat32(offset + 16, v1.y, true);
  view.setFloat32(offset + 20, v1.z, true);
  view.setFloat32(offset + 24, v2.x, true);
  view.setFloat32(offset + 28, v2.y, true);
  view.setFloat32(offset + 32, v2.z, true);
  view.setFloat32(offset + 36, v3.x, true);
  view.setFloat32(offset + 40, v3.y, true);
  view.setFloat32(offset + 44, v3.z, true);
  view.setUint16(offset + 48, 0, true);
}
