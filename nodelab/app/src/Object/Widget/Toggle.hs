module Object.Widget.Toggle where

import           Utils.PreludePlus
import           Utils.Vector
import           Object.Widget


data Toggle = Toggle { _position :: Vector2 Double
                     , _size     :: Vector2 Double
                     , _label    :: Text
                     , _value    :: Bool
                     } deriving (Eq, Show, Typeable)

makeLenses ''Toggle

instance IsDisplayObject Toggle where
    widgetPosition = position

