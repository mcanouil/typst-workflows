'use strict';

const LIST_ARTIFACTS = '/twirp/github.actions.results.api.v1.ArtifactService/ListArtifacts';

function backendIds(token) {
  let claims;
  try {
    claims = JSON.parse(Buffer.from(token.split('.')[1], 'base64url').toString());
  } catch {
    return { error: 'The runtime token cannot be read as a JSON web token.' };
  }
  const scope = (claims.scp ?? '').split(' ').find((s) => s.startsWith('Actions.Results:'));
  if (!scope) {
    return { error: 'The runtime token has no Actions.Results scope, so the artefact list cannot be read.' };
  }
  const [, runId, jobId] = scope.split(':');
  return { ids: { workflow_run_backend_id: runId, workflow_job_run_backend_id: jobId } };
}

function isRetryable(status) {
  return status === 429 || status >= 500;
}

async function listArtifacts(url, token, ids) {
  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify(ids),
    });
    if (response.ok) {
      const { artifacts = [] } = await response.json();
      return { artifacts };
    }
    const detail = `HTTP ${response.status}: ${await response.text()}`;
    return isRetryable(response.status) ? { retry: detail } : { error: `Listing the artefacts failed with ${detail}` };
  } catch (error) {
    return { retry: error.message };
  }
}

module.exports = async function waitForArtifact({
  core,
  name,
  env = process.env,
  checks = 30,
  intervalMs = 2000,
  sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms)),
}) {
  for (const variable of ['ACTIONS_RUNTIME_TOKEN', 'ACTIONS_RESULTS_URL']) {
    if (!env[variable]) {
      core.setFailed(`${variable} is not set. Run this action as an action step, not inside a run step.`);
      return;
    }
  }
  const token = env.ACTIONS_RUNTIME_TOKEN;
  const { ids, error } = backendIds(token);
  if (error) {
    core.setFailed(error);
    return;
  }
  const url = new URL(LIST_ARTIFACTS, env.ACTIONS_RESULTS_URL);
  for (let check = 1; check <= checks; check++) {
    const result = await listArtifacts(url, token, ids);
    if (result.error) {
      core.setFailed(result.error);
      return;
    }
    if (result.retry) {
      core.info(`Check ${check} could not list the artefacts (${result.retry}).`);
    } else if (result.artifacts.some((artifact) => artifact.name === name)) {
      core.info(`${name} is listed after ${check} check(s).`);
      return;
    }
    if (check < checks) {
      await sleep(intervalMs);
    }
  }
  core.setFailed(`${name} is still not listed after ${checks} checks. Re-run the job.`);
};
