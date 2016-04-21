module Empire.API.Graph.GetProgram where

import           Prologue
import           Data.Binary                   (Binary)
import           Data.Text.Lazy                (Text)

import           Empire.API.Data.GraphLocation (GraphLocation)
import           Empire.API.Data.Graph         (Graph)
import           Empire.API.Data.NodeSearcher  (ModuleItems)
import qualified Empire.API.Update           as Update

data Request = Request { _location :: GraphLocation
                       } deriving (Generic, Show, Eq)

data Status = Status { _graph            :: Graph
                     , _code             :: Text
                     , _nodeSearcherData :: ModuleItems
                     } deriving (Generic, Show, Eq)

type Update = Update.Update Request Status

makeLenses ''Request
makeLenses ''Status

instance Binary Request
instance Binary Status
