#!/usr/bin/env node
const { readFileSync, writeFileSync } = require("fs");
const { tmpdir } = require("os");
const { join } = require("path");
const { compileToString } = require("node-elm-compiler");

const [,, decoderArg] = process.argv;

if (!decoderArg) {
    console.error("Usage: elm-decode <Module.Name.decoder>");
    process.exit(1);
}

const [modulePath, decoderName] = (() => {
    const lastDot = decoderArg.lastIndexOf(".");
    return [decoderArg.slice(0, lastDot), decoderArg.slice(lastDot + 1)];
})();

const moduleImport = \`import \${modulePath} exposing (\${decoderName})\`;

const elmSource = \`
port module DecodeRunner exposing (main)

import Json.Decode exposing (decodeValue, Value)
\${moduleImport}

port sendToJS : Value -> Cmd msg
port moduleInput : (Value -> msg) -> Sub msg

main =
    Platform.worker
        { init = \\_ -> ( (), Cmd.none )
        , update = \\json _ ->
            case decodeValue \${decoderName} json of
                Ok value ->
                    ( (), sendToJS (Json.Encode.string ("Success: " ++ Debug.toString value)) )

                Err err ->
                    ( (), sendToJS (Json.Encode.string ("Error: " ++ Debug.toString err)) )
        , subscriptions = \\_ -> moduleInput
        }
\`;

const elmFilePath = join(tmpdir(), "DecodeRunner.elm");
writeFileSync(elmFilePath, elmSource);

compileToString([elmFilePath], { output: "ignored.js" }).then(jsCode => {
    const Module = { exports: {} };
    eval(jsCode);
    const app = global.Elm.DecodeRunner.init();

    app.ports.sendToJS.subscribe(msg => {
        console.log(msg);
        process.exit(0);
    });

    let input = "";
    process.stdin.setEncoding("utf8");
    process.stdin.on("data", chunk => input += chunk);
    process.stdin.on("end", () => {
        try {
            const json = JSON.parse(input);
            app.ports.moduleInput.send(json);
        } catch (err) {
            console.error("Invalid JSON input");
            process.exit(1);
        }
    });

    process.stdin.resume();
}).catch(err => {
    console.error("Elm compilation failed:", err);
    process.exit(1);
});
