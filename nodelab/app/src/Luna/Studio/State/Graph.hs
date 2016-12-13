{-# LANGUAGE OverloadedStrings #-}

module Luna.Studio.State.Graph
    ( State(..)
    , addConnection
    , addNode
    , connectionIdsContainingNode
    , connections
    , connectionsContainingNode
    , connectionsMap
    , connectionsToNodes
    , connectionsToNodesIds
    , getConnectionNodeIds
    , getConnections
    , getConnectionsMap
    , getNodes
    , getNodesMap
    , hasConnections
    , lookUpConnection
    , nodes
    , nodesMap
    , removeConnections
    , removeNode
    , updateNodes
    ) where

import           Luna.Studio.Prelude          hiding ((.=))

import           Data.Hashable              (Hashable)
import           Data.HashMap.Strict        (HashMap)
import qualified Data.HashMap.Strict        as HashMap
import qualified Data.Map.Strict            as Map
import qualified Data.Set                   as Set
import           Data.UUID.Types            (UUID)

import           Data.Aeson                 hiding ((.:))
import           Empire.API.Data.Connection (Connection (..), ConnectionId)
import qualified Empire.API.Data.Connection as Connection
import           Empire.API.Data.Node       (Node, NodeId)
import qualified Empire.API.Data.Node       as Node
import           Empire.API.Data.Port       (InPort, OutPort)
import           Empire.API.Data.PortRef    (AnyPortRef, InPortRef, OutPortRef)
import qualified Empire.API.Data.PortRef    as PortRef
import qualified Empire.API.JSONInstances   ()
import           Luna.Studio.Commands.Command  (Command)


type NodesMap       = HashMap NodeId Node
type ConnectionsMap = HashMap InPortRef Connection


instance (ToJSON b) => ToJSON (HashMap UUID b) where
    toJSON = toJSON . Map.fromList . HashMap.toList
    {-# INLINE toJSON #-}

instance (ToJSON b) => ToJSON  (HashMap AnyPortRef b) where
    toJSON = toJSON . Map.fromList . HashMap.toList
    {-# INLINE toJSON #-}

instance (ToJSON b) => ToJSON  (HashMap InPortRef b) where
    toJSON = toJSON . Map.fromList . HashMap.toList
    {-# INLINE toJSON #-}

instance Default (HashMap a b) where def = HashMap.empty
instance Hashable InPort
instance Hashable OutPort
instance Hashable InPortRef
instance Hashable OutPortRef
instance Hashable AnyPortRef

data State = State { _nodesMap             :: NodesMap
                   , _connectionsMap       :: ConnectionsMap
                   } deriving (Show, Eq, Generic)

makeLenses ''State

instance ToJSON State
instance Default State where
    def = State def def

connectionToNodeIds :: Connection -> (NodeId, NodeId)
connectionToNodeIds conn = ( conn ^. Connection.src . PortRef.srcNodeId
                           , conn ^. Connection.dst . PortRef.dstNodeId)

nodes :: Getter State [Node]
nodes = to getNodes

connections :: Getter State [Connection]
connections = to getConnections

getNodes :: State -> [Node]
getNodes = HashMap.elems . getNodesMap

getNodesMap :: State -> NodesMap
getNodesMap = view nodesMap

getConnections :: State -> [Connection]
getConnections = HashMap.elems . getConnectionsMap

getConnectionsMap :: State -> ConnectionsMap
getConnectionsMap = view connectionsMap

getConnectionNodeIds :: ConnectionId -> State -> Maybe (NodeId, NodeId)
getConnectionNodeIds connId state = connectionToNodeIds <$> conn
    where conn = lookUpConnection state connId

updateNodes :: NodesMap -> State -> State
updateNodes newNodesMap state = state & nodesMap .~ newNodesMap

addNode :: Node -> State -> State
addNode newNode state  = state & nodesMap . at (newNode ^. Node.nodeId) ?~ newNode

removeNode :: NodeId -> State -> State
removeNode remNodeId state = state & nodesMap . at remNodeId .~ Nothing

addConnection :: OutPortRef -> InPortRef -> Command State ConnectionId
addConnection sourcePortRef destPortRef = do
    connectionsMap . at destPortRef ?= Connection sourcePortRef destPortRef
    return destPortRef

removeConnections :: [ConnectionId] -> State -> State
removeConnections connIds state = foldr removeConnection state connIds

removeConnection :: ConnectionId -> State -> State
removeConnection connId state = state & connectionsMap . at connId .~ Nothing

lookUpConnection :: State -> ConnectionId -> Maybe Connection
lookUpConnection state connId = HashMap.lookup connId $ getConnectionsMap state

containsNode :: NodeId -> Connection -> Bool
containsNode nid conn = startsWithNode nid conn
                    || endsWithNode   nid conn

startsWithNode :: NodeId -> Connection -> Bool
startsWithNode nid conn = conn ^. Connection.src . PortRef.srcNodeId == nid

endsWithNode :: NodeId -> Connection -> Bool
endsWithNode nid conn = conn ^. Connection.dst . PortRef.dstNodeId == nid

connectionsContainingNode :: NodeId -> State -> [Connection]
connectionsContainingNode nid state = filter (containsNode nid) $ getConnections state

connectionsToNodes :: Set.Set NodeId -> State -> [Connection]
connectionsToNodes nodeIds state = filter ((flip Set.member nodeIds) . (view $ Connection.dst . PortRef.dstNodeId)) $ getConnections state

connectionIdsContainingNode :: NodeId -> State -> [ConnectionId]
connectionIdsContainingNode nid state = view Connection.connectionId <$> connectionsContainingNode nid state

connectionsToNodesIds :: Set.Set NodeId -> State -> [ConnectionId]
connectionsToNodesIds nodeIds state = view Connection.connectionId <$> connectionsToNodes nodeIds state

hasConnections :: NodeId -> State -> Bool
hasConnections = (not . null) .: connectionsContainingNode
