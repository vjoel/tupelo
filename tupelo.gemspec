require 'tupelo/version'

Gem::Specification.new do |s|
  s.name = "tupelo"
  s.version = Tupelo::VERSION

  s.required_rubygems_version = Gem::Requirement.new(">= 0")
  s.authors = ["Joel VanderWerf"]
  s.date = Time.now.strftime "%Y-%m-%d"
  s.description = "Distributed tuplespace."
  s.email = "vjoel@users.sourceforge.net"
  s.extra_rdoc_files = ["README.md", "COPYING"]
  s.files = Dir[
    "README.md", "COPYING", "Rakefile",
    "lib/**/*.rb",
    "bin/**/*.rb",
    "bench/**/*.rb",
    "bugs/**/*.rb",
    "example/**/*.rb",
    "test/**/*.rb"
  ]
  s.test_files = Dir["test/unit/*.rb"]
  s.homepage = "https://github.com/vjoel/tupelo"
  s.license = "BSD"
  s.rdoc_options = [
    "--quiet", "--line-numbers", "--inline-source",
    "--title", "tupelo", "--main", "README.md"]
  s.require_paths = ["lib"]
  s.summary = "Distributed tuplespace"

  s.add_dependency 'object-stream'
end
