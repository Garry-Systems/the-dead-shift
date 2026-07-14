class_name SafeArea
## Display cutout (punch-hole camera / status bar) handling for top-anchored HUD elements
## (launch hygiene v0.1.72). Pure static helper — no scene state, safe from any _ready().
##
## The project renders a 1080x1920 canvas_items/expand viewport, so a physical-pixel cutout
## height from DisplayServer must be converted to viewport pixels before it can be added to
## a Control's offset_top. In portrait with aspect=expand the horizontal axis is the fitted
## one (1080 viewport px == window width px), so the vertical conversion factor is
## 1080 / window_width. Returns 0.0 on desktop/headless (no cutout, or a zero window size —
## the probe-verified headless values), so every consumer can add it unconditionally.


## Top inset in VIEWPORT pixels that top-anchored HUD elements should shift down by.
## Clamped to 240 viewport px as insurance against a nonsense safe-area report — no real
## cutout/status-bar band is taller than ~12% of the screen.
static func top_inset() -> float:
	var win := DisplayServer.window_get_size()
	if win.x <= 0:
		return 0.0
	var to_viewport := 1080.0 / float(win.x)
	return clampf(DisplayServer.get_display_safe_area().position.y * to_viewport, 0.0, 240.0)
