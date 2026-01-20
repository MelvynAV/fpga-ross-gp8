# 🥈 FPGA ROSS Video Challenge – Group 8  
**2nd Place Winner – uOttaHack 8**

**Team:** Melvyn Avoa · Hassan Hadji  
🎥 **Demo:** https://youtu.be/604zTcAmVCg & https://youtu.be/63LUePm7tjw 

---

## Overview

This project is a **real-time sports broadcast renderer fully implemented on FPGA**. Inspired by professional TV broadcasts (e.g. ESPN), the system generates a complete **1080p soccer match** with animated players, ball physics, scoring, timers, and broadcast overlays — **entirely in hardware**, with no CPU or GPU.

---

## What It Does

**ESPN LIVE** renders in real time:
- Soccer field and animated players  
- Ball physics, goals, and score tracking  
- Match timer  
- Broadcast overlays (*ESPN LIVE*, *ROSS VIDEO*)  

All graphics are generated **pixel-by-pixel using deterministic FPGA logic**.

---

## Technical Architecture

- **Language:** SystemVerilog  
- **Toolchain:** Vivado  
- **Resolution:** 1920×1080 @ 60 FPS  
- **Design style:** Fully synchronous RTL  

---

## Video Pipeline

- DE-based video timing  
- Pixel position tracking *(x, y)*  
- Layered rendering pipeline:
  1. Background (field)  
  2. Players  
  3. Ball  
  4. Overlays & text  

Final pixel is composed in a **single clocked path**.

---

## Core Equations & Logic

### Ball Motion (Discrete-Time Physics)

Ball movement is updated once per frame using:
```
xₙ₊₁ = xₙ + vₓ
yₙ₊₁ = yₙ + vᵧ
```

Collision handling:
```
vₓ = -vₓ   // wall collision
vᵧ = -vᵧ
```

This ensures **deterministic, hardware-friendly motion** without floating-point arithmetic.

---

### Frame-Tick Game Logic

All gameplay logic is synchronized to a frame tick:
```
frame_tick = (x == 0 && y == 0)
```

Used to update:
- Player movement  
- Ball physics  
- Score and timer  
- Animations  

This guarantees stable real-time behavior independent of pixel clock speed.

---

### Rendering Condition (Per-Pixel)

Objects are rendered using bounding-box checks:
```
(pixel_x >= obj_x_start && pixel_x <= obj_x_end) &&
(pixel_y >= obj_y_start && pixel_y <= obj_y_end)
```

This allows efficient shape rendering directly in RTL.

---

## Challenges

- Long synthesis and implementation times  
- Debugging real-time RTL logic  
- Designing game mechanics without software constructs  
- Increased workload after a teammate left mid-project  

---

## Accomplishments

- 🥈 **2nd place at the ROSS Video FPGA Challenge**  
- Fully functional real-time 1080p broadcast engine  
- Stable video timing, gameplay, and overlays  
- Professional broadcast-style visuals — all in FPGA hardware  

---

## What We Learned

- FPGA video pipelines and timing constraints  
- SystemVerilog RTL design and debugging  
- Deterministic real-time hardware graphics  
- Teamwork, adaptability, and delivery under pressure  

---

## What’s Next

- More advanced physics and animations  
- Additional broadcast graphics  
- External inputs for interactivity  
- Support for other sports or resolutions  

---

## FPGA Architecture (ASCII Diagram)

```
                ┌────────────────────┐
                │  Video Timing Gen  │
                │  (HS, VS, DE)      │
                └─────────┬──────────┘
                          │
                  Pixel Coordinates
                      (x, y)
                          │
        ┌─────────────────┴─────────────────┐
        │                                   │
┌───────▼───────┐                   ┌───────▼───────┐
│ Game Logic    │                   │ Text & Overlay│
│ (frame-tick)  │                   │ Renderer      │
│ - players     │                   │ - fonts       │
│ - ball        │                   │ - scoreboard  │
│ - scoring     │                   │ - branding    │
└───────┬───────┘                   └───────┬───────┘
        │                                   │
        └──────────────┬────────────────────┘
                       │
              ┌────────▼────────┐
              │ Pixel Composer  │
              │ (layer priority)│
              └────────┬────────┘
                       │
                 RGB Output
                 (1080p)
```
