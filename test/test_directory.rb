# frozen_string_literal: true

require "test_helper"

class TestDirectory < Minitest::Test
  def test_empty_directory
    entries = []
    swhid = Swhid.from_directory(entries)

    assert_equal "dir", swhid.object_type
    # Hash of empty tree in Git
    assert_equal "4b825dc642cb6eb9a060e54bf8d69288fbee4904", swhid.object_hash
  end

  def test_single_file_entry
    entries = [
      { name: "file.txt", type: :file, target: "94a9ed024d3859793618152ea559a168bbcbb5e2" }
    ]
    swhid = Swhid.from_directory(entries)

    assert_equal "dir", swhid.object_type
    assert_equal 40, swhid.object_hash.length
  end

  def test_multiple_entries
    entries = [
      { name: "a.txt", type: :file, target: "94a9ed024d3859793618152ea559a168bbcbb5e2" },
      { name: "b.txt", type: :file, target: "94a9ed024d3859793618152ea559a168bbcbb5e2" }
    ]
    swhid = Swhid.from_directory(entries)

    assert_equal "dir", swhid.object_type
    assert_equal 40, swhid.object_hash.length
  end

  def test_directory_sorting
    # Directories should be sorted with trailing slash for comparison
    entries = [
      { name: "file", type: :file, target: "94a9ed024d3859793618152ea559a168bbcbb5e2" },
      { name: "dir", type: :dir, target: "94a9ed024d3859793618152ea559a168bbcbb5e2" }
    ]
    swhid1 = Swhid.from_directory(entries)

    entries_reversed = entries.reverse
    swhid2 = Swhid.from_directory(entries_reversed)

    assert_equal swhid1.object_hash, swhid2.object_hash
  end

  def test_different_permissions
    entries = [
      { name: "script.sh", type: :exec, target: "94a9ed024d3859793618152ea559a168bbcbb5e2" }
    ]
    swhid = Swhid.from_directory(entries)

    assert_equal "dir", swhid.object_type
    assert_equal 40, swhid.object_hash.length
  end

  def test_symlink_entry
    entries = [
      { name: "link", type: :symlink, target: "94a9ed024d3859793618152ea559a168bbcbb5e2" }
    ]
    swhid = Swhid.from_directory(entries)

    assert_equal "dir", swhid.object_type
    assert_equal 40, swhid.object_hash.length
  end

  def test_nested_directory
    entries = [
      { name: "subdir", type: :dir, target: "4b825dc642cb6eb9a060e54bf8d69288fbee4904" }
    ]
    swhid = Swhid.from_directory(entries)

    assert_equal "dir", swhid.object_type
    assert_equal 40, swhid.object_hash.length
  end

  def test_custom_permissions
    entries = [
      { name: "file.txt", type: :file, target: "94a9ed024d3859793618152ea559a168bbcbb5e2", perms: "100644" }
    ]
    swhid = Swhid.from_directory(entries)

    assert_equal "dir", swhid.object_type
    assert_equal 40, swhid.object_hash.length
  end

  def test_identifier_target_matches_hash_target
    target = Swhid::Identifier.new(
      object_type: "cnt",
      object_hash: "94a9ed024d3859793618152ea559a168bbcbb5e2"
    )

    from_identifier = Swhid.from_directory([{ name: "file.txt", type: :file, target: target }])
    from_hash = Swhid.from_directory([{ name: "file.txt", type: :file, target: target.object_hash }])

    assert_equal from_hash, from_identifier
  end

  def test_rejects_invalid_target_hash
    assert_raises(Swhid::ValidationError) do
      Swhid.from_directory([{ name: "file.txt", type: :file, target: "z" * 40 }])
    end
  end

  def test_rejects_duplicate_entry_names
    entries = [
      { name: "file.txt", type: :file, target: "94a9ed024d3859793618152ea559a168bbcbb5e2" },
      { name: "file.txt", type: :file, target: "84a9ed024d3859793618152ea559a168bbcbb5e1" }
    ]

    assert_raises(Swhid::ValidationError) { Swhid.from_directory(entries) }
  end

  def test_rejects_duplicate_entry_names_separated_by_sort_order
    entries = [
      { name: "foo", type: :file, target: "94a9ed024d3859793618152ea559a168bbcbb5e2" },
      { name: "foo.txt", type: :file, target: "84a9ed024d3859793618152ea559a168bbcbb5e1" },
      { name: "foo", type: :dir, target: "74a9ed024d3859793618152ea559a168bbcbb5e0" }
    ]

    assert_raises(Swhid::ValidationError) { Swhid.from_directory(entries) }
  end

  def test_rejects_invalid_entry_names
    ["path/name", "null\0name"].each do |name|
      assert_raises(Swhid::ValidationError) do
        Swhid.from_directory([{ name: name, type: :file, target: "94a9ed024d3859793618152ea559a168bbcbb5e2" }])
      end
    end
  end

  def test_accepts_entry_names_with_non_utf8_bytes
    name = "name-\xFF".b

    swhid = Swhid.from_directory([
      { name: name, type: :file, target: "94a9ed024d3859793618152ea559a168bbcbb5e2" }
    ])

    assert_equal "dir", swhid.object_type
  end
end
