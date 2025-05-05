module Example.Product exposing (Product, decoder)

import Json.Decode exposing (Decoder, int, map2, string)


type alias Product =
    { id : Int
    , name : String
    }


decoder : Decoder Product
decoder =
    map2 Product
        (Json.Decode.field "id" int)
        (Json.Decode.field "name" string)
