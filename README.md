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

```
echo '{"name":"Alice","age":30}' | elm-decode-runner Example.User.decoder
```

This tool makes it easy to test Elm decoders from the command line by:

1. Taking JSON input from stdin
2. Running it through the specified Elm decoder
3. Printing the result to stdout

### Requirements

- Must be run in an Elm project directory (with valid `elm.json`)
- The specified decoder must be found in the module path

### Arguments

`elm-decode-runner <Module.Path.decoderName>`

Where:

- `Module.Path` is the Elm module path (e.g., `Example.User`)
- `decoderName` is the name of the decoder function (e.g., `decoder`)

## Examples

### Success case

```bash
❯ curl -s https://jsonplaceholder.typicode.com/todos/1 | elm-decode-runner Example.Todo.decoder
{ completed = False, id = 1, title = "delectus aut autem", userId = 1 }
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
