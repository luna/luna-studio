{-# LANGUAGE OverloadedStrings #-}
module Luna.Studio.State.Graph where

import           Data.Aeson                 (FromJSON, ToJSON)
import           Data.HashMap.Strict        (HashMap)
import           Empire.API.Data.Connection (Connection, ConnectionId)
import           Empire.API.Data.Node       (Node, NodeId)
import           Luna.Studio.Prelude


type NodesMap       = HashMap NodeId Node
type ConnectionsMap = HashMap ConnectionId Connection

data Graph = Graph { _nodesMap             :: NodesMap
                   } deriving (Show, Eq, Generic)

makeLenses ''Graph

instance ToJSON Graph
instance FromJSON Graph
instance Default Graph where
    def = Graph def
