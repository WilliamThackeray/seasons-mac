export const defaults = Object.freeze({
  season: "winter",
  effect: "fireflies",
  winterEffect: "snow",
  lightColor: "classic",
  lightDips: 3,
  lightSlack: 0.34,
  lightSize: 1,
  intensity: "steady",
  pile: "normal",
  tool: "glove",
  windX: 0.12,
  windY: 0,
});
const finite = (x, fallback) =>
  typeof x === "number" && Number.isFinite(x)
    ? Math.max(-1, Math.min(1, x))
    : fallback;
const namedSlack = { tight: 0.16, easy: 0.34, loose: 0.55 };
const clampInt = (value, min, max, fallback) => {
  const number = Math.round(Number(value));
  return Number.isFinite(number) ? Math.min(max, Math.max(min, number)) : fallback;
};
const clampUnit = (value, min, max, fallback) => {
  const named = namedSlack[value];
  const number = typeof named === "number" ? named : Number(value);
  return Number.isFinite(number) ? Math.min(max, Math.max(min, number)) : fallback;
};
export function validatePreferences(value) {
  const v = value && typeof value === "object" ? value : {};
  return {
    season: ["winter", "spring", "summer", "fall"].includes(v.season)
      ? v.season
      : defaults.season,
    effect: ["fireflies", "grass"].includes(v.effect) ? v.effect : defaults.effect,
    winterEffect: ["snow", "lights"].includes(v.winterEffect)
      ? v.winterEffect
      : defaults.winterEffect,
    lightColor: ["classic", "warm", "peppermint", "frost"].includes(v.lightColor)
      ? v.lightColor
      : defaults.lightColor,
    lightDips: clampInt(v.lightDips, 2, 8, defaults.lightDips),
    lightSlack: clampUnit(v.lightSlack, 0.1, 0.65, defaults.lightSlack),
    lightSize: clampUnit(v.lightSize, 0.6, 1.8, defaults.lightSize),
    intensity: ["light", "steady", "flurry"].includes(v.intensity)
      ? v.intensity
      : defaults.intensity,
    pile: ["short", "normal", "tall", "none"].includes(v.pile)
      ? v.pile
      : defaults.pile,
    tool: ["glove", "shovel"].includes(v.tool) ? v.tool : defaults.tool,
    windX: finite(v.windX, defaults.windX),
    windY: finite(v.windY, defaults.windY),
  };
}
export function readPreferences(storage) {
  try {
    return validatePreferences(JSON.parse(storage.getItem("snowy-weather-v1")));
  } catch {
    return { ...defaults };
  }
}
export function savePreferences(storage, value) {
  try {
    storage.setItem(
      "snowy-weather-v1",
      JSON.stringify(validatePreferences(value)),
    );
    return true;
  } catch {
    return false;
  }
}
