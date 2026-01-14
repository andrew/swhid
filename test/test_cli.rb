# frozen_string_literal: true

require "test_helper"
require "open3"

class TestCLI < Minitest::Test
  def swhid_exe
    File.expand_path("../exe/swhid", __dir__)
  end

  def run_cli(*args, stdin: nil)
    cmd = [RbConfig.ruby, swhid_exe, *args]
    stdout, stderr, status = Open3.capture3(*cmd, stdin_data: stdin, binmode: true)
    [stdout, stderr, status]
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

  def test_help
    stdout, stderr, status = run_cli("help")
    assert status.success?, "CLI failed: #{stderr}"
    assert_includes stdout, "swhid"
    assert_includes stdout, "content"
    assert_includes stdout, "directory"
  end
end
