module LunaStudio.API.Atom.SaveFile where

import Prologue

import qualified LunaStudio.API.Request  as R
import qualified LunaStudio.API.Response as Response
import qualified LunaStudio.API.Topic    as T

import Data.Aeson.Types        (ToJSON)
import Data.Binary             (Binary)
import Data.Path               (File, Path, Rel)


data Request = Request
    { _filePath :: Path Rel File }
    deriving (Eq, Generic, Show)

makeLenses ''Request

instance Binary Request
instance NFData Request
instance ToJSON Request


type Response = Response.SimpleResponse Request ()
type instance Response.InverseOf Request = ()
type instance Response.ResultOf  Request = ()

instance T.MessageTopic Request where
    topic = "empire.atom.file.save"
