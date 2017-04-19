{-# LANGUAGE DeriveAnyClass    #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes        #-}
{-# OPTIONS_GHC -fno-warn-orphans  #-}
module Node.Editor.React.Model.Node.SidebarNode
    ( module Node.Editor.React.Model.Node.SidebarNode
    , module X
    , NodeId
    , NodeLoc
    ) where

import           Data.Convert                   (Convertible (convert))
import           Data.HashMap.Strict            (HashMap)
import           Empire.API.Data.Node           (NodeId)
import qualified Empire.API.Data.Node           as Empire
import           Empire.API.Data.NodeLoc        (NodeLoc (NodeLoc), NodePath)
import           Luna.Prelude
import           Node.Editor.React.Model.IsNode as X
import           Node.Editor.React.Model.Port   (InPort, InPortTree, OutPort, OutPortIndex (Projection), OutPortTree)
import qualified Node.Editor.React.Model.Port   as Port


data SidebarMode = AddRemove
              | MoveConnect
              deriving (Generic, Eq, NFData, Show)

instance Default SidebarMode where
    def = MoveConnect

data InputNode = InputNode
        { _inputNodeLoc      :: NodeLoc
        , _inputSidebarPorts :: [OutPortTree OutPort]
        , _inputMode         :: SidebarMode
        , _inputFrozenHeight :: Maybe Double
        } deriving (Eq, Generic, NFData, Show)

data OutputNode = OutputNode
        { _outputNodeLoc      :: NodeLoc
        , _outputSidebarPorts :: InPortTree InPort
        , _outputMode         :: SidebarMode
        , _outputFrozenHeight :: Maybe Double
        } deriving (Eq, Generic, NFData, Show)

makeLenses ''InputNode
makeLenses ''OutputNode

type InputNodesMap  = HashMap NodeId InputNode
type OutputNodesMap = HashMap NodeId OutputNode

instance Convertible (NodePath, Empire.InputSidebar) InputNode where
    convert (path, n) = InputNode
        {- inputNodeLoc      -} (NodeLoc path (n ^. Empire.inputNodeId))
        {- inputSidebarPorts -} (convert `fmap2` (n ^. Empire.inputEdgePorts))
        {- inputMode         -} def
        {- inputFrozenHeight -} def

instance Convertible (NodePath, Empire.OutputSidebar) OutputNode where
    convert (path, n) = OutputNode
        {- outputNodeLoc      -} (NodeLoc path (n ^. Empire.outputNodeId))
        {- outputSideBarPorts -} (convert <$> n ^. Empire.outputEdgePorts)
        {- outputMode         -} def
        {- outputFrozenHeight -} def

instance HasNodeLoc InputNode where
    nodeLoc = inputNodeLoc

instance HasNodeLoc OutputNode where
    nodeLoc = outputNodeLoc

instance HasPorts OutputNode where
    inPortsList  = Port.inPortTreeLeafs . view outputSidebarPorts
    outPortsList = const def
    inPortAt pid = outputSidebarPorts . ix pid
    outPortAt    = const ignored

instance HasPorts InputNode where
    inPortsList   = const def
    outPortsList  = concatMap Port.outPortTreeLeafs . view inputSidebarPorts
    inPortAt      = const ignored
    outPortAt ((Projection i):t) = inputSidebarPorts . ix i . ix t
    outPortAt _                  = ignored

class IsNode node => SidebarNode node where
    mode           :: Lens' node SidebarMode
    frozenHeight   :: Lens' node (Maybe Double)
    isInputSidebar :: node -> Bool

    isInMode :: SidebarMode -> node -> Bool
    isInMode mode' n = n ^. mode == mode'

    isInAddRemoveMode :: node -> Bool
    isInAddRemoveMode = isInMode AddRemove

    isInMoveConnectMode :: node -> Bool
    isInMoveConnectMode = isInMode MoveConnect

instance SidebarNode InputNode where
    mode           = inputMode
    frozenHeight   = inputFrozenHeight
    isInputSidebar = const True

instance SidebarNode OutputNode where
    mode           = outputMode
    frozenHeight   = outputFrozenHeight
    isInputSidebar = const False
