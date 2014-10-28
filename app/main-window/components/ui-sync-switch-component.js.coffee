App.UiSyncSwitchComponent = Em.Component.extend
  classNames: ['ui-sync-switch']
  classNameBindings: ['on']
  layoutName: 'main-window/ui-sync-switch'

  on: false

  click: ->
    @toggleProperty 'on'
