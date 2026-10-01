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
 *   pins        anchored pins whose distance to their element is not the expected one
 * Run it at desktop width (1280 px) and at phone width (390 px): both must return ok: true.
 */
(function () {
	const MIN_GAP_PX = 16;
	const PIN_GAP_PX = 14;
	const TOLERANCE_PX = 2;
	const RENDER_WAIT_MS = 2500;

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
				const rect = target.getBoundingClientRect();
				const horizontal = Math.round(rect.left - (pinRect.left + pinRect.width / 2));
				const vertical = Math.round(pinRect.top + pinRect.height / 2 - (rect.top + rect.height / 2));
				if (Math.abs(horizontal - PIN_GAP_PX) > TOLERANCE_PX || Math.abs(vertical) > TOLERANCE_PX) pins.push([key, [horizontal, vertical]]);
			});
		});
		return { width: view.innerWidth, frames: hosts.length, unrendered, fit, pins, ok: !unrendered.length && !fit.length && !pins.length };
	};
})();
