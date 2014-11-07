App.UiSwitchComponent = Em.Component.extend
  classNames: ['ui-switch']
  classNameBindings: ['enabled:on']
  enabled: false
  preventFastToggling: false
  togglingDisabled: false
  layoutName: 'main-window/ui-switch'

  click: ->
    unless @get('preventFastToggling')
      @toggleProperty 'enabled'
    else unless @get('togglingDisabled')
      @set 'togglingDisabled', true
      Em.run.later(=>
        @set 'togglingDisabled', false
      , 600)
      @toggleProperty 'enabled'
    false
