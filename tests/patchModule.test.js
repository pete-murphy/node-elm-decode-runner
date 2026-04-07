const assert = require("assert");
const { test, describe } = require("node:test");

// Extract the patching logic from cli.js for unit testing
function buildExposingPattern(moduleName) {
  return new RegExp(
    `module\\s+${moduleName}\\s+exposing\\s*\\(((?:[^()]*|\\([^()]*\\))*)\\)`,
    "s"
  );
}

function patchContent(content, moduleName, decoderName) {
  const exposingPattern = buildExposingPattern(moduleName);
  const match = exposingPattern.exec(content);
  if (!match) return { patched: null, reason: "no match" };

  const exposingList = match[1];
  if (exposingList.trim() === "..") return { patched: null, reason: "already exposing all" };
  if (exposingList.includes(decoderName)) return { patched: null, reason: "already exposed" };

  const patched = content.replace(
    exposingPattern,
    `module ${moduleName} exposing (..)`
  );
  return { patched, reason: "patched" };
}

describe("patchModule exposing pattern", () => {
  test("patches simple single-line exposing list", () => {
    const content = `module Decoders exposing (Foo)\n\nfooDecoder = ...`;
    const { patched, reason } = patchContent(content, "Decoders", "fooDecoder");
    assert.strictEqual(reason, "patched");
    assert.ok(patched.startsWith("module Decoders exposing (..)"));
    assert.ok(!patched.includes("(Foo)"));
  });

  test("patches multiline exposing list", () => {
    const content = `module Decoders exposing\n    ( Foo\n    , bar\n    )\n\nfooDecoder = ...`;
    const { patched, reason } = patchContent(content, "Decoders", "fooDecoder");
    assert.strictEqual(reason, "patched");
    assert.ok(patched.startsWith("module Decoders exposing (..)"));
  });

  test("skips when exposing (..)", () => {
    const content = `module Decoders exposing (..)\n\nfooDecoder = ...`;
    const { reason } = patchContent(content, "Decoders", "fooDecoder");
    assert.strictEqual(reason, "already exposing all");
  });

  test("skips when decoder is already exposed", () => {
    const content = `module Decoders exposing (Foo, fooDecoder)\n\nfooDecoder = ...`;
    const { reason } = patchContent(content, "Decoders", "fooDecoder");
    assert.strictEqual(reason, "already exposed");
  });

  test("patches exposing list with variant exports like MyError(..)", () => {
    const content = `module Decoders exposing
    ( Foo
    , MyError(..)
    )

fooDecoder = ...`;
    const { patched, reason } = patchContent(content, "Decoders", "fooDecoder");
    assert.strictEqual(reason, "patched");
    assert.ok(patched.startsWith("module Decoders exposing (..)"),
      `Expected patched to start with 'module Decoders exposing (..)' but got:\n${patched}`);
    // The rest of the file should be preserved cleanly
    assert.ok(patched.includes("fooDecoder = ..."),
      `Expected patched to contain the rest of the file but got:\n${patched}`);
    // No leftover fragments from the old exposing list
    assert.ok(!patched.includes("MyError"),
      `Expected no leftover from old exposing list but got:\n${patched}`);
    assert.ok(!patched.includes(", Foo"),
      `Expected no leftover from old exposing list but got:\n${patched}`);
  });

  test("patches exposing list with multiple variant exports", () => {
    const content = `module Challenge exposing
    ( Challenge
    , Details
    , PostInviteTeammatesError(..)
    , Preview
    , PreviewList
    , dateRange
    , getDetails
    )

import Json.Decode`;
    const { patched, reason } = patchContent(content, "Challenge", "previewDecoder");
    assert.strictEqual(reason, "patched");
    assert.ok(patched.startsWith("module Challenge exposing (..)"),
      `Expected clean patch but got:\n${patched}`);
    assert.ok(patched.includes("import Json.Decode"),
      `Expected rest of file preserved but got:\n${patched}`);
    // No leftover fragments
    assert.ok(!patched.includes("Challenge\n"),
      `Expected no leftover from old exposing list`);
    assert.ok(!patched.includes("PostInviteTeammatesError"),
      `Expected no leftover from old exposing list`);
  });
});
