module Node.Editor.React.Model.DataFrame where

import           Luna.Prelude
import           Data.Aeson (ToJSON)

data DataFrame = DataFrame { _headers   :: [Text]
                           , _rows      :: [[Text]]
                           } deriving (Eq, Show, Typeable, Generic)


makeLenses ''DataFrame
instance ToJSON DataFrame

create :: [Text] -> [[Text]] -> DataFrame
create = DataFrame