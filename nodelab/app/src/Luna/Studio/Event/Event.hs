{-# LANGUAGE DeriveAnyClass #-}
module Luna.Studio.Event.Event where

import           Data.Aeson                    (ToJSON)

import qualified Luna.Studio.Event.Batch       as Batch
import qualified Luna.Studio.Event.Connection  as Connection
import qualified Luna.Studio.Event.CustomEvent as CustomEvent
import qualified Luna.Studio.Event.Debug       as Debug
import           Luna.Studio.Event.Shortcut    (ShortcutEvent)
import           Luna.Studio.Event.UI          (UIEvent)
import           Luna.Studio.Prelude



data Event = Init
           | Batch                         Batch.Event
           | Connection               Connection.Event
           | CustomEvent             CustomEvent.Event
           | Debug                         Debug.Event
           | Tick
           | Shortcut                    ShortcutEvent
           | UI                                UIEvent
           deriving (Generic, Show, NFData)

makeLenses ''Event

instance Default Event where
    def = Init

instance ToJSON Event

name :: Contravariant f => (String -> f String) -> Event -> f Event
name = to $ head . words . show
