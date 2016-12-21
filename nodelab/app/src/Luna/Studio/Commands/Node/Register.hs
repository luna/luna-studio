module Luna.Studio.Commands.Node.Register
    ( registerNode
    ) where

import           Luna.Studio.Data.Vector              (Vector2, toTuple)
import           Luna.Studio.Prelude

import qualified Empire.API.Data.NodeMeta             as NodeMeta
import qualified JS.GoogleAnalytics                   as GA
import qualified Luna.Studio.Commands.Batch           as BatchCmd
import           Luna.Studio.Commands.Command         (Command)
import           Luna.Studio.Commands.Graph.Selection (selectedNodes)
import           Luna.Studio.Commands.Node.Snap
import           Luna.Studio.React.Store              (widget)
import           Luna.Studio.State.Global             (State)
import qualified Object.Widget.Node                   as UINode



registerNode :: Vector2 Double -> Text -> Command State ()
registerNode nodePos expr = do
    let nodePosSnapped = snap nodePos
        nodeMeta = def & NodeMeta.position .~ toTuple nodePosSnapped
    selected   <- selectedNodes
    let connectTo = case selected of
            []     -> Nothing
            [wf]   -> Just $ wf ^. widget . UINode.nodeId
            (_:_) -> Nothing
    BatchCmd.addNode expr nodeMeta connectTo
    GA.sendEvent $ GA.AddNode $ if isJust connectTo then GA.AutoConnect else GA.Simple
