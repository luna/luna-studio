module NodeEditor.Action.Basic.EnterBreadcrumb where

import           Common.Prelude
import           Empire.API.Data.Breadcrumb                 (Breadcrumb, BreadcrumbItem (Lambda), items)
import           Empire.API.Data.GraphLocation              (breadcrumb)
import           NodeEditor.Action.Basic.ProjectManager     (navigateToGraph)
import           NodeEditor.Action.Command                  (Command)
import           NodeEditor.Batch.Workspace                 (currentLocation)
import           NodeEditor.React.Model.Node.ExpressionNode (ExpressionNode, canEnter, nodeId)
import           NodeEditor.State.Global                    (State, workspace)


enterBreadcrumb :: BreadcrumbItem -> Command State ()
enterBreadcrumb item =
    withJustM (preuse $ workspace . traverse . currentLocation) $ \location ->
        navigateToGraph $ location & breadcrumb . items %~ (++ [item])

enterBreadcrumbs :: Breadcrumb BreadcrumbItem -> Command State ()
enterBreadcrumbs newBc =
    withJustM (preuse $ workspace . traverse . currentLocation) $ \location ->
        navigateToGraph $ location & breadcrumb .~ newBc

exitBreadcrumb :: Command State ()
exitBreadcrumb =
    withJustM (preuse $ workspace . traverse . currentLocation) $ \location ->
        case location ^. breadcrumb . items of
            (_:t) -> navigateToGraph $ location & breadcrumb . items .~ t
            []    -> return ()

enterNode :: ExpressionNode -> Command State ()
enterNode node = when (node ^. canEnter) $ enterBreadcrumb $ Lambda (node ^. nodeId)
