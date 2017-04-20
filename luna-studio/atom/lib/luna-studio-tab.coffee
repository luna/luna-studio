path = require 'path'
{View} = require 'atom-space-pen-views'

uniqueTabNo = 0

module.exports =
class LunaStudioTab extends View
  mountPoint = ""
  initialize: (@uri, @code) ->
      @on 'contextmenu', -> false
      @code.start(@uri, mountPoint)

  @content: ->
    mountPoint = "luna-studio-mount" + uniqueTabNo
    uniqueTabNo = uniqueTabNo + 1
    @div
      id: mountPoint
      =>
        @h1 "Loading ..."

  getTitle:     -> path.basename(@uri)