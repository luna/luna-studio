module Empire.Server.Server where

import Prologue

import qualified Bus.Data.Message              as Message
import qualified Bus.Framework.App             as Bus
import qualified Compress
import qualified Data.Binary                   as Bin
import qualified Data.Map                      as Map
import qualified Data.Set                      as Set
import qualified Data.Text                     as Text
import qualified Empire.ApiHandlers            as Api
import qualified Empire.Commands.Graph         as Graph
import qualified Empire.Empire                 as Empire
import qualified Empire.Env                    as Env
import qualified Luna.Package.Structure.Name   as Package
import qualified LunaStudio.API.Graph.Request  as G
import qualified LunaStudio.API.Response       as Response
import qualified LunaStudio.API.Topic          as Topic
import qualified LunaStudio.Data.Graph         as GraphAPI
import qualified LunaStudio.Data.GraphLocation as GraphLocation
import qualified LunaStudio.Data.Node          as Node
import qualified System.Log.MLogger            as Logger

import Control.Arrow                 ((&&&))
import Control.Concurrent.STM.TChan  (writeTChan)
import Control.Lens                  (to, use, (.=), (^..), _Left)
import Control.Monad.Catch           (handle, try)
import Control.Monad.State           (StateT)
import Control.Monad.STM             (atomically)
import Data.Binary                   (Binary)
import Data.ByteString.Lazy          (toStrict)
import Empire.Data.AST               (SomeASTException)
import Empire.Data.Graph             (CommandState)
import Empire.Empire                 (Empire, runEmpire)
import Empire.Env                    (Env)
import Empire.Utils                  (currentISO8601Time)
import GHC.Stack                     (renderStack, whoCreated)
import LunaStudio.API.Request        (Request (..))
import LunaStudio.API.Topic          (MessageTopic)
import LunaStudio.Data.Error         (Error, LunaError, errorContent)
import LunaStudio.Data.Graph         (Graph (..))
import LunaStudio.Data.GraphLocation (GraphLocation (..))
import System.Environment            (getEnv)
import System.FilePath               (replaceFileName, (</>))

logger :: Logger.Logger
logger = Logger.getLogger $(Logger.moduleName)

sendToBus :: Binary a => String -> a -> StateT Env Bus.App ()
sendToBus topic bin = do
    chan <- use Env.toBusChan
    liftIO $ atomically $ writeTChan chan
        $ Message.Message topic $ Compress.pack $ Bin.encode bin

sendToBus' :: forall a. (MessageTopic a, Binary a) => a -> StateT Env Bus.App ()
sendToBus' msg = sendToBus (Topic.topic @a) msg

replyFail :: forall a b c. Response.ResponseResult a b c
    => Logger.Logger -> Error LunaError -> Request a -> Response.Status b
    -> StateT Env Bus.App ()
replyFail logger err req inv = do
    time <- liftIO currentISO8601Time
    logger Logger.error $ time
        <> "\t:: " <> formatErrorMessage req (Text.unpack $ err ^. errorContent)
    sendToBus' $ Response.error req inv err

replyOk :: forall a b. Response.ResponseResult a b ()
    => Request a -> b -> StateT Env Bus.App ()
replyOk req inv = do
    time <- liftIO currentISO8601Time
    logger Logger.info $ time <> "\t:: sending ok for " <> Topic.topic @(Request a)
    sendToBus' $ Response.ok req inv

replyResult :: forall a b c. (Response.ResponseResult a b c, Show c)
    => Request a -> b -> c -> StateT Env Bus.App ()
replyResult req inv res = do
    time <- liftIO currentISO8601Time
    logger Logger.info $ time <> "\t:: sending response for " <> Topic.topic @(Request a)
    logger Logger.info $ time <> "\t:: " <> show res
    sendToBus' $ Response.result req inv res

errorMessage :: String
errorMessage = "error during processing request "

formatErrorMessage :: forall a. MessageTopic a => a -> String -> String
formatErrorMessage req msg = errorMessage <> (Topic.topic @a) <> ": " <> msg

withActiveProject :: (CommandState Empire.Env -> StateT Env Bus.App ()) ->
    StateT Env Bus.App ()
withActiveProject act = do
    currentEmpireEnv <- use Env.empireEnv
    case currentEmpireEnv of
        Just env -> act env
        Nothing  -> logger Logger.info "withActiveProject: No Project"

modifyGraph :: forall req inv res res'.
    ( Show req
    , G.GraphRequest req
    , Response.ResponseResult req inv res')
    => (req -> Empire inv) -> (req -> Empire res)
    -> (Request req -> inv -> res -> StateT Env Bus.App ()) -> Request req
    -> StateT Env Bus.App ()
modifyGraph inverse action success origReq@(Request uuid guiID request) = do
    withActiveProject $ \empireEnv -> do
        logger Logger.info $ Topic.topic @(Request req) <> ": " <> show request
        empireNotifEnv   <- use Env.empireNotif
        inv'             <- liftIO $ try
            $ runEmpire empireNotifEnv empireEnv $ inverse request
        case inv' of
            Left (exc :: SomeException) -> do
                err <- liftIO $ Graph.prepareLunaError exc
                replyFail logger err origReq (Response.Error err)
            Right (inv, _) -> do
                let invStatus = Response.Ok inv
                result <- liftIO $ try
                    $ runEmpire empireNotifEnv empireEnv $ action request
                case result of
                    Left  (exc :: SomeException) -> do
                        err <- liftIO $ Graph.prepareLunaError exc
                        replyFail logger err origReq invStatus
                    Right (result, newEmpireEnv) -> do
                        Env.empireEnv .= Just newEmpireEnv
                        success origReq inv result

modifyGraphOk :: forall req inv.
    ( Show req
    , Bin.Binary req
    , G.GraphRequest req
    , Response.ResponseResult req inv ()
    ) => (req -> Empire inv) -> (req -> Empire ()) -> Request req
    -> StateT Env Bus.App ()
modifyGraphOk inverse action = modifyGraph inverse action reply where
    reply :: Request req -> inv -> () -> StateT Env Bus.App ()
    reply req inv _ = replyOk req inv

type GraphRequestContext req inv result = (
    Show req, Show result, Bin.Binary req, G.GraphRequest req,
    Response.ResponseResult req inv result, Api.Modification req,
    Response.InverseOf req ~ inv, Response.ResultOf req ~ result
    )

type GraphRequestContext'  req     =
    GraphRequestContext'' req (Response.ResultOf req)
type GraphRequestContext'' req res =
    GraphRequestContext   req (Response.InverseOf req) res

handle :: GraphRequestContext' req => Request req -> StateT Env Bus.App ()
handle = modifyGraph Api.buildInverse Api.perform replyResult

handleOk :: GraphRequestContext'' req () => Request req -> StateT Env Bus.App ()
handleOk = modifyGraph Api.buildInverse Api.perform replyResult

defInverse :: a -> Empire ()
defInverse = const $ pure ()

