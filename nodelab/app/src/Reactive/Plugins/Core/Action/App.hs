module Reactive.Plugins.Core.Action.App
    ( toAction
    ) where

import           Utils.PreludePlus
import           Utils.Vector

import           Event.Event
import           Event.UI                  (UIEvent (AppEvent))
import qualified React.Event.App           as App
import           React.Flux                (mousePageX, mousePageY)
import           Reactive.Commands.Command (Command)
import qualified Reactive.State.Global     as Global



toAction :: Event -> Maybe (Command Global.State ())
toAction (UI (AppEvent  (App.MouseMove evt))) = Just $ do
    let pos = Vector2 (mousePageX evt) (mousePageY evt)
    Global.mousePos .= pos
toAction _                                             = Nothing
