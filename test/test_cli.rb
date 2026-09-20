# frozen_string_literal: true

require "test_helper"
require "open3"
require "tmpdir"

class TestCLI < Minitest::Test
  def swhid_exe
    File.expand_path("../exe/swhid", __dir__)
  end

  def run_cli(*args, stdin: nil)
    cmd = [RbConfig.ruby, swhid_exe, *args]
    stdout, stderr, status = Open3.capture3(*cmd, stdin_data: stdin, binmode: true)
    [stdout, stderr, status]
  end

  def run_git(repo_path, *args)
    stdout, stderr, status = Open3.capture3("git", "-C", repo_path, *args)
    assert status.success?, "git #{args.join(" ")} failed: #{stderr}"
    stdout.strip
  end

  def with_git_repository
    Dir.mktmpdir("swhid-git") do |repo_path|
      run_git(repo_path, "init", "--quiet")
      run_git(repo_path, "symbolic-ref", "HEAD", "refs/heads/main")
      run_git(repo_path, "config", "user.name", "SWHID Test")
      run_git(repo_path, "config", "user.email", "swhid@example.com")
      run_git(repo_path, "config", "commit.gpgsign", "false")
      yield repo_path
    end
  end

  def test_content_simple_text
    stdout, stderr, status = run_cli("content", stdin: "Hello, World!")
    assert status.success?, "CLI failed: #{stderr}"
    assert_equal "swh:1:cnt:b45ef6fec89518d314f546fd6c3025367b721684\n", stdout
  end

  def test_content_binary_data
    # Binary content with bytes that could be corrupted by text mode
    binary = "\x00\x01\x02\xFF\xFE\xFD"
    stdout, stderr, status = run_cli("content", stdin: binary)
    assert status.success?, "CLI failed: #{stderr}"

    # Verify against library
    expected = Swhid.from_content(binary).to_s
    assert_equal "#{expected}\n", stdout
  end

  def test_content_crlf_preserved
    # CRLF line endings must be preserved, not converted to LF
    crlf_content = "line1\r\nline2\r\n"
    stdout, stderr, status = run_cli("content", stdin: crlf_content)
    assert status.success?, "CLI failed: #{stderr}"

    # Verify against library (which correctly handles binary)
    expected = Swhid.from_content(crlf_content).to_s
    assert_equal "#{expected}\n", stdout

    # Verify it's different from LF-only version
    lf_content = "line1\nline2\n"
    lf_swhid = Swhid.from_content(lf_content).to_s
    refute_equal "#{lf_swhid}\n", stdout, "CRLF was converted to LF"
  end

  def test_content_mixed_line_endings
    # Mixed line endings (CR, LF, CRLF)
    mixed = "line1\r\nline2\nline3\rline4"
    stdout, stderr, status = run_cli("content", stdin: mixed)
    assert status.success?, "CLI failed: #{stderr}"

    expected = Swhid.from_content(mixed).to_s
    assert_equal "#{expected}\n", stdout
  end

  def test_content_null_bytes
    # Content with null bytes (common in binary files)
    content = "before\x00after"
    stdout, stderr, status = run_cli("content", stdin: content)
    assert status.success?, "CLI failed: #{stderr}"

    expected = Swhid.from_content(content).to_s
    assert_equal "#{expected}\n", stdout
  end

  def test_content_empty
    stdout, stderr, status = run_cli("content", stdin: "")
    assert status.success?, "CLI failed: #{stderr}"
    # Empty content has a known hash
    assert_equal "swh:1:cnt:e69de29bb2d1d6434b8b29ae775ad8c2e48c5391\n", stdout
  end

  def test_parse_valid_swhid
    stdout, stderr, status = run_cli("parse", "swh:1:cnt:e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    assert status.success?, "CLI failed: #{stderr}"
    assert_includes stdout, "swh:1:cnt:e69de29bb2d1d6434b8b29ae775ad8c2e48c5391"
  end

  def test_snapshot_ignores_remote_tracking_and_note_refs
    with_git_repository do |repo_path|
      File.binwrite(File.join(repo_path, "README"), "snapshot fixture\n")
      run_git(repo_path, "add", "README")
      run_git(repo_path, "commit", "--quiet", "-m", "Initial commit")

      expected_stdout, expected_stderr, expected_status = run_cli("snapshot", repo_path)
      assert expected_status.success?, "CLI failed: #{expected_stderr}"

      head = run_git(repo_path, "rev-parse", "HEAD")
      run_git(repo_path, "update-ref", "refs/remotes/origin/main", head)
      run_git(repo_path, "update-ref", "refs/notes/review", head)

      stdout, stderr, status = run_cli("snapshot", repo_path)
      assert status.success?, "CLI failed: #{stderr}"
      assert_equal expected_stdout, stdout
    end
  end

  def test_directory_uses_gitlink_from_index
    with_git_repository do |repo_path|
      run_git(repo_path, "commit", "--quiet", "--allow-empty", "-m", "Submodule target")
      target = run_git(repo_path, "rev-parse", "HEAD")
      run_git(repo_path, "update-index", "--add", "--cacheinfo", "160000,#{target},submodule")

      submodule_path = File.join(repo_path, "submodule")
      Dir.mkdir(submodule_path)
      File.binwrite(File.join(submodule_path, "local-file"), "not part of the gitlink\n")

      stdout, stderr, status = run_cli("directory", repo_path)
      assert status.success?, "CLI failed: #{stderr}"

      expected = Swhid.from_directory([{ name: "submodule", type: :rev, target: target }])
      assert_equal "#{expected}\n", stdout
    end
  end

  def test_help
    stdout, stderr, status = run_cli("help")
    assert status.success?, "CLI failed: #{stderr}"
    assert_includes stdout, "swhid"
    assert_includes stdout, "content"
    assert_includes stdout, "directory"
  end
end
