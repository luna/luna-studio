{-# OPTIONS_GHC -fno-warn-orphans #-}

module Luna.Studio.State.Global where

import           Data.Word                            (Word8)
import           Luna.Studio.Data.Vector              (Position (Position), Vector2 (Vector2))
import           Luna.Studio.Prelude

import qualified Control.Monad.State                  as M
import           Data.Aeson                           (ToJSON, toJSON)
import           Data.DateTime                        (DateTime)
import           Data.Set                             (Set)
import           Data.UUID.Types                      (UUID)
import           Luna.Studio.Action.Command           (Command)
import           System.Random                        (StdGen)
import qualified System.Random                        as Random

import           Empire.API.Data.Connection           (ConnectionId)
import           Empire.API.Data.Node                 (NodeId)
import qualified Empire.API.Data.Node                 as Node
import qualified Empire.API.Graph.Collaboration       as Collaboration
import qualified Event.Event                          as Event
import           Luna.Studio.Batch.Workspace
import           Luna.Studio.React.Model.App          (App)
import qualified Luna.Studio.React.Model.App          as App
import           Luna.Studio.React.Model.Breadcrumbs  (Breadcrumbs)
import           Luna.Studio.React.Model.CodeEditor   (CodeEditor)
import           Luna.Studio.Data.ConnectionPen   (ConnectionPen)
import           Luna.Studio.React.Model.Node         (Node)
import           Luna.Studio.React.Model.NodeEditor   (NodeEditor)
import           Luna.Studio.React.Model.Connection    (Connection, CurrentConnection)
import qualified Luna.Studio.React.Model.NodeEditor   as NodeEditor
import           Luna.Studio.React.Model.Searcher     (Searcher)
import           Luna.Studio.React.Model.SelectionBox (SelectionBox)
import           Luna.Studio.React.Store              (Ref)
import qualified Luna.Studio.React.Store              as Store
import qualified Luna.Studio.State.Camera             as Camera
import qualified Luna.Studio.State.Collaboration      as Collaboration
import qualified Luna.Studio.State.ConnectionPen      as ConnectionPen
import qualified Luna.Studio.State.Drag               as Drag
import qualified Luna.Studio.State.Graph              as Graph
import qualified Luna.Studio.State.MultiSelection     as MultiSelection
import qualified Luna.Studio.State.Slider             as Slider
import qualified Luna.Studio.State.UIRegistry         as UIRegistry



foreign import javascript safe "{}" defJsState :: Event.JSState

-- TODO[react]: Move all action states to ActionState
-- TODO split to more states
data State = State { _mousePos           :: Position
                   , _graph              :: Graph.State
                   , _cameraState        :: Maybe Camera.State
                   , _multiSelection     :: MultiSelection.State
                   , _selectionHistory   :: [Set Node.NodeId]
                   , _drag               :: Drag.State
                   , _slider             :: Maybe Slider.State
                   -- TODO[react]: wyjebawszy
                   , _uiRegistry         :: UIRegistry.State
                   , _connectionPen      :: ConnectionPen.State
                   , _workspace          :: Workspace
                   , _lastEvent          :: Maybe Event.Event
                   , _eventNum           :: Int
                   , _jsState            :: Event.JSState
                   , _collaboration      :: Collaboration.State
                   , _pendingRequests    :: Set UUID
                   , _lastEventTimestamp :: DateTime
                   , _clientId           :: Collaboration.ClientId
                   , _random             :: StdGen
                   , _tutorial           :: Maybe Int
                   , _app                :: Ref App
                   } deriving (Generic)

instance ToJSON State
instance ToJSON StdGen where
    toJSON _ = toJSON "(random-generator)"
instance ToJSON (Ref App) where
    toJSON _ = toJSON "(Ref App)"


makeLenses ''State


withApp' :: (Ref App -> Command State r) -> Command State r
withApp' action = action =<< use app

with lens action = withApp' $ Store.modifyM' $ zoom lens action

get' lens = withApp' $ return . view lens <=< Store.get

withApp :: M.State App r -> Command State r
withApp = withApp' . Store.modifyM'

withNodeEditor :: M.State NodeEditor r -> Command State r
withNodeEditor = with App.nodeEditor

getNodeEditor :: Command State NodeEditor
getNodeEditor = get' App.nodeEditor

withCodeEditor :: M.State CodeEditor r -> Command State r
withCodeEditor = with App.codeEditor

withBreadcrumbs :: (Ref Breadcrumbs -> Command State r) -> Command State r
withBreadcrumbs action = withApp' $ (action . view App.breadcrumbs) <=< Store.get

withSearcher :: M.State Searcher r -> Command State r
withSearcher = with App.searcher

getSearcher :: Command State Searcher
getSearcher = get' App.searcher

withSelectionBox :: M.State SelectionBox r -> Command State r
withSelectionBox = with (App.nodeEditor . NodeEditor.selectionBox)

withConnectionPen :: Monoid r => M.State ConnectionPen r -> Command State r
withConnectionPen = with (App.nodeEditor . NodeEditor.connectionPen) . zoom traverse

withCurrentConnection :: Monoid r => M.State CurrentConnection r -> Command State r
withCurrentConnection = with (App.nodeEditor . NodeEditor.currentConnection) . zoom traverse

withNode :: Monoid r => NodeId -> M.State Node r -> Command State r
withNode nodeId = with (App.nodeEditor . NodeEditor.nodes . at nodeId) . zoom traverse

getNode :: NodeId -> Command State (Maybe Node)
getNode nodeId = get' (App.nodeEditor . NodeEditor.nodes . at nodeId)

withConnection :: Monoid r => ConnectionId -> M.State Connection r -> Command State r
withConnection connectionId = with (App.nodeEditor . NodeEditor.connections . at connectionId) . zoom traverse

getConnection :: ConnectionId -> Command State (Maybe Connection)
getConnection connectionId = get' (App.nodeEditor . NodeEditor.connections . at connectionId)

initialState :: DateTime -> Collaboration.ClientId -> StdGen -> Maybe Int -> Ref App -> State
initialState = State (Position (Vector2 200 200)) def Nothing def def def def def def def def def defJsState def def

inRegistry :: Command UIRegistry.State a -> Command State a
inRegistry = zoom uiRegistry

inRegistry_ :: Command UIRegistry.State a -> Command State ()
inRegistry_ = void . zoom uiRegistry

nextRandom :: Command State Word8
nextRandom = do
    (val, rnd) <- uses random Random.random
    random .= rnd
    return val
