# elm-decode-runner

CLI tool to run an Elm decoder on JSON input from stdin.

## Installation

### Using npm

```
npm install -g elm-decode-runner
```

### Using Nix

You can run `elm-decode-runner` directly from GitHub without installing:

```bash
echo '{"name":"Alice","age":30}' | nix run github:pete-murphy/node-elm-decode-runner -- Example.User.decoder
```

## Usage

### Direct Decoder Usage

```bash
echo '{"name":"Alice","age":30}' | elm-decode-runner Example.User.decoder
```

### Discover Available Decoders

```bash
elm-decode-runner --discover
```

### Interactive Decoder Selection (with fzf)

```bash
echo '{"name":"Alice","age":30}' | elm-decode-runner --discover
```

This will:

1. Parse and validate your JSON input
2. Discover all available decoders in your project
3. Launch `fzf` to let you interactively select a decoder
4. Run the selected decoder on your JSON input

This tool makes it easy to test Elm decoders from the command line by:

1. Taking JSON input from stdin
2. Running it through the specified Elm decoder
3. Printing the result to stdout

### Requirements

- Must be run in an Elm project directory (with valid `elm.json`)
- The specified decoder must be found in the module path
- For interactive mode: `fzf` must be installed (optional)

### Arguments

- `elm-decode-runner <Module.Path.decoderName>` - Run a specific decoder
- `elm-decode-runner --discover` - List all available decoders
- `echo '{}' | elm-decode-runner --discover` - Interactive decoder selection

Where:

- `Module.Path` is the Elm module path (e.g., `Example.User`)
- `decoderName` is the name of the decoder function (e.g., `decoder`)

## Examples

### Success case

```bash
❯ curl -s https://jsonplaceholder.typicode.com/todos/1 | elm-decode-runner Example.Todo.decoder
{ completed = False, id = 1, title = "delectus aut autem", userId = 1 }
```

### Discovery example

```bash
❯ elm-decode-runner --discover
Example.Todo.decoder
Example.User.userDecoder
Example.User.adminDecoder
Utils.Config.settingsDecoder
```

### Interactive example

```bash
❯ echo '{"id":1,"name":"Alice"}' | elm-decode-runner --discover
# Opens fzf with list of decoders, after selection:
{ id = 1, name = "Alice" }
```

### Failure case

```bash
❯ echo '{"name":"Alice","age":30}' | elm-decode-runner Example.User.decoder
Problem with the given value:

{
        "name": "Alice",
        "age": 30
    }

Expecting an OBJECT with a field named `email`
```

## License

ISC
