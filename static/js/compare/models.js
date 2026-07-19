// compare/models.js — model classification, fetching, display names, persistence
import Storage from '../storage.js';
import state from './state.js';
import uiModule from '../ui.js';
import { sortModeloObjects } from '../modelSort.js';

var escapeHtml = uiModule.esc;

// ── Modelo classification constants ──
const NON_CHAT_PREFIXES = ['tts-', 'whisper-', 'text-embedding-', 'text-moderation-', 'moderation-', 'embedding'];
const NON_CHAT_SUFFIXES = ['deep-research', '-online'];
const IMAGE_PREFIXES = ['dall-e-3', 'gpt-image', 'chatgpt-image'];
const DEPRECATED_IMAGE = ['dall-e-2'];

function classifyModelo(id) {
  const lower = id.toLowerCase();
  if (DEPRECATED_IMAGE.some(p => lower.startsWith(p))) return 'other';
  if (IMAGE_PREFIXES.some(p => lower.startsWith(p))) return 'image';
  if (NON_CHAT_PREFIXES.some(p => lower.startsWith(p))) return 'other';
  if (NON_CHAT_SUFFIXES.some(p => lower.endsWith(p) || lower.includes(p))) return 'other';
  return 'chat';
}

/** Build display names for selected models, adding endpoint name when the same model appears from multiple providers. */
function _modelDisplayNames(models) {
  const nameCount = {};
  for (const m of models) {
    const short = m.name || m.model.split('/').pop();
    nameCount[short] = (nameCount[short] || 0) + 1;
  }
  return models.map(m => {
    const short = m.name || m.model.split('/').pop();
    if (nameCount[short] > 1 && m.endpointName) return short + ' (' + escapeHtml(m.endpointName) + ')';
    return short;
  });
}

/** Guardar selected models and synth models to localStorage, keyed by compare mode. */
function _persistSelections() {
  if (state._selectedModelos.length > 0) {
    Storage.setJSON('odysseus-compare-selections-' + (state._compareMode || 'chat'), state._selectedModelos);
  }
  if ((state._compareMode === 'search' || state._compareMode === 'research') && state._searchSynthModelos) {
    Storage.setJSON('odysseus-compare-synth-' + state._compareMode, state._searchSynthModelos);
  }
}

// ── Modelo fetching with cache ──
const MODELS_CACHE_TTL = 30000; // 30 seconds

/** Fetch available models from API. */
async function fetchModelos() {
  const now = Date.now();
  if (state._fetchModelosCache && (now - state._fetchModelosCacheTime) < MODELS_CACHE_TTL) {
    return state._fetchModelosCache;
  }
  const res = await fetch(`${state.API_BASE}/api/models`);
  const data = await res.json();
  const models = [];
  if (data.items && data.items.length > 0) {
    data.items.forEach(item => {
      const displayNames = item.models_display || item.models || [];
      const extraDisplay = item.models_extra_display || item.models_extra || [];
      // Curated list (item.models) takes priority; non-curated extras come
      // after so newer/uncatalogued models (e.g. deepseek-v4-pro) still show.
      (item.models || []).forEach((mid, i) => {
        models.push({
          id: mid,
          url: item.url,
          name: (displayNames[i] || mid).split('/').pop(),
          endpointId: item.endpoint_id || null,
          endpointName: item.endpoint_name || '',
          type: classifyModelo(mid),
        });
      });
      (item.models_extra || []).forEach((mid, i) => {
        models.push({
          id: mid,
          url: item.url,
          name: (extraDisplay[i] || mid).split('/').pop(),
          endpointId: item.endpoint_id || null,
          endpointName: item.endpoint_name || '',
          type: classifyModelo(mid),
        });
      });
    });
  }
  state._fetchModelosCache = sortModeloObjects(models);
  state._fetchModelosCacheTime = now;
  return state._fetchModelosCache;
}

// ── Shuffle pool persistence ──
const POOL_STORAGE_KEY = 'odysseus-shuffle-pool-excluded';

function getExcludedModelos() {
  return Storage.getJSON(POOL_STORAGE_KEY, []);
}

function setExcludedModelos(arr) {
  Storage.setJSON(POOL_STORAGE_KEY, arr);
}

export { classifyModelo, _modelDisplayNames, fetchModelos, _persistSelections, getExcludedModelos, setExcludedModelos };
