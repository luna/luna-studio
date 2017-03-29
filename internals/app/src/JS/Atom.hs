{-# LANGUAGE JavaScriptFFI #-}

module JS.Atom
    ( pushCode
    , pushBuffer
    , subscribeText
    , subscribeEventListenerInternal
    ) where


import           GHCJS.Foreign.Callback
import           GHCJS.Marshal.Pure         (pFromJSVal)
import qualified Data.JSString              as JSString
import qualified Data.Text                  as Text
import           Internal.Event.Internal (InternalEvent)
import qualified Internal.Event.Internal as Internal
import           Internal.Event.Text (TextEvent, TextEvent (..))
import qualified Internal.Event.Text as TextEvent
import           Internal.Prelude


foreign import javascript safe "atomCallback2.pushCode($1, $2, $3, $4)"
    pushCode' :: JSString -> Int -> Int -> JSString -> IO ()

foreign import javascript safe "atomCallback2.pushBuffer($1, $2)"
    pushBuffer :: JSString -> JSString -> IO ()


foreign import javascript safe "atomCallback2.subscribeEventListenerInternal($1)"
  subscribeEventListenerInternal' :: Callback (JSVal -> IO ()) -> IO ()

foreign import javascript safe "($1).unsubscribeEventListenerInternal()"
  unsubscribeEventListenerInternal' :: Callback (JSVal -> IO ()) -> IO ()

foreign import javascript safe "atomCallback2.subscribeText($1)"
  subscribeText' :: Callback (JSVal -> IO ()) -> IO ()

foreign import javascript safe "($1).unsubscribeText()"
  unsubscribeText' :: Callback (JSVal -> IO ()) -> IO ()

foreign import javascript safe "atomCallback2.getPath($1)"
  getPath :: JSVal -> JSVal

foreign import javascript safe "atomCallback2.getStart($1)"
  getStart :: JSVal -> JSVal

foreign import javascript safe "atomCallback2.getStop($1)"
  getStop :: JSVal -> JSVal

foreign import javascript safe "atomCallback2.getText($1)"
  getText :: JSVal -> JSVal

foreign import javascript safe "atomCallback2.getCursor($1)"
  getCursor :: JSVal -> JSVal

jsvalToText :: JSVal -> TextEvent
jsvalToText jsval = result where
  filepath = pFromJSVal $ getPath jsval
  start    = pFromJSVal $ getStart jsval
  stop     = pFromJSVal $ getStop jsval
  text     = pFromJSVal $ getText jsval
  cursor   = pFromJSVal $ getCursor jsval
  result   = TextEvent filepath start stop text $ Just cursor

subscribeText :: (TextEvent -> IO ()) -> IO (IO ())
subscribeText callback = do
  wrappedCallback <- syncCallback1 ContinueAsync $ callback . jsvalToText
  subscribeText' wrappedCallback
  return $ unsubscribeText' wrappedCallback >> releaseCallback wrappedCallback

pushCode :: TextEvent -> IO ()
pushCode = do
  uri   <- (^. TextEvent.filePath)
  start <- (^. TextEvent.start)
  end   <- (^. TextEvent.stop)
  text  <- (^. TextEvent.text)
  return $ pushCode' (convert uri) start end $ convert $ Text.unpack text

subscribeEventListenerInternal :: (InternalEvent -> IO ()) -> IO (IO ())
subscribeEventListenerInternal callback = do
    wrappedCallback <- syncCallback1 ContinueAsync $ callback . Internal.fromString . pFromJSVal
    subscribeEventListenerInternal' wrappedCallback
    return $ unsubscribeEventListenerInternal' wrappedCallback >> releaseCallback wrappedCallback
