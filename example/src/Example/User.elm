module Example.User exposing (User, decoder)

import Json.Decode exposing (Decoder, int, map2, string)


type alias User =
    { name : String
    , age : Int
    }


decoder : Decoder User
decoder =
    map2 User
        (Json.Decode.field "name" string)
        (Json.Decode.field "age" int)
