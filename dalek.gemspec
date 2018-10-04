# frozen_string_literal: true

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'dalek/version'

Gem::Specification.new do |spec|
  spec.name = 'dalek'
  spec.version = Dalek::VERSION
  spec.platform = Gem::Platform::RUBY
  spec.author = 'Kamen Kanev'
  spec.email = 'kamen.e.kanev@gmail.com'
  spec.homepage = 'https://github.com/kanevk/dalek'
  spec.summary = 'Gem useful for deleting of super coupled AR models, the right tool for GDPR User deletion'
  spec.description = <<-DESC
    Gem useful for deleting of super coupled AR models, the right tool for GDPR User deletion
  DESC
  spec.metadata = { 'github' => 'https://github.com/kanevk/dalek' }
  spec.license = 'MIT'

  spec.files = Dir['{lib}/**/*.rb', 'bin/*', 'LICENSE', '*.md']
  spec.bindir = 'bin'

  spec.add_dependency "activerecord", ">= 4.2", "< 6"

  spec.add_development_dependency "bundler", "~> 1.14"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.5.0"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "database_cleaner", "~> 1.5"
  spec.add_development_dependency "sqlite3"
  spec.add_development_dependency "pg"
  spec.add_development_dependency "rubocop"
end

