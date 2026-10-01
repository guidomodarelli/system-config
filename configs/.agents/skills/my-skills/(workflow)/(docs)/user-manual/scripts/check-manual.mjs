#!/usr/bin/env node
/**
 * Static checks for a finished user manual, run before publishing. No dependencies.
 *
 * Usage:
 *   node check-manual.mjs <manual.html> [--translations <file> ...] [--forbidden <value,value,...>]
 *                         [--allow-host <host> ...]
 *
 *   --translations  .po or .json translation files of the documented app (reader's locale). Every
 *                   text quoted between «…» in the manual must exist in one of them.
 *   --forbidden     real values seen while capturing (names, LDAP, user ids). Zero hits allowed.
 *   --allow-host    extra hosts allowed in the file besides fonts, the app CDN and the share URL.
 *   --design        DESIGN.md to compare the navigation script with (default ~/system-config/configs/.agents/DESIGN.md).
 *
 * Exit code: 0 when there are no errors (warnings do not fail), 1 with errors, 2 on bad usage.
 * The rendered checks (frame fit, pin distance) run in the browser with check-rendered.js.
 */
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const DEFAULT_ALLOWED_HOSTS = ['fonts.googleapis.com', 'fonts.gstatic.com', 'http2.mlstatic.com', 'www.w3.org'];
const DEFAULT_DESIGN_PATH = path.join(os.homedir(), 'system-config/configs/.agents/DESIGN.md');
const NAVIGATION_SCRIPT_MARKER = '// Navegación e interacciones Heritage';
const ENVIRONMENT_MARKERS = [':8443', 'melioffice', 'melisystems', 'localhost', '127.0.0.1', 'dev.adminml.com'];
const SECRET_PATTERNS = [/type=\\?"hidden\\?"/i, /_csrf/i, /csrf-token/i, /session-id/i, /authorization:/i];
const CHANGE_MARKERS = [/data-change=/, /class="[^"]*change-badge/, /Novedades:/];
const HEADER_NOISE = [/<span>Estado:/, /Capturas: [0-9-]+ · App v/];
const SOURCE_META_NAMES = ['heritage:source-repo', 'heritage:source-ref', 'heritage:source-commit', 'heritage:source-files', 'heritage:source-commit-url'];

const parseArguments = (argv) => {
	const options = { manual: null, translations: [], forbidden: [], allowHosts: [], design: DEFAULT_DESIGN_PATH };
	for (let index = 0; index < argv.length; index += 1) {
		const argument = argv[index];
		if (argument === '--translations') options.translations.push(argv[(index += 1)]);
		else if (argument === '--forbidden') options.forbidden.push(...argv[(index += 1)].split(',').map((value) => value.trim()).filter(Boolean));
		else if (argument === '--allow-host') options.allowHosts.push(argv[(index += 1)]);
		else if (argument === '--design') options.design = argv[(index += 1)];
		else if (!options.manual) options.manual = argument;
		else throw new Error(`check-manual: unexpected argument ${argument}`);
	}
	if (!options.manual) throw new Error('check-manual: missing <manual.html>');
	return options;
};

const decodeEntities = (text) =>
	text
		.replace(/&nbsp;/g, ' ')
		.replace(/&amp;/g, '&')
		.replace(/&lt;/g, '<')
		.replace(/&gt;/g, '>')
		.replace(/&quot;/g, '"')
		.replace(/&#39;/g, "'")
		.replace(/&#(\d+);/g, (match, code) => String.fromCharCode(Number(code)));
const stripTags = (html) => decodeEntities(html.replace(/<[^>]+>/g, '')).replace(/\s+/g, ' ').trim();
const metaContent = (html, name) => {
	const match = html.match(new RegExp(`<meta name="${name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}" content="([^"]*)"`));
	return match ? decodeEntities(match[1]) : null;
};

/** Reads every msgstr / JSON value of the translation files into one normalized set. */
const loadTranslations = (files) => {
	const texts = new Set();
	const normalize = (text) => text.replace(/\s+/g, ' ').trim();
	for (const file of files) {
		const content = fs.readFileSync(file, 'utf8');
		if (file.endsWith('.json')) {
			const walk = (node) => {
				if (typeof node === 'string') texts.add(normalize(node));
				else if (Array.isArray(node)) node.forEach(walk);
				else if (node && typeof node === 'object') Object.entries(node).forEach(([key, value]) => { texts.add(normalize(key)); walk(value); });
			};
			walk(JSON.parse(content));
		} else {
			for (const match of content.matchAll(/^(msgid|msgstr) "((?:[^"\\]|\\.)*)"((?:\n"(?:[^"\\]|\\.)*")*)/gm)) {
				const continuation = match[3].split('\n').filter(Boolean).map((line) => line.slice(1, -1)).join('');
				texts.add(normalize((match[2] + continuation).replace(/\\"/g, '"').replace(/\\n/g, ' ')));
			}
		}
	}
	return [...texts].filter(Boolean);
};

/** A quoted text matches when a translation contains it; «… » marks a truncated quote. */
const quoteExists = (quote, translations) => {
	const fragments = quote.split('…').map((fragment) => fragment.trim().replace(/[.:]$/, '')).filter((fragment) => fragment.length > 2);
	if (!fragments.length) return true;
	// Placeholders like {0} in translations stand for values the manual writes out (ARBA01, 50).
	const asPattern = (translation) => new RegExp(translation.split(/\{\d+\}/).map((part) => part.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('.+?'), 'i');
	return fragments.every((fragment) => translations.some((translation) => translation.includes(fragment) || (/\{\d+\}/.test(translation) && asPattern(translation).test(fragment))));
};

const main = () => {
	const options = parseArguments(process.argv.slice(2));
	const html = fs.readFileSync(options.manual, 'utf8');
	const errors = [];
	const warnings = [];
	const payloadStart = html.indexOf('<!-- app-frames:start -->');
	const document = payloadStart === -1 ? html : html.slice(0, payloadStart);
	const body = document.slice(document.indexOf('<body>'));
	// Markup only: scripts and styles may mention class names or old features in comments.
	const visible = body.replace(/<script\b[\s\S]*?<\/script>/g, '').replace(/<style\b[\s\S]*?<\/style>/g, '');

	// Structure: TOC entries ↔ section titles.
	const titles = new Map([...visible.matchAll(/<h2 class="section-title" id="(s\d+)">([\s\S]*?)<\/h2>/g)].map((match) => [match[1], stripTags(match[2])]));
	const tocEntries = [...visible.matchAll(/<nav class="toc"[\s\S]*?<\/nav>/g)].flatMap((toc) => [...toc[0].matchAll(/<a href="#(s\d+)"><span class="toc-num">\d+<\/span>([\s\S]*?)<\/a>/g)]);
	if (!tocEntries.length) errors.push('toc: no nav.toc entries found');
	for (const [, id, label] of tocEntries) {
		if (!titles.has(id)) errors.push(`toc: link #${id} has no section`);
		else if (stripTags(label) !== titles.get(id)) errors.push(`toc: "${stripTags(label)}" differs from the title of #${id} ("${titles.get(id)}")`);
	}
	for (const id of titles.keys()) if (!tocEntries.some((entry) => entry[1] === id)) errors.push(`toc: section #${id} is missing from the TOC`);
	for (const required of ['class="section-rail"', 'class="section-pill"', 'class="toc-sheet"', 'class="back-to-top"']) {
		if (!visible.includes(required)) errors.push(`navigation: ${required} missing`);
	}
	// The navigation script travels inside each manual: compare it with the current boilerplate.
	const extractNavigationScript = (source) => {
		const start = source.indexOf(NAVIGATION_SCRIPT_MARKER);
		return start === -1 ? null : source.slice(start, source.indexOf('</script>', start)).trim();
	};
	if (fs.existsSync(options.design)) {
		const current = extractNavigationScript(fs.readFileSync(options.design, 'utf8'));
		const embedded = extractNavigationScript(body);
		if (!embedded) errors.push('navigation: the Heritage navigation script is missing');
		else if (current && embedded !== current) warnings.push('navigation: the navigation script differs from the DESIGN.md boilerplate (outdated); copy the current one');
	}

	// Glossary terms resolve.
	const definitions = new Set([...visible.matchAll(/<dt id="([^"]+)"/g)].map((match) => match[1]));
	for (const [, target] of visible.matchAll(/class="term" href="#([^"]+)"/g)) if (!definitions.has(target)) errors.push(`glossary: term link #${target} has no <dt>`);

	// Mockups: caption after each one, url bar without host, pins anchored on captures.
	const mockups = [...visible.matchAll(/<div class="mockup[^"]*">[\s\S]*?<span class="mockup-url">([^<]*)<\/span>/g)];
	for (const [, url] of mockups) if (/https?:\/\/|[a-z0-9-]+\.(com|io|net|ar|br)\b|:\d{2,5}/i.test(url)) errors.push(`mockup-url: "${url}" shows a host`);
	const figcapCount = (visible.match(/class="figcap"/g) || []).length;
	if (figcapCount < mockups.length) warnings.push(`figcap: ${mockups.length} mockups but ${figcapCount} captions`);
	for (const stage of visible.matchAll(/<div class="hotspot-stage">([\s\S]*?)<\/div>\s*<\/div>/g)) {
		if (!stage[1].includes('class="app-frame"')) continue;
		const capture = (stage[1].match(/data-cap="([^"]+)"/) || [])[1];
		for (const pin of stage[1].matchAll(/<span class="hotspot"[^>]*>/g)) if (!pin[0].includes('data-target=')) errors.push(`pins: a pin on capture "${capture}" has no data-target`);
	}

	// Pins: each section owns its pins; one pin per number, and every step or reference has its pin.
	for (const [, sectionId, sectionBody] of visible.matchAll(/<section class="section" aria-labelledby="([^"]+)">([\s\S]*?)<\/section>/g)) {
		const pinNumbers = [...sectionBody.matchAll(/<span class="hotspot"[^>]*data-hotspot="([^"]+)"/g)].map((match) => match[1]);
		const linkedNumbers = new Set([...sectionBody.matchAll(/class="(?:step-item|hotspot-ref)"[^>]*data-hotspot="([^"]+)"/g)].map((match) => match[1]));
		const repeated = [...new Set(pinNumbers.filter((number, index) => pinNumbers.indexOf(number) !== index))];
		if (repeated.length) errors.push(`pins: section ${sectionId} has more than one pin numbered ${repeated.join(', ')} (one pin per number per section)`);
		for (const number of linkedNumbers) if (!pinNumbers.includes(number)) errors.push(`pins: section ${sectionId} refers to pin ${number} but has no pin with that number (repeat the capture in this section)`);
		for (const number of new Set(pinNumbers)) if (!linkedNumbers.has(number)) errors.push(`pins: section ${sectionId} has pin ${number} with no step or reference in the same section`);
	}

	// Root-relative images inside captures resolve against the manual's host and show empty.
	const relativeImages = new Set([...html.matchAll(/<img[^>]*?\bsrc=\\?"(\/(?!\/)[^"\\]*)/g)].map((match) => match[1]));
	for (const source of relativeImages) errors.push(`images: capture image ${source} has a root-relative path (inline it as a data URI; recapture with the current capture-snippet.js)`);

	// No change markers.
	for (const marker of CHANGE_MARKERS) if (marker.test(visible)) errors.push(`change markers: found ${marker} (manuals never mark new or updated sections)`);
	// The doc-meta carries only what tells the reader something.
	if (!/<div class="doc-meta">[\s\S]*?<span>Audiencia: [^<]+<\/span>[\s\S]*?<\/div>/.test(visible)) errors.push('doc-meta: missing "Audiencia: <rol> / <rol>"');
	for (const noise of HEADER_NOISE) if (noise.test(visible)) errors.push(`doc-meta: found ${noise} (no "Estado" and no app version in a manual header)`);

	// Source trace (where the content comes from).
	const missingSource = SOURCE_META_NAMES.filter((name) => metaContent(html, name) === null);
	if (missingSource.length) errors.push(`source: missing ${missingSource.join(', ')} (scripts/source-trace.py record)`);
	const commitUrl = metaContent(html, 'heritage:source-commit-url');
	const commit = metaContent(html, 'heritage:source-commit');
	const codeLink = visible.match(/<footer class="doc-footer">[^<]*Código: <a href="([^"]+)"[^>]*>([^<]+)<\/a><\/footer>/);
	if (!codeLink) errors.push('source: no doc-footer with the "Código: <ref> @ <commit>" line linked to the commit (run source-trace.py record)');
	if (/<div class="doc-meta">[\s\S]*?Código:[\s\S]*?<\/div>/.test(visible.slice(0, visible.indexOf('</header>')))) errors.push('source: "Código:" belongs in the doc-footer, not in the doc-meta');
	else if (commitUrl && decodeEntities(codeLink[1]) !== commitUrl) errors.push('source: the "Código" link does not point to heritage:source-commit-url');
	if (commitUrl && commit && !commitUrl.endsWith(`/commit/${commit}`)) errors.push('source: heritage:source-commit-url does not match heritage:source-commit');
	if (!metaContent(html, 'heritage:share-url')) warnings.push('share-url: no heritage:share-url meta (needed when the manual is shown inside an iframe)');

	// Environment data and secrets anywhere in the file, captures payload included.
	const shareHost = (() => { try { return new URL(metaContent(html, 'heritage:share-url')).host; } catch (error) { return null; } })();
	const commitHost = (() => { try { return new URL(commitUrl).host; } catch (error) { return null; } })();
	const allowedHosts = new Set([...DEFAULT_ALLOWED_HOSTS, ...options.allowHosts, ...(shareHost ? [shareHost] : []), ...(commitHost ? [commitHost] : [])]);
	const unexpectedHosts = new Set([...html.matchAll(/https?:\\?\/\\?\/([a-z0-9.-]+)/gi)].map((match) => match[1].toLowerCase()).filter((host) => !allowedHosts.has(host)));
	for (const host of unexpectedHosts) errors.push(`hosts: unexpected host ${host}`);
	for (const marker of ENVIRONMENT_MARKERS) if (html.includes(marker)) errors.push(`hosts: environment marker "${marker}" found`);
	for (const pattern of SECRET_PATTERNS) if (pattern.test(html)) errors.push(`secrets: ${pattern} found`);
	for (const value of options.forbidden) if (html.includes(value)) errors.push(`forbidden: real value "${value.slice(0, 3)}…" found`);

	// Quoted texts must exist in the app's translations (catches obsolete strings).
	if (options.translations.length) {
		const translations = loadTranslations(options.translations);
		const quotes = [...new Set([...visible.matchAll(/«([^»]+)»/g)].map((match) => stripTags(match[1])))];
		const missing = quotes.filter((quote) => !quoteExists(quote, translations));
		for (const quote of missing) errors.push(`texts: «${quote}» is not in the translations (obsolete or misquoted)`);
		console.log(`texts: ${quotes.length - missing.length}/${quotes.length} quoted texts found in ${options.translations.length} translation file(s)`);
	} else {
		warnings.push('texts: no --translations given; quoted texts were not checked against the app');
	}

	console.log(`check-manual: ${path.basename(options.manual)} — ${titles.size} sections, ${mockups.length} mockups, ${errors.length} errors, ${warnings.length} warnings`);
	warnings.forEach((warning) => console.log(`  warn  ${warning}`));
	errors.forEach((error) => console.log(`  ERROR ${error}`));
	process.exitCode = errors.length ? 1 : 0;
};

try {
	main();
} catch (error) {
	console.error(error.message);
	process.exitCode = 2;
}
