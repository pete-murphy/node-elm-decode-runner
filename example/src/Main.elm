module Main exposing (main)

import Browser
import Example.Product
import Example.User
import Html
import Json.Decode


main : Program () () msg
main =
    Browser.sandbox
        { init = ()
        , update = \_ _ -> ()
        , view = \_ -> Html.text "Hello, World!"
        }
