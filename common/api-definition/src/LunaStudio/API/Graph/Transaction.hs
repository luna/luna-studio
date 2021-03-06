module LunaStudio.API.Graph.Transaction where

import           Data.Aeson.Types              (ToJSON)
import           Data.Binary                   (Binary)
import           Data.ByteString.Lazy          (ByteString)
import qualified LunaStudio.API.Graph.Request  as G
import qualified LunaStudio.API.Request        as R
import qualified LunaStudio.API.Topic          as T
import           LunaStudio.Data.Diff          (Diff)
import           LunaStudio.Data.GraphLocation (GraphLocation)
import           LunaStudio.Data.PortDefault   (PortDefault)
import           LunaStudio.Data.PortRef       (InPortRef)
import           Prologue


data Request = Request
    { _location     :: GraphLocation
    , _actions      :: [(T.Topic, ByteString)]
    } deriving (Eq, Generic, Show)

makeLenses ''Request

instance Binary Request
instance NFData Request
-- instance ToJSON Request
instance G.GraphRequest Request where location = location


instance T.MessageTopic Request where
    topic = "empire.graph.node.transaction"
