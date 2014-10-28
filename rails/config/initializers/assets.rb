Rails.application.config.assets.version = '1.0'
Rails.application.config.assets.precompile += %w(
  package.json
  main.js
  jquery.js
  login-window/login-window.js
  main-window/main-window.js
  lib/ajax.js
  config.js
)
