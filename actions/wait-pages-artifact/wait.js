'use strict';

const LIST_ARTIFACTS = '/twirp/github.actions.results.api.v1.ArtifactService/ListArtifacts';

function backendIds(token) {
  const claims = JSON.parse(Buffer.from(token.split('.')[1], 'base64url').toString());
  const scope = (claims.scp ?? '').split(' ').find((s) => s.startsWith('Actions.Results:'));
  if (!scope) {
    return null;
  }
  const [, runId, jobId] = scope.split(':');
  return { workflow_run_backend_id: runId, workflow_job_run_backend_id: jobId };
}

module.exports = async function waitForArtifact({
  core,
  name,
  env = process.env,
  checks = 30,
  intervalMs = 2000,
  sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms)),
}) {
  const token = env.ACTIONS_RUNTIME_TOKEN;
  const ids = backendIds(token);
  if (!ids) {
    core.setFailed('The runtime token has no Actions.Results scope, so the artefact list cannot be read.');
    return;
  }
  const url = new URL(LIST_ARTIFACTS, env.ACTIONS_RESULTS_URL);
  for (let check = 1; check <= checks; check++) {
    const response = await fetch(url, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify(ids),
    });
    if (!response.ok) {
      core.setFailed(`Listing the artefacts failed with HTTP ${response.status}: ${await response.text()}`);
      return;
    }
    const { artifacts = [] } = await response.json();
    if (artifacts.some((artifact) => artifact.name === name)) {
      core.info(`${name} is listed after ${check} check(s).`);
      return;
    }
    if (check < checks) {
      await sleep(intervalMs);
    }
  }
  core.setFailed(`${name} is still not listed after ${checks} checks. Re-run the job.`);
};
