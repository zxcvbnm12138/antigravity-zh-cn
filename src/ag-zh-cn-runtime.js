"use strict";

// <antigravity-zh-cn-runtime>
(function installAntigravityZhCnRuntime() {
  const marker = "__antigravityZhCnRuntimeInstalled";
  if (globalThis[marker]) {
    return;
  }
  globalThis[marker] = true;

  let translations = globalThis.__ANTIGRAVITY_ZH_CN_TRANSLATIONS__;
  if (!translations && typeof window !== "undefined") {
    translations = window.__ANTIGRAVITY_ZH_CN_TRANSLATIONS__;
  }
  if (!translations && typeof global !== "undefined") {
    translations = global.__ANTIGRAVITY_ZH_CN_TRANSLATIONS__;
  }

  try {
    translations = translations || require("../translations/zh-CN.json");
  } catch (error) {
    console.warn("[antigravity-zh-cn] translation file is unavailable", error);
    return;
  }

  const exact = new Map(Object.entries(translations.exact || {}));
  const attrTranslations = translations.attributes || {};
  const patterns = (translations.patterns || []).map((entry) => ({
    regex: new RegExp(entry.match),
    replace: entry.replace,
  }));
  let totalChanges = 0;
  const maxTextLength = 400;
  const textAttrs = ["title", "aria-label", "placeholder", "alt"];
  const ELEMENT_NODE = 1;
  const TEXT_NODE = 3;
  const DOCUMENT_NODE = 9;
  const SHOW_ELEMENT = 1;
  const SHOW_TEXT = 4;
  const FILTER_ACCEPT = 1;
  const FILTER_REJECT = 2;
  const FILTER_SKIP = 3;
  const skipTags = new Set([
    "SCRIPT",
    "STYLE",
    "TEXTAREA",
    "INPUT",
    "PRE",
    "CODE",
    "KBD",
    "SAMP",
    "CANVAS",
    "WEBVIEW",
    "IFRAME",
  ]);
  const skipSelector = [
    "[role='article']",
    "[contenteditable='true']",
    ".monaco-editor",
    ".monaco-editor-background",
    ".view-lines",
    ".view-line",
    ".xterm",
    ".terminal",
    ".integrated-terminal",
    ".cm-editor",
    ".cm-content",
    ".notebook-editor",
    ".notebook-cell-list",
    ".codicon",
    ".quick-input-widget input",
    "webview",
    "iframe",
  ].join(",");
  const weakSkipSelector = ".select-text";
  const attrSkipTags = new Set(["SCRIPT", "STYLE", "CANVAS", "WEBVIEW", "IFRAME"]);

  function normalize(value) {
    return String(value || "").replace(/\s+/g, " ").trim();
  }

  function preserveOuterWhitespace(original, replacement) {
    const leading = String(original).match(/^\s*/)[0];
    const trailing = String(original).match(/\s*$/)[0];
    return `${leading}${replacement}${trailing}`;
  }

  function translateValue(value, attrName, options = {}) {
    const normalized = normalize(value);
    if (!normalized || normalized.length > maxTextLength) {
      return null;
    }

    const attrMap = attrName ? attrTranslations[attrName] : null;
    if (attrMap && Object.prototype.hasOwnProperty.call(attrMap, normalized)) {
      return preserveOuterWhitespace(value, attrMap[normalized]);
    }

    if (exact.has(normalized)) {
      return preserveOuterWhitespace(value, exact.get(normalized));
    }

    if (options.exactOnly) {
      return null;
    }

    for (const entry of patterns) {
      if (entry.regex.test(normalized)) {
        return preserveOuterWhitespace(value, normalized.replace(entry.regex, entry.replace));
      }
    }

    return null;
  }

  function shouldSkipElement(element) {
    if (!element || element.nodeType !== ELEMENT_NODE) {
      return false;
    }
    if (skipTags.has(element.tagName)) {
      return true;
    }
    if (typeof element.closest === "function" && element.closest(skipSelector)) {
      return true;
    }
    return false;
  }

  function isWeakSkipped(element) {
    return Boolean(
      element &&
      element.nodeType === ELEMENT_NODE &&
      typeof element.closest === "function" &&
      element.closest(weakSkipSelector)
    );
  }

  function translateValueForElement(value, attrName, element) {
    return translateValue(value, attrName, { exactOnly: isWeakSkipped(element) });
  }

  function shouldSkipAttributes(element) {
    if (!element || element.nodeType !== ELEMENT_NODE) {
      return false;
    }
    if (attrSkipTags.has(element.tagName)) {
      return true;
    }
    if (typeof element.closest === "function" && element.closest(skipSelector)) {
      return true;
    }
    return false;
  }

  function translateTextNode(node) {
    const parent = node.parentElement;
    if (!parent || shouldSkipElement(parent)) {
      return;
    }
    const translated = translateValueForElement(node.nodeValue, null, parent);
    if (translated && translated !== node.nodeValue) {
      node.nodeValue = translated;
      totalChanges += 1;
    }
  }

  function translateAttributes(element) {
    if (!element || shouldSkipAttributes(element)) {
      return;
    }
    for (const attrName of textAttrs) {
      if (!element.hasAttribute(attrName)) {
        continue;
      }
      const current = element.getAttribute(attrName);
      const translated = translateValueForElement(current, attrName, element);
      if (translated && translated !== current) {
        element.setAttribute(attrName, translated);
        totalChanges += 1;
      }
    }
  }

  function translateOwnText(element) {
    if (!element || shouldSkipElement(element) || element.children.length > 0 || element.childNodes.length < 2) {
      return;
    }
    const translated = translateValueForElement(element.textContent, null, element);
    if (translated && translated !== element.textContent) {
      element.textContent = translated;
      totalChanges += 1;
    }
  }

  function translateDirectText(element) {
    if (!element || shouldSkipElement(element) || element.childNodes.length < 2) {
      return;
    }
    const textNodes = Array.from(element.childNodes).filter((node) => node.nodeType === TEXT_NODE);
    if (textNodes.length < 2) {
      return;
    }
    const combined = textNodes.map((node) => node.nodeValue).join("");
    const translated = translateValueForElement(combined, null, element);
    if (translated && translated !== combined) {
      textNodes[0].nodeValue = translated;
      for (let index = 1; index < textNodes.length; index += 1) {
        textNodes[index].nodeValue = "";
      }
      totalChanges += 1;
    }
  }

  function translateRoot(root) {
    if (!root) {
      return;
    }

    if (root.nodeType === TEXT_NODE) {
      translateTextNode(root);
      return;
    }

    if (root.nodeType !== ELEMENT_NODE && root.nodeType !== DOCUMENT_NODE) {
      return;
    }

    if (root.nodeType === ELEMENT_NODE && shouldSkipElement(root)) {
      return;
    }

    if (root.nodeType === ELEMENT_NODE) {
      translateAttributes(root);
      translateOwnText(root);
      translateDirectText(root);
    }

    const walker = document.createTreeWalker(root, SHOW_TEXT | SHOW_ELEMENT, {
      acceptNode(node) {
        if (node.nodeType === ELEMENT_NODE) {
          return shouldSkipElement(node) ? FILTER_REJECT : FILTER_ACCEPT;
        }
        if (node.nodeType === TEXT_NODE) {
          const parent = node.parentElement;
          return parent && !shouldSkipElement(parent) ? FILTER_ACCEPT : FILTER_REJECT;
        }
        return FILTER_SKIP;
      },
    });

    let node = walker.currentNode;
    while (node) {
      if (node.nodeType === ELEMENT_NODE) {
        translateAttributes(node);
        translateOwnText(node);
        translateDirectText(node);
      } else if (node.nodeType === TEXT_NODE) {
        translateTextNode(node);
      }
      node = walker.nextNode();
    }
  }

  let scheduled = false;
  function scheduleTranslate() {
    if (scheduled) {
      return;
    }
    scheduled = true;
    const run = () => {
      scheduled = false;
      try {
        translateRoot(document.body || document.documentElement);
        document.documentElement.setAttribute("data-ag-zh-cn-changes", String(totalChanges));
      } catch (error) {
        console.warn("[antigravity-zh-cn] translate pass failed", error);
      }
    };
    setTimeout(run, 0);
  }

  function start() {
    try {
      document.documentElement.setAttribute("data-ag-zh-cn-runtime", "installed");
      document.documentElement.setAttribute("data-ag-zh-cn-exact-size", String(exact.size));
    } catch (error) {
      console.warn("[antigravity-zh-cn] runtime marker failed", error);
    }
    scheduleTranslate();
    if (typeof MutationObserver === "function") {
      const observer = new MutationObserver((mutations) => {
        for (const mutation of mutations) {
          if (mutation.type === "childList" || mutation.type === "characterData" || mutation.type === "attributes") {
            scheduleTranslate();
            break;
          }
        }
      });
      observer.observe(document.documentElement, {
        childList: true,
        subtree: true,
        characterData: true,
        attributes: true,
        attributeFilter: textAttrs,
      });
    }
    setInterval(scheduleTranslate, 2000);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", start, { once: true });
  } else {
    start();
  }
})();
// </antigravity-zh-cn-runtime>
