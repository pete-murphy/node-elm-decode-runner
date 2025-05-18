#!/usr/bin/env node
const {
  writeFileSync,
  readFileSync,
  copyFileSync,
  unlinkSync,
  existsSync,
} = require("fs");
const { tmpdir } = require("os");
const { join, resolve } = require("path");
const { compileToString } = require("node-elm-compiler");

// Get the command line arguments
const [, , decoderArg] = process.argv;

if (!decoderArg) {
  console.error("Usage: elm-decode-runner <Module.Name.decoder>");
  process.exit(1);
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

// Try to patch the original module (if decoder isn't exported)
const patchModule = (moduleName, decoderName) => {
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

  console.error(`decoder not found: ${decoderName} in module ${modulePath}`);
  process.exit(1);
};

const restore = patchModule(modulePath);

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
