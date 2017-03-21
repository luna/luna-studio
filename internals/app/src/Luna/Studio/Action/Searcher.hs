{-# OPTIONS_GHC -fno-warn-orphans #-}
{-# LANGUAGE OverloadedStrings #-}
module Luna.Studio.Action.Searcher where

import qualified Data.Map                            as Map
import           Data.Monoid                         (All (All), getAll)
import qualified Data.Text                           as Text
import           Text.Read                           (readMaybe)

import           Data.Position                       (Position)
import           Data.ScreenPosition                 (ScreenPosition, x)
import           Empire.API.Data.Node                (NodeId)
import qualified JS.GoogleAnalytics                  as GA
import qualified JS.Searcher                         as Searcher
import           Luna.Studio.Action.Basic            (addNode, setNodeExpression)
import qualified Luna.Studio.Action.Batch            as Batch
import           Luna.Studio.Action.Command          (Command)
import           Luna.Studio.Action.State.Action     (beginActionWithKey, continueActionWithKey, removeActionFromState, updateActionWithKey)
import           Luna.Studio.Action.State.App        (renderIfNeeded)
import           Luna.Studio.Action.State.NodeEditor (getSearcher, getSelectedNodes, getSelectedNodes, modifyNodeEditor, modifySearcher)
import           Luna.Studio.Action.State.Scene      (translateToScreen, translateToWorkspace)
import           Luna.Studio.Event.Event             (Event (Shortcut))
import qualified Luna.Studio.Event.Shortcut          as Shortcut
import           Luna.Studio.Prelude
import qualified Luna.Studio.React.Model.Node        as Node
import qualified Luna.Studio.React.Model.NodeEditor  as NodeEditor
import qualified Luna.Studio.React.Model.Searcher    as Searcher
import qualified Luna.Studio.React.View.App          as App
import           Luna.Studio.State.Action            (Action (begin, continue, end, update), Searcher (Searcher), searcherAction)
import           Luna.Studio.State.Global            (State)
import qualified Luna.Studio.State.Global            as Global
import           Text.ScopeSearcher.Item             (Item (..), Items)
import qualified Text.ScopeSearcher.Scope            as Scope


instance Action (Command State) Searcher where
    begin    = beginActionWithKey    searcherAction
    continue = continueActionWithKey searcherAction
    update   = updateActionWithKey   searcherAction
    end      = close


data OtherCommands = AddNode
                   deriving (Bounded, Enum, Eq, Generic, Read, Show)

open :: Command State ()
open = openWith def =<< use Global.mousePos

positionDelta :: Double
positionDelta = 100

openWith :: Maybe NodeId -> ScreenPosition -> Command State ()
openWith nodeId pos = do
    pos' <- (map (view Node.position) <$> getSelectedNodes) >>= \case
          [nodePosition] -> if isNothing nodeId then return $ nodePosition & x %~ (+positionDelta) else translateToWorkspace pos
          _              -> translateToWorkspace pos
    begin Searcher
    GA.sendEvent GA.NodeSearcher
    modifyNodeEditor $ NodeEditor.searcher ?= Searcher.Searcher pos' 0 (Searcher.Node def) def nodeId False
    renderIfNeeded
    liftIO Searcher.focus

close :: Searcher -> Command State ()
close _ = do
    modifyNodeEditor $ NodeEditor.searcher .= Nothing
    removeActionFromState searcherAction
    liftIO App.focus

moveDown :: Searcher -> Command State ()
moveDown _ = modifySearcher $ do
    items <- use Searcher.resultsLength
    unless (items == 0) $
        Searcher.selected %= \p -> (p - 1) `mod` (items + 1)

moveUp :: Searcher -> Command State ()
moveUp _ = modifySearcher $ do
    items <- use Searcher.resultsLength
    unless (items == 0) $
        Searcher.selected %= \p -> (p + 1) `mod` (items + 1)

tryRollback :: Searcher -> Command State ()
tryRollback _ = do
    withJustM getSearcher $ \searcher -> do
       when (Text.null (searcher ^. Searcher.input)
         && (searcher ^. Searcher.isNode)
         && (searcher ^. Searcher.rollbackReady)) $
            modifySearcher $ do
                Searcher.rollbackReady .= False
                Searcher.selected      .= def
                Searcher.mode          .= Searcher.Command def
                Searcher.input         .= def

enableRollback :: Searcher -> Command State ()
enableRollback _ = modifySearcher $
    Searcher.rollbackReady .= True

accept :: (Event -> IO ()) -> Searcher -> Command State ()
accept scheduleEvent action = do
    withJustM getSearcher $ \searcher -> do
        let expression = searcher ^. Searcher.selectedExpression
        if searcher ^. Searcher.isNode then do
            case searcher ^. Searcher.nodeId of
                Nothing     -> addNode (searcher ^. Searcher.position) expression
                Just nodeId -> setNodeExpression nodeId expression
            close action
        else
            execCommand action scheduleEvent $ convert expression

openEdit :: Text -> NodeId -> Position -> Command State ()
openEdit expr nodeId pos = do
    openWith (Just nodeId) =<< translateToScreen pos
    continue $ querySearch expr

allCommands :: Items ()
allCommands = Map.fromList $ (,Element ()) . convert <$> (commands <> otherCommands) where
    commands = show <$> [(minBound :: Shortcut.Command) ..]
    otherCommands = show <$> [(minBound :: OtherCommands)]

execCommand :: Searcher -> (Event -> IO ()) -> String -> Command State ()
execCommand action scheduleEvent expression = case readMaybe expression of
    Just command -> do
        liftIO $ scheduleEvent $ Shortcut $ Shortcut.Event command def
        close action
    Nothing -> case readMaybe expression of
        Just AddNode -> modifySearcher $ do
            Searcher.selected .= def
            Searcher.mode     .= Searcher.Node def
            Searcher.input    .= def
            Searcher.rollbackReady .= False
        Nothing -> return ()

acceptEntry :: (Event -> IO ()) -> Int -> Searcher -> Command State ()
acceptEntry scheduleEvent entryNum searcher = do
    mayItemsLength <- (fmap . fmap) (view Searcher.resultsLength) $ getSearcher
    withJust mayItemsLength $ \itemsLength -> when (itemsLength >= entryNum) $ do
        modifySearcher $ Searcher.selected .= entryNum
        accept scheduleEvent searcher

substituteInputWithEntry :: Searcher -> Command State ()
substituteInputWithEntry _ = modifySearcher $ do
    newInput <- use Searcher.selectedExpression
    Searcher.input .= newInput

querySearch :: Text -> Searcher -> Command State ()
querySearch query _ = do
    selection <- Searcher.selection
    isNode <- modifySearcher $ do
        isNode <- use Searcher.isNode
        Searcher.input .= query
        if isNode then
            Searcher.rollbackReady .= False
            {- clearing results prevents from selecting out of date result, but make searcher blink. -}
            -- Searcher.mode .= Searcher.Node def
        else do
            let items = Scope.searchInScope allCommands query
            Searcher.selected      .= min 1 (length items)
            Searcher.mode          .= Searcher.Command items
            Searcher.rollbackReady .= False
        return $ All isNode
    when (getAll isNode) $ Batch.searchNodes query selection
