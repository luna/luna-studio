module JS.Visualizers where

import           Common.Prelude     hiding (toList)
import           Control.Arrow      ((&&&))
import           Data.Map           (Map)
import qualified Data.Map           as Map
import           Data.UUID.Types    (UUID)
import           GHCJS.Marshal.Pure (pFromJSVal)
import           JavaScript.Array   (JSArray, toList)

foreign import javascript safe "Object.keys(typeof window.visualizers == 'object' ? window.visualizers : {})"
    getVisualizers' :: IO JSArray

getVisualizers :: IO [String]
getVisualizers = fmap pFromJSVal . toList <$> getVisualizers'

foreign import javascript safe "visualizerFramesManager.sendData($1, $2);"
    sendVisualisationData' :: JSString -> JSString -> IO ()

foreign import javascript safe "visualizerFramesManager.sendDatapoint($1, $2);"
    sendStreamDatapoint' :: JSString -> JSString -> IO ()

foreign import javascript safe "visualizerFramesManager.register($1);"
    registerVisualizerFrame' :: JSString -> IO ()

foreign import javascript safe "visualizerFramesManager.notifyStreamRestart($1)"
    notifyStreamRestart' :: JSString -> IO ()

notifyStreamRestart :: UUID -> IO ()
notifyStreamRestart = notifyStreamRestart' . convert . show

sendStreamDatapoint :: UUID -> Text -> IO ()
sendStreamDatapoint uid d = sendStreamDatapoint' (convert $ show uid) (convert d)

registerVisualizerFrame :: UUID -> IO ()
registerVisualizerFrame = registerVisualizerFrame' . convert . show

sendVisualisationData :: UUID -> Text -> IO ()
sendVisualisationData uid d = sendVisualisationData' (convert $ show uid) (convert d)

foreign import javascript safe "window.visualizers[$1]($2)"
    checkVisualizer' :: JSString -> JSString -> IO JSString

checkVisualizer :: String -> String -> IO String
checkVisualizer name rep = convert <$> checkVisualizer' (convert name) (convert rep)

mkVisualizersMap :: IO (Map String (String -> IO String))
mkVisualizersMap = Map.fromList . fmap (id &&& checkVisualizer) <$> getVisualizers
