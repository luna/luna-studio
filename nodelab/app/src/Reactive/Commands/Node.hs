{-# LANGUAGE OverloadedStrings #-}
module Reactive.Commands.Node
    ( expandSelectedNodes
    , editExpression
    , enter
    , exit
    , tryEnter
    , rename
    ) where

import qualified Luna.Studio.Batch.Workspace                   as Workspace
import           Empire.API.Data.Breadcrumb        (BreadcrumbItem (..))
import qualified Empire.API.Data.Breadcrumb        as Breadcrumb
import qualified Empire.API.Data.GraphLocation     as GraphLocation
import           Empire.API.Data.Node              (Node, NodeId)
import qualified Empire.API.Data.Node              as Node
import qualified Empire.API.Data.NodeMeta          as NodeMeta
import           Object.UITypes                    (WidgetId)
import qualified Object.Widget.Node                as Model
import           React.Store                       (WRef (..), widget)
import qualified React.Store                       as Store
import           Reactive.Commands.Command         (Command)
import           Reactive.Commands.Graph.Selection (selectedNodes)
import           Reactive.Commands.Node.NodeMeta   (modifyNodeMeta)
import           Reactive.Commands.ProjectManager  as ProjectManager
import qualified Reactive.Commands.Searcher        as Searcher
import           Reactive.State.Global             (State)
import qualified Reactive.State.Global             as Global
import qualified Reactive.State.Graph              as Graph
import           Luna.Studio.Prelude



tryEnter :: Node -> Command State ()
tryEnter node = when (node ^. Node.canEnter) $
    enter $ Breadcrumb.Lambda $ node ^. Node.nodeId

enter :: BreadcrumbItem -> Command State ()
enter item = do
    location <- use $ Global.workspace . Workspace.currentLocation
    let newLocation = location & GraphLocation.breadcrumb . Breadcrumb.items %~ (++ [item])
    ProjectManager.navigateToGraph newLocation

exit :: Command State ()
exit = do
    location <- use $ Global.workspace . Workspace.currentLocation
    case location ^. GraphLocation.breadcrumb . Breadcrumb.items of
        (_:t) -> ProjectManager.navigateToGraph $ location & GraphLocation.breadcrumb . Breadcrumb.items .~ t
        [] -> return ()

rename :: NodeId -> Text -> Command State ()
rename nodeId name = do
    Global.graph . Graph.nodesMap . ix nodeId . Node.name .= name
    Global.withNode nodeId $
        mapM_ $ Store.modify_ (Model.name .~ name)

expandSelectedNodes :: Command State ()
expandSelectedNodes = do
    sn <- selectedNodes
    let allSelected = all (view $ widget . Model.isExpanded) sn
        update      = if allSelected then Model.isExpanded %~ not
                                     else Model.isExpanded .~ True
    forM_ sn $
        Store.modify_ update . _ref

visualizationsToggled :: WidgetId -> NodeId -> Bool -> Command State ()
visualizationsToggled _ nid val = modifyNodeMeta nid (NodeMeta.displayResult .~ val)

editExpression :: NodeId -> Command State ()
editExpression nodeId = do
    exprMay     <- preuse $ Global.graph . Graph.nodesMap . ix nodeId . Node.nodeType . Node.expression
    nodeRefMay <- Global.getNode nodeId
    withJust exprMay $ \expr -> withJust nodeRefMay $ \nodeRef -> do
        node <- Store.get nodeRef
        let pos = round <$> node ^. Model.position
        Searcher.openEdit expr nodeId $ pos
