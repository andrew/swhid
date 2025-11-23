# frozen_string_literal: true

require_relative "lib/swhid/version"

Gem::Specification.new do |spec|
  spec.name = "swhid"
  spec.version = Swhid::VERSION
  spec.authors = ["Andrew Nesbitt"]
  spec.email = ["andrewnez@gmail.com"]

  spec.summary = "Generate and parse SoftWare Hash IDentifiers (SWHIDs)"
  spec.description = "A Ruby library and CLI for generating and parsing SoftWare Hash IDentifiers (SWHIDs). Supports all object types (content, directory, revision, release, snapshot) and qualifiers. Compatible with Git object hashing."
  spec.homepage = "https://github.com/andrew/swhid"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/andrew/swhid"
  spec.metadata["changelog_uri"] = "https://github.com/andrew/swhid/blob/main/CHANGELOG.md"
  spec.metadata["documentation_uri"] = "https://www.swhid.org/specification"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore test/ .github/])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Git repository integration for revision, release, and snapshot commands
  spec.add_dependency "rugged", "~> 1.9"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
