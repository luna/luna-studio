module LunaStudio.API.Graph.SetCode where

import           Data.Aeson.Types              (ToJSON)
import           Data.Binary                   (Binary)
import qualified LunaStudio.API.Graph.Request  as G
import qualified LunaStudio.API.Request        as R
import qualified LunaStudio.API.Response       as Response
import qualified LunaStudio.API.Topic          as T
import           LunaStudio.Data.Diff          (Diff)
import           LunaStudio.Data.GraphLocation (GraphLocation)
import           LunaStudio.Data.NodeCache     (NodeCache)
import           Prologue


data Request = Request
    { _location :: GraphLocation
    , _code     :: Text
    , _cache    :: NodeCache
    } deriving (Generic, Show)

data Inverse = Inverse
    { _prevCode  :: Text
    , _prevCache :: NodeCache
    } deriving (Generic, Show)

makeLenses ''Request
makeLenses ''Inverse

instance Binary Request
instance NFData Request
instance ToJSON Request
instance Binary Inverse
instance NFData Inverse
instance ToJSON Inverse
instance G.GraphRequest Request where location = location


type Response = Response.Response Request Inverse Diff
type instance Response.InverseOf Request = Inverse
type instance Response.ResultOf  Request = Diff

instance T.MessageTopic Request where
    topic = "empire.graph.node.setCode"
