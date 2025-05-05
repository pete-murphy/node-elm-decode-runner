set quiet

default:
    just --list

[working-directory: 'example']
run-example:
    echo '{"name":"Alice","age":30}' | npx elm-decode Example.User.decoder

[working-directory: 'example']
run-example-no-export:
    echo '{"id":1,"name":"foo"}' | npx elm-decode Example.Product.decoder
    
