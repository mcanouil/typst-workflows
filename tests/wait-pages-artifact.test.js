'use strict';

const { createServer } = require('node:http');
const assert = require('node:assert/strict');
const test = require('node:test');
const path = require('node:path');

const waitForArtifact = require(path.join(__dirname, '..', 'actions', 'wait-pages-artifact', 'wait.js'));

const runId = 'run-backend-id';
const jobId = 'job-backend-id';
const tokenWith = (scp) => `header.${Buffer.from(JSON.stringify({ scp })).toString('base64url')}.signature`;
const goodToken = tokenWith(`Actions.Example Actions.Results:${runId}:${jobId}`);
const listed = (...names) => ({ body: { artifacts: names.map((name) => ({ name })) } });

async function run({ responses, token = goodToken, env }) {
  const requests = [];
  const server = createServer((req, res) => {
    let data = '';
    req.on('data', (chunk) => {
      data += chunk;
    });
    req.on('end', () => {
      requests.push({ url: req.url, auth: req.headers.authorization, body: JSON.parse(data) });
      const next = responses[Math.min(requests.length - 1, responses.length - 1)];
      if (next.drop) {
        req.socket.destroy();
        return;
      }
      res.writeHead(next.status ?? 200, { 'content-type': 'application/json' });
      res.end(JSON.stringify(next.body ?? {}));
    });
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const result = { failed: null, warned: null, info: [], sleeps: 0 };
  const core = {
    setFailed: (message) => {
      result.failed = message;
    },
    info: (message) => result.info.push(message),
    warning: (message) => {
      result.warned = message;
    },
  };
  try {
    await waitForArtifact({
      core,
      name: 'github-pages-2',
      env: env ?? { ACTIONS_RUNTIME_TOKEN: token, ACTIONS_RESULTS_URL: `http://127.0.0.1:${server.address().port}/` },
      sleep: async () => {
        result.sleeps++;
      },
    });
  } finally {
    server.close();
  }
  return { ...result, requests };
}

test('checks until the artefact is listed', async () => {
  const r = await run({
    responses: [listed('site-dev'), listed('site-dev', 'github-pages-1'), listed('github-pages-1', 'github-pages-2')],
  });
  assert.equal(r.failed, null);
  assert.equal(r.requests.length, 3);
  assert.equal(r.sleeps, 2);
  assert.equal(r.requests[0].url, '/twirp/github.actions.results.api.v1.ArtifactService/ListArtifacts');
  assert.equal(r.requests[0].auth, `Bearer ${goodToken}`);
  assert.deepEqual(r.requests[0].body, { workflow_run_backend_id: runId, workflow_job_run_backend_id: jobId });
  assert.match(r.info[0], /github-pages-2 is listed after 3 check/);
});

test('fails after the last check without a final wait', async () => {
  const r = await run({ responses: [listed('github-pages-1')] });
  assert.equal(r.requests.length, 30);
  assert.equal(r.sleeps, 29);
  assert.match(r.failed, /github-pages-2 is still not listed after 30 checks/);
});

test('warns and stops at once on an HTTP error that a retry cannot correct', async () => {
  const r = await run({ responses: [{ status: 404, body: { msg: 'no' } }] });
  assert.equal(r.requests.length, 1);
  assert.equal(r.failed, null);
  assert.match(r.warned, /HTTP 404/);
});

test('warns without a request when the token has no results scope', async () => {
  const r = await run({ responses: [listed()], token: tokenWith('Actions.Example') });
  assert.equal(r.requests.length, 0);
  assert.equal(r.failed, null);
  assert.match(r.warned, /no Actions.Results scope/);
});

test('counts a server error or rate limit as one more check', async () => {
  const r = await run({ responses: [{ status: 503 }, { status: 429 }, listed('github-pages-2')] });
  assert.equal(r.failed, null);
  assert.equal(r.requests.length, 3);
  assert.match(r.info.at(-1), /github-pages-2 is listed after 3 check/);
});

test('counts a dropped connection as one more check', async () => {
  const r = await run({ responses: [{ drop: true }, listed('github-pages-2')] });
  assert.equal(r.failed, null);
  assert.equal(r.requests.length, 2);
});

test('warns with a clear message when the runtime variables are missing', async () => {
  let r = await run({ responses: [listed()], env: { ACTIONS_RESULTS_URL: 'http://127.0.0.1:1/' } });
  assert.match(r.warned, /ACTIONS_RUNTIME_TOKEN is not set/);
  r = await run({ responses: [listed()], env: { ACTIONS_RUNTIME_TOKEN: goodToken } });
  assert.match(r.warned, /ACTIONS_RESULTS_URL is not set/);
  r = await run({ responses: [listed()], env: { ACTIONS_RUNTIME_TOKEN: 'not-a-jwt', ACTIONS_RESULTS_URL: 'http://127.0.0.1:1/' } });
  assert.match(r.warned, /runtime token cannot be read/);
  assert.equal(r.failed, null);
});

test('warns that the list cannot be read when no check reads it', async () => {
  const r = await run({ responses: [{ status: 503, body: { msg: 'down' } }] });
  assert.equal(r.requests.length, 30);
  assert.equal(r.failed, null);
  assert.match(r.warned, /artefact list could not be read in 30 checks/);
  assert.match(r.warned, /HTTP 503/);
});

test('names the cause of a dropped connection', async () => {
  const r = await run({ responses: [{ drop: true }, listed('github-pages-2')] });
  assert.match(r.info[0], /fetch failed: (ECONNRESET|UND_ERR_SOCKET)/);
});
