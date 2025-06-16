module Mixed exposing (..)

import Json.Decode as Decode
import Json.Encode as Encode


type alias Item =
    { name : String
    , count : Int
    }



-- This should be detected


itemDecoder : Decode.Decoder Item
itemDecoder =
    Decode.map2 Item
        (Decode.field "name" Decode.string)
        (Decode.field "count" Decode.int)



-- This should NOT be detected (encoder, not decoder)


itemEncoder : Item -> Encode.Value
itemEncoder item =
    Encode.object
        [ ( "name", Encode.string item.name )
        , ( "count", Encode.int item.count )
        ]



-- This should NOT be detected (function returning decoder)


customDecoder : String -> Decode.Decoder String
customDecoder fieldName =
    Decode.field fieldName Decode.string



-- This should be detected


nameDecoder : Decode.Decoder String
nameDecoder =
    Decode.field "name" Decode.string



-- This should NOT be detected (not a decoder type)


itemToString : Item -> String
itemToString item =
    item.name ++ ": " ++ String.fromInt item.count
