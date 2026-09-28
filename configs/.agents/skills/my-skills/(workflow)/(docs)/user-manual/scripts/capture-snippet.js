/**
 * Browser snippet that captures real UI fragments (markup + only the CSS they use) from the app
 * being documented, so manual mockups render with the app's exact styles.
 *
 * Paste the whole file into the page with the browser automation JavaScript tool, then call:
 *   __umCap(name, element, { pairs, transform, floating, fixedWidth })   capture one fragment
 *   __umCheck(forbiddenStrings)                     list captures that still contain real data
 *   __umExport(fileName, { appVersion })            download { meta, rules, caps } as JSON
 *   __umClear()                                     drop everything stored in sessionStorage
 *
 * Captures persist in sessionStorage, so navigating between pages of the same origin keeps them.
 * Re-paste the snippet after every navigation (window globals are lost, stored data is not).
 *
 * Design-system agnostic: it copies whatever stylesheets the page uses (Andes, Material,
 * Tailwind, custom SCSS...). Cross-origin sheets that block cssRules are reported, not copied.
 */
(() => {
	const RULES_KEY = '__umRules';
	const CAPS_KEY = '__umCaps';
	const read = (key) => JSON.parse(sessionStorage.getItem(key) || '[]');
	const write = (key, value) => sessionStorage.setItem(key, JSON.stringify(value));

	// Interaction pseudo-classes are stripped so rules for the current state and its hover/focus
	// variants are kept; pseudo-elements are stripped because Element.matches rejects them.
	const PSEUDO_ELEMENTS =
		/::?(before|after|placeholder|selection|marker|backdrop|first-line|first-letter|file-selector-button|-webkit-[a-z-]+|-moz-[a-z-]+|-ms-[a-z-]+)(\([^)]*\))?/g;
	const STATE_PSEUDOS =
		/:(hover|focus-visible|focus-within|focus|active|visited|checked|disabled|enabled|indeterminate|invalid|valid|required|optional|placeholder-shown|read-only|read-write|autofill|target|open)/g;
	const stripSelector = (selector) => selector.replace(PSEUDO_ELEMENTS, '').replace(STATE_PSEUDOS, '').trim();

	// html/body/:root cannot live inside a shadow root, so they become <div data-tag> and every
	// selector that targets them is rewritten to the attribute form.
	const retagSelector = (css) =>
		css
			.replace(/(^|[\s,>+~(}])(html|body)(?=[\s,.:#[>+~{)]|$)/g, '$1[data-tag="$2"]')
			.replace(/:root\b/g, '[data-tag="html"]');

	// Dimension media queries (width, height, orientation, aspect ratio) are resolved against the capture
	// viewport and flattened, so the frame shows the layout that was captured whatever the reader's screen
	// is. Other media (hover, reduced motion, print) stay conditional and follow the reader.
	const DIMENSION_MEDIA = /width|height|orientation|aspect-ratio/;
	const collectRules = (elements) => {
		const registry = read(RULES_KEY);
		const index = new Map(registry.map((rule, position) => [rule, position]));
		const used = new Set();
		const blockedSheets = [];
		const add = (cssText) => {
			if (!index.has(cssText)) {
				index.set(cssText, registry.length);
				registry.push(cssText);
			}
			used.add(index.get(cssText));
		};
		const matches = (selector) => {
			const stripped = stripSelector(selector);
			if (!stripped) return false;
			try {
				return elements.some((element) => element.matches(stripped));
			} catch (error) {
				return false;
			}
		};
		// Relative url() values (fonts, icons, backgrounds) must stay resolvable outside the app.
		const absolutize = (cssText, base) =>
			cssText.replace(/url\((['"]?)(?!data:|https?:|blob:|#)([^'")]+)\1\)/g, (match, quote, target) => {
				try {
					return `url("${new URL(target, base).href}")`;
				} catch (error) {
					return match;
				}
			});
		let baseUrl = location.href;
		const walk = (list, wrap) => {
			for (const rule of list) {
				if (rule instanceof CSSStyleRule) {
					// Only the selector is retagged; declarations are copied verbatim.
					if (rule.selectorText.split(',').some(matches)) {
						add(absolutize(wrap(`${retagSelector(rule.selectorText)}{${rule.style.cssText}}`), baseUrl));
					}
				} else if (rule instanceof CSSMediaRule) {
					if (!DIMENSION_MEDIA.test(rule.conditionText)) walk(rule.cssRules, (inner) => wrap(`@media ${rule.conditionText}{${inner}}`));
					else if (window.matchMedia(rule.conditionText).matches) walk(rule.cssRules, wrap);
				} else if (typeof CSSContainerRule !== 'undefined' && rule instanceof CSSContainerRule) {
					// Container queries keep their condition; they evaluate against the frame's own containers.
					const condition = `${rule.containerName ? `${rule.containerName} ` : ''}${rule.containerQuery}`;
					walk(rule.cssRules, (inner) => wrap(`@container ${condition}{${inner}}`));
				} else if (typeof CSSLayerBlockRule !== 'undefined' && rule instanceof CSSLayerBlockRule) {
					// Layered rules lose to unlayered ones; dropping the layer would change which rule wins.
					walk(rule.cssRules, (inner) => wrap(`@layer ${rule.name}{${inner}}`));
				} else if (typeof CSSSupportsRule !== 'undefined' && rule instanceof CSSSupportsRule) {
					walk(rule.cssRules, (inner) => wrap(`@supports ${rule.conditionText}{${inner}}`));
				} else if (rule instanceof CSSFontFaceRule || rule instanceof CSSKeyframesRule) {
					add(absolutize(rule.cssText, baseUrl));
				} else if (rule.cssRules) {
					walk(rule.cssRules, wrap);
				}
			}
		};
		for (const sheet of document.styleSheets) {
			try {
				baseUrl = sheet.href || location.href;
				walk(sheet.cssRules, (text) => text);
			} catch (error) {
				blockedSheets.push(sheet.href);
			}
		}
		write(RULES_KEY, registry);
		return { used: [...used], blockedSheets };
	};

	// Live form state (checked, value) is a DOM property that cloneNode does not copy.
	const syncFormState = (live, clone) => {
		const liveControls = [...live.querySelectorAll('input, textarea, select')];
		const cloneControls = [...clone.querySelectorAll('input, textarea, select')];
		liveControls.forEach((control, position) => {
			const target = cloneControls[position];
			if (!target) return;
			if (control.type === 'checkbox' || control.type === 'radio') {
				control.checked ? target.setAttribute('checked', '') : target.removeAttribute('checked');
			} else if (control.tagName === 'TEXTAREA') {
				target.textContent = control.value;
			} else if (control.tagName === 'SELECT') {
				[...target.options].forEach((option, optionIndex) => {
					optionIndex === control.selectedIndex ? option.setAttribute('selected', '') : option.removeAttribute('selected');
				});
			} else {
				target.setAttribute('value', control.value);
			}
		});
	};

	const SANITIZED_ATTRIBUTES = ['aria-label', 'aria-describedby', 'title', 'alt', 'value', 'placeholder', 'data-testid', 'href', 'id', 'for'];
	const replaceAll = (text, pairs) => pairs.reduce((value, [from, to]) => value.split(from).join(to), text);
	const sanitize = (root, pairs) => {
		const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
		const nodes = [];
		while (walker.nextNode()) nodes.push(walker.currentNode);
		nodes.forEach((node) => {
			node.nodeValue = replaceAll(node.nodeValue, pairs);
		});
		[root, ...root.querySelectorAll('*')].forEach((element) => {
			SANITIZED_ATTRIBUTES.forEach((attribute) => {
				if (element.hasAttribute(attribute)) element.setAttribute(attribute, replaceAll(element.getAttribute(attribute), pairs));
			});
		});
	};

	// Scroll areas inside floating layers usually cap their height with the viewport (100vh - N); when their
	// content already fits, the cap is released so the manual does not cut them at its own viewport height.
	const releaseViewportCaps = (live, clone) => {
		const liveNodes = [live, ...live.querySelectorAll('*')];
		const cloneNodes = [clone, ...clone.querySelectorAll('*')];
		liveNodes.forEach((node, position) => {
			const style = getComputedStyle(node);
			const scrolls = ['auto', 'scroll'].includes(style.overflowY);
			if (style.maxHeight === 'none' || !scrolls || node.scrollHeight > node.clientHeight + 1) return;
			cloneNodes[position].style.maxHeight = 'none';
			cloneNodes[position].style.overflowY = 'visible';
		});
	};

	// Floating layers (modals, popovers) are captured in place; these neutralize viewport positioning.
	const unfloat = (element) => {
		element.style.position = 'relative';
		element.style.inset = 'auto';
		element.style.transform = 'none';
		element.style.maxHeight = 'none';
		element.style.margin = '0 auto';
	};

	// fixedWidth renders the capture at its viewport width in the manual (mobile captures at 375 px).
	window.__umCap = (name, element, { pairs = [], transform = null, floating = false, fixedWidth = false } = {}) => {
		const ancestors = [];
		for (let node = element.parentElement; node; node = node.parentElement) ancestors.unshift(node);
		const { used, blockedSheets } = collectRules([...ancestors, element, ...element.querySelectorAll('*')]);

		const clone = element.cloneNode(true);
		syncFormState(element, clone);
		clone.setAttribute('data-capture-root', '');
		if (floating) {
			unfloat(clone);
			releaseViewportCaps(element, clone);
		}
		if (transform) transform(clone);
		sanitize(clone, pairs);
		clone.querySelectorAll('script, noscript, iframe').forEach((node) => node.remove());

		// Ancestors are kept as empty shells so descendant selectors (.page .card) still match.
		let html = clone.outerHTML;
		for (const ancestor of [...ancestors].reverse()) {
			const tag = ancestor.tagName.toLowerCase();
			const shell = document.createElement(tag === 'html' || tag === 'body' ? 'div' : tag);
			for (const { name: attribute, value } of ancestor.attributes) {
				if (attribute !== 'id' && attribute !== 'style') shell.setAttribute(attribute, replaceAll(value, pairs));
			}
			if (tag === 'html' || tag === 'body') shell.setAttribute('data-tag', tag);
			shell.setAttribute('data-shell', '');
			const open = shell.outerHTML;
			const close = `</${shell.tagName.toLowerCase()}>`;
			html = open.slice(0, open.lastIndexOf(close)) + html + close;
		}

		const caps = read(CAPS_KEY);
		const record = { name, html, rules: used, captureViewportWidth: window.innerWidth };
		if (fixedWidth) record.viewportWidth = window.innerWidth;
		const existing = caps.findIndex((capture) => capture.name === name);
		existing >= 0 ? (caps[existing] = record) : caps.push(record);
		write(CAPS_KEY, caps);
		return { name, htmlLength: html.length, rules: used.length, blockedSheets, storageBytes: JSON.stringify(caps).length };
	};

	window.__umCheck = (forbidden) =>
		read(CAPS_KEY).flatMap((capture) => forbidden.filter((value) => capture.html.includes(value)).map((value) => [capture.name, value]));

	// meta travels with the captures so the manual can say when, and from which app version, its screens come.
	window.__umExport = (fileName = 'app-captures.json', { appVersion = null } = {}) => {
		const rules = read(RULES_KEY);
		const meta = { capturedAt: new Date().toISOString().slice(0, 10), appVersion };
		const payload = { meta, rules, caps: read(CAPS_KEY) };
		const blob = new Blob([JSON.stringify(payload)], { type: 'application/json' });
		const link = document.createElement('a');
		link.href = URL.createObjectURL(blob);
		link.download = fileName;
		document.body.appendChild(link);
		link.click();
		link.remove();
		return { meta, rules: rules.length, caps: payload.caps.length, bytes: blob.size };
	};

	window.__umClear = () => {
		sessionStorage.removeItem(RULES_KEY);
		sessionStorage.removeItem(CAPS_KEY);
		return 'cleared';
	};

	window.__umReplaceText = sanitize;
	return 'user-manual capture helpers installed';
})();
