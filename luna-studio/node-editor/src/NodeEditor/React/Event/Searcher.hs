{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE TypeFamilies   #-}

module NodeEditor.React.Event.Searcher where

import           Data.Aeson          (FromJSON, ToJSON)
import           React.Flux          (KeyboardEvent)

import           Common.Prelude



data Event = InputChanged Text
           | Accept
           | AcceptInput
           | AcceptEntry Int
           | EditEntry
           | MoveDown
           | MoveUp
           | MoveLeft
           | KeyDown KeyboardEvent
           | KeyUp   KeyboardEvent
            deriving (Read, Show, Generic, NFData, Typeable)

instance ToJSON   Event
instance FromJSON Event