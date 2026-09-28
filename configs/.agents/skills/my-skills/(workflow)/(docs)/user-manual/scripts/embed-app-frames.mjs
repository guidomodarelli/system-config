#!/usr/bin/env node
/**
 * Embeds real-app captures (from capture-snippet.js) into a user manual.
 *
 * Usage: node embed-app-frames.mjs <captures.json> <manual.html> [--page-background=#ededed]
 *
 * The manual marks each preview with an empty host element:
 *   <div class="app-frame" data-cap="<capture name>"></div>
 * This script injects, between marker comments (re-runs replace the previous block):
 *   - a JSON payload with the used CSS, @font-face rules and one template per capture;
 *   - a small runtime that renders every host inside its own shadow root, so the app's CSS and
 *     the manual's CSS never leak into each other.
 * No dependencies beyond Node's standard library.
 */
import fs from 'node:fs';

const [capturesPath, manualPath, ...flags] = process.argv.slice(2);
if (!capturesPath || !manualPath) {
	console.error('Usage: node embed-app-frames.mjs <captures.json> <manual.html> [--page-background=<css color>]');
	process.exit(1);
}
const pageBackground = (flags.find((flag) => flag.startsWith('--page-background=')) || '').split('=')[1] || 'transparent';

const START = '<!-- app-frames:start -->';
const END = '<!-- app-frames:end -->';
// Fonts injected by browser extensions or unrelated locales must not travel with the manual.
const FOREIGN_RULE = /chrome-extension:|moz-extension:|safari-web-extension:/;

const { rules, caps } = JSON.parse(fs.readFileSync(capturesPath, 'utf8'));
let manual = fs.readFileSync(manualPath, 'utf8');
const hosts = [...new Set([...manual.matchAll(/class="app-frame"[^>]*data-cap="([^"]+)"/g)].map((match) => match[1]))];
// Only the CSS of the captures the manual actually shows is embedded.
const usedIndexes = new Set(caps.filter((capture) => hosts.includes(capture.name)).flatMap((capture) => capture.rules));
const usedRules = [...usedIndexes].sort((a, b) => a - b).map((index) => rules[index]).filter((rule) => !FOREIGN_RULE.test(rule));
const fontFaces = usedRules.filter((rule) => rule.startsWith('@font-face'));
const css = usedRules.filter((rule) => !rule.startsWith('@font-face')).join('\n');
const templates = Object.fromEntries(caps.map((capture) => [capture.name, capture.html]));

const missing = hosts.filter((name) => !templates[name]);
if (missing.length) {
	console.error(`Missing captures for: ${missing.join(', ')}`);
	process.exit(1);
}

// Shells are layout wrappers copied only so descendant selectors match; they must not add layout,
// overlays or viewport positioning. Floating roots (modals, popovers) are pinned in the flow.
const HOST_CSS = `
.app-frame__page{background:${pageBackground};overflow:hidden;text-align:left;}
[data-shell]{position:relative!important;inset:auto!important;transform:none!important;width:auto!important;height:auto!important;min-height:0!important;max-height:none!important;overflow:visible!important;margin:0!important;padding:0!important;background:transparent!important;display:block!important;box-shadow:none!important;border:0!important;opacity:1!important;visibility:visible!important;}
[data-capture-root]{margin-left:auto!important;margin-right:auto!important;opacity:1!important;visibility:visible!important;}
[data-capture-root][style*="position: relative"]{inset:auto!important;transform:none!important;}
`;

const payload = JSON.stringify({ fontFaces, css: css + HOST_CSS, templates: Object.fromEntries(hosts.map((name) => [name, templates[name]])) })
	.replace(/<\//g, '<\\/')
	.replace(/<!--/g, '<\\!--');

const block = `${START}
<script id="app-frames-data" type="application/json">${payload}</script>
<script>
// Renders each captured screen in its own shadow root and fits it so every visible layer
// (including popovers and dropdowns that float outside their parent) shows whole with 16px of air.
(function () {
	var MARGIN = 16;
	var data = JSON.parse(document.getElementById('app-frames-data').textContent);
	var fonts = document.createElement('style');
	fonts.textContent = data.fontFaces.join('\\n');
	document.head.appendChild(fonts);
	var sheet = new CSSStyleSheet();
	sheet.replaceSync(data.css);

	function visibleBounds(content) {
		var box = { left: Infinity, top: Infinity, right: -Infinity, bottom: -Infinity };
		content.querySelectorAll('[data-capture-root], [data-capture-root] *').forEach(function (element) {
			var rect = element.getBoundingClientRect();
			if (!rect.width || !rect.height) return;
			var style = getComputedStyle(element);
			if (style.visibility === 'hidden' || style.display === 'none' || style.opacity === '0') return;
			box.left = Math.min(box.left, rect.left);
			box.top = Math.min(box.top, rect.top);
			box.right = Math.max(box.right, rect.right);
			box.bottom = Math.max(box.bottom, rect.bottom);
		});
		return box;
	}

	function fit(page, content) {
		content.style.zoom = '';
		content.style.margin = '0px';
		content.style.width = '';
		var pageRect = page.getBoundingClientRect();
		var available = pageRect.width - MARGIN * 2;
		var box = visibleBounds(content);
		if (box.left === Infinity) return;
		// Layers positioned in fixed pixels (popovers, menus) can stick out of a fluid root: narrow the
		// content by that amount so the root shrinks and the layer lands inside it.
		var rootRect = content.querySelector('[data-capture-root]').getBoundingClientRect();
		var sticking = Math.max(0, box.right - rootRect.right);
		if (sticking > 0) {
			content.style.width = (content.getBoundingClientRect().width - sticking) + 'px';
			box = visibleBounds(content);
		}
		// Anything still wider than the page scales down until the widest layer fits.
		var scale = 1;
		for (var attempt = 0; attempt < 4 && box.right - box.left > available + 0.5; attempt += 1) {
			scale *= available / (box.right - box.left);
			content.style.zoom = String(scale);
			box = visibleBounds(content);
		}
		var contentRect = content.getBoundingClientRect();
		content.style.marginTop = (contentRect.top - box.top) + 'px';
		content.style.marginBottom = (box.bottom - contentRect.bottom) + 'px';
		box = visibleBounds(content);
		pageRect = page.getBoundingClientRect();
		var leftOverflow = pageRect.left + MARGIN - box.left;
		var rightOverflow = box.right - (pageRect.right - MARGIN);
		if (leftOverflow > 0) content.style.marginLeft = leftOverflow + 'px';
		else if (rightOverflow > 0) content.style.marginLeft = -rightOverflow + 'px';
	}

	document.querySelectorAll('.app-frame').forEach(function (host) {
		if (host.shadowRoot) return;
		var root = host.attachShadow({ mode: 'open' });
		root.adoptedStyleSheets = [sheet];
		var page = document.createElement('div');
		page.className = 'app-frame__page';
		page.style.padding = MARGIN + 'px';
		var content = document.createElement('div');
		// flow-root keeps captured margins inside, so empty space above the screen can be trimmed.
		content.style.display = 'flow-root';
		content.innerHTML = data.templates[host.getAttribute('data-cap')] || '';
		content.querySelectorAll('a[href]').forEach(function (link) { link.removeAttribute('href'); });
		page.setAttribute('inert', '');
		page.appendChild(content);
		root.appendChild(page);
		var refit = function () { fit(page, content); };
		// setTimeout instead of requestAnimationFrame: rAF does not fire in background tabs.
		(document.fonts ? document.fonts.ready : Promise.resolve()).then(function () { setTimeout(refit, 0); });
		new ResizeObserver(refit).observe(host);
	});
})();
</script>
${END}`;

const existing = new RegExp(`${START}[\\s\\S]*?${END}`);
manual = existing.test(manual) ? manual.replace(existing, block) : manual.replace(/<\/body>/i, `${block}\n</body>`);
if (!manual.includes('.app-frame{')) manual = manual.replace(/<\/style>/i, '.app-frame{display:block;}\n</style>');
fs.writeFileSync(manualPath, manual);
console.log(`Embedded ${hosts.length} frames, ${usedRules.length} CSS rules (${fontFaces.length} @font-face), ${Buffer.byteLength(manual)} bytes.`);
