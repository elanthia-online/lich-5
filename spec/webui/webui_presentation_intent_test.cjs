const { test } = require('node:test');
const assert = require('node:assert/strict');
const { measuredDomFixture } = require('./webui_measured_dom_fixture.cjs');

for (const [cid, vertical] of [['arbitrary-tabs', true], ['saved-account-tabs', false]]) {
  test(`tabs ${cid} follow explicit vertical=${vertical} with stable selection and actions`, t => {
    const f = measuredDomFixture();
    t.after(() => f.dom.window.close());
    f.receive({ type: 'hello', pages: [{ address: 'intent' }] });
    const frame = generation => ({ type: 'render', page: 'intent', generation,
      bindings: { [cid]: ['select'], help: ['activate'] },
      tree: { type: 'page', cid: 'root', props: { bare: true }, children: [
        { type: 'tabs', cid, props: { vertical, names: ['One', 'Two'], selected: 1 }, children: [
          { type: 'text', cid: 'one', slot: 'One', props: { content: 'First' } },
          { type: 'text', cid: 'two', slot: 'Two', props: { content: 'Second' } },
          { type: 'button', cid: 'help', placement: { tab_action: 'end' }, props: { label: 'Help' } }
        ] }
      ] } });
    f.receive(frame(1));
    const tabs = f.element(cid);
    assert.equal(tabs.classList.contains('account-tabs-left'), vertical);
    assert.equal(tabs.querySelectorAll('.tab-panel').length, 2);
    assert.equal(tabs.querySelectorAll('[role="tab"]')[1].getAttribute('aria-selected'), 'true');
    assert.equal(f.element('one').hidden, true);
    assert.equal(f.element('two').hidden, false);
    assert.equal(tabs.querySelector('[role="tablist"]').contains(f.element('help')), false);
    f.element('help').click();
    tabs.querySelector('[role="tab"]').click();
    const events = f.sent.filter(message => message.type === 'event');
    assert.deepEqual(events.map(message => [message.cid, message.event]), [['help', 'activate'], [cid, 'select']]);
    assert.deepEqual(events[1].payload, { index: 0 });
    f.receive(frame(2));
    assert.equal(f.element(cid).classList.contains('account-tabs-left'), vertical);
  });
}

test('declared roles and literal child composition work with arbitrary button identities', t => {
  const f = measuredDomFixture();
  t.after(() => f.dom.window.close());
  f.receive({ type: 'hello', pages: [{ address: 'intent' }] });
  f.receive({ type: 'render', page: 'intent', generation: 1,
    bindings: { arbitrary: ['activate'], star: ['activate'] }, submissions: { arbitrary: ['name'] },
    tree: { type: 'page', cid: 'root', props: { bare: true }, children: [
      { type: 'text_input', cid: 'name', props: { value: 'Draft' } },
      { type: 'button', cid: 'arbitrary', props: { label: 'Unparsed  |  label', presentation_role: 'record_primary',
        a11y_label: 'Play literal' }, children: [
        { type: 'text', cid: 'content', slot: 'content', props: { content: '', fragments: [
          { content: '<img src=bad>' }, { content: 'A  |  B' }, { content: 'Third' }
        ] } }
      ] },
      { type: 'button', cid: 'star', props: { label: 'unchanged token', checked: true, presentation_role: 'record_favorite',
        a11y_label: 'Unfavorite literal' }, children: [
        { type: 'text', cid: 'glyph', slot: 'content', props: { content: '\u2605' } }
      ] }
    ] } });
  const button = f.element('arbitrary');
  assert.equal(button.dataset.presentationRole, 'record_primary');
  assert.equal(button.getAttribute('aria-label'), 'Play literal');
  assert.equal(button.textContent, '<img src=bad>A  |  BThird');
  assert.equal(button.querySelector('img'), null);
  assert.deepEqual([...button.querySelectorAll('.webui-text-fragment')].map(part => part.textContent),
    ['<img src=bad>', 'A  |  B', 'Third']);
  button.querySelector('.webui-text-fragment').click();
  const event = f.sent.filter(message => message.type === 'event').at(-1);
  assert.equal(event.cid, 'arbitrary');
  assert.equal(event.event, 'activate');
  assert.deepEqual(event.submission, ['Draft']);
  assert.equal(f.sent.filter(message => message.event === 'activate').length, 1);
  assert.equal(f.element('star').textContent, '\u2605');
  assert.equal(f.element('star').dataset.favoriteState, 'filled_star');
  assert.equal(f.element('star').getAttribute('aria-label'), 'Unfavorite literal');
});

test('launcher-looking identities and display tokens cannot select button or tab presentation', t => {
  const f = measuredDomFixture();
  t.after(() => f.dom.window.close());
  f.receive({ type: 'hello', pages: [{ address: 'intent' }] });
  f.receive({ type: 'render', page: 'intent', generation: 1, tree: { type: 'page', cid: 'root', props: {}, children: [
    { type: 'button', cid: 'button:play-entry-lookalike', props: { label: 'First  |  Second  |  Third' } },
    { type: 'button', cid: 'button:favorite-entry-lookalike', props: { label: 'filled_star' } },
    { type: 'tabs', cid: 'tabs:account-management-tabs', props: { names: ['One'] }, children: [
      { type: 'text', cid: 'one', props: { content: 'One' } }
    ] }
  ] } });
  const play = f.element('button:play-entry-lookalike');
  assert.equal(play.textContent, 'First  |  Second  |  Third');
  assert.equal(play.children.length, 0);
  assert.equal(play.dataset.presentationRole, undefined);
  const favorite = f.element('button:favorite-entry-lookalike');
  assert.equal(favorite.textContent, 'filled_star');
  assert.equal(favorite.dataset.favoriteState, undefined);
  assert.equal(f.element('tabs:account-management-tabs').classList.contains('nested'), false);
});
