module Reactive.Commands.Function.Output
    (registerOutput
    ) where

import           Prologue

import           Empire.API.Data.Node         (NodeId)
import           Empire.API.Data.Output       (Output)
import qualified Object.Widget.FunctionPort   as Model
import qualified React.Stores                 as Stores
import           Reactive.Commands.Command    (Command)
import qualified Reactive.Commands.UIRegistry as UICmd
import           Reactive.State.Global        (State, inRegistry)
import qualified Reactive.State.Global        as Global
import qualified Reactive.State.Graph         as Graph
import qualified Reactive.State.UIElements    as UIElements
import           UI.Handlers.FunctionPort     ()



registerOutput :: NodeId -> Output -> Command State ()
registerOutput nodeId output = do
    let outputModel = Model.fromOutput nodeId output
    outputRef <- Input.create outputModel
    Global.stores . Stores.outputs . at outputNo ?= outputWidget
