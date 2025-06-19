module Decoders exposing
    ( Bar
    , Foo
    , barDecoder
    )

import Json.Decode exposing (Decoder, int, map2, map3, string)


type alias Foo =
    { name : String
    , age : Int
    }


type alias Bar =
    { name : String
    , age : Int
    , foo : Foo
    }


barDecoder : Decoder Bar
barDecoder =
    map3 Bar
        (Json.Decode.field "name" string)
        (Json.Decode.field "age" int)
        (Json.Decode.field "foo" fooDecoder)


fooDecoder : Decoder Foo
fooDecoder =
    map2 Foo
        (Json.Decode.field "name" string)
        (Json.Decode.field "age" int)
