import {
  isArgumentElement,
  isDateElement,
  isNumberElement,
  isPluralElement,
  isSelectElement,
  isTagElement,
  isTimeElement,
  parse,
  type MessageFormatElement,
} from "@formatjs/icu-messageformat-parser";
import { describe, expect, it } from "vitest";
import en from "../../messages/en.json";
import hu from "../../messages/hu.json";

type MessageTree = { [key: string]: string | MessageTree };

function flatten(tree: MessageTree, prefix = ""): Map<string, string> {
  const out = new Map<string, string>();
  for (const [key, value] of Object.entries(tree)) {
    const path = prefix ? `${prefix}.${key}` : key;
    if (typeof value === "string") {
      out.set(path, value);
    } else {
      for (const [k, v] of flatten(value as MessageTree, path)) out.set(k, v);
    }
  }
  return out;
}

// Only the *argument names* matter here — {count}, {count, plural, ...},
// <tag> — not the branch text inside a plural/select, which is free to read
// completely differently per language (Hungarian routinely collapses a
// `plural`'s branches into one, since it doesn't inflect nouns for count the
// way English does, and a plural's own branch labels — "client"/"clients" in
// `{count, plural, one {client} other {clients}}` — are literal text, not
// placeholders). A real ICU parser is the only way to tell the two apart
// reliably, so this walks the same AST next-intl builds at render time
// (`@formatjs/icu-messageformat-parser`, its parser dependency).
function placeholders(message: string): Set<string> {
  const tokens = new Set<string>();
  function walk(nodes: MessageFormatElement[]) {
    for (const node of nodes) {
      if (
        isArgumentElement(node) ||
        isNumberElement(node) ||
        isDateElement(node) ||
        isTimeElement(node)
      ) {
        tokens.add(`{${node.value}}`);
      } else if (isPluralElement(node) || isSelectElement(node)) {
        tokens.add(`{${node.value}}`);
        for (const option of Object.values(node.options)) walk(option.value);
      } else if (isTagElement(node)) {
        tokens.add(`<${node.value}>`);
        walk(node.children);
      }
    }
  }
  walk(parse(message));
  return tokens;
}

describe("messages/en.json and messages/hu.json (D-W0.8: missing translation = build error)", () => {
  const enFlat = flatten(en);
  const huFlat = flatten(hu as MessageTree);

  it("have the same set of keys", () => {
    const enKeys = new Set(enFlat.keys());
    const huKeys = new Set(huFlat.keys());
    const missingInHu = [...enKeys].filter((k) => !huKeys.has(k)).sort();
    const missingInEn = [...huKeys].filter((k) => !enKeys.has(k)).sort();
    expect(missingInHu).toEqual([]);
    expect(missingInEn).toEqual([]);
  });

  it("every ICU placeholder in en.json has a matching one in hu.json", () => {
    const mismatches: string[] = [];
    for (const [key, enValue] of enFlat) {
      const huValue = huFlat.get(key);
      if (huValue === undefined) continue; // reported by the key-parity test above
      const enTokens = placeholders(enValue);
      const huTokens = placeholders(huValue);
      const missing = [...enTokens].filter((t) => !huTokens.has(t));
      const extra = [...huTokens].filter((t) => !enTokens.has(t));
      if (missing.length || extra.length) {
        mismatches.push(`${key}: en=[${[...enTokens]}] hu=[${[...huTokens]}]`);
      }
    }
    expect(mismatches).toEqual([]);
  });
});
