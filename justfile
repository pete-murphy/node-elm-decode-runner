set quiet

default:
    just --list

[working-directory: 'example']
run-example:
    echo '{"name":"Alice","age":30}' | node ../cli.js Example.User.decoder

    
