/**
 * Rendered checks for a user manual, run in the browser on the manual itself (served locally or inside
 * the destination iframe). Complements check-manual.mjs with what only exists once frames render.
 *
 *   await __umCheckRendered()            // in the manual's window
 *   await __umCheckRendered(iframe.contentWindow)   // from the Grid view, on its iframe
 *
 * Returns { frames, unrendered, fit, pins, ok }:
 *   unrendered  captures that did not render (no shadow root or no height)
 *   fit         captures whose visible content is closer than 16 px to an edge (cut or cramped)
 *   pins        anchored pins that are not 14 px left of what the reader sees in their element (its text
 *               and media, or the whole box when it is filled or bordered), or that fall outside the capture
 * Run it at desktop width (1280 px) and at phone width (390 px): both must return ok: true.
 */
(function () {
	const MIN_GAP_PX = 16;
	const PIN_GAP_PX = 14;
	// Inside a full-width target: pin radius (12) + inset (4).
	const PIN_INSIDE_PX = 16;
	const TOLERANCE_PX = 2;
	const RENDER_WAIT_MS = 2500;

	// Left edge of what the reader actually sees inside an element (text, images, icons), which can be far
	// from the element's own box when it is a wide cell or row.
	// Same rule as the capture runtime: a filled or bordered box counts whole; otherwise its text and media.
	const TRANSPARENT = /^transparent$|rgba\([^)]*,\s*0\)$/;
	const visibleBox = (element, view) => {
		const style = view.getComputedStyle(element);
		const background = style.backgroundColor;
		const filled = background && background !== 'transparent' && !TRANSPARENT.test(background);
		const bordered = parseFloat(style.borderLeftWidth) > 0 && !TRANSPARENT.test(style.borderLeftColor);
		if (filled || bordered) return element.getBoundingClientRect();
		const box = { left: Infinity, top: Infinity, right: -Infinity, bottom: -Infinity };
		const add = (rect) => {
			if (!rect.width || !rect.height) return;
			box.left = Math.min(box.left, rect.left); box.top = Math.min(box.top, rect.top);
			box.right = Math.max(box.right, rect.right); box.bottom = Math.max(box.bottom, rect.bottom);
		};
		const range = element.ownerDocument.createRange();
		const walker = element.ownerDocument.createTreeWalker(element, view.NodeFilter.SHOW_TEXT);
		for (let node = walker.nextNode(); node; node = walker.nextNode()) {
			if (!node.textContent.trim()) continue;
			range.selectNodeContents(node);
			[...range.getClientRects()].forEach(add);
		}
		element.querySelectorAll('img, svg, picture, canvas, input, button, textarea, select').forEach((media) => add(media.getBoundingClientRect()));
		if (box.left === Infinity) return element.getBoundingClientRect();
		return { left: box.left, top: box.top, width: box.right - box.left, height: box.bottom - box.top };
	};

	const visibleBounds = (pageElement, view) => {
		const box = { left: Infinity, top: Infinity, right: -Infinity, bottom: -Infinity };
		pageElement.querySelectorAll('[data-capture-root], [data-capture-root] *').forEach((element) => {
			const rect = element.getBoundingClientRect();
			const style = view.getComputedStyle(element);
			if (!rect.width || !rect.height || style.display === 'none' || style.visibility === 'hidden' || style.opacity === '0') return;
			box.left = Math.min(box.left, rect.left);
			box.top = Math.min(box.top, rect.top);
			box.right = Math.max(box.right, rect.right);
			box.bottom = Math.max(box.bottom, rect.bottom);
		});
		return box;
	};

	window.__umCheckRendered = async (view = window) => {
		const manual = view.document;
		view.dispatchEvent(new view.Event('beforeprint'));
		await new Promise((resolve) => setTimeout(resolve, RENDER_WAIT_MS));
		const hosts = [...manual.querySelectorAll('.app-frame')];
		const unrendered = hosts.filter((host) => !host.shadowRoot || host.getBoundingClientRect().height < 40).map((host) => host.dataset.cap);
		const fit = hosts.flatMap((host) => {
			const pageElement = host.shadowRoot && host.shadowRoot.querySelector('.app-frame__page');
			if (!pageElement) return [];
			const pageRect = pageElement.getBoundingClientRect();
			const box = visibleBounds(pageElement, view);
			if (box.left === Infinity) return [[host.dataset.cap, 'empty']];
			const gaps = [box.top - pageRect.top, pageRect.bottom - box.bottom, box.left - pageRect.left, pageRect.right - box.right].map(Math.round);
			// Full-width app screens touch the sides by design; only top/bottom cuts and overflow matter there.
			const cut = gaps[0] < MIN_GAP_PX || gaps[1] < MIN_GAP_PX || gaps[2] < 0 || gaps[3] < 0;
			return cut ? [[host.dataset.cap, gaps]] : [];
		});
		const pins = [];
		manual.querySelectorAll('.hotspot-stage').forEach((stage) => {
			const host = stage.querySelector('.app-frame');
			stage.querySelectorAll('.hotspot').forEach((pin) => {
				const key = `${host ? host.dataset.cap : 'mockup-body'}#${pin.dataset.hotspot}`;
				if (!host) return;
				if (!pin.dataset.target) { pins.push([key, 'no data-target']); return; }
				const candidates = host.shadowRoot ? [...host.shadowRoot.querySelectorAll(pin.dataset.target)] : [];
				const target = pin.dataset.targetText ? candidates.find((element) => element.textContent.trim() === pin.dataset.targetText) : candidates[0];
				if (!target) { pins.push([key, `target not found: ${pin.dataset.target} ${pin.dataset.targetText || ''}`.trim()]); return; }
				const pinRect = pin.getBoundingClientRect();
				const rect = visibleBox(target, view);
				// 14 px left of what the reader sees, 14 px right of it when the target starts at the capture's edge,
				// or just inside its left edge when there is no room on either side.
				const pinCenter = pinRect.left + pinRect.width / 2;
				const leftGap = Math.round(rect.left - pinCenter);
				const rightGap = Math.round(pinCenter - (rect.left + rect.width));
				const insideGap = Math.round(pinCenter - rect.left);
				const placements = pin.dataset.side === 'right' ? [rightGap - PIN_GAP_PX] : [leftGap - PIN_GAP_PX, rightGap - PIN_GAP_PX, insideGap - PIN_INSIDE_PX];
				const horizontal = PIN_GAP_PX + placements.reduce((best, offset) => (Math.abs(offset) < Math.abs(best) ? offset : best));
				const vertical = Math.round(pinRect.top + pinRect.height / 2 - (rect.top + rect.height / 2));
				if (Math.abs(horizontal - PIN_GAP_PX) > TOLERANCE_PX || Math.abs(vertical) > TOLERANCE_PX) pins.push([key, [leftGap, vertical]]);
				// A pin anchored to a full-width element lands on (or past) the capture's edge and shows cut.
				const stageRect = stage.getBoundingClientRect();
				if (pinRect.left < stageRect.left || pinRect.right > stageRect.right) pins.push([key, 'outside the capture: anchor it to a compact element']);
			});
		});
		return { width: view.innerWidth, frames: hosts.length, unrendered, fit, pins, ok: !unrendered.length && !fit.length && !pins.length };
	};
})();
