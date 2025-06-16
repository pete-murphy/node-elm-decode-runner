module Order exposing (..)

import Json.Decode as J


type alias Order =
    { id : String
    , userId : Int
    , total : Float
    }


orderDecoder : J.Decoder Order
orderDecoder =
    J.map3 Order
        (J.field "id" J.string)
        (J.field "userId" J.int)
        (J.field "total" J.float)


-- This should also be detected even with different spacing
statusDecoder   :   J.Decoder   String
statusDecoder =
    J.field "status" J.string 