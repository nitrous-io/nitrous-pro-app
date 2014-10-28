guard 'shell' do
  watch(%r{\A(app|css|spec)/.+\.(html|emblem|slim|erb|css|sass|scss|js|coffee|json)\z}) do |m|
    system 'make build-dev'
  end
end
