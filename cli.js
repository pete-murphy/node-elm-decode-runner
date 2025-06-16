#!/usr/bin/env node
const {
  writeFileSync,
  readFileSync,
  copyFileSync,
  unlinkSync,
  existsSync,
  readdirSync,
  statSync,
} = require("fs");
const { tmpdir } = require("os");
const { join, resolve } = require("path");
const { compileToString } = require("node-elm-compiler");
const { spawn } = require("child_process");

// Get the command line arguments
const [, , decoderArg] = process.argv;

// Handle --discover flag
if (decoderArg === "--discover") {
  // Check if we have stdin (JSON to decode)
  if (process.stdin.isTTY) {
    // No piped input - just list decoders
    discoverDecoders();
  } else {
    // Piped input - interactive mode with fzf
    discoverAndRunInteractive();
  }
  return;
}

if (!decoderArg) {
  console.error("Usage:");
  console.error("  elm-decode-runner <Module.Name.decoder>");
  console.error("  elm-decode-runner --discover");
  console.error(
    '  echo \'{"json":"data"}\' | elm-decode-runner --discover  # Interactive mode'
  );
  process.exit(1);
}

// Function to discover decoders in the project
function discoverDecoders() {
  // Check if elm.json exists in the current directory
  if (!existsSync("elm.json")) {
    console.error("elm.json not found in current directory");
    process.exit(1);
  }

  let elmJson;
  try {
    const elmJsonContent = readFileSync("elm.json", "utf8");
    elmJson = JSON.parse(elmJsonContent);

    // Basic validation of elm.json structure
    if (!elmJson["source-directories"] || !elmJson["dependencies"]) {
      console.error("invalid elm.json format");
      process.exit(1);
    }
  } catch (err) {
    console.error("invalid elm.json");
    process.exit(1);
  }

  const srcDirs = elmJson["source-directories"] || ["src"];
  const decoders = [];

  for (const srcDir of srcDirs) {
    if (existsSync(srcDir)) {
      findDecodersInDirectory(srcDir, "", decoders);
    }
  }

  // Sort decoders alphabetically
  decoders.sort();

  // Output each decoder on its own line
  decoders.forEach((decoder) => console.log(decoder));

  return decoders;
}

// Function for interactive discovery with fzf
function discoverAndRunInteractive() {
  // Check if elm.json exists in the current directory
  if (!existsSync("elm.json")) {
    console.error("elm.json not found in current directory");
    process.exit(1);
  }

  // First, read and buffer stdin
  let inputJson = "";
  process.stdin.setEncoding("utf8");

  process.stdin.on("data", (chunk) => {
    inputJson += chunk;
  });

  process.stdin.on("end", () => {
    // Validate JSON early
    try {
      JSON.parse(inputJson);
    } catch (err) {
      console.error("JSON syntax error:", err.message);
      process.exit(1);
    }

    // Discover available decoders
    const decoders = discoverDecodersForInteractive();

    if (decoders.length === 0) {
      console.error("No decoders found in project");
      process.exit(1);
    }

    // Launch fzf with the decoders
    const fzf = spawn("fzf", ["--prompt=Select decoder: "], {
      stdio: ["pipe", "pipe", "inherit"],
    });

    // Handle fzf not being available
    fzf.on("error", (err) => {
      if (err.code === "ENOENT") {
        console.error(
          "fzf not found. Please install fzf to use interactive mode."
        );
        console.error("Available decoders:");
        decoders.forEach((decoder) => console.error(`  ${decoder}`));
      } else {
        console.error("Error launching fzf:", err.message);
      }
      process.exit(1);
    });

    // Send decoders to fzf
    fzf.stdin.write(decoders.join("\n"));
    fzf.stdin.end();

    // Collect fzf output
    let selectedDecoder = "";
    fzf.stdout.on("data", (data) => {
      selectedDecoder += data.toString();
    });

    fzf.on("close", (code) => {
      if (code !== 0) {
        console.error("Selection cancelled");
        process.exit(1);
      }

      selectedDecoder = selectedDecoder.trim();
      if (!selectedDecoder) {
        console.error("No decoder selected");
        process.exit(1);
      }

      // Now run the selected decoder on the buffered JSON
      runDecoderOnJson(selectedDecoder, inputJson);
    });
  });

  process.stdin.resume();
}

// Helper function to discover decoders without outputting them
function discoverDecodersForInteractive() {
  let elmJson;
  try {
    const elmJsonContent = readFileSync("elm.json", "utf8");
    elmJson = JSON.parse(elmJsonContent);

    // Basic validation of elm.json structure
    if (!elmJson["source-directories"] || !elmJson["dependencies"]) {
      console.error("invalid elm.json format");
      process.exit(1);
    }
  } catch (err) {
    console.error("invalid elm.json");
    process.exit(1);
  }

  const srcDirs = elmJson["source-directories"] || ["src"];
  const decoders = [];

  for (const srcDir of srcDirs) {
    if (existsSync(srcDir)) {
      findDecodersInDirectory(srcDir, "", decoders);
    }
  }

  // Sort decoders alphabetically
  decoders.sort();
  return decoders;
}

// Try to patch the original module (if decoder isn't exported)
function patchModule(moduleName, decoderName) {
  const elmJson = JSON.parse(readFileSync("elm.json", "utf8"));
  const srcDirs = elmJson["source-directories"] || ["src"];
  const modulePathParts = moduleName.split(".");
  const fileName = modulePathParts.pop() + ".elm";
  const relDir = modulePathParts.join("/");

  for (const srcDir of srcDirs) {
    // Check if the source directory exists
    const absPath = resolve(srcDir, relDir, fileName);
    const backupPath = absPath + ".bak";

    if (!existsSync(absPath)) continue;

    const content = readFileSync(absPath, "utf8");
    const exposingPattern = new RegExp(
      `module\\s+${moduleName}\\s+exposing\\s+\\(([^)]*)\\)`
    );
    const alreadyExposingAll =
      exposingPattern.test(content) &&
      exposingPattern.exec(content)[1].includes("..");

    if (alreadyExposingAll) return null; // no patch needed

    const alreadyExposingDecoder =
      exposingPattern.test(content) &&
      exposingPattern.exec(content)[1].includes(decoderName);

    if (alreadyExposingDecoder) return null;

    copyFileSync(absPath, backupPath);
    const patched = content.replace(
      exposingPattern,
      `module ${moduleName} exposing (..)`
    );

    writeFileSync(absPath, patched);
    return () => {
      copyFileSync(backupPath, absPath);
      unlinkSync(backupPath);
    };
  }

  console.error(`decoder not found: ${decoderName} in module ${moduleName}`);
  process.exit(1);
}

// Function to run a specific decoder on JSON input
function runDecoderOnJson(decoderArg, inputJson) {
  const [modulePath, decoderName] = (() => {
    const lastDot = decoderArg.lastIndexOf(".");
    return [decoderArg.slice(0, lastDot), decoderArg.slice(lastDot + 1)];
  })();

  const moduleImport = `import ${modulePath} exposing (${decoderName})`;
  const elmSource = `
port module DecodeRunner exposing (main)

import Json.Decode exposing (Value)
import Json.Encode
${moduleImport}

port sendToJs : Value -> Cmd msg
port moduleInput : (Value -> msg) -> Sub msg

main : Program () () Value
main =
    Platform.worker
        { init = \\_ -> ( (), Cmd.none )
        , update = \\json _ ->
            case Json.Decode.decodeValue ${decoderName} json of
                Ok value ->
                    ( ()
                    , sendToJs
                        (Json.Encode.object
                            [ ( "tag", Json.Encode.string "Success" )
                            , ( "value", Json.Encode.string (Debug.toString value) )
                            ]
                        )
                    )

                Err err ->
                    ( ()
                    , sendToJs
                        (Json.Encode.object
                            [ ( "tag", Json.Encode.string "Error" )
                            , ( "value", Json.Encode.string (Json.Decode.errorToString err) )
                            ]
                        )
                    )
        , subscriptions = \\_ -> moduleInput (\\json -> json)
        }
`;

  const restore = patchModule(modulePath, decoderName);

  // Write temporary Elm file and compile
  const elmFilePath = join(tmpdir(), "DecodeRunner.elm");
  writeFileSync(elmFilePath, elmSource);

  compileToString([elmFilePath], { output: "ignored.js" })
    .then((jsCode) => {
      if (restore) restore(); // clean up patched file

      const _warn = console.warn;
      console.warn = () => {};
      eval(jsCode);
      console.warn = _warn;

      const app = this.Elm.DecodeRunner.init();

      app.ports.sendToJs.subscribe((msg) => {
        const { tag, value } = msg;
        if (tag === "Error") {
          console.error(value);
          process.exit(1);
        } else {
          console.log(value);
          process.exit(0);
        }
      });

      try {
        const json = JSON.parse(inputJson);
        app.ports.moduleInput.send(json);
      } catch (err) {
        console.error("JSON syntax error:", err.message);
        process.exit(1);
      }
    })
    .catch((err) => {
      if (restore) restore(); // ensure cleanup even on error
      console.error("Elm compilation failed:", err);
      process.exit(1);
    });
}

// Recursively find decoders in a directory
function findDecodersInDirectory(dirPath, modulePrefix, decoders) {
  const entries = readdirSync(dirPath);

  for (const entry of entries) {
    const fullPath = join(dirPath, entry);
    const stat = statSync(fullPath);

    if (stat.isDirectory()) {
      // Recursively search subdirectories
      const newModulePrefix = modulePrefix ? `${modulePrefix}.${entry}` : entry;
      findDecodersInDirectory(fullPath, newModulePrefix, decoders);
    } else if (entry.endsWith(".elm")) {
      // Process Elm files
      const moduleName = entry.slice(0, -4); // Remove .elm extension
      const fullModuleName = modulePrefix
        ? `${modulePrefix}.${moduleName}`
        : moduleName;

      try {
        const content = readFileSync(fullPath, "utf8");
        const foundDecoders = extractDecodersFromContent(
          content,
          fullModuleName
        );
        decoders.push(...foundDecoders);
      } catch (err) {
        // Skip files that can't be read
        continue;
      }
    }
  }
}

// Extract decoder declarations from Elm file content
function extractDecodersFromContent(content, moduleName) {
  const decoders = [];

  // Single regex pattern to match all decoder type signatures
  // Matches patterns like:
  // - name : Decoder Type
  // - name : Json.Decode.Decoder Type
  // - name : Decode.Decoder Type
  // - name : J.Decoder Type
  // - name   :   Decoder   Type (with various spacing)

  const decoderPattern =
    /^([a-zA-Z][a-zA-Z0-9_]*)\s*:\s*(?:([a-zA-Z][a-zA-Z0-9_.]*)\.)?(Decoder)\s+/gm;

  let match;
  while ((match = decoderPattern.exec(content)) !== null) {
    const decoderName = match[1];
    const qualification = match[2] || "";
    const decoderKeyword = match[3];

    // Filter out function types (those with -> in them)
    // We need to check the rest of the line to see if there's an arrow
    const lineStart = match.index;
    const lineEnd = content.indexOf("\n", lineStart);
    const fullLine = content.slice(
      lineStart,
      lineEnd === -1 ? content.length : lineEnd
    );

    // Skip if this is a function type (contains ->)
    if (fullLine.includes("->")) {
      continue;
    }

    // Check if this looks like a JSON decoder type
    // Accept patterns like "Decoder", "Json.Decode.Decoder", "Decode.Decoder", "J.Decoder" etc.
    // Skip other types like "Bytes.Decoder", "TsJson.Decoder" unless they're common JSON decoder aliases
    if (
      !qualification ||
      qualification.match(/^(Json\.Decode|Decode|J|JD|JsonDecode)$/)
    ) {
      decoders.push(`${moduleName}.${decoderName}`);
    }
  }

  return decoders;
}

// Check if elm.json exists in the current directory
if (!existsSync("elm.json")) {
  console.error("elm.json not found in current directory");
  process.exit(1);
}

// Check if elm.json is valid JSON
try {
  const elmJsonContent = readFileSync("elm.json", "utf8");
  try {
    const elmJson = JSON.parse(elmJsonContent);

    // Basic validation of elm.json structure
    if (!elmJson["source-directories"] || !elmJson["dependencies"]) {
      console.error("invalid elm.json format");
      process.exit(1);
    }
  } catch (err) {
    console.error("invalid elm.json");
    process.exit(1);
  }
} catch (err) {
  console.error("Error reading elm.json:", err.message);
  process.exit(1);
}

const [modulePath, decoderName] = (() => {
  const lastDot = decoderArg.lastIndexOf(".");
  return [decoderArg.slice(0, lastDot), decoderArg.slice(lastDot + 1)];
})();

const moduleImport = `import ${modulePath} exposing (${decoderName})`;
const elmSource = `
port module DecodeRunner exposing (main)

import Json.Decode exposing (Value)
import Json.Encode
${moduleImport}

port sendToJs : Value -> Cmd msg
port moduleInput : (Value -> msg) -> Sub msg

main : Program () () Value
main =
    Platform.worker
        { init = \\_ -> ( (), Cmd.none )
        , update = \\json _ ->
            case Json.Decode.decodeValue ${decoderName} json of
                Ok value ->
                    ( ()
                    , sendToJs
                        (Json.Encode.object
                            [ ( "tag", Json.Encode.string "Success" )
                            , ( "value", Json.Encode.string (Debug.toString value) )
                            ]
                        )
                    )

                Err err ->
                    ( ()
                    , sendToJs
                        (Json.Encode.object
                            [ ( "tag", Json.Encode.string "Error" )
                            , ( "value", Json.Encode.string (Json.Decode.errorToString err) )
                            ]
                        )
                    )
        , subscriptions = \\_ -> moduleInput (\\json -> json)
        }
`;

const restore = patchModule(modulePath, decoderName);

// Write temporary Elm file and compile
const elmFilePath = join(tmpdir(), "DecodeRunner.elm");
writeFileSync(elmFilePath, elmSource);

compileToString([elmFilePath], { output: "ignored.js" })
  .then((jsCode) => {
    if (restore) restore(); // clean up patched file

    const _warn = console.warn;
    console.warn = () => {};
    eval(jsCode);
    console.warn = _warn;

    const app = this.Elm.DecodeRunner.init();

    app.ports.sendToJs.subscribe((msg) => {
      const { tag, value } = msg;
      if (tag === "Error") {
        console.error(value);
        process.exit(1);
      } else {
        console.log(value);
        process.exit(0);
      }
    });

    let input = "";
    process.stdin.setEncoding("utf8");
    process.stdin.on("data", (chunk) => (input += chunk));
    process.stdin.on("end", () => {
      try {
        const json = JSON.parse(input);
        app.ports.moduleInput.send(json);
      } catch (err) {
        console.error("JSON syntax error:", err.message);
        process.exit(1);
      }
    });

    process.stdin.resume();
  })
  .catch((err) => {
    if (restore) restore(); // ensure cleanup even on error
    console.error("Elm compilation failed:", err);
    process.exit(1);
  });
