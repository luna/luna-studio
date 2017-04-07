module Luna.Studio.Event.Processor where

import           Control.Concurrent.MVar
import           Control.Exception                          (handle)
import           Data.DateTime                              (getCurrentTime)
import           Data.Monoid                                (Last (..))
import           GHCJS.Prim                                 (JSException)

import qualified JS.Debug
import           JS.WebSocket                               (WebSocket)
import           Luna.Studio.Action.Command                 (Command, execCommand)
import           Luna.Studio.Action.State.App               (renderIfNeeded)
import           Luna.Studio.Event.Event                    (Event)
import qualified Luna.Studio.Event.Event                    as Event
import           Luna.Studio.Event.Loop                     (LoopRef)
import qualified Luna.Studio.Event.Loop                     as Loop
import qualified Luna.Studio.Event.Preprocessor.Batch       as BatchEventPreprocessor
import qualified Luna.Studio.Event.Preprocessor.CustomEvent as CustomEventPreprocessor
import qualified Luna.Studio.Event.Preprocessor.Shortcut    as ShortcutEventPreprocessor
import           Luna.Studio.Event.Source                   (AddHandler (..))
import qualified Luna.Studio.Event.Source                   as JSHandlers
import qualified Luna.Studio.Handler.App                    as App
import qualified Luna.Studio.Handler.Autolayout             as Autolayout
import qualified Luna.Studio.Handler.Backend.Control        as Control
import qualified Luna.Studio.Handler.Backend.Graph          as Graph
import qualified Luna.Studio.Handler.Backend.ProjectManager as ProjectManager
import qualified Luna.Studio.Handler.Breadcrumbs            as Breadcrumbs
import qualified Luna.Studio.Handler.Camera                 as Camera
import qualified Luna.Studio.Handler.Clipboard              as Clipboard
import qualified Luna.Studio.Handler.CodeEditor             as CodeEditor
import qualified Luna.Studio.Handler.Collaboration          as Collaboration
import qualified Luna.Studio.Handler.Connect                as Connect
import qualified Luna.Studio.Handler.ConnectionPen          as ConnectionPen
import qualified Luna.Studio.Handler.Debug                  as Debug
import qualified Luna.Studio.Handler.MultiSelection         as MultiSelection
import qualified Luna.Studio.Handler.Navigation             as Navigation
import qualified Luna.Studio.Handler.Node                   as Node
import qualified Luna.Studio.Handler.Port                   as Port
import qualified Luna.Studio.Handler.Searcher               as Searcher
import qualified Luna.Studio.Handler.Sidebar                as Sidebar
import qualified Luna.Studio.Handler.Undo                   as Undo
import qualified Luna.Studio.Handler.Visualization          as Visualization
import           Luna.Studio.Prelude
import           Luna.Studio.Report
import           Luna.Studio.State.Global                   (State)
import qualified Luna.Studio.State.Global                   as Global


displayProcessingTime :: Bool
displayProcessingTime = False

foreign import javascript safe "console.time($1);"    consoleTimeStart' :: JSString -> IO ()
foreign import javascript safe "console.timeEnd($1);" consoleTimeEnd'   :: JSString -> IO ()


consoleTimeStart, consoleTimeEnd :: String -> IO ()
consoleTimeStart = consoleTimeStart' . convert
consoleTimeEnd   = consoleTimeEnd'   . convert

actions :: LoopRef -> [Event -> Maybe (Command State ())]
actions loop =
    [ App.handle
    , Autolayout.handle
    , Breadcrumbs.handle
    , Camera.handle
    , Clipboard.handle
    , CodeEditor.handle
    , Collaboration.handle
    , Connect.handle
    , ConnectionPen.handle
    , Control.handle
    , Debug.handle
    , Debug.handleEv
    , Graph.handle
    , MultiSelection.handle
    , Navigation.handle
    , Node.handle
    , Port.handle
    , Sidebar.handle
    , Undo.handle
    , ProjectManager.handle
    , Searcher.handle (scheduleEvent loop)
    , Visualization.handle
    ]

runCommands :: [Event -> Maybe (Command State ())] -> Event -> Command State ()
runCommands cmds event = sequence_ . catMaybes $ fmap ($ event) cmds

preprocessEvent :: Event -> IO Event
preprocessEvent ev = do
    let batchEvent    = BatchEventPreprocessor.process ev
        shortcutEvent = ShortcutEventPreprocessor.process ev
    customEvent   <- CustomEventPreprocessor.process ev
    return $ fromMaybe ev $ getLast $ Last batchEvent <> Last customEvent <> Last shortcutEvent

processEvent :: LoopRef -> Event -> IO ()
processEvent loop ev = modifyMVar_ (loop ^. Loop.state) $ \state -> do
    realEvent <- preprocessEvent ev
    when displayProcessingTime $ do
        consoleTimeStart $ (realEvent ^. Event.name) <>" show and force"
        --putStrLn . show . length $ show realEvent
        JS.Debug.error (convert $ realEvent ^. Event.name) realEvent
        consoleTimeEnd $ (realEvent ^. Event.name) <> " show and force"
        consoleTimeStart (realEvent ^. Event.name)
    timestamp <- getCurrentTime
    let state' = state & Global.lastEventTimestamp .~ timestamp
    handle (handleExcept state realEvent) $ do
        newState <- execCommand (runCommands (actions loop) realEvent >> renderIfNeeded) state'
        when displayProcessingTime $
            consoleTimeEnd (realEvent ^. Event.name)
        return newState

connectEventSources :: WebSocket -> LoopRef -> IO ()
connectEventSources conn loop = do
    let handlers = [ JSHandlers.webSocketHandler conn
                   , JSHandlers.atomHandler
                   , JSHandlers.sceneResizeHandler
                   ]
        mkSource (AddHandler rh) = rh $ scheduleEvent loop
    sequence_ $ mkSource <$> handlers

handleExcept :: State -> Event -> JSException -> IO State
handleExcept oldState event except = do
    error $ "JavaScriptException: " <> show except <> "\n\nwhile processing: " <> show event
    return oldState


scheduleEvent :: LoopRef -> Event -> IO ()
scheduleEvent loop = Loop.schedule loop . processEvent loop

scheduleInit :: LoopRef -> IO ()
scheduleInit loop = scheduleEvent loop Event.Init
