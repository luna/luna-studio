{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE TypeFamilies   #-}

module React.Store
    ( module React.Store
    , module X
) where

import           Control.Monad.Trans.Reader
import           React.Flux
import           Utils.PreludePlus          as P hiding (transform)

import qualified Event.Event                as Event
import Event.UI                   (UIEvent)
import           React.Store.App            (App (App))
import           React.Store.Ref            as X



instance Typeable a => StoreData (Store a) where
    type StoreAction (Store a) = UIEvent
    transform event store = do
        (store ^. sendEvent) $ Event.UI event
        return $ store

dispatch :: Typeable a => Ref a -> UIEvent -> [SomeStoreAction]
dispatch s a = [SomeStoreAction s a]

create' :: (StoreData (Store a), MonadIO m) => SendEvent -> a -> m (Ref a)
create' se a = liftIO $ mkStore $ Store a se

create :: (StoreData (Store a), MonadIO m) => a -> SendEventM m (Ref a)
create a = do
    se <- ask
    create' se a

createApp :: MonadIO m => SendEvent -> m (Ref App)
createApp = runReaderT (create =<< (App <$> create def <*> create def))
