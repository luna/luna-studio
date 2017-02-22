module Luna.Studio.Action.Geometry.Constants where

import Luna.Studio.Prelude

gridSize, fontSize, lineHeight, connectionWidth, nodeRadius, nodeRadius', portRadius, nodeExpandedWidth :: Double

gridSize          = 16
fontSize          = 12
lineHeight        = gridSize

connectionWidth   = 2.6
nodeRadius        = 20
nodeRadius'       = nodeRadius - connectionWidth
portRadius        = nodeRadius - connectionWidth/2

nodeExpandedWidth = 160
