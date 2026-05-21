"use strict";

function translateApplicationMenu(menu) {
  let translations;
  try {
    translations = require("../translations/zh-CN.json");
  } catch (error) {
    console.warn("[antigravity-zh-cn] native menu translations are unavailable", error);
    return;
  }

  const map = translations.nativeMenus || {};
  const translateMenu = (currentMenu) => {
    if (!currentMenu || !Array.isArray(currentMenu.items)) {
      return;
    }
    for (const item of currentMenu.items) {
      if (item.label && Object.prototype.hasOwnProperty.call(map, item.label)) {
        item.label = map[item.label];
      }
      if (item.submenu) {
        translateMenu(item.submenu);
      }
    }
  };

  translateMenu(menu);
}

module.exports = { translateApplicationMenu };
