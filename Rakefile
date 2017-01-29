# gem authoring stuff
begin
  require 'buildar'

  Buildar.new do |b|
    b.gemspec_file = 'healthy_options.gemspec'
    b.version_file = 'VERSION'
    b.use_git = true
  end
rescue LoadError
  # ok
end
