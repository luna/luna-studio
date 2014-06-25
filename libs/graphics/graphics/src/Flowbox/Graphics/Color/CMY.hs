---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------
{-# LANGUAGE DeriveDataTypeable #-}

module Flowbox.Graphics.Color.CMY where

import Data.Typeable

import Flowbox.Prelude



data CMY a = CMY { cmyC :: a, cmyM :: a, cmyY :: a } deriving (Show, Typeable)
