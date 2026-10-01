/**
 * Grid helpers, run with the browser JavaScript tool in a tab of grid.adminml.com where the user is
 * already signed in. Publishing goes through the same endpoints the Grid editor uses.
 *
 *   await __gridInfo(documentId)
 *     -> { latestVersion, filename, frameWidth }
 *   await __gridPull(documentId, { bridgeUrl })
 *     -> POSTs { version, html } as grid-<documentId>.json to capture-bridge.py (served for this origin)
 *   await __gridPublish({ documentId, sourceUrl, sha256, expectedVersion })
 *     -> { version } after lock, PUT /content?if_version, lock release and cache refresh
 *
 * Before publishing, remove Grid's injected scripts from the source (strip-grid-injections.py) and
 * serve the final file with capture-bridge.py --origin https://grid.adminml.com. `sha256` is the hash
 * of that file (`shasum -a 256`): the upload aborts if the browser received anything else.
 */
(function () {
	const documentsApi = (documentId) => `/api/v1/documents/${encodeURIComponent(documentId)}`;

	const sha256Hex = async (text) =>
		Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text))))
			.map((byte) => byte.toString(16).padStart(2, '0'))
			.join('');

	const listVersions = async (documentId) => {
		const response = await fetch(`${documentsApi(documentId)}/versions`, { credentials: 'same-origin', cache: 'no-store' });
		if (!response.ok) throw new Error(`grid-publish:listVersions failed: GET versions ${response.status} documentId=${documentId}`);
		const body = await response.json();
		return Array.isArray(body) ? body : body.versions || body.items || [];
	};

	window.__gridInfo = async (documentId) => {
		const versions = await listVersions(documentId);
		const latest = versions[versions.length - 1] || {};
		const frame = document.querySelector('iframe');
		return { latestVersion: latest.version, filename: latest.filename, frameWidth: frame ? frame.clientWidth : null };
	};

	window.__gridPull = async (documentId, { bridgeUrl }) => {
		const versions = await listVersions(documentId);
		const version = (versions[versions.length - 1] || {}).version;
		const response = await fetch(`/d/${encodeURIComponent(documentId)}/raw`, { credentials: 'same-origin', cache: 'no-store' });
		if (!response.ok) throw new Error(`grid-publish:pull failed: GET raw ${response.status} documentId=${documentId}`);
		const html = await response.text();
		const status = await fetch(`${bridgeUrl.replace(/\/$/, '')}/grid-${documentId.toLowerCase()}.json`, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({ version, html }),
		}).then((bridgeResponse) => bridgeResponse.status);
		return { version, bytes: html.length, bridgeStatus: status };
	};

	window.__gridPublish = async ({ documentId, sourceUrl, sha256, expectedVersion }) => {
		const html = await fetch(sourceUrl, { cache: 'no-store' }).then((response) => response.text());
		if ((await sha256Hex(html)) !== sha256) throw new Error('grid-publish:publish aborted: content digest mismatch');
		const versions = await listVersions(documentId);
		const latestVersion = (versions[versions.length - 1] || {}).version;
		if (latestVersion !== expectedVersion) {
			throw new Error(`grid-publish:publish aborted: expected version ${expectedVersion}, found ${latestVersion}`);
		}
		const csrfMeta = document.querySelector('meta[name=csrf-token]');
		if (!csrfMeta) throw new Error('grid-publish:publish aborted: csrf-token meta not found (open the document view first)');
		const headers = { 'x-csrf-token': csrfMeta.content };
		const lockResponse = await fetch(`${documentsApi(documentId)}/lock`, {
			method: 'POST',
			credentials: 'same-origin',
			headers: { ...headers, 'Content-Type': 'application/json' },
			body: '{}',
		});
		if (!lockResponse.ok) throw new Error(`grid-publish:publish failed: POST lock ${lockResponse.status} documentId=${documentId}`);
		try {
			const saveResponse = await fetch(`${documentsApi(documentId)}/content?if_version=${expectedVersion}`, {
				method: 'PUT',
				credentials: 'same-origin',
				headers: { ...headers, 'Content-Type': 'text/html' },
				body: html,
			});
			const body = await saveResponse.json().catch(() => ({}));
			if (!saveResponse.ok) throw new Error(`grid-publish:publish failed: PUT content ${saveResponse.status} documentId=${documentId}`);
			// The viewer caches /raw: refresh it so a reload shows the new version.
			await fetch(`/d/${encodeURIComponent(documentId)}/raw`, { cache: 'reload' });
			await fetch(`/d/${encodeURIComponent(documentId)}/view`, { cache: 'reload' });
			return { version: body.version, warnings: body.warnings || [] };
		} finally {
			await fetch(`${documentsApi(documentId)}/lock`, { method: 'DELETE', credentials: 'same-origin', headers });
		}
	};
})();
