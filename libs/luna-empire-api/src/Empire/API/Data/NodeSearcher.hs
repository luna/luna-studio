module Empire.API.Data.NodeSearcher where

import           Data.Binary   (Binary)
import           Data.Map.Lazy as Map
import           Prologue      hiding (Item)

-- data LunaModule = LunaModule { _items :: Map Text Item }
--                   deriving (Show, Eq, Generic)

type ModuleItems = Map Text Item

-- type LunaModule = ModuleItems

data Item = Function
          | Module { _items :: ModuleItems }
          -- | Module { _itmod :: LunaModule }
          deriving (Show, Eq, Generic)

-- instance Binary LunaModule
instance Binary Item

-- makeLenses ''LunaModule
makeLenses ''Item
makePrisms ''Item

-- instance Default LunaModule where
--   def = LunaModule def
