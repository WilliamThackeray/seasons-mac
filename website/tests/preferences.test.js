import test from "node:test";
import assert from "node:assert/strict";
import {
  defaults,
  readPreferences,
  savePreferences,
} from "../src/preferences.js";

test("preferences survive a reload through the same storage", () => {
  const values = new Map();
  const storage = {
    getItem: (key) => values.get(key) ?? null,
    setItem: (key, value) => values.set(key, value),
  };
  assert.equal(
    savePreferences(storage, {
      ...defaults,
      tool: "shovel",
      intensity: "flurry",
      windX: -0.8,
    }),
    true,
  );
  assert.deepEqual(readPreferences(storage), {
    ...defaults,
    tool: "shovel",
    intensity: "flurry",
    windX: -0.8,
  });
});
test("malformed and unavailable storage keep the desktop usable", () => {
  assert.deepEqual(readPreferences({ getItem: () => "{broken" }), defaults);
  assert.deepEqual(
    readPreferences({
      getItem: () => {
        throw Error("disabled");
      },
    }),
    defaults,
  );
  assert.equal(
    savePreferences(
      {
        setItem: () => {
          throw Error("full");
        },
      },
      defaults,
    ),
    false,
  );
  const invalid = readPreferences({
    getItem: () =>
      JSON.stringify({
        intensity: "<script>",
        tool: "eval",
        windX: 900,
        paused: "yes",
      }),
  });
  assert.equal(invalid.windX, 1);
  assert.equal(invalid.tool, "glove");
  assert.equal(invalid.season, "winter");
  assert.equal(invalid.pile, "normal");
  assert.equal("paused" in invalid, false);
});
test("season is winter, spring, summer, or fall", () => {
  const values = new Map();
  const storage = {
    getItem: (key) => values.get(key) ?? null,
    setItem: (key, value) => values.set(key, value),
  };
  assert.equal(
    savePreferences(storage, { ...defaults, season: "fall" }),
    true,
  );
  assert.equal(readPreferences(storage).season, "fall");
  savePreferences(storage, { ...defaults, season: "spring" });
  assert.equal(readPreferences(storage).season, "spring");
  savePreferences(storage, { ...defaults, season: "summer" });
  assert.equal(readPreferences(storage).season, "summer");
  savePreferences(storage, { ...defaults, season: "holiday" });
  assert.equal(readPreferences(storage).season, "winter");
});
test("summer effect is fireflies or grass", () => {
  const values = new Map();
  const storage = {
    getItem: (key) => values.get(key) ?? null,
    setItem: (key, value) => values.set(key, value),
  };
  assert.equal(defaults.effect, "fireflies");
  savePreferences(storage, { ...defaults, effect: "grass" });
  assert.equal(readPreferences(storage).effect, "grass");
  savePreferences(storage, { ...defaults, effect: "bees" });
  assert.equal(readPreferences(storage).effect, "fireflies");
});
test("winter lights remember color, dips, and slack", () => {
  const values = new Map();
  const storage = {
    getItem: (key) => values.get(key) ?? null,
    setItem: (key, value) => values.set(key, value),
  };
  assert.equal(defaults.winterEffect, "snow");
  assert.equal(defaults.lightDips, 3);
  assert.equal(defaults.lightSlack, 0.34);
  assert.equal(defaults.lightSize, 1);
  savePreferences(storage, {
    ...defaults,
    winterEffect: "lights",
    lightColor: "frost",
    lightDips: 5,
    lightSlack: 0.5,
    lightSize: 1.4,
  });
  const saved = readPreferences(storage);
  assert.equal(saved.winterEffect, "lights");
  assert.equal(saved.lightColor, "frost");
  assert.equal(saved.lightDips, 5);
  assert.equal(saved.lightSlack, 0.5);
  assert.equal(saved.lightSize, 1.4);
  savePreferences(storage, {
    ...defaults,
    winterEffect: "scene",
    lightColor: "rainbow",
    lightDips: 12,
    lightSlack: "loose",
    lightSize: 9,
  });
  const invalid = readPreferences(storage);
  assert.equal(invalid.winterEffect, "snow");
  assert.equal(invalid.lightColor, "classic");
  assert.equal(invalid.lightDips, 8);
  assert.equal(invalid.lightSlack, 0.55);
  assert.equal(invalid.lightSize, 1.8);
});
test("pile height is short, normal, tall, or no limit", () => {
  const values = new Map();
  const storage = {
    getItem: (key) => values.get(key) ?? null,
    setItem: (key, value) => values.set(key, value),
  };
  assert.equal(defaults.pile, "normal");
  savePreferences(storage, { ...defaults, pile: "none" });
  assert.equal(readPreferences(storage).pile, "none");
  savePreferences(storage, { ...defaults, pile: "tall" });
  assert.equal(readPreferences(storage).pile, "tall");
  savePreferences(storage, { ...defaults, pile: "endless" });
  assert.equal(readPreferences(storage).pile, "normal");
});
