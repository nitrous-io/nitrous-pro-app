remote = require 'remote'
Menu = remote.require 'menu'
app = remote.require 'app'
currentWindow = remote.getCurrentWindow()
config = require './config'

App.MainWindowView = klass = Em.View.extend
  elementId: 'main-window-view'
  templateName: 'main-window/main-window'

  didInsertElement: ->
    @_super.apply this, arguments
    menuTemplate = @menuTemplate()
    if config.debug
      menuTemplate.push
        label: 'Debug'
        submenu: [
          { label: 'Reload', accelerator: 'Command+R', click: -> currentWindow.restart() }
          { type: 'separator' }
          { label: 'Toggle Dev Tools', accelerator: 'Alt+Command+I', click: -> currentWindow.toggleDevTools() }
        ]
    menu = Menu.buildFromTemplate(menuTemplate)
    if App.platform.isMac
      Menu.setApplicationMenu(menu)
    else
      currentWindow.setMenu(menu)

  menuTemplate: ->
    if App.platform.isMac
      [
        {
          label: 'Nitrous'
          submenu: [
            { label: 'About Nitrous', selector: 'orderFrontStandardAboutPanel:' }
            { type: 'separator' }
            { label: 'Services', submenu: [] }
            { type: 'separator' }
            { label: 'Hide Nitrous', accelerator: 'Command+H', selector: 'hide:' }
            { label: 'Hide Others', accelerator: 'Command+Shift+H', selector: 'hideOtherApplications:' }
            { label: 'Show All', selector: 'unhideAllApplications:' }
            { type: 'separator' }
            { label: 'Quit', accelerator: 'Command+Q', click: -> app.quit() }
          ]
        }
        {
          label: 'File'
          submenu: [
            { label: 'Close Window', accelerator: 'Command+W', selector: 'performClose:' }
            { type: 'separator' }
            { label: "Logged in as #{App.get('username')}", enabled: false }
            { label: 'Log Out', click: -> App.trigger 'log-out' }
          ]
        }
        {
          label: 'Edit'
          submenu: [
            { label: 'Undo', accelerator: 'Command+Z', selector: 'undo:' }
            { label: 'Redo', accelerator: 'Shift+Command+Z', selector: 'redo:' }
            { type: 'separator' }
            { label: 'Cut', accelerator: 'Command+X', selector: 'cut:' }
            { label: 'Copy', accelerator: 'Command+C', selector: 'copy:' }
            { label: 'Paste', accelerator: 'Command+V', selector: 'paste:' }
            { label: 'Select All', accelerator: 'Command+A', selector: 'selectAll:' }
          ]
        }
        {
          label: 'Window',
          submenu: [
            { label: 'Minimize', accelerator: 'Command+M', selector: 'performMiniaturize:' }
            { label: 'Zoom', selector: 'performZoom:' }
            { type: 'separator' }
            { label: 'Bring All to Front', selector: 'arrangeInFront:' }
          ]
        }
      ]
    else
      [
        {
          label: '&File', submenu: [
            { label: 'Log Out', click: -> App.trigger 'log-out' }
            { type: 'separator' }
            { label: '&Close Window', accelerator: 'Ctrl+W', click: -> currentWindow.close() }
            { type: 'separator' }
            { label: 'E&xit', accelerator: 'Alt+F4', click: -> app.quit() }
          ]
        }
      ]
