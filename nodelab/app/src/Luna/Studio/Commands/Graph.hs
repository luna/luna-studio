module Luna.Studio.Commands.Graph
    ( allNodes
    , allNodes'
    , focusNode
    , getNode
    , getPort
    , getConnection
    -- , updateConnection
    -- , updateConnections
    -- , updateConnectionsForNodes
    , updateNodeZOrder
    ) where


import           Control.Monad.Trans.Maybe          (runMaybeT)
import qualified Data.HashMap.Lazy                  as HashMap
import           Data.Ord                           (comparing)
import qualified Data.Set                           as Set
import           Luna.Studio.Data.Angle
import           Luna.Studio.Data.Vector            (Vector2 (Vector2), lengthSquared)
import           Luna.Studio.Prelude

import           Luna.Studio.React.Model.Node       (Node)
import qualified Luna.Studio.React.Model.Node       as Node
import qualified Luna.Studio.React.Model.NodeEditor as NodeEditor
import           Luna.Studio.React.Store            (Ref, WRef, ref, widget)
import qualified Luna.Studio.React.Store            as Store

import qualified Luna.Studio.React.Model.Node       as Model
import qualified Luna.Studio.React.Model.Port       as PortModel
import qualified Object.Widget.Connection           as ConnectionModel

import           Luna.Studio.Commands.Command       (Command)
import           Luna.Studio.Data.Color             (vtToColor)
import           Luna.Studio.State.Global           (State)
import qualified Luna.Studio.State.Global           as Global
import qualified Luna.Studio.State.Graph            as Graph

import           Empire.API.Data.Connection         (ConnectionId)
import qualified Empire.API.Data.Connection         as Connection
import           Empire.API.Data.Node               (NodeId)
import qualified Empire.API.Data.Node               as NodeAPI
import qualified Empire.API.Data.Port               as Port
import           Empire.API.Data.PortRef            (AnyPortRef (..), InPortRef (..))
import qualified Empire.API.Data.PortRef            as PortRef



allNodes :: Command State [Ref Node]
allNodes = Global.withNodeEditor $
    Store.use (NodeEditor.nodes . to HashMap.elems)

allNodes' :: Command State [WRef Node]
allNodes' = mapM Store.get' =<< allNodes

-- TODO[react]: Reconsider module Empire.API.Data.PortRef because it is impossible
--              to use this function if AnyPortRef is specified to InPortRef or OutPortRef
getPort :: AnyPortRef -> Command State (Maybe PortModel.Port)
getPort portRef = runMaybeT $ do
    Just node <- lift $ getNode $ portRef ^. PortRef.nodeId
    fromJustM $ node ^? Node.ports . ix portRef

getGraphPort :: AnyPortRef -> Command State (Maybe Port.Port)
getGraphPort portRef = preuse $ Global.graph . Graph.nodesMap . ix (portRef ^. PortRef.nodeId) . NodeAPI.ports . ix (portRef ^. PortRef.portId)

getNode :: NodeId -> Command State (Maybe Model.Node)
getNode nodeId = Global.withNode nodeId $ mapM Store.get

getConnection :: ConnectionId -> Command State (Maybe ConnectionModel.Connection)
getConnection connId = Global.withConnection connId $ mapM Store.get

nats :: [Integer]
nats = [1..]

focusNode :: Ref Node -> Command State ()
focusNode nodeRef = do
    node <- Store.get' nodeRef
    nodes <- mapM Store.get' =<< allNodes
    let sortedNodes = sortBy (comparing $ negate . (view $ widget . Model.zPos)) nodes
        equalFst a b = a ^. widget == b ^. widget
        newOrderNodes = node : deleteBy equalFst node sortedNodes
        newOrderRefs  = view ref <$> newOrderNodes
    forM_ (zip newOrderRefs nats) $ \(nRef, idx) -> do
        let newZPos = negate $ (fromIntegral idx) / 100.0
        Store.modify_ (Node.zPos .~ newZPos) nRef

updateNodeZOrder :: Command State ()
updateNodeZOrder = do
    nodes <- mapM Store.get' =<< allNodes
    let sortedNodes = sortBy (comparing $ negate . (view $ widget . Model.zPos)) nodes
        sortedRefs  = view ref <$> sortedNodes
    forM_ (zip sortedRefs nats) $ \(nRef, idx) -> do
        let newZPos = negate $ (fromIntegral idx) / 100.0
        Store.modify_ (Node.zPos .~ newZPos) nRef

-- TODO[react]: Find out if we need this
-- updateConnections :: Command Global.State ()
-- updateConnections = do
--     connectionIds <- uses (Global.graph . Graph.connectionsMap) HashMap.keys
--     mapM_ updateConnection connectionIds
--
-- updateConnectionsForNodes :: [NodeId] -> Command Global.State ()
-- updateConnectionsForNodes nodes = do
--     connections <- uses (Global.graph . Graph.connectionsMap) HashMap.toList
--     let nodes' = Set.fromList nodes
--         connectionsToUpdate = [wid | (wid, conn) <- connections, (    (conn ^. Connection.src . PortRef.srcNodeId) `Set.member` nodes'
--                                                                  || (conn ^. Connection.dst . PortRef.dstNodeId) `Set.member` nodes') ]
--     mapM_ updateConnection connectionsToUpdate
--
-- lineEndPos :: Position -> Position -> Double -> Maybe PortModel.Port -> Position
-- lineEndPos node1Pos node2Pos radius (Just port) = moveByAngle node1Pos radius portAngle' where
--     portAngle   = port ^. PortModel.angle
--     portCount   = port ^. PortModel.portCount
--     portAngle'  = boundedAngle portAngle portCount node1Pos node2Pos
-- lineEndPos node1Pos node2Pos radius Nothing = moveByAngle node1Pos radius portAngle where
--     portAngle = toAngle $ node2Pos - node1Pos
--
--
-- updateConnection :: ConnectionId -> Command Global.State () -- FIXME: run in MaybeT
-- updateConnection connectionId = do
--     Just connection    <- preuse $ Global.graph . Graph.connectionsMap       . ix connectionId -- fatal
--     Just connectionRef <- Global.getConnection connectionId -- fatal
--
--     Just srcNode       <- getNode $ connection ^. Connection.src . PortRef.srcNodeId           -- fatal
--     Just dstNode       <- getNode $ connection ^. Connection.dst . PortRef.dstNodeId           -- fatal
--
--     srcPort            <- getPort      $ OutPortRef' $ connection ^. Connection.src            -- non-fatal
--     dstPort            <- getPort      $ InPortRef'  $ connection ^. Connection.dst            -- non-fatal
--     let dstNodePos     = dstNode ^. widgetPosition
--         srcNodePos     = srcNode ^. widgetPosition
--         dstRadius      = portRadius $ connection ^. Connection.dst
--         posSrc         = lineEndPos srcNodePos dstNodePos normalPortRadius srcPort
--         posDst         = lineEndPos dstNodePos srcNodePos dstRadius        dstPort
--
--     srcGraphPort      <- getGraphPort $ OutPortRef' $ connection ^. Connection.src            -- non-fatal
--     let visible        = lengthSquared (dstNodePos - srcNodePos) > 100
--         fallbackColor  = 13
--         color          = fromMaybe fallbackColor $ vtToColor <$> (view Port.valueType) <$> srcGraphPort
--
--     flip Store.modifyM_ connectionRef $ do
--         ConnectionModel.from    .= posSrc
--         ConnectionModel.to      .= posDst
--         ConnectionModel.visible .= visible
--         ConnectionModel.color   .= color
--
-- moveByAngle :: Position -> Double -> Angle -> Position
-- moveByAngle (Position x y) radius angle = Position (x + radius * cos angle) (y + radius * sin angle)
--
-- normalPortRadius :: Double
-- normalPortRadius = 22.0
--
-- portRadius :: InPortRef -> Double
-- portRadius (InPortRef _ Port.Self) = 0.0
-- portRadius _ = normalPortRadius
