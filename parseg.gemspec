# frozen_string_literal: true

require_relative "lib/parseg/version"

Gem::Specification.new do |spec|
  spec.name = "parseg"
  spec.version = Parseg::VERSION
  spec.authors = ["Soutaro Matsumoto"]
  spec.email = ["matsumoto@soutaro.com"]

  spec.summary = "Parseg is a parser generator"
  spec.description = "Parseg is a LL parser generator"
  spec.homepage = "https://github.com/soutaro/parseg"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/soutaro/parseg.git"
  spec.metadata["changelog_uri"] = "https://github.com/soutaro/parseg/blob/v#{spec.version}/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "yaml", "~> 0.2.1"
  spec.add_dependency "set", "~> 1.0.3"
  spec.add_dependency "strong_json", "~> 2.1.2"
end
