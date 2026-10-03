# frozen_string_literal: true

require "test_helper"
require "open3"
require "tmpdir"
require "json"

class TestCLI < Minitest::Test
  HELLO_SWHID = "swh:1:cnt:3b18e512dba79e4c8300dd08aeb37f8e728b8dad"

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
      run_git(repo_path, "config", "tag.gpgsign", "false")
      yield repo_path
    end
  end

  def test_content_simple_text
    stdout, stderr, status = run_cli("content", "-f", "raw", stdin: "Hello, World!")
    assert status.success?, "CLI failed: #{stderr}"
    assert_equal "swh:1:cnt:b45ef6fec89518d314f546fd6c3025367b721684\n", stdout
  end

  def test_content_binary_data
    # Binary content with bytes that could be corrupted by text mode
    binary = "\x00\x01\x02\xFF\xFE\xFD"
    stdout, stderr, status = run_cli("content", "-f", "raw", stdin: binary)
    assert status.success?, "CLI failed: #{stderr}"

    # Verify against library
    expected = Swhid.from_content(binary).to_s
    assert_equal "#{expected}\n", stdout
  end

  def test_content_crlf_preserved
    # CRLF line endings must be preserved, not converted to LF
    crlf_content = "line1\r\nline2\r\n"
    stdout, stderr, status = run_cli("content", "-f", "raw", stdin: crlf_content)
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
    stdout, stderr, status = run_cli("content", "-f", "raw", stdin: mixed)
    assert status.success?, "CLI failed: #{stderr}"

    expected = Swhid.from_content(mixed).to_s
    assert_equal "#{expected}\n", stdout
  end

  def test_content_null_bytes
    # Content with null bytes (common in binary files)
    content = "before\x00after"
    stdout, stderr, status = run_cli("content", "-f", "raw", stdin: content)
    assert status.success?, "CLI failed: #{stderr}"

    expected = Swhid.from_content(content).to_s
    assert_equal "#{expected}\n", stdout
  end

  def test_content_empty
    stdout, stderr, status = run_cli("content", "-f", "raw", stdin: "")
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

      stdout, stderr, status = run_cli("directory", repo_path, "-f", "raw")
      assert status.success?, "CLI failed: #{stderr}"

      expected = Swhid.from_directory([{ name: "submodule", type: :rev, target: target }])
      assert_equal "#{expected}\n", stdout
    end
  end

  def test_directory_uses_nested_git_index_permissions
    with_git_repository do |repo_path|
      nested_path = File.join(repo_path, "nested")
      Dir.mkdir(nested_path)
      script_path = File.join(nested_path, "script")
      File.binwrite(script_path, "#!/bin/sh\necho test\n")
      run_git(repo_path, "add", "nested/script")
      run_git(repo_path, "update-index", "--chmod=+x", "nested/script")

      stdout, stderr, status = run_cli("directory", repo_path, "-f", "raw")
      assert status.success?, "CLI failed: #{stderr}"

      content = Swhid.from_content(File.binread(script_path))
      nested = Swhid.from_directory([{ name: "script", type: :exec, target: content.object_hash }])
      expected = Swhid.from_directory([{ name: "nested", type: :dir, target: nested.object_hash }])
      assert_equal "#{expected}\n", stdout
    end
  end

  def test_revision_and_release_match_git_object_ids
    with_git_repository do |repo_path|
      File.binwrite(File.join(repo_path, "README"), "Git object fixture\n")
      run_git(repo_path, "add", "README")
      run_git(repo_path, "commit", "--quiet", "-m", "Initial commit")

      commit_oid = run_git(repo_path, "rev-parse", "HEAD")
      revision_stdout, revision_stderr, revision_status = run_cli("revision", repo_path, "-f", "raw")
      assert revision_status.success?, "CLI failed: #{revision_stderr}"
      assert_equal "swh:1:rev:#{commit_oid}\n", revision_stdout

      run_git(repo_path, "tag", "--annotate", "v1.0.0", "--message", "Release 1.0.0")
      tag_oid = run_git(repo_path, "rev-parse", "refs/tags/v1.0.0")
      release_stdout, release_stderr, release_status = run_cli("release", repo_path, "v1.0.0", "-f", "raw")
      assert release_status.success?, "CLI failed: #{release_stderr}"
      assert_equal "swh:1:rel:#{tag_oid}\n", release_stdout
    end
  end

  def test_help
    stdout, stderr, status = run_cli("help")
    assert status.success?, "CLI failed: #{stderr}"
    assert_includes stdout, "swhid"
    assert_includes stdout, "content"
    assert_includes stdout, "directory"
  end

  def test_default_text_matches_parse_output
    stdout, stderr, status = run_cli("content", stdin: "hello world\n")
    assert status.success?, stderr
    assert_empty stderr
    assert_equal <<~TEXT, stdout
      SWHID: #{HELLO_SWHID}
      Core:  #{HELLO_SWHID}
      Type:  cnt
      Hash:  3b18e512dba79e4c8300dd08aeb37f8e728b8dad
    TEXT
    parsed, parse_stderr, parse_status = run_cli("parse", HELLO_SWHID)
    assert parse_status.success?, parse_stderr
    assert_equal stdout, parsed
  end

  def test_output_formats_and_option_positions
    %w[text raw json jsonl].each do |format|
      before, stderr, status = run_cli("parse", "--format", format, HELLO_SWHID)
      assert status.success?, stderr
      after, stderr, status = run_cli("parse", HELLO_SWHID, "-f", format)
      assert status.success?, stderr
      assert_equal before, after
      case format
      when "raw"
        assert_equal "#{HELLO_SWHID}\n", after
      when "json", "jsonl"
        assert_equal({
          "swhid" => HELLO_SWHID,
          "core" => HELLO_SWHID,
          "object_type" => "cnt",
          "object_hash" => "3b18e512dba79e4c8300dd08aeb37f8e728b8dad",
          "qualifiers" => {}
        }, JSON.parse(after))
        assert_equal 1, after.lines.size if format == "jsonl"
        assert_operator after.lines.size, :>, 1 if format == "json"
      end
    end
  end

  def test_go_flag_spellings
    %w[-f -format --format].each do |flag|
      [[flag, "raw"], ["#{flag}=raw"]].each do |options|
        stdout, stderr, status = run_cli("parse", HELLO_SWHID, *options)
        assert status.success?, stderr
        assert_equal "#{HELLO_SWHID}\n", stdout
      end
    end
    %w[-q -qualifier --qualifier].each do |flag|
      [[flag, "path=/file"], ["#{flag}=path=/file"]].each do |options|
        stdout, stderr, status = run_cli("content", "-f", "raw", *options, stdin: "hello world\n")
        assert status.success?, stderr
        assert_equal "#{HELLO_SWHID};path=/file\n", stdout
      end
    end
  end

  def test_option_terminator
    stdout, stderr, status = run_cli("parse", "--format", "raw", "--", HELLO_SWHID)
    assert status.success?, stderr
    assert_equal "#{HELLO_SWHID}\n", stdout
    stdout, stderr, status = run_cli("directory", "--", "--help")
    assert_equal 1, status.exitstatus
    assert_empty stdout
    assert_includes stderr, "Path does not exist: --help"
  end

  def test_usage_errors_write_only_to_stderr
    [
      ["unknown"], ["content", "-f", "yaml"], ["content", "--unknown"],
      ["content", "-f"], ["content", "-f="], ["content", "--form", "raw"],
      ["content", "file.txt"], ["-f", "json", "content"],
      ["parse"], ["parse", HELLO_SWHID, "extra"],
      ["directory"], ["directory", ".", "extra"],
      ["revision"], ["revision", ".", "HEAD", "extra"],
      ["release"], ["release", "."], ["release", ".", "tag", "extra"],
      ["snapshot"], ["snapshot", ".", "extra"],
      ["content", "-q", "origin"], ["content", "-q", ""], ["content", "-q", "=value"],
      ["content", "-q", "path=/a", "-q", "path=/b"],
      ["parse", HELLO_SWHID, "-q", "path=/a"]
    ].each do |args|
      stdout, stderr, status = run_cli(*args, stdin: "hello world\n")
      assert_equal 2, status.exitstatus, args.inspect
      assert_empty stdout, args.inspect
      assert_includes stderr, "Error:", args.inspect
    end
  end

  def test_command_errors_write_only_to_stderr
    Dir.mktmpdir do |directory|
      [["parse", "invalid"], ["directory", File.join(directory, "missing")],
       ["revision", directory], ["release", directory, "missing"], ["snapshot", directory]].each do |args|
        stdout, stderr, status = run_cli(*args)
        assert_equal 1, status.exitstatus, args.inspect
        assert_empty stdout
        assert_includes stderr, "Error:"
      end
    end
  end

  def test_version
    %w[version --version -version].each do |command|
      stdout, stderr, status = run_cli(command)
      assert status.success?, stderr
      assert_empty stderr
      assert_equal "swhid #{Swhid::VERSION}\n", stdout
    end
  end

  def test_help_streams
    [[], ["--help"], ["-h"], ["help"]].each do |args|
      stdout, stderr, status = run_cli(*args)
      assert status.success?, stderr
      assert_empty stderr
      assert_includes stdout, "text, raw, json, jsonl"
    end
    stdout, stderr, status = run_cli("content", "--help")
    assert status.success?
    assert_empty stdout
    assert_includes stderr, "Usage: swhid content"
  end

  def test_qualifiers_are_escaped_and_round_trip_through_parse
    path = "/a b+c%20;d?#\u00a0é"
    stdout, stderr, status = run_cli("content", "-f", "jsonl", "-q", "path=#{path}",
                                    "-q", "origin=https://example.com/a+b?q=x#y", stdin: "hello world\n")
    assert status.success?, stderr
    data = JSON.parse(stdout)
    assert_equal path, data.fetch("qualifiers").fetch("path")
    assert_equal "#{HELLO_SWHID};origin=https://example.com/a+b?q=x#y;path=/a%20b+c%2520%3Bd%3F%23%C2%A0é", data.fetch("swhid")
    parsed, stderr, status = run_cli("parse", data.fetch("swhid"), "-f", "jsonl")
    assert status.success?, stderr
    assert_equal data, JSON.parse(parsed)
  end

  def test_invalid_qualifier_values
    ["path=relative", "origin=relative", "lines=0", "bytes=-1", "lines=4-2", "unknown=value",
     "visit=#{HELLO_SWHID}", "anchor=#{HELLO_SWHID}", "path=/a\nb"].each do |qualifier|
      stdout, stderr, status = run_cli("content", "-q", qualifier, stdin: "hello world\n")
      assert_equal 1, status.exitstatus, qualifier
      assert_empty stdout
      refute_empty stderr
    end
    stdout, stderr, status = run_cli("content", "-q", "lines=1", "-q", "bytes=0", stdin: "hello world\n")
    assert_equal 1, status.exitstatus
    assert_empty stdout
    assert_includes stderr, "cannot be combined"
  end

  def test_parse_rejects_malformed_qualifiers
    [";", ";path=/a;", ";path=/a;;lines=1", ";path=/a;path=/b", ";path=/a b",
     ";path=/a%", ";path=/a%ZZ"].each do |suffix|
      stdout, stderr, status = run_cli("parse", HELLO_SWHID + suffix)
      assert_equal 1, status.exitstatus, suffix
      assert_empty stdout
      refute_empty stderr
    end
  end

  def test_content_spool_is_removed
    Dir.mktmpdir do |directory|
      stdout, stderr, status = Open3.capture3(
        { "TMPDIR" => directory, "TMP" => directory, "TEMP" => directory },
        RbConfig.ruby, swhid_exe, "content", "-f", "raw",
        stdin_data: "hello world\n", binmode: true
      )
      assert status.success?, stderr
      assert_equal "#{HELLO_SWHID}\n", stdout
      assert_empty Dir.children(directory)
    end
  end

  def test_revision_resolves_annotated_tags
    with_git_repository do |repo_path|
      run_git(repo_path, "commit", "--quiet", "--allow-empty", "-m", "Commit")
      run_git(repo_path, "tag", "--annotate", "example", "--message", "Tag")
      run_git(repo_path, "tag", "--annotate", "nested", "example", "--message", "Nested tag")
      expected = "swh:1:rev:#{run_git(repo_path, 'rev-parse', 'HEAD')}\n"
      %w[HEAD example nested].each do |ref|
        stdout, stderr, status = run_cli("revision", repo_path, ref, "-f", "raw")
        assert status.success?, stderr
        assert_equal expected, stdout
      end
    end
  end

  def test_snapshot_includes_detached_head
    with_git_repository do |repo_path|
      run_git(repo_path, "commit", "--quiet", "--allow-empty", "-m", "Commit")
      branch_oid = run_git(repo_path, "rev-parse", "HEAD")
      run_git(repo_path, "checkout", "--quiet", "--detach", "HEAD")
      run_git(repo_path, "commit", "--quiet", "--allow-empty", "-m", "Detached commit")
      head_oid = run_git(repo_path, "rev-parse", "HEAD")
      stdout, stderr, status = run_cli("snapshot", repo_path, "-f", "raw")
      assert status.success?, stderr
      expected = Swhid.from_snapshot([
        { name: "HEAD", target_type: "revision", target: head_oid },
        { name: "refs/heads/main", target_type: "revision", target: branch_oid }
      ])
      assert_equal "#{expected}\n", stdout
    end
  end
end
