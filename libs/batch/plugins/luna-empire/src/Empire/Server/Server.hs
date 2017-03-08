{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE Rank2Types       #-}
module Empire.Server.Server where

import           Control.Concurrent.STM.TChan (writeTChan)
import           Control.Monad.State          (StateT)
import           Control.Monad.STM            (atomically)
import           Data.Binary                  (Binary)
import qualified Data.Binary                  as Bin
import           Data.ByteString.Lazy         (toStrict)
import           Prologue

import           Empire.API.Request           (Request)
import qualified Empire.API.Response          as Response
import           Empire.API.Topic             (MessageTopic)
import qualified Empire.API.Topic             as Topic
import           Empire.Env                   (Env)
import qualified Empire.Env                   as Env
import qualified System.Log.MLogger           as Logger
import qualified ZMQ.Bus.Data.Message         as Message
import           ZMQ.Bus.Trans                (BusT (..))

sendToBus :: Binary a => String -> a -> StateT Env BusT ()
sendToBus topic bin = do
    chan <- use Env.toBusChan
    liftIO $ atomically $ writeTChan chan $ Message.Message topic $ toStrict $ Bin.encode bin

sendToBus' :: (MessageTopic a, Binary a) => a -> StateT Env BusT ()
sendToBus' msg = sendToBus (Topic.topic msg) msg

replyFail :: forall a b c. Response.ResponseResult a b c => Logger.Logger -> String -> Request a -> Response.Status b -> StateT Env BusT ()
replyFail logger errMsg req inv = do
  logger Logger.error $ formatErrorMessage req errMsg
  sendToBus' $ Response.error req inv errMsg

replyOk :: forall a b. Response.ResponseResult a b () => Request a -> b -> StateT Env BusT ()
replyOk req inv = sendToBus' $ Response.ok req inv

replyResult :: forall a b c. Response.ResponseResult a b c => Request a -> b -> c -> StateT Env BusT ()
replyResult req inv res = sendToBus' $ Response.result req inv res

errorMessage :: String
errorMessage = "Error processing request: "

formatErrorMessage :: MessageTopic a => a -> String -> String
formatErrorMessage req msg = errorMessage <> (Topic.topic req) <> ": " <> msg
