module Utils.Helpers exposing (..)

import Json.Decode exposing (Decoder)


type alias Config =
    { apiUrl : String
    , timeout : Int
    }


configDecoder : Decoder Config
configDecoder =
    Json.Decode.map2 Config
        (Json.Decode.field "apiUrl" Json.Decode.string)
        (Json.Decode.field "timeout" Json.Decode.int)


-- Another decoder with full qualification
settingsDecoder : Json.Decode.Decoder Config
settingsDecoder =
    configDecoder 