{-# LANGUAGE DeriveAnyClass #-}
module Luna.Atom.Event.Text where

import           Data.Aeson          (FromJSON, ToJSON)
import           Luna.Prelude



data TextEvent = TextEvent
               { _filePath  :: FilePath
               , _start     :: Int
               , _stop      :: Int
               , _text      :: Text
               , _cursor    :: Maybe Int
               } deriving (Generic, NFData, Show, Typeable)

makeLenses ''TextEvent

instance ToJSON   TextEvent
instance FromJSON TextEvent