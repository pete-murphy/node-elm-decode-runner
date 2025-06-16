module Product exposing (..)

import Json.Decode as Decode


type alias Product =
    { id : Int
    , name : String
    , price : Float
    }


productDecoder : Decode.Decoder Product
productDecoder =
    Decode.map3 Product
        (Decode.field "id" Decode.int)
        (Decode.field "name" Decode.string)
        (Decode.field "price" Decode.float)


listDecoder : Decode.Decoder (List Product)
listDecoder =
    Decode.list productDecoder 