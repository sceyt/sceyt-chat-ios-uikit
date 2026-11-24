const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const workflow = fs.readFileSync(path.join(__dirname, '../workflows/channel-alerts.yml'), 'utf8');

// Each step's inline github-script, in workflow order.
function inlineScripts(source) {
  const lines = source.split(/\r?\n/);
  const scripts = [];
  for (let index = 0; index < lines.length; index++) {
    const match = lines[index].match(/^( *)script: \|$/);
    if (!match) continue;
    const indentation = ' '.repeat(match[1].length + 2);
    const body = [];
    while (index + 1 < lines.length) {
      const line = lines[index + 1];
      if (line.trim() && !line.startsWith(indentation)) break;
      body.push(line.slice(indentation.length));
      index++;
    }
    scripts.push(body.join('\n'));
  }
  return scripts;
}

const [buildAlert, sendAlert] = inlineScripts(workflow);
assert(buildAlert && sendAlert, 'The alert workflow must build and send the alert in two scripts');

const WEBHOOK = 'https://hooks.slack.com/services/T000/B000/abcDEF123';
const RUN_URL = 'https://github.example/uikit/actions/runs/123';

function testsJob(conclusion, failedStep) {
  return {name: 'unit-tests', conclusion,
    steps: failedStep ? [{name: failedStep, conclusion: 'failure'}] : [{name: 'Build and test', conclusion}]};
}

async function run(options = {}) {
  const requests = [], errors = [], warnings = [], infos = [], outputs = {};
  const pr = {number: 5, state: 'open', title: 'Fix "upload"\nflow',
    head: {sha: 'abc123456789', ref: 'feature/upload'}, base: {ref: 'dev'},
    html_url: 'https://github.example/uikit/pull/5'};
  const core = {
    info: message => infos.push(message),
    warning: message => warnings.push(message),
    setFailed: message => errors.push(message),
    setOutput: (name, value) => { outputs[name] = value; }
  };
  const jobs = options.jobs || [
    testsJob(options.failed ? 'failure' : 'success', options.failed ? 'Build and test' : null),
    {name: 'Slack Alerts / notify', conclusion: 'failure', steps: [{name: 'Send CI alert to Slack', conclusion: 'failure'}]}
  ];

  await vm.runInNewContext('(async () => {' + buildAlert + '\n})()', {
    core,
    context: {repo: {owner: 'example', repo: 'uikit'}, runId: 123,
      payload: options.pr ? {pull_request: pr} : {}},
    process: {env: {FAILED: String(Boolean(options.failed))}},
    github: {
      rest: {
        actions: {getWorkflowRun: async () => ({data: {
          head_sha: pr.head.sha, head_branch: 'dev', run_number: 12,
          html_url: RUN_URL, actor: {login: 'builder'}
        }}), listJobsForWorkflowRun: () => {}},
        pulls: {get: async () => ({data: {...pr,
          ...(options.stale ? {head: {...pr.head, sha: 'new'}} : {}),
          ...(options.closed ? {state: 'closed'} : {})
        }})}
      },
      paginate: async () => {
        if (options.jobsUnavailable) throw new Error('API unavailable');
        return jobs;
      }
    }
  });

  // The workflow skips the send step when the first step produced no alert.
  const body = outputs.body || '';
  if (body) {
    await vm.runInNewContext('(async () => {' + sendAlert + '\n})()', {
      core, AbortSignal,
      process: {env: {ALERT_BODY: body,
        SLACK_WEBHOOK_URL_CI_IOS: options.webhook === undefined ? WEBHOOK : options.webhook}},
      fetch: async (url, request) => {
        requests.push({url, request, payload: JSON.parse(request.body)});
        if (options.networkFailure) throw new Error('Connection failed');
        const status = options.status || 200;
        return {ok: status >= 200 && status < 300, status};
      }
    });
  }
  return {body, requests, errors, warnings, infos};
}

test('success posts the passed checks to the Slack webhook', async () => {
  const result = await run();
  assert.equal(result.requests.length, 1);
  const sent = result.requests[0];
  assert.equal(sent.url, WEBHOOK);
  assert.equal(sent.request.method, 'POST');
  assert.equal(sent.request.redirect, 'error');
  assert.deepEqual(sent.payload, {text: result.body, mrkdwn: false, link_names: false,
    unfurl_links: false, unfurl_media: false});
  assert(result.body.startsWith('🟢 All iOS checks passed\n\n📱 Sceyt Chat iOS UIKit · GitHub\n🌿 dev\n'));
  assert(result.body.includes('🔖 Commit abc1234 · Run #12'));
  assert(result.body.includes('👤 Triggered by @builder'));
  assert(result.body.includes('🔍 View logs\n' + RUN_URL));
  assert(result.body.includes('✅ Passed checks\n• unit-tests'));
  assert(!result.body.includes('Slack Alerts'));
  assert.deepEqual(result.errors, []);
});

test('failure names the failed check first and links the pull request', async () => {
  const result = await run({failed: true, pr: true,
    jobs: [testsJob('failure', 'Check changed source line coverage')]});
  assert(result.body.startsWith('🔴 Changed-line coverage failed\n'));
  assert(result.body.includes('🌿 feature/upload → dev\n🔀 PR #5 · Fix "upload" flow'));
  assert(result.body.includes('❌ Failed checks\n• unit-tests'));
  assert(result.body.endsWith('🔀 Open pull request\nhttps://github.example/uikit/pull/5'));
  assert.equal(result.requests.length, 1);
});

test('failure titles use the step name, or the job name without a failed step', async () => {
  const result = await run({failed: true, jobs: [
    testsJob('failure', 'Check the public API'),
    testsJob('failure', 'Transfer strict concurrency'),
    {name: 'Other Job', conclusion: 'timed_out', steps: []}
  ]});
  assert(result.body.startsWith('🔴 Public API & Transfer strict concurrency & Other Job failed\n'));
});

test('a Thread Sanitizer failure is named and listed with the passed tests job', async () => {
  const result = await run({failed: true, jobs: [
    testsJob('success'),
    {name: 'Thread Sanitizer', conclusion: 'failure',
      steps: [{name: 'Run unit tests with Thread Sanitizer', conclusion: 'failure'}]}
  ]});
  assert(result.body.startsWith('🔴 Thread Sanitizer failed\n'));
  assert(result.body.includes('✅ Passed checks\n• unit-tests'));
  assert(result.body.includes('❌ Failed checks\n• Thread Sanitizer'));
});

test('every check title names a step in the CI workflow', () => {
  const ci = fs.readFileSync(path.join(__dirname, '../workflows/ios-ci.yml'), 'utf8');
  const steps = [...buildAlert.matchAll(/^\s*\['([^']+)', '[^']+'\],?$/gm)].map(match => match[1]);
  assert.equal(steps.length, 5);
  for (const step of steps) assert(ci.includes(`- name: ${step}\n`), step);
});

for (const option of ['stale', 'closed']) {
  test(option + ' pull request does not send an alert', async () => {
    const result = await run({pr: true, [option]: true});
    assert.equal(result.body, '');
    assert.equal(result.requests.length, 0);
  });
}

test('a missing webhook skips the alert without failing', async () => {
  const result = await run({webhook: ''});
  assert.equal(result.requests.length, 0);
  assert.deepEqual(result.errors, []);
  assert(result.infos.some(message => message.includes('SLACK_WEBHOOK_URL_CI_IOS')));
});

test('a webhook that is not a Slack incoming webhook is rejected', async () => {
  const result = await run({webhook: 'https://example.com/hook'});
  assert.equal(result.requests.length, 0);
  assert.deepEqual(result.errors, ['Configure SLACK_WEBHOOK_URL_CI_IOS with a Slack incoming webhook URL.']);
});

for (const status of [400, 404, 500]) {
  test('HTTP ' + status + ' fails the job without a retry', async () => {
    const result = await run({status});
    assert.equal(result.requests.length, 1);
    assert.deepEqual(result.errors, ['Slack delivery failed: HTTP ' + status]);
  });
}

test('a connection failure fails the job without a retry', async () => {
  const result = await run({networkFailure: true});
  assert.equal(result.requests.length, 1);
  assert.deepEqual(result.errors, ['Slack delivery failed before an HTTP response was received.']);
});

test('job API failure still sends the run link', async () => {
  const result = await run({failed: true, jobsUnavailable: true});
  assert.equal(result.warnings.length, 1);
  assert(result.body.startsWith('🔴 iOS CI failed\n'));
  assert(result.body.includes('🔍 View logs\n' + RUN_URL));
  assert(result.body.includes('Check results unavailable. See the run logs for details.'));
  assert.equal(result.requests.length, 1);
});
