module Luna.Studio.Action.Basic.AddConnection where

import           Control.Monad                           (filterM)
import           Empire.API.Data.PortRef                 (AnyPortRef (InPortRef'), InPortRef, OutPortRef, dstNodeLoc, dstPortId)
import           Luna.Studio.Action.Basic.DrawConnection (createConnection)
import           Luna.Studio.Action.Basic.UpdateNode     (updatePortSelfVisibility)
import qualified Luna.Studio.Action.Batch                as Batch
import           Luna.Studio.Action.Command              (Command)
import qualified Luna.Studio.Action.State.NodeEditor     as NodeEditor
import           Luna.Prelude
import           Luna.Studio.React.Model.Connection      (ConnectionId)
import           Luna.Studio.React.Model.Node            (NodeLoc)
import           Luna.Studio.React.Model.Port            (InPortIndex (Self))
import           Luna.Studio.State.Global                (State)


connect :: Either OutPortRef NodeLoc -> Either InPortRef NodeLoc -> Command State ()
connect src'@(Left srcPortRef) (Left dstPortRef) =
    whenM (localAddConnection srcPortRef dstPortRef) $ Batch.addConnection src' (Left $ InPortRef' dstPortRef)
connect src' (Left dstPortRef) = Batch.addConnection src' (Left $ InPortRef' dstPortRef)
connect src' (Right nid)       = Batch.addConnection src' (Right nid)

localAddConnections :: [(OutPortRef, InPortRef)] -> Command State [ConnectionId]
localAddConnections = (fmap . map) snd . filterM (uncurry localAddConnection)

localAddConnection :: OutPortRef -> InPortRef -> Command State Bool
localAddConnection src' dst' = do
    mayConn <- createConnection src' dst'
    withJust mayConn $ \conn -> do
        NodeEditor.addConnection conn
        when ([Self] == dst' ^. dstPortId) . void . updatePortSelfVisibility $ dst' ^. dstNodeLoc
    return $ isJust mayConn