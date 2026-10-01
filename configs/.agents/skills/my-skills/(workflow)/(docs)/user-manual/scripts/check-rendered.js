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
 *   pins        anchored pins whose distance to their element is not the expected one, that sit far from
 *               the element's visible content (anchored to a wide box) or outside the capture
 * Run it at desktop width (1280 px) and at phone width (390 px): both must return ok: true.
 */
(function () {
	const MIN_GAP_PX = 16;
	const PIN_GAP_PX = 14;
	const TOLERANCE_PX = 2;
	const RENDER_WAIT_MS = 2500;

	const MAX_CONTENT_GAP_PX = 24;

	// Left edge of what the reader actually sees inside an element (text, images, icons), which can be far
	// from the element's own box when it is a wide cell or row.
	const hasVisibleBox = (element, view) => {
		const style = view.getComputedStyle(element);
		const background = style.backgroundColor;
		const filled = background && background !== 'transparent' && !/rgba\([^)]*,\s*0\)$/.test(background);
		return filled || parseFloat(style.borderLeftWidth) > 0 || style.boxShadow !== 'none';
	};
	const contentLeft = (element, view) => {
		// A filled or bordered box (a button, a chip) is itself what the reader sees.
		if (hasVisibleBox(element, view)) return element.getBoundingClientRect().left;
		let left = Infinity;
		const range = element.ownerDocument.createRange();
		const walker = element.ownerDocument.createTreeWalker(element, view.NodeFilter.SHOW_TEXT);
		for (let node = walker.nextNode(); node; node = walker.nextNode()) {
			if (!node.textContent.trim()) continue;
			range.selectNodeContents(node);
			for (const rect of range.getClientRects()) if (rect.width) left = Math.min(left, rect.left);
		}
		element.querySelectorAll('img, svg, picture, canvas, input, button').forEach((media) => {
			const rect = media.getBoundingClientRect();
			if (rect.width && rect.height) left = Math.min(left, rect.left);
		});
		return left;
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
				const rect = target.getBoundingClientRect();
				const horizontal = Math.round(rect.left - (pinRect.left + pinRect.width / 2));
				const vertical = Math.round(pinRect.top + pinRect.height / 2 - (rect.top + rect.height / 2));
				if (Math.abs(horizontal - PIN_GAP_PX) > TOLERANCE_PX || Math.abs(vertical) > TOLERANCE_PX) pins.push([key, [horizontal, vertical]]);
				// Anchored to a wide box (a cell, a row), the pin sits by the box but far from what the reader sees.
				const visibleLeft = contentLeft(target, view);
				if (visibleLeft !== Infinity && visibleLeft - rect.left > MAX_CONTENT_GAP_PX) pins.push([key, `far from its content (${Math.round(visibleLeft - rect.left)}px): anchor it to the icon, text or button inside`]);
				// A pin anchored to a full-width element lands on (or past) the capture's edge and shows cut.
				const stageRect = stage.getBoundingClientRect();
				if (pinRect.left < stageRect.left || pinRect.right > stageRect.right) pins.push([key, 'outside the capture: anchor it to a compact element']);
			});
		});
		return { width: view.innerWidth, frames: hosts.length, unrendered, fit, pins, ok: !unrendered.length && !fit.length && !pins.length };
	};
})();
