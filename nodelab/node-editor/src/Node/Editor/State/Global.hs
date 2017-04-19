{-# LANGUAGE DeriveAnyClass #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}
module Node.Editor.State.Global where

import           Data.DateTime                        (DateTime)
import           Data.Map                             (Map)
import           Data.Set                             (Set)
import           Data.UUID.Types                      (UUID)
import           Data.Word                            (Word8)
import           Empire.API.Data.NodeLoc              (NodeLoc)
import           Empire.API.Graph.CollaborationUpdate (ClientId)
import           Node.Editor.Action.Command           (Command)
import           Node.Editor.Batch.Workspace (Workspace)
import           qualified Node.Editor.Batch.Workspace as Workspace
import           Node.Editor.Event.Event              (Event)
import           Luna.Prelude
import           Node.Editor.React.Model.App          (App)
import           Node.Editor.React.Store              (Ref)
import           Node.Editor.State.Action             (ActionRep, Connect, SomeAction)
import qualified Node.Editor.State.Collaboration      as Collaboration
import qualified Node.Editor.State.UI                 as UI
import           System.Random                        (StdGen)
import qualified System.Random                        as Random

-- TODO: Reconsider our design. @wdanilo says that we shouldn't use MonadState at all
data State = State
        { _ui                   :: UI.State
        , _backend              :: BackendState
        , _actions              :: ActionState
        , _collaboration        :: Collaboration.State
        , _debug                :: DebugState
        , _selectionHistory     :: [Set NodeLoc]
        , _workspace            :: Workspace
        , _lastEventTimestamp   :: DateTime
        , _random               :: StdGen
        }

data ActionState = ActionState
        { _currentActions       :: Map ActionRep (SomeAction (Command State))
        -- TODO[LJK]: This is duplicate. Find way to remove it but make it possible to get Connect without importing its instance
        , _currentConnectAction :: Maybe Connect
        } deriving (Default, Generic)

data BackendState = BackendState
        { _pendingRequests      :: Set UUID
        , _clientId             :: ClientId
        }

data DebugState = DebugState
        { _lastEvent            :: Maybe Event
        , _eventNum             :: Int
        } deriving (Default, Generic)

makeLenses ''ActionState
makeLenses ''BackendState
makeLenses ''State
makeLenses ''DebugState

mkState :: Ref App -> ClientId -> FilePath -> DateTime -> StdGen -> State
mkState ref clientId' path = State
    {- react                -} (UI.mkState ref)
    {- backend              -} (BackendState def clientId')
    {- actions              -} def
    {- collaboration        -} def
    {- debug                -} def
    {- selectionHistory     -} def
    {- workspace            -} (Workspace.mk path)

nextRandom :: Command State Word8
nextRandom = uses random Random.random >>= \(val, rnd) -> random .= rnd >> return val