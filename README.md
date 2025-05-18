# elm-decode-cli

CLI tool to run an Elm decoder on JSON input from stdin.

## Installation

```
npm install -g elm-decode-cli
```

## Usage

```
echo '{"name":"Alice","age":30}' | elm-decode Example.User.decoder
```

This tool makes it easy to test Elm decoders from the command line by:

1. Taking JSON input from stdin
2. Running it through the specified Elm decoder
3. Printing the result to stdout

### Requirements

- Must be run in an Elm project directory (with valid `elm.json`)
- The specified decoder must be found in the module path

### Arguments

`elm-decode <Module.Path.decoderName>`

Where:

- `Module.Path` is the Elm module path (e.g., `Example.User`)
- `decoderName` is the name of the decoder function (e.g., `decoder`)

## Examples

```bash
# Using a specific decoder
echo '{"name":"Alice","age":30}' | elm-decode Example.User.decoder

# Piping from a file
cat data.json | elm-decode Example.Product.decoder
```

## License

ISC
