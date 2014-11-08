remote = require 'remote'
Menu = remote.require 'menu'
app = remote.require 'app'
currentWindow = remote.getCurrentWindow()
config = require './config'

App.LoginWindowView = Em.View.extend
  elementId: 'login-window-view'
  templateName: 'login-window/login-window'

  loginButtonDisabled: (->
    !@get('controller.username') || !@get('controller.password') || @get('controller.loggingIn')
  ).property 'controller.username', 'controller.password', 'controller.loggingIn'

  didReceiveInvalidCredentails: (->
    if @get('controller.invalidCredentials')
      Em.run.scheduleOnce 'afterRender', =>
        @$('.username-field').focus().select()
    ).observes 'controller.invalidCredentials'

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

    Em.run.scheduleOnce 'afterRender', =>
      currentWindow.setResizable(false)
      currentWindow.show()
      currentWindow.focus()
      @$('.username-field').focus().select()

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
            { type: 'separator' }
            { label: 'Bring All to Front', selector: 'arrangeInFront:' }
          ]
        }
      ]
    else
      [
        {
          label: '&File', submenu: [
            { label: 'E&xit', accelerator: 'Alt+F4', click: -> app.quit() }
          ]
        }
      ]
