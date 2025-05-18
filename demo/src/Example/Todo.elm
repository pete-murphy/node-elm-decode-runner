module Example.Todo exposing
    ( Todo
    , decoder
    )

import Json.Decode
import Json.Decode.Pipeline


type alias Todo =
    { userId : Int
    , id : Int
    , title : String
    , completed : Bool
    }


decoder : Json.Decode.Decoder Todo
decoder =
    Json.Decode.succeed Todo
        |> Json.Decode.Pipeline.required "userId" Json.Decode.int
        |> Json.Decode.Pipeline.required "id" Json.Decode.int
        |> Json.Decode.Pipeline.required "title" Json.Decode.string
        |> Json.Decode.Pipeline.required "completed" Json.Decode.bool
