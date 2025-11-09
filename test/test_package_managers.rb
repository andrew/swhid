# frozen_string_literal: true

require "test_helper"
require "open-uri"
require "tempfile"

# Tests for real package manager artifacts from various ecosystems
# These tests download actual packages and verify SWHID generation matches expected hashes
# This provides real-world validation across Python (PyPI), Ruby (RubyGems),
# Java (Maven), Rust (Cargo), and JavaScript (NPM) package formats
#
# All expected hashes have been verified with:
# - `git hash-object -t blob <file>` (Git compatibility)
# - Python swh.model library (cross-implementation validation)
# All hashes match across Ruby, Python, and Git implementations
class TestPackageManagers < Minitest::Test
  def setup
    @cache_dir = File.join(Dir.tmpdir, "swhid_package_cache")
    Dir.mkdir(@cache_dir) unless Dir.exist?(@cache_dir)
  end

  def download_and_cache(url, filename)
    cache_path = File.join(@cache_dir, filename)

    unless File.exist?(cache_path)
      puts "Downloading #{filename}..."
      URI.open(url) do |remote|
        File.binwrite(cache_path, remote.read)
      end
    end

    File.binread(cache_path)
  end

  def test_python_package_tarball
    # Download a small Python package from PyPI
    # Example: requests 2.31.0 tarball
    # Software Heritage: https://archive.softwareheritage.org/swh:1:cnt:b0962abc7053dcda90c1f586d00c0fc5b9eb14ab
    url = "https://files.pythonhosted.org/packages/9d/be/10918a2eac4ae9f02f6cfe6414b7a155ccd8f7f9d4380d62fd5b955065c3/requests-2.31.0.tar.gz"
    filename = "requests-2.31.0.tar.gz"

    content = download_and_cache(url, filename)
    swhid = Swhid.from_content(content)

    assert_equal "cnt", swhid.object_type
    assert_equal 40, swhid.object_hash.length
    assert_equal "b0962abc7053dcda90c1f586d00c0fc5b9eb14ab", swhid.object_hash
  end

  def test_rubygems_package
    # Download a small Ruby gem
    # Example: rack 3.0.0
    # Software Heritage: https://archive.softwareheritage.org/swh:1:cnt:dfaf984d9ee45adb6eb89d4cb0f7c9e184286cf3
    url = "https://rubygems.org/downloads/rack-3.0.0.gem"
    filename = "rack-3.0.0.gem"

    content = download_and_cache(url, filename)
    swhid = Swhid.from_content(content)

    assert_equal "cnt", swhid.object_type
    assert_equal 40, swhid.object_hash.length
    assert_equal "dfaf984d9ee45adb6eb89d4cb0f7c9e184286cf3", swhid.object_hash
  end

  def test_maven_jar
    # Download a small Maven artifact
    # Example: junit-jupiter-api 5.9.0
    # Software Heritage: https://archive.softwareheritage.org/swh:1:cnt:6f4cc94aac293d0c557a1b80cee04e16205cc85c
    url = "https://repo1.maven.org/maven2/org/junit/jupiter/junit-jupiter-api/5.9.0/junit-jupiter-api-5.9.0.jar"
    filename = "junit-jupiter-api-5.9.0.jar"

    content = download_and_cache(url, filename)
    swhid = Swhid.from_content(content)

    assert_equal "cnt", swhid.object_type
    assert_equal 40, swhid.object_hash.length
    assert_equal "6f4cc94aac293d0c557a1b80cee04e16205cc85c", swhid.object_hash
  end

  def test_cargo_crate
    # Download a Rust crate from crates.io
    # Example: serde 1.0.0
    url = "https://static.crates.io/crates/serde/serde-1.0.0.crate"
    filename = "serde-1.0.0.crate"

    content = download_and_cache(url, filename)
    swhid = Swhid.from_content(content)

    assert_equal "cnt", swhid.object_type
    assert_equal 40, swhid.object_hash.length
    assert_equal "43f2740a0aad900ff5177bc576a6194cfbab760d", swhid.object_hash
  end

  def test_npm_tarball
    # Download an NPM package tarball
    # Example: lodash 4.17.21
    # Software Heritage: https://archive.softwareheritage.org/swh:1:cnt:f2461356dbb4136645043014138c2f8538081770
    url = "https://registry.npmjs.org/lodash/-/lodash-4.17.21.tgz"
    filename = "lodash-4.17.21.tgz"

    content = download_and_cache(url, filename)
    swhid = Swhid.from_content(content)

    assert_equal "cnt", swhid.object_type
    assert_equal 40, swhid.object_hash.length
    assert_equal "f2461356dbb4136645043014138c2f8538081770", swhid.object_hash
  end

  def test_multiple_packages_produce_different_hashes
    # Verify that different packages produce different SWHIDs
    packages = [
      "requests-2.31.0.tar.gz",
      "rack-3.0.0.gem",
      "lodash-4.17.21.tgz"
    ]

    hashes = packages.map do |filename|
      path = File.join(@cache_dir, filename)
      next unless File.exist?(path)

      content = File.binread(path)
      Swhid.from_content(content).object_hash
    end.compact

    # All hashes should be unique
    assert_equal hashes.length, hashes.uniq.length if hashes.length > 1
  end
end
