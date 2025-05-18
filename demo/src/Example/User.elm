module Example.User exposing (..)

import Json.Decode
import Json.Decode.Pipeline


type alias User =
    { id : Int
    , name : String
    , email : String
    }


decoder : Json.Decode.Decoder User
decoder =
    Json.Decode.succeed User
        |> Json.Decode.Pipeline.required "id" Json.Decode.int
        |> Json.Decode.Pipeline.required "name" Json.Decode.string
        |> Json.Decode.Pipeline.required "email" Json.Decode.string
