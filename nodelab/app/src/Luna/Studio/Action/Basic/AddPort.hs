module Luna.Studio.Action.Basic.AddPort where

import           Control.Arrow
import qualified Data.Map.Lazy                          as Map
import           Empire.API.Data.Connection             (Connection (Connection), src)
import           Empire.API.Data.Node                   (ports)
import           Empire.API.Data.Port                   (OutPort (Projection), Port (Port), PortId (OutPortId), PortState (NotConnected),
                                                         portId)
import           Empire.API.Data.PortRef                (AnyPortRef (OutPortRef'), OutPortRef (OutPortRef), srcPortId)
import           Empire.API.Data.TypeRep                (TypeRep (TStar))
import           Luna.Studio.Action.Basic.AddConnection (localAddConnection)
import           Luna.Studio.Action.Basic.UpdateNode    (localUpdateNode)
import qualified Luna.Studio.Action.Batch               as Batch
import           Luna.Studio.Action.Command             (Command)
import           Luna.Studio.Action.State.Graph         (getConnectionsContainingNode)
import qualified Luna.Studio.Action.State.Graph         as Graph
import           Luna.Studio.Action.State.NodeEditor    (getNode)
import           Luna.Studio.Prelude
import           Luna.Studio.React.Model.Node           (countProjectionPorts, getPorts, isInputEdge)
import           Luna.Studio.React.Model.Port           (port)
import           Luna.Studio.State.Global               (State)


addPort :: AnyPortRef -> Command State ()
addPort portRef = whenM (localAddPort portRef) $ Batch.addPort portRef

localAddPort :: AnyPortRef -> Command State Bool
localAddPort (OutPortRef' (OutPortRef nid pid@(Projection pos))) = do
    mayNode      <- getNode nid
    mayGraphNode <- Graph.getNode nid
    flip (maybe (return False)) ((,) <$> mayNode <*> mayGraphNode) $ \(node, graphNode) ->
        if     (not . isInputEdge $ node)
            || pos > countProjectionPorts node
            || pos < 0
            then return False
            else do
                let newPort     = Port (OutPortId pid) "" TStar NotConnected
                    oldPorts    = map (view port) $ getPorts node
                    newPorts'   = flip map oldPorts $ \port' -> case port' ^. portId of
                        OutPortId (Projection i) ->
                            if i < pos
                                then port'
                                else port' & portId .~ (OutPortId $ Projection (i+1))
                        _                        -> port'
                    newPorts    = newPort : newPorts'
                    newPortsMap = Map.fromList $ map (view portId &&& id) newPorts
                void . localUpdateNode $ graphNode & ports .~ newPortsMap
                conns <- getConnectionsContainingNode nid
                forM_ conns $ \conn -> case conn of
                    Connection (OutPortRef srcNid (Projection i)) _ ->
                        when (srcNid == nid && i >= pos) $
                            void . localAddConnection $ conn & src . srcPortId .~ Projection (i+1)
                    _ -> return ()
                return True
localAddPort _ = $notImplemented
