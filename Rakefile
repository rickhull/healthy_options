require 'rake/testtask'

task default: :test

desc "Run minitest specs"
Rake::TestTask.new :test do |t|
  t.pattern = 'test/*spec.rb'
end

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
