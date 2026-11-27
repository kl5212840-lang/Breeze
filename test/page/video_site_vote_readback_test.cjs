const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const source = fs.readFileSync(
  path.join(__dirname, '../../lib/page/video/video_site_operations.dart'),
  'utf8',
);
const body = source.match(/const videoSiteOperationBody = r'''([\s\S]*?)''';/)[1];
const run = new Function(
  'expected', 'operation', 'payload', 'requestId', 'location', 'window',
  'document', 'DOMParser', 'FormData', 'fetch', body,
);
const watch = 'https://fixture.invalid/watch?v=42';

function video({
  liked = false, owner = '7', work = '42', positive = liked ? '8' : '7',
  disliked = false, negative = disliked ? '3' : '2',
} = {}) {
  const inputs = Object.fromEntries(Object.entries({
    '_token': 'fixture',
    'like-foreign-id': work,
    'like-user-id': owner,
    'like-status': liked ? '1' : '',
    'like-is-positive': '1',
    'unlike-status': disliked ? '1' : '',
    'likes-count': positive,
    'unlikes-count': negative,
  }).map(([name, value]) => [name, { value }]));
  const form = {
    id: 'video-like-form',
    getAttribute: name => ({ action: '/like', method: 'post' })[name],
    querySelector: selector => inputs[selector.match(/name="([^"]+)"/)?.[1]],
    querySelectorAll: selector => {
      const input = form.querySelector(selector);
      return input ? [input] : [];
    },
    inputs,
  };
  return {
    querySelector: selector => selector.startsWith('a#user-modal-trigger')
      ? { getAttribute: () => '/user/' + owner }
      : selector === 'input[name="_token"]' ? inputs._token : null,
    querySelectorAll: selector => selector === 'form' ? [form] : [],
  };
}

async function exercise(reads, { accepted = true, operation = 'like', replacement } = {}) {
  const window = {};
  const calls = [];
  const documents = new Map();
  const started = run(
    new URL(watch), operation, { enabled: true }, 'fixture-vote', { href: watch },
    window, video(),
    class {
      parseFromString(key) { return documents.get(key); }
    },
    function (form) {
      return Object.entries(form.inputs).map(([name, input]) => [name, input.value]);
    },
    async (url, options) => {
      const method = options.method || 'GET';
      calls.push([method, url]);
      let payload;
      if (method === 'POST') {
        assert.equal(options.body.get('like-foreign-id'), '42');
        if (replacement) documents.set('replacement', video(replacement));
        payload = JSON.stringify({
          success: accepted ? true : undefined,
          likeBtn: replacement ? 'replacement' : undefined,
        });
      } else {
        assert.equal(options.cache, 'no-store');
        assert.ok(reads.length, 'no additional readback allowed');
        payload = 'response-' + calls.length;
        documents.set(payload, video(reads.shift()));
      }
      return { ok: true, headers: new Headers(), text: async () => payload };
    },
  );
  assert.equal(started.status, 'pending');
  const job = window.__breezeNativeVideoWork.jobs['fixture-vote'];
  for (let retries = 0; job.pending && retries < 100; retries++) {
    await new Promise(resolve => setTimeout(resolve, 10));
  }
  assert.equal(job.pending, false);
  return { result: job.result, acceptedVote: job.voteAccepted, calls };
}

test('accepted vote with a stale first readback reconciles after one GET', async () => {
  const { result, calls } = await exercise([{}, {}, { liked: true }]);
  assert.deepEqual(calls, [
    ['GET', watch], ['POST', 'https://fixture.invalid/like'],
    ['GET', watch], ['GET', watch],
  ]);
  assert.equal(result.status, 'ok');
  assert.equal(result.liked, true);
  assert.equal(result.positiveVotes, 8);
});

test('a second stale readback leaves the accepted vote unconfirmed', async () => {
  const { result, calls } = await exercise([{}, {}, {}]);
  assert.equal(calls.filter(([method]) => method === 'POST').length, 1);
  assert.equal(calls.length, 4);
  assert.deepEqual(result, { status: 'unconfirmed', writeUnconfirmed: true });
});

test('confirmed selection with an old tally reads again and uses the new site total', async () => {
  const { result, calls } = await exercise([
    {}, { liked: true, positive: '7' }, { liked: true, positive: '11' },
  ], { accepted: false });
  assert.deepEqual(calls.map(([method]) => method), ['GET', 'POST', 'GET', 'GET']);
  assert.equal(result.liked, true);
  assert.equal(result.positiveVotes, 11);
  assert.equal(result.totalVotes, 13);
});

test('a same-work replacement can supply the new tally without a second read', async () => {
  const { result, calls } = await exercise([{}, { liked: true, positive: '7' }], {
    replacement: { liked: true, positive: '10' },
  });
  assert.deepEqual(calls.map(([method]) => method), ['GET', 'POST', 'GET']);
  assert.equal(result.positiveVotes, 10);
  assert.equal(result.totalVotes, 12);
});

test('an accepted switch to dislike is not overwritten by the pre-write tally', async () => {
  const before = { liked: true, positive: '8', negative: '2' };
  const lagged = { disliked: true, positive: '8', negative: '2' };
  const { result, acceptedVote, calls } = await exercise([before, lagged, lagged], {
    operation: 'dislike',
  });
  assert.deepEqual(calls.map(([method]) => method), ['GET', 'POST', 'GET', 'GET']);
  assert.equal(acceptedVote.liked, false);
  assert.equal(acceptedVote.disliked, true);
  assert.equal(acceptedVote.positiveVotes, 7);
  assert.equal(acceptedVote.negativeVotes, 3);
  assert.equal(acceptedVote.totalVotes, 10);
  assert.equal(acceptedVote.voteCountEstimated, true);
  assert.equal(result.liked, false);
  assert.equal(result.disliked, true);
  assert.equal(result.positiveVotes, 7);
  assert.equal(result.negativeVotes, 3);
  assert.equal(result.totalVotes, 10);
  assert.equal(result.voteCountEstimated, true);
});

test('an owner or work mismatch cannot trigger a second readback', async () => {
  for (const mismatch of [{ owner: '8' }, { work: '43' }]) {
    const { result, calls } = await exercise([{}, mismatch]);
    assert.equal(calls.length, 3);
    assert.deepEqual(result, { status: 'changed', writeUnconfirmed: true });
  }
});

test('an ambiguous POST acknowledgement does not extend readback', async () => {
  const { result, calls } = await exercise([{}, {}], { accepted: false });
  assert.equal(calls.length, 3);
  assert.deepEqual(result, { status: 'unconfirmed', writeUnconfirmed: true });
});
