module Luna.Atom.Handler.Backend.ProjectManager
    ( handle
    ) where


import           JS.Atom
import qualified Empire.API.Atom.OpenFile           as OpenFile
import qualified Empire.API.Atom.IsSaved            as IsSaved
import qualified Empire.API.Response                as Response
import qualified Luna.Atom.Action.Batch              as BatchCmd (closeFile, isSaved, openFile, saveFile, setProject)
import           Luna.Atom.Action.Command            (Command)
import qualified Luna.Atom.Event.Batch               as Batch
import           Luna.Atom.Event.Event               (Event (Batch, Atom))
import           Luna.Atom.Event.Internal            (InternalEvent(..), ActionType(..))
import           Luna.Atom.Handler.Backend.Common    (doNothing, handleResponse)
import           Luna.Prelude
import           Luna.Atom.State.Global              (State)
import           Data.Char                          (toUpper)

handle :: Event -> Maybe (Command State ())

handle (Atom (InternalEvent SetProject path)) = Just $ BatchCmd.setProject path
handle (Atom (InternalEvent CloseFile path))  = Just $ BatchCmd.closeFile path
handle (Atom (InternalEvent OpenFile path))   = Just $ BatchCmd.openFile path
handle (Atom (InternalEvent SaveFile path))   = Just $ BatchCmd.saveFile path
handle (Atom (InternalEvent IsSaved path))    = Just $ BatchCmd.isSaved path

handle (Batch (Batch.ProjectSet response))    = Just $ handleResponse response doNothing doNothing
handle (Batch (Batch.FileOpened response))    = Just $ handleResponse response success doNothing where
    success result = do
        let uri  = response ^. Response.request . OpenFile.filePath
            status = "ok"
        liftIO $ pushStatus (convert "FileSaved") (convert uri) (convert status)
handle (Batch (Batch.FileClosed response))    = Just $ handleResponse response doNothing doNothing
handle (Batch (Batch.FileSaved response))     = Just $ handleResponse response doNothing doNothing
handle (Batch (Batch.IsSaved response))       = Just $ handleResponse response success doNothing where
   success result = do
       let uri  = response ^. Response.request . IsSaved.filePath
           status = map toUpper . show $ result ^. IsSaved.status
       liftIO $ pushStatus (convert "IsSaved") (convert uri) (convert status)

handle _ = Nothing