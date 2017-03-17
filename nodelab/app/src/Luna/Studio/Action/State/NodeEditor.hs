{-# LANGUAGE DataKinds      #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE LambdaCase     #-}
module Luna.Studio.Action.State.NodeEditor where

import qualified Control.Monad.State                as M
import           Control.Monad.Trans.Maybe          (runMaybeT)
import qualified Data.HashMap.Strict                as HashMap
import qualified Data.Map.Lazy                      as Map
import qualified Data.Set                           as Set

import           Empire.API.Data.MonadPath          (MonadPath)
import qualified Empire.API.Data.Node               as Node
import           Empire.API.Data.Port               (OutPort (All), _WithDefault)
import           Empire.API.Data.PortDefault        (PortDefault)
import           Empire.API.Data.PortRef            (AnyPortRef (InPortRef', OutPortRef'), InPortRef, OutPortRef (OutPortRef))
import qualified Empire.API.Data.PortRef            as PortRef
import           Luna.Studio.Action.Command         (Command)
import           Luna.Studio.Action.State.App       (get, modify)
import           Luna.Studio.Batch.Workspace        (nodeSearcherData)
import           Luna.Studio.Prelude
import           Luna.Studio.React.Model.App        (nodeEditor)
import           Luna.Studio.React.Model.Connection (Connection, ConnectionId, ConnectionsMap, CurrentConnection, connectionId,
                                                     containsNode, containsPortRef, dstNodeId, srcNodeId, toConnectionsMap)
import           Luna.Studio.React.Model.Node       (Node, NodeId, NodesMap, isEdge, isSelected, nodeId, ports, toNodesMap)
import           Luna.Studio.React.Model.NodeEditor
import           Luna.Studio.React.Model.Port       (Port, state, valueType)
import           Luna.Studio.React.Model.Searcher   (Searcher)
import           Luna.Studio.State.Global           (State, workspace)
import           Text.ScopeSearcher.Item            (Items, isElement, items)


getNodeEditor :: Command State NodeEditor
getNodeEditor = get nodeEditor

modifyNodeEditor :: M.State NodeEditor r -> Command State r
modifyNodeEditor = modify nodeEditor

resetGraph :: Command State ()
resetGraph = modifyNodeEditor $ do
    nodes               .= def
    monads              .= def
    connections         .= def
    portDragConnections .= def
    connectionPen       .= def
    selectionBox        .= def
    searcher            .= def
    visualizations      .= def
    draggedPort         .= def

-- TODO[LJK]: Make this work
-- separateSubgraph :: [NodeId] -> Command State Graph
-- separateSubgraph nodeIds = do
--     let idSet = Set.fromList nodeIds
--         inSet = flip Set.member idSet
--     nodes <- Map.filterWithKey (inSet .: const)  <$> getNodesMap
--     conns <- Map.filter (inSet . view dstNodeId) <$> getConnectionsMap
--     return $ Graph nodes conns


addNode :: Node -> Command State ()
addNode node = modifyNodeEditor $ nodes . at (node ^. nodeId) ?= node

getAllNodes :: Command State [Node]
getAllNodes = HashMap.elems <$> getNodesMap

getEdgeNodes :: Command State [Node]
getEdgeNodes = filter isEdge <$> getAllNodes

getNode :: NodeId -> Command State (Maybe Node)
getNode nid = view (nodes . at nid) <$> getNodeEditor

getNodes :: Command State [Node]
getNodes = filter (not . isEdge) <$> getAllNodes

getNodesMap :: Command State NodesMap
getNodesMap = view nodes <$> getNodeEditor

modifyNode :: Monoid r => NodeId -> M.State Node r -> Command State r
modifyNode nid = modify (nodeEditor . nodes . at nid) . zoom traverse

removeNode :: NodeId -> Command State ()
removeNode nid = modifyNodeEditor $ nodes . at nid .= Nothing

getSelectedNodes :: Command State [Node]
getSelectedNodes = filter (view isSelected) <$> getNodes

updateNodes :: [Node] -> Command State ()
updateNodes update = modifyNodeEditor $ nodes .= toNodesMap update


addConnection :: Connection -> Command State ()
addConnection conn = modifyNodeEditor $ connections . at connId ?= conn where
    connId = conn ^. connectionId

getConnection :: ConnectionId -> Command State (Maybe Connection)
getConnection connId = HashMap.lookup connId <$> getConnectionsMap

getConnections :: Command State [Connection]
getConnections = HashMap.elems <$> getConnectionsMap

getConnectionsMap :: Command State ConnectionsMap
getConnectionsMap = view connections <$> getNodeEditor

getConnectionsBetweenNodes :: NodeId -> NodeId -> Command State [Connection]
getConnectionsBetweenNodes nid1 nid2 =
    filter (\conn -> containsNode nid1 conn && containsNode nid2 conn) <$> getConnections

getConnectionsContainingNode :: NodeId -> Command State [Connection]
getConnectionsContainingNode nid = filter (containsNode nid) <$> getConnections

getConnectionsContainingNodes :: [NodeId] -> Command State [Connection]
getConnectionsContainingNodes nodeIds = filter containsNode' <$> getConnections where
    nodeIdsSet         = Set.fromList nodeIds
    containsNode' conn = Set.member (conn ^. srcNodeId) nodeIdsSet
                      || Set.member (conn ^. dstNodeId) nodeIdsSet

getConnectionsContainingPortRef :: AnyPortRef -> Command State [Connection]
getConnectionsContainingPortRef portRef = filter (containsPortRef portRef) <$> getConnections

getConnectionsToNode :: NodeId -> Command State [Connection]
getConnectionsToNode nid = filter (\conn -> conn ^. dstNodeId == nid) <$> getConnections

modifyConnection :: Monoid r => ConnectionId -> M.State Connection r -> Command State r
modifyConnection connId = modify (nodeEditor . connections . at connId) . zoom traverse

removeConnection :: ConnectionId -> Command State ()
removeConnection connId = modifyNodeEditor $ connections . at connId .= Nothing

updateConnections :: [Connection] -> Command State ()
updateConnections update = modifyNodeEditor $ connections .= toConnectionsMap update


getMonads :: Command State [MonadPath]
getMonads = view monads <$> getNodeEditor

updateMonads :: [MonadPath] -> Command State ()
updateMonads update = modifyNodeEditor $ monads .= update


modifyCurrentConnections :: M.State [CurrentConnection] r -> Command State r
modifyCurrentConnections = modify (nodeEditor . currentConnections)


getSearcher :: Command State (Maybe Searcher)
getSearcher = view searcher <$> getNodeEditor

modifySearcher :: Monoid r => M.State Searcher r -> Command State r
modifySearcher = modify (nodeEditor . searcher) . zoom traverse

globalFunctions :: Items a -> Items a
globalFunctions = Map.filter isElement

getNodeSearcherData :: Command State (Items Node.Node)
getNodeSearcherData = do
    completeData <- use $ workspace . nodeSearcherData
    selected     <- getSelectedNodes
    mscope       <- case selected of
        [node] -> (fmap . fmap) (convert . view valueType) $ getPort (OutPortRef (node ^. nodeId) All)
        _      -> return Nothing
    return $ case mscope of
        Nothing -> completeData
        Just tn -> Map.union (globalFunctions scope) (globalFunctions completeData) where
            scope = fromMaybe mempty $ completeData ^? ix tn . items

class GraphElementId a where
    inGraph :: a -> Command State Bool
instance GraphElementId NodeId where
    inGraph = fmap isJust . getNode
instance GraphElementId ConnectionId where
    inGraph = fmap isJust . getConnection

class HasPort a where
    getPort :: a -> Command State (Maybe Port)
instance HasPort InPortRef where
    getPort portRef = getPortFromAnyPortRef $ InPortRef' portRef
instance HasPort OutPortRef where
    getPort portRef = getPortFromAnyPortRef $ OutPortRef' portRef
instance HasPort AnyPortRef where
    getPort = getPortFromAnyPortRef

modifyPort :: Monoid r => AnyPortRef -> M.State Port r -> Command State r
modifyPort portRef = modify (nodeEditor . nodes . at nid . traverse . ports . at pid) . zoom traverse where
    nid = portRef ^. PortRef.nodeId
    pid = portRef ^. PortRef.portId

getPortFromAnyPortRef :: AnyPortRef -> Command State (Maybe Port)
getPortFromAnyPortRef portRef = runMaybeT $ do
    Just node <- lift $ getNode $ portRef ^. PortRef.nodeId
    fromJustM $ node ^? ports . ix (portRef ^. PortRef.portId)

getPortDefault :: AnyPortRef -> Command State (Maybe PortDefault)
getPortDefault portRef = maybe Nothing (\mayPort -> mayPort ^? state . _WithDefault) <$> getPort portRef
