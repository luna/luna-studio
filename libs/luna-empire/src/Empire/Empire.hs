{-# LANGUAGE ScopedTypeVariables #-}

module Empire.Empire where

import           Empire.Prelude                hiding (TypeRep)
import           Empire.API.Data.AsyncUpdate   (AsyncUpdate)
import qualified Empire.API.Data.Error         as APIError
import           Empire.API.Data.GraphLocation (GraphLocation)
import           Empire.API.Data.Node          (ExpressionNode, NodeId)
import           Empire.API.Data.PortDefault   (PortValue)
import           Empire.API.Data.Project       (ProjectId)
import           Empire.API.Data.TypeRep       (TypeRep)
import           Empire.Data.AST               (SomeASTException)
import           Empire.Data.Graph             (Graph, defaultGraph)
import           Empire.Data.Library           (Library)
import           Empire.Prelude

import           Control.Concurrent.STM.TChan  (TChan)
import           Control.Exception             (try)
import           Control.Monad.Except          (ExceptT (..), MonadError, runExceptT, throwError)
import           Control.Monad.Reader
import           Control.Monad.State
import           Data.Map.Lazy                 (Map)
import qualified Data.Map.Lazy                 as Map

type Error = String

type ActiveFiles = Map FilePath Library

newtype Env = Env { _activeFiles :: ActiveFiles } deriving Show
makeLenses ''Env

instance Default Env where
    def = Env Map.empty

data CommunicationEnv = CommunicationEnv { _updatesChan   :: TChan AsyncUpdate
                                         -- FIXME[MK]: Yeah, let's use 3-tuples, way to code!
                                         , _typecheckChan :: TChan (GraphLocation, Graph, Bool)
                                         }
makeLenses ''CommunicationEnv

instance Show CommunicationEnv where
    show _ = "CommunicationEnv"

data InterpreterEnv = InterpreterEnv { _valuesCache :: Map NodeId [PortValue]
                                     , _nodesCache  :: Map NodeId ExpressionNode
                                     , _errorsCache :: Map NodeId APIError.Error
                                     , _graph       :: Graph
                                     , _destructors :: [IO ()]
                                     }
makeLenses ''InterpreterEnv

defaultInterpreterEnv :: IO InterpreterEnv
defaultInterpreterEnv = do
    g <- defaultGraph
    return $ InterpreterEnv def def def g []

type CommandStack s = ExceptT Error (ReaderT CommunicationEnv (StateT s IO))
type Command s a = ExceptT Error (ReaderT CommunicationEnv (StateT s IO)) a

type Empire a = Command Env a

runEmpire :: CommunicationEnv -> s -> Command s a -> IO (Either Error a, s)
runEmpire notif st cmd = do
    res <- try $ runStateT (runReaderT (runExceptT cmd) notif) st
    case res of
        Left (exc :: SomeASTException) -> return (Left (displayException exc), st)
        Right (eea, st')               -> return (eea, st')

execEmpire :: CommunicationEnv -> s -> Command s a -> IO (Either Error a)
execEmpire = fmap fst .:. runEmpire

empire :: (CommunicationEnv -> s -> IO (Either Error a, s)) -> Command s a
empire = ExceptT . ReaderT . fmap StateT

infixr 4 <?!>
(<?!>) :: MonadError Error m => m (Maybe a) -> Error -> m a
(<?!>) cmd err = cmd >>= maybe (throwError err) return
