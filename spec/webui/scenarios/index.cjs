// Registration is explicit and inert: Ruby still owns service/browser lifetimes.
function createRegistry(families) {
  const byId = new Map();
  for (const descriptors of families) {
    for (const descriptor of descriptors) {
      if (!descriptor || typeof descriptor.id !== 'string' || !descriptor.id || typeof descriptor.run !== 'function') {
        throw new TypeError('A WebUI scenario requires a nonempty id and run callback');
      }
      for (const hook of ['prepare', 'afterEach']) {
        if (descriptor[hook] !== undefined && typeof descriptor[hook] !== 'function') {
          throw new TypeError(`WebUI scenario ${descriptor.id} has an invalid ${hook} callback`);
        }
      }
      if (byId.has(descriptor.id)) throw new Error(`Duplicate WebUI scenario: ${descriptor.id}`);
      byId.set(descriptor.id, Object.freeze({ ...descriptor }));
    }
  }
  return Object.freeze({
    ids: Object.freeze([...byId.keys()]),
    select(id) {
      if (!byId.has(id)) throw new Error(`Unknown WebUI scenario: ${String(id)}`);
      return byId.get(id);
    },
  });
}

const registry = createRegistry([
  require('./controls.cjs'),
  require('./models_tables.cjs'),
  require('./layout_windows.cjs'),
  require('./gestures.cjs'),
  require('./decoration.cjs'),
  require('./bootstrap_launcher.cjs'),
  require('./builder_acceptance.cjs'),
  require('./source_acceptance.cjs'),
  require('./scheduling.cjs'),
]);

module.exports = { createRegistry, scenarioIds: registry.ids, selectScenario: registry.select };
