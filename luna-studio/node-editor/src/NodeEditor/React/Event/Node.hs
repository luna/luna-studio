{-# LANGUAGE DeriveAnyClass #-}
module NodeEditor.React.Event.Node where

import           Data.Aeson                  (FromJSON, ToJSON)
import           Empire.API.Data.NodeLoc     (NodeLoc)
import           Empire.API.Data.PortDefault (PortDefault)
import           Empire.API.Data.PortRef     (InPortRef)
import           Common.Prelude
import           NodeEditor.State.Action    (InitValue)
import           React.Flux                  (KeyboardEvent, MouseEvent)


data Event = DisplayResultChanged Bool          NodeLoc
           | EditExpression                     NodeLoc
           | Enter                              NodeLoc
           | MouseDown            MouseEvent    NodeLoc
           | NameEditApply                      NodeLoc Text
           | NameEditDiscard                    NodeLoc
           | NameEditStart                      NodeLoc
           | PortApplyString      KeyboardEvent InPortRef PortDefault
           | PortEditString                     InPortRef PortDefault
           | PortInitSlider          MouseEvent InPortRef InitValue
           | PortSetPortDefault                 InPortRef PortDefault
           | Select               MouseEvent    NodeLoc
           | SetCode                            NodeLoc Text
            deriving (Show, Generic, NFData, Typeable)

instance ToJSON   Event
instance FromJSON Event