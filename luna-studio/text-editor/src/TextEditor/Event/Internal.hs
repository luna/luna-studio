{-# LANGUAGE DeriveAnyClass #-}
module TextEditor.Event.Internal where

import           Data.Aeson          (FromJSON, ToJSON)
import           Common.Prelude


data ActionType = CloseFile
                  | IsSaved
                  | OpenFile
                  | SaveFile
                  | SetProject
                  | GetBuffer
                  deriving (Bounded, Eq, Enum, Generic, NFData, Read, Show, Typeable)

data InternalEvent = InternalEvent
                   { _dataType  :: ActionType
                   , _path      :: String
                   } deriving (Generic, NFData, Show, Typeable)

makeLenses ''InternalEvent

instance ToJSON   ActionType
instance FromJSON ActionType
instance ToJSON   InternalEvent
instance FromJSON InternalEvent