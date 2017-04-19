{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE TypeFamilies   #-}

module Node.Editor.React.Store.Ref where

import           Control.Monad.State        (runState)
import           Control.Monad.Trans.Reader
import           Control.Monad.Trans.State  hiding (get, modify)
import           Luna.Prelude        as P hiding (transform)
import           React.Flux

import           Node.Editor.Action.Command (Command)
import qualified Node.Editor.Event.Event    as E



type Ref a = ReactStore (Store a)

type SendEvent = E.Event -> IO ()

data Store a = Store { _dt :: a
                     , _sendEvent :: SendEvent
                     } deriving (Generic, NFData)

instance Eq a => Eq (Store a) where
    s1 == s2 = _dt s1 == _dt s2

type SendEventM = ReaderT SendEvent
type StoreModifyM a m = StateT a (SendEventM m)--TODO newtype

makeLenses ''Store

runState' :: State a r -> Store a -> (Store a, r)
runState' action store = (store & dt .~ newDt, ret) where
    (ret, newDt) = runState action $ store ^. dt

continueModify :: Typeable s => State s r -> Ref s -> Command a r
continueModify action = liftIO . flip modifyStoreNoCommit (return . runState' action)

commit :: Typeable s => Ref s -> Command a ()
commit = liftIO . storeCommit

get :: Ref p -> Command s p
get rf = _dt <$> liftIO (getStoreData rf)

-- runStoreModifyM :: Monad m => StoreModifyM a m r -> Store a -> m (Store a, r)
-- runStoreModifyM action store = do
--     (ret, newDt) <- runReaderT (runStateT action $ store ^. dt) (store ^. sendEvent)
--     return (store & dt .~ newDt, ret)
--
-- modify :: Typeable s => (s -> (s, r)) -> Ref s -> Command a r
-- modify action = modifyM (StateT $ return . swap . action)
--
-- modify_ :: Typeable s => (s -> s) -> Ref s -> Command a ()
-- modify_ action = modifyM_ (State.modify action)
--
-- modifyM :: Typeable s => StoreModifyM s IO r -> Ref s -> Command a r
-- modifyM action = liftIO . flip modifyStore (runStoreModifyM action)

-- modifyM_ :: Typeable s => StoreModifyM s IO () -> Ref s -> Command a ()
-- modifyM_ = modifyM

-- with :: (p -> Command a r) -> Ref p -> Command a r
-- with action parentRef = action =<< get parentRef
--
-- get' :: Ref p -> Command s (WRef p)
-- get' rf = WRef rf <$> get rf
--
-- use :: Getting r s r -> Ref s -> Command state r
-- use getter store = P.view getter <$> get store