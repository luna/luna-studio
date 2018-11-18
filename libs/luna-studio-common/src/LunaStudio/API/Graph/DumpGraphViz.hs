module LunaStudio.API.Graph.DumpGraphViz where

import           Data.Aeson.Types              (ToJSON)
import           Data.Binary                   (Binary)
import qualified LunaStudio.API.Graph.Request  as G
import qualified LunaStudio.API.Request        as R
import qualified LunaStudio.API.Response       as Response
import qualified LunaStudio.API.Topic          as T
import           LunaStudio.Data.GraphLocation (GraphLocation)
import           Prologue


data Request = Request
    { _location :: GraphLocation
    } deriving (Eq, Generic, Show)

makeLenses ''Request

instance Binary Request
instance NFData Request
instance ToJSON Request
instance G.GraphRequest Request where location = location


type Response = Response.SimpleResponse Request ()
type instance Response.InverseOf Request = ()
type instance Response.ResultOf  Request = ()

instance T.MessageTopic Request where
    topic = "empire.environment.debug.graphviz"
