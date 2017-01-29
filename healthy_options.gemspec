Gem::Specification.new do |s|
  s.name = 'healthy_options'
  s.summary = 'Parse a wide but limited variety of command line option styles'
  s.description = <<EOF
* long and short options
* value or not
* use equals for value or not
* short option smashing
EOF
  s.authors = ["Rick Hull"]
  s.homepage = 'https://github.com/rickhull/healthy_options'
  s.license = 'GPL-3.0'
  s.files = %w(
README.md
lib/healthy_options.rb
VERSION
)
  s.required_ruby_version = "~> 2"

  s.version = File.read(File.join(__dir__, 'VERSION'))
end
