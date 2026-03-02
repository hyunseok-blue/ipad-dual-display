Design a single-page web UI dashboard for an "iPad Dual Display + Monitor Setup Tool" on macOS.

Context: This tool helps users set up dual iPads + external monitor on an M1 MacBook. It has 3 modes:
1. Sidecar + Duet Display (most stable, paid)
2. Sidecar + BetterDisplay + VNC (one-time cost)  
3. Sidecar + Universal Control (free, limited)

The UI needs:
- Dark theme, modern macOS-inspired design
- A visual diagram showing the display arrangement (MacBook + 2 iPads + Monitor)
- Mode selection cards with pros/cons
- Status panel showing connected displays (live)
- One-click Start/Stop buttons
- Setup wizard flow for first-time users
- Responsive layout

Tech: Single HTML file with inline CSS/JS (no build tools needed). Use vanilla JS. The HTML file will be served by a simple Python HTTP server that also runs shell commands.

Provide the complete HTML/CSS/JS design with:
1. Color palette and typography choices
2. Component layout (ASCII mockup)
3. Key interaction patterns
4. The actual HTML structure with Tailwind CSS via CDN

Make it visually stunning - think of it as a premium macOS utility app.