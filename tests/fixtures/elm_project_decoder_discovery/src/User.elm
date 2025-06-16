module User exposing (..)

import Json.Decode exposing (Decoder, int, string, map3)


type alias User =
    { id : Int
    , name : String
    , email : String
    }


userDecoder : Decoder User
userDecoder =
    map3 User
        (Json.Decode.field "id" int)
        (Json.Decode.field "name" string)
        (Json.Decode.field "email" string)


adminDecoder : Json.Decode.Decoder User
adminDecoder =
    userDecoder


-- This is not a decoder, should be ignored
userToString : User -> String
userToString user =
    user.name ++ " (" ++ user.email ++ ")" 