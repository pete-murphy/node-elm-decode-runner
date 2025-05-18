module Decoders exposing
    ( Foo
    , fooDecoder
    )

import Json.Decode exposing (Decoder, int, map2, string)


type alias Foo =
    { name : String
    , age : Int
    }


fooDecoder : Decoder Foo
fooDecoder =
    map2 Foo
        (Json.Decode.field "name" string)
        (Json.Decode.field "age" int)
