guard 'shell' do
  watch(%r{\A(src|spec)/.+\.(html|slim|erb|css|sass|scss|js|coffee|json)\z}) do |m|
    system 'rake build'
  end
end
