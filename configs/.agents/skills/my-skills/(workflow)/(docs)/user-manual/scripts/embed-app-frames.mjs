#!/usr/bin/env node
/**
 * Embeds real-app captures (from capture-snippet.js) into a user manual.
 *
 * Usage: node embed-app-frames.mjs <captures.json> [more-captures.json ...] <manual.html> [--page-background=#ededed] [--host-css=<file>]
 *
 * --host-css appends design-system rules to the host CSS, for example to release a modal's inner scroll
 * area whose max-height depends on the viewport of the app.
 *
 * The manual marks each preview with an empty host element:
 *   <div class="app-frame" data-cap="<capture name>"></div>
 * This script injects, between marker comments (re-runs replace the previous block):
 *   - a JSON payload with the used CSS, @font-face rules and one template per capture;
 *   - a small runtime that renders every host inside its own shadow root, so the app's CSS and
 *     the manual's CSS never leak into each other.
 * Several exports can be combined; when two contain the same capture name, the later file wins.
 * Captures taken with `flattenMedia` (mobile) get their own stylesheet and keep their viewport width.
 * No dependencies beyond Node's standard library.
 */
import fs from 'node:fs';

const positional = process.argv.slice(2).filter((argument) => !argument.startsWith('--'));
const flags = process.argv.slice(2).filter((argument) => argument.startsWith('--'));
const manualPath = positional.pop();
const capturesPaths = positional;
if (!capturesPaths.length || !manualPath) {
	console.error('Usage: node embed-app-frames.mjs <captures.json> [more-captures.json ...] <manual.html> [--page-background=<css color>] [--host-css=<file>]');
	process.exit(1);
}
const flagValue = (name) => (flags.find((flag) => flag.startsWith(`--${name}=`)) || '').slice(name.length + 3);
const pageBackground = flagValue('page-background') || 'transparent';
const hostCssPath = flagValue('host-css');
const extraHostCss = hostCssPath ? fs.readFileSync(hostCssPath, 'utf8') : '';

const START = '<!-- app-frames:start -->';
const END = '<!-- app-frames:end -->';
const META_ATTRIBUTE = 'data-app-frames-meta';
// Fonts injected by browser extensions or unrelated locales must not travel with the manual.
const FOREIGN_RULE = /chrome-extension:|moz-extension:|safari-web-extension:/;

// Every export has its own rule registry, so rule indexes are remapped into one merged registry.
const rules = [];
const ruleIndex = new Map();
const captures = new Map();
let meta = { capturedAt: null, appVersion: null };
for (const path of capturesPaths) {
	const exported = JSON.parse(fs.readFileSync(path, 'utf8'));
	const remap = exported.rules.map((rule) => {
		if (!ruleIndex.has(rule)) {
			ruleIndex.set(rule, rules.length);
			rules.push(rule);
		}
		return ruleIndex.get(rule);
	});
	for (const capture of exported.caps) captures.set(capture.name, { ...capture, rules: capture.rules.map((index) => remap[index]) });
	if (exported.meta?.capturedAt && (!meta.capturedAt || exported.meta.capturedAt > meta.capturedAt)) meta = { ...meta, capturedAt: exported.meta.capturedAt };
	if (exported.meta?.appVersion) meta = { ...meta, appVersion: exported.meta.appVersion };
}

let manual = fs.readFileSync(manualPath, 'utf8');
const hosts = [...new Set([...manual.matchAll(/class="app-frame"[^>]*data-cap="([^"]+)"/g)].map((match) => match[1]))];
const missing = hosts.filter((name) => !captures.has(name));
if (missing.length) {
	console.error(`Missing captures for: ${missing.join(', ')}`);
	process.exit(1);
}

const usedCaptures = hosts.map((name) => captures.get(name));
const cssOf = (indexes) => [...new Set(indexes)].sort((a, b) => a - b).map((index) => rules[index]).filter((rule) => !FOREIGN_RULE.test(rule));
const allUsed = cssOf(usedCaptures.flatMap((capture) => capture.rules));
const fontFaces = allUsed.filter((rule) => rule.startsWith('@font-face'));
const withoutFonts = (list) => list.filter((rule) => !rule.startsWith('@font-face')).join('\n');
// Desktop captures share one sheet; each fixed-viewport capture gets its own, because its flattened
// mobile rules would otherwise restyle the desktop captures (and the other way round).
const css = withoutFonts(cssOf(usedCaptures.filter((capture) => !capture.viewportWidth).flatMap((capture) => capture.rules)));
const sheets = Object.fromEntries(usedCaptures.filter((capture) => capture.viewportWidth).map((capture) => [capture.name, withoutFonts(cssOf(capture.rules))]));
const widths = Object.fromEntries(usedCaptures.filter((capture) => capture.viewportWidth).map((capture) => [capture.name, capture.viewportWidth]));

// Shells are layout wrappers copied only so descendant selectors match; they must not add layout,
// overlays or viewport positioning. Floating roots (modals, popovers) are pinned in the flow.
const HOST_CSS = `
.app-frame__page{background:${pageBackground};overflow:hidden;text-align:left;}
[data-shell]{position:relative!important;inset:auto!important;transform:none!important;width:auto!important;height:auto!important;min-height:0!important;max-height:none!important;overflow:visible!important;margin:0!important;padding:0!important;background:transparent!important;display:block!important;box-shadow:none!important;border:0!important;opacity:1!important;visibility:visible!important;}
[data-capture-root]{margin-left:auto!important;margin-right:auto!important;opacity:1!important;visibility:visible!important;}
[data-capture-root][style*="position: relative"]{inset:auto!important;transform:none!important;}
`;

const payload = JSON.stringify({ fontFaces, css, hostCss: HOST_CSS + extraHostCss, sheets, widths, templates: Object.fromEntries(hosts.map((name) => [name, captures.get(name).html])) })
	.replace(/<\//g, '<\\/')
	.replace(/<!--/g, '<\\!--');

const block = `${START}
<script id="app-frames-data" type="application/json">${payload}</script>
<script>
// Renders each captured screen in its own shadow root, lazily, and fits it so every visible layer
// (including popovers and dropdowns that float outside their parent) shows whole with 16px of air.
(function () {
	var MARGIN = 16;
	var LAZY_ROOT_MARGIN = '800px 0px';
	var data = JSON.parse(document.getElementById('app-frames-data').textContent);
	var fonts = document.createElement('style');
	fonts.textContent = data.fontFaces.join('\\n');
	document.head.appendChild(fonts);
	function toSheet(cssText) {
		var sheet = new CSSStyleSheet();
		sheet.replaceSync(cssText);
		return sheet;
	}
	var sharedSheet = toSheet(data.css);
	var hostSheet = toSheet(data.hostCss);
	var hosts = Array.prototype.slice.call(document.querySelectorAll('.app-frame'));

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

	function fit(page, content, fixedWidth) {
		content.style.zoom = '';
		content.style.margin = '0px';
		content.style.width = fixedWidth ? fixedWidth + 'px' : '';
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
		// Fixed-viewport (mobile) captures are centered, like a phone screen on the page.
		else if (fixedWidth) content.style.marginLeft = Math.max(0, (available - (box.right - box.left)) / 2) + 'px';
	}

	// Screen readers get the caption as the image description; the capture itself stays inert.
	function describe(host) {
		if (host.hasAttribute('aria-label')) return;
		var mockup = host.closest('.mockup');
		var caption = mockup && mockup.nextElementSibling && mockup.nextElementSibling.classList.contains('figcap')
			? mockup.nextElementSibling.textContent.trim()
			: '';
		var title = mockup ? (mockup.querySelector('.mockup-url') || {}).textContent : '';
		host.setAttribute('role', 'img');
		host.setAttribute('aria-label', 'Captura de pantalla: ' + (caption || title || host.getAttribute('data-cap')));
	}

	function render(host) {
		if (host.shadowRoot) return;
		var name = host.getAttribute('data-cap');
		var root = host.attachShadow({ mode: 'open' });
		root.adoptedStyleSheets = [data.sheets[name] !== undefined ? toSheet(data.sheets[name]) : sharedSheet, hostSheet];
		var page = document.createElement('div');
		page.className = 'app-frame__page';
		page.style.padding = MARGIN + 'px';
		var content = document.createElement('div');
		// flow-root keeps captured margins inside, so empty space above the screen can be trimmed.
		content.style.display = 'flow-root';
		content.innerHTML = data.templates[name] || '';
		content.querySelectorAll('a[href]').forEach(function (link) { link.removeAttribute('href'); });
		page.setAttribute('inert', '');
		page.setAttribute('aria-hidden', 'true');
		page.appendChild(content);
		root.appendChild(page);
		host.style.minHeight = '';
		var refit = function () { fit(page, content, data.widths[name]); };
		// setTimeout instead of requestAnimationFrame: rAF does not fire in background tabs.
		(document.fonts ? document.fonts.ready : Promise.resolve()).then(function () { setTimeout(refit, 0); });
		new ResizeObserver(refit).observe(host);
	}

	hosts.forEach(function (host) {
		describe(host);
		// Reserve space so the lazy frames do not collapse the page before they render.
		if (!host.shadowRoot) host.style.minHeight = '240px';
	});
	if ('IntersectionObserver' in window) {
		var observer = new IntersectionObserver(function (entries) {
			entries.forEach(function (entry) {
				if (!entry.isIntersecting) return;
				observer.unobserve(entry.target);
				render(entry.target);
			});
		}, { rootMargin: LAZY_ROOT_MARGIN });
		hosts.forEach(function (host) { observer.observe(host); });
	} else {
		hosts.forEach(render);
	}
	// Printing and PDF export must include every screen, even the ones never scrolled into view.
	window.addEventListener('beforeprint', function () { hosts.forEach(render); });
})();
</script>
${END}`;

const existing = new RegExp(`${START}[\\s\\S]*?${END}`);
// The header says when, and from which app version, the screens were captured.
if (meta.capturedAt) {
	const label = `Capturas: ${meta.capturedAt}${meta.appVersion ? ` · App v${meta.appVersion}` : ''}`;
	const metaSpan = new RegExp(`<span ${META_ATTRIBUTE}>[^<]*</span>`);
	if (metaSpan.test(manual)) manual = manual.replace(metaSpan, `<span ${META_ATTRIBUTE}>${label}</span>`);
	else manual = manual.replace(/(<div class="doc-meta">[\s\S]*?)(\s*<\/div>)/, `$1\n    <span ${META_ATTRIBUTE}>${label}</span>$2`);
}
manual = existing.test(manual) ? manual.replace(existing, block) : manual.replace(/<\/body>/i, `${block}\n</body>`);
if (!manual.includes('.app-frame{')) manual = manual.replace(/<\/style>/i, '.app-frame{display:block;}\n</style>');
fs.writeFileSync(manualPath, manual);
console.log(`Embedded ${hosts.length} frames (${Object.keys(sheets).length} fixed-viewport), ${allUsed.length} CSS rules (${fontFaces.length} @font-face), ${Buffer.byteLength(manual)} bytes.`);
