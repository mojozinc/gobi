---
name: generate-reading-doc
description: Generates clean, modern, distraction-free HTML reading documents with crisp typography, CSS variables, dark/light theme toggle, interactive pan/zoom Mermaid diagrams, and structured callouts. Use when creating standalone technical documentation, architecture flow guides, post-mortems, or reading artifacts.
---

# Generating Clean HTML Reading Documents

## Contents
- [Core Design Principles](#core-design-principles)
- [Typography & Layout System](#typography--layout-system)
- [Color Palette & CSS Variables](#color-palette--css-variables)
- [Dark / Light Theme Toggle Component](#dark--light-theme-toggle-component)
- [Interactive Mermaid Pan/Zoom Component](#interactive-mermaid-panzoom-component)
- [Standard Content Blocks](#standard-content-blocks)
- [Complete Starter Boilerplate](#complete-starter-boilerplate)

---

## Core Design Principles

1. **Focus on Readability & Typography First**:
   - Optimal reading width: `max-width: 840px` centered with `padding: 48px 20px 80px`.
   - Body font: `Inter`, `-apple-system`, `BlinkMacSystemFont`, `"Segoe UI"`, `Roboto`, `sans-serif`.
   - Base font size: `15px`, line height: `1.65`.
   - Monospace font: `JetBrains Mono`, `monospace` (font size: `13px`).
2. **Distraction-Free Aesthetics**:
   - **No gradients, no flashy animations, no heavy JavaScript libraries**.
   - Generous whitespace, crisp borders, subtle background elevations.
3. **First-Class Dark / Light Mode Support**:
   - Instant theme switching via CSS custom properties on `:root` and `[data-theme="dark"]`.
   - `localStorage` persistence and automatic OS `prefers-color-scheme` detection.
4. **24-Inch Monitor & Responsive Diagrams**:
   - Interactive Mermaid diagrams with built-in toolbar: `Zoom In (+)`, `Zoom Out (-)`, `Reset (100%)`, `Fit Width (↔)`, and `Fullscreen (⛶)`.
   - Drag-to-pan, mouse wheel zoom at cursor, `ESC` key to exit fullscreen.

---

## Color Palette & CSS Variables

```css
:root {
  --bg: #ffffff;
  --bg-alt: #f8fafc;
  --bg-viewport: #fafbfc;
  --grid-dot: #cbd5e1;
  --text: #0f172a;
  --text-muted: #475569;
  --text-subtle: #94a3b8;
  --border: #e2e8f0;
  --border-dark: #cbd5e1;
  --primary: #0284c7;
  --primary-subtle: #e0f2fe;
  --accent: #0f766e;
  --accent-subtle: #ccfbf1;
  --warning-bg: #fffbeb;
  --warning-border: #f59e0b;
  --warning-text: #92400e;
  --code-bg: #f1f5f9;
  --radius: 8px;
}

[data-theme="dark"] {
  --bg: #0f172a;
  --bg-alt: #1e293b;
  --bg-viewport: #0b1120;
  --grid-dot: #334155;
  --text: #f8fafc;
  --text-muted: #94a3b8;
  --text-subtle: #64748b;
  --border: #334155;
  --border-dark: #475569;
  --primary: #38bdf8;
  --primary-subtle: #082f49;
  --accent: #2dd4bf;
  --accent-subtle: #134e4a;
  --warning-bg: #451a03;
  --warning-border: #d97706;
  --warning-text: #fde68a;
  --code-bg: #1e293b;
}
```

---

## Standard Content Blocks

### 1. Header & Badge
```html
<header>
  <div class="header-top">
    <div class="badge">Architecture & Flow Reference</div>
    <button class="theme-toggle" id="theme-toggle" title="Toggle Theme">
      <span class="theme-icon">🌙</span> <span class="theme-text">Dark Mode</span>
    </button>
  </div>
  <h1>Document Title</h1>
  <p class="subtitle">Brief summary of the document purpose and architecture.</p>
</header>
```

### 2. Numbered Flow Steps (`.flow-steps`)
```html
<div class="flow-steps">
  <div class="flow-step">
    <div class="step-number">1</div>
    <div class="step-content">
      <div class="step-header">Step Title</div>
      <div class="step-body">Step detailed description with formatted <code>inline code</code>.</div>
    </div>
  </div>
</div>
```

### 3. Key-Value Cards Grid (`.kv-grid`)
```html
<div class="kv-grid">
  <div class="kv-card">
    <div class="kv-title">Entity or Metric</div>
    <div class="kv-value">Current Value</div>
    <div class="kv-desc">Contextual description explaining this card.</div>
  </div>
</div>
```

### 4. Semantic Callouts
```html
<div class="callout callout-warning">
  <strong>Warning:</strong> Critical constraint or failure mode.
</div>

<div class="callout callout-info">
  <strong>Note:</strong> Helpful architectural context or recommendation.
</div>
```

---

## Complete Starter Boilerplate

Save this template as `document_name.html` when generating a new reading document:

```html
<!DOCTYPE html>
<html lang="en" data-theme="light">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Architecture Guide</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
  <style>
    :root {
      --bg: #ffffff;
      --bg-alt: #f8fafc;
      --bg-viewport: #fafbfc;
      --grid-dot: #cbd5e1;
      --text: #0f172a;
      --text-muted: #475569;
      --text-subtle: #94a3b8;
      --border: #e2e8f0;
      --border-dark: #cbd5e1;
      --primary: #0284c7;
      --primary-subtle: #e0f2fe;
      --accent: #0f766e;
      --warning-bg: #fffbeb;
      --warning-border: #f59e0b;
      --warning-text: #92400e;
      --code-bg: #f1f5f9;
      --radius: 8px;
    }
    [data-theme="dark"] {
      --bg: #0f172a;
      --bg-alt: #1e293b;
      --bg-viewport: #0b1120;
      --grid-dot: #334155;
      --text: #f8fafc;
      --text-muted: #94a3b8;
      --text-subtle: #64748b;
      --border: #334155;
      --border-dark: #475569;
      --primary: #38bdf8;
      --primary-subtle: #082f49;
      --accent: #2dd4bf;
      --warning-bg: #451a03;
      --warning-border: #d97706;
      --warning-text: #fde68a;
      --code-bg: #1e293b;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: 'Inter', -apple-system, sans-serif;
      background: var(--bg);
      color: var(--text);
      line-height: 1.65;
      font-size: 15px;
      padding: 48px 20px 80px;
    }
    .container { max-width: 840px; margin: 0 auto; }
    header { margin-bottom: 40px; padding-bottom: 24px; border-bottom: 1px solid var(--border); }
    .header-top { display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; }
    .badge {
      font-size: 12px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.05em;
      color: var(--primary); background: var(--primary-subtle); padding: 4px 10px; border-radius: 4px;
    }
    .theme-toggle {
      background: var(--bg-alt); border: 1px solid var(--border); border-radius: 6px;
      padding: 6px 12px; font-size: 13px; font-weight: 600; color: var(--text); cursor: pointer;
      display: inline-flex; align-items: center; gap: 6px;
    }
    .theme-toggle:hover { background: var(--border); }
    h1 { font-size: 28px; font-weight: 700; margin-bottom: 8px; letter-spacing: -0.02em; }
    .subtitle { font-size: 16px; color: var(--text-muted); }
    h2 { font-size: 20px; font-weight: 700; margin-top: 48px; margin-bottom: 16px; padding-bottom: 8px; border-bottom: 1px solid var(--border); }
    p { margin-bottom: 16px; }
    /* Diagram Viewer */
    .diagram-wrapper { position: relative; background: var(--bg); border: 1px solid var(--border); border-radius: var(--radius); margin: 24px 0; overflow: hidden; }
    .diagram-toolbar { display: flex; justify-content: space-between; align-items: center; padding: 10px 16px; background: var(--bg-alt); border-bottom: 1px solid var(--border); }
    .diagram-viewport { height: 560px; overflow: hidden; cursor: grab; position: relative; background: var(--bg-viewport); background-image: radial-gradient(circle, var(--grid-dot) 1px, transparent 1px); background-size: 24px 24px; display: flex; align-items: center; justify-content: center; }
    .diagram-viewport.panning { cursor: grabbing; user-select: none; }
    .diagram-canvas { transform-origin: center center; will-change: transform; padding: 40px; }
    .btn-control { background: var(--bg); border: 1px solid var(--border); border-radius: 4px; padding: 5px 10px; font-size: 12px; font-weight: 600; color: var(--text); cursor: pointer; }
    .diagram-wrapper.fullscreen { position: fixed; top: 0; left: 0; width: 100vw; height: 100vh; z-index: 9999; margin: 0; border: none; display: flex; flex-direction: column; background: var(--bg); }
    .diagram-wrapper.fullscreen .diagram-viewport { flex: 1; height: auto; }
    /* Tables & Code */
    table { width: 100%; border-collapse: collapse; margin: 24px 0; border: 1px solid var(--border); border-radius: var(--radius); overflow: hidden; font-size: 14px; }
    th { background: var(--bg-alt); padding: 12px 16px; text-align: left; font-weight: 600; border-bottom: 1px solid var(--border); }
    td { padding: 12px 16px; border-bottom: 1px solid var(--border); }
    code { font-family: 'JetBrains Mono', monospace; font-size: 13px; background: var(--code-bg); padding: 2px 6px; border-radius: 4px; color: var(--primary); }
    pre { background: var(--bg-alt); border: 1px solid var(--border); border-radius: var(--radius); padding: 16px; overflow-x: auto; margin: 16px 0; }
    pre code { background: transparent; padding: 0; color: var(--text); }
  </style>
  <script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>
</head>
<body>
  <div class="container">
    <header>
      <div class="header-top">
        <div class="badge">Guide</div>
        <button class="theme-toggle" id="theme-toggle"><span class="theme-icon">🌙</span> <span class="theme-text">Dark Mode</span></button>
      </div>
      <h1>System Architecture</h1>
      <p class="subtitle">Complete technical overview of data flows and components.</p>
    </header>

    <main>
      <h2>Sequence Flow</h2>
      <div class="diagram-wrapper" id="diagram-wrapper">
        <div class="diagram-toolbar">
          <span style="font-weight:600;">Sequence Diagram</span>
          <div>
            <button class="btn-control" id="btn-zoom-in">+</button>
            <button class="btn-control" id="btn-zoom-out">&minus;</button>
            <button class="btn-control" id="btn-zoom-reset">Reset</button>
            <button class="btn-control" id="btn-fullscreen">⛶ Fullscreen</button>
          </div>
        </div>
        <div class="diagram-viewport" id="diagram-viewport">
          <div class="diagram-canvas" id="diagram-canvas">
            <div class="mermaid">
sequenceDiagram
    participant User
    participant App
    User->>App: Request
    App-->>User: Response
            </div>
          </div>
        </div>
      </div>
    </main>
  </div>

  <script>
    // 1. Theme Toggle Logic
    const toggleBtn = document.getElementById('theme-toggle');
    const root = document.documentElement;
    const storedTheme = localStorage.getItem('gobi_doc_theme') || (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
    setTheme(storedTheme);

    toggleBtn?.addEventListener('click', () => {
      const nextTheme = root.getAttribute('data-theme') === 'dark' ? 'light' : 'dark';
      setTheme(nextTheme);
    });

    function setTheme(theme) {
      root.setAttribute('data-theme', theme);
      localStorage.setItem('gobi_doc_theme', theme);
      if (toggleBtn) {
        toggleBtn.querySelector('.theme-icon').textContent = theme === 'dark' ? '☀️' : '🌙';
        toggleBtn.querySelector('.theme-text').textContent = theme === 'dark' ? 'Light Mode' : 'Dark Mode';
      }
    }

    // 2. Mermaid & Pan-Zoom Initialization
    mermaid.initialize({
      startOnLoad: true,
      theme: storedTheme === 'dark' ? 'dark' : 'neutral',
      sequence: { actorMargin: 70, messageMargin: 40, messageFontSize: 15, actorFontSize: 16 }
    });

    // Pan-Zoom Script
    const wrapper = document.getElementById('diagram-wrapper');
    const viewport = document.getElementById('diagram-viewport');
    const canvas = document.getElementById('diagram-canvas');
    let scale = 1.15, panX = 0, panY = 0, isPanning = false, startX = 0, startY = 0;

    function updateTransform() { canvas.style.transform = `translate(${panX}px, ${panY}px) scale(${scale})`; }
    document.getElementById('btn-zoom-in')?.addEventListener('click', () => { scale = Math.min(scale + 0.25, 4.0); updateTransform(); });
    document.getElementById('btn-zoom-out')?.addEventListener('click', () => { scale = Math.max(scale - 0.25, 0.4); updateTransform(); });
    document.getElementById('btn-zoom-reset')?.addEventListener('click', () => { scale = 1.15; panX = 0; panY = 0; updateTransform(); });
    document.getElementById('btn-fullscreen')?.addEventListener('click', () => {
      wrapper.classList.toggle('fullscreen');
      scale = wrapper.classList.contains('fullscreen') ? 1.45 : 1.15; panX = 0; panY = 0; updateTransform();
    });
    viewport?.addEventListener('mousedown', (e) => { isPanning = true; startX = e.clientX - panX; startY = e.clientY - panY; viewport.classList.add('panning'); });
    window.addEventListener('mousemove', (e) => { if (isPanning) { panX = e.clientX - startX; panY = e.clientY - startY; updateTransform(); } });
    window.addEventListener('mouseup', () => { isPanning = false; viewport?.classList.remove('panning'); });
    viewport?.addEventListener('wheel', (e) => { e.preventDefault(); scale = Math.min(Math.max(scale + (e.deltaY < 0 ? 0.15 : -0.15), 0.4), 4.0); updateTransform(); }, { passive: false });
  </script>
</body>
</html>
```
