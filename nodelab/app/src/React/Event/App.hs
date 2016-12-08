{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE TypeFamilies   #-}

module React.Event.App where

import           Control.DeepSeq   (NFData)
import           Data.Aeson        (FromJSON, ToJSON)
import           React.Flux        (KeyboardEvent, MouseEvent)

import           Utils.PreludePlus



data Event = MouseDown  MouseEvent
           | MouseMove  MouseEvent
           | MouseUp    MouseEvent
           | KeyDown    KeyboardEvent
            deriving (Show, Generic, NFData, Typeable)

instance ToJSON   Event
instance FromJSON Event
