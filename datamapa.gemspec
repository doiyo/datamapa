# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'datamapa/version'

Gem::Specification.new do |spec|
  spec.name          = "datamapa"
  spec.version       = DataMapa::VERSION
  spec.authors       = ["Yosuke Doi"]
  spec.email         = ["doinchi@gmail.com"]
  spec.description   = 'A minimalistic Data Mapper for removing model dependency on Active Record'
  spec.summary       = 'Data Mapper using Active Record'
  spec.homepage      = 'https://github.com/doiyo/datamapa'
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency 'activerecord', '~> 4.0.2'

  spec.add_development_dependency 'rake', '~> 10.1.1'
  spec.add_development_dependency 'minitest', '~> 4.2'
  spec.add_development_dependency 'mocha', '~> 1.0.0'
end
