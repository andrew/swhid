# frozen_string_literal: true

require "test_helper"
require "open-uri"
require "tmpdir"
require "fileutils"
require "zlib"
require "rubygems/package"

# Tests for directory SWHIDs from extracted package archives
# These tests download packages, extract them, and verify the directory hashes
# match both Git and Software Heritage
class TestPackageDirectories < Minitest::Test
  def setup
    @cache_dir = File.join(Dir.tmpdir, "swhid_package_cache")
    @extract_dir = File.join(Dir.tmpdir, "swhid_extracted")
    Dir.mkdir(@cache_dir) unless Dir.exist?(@cache_dir)
    Dir.mkdir(@extract_dir) unless Dir.exist?(@extract_dir)
  end

  def download_and_cache(url, filename)
    cache_path = File.join(@cache_dir, filename)

    unless File.exist?(cache_path)
      URI.open(url) do |remote|
        File.binwrite(cache_path, remote.read)
      end
    end

    cache_path
  end

  def extract_tar_gz(tarball_path, extract_path)
    permissions = {}
    File.open(tarball_path, "rb") do |file|
      Zlib::GzipReader.wrap(file) do |gz|
        Gem::Package::TarReader.new(gz) do |tar|
          tar.each do |entry|
            dest = File.join(extract_path, entry.full_name)
            if entry.directory?
              FileUtils.mkdir_p(dest)
            elsif entry.file?
              FileUtils.mkdir_p(File.dirname(dest))
              File.binwrite(dest, entry.read)
              mode = entry.header.mode
              if mode
                File.chmod(mode, dest) rescue nil
                permissions[dest] = mode
              end
            elsif entry.symlink?
              FileUtils.mkdir_p(File.dirname(dest))
              File.symlink(entry.header.linkname, dest)
            end
          end
        end
      end
    end
    permissions
  end

  def extract_zip(zip_path, extract_path)
    require "zip" # from rubyzip gem
    Zip::File.open(zip_path) do |zip_file|
      zip_file.each do |entry|
        dest = File.join(extract_path, entry.name)
        if entry.directory?
          FileUtils.mkdir_p(dest)
        else
          FileUtils.mkdir_p(File.dirname(dest))
          entry.extract(dest)
        end
      end
    end
  end

  def test_python_package_directory
    # Python requests 2.31.0 tarball extraction
    # Software Heritage: https://archive.softwareheritage.org/swh:1:dir:8cc447d988f7a3285be93c092a9028cc72baf77b
    url = "https://files.pythonhosted.org/packages/9d/be/10918a2eac4ae9f02f6cfe6414b7a155ccd8f7f9d4380d62fd5b955065c3/requests-2.31.0.tar.gz"
    filename = "requests-2.31.0.tar.gz"

    tarball = download_and_cache(url, filename)
    extract_path = File.join(@extract_dir, "requests")
    FileUtils.rm_rf(extract_path)
    FileUtils.mkdir_p(extract_path)

    permissions = extract_tar_gz(tarball, extract_path)
    dir_path = File.join(extract_path, "requests-2.31.0")

    swhid = Swhid::FromFilesystem.from_directory_path(dir_path, permissions: permissions)

    assert_equal "dir", swhid.object_type
    assert_equal "8cc447d988f7a3285be93c092a9028cc72baf77b", swhid.object_hash
  end

  def test_npm_package_directory
    # NPM lodash 4.17.21 tarball extraction
    # Software Heritage: https://archive.softwareheritage.org/swh:1:dir:218534bee8c4a3747459845330228bfac854715b
    url = "https://registry.npmjs.org/lodash/-/lodash-4.17.21.tgz"
    filename = "lodash-4.17.21.tgz"

    tarball = download_and_cache(url, filename)
    extract_path = File.join(@extract_dir, "npm")
    FileUtils.rm_rf(extract_path)
    FileUtils.mkdir_p(extract_path)

    permissions = extract_tar_gz(tarball, extract_path)
    dir_path = File.join(extract_path, "package")

    swhid = Swhid::FromFilesystem.from_directory_path(dir_path, permissions: permissions)

    assert_equal "dir", swhid.object_type
    assert_equal "218534bee8c4a3747459845330228bfac854715b", swhid.object_hash
  end

  def test_cargo_package_directory
    # Rust serde 1.0.0 crate extraction
    # Software Heritage: https://archive.softwareheritage.org/swh:1:dir:2006e18d039fb1d83d93155917fd720f5cad5980
    url = "https://static.crates.io/crates/serde/serde-1.0.0.crate"
    filename = "serde-1.0.0.crate"

    tarball = download_and_cache(url, filename)
    extract_path = File.join(@extract_dir, "cargo")
    FileUtils.rm_rf(extract_path)
    FileUtils.mkdir_p(extract_path)

    permissions = extract_tar_gz(tarball, extract_path)
    dir_path = File.join(extract_path, "serde-1.0.0")

    swhid = Swhid::FromFilesystem.from_directory_path(dir_path, permissions: permissions)

    assert_equal "dir", swhid.object_type
    assert_equal "2006e18d039fb1d83d93155917fd720f5cad5980", swhid.object_hash
  end

  def test_maven_jar_directory
    # Maven junit-jupiter-api 5.9.0 JAR extraction
    # Software Heritage: https://archive.softwareheritage.org/swh:1:dir:6bbdb8d5132401f3149fbfa6bf3a4de94216b170
    url = "https://repo1.maven.org/maven2/org/junit/jupiter/junit-jupiter-api/5.9.0/junit-jupiter-api-5.9.0.jar"
    filename = "junit-jupiter-api-5.9.0.jar"

    jar = download_and_cache(url, filename)
    extract_path = File.join(@extract_dir, "maven")
    FileUtils.rm_rf(extract_path)
    FileUtils.mkdir_p(extract_path)

    extract_zip(jar, extract_path)

    swhid = Swhid::FromFilesystem.from_directory_path(extract_path)

    assert_equal "dir", swhid.object_type
    assert_equal "6bbdb8d5132401f3149fbfa6bf3a4de94216b170", swhid.object_hash
  end
end
