Rails.application.config.assets.version = '1.0'
Rails.application.config.assets.precompile += %w(
  package.json
  main.js
  jquery.js
  login-window/login-window.js
  main-window/main-window.js
  lib/ajax.js
  lib/mixpanel-wrapper.js
  lib/mixpanel.js
  lib/logger.js
  config.js
)

if Rails.env.test?
  ["login", "main"].each do |grp|
    path = Rails.root.join("app", "assets", "javascripts", "tests", grp, "**")
    Dir[path].each do |file|
      Rails.application.config.assets.precompile << file
    end
  end
end
