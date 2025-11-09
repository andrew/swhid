# frozen_string_literal: true

require "test_helper"

# Cross-implementation tests borrowed from the Python swh-model library
# https://gitlab.softwareheritage.org/swh/devel/swh-model
# These tests ensure we produce the same hashes as the reference implementation

class TestCrossImplementation < Minitest::Test
  # Test data from Python swh-model test_identifiers.py

  def test_empty_directory_matches_python
    # Empty directory should match Git's empty tree hash
    # Python test: test_dir_identifier_empty_directory
    entries = []
    swhid = Swhid.from_directory(entries)

    assert_equal "4b825dc642cb6eb9a060e54bf8d69288fbee4904", swhid.object_hash
  end

  def test_directory_with_entries_matches_python
    # From Python: directory_example
    # Expected ID: d7ed3d2c31d608823be58b1cbe57605310615231
    entries = [
      { name: "README", type: :file, target: "37ec8ea2110c0b7a32fbb0e872f6e7debbf95e21" },
      { name: "Rakefile", type: :file, target: "3bb0e8592a41ae3185ee32266c860714980dbed7" },
      { name: "app", type: :dir, target: "61e6e867f5d7ba3b40540869bc050b0c4fed9e95" },
      { name: "1.megabyte", type: :file, target: "7c2b2fbdd57d6765cdc9d84c2d7d333f11be7fb3" },
      { name: "config", type: :dir, target: "591dfe784a2e9ccc63aaba1cb68a765734310d98" },
      { name: "public", type: :dir, target: "9588bf4522c2b4648bfd1c61d175d1f88c1ad4a5" },
      { name: "development.sqlite3", type: :file, target: "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391" },
      { name: "doc", type: :dir, target: "154705c6aa1c8ead8c99c7916373e3c44012057f" },
      { name: "db", type: :dir, target: "85f157bdc39356b7bc7de9d0099b4ced8b3b382c" },
      { name: "log", type: :dir, target: "5e3d3941c51cce73352dff89c805a304ba96fffe" },
      { name: "script", type: :dir, target: "1b278423caf176da3f3533592012502aa10f566c" },
      { name: "test", type: :dir, target: "035f0437c080bfd8711670b3e8677e686c69c763" },
      { name: "vendor", type: :dir, target: "7c0dc9ad978c1af3f9a4ce061e50f5918bd27138" },
      { name: "will_paginate", type: :rev, perms: "160000", target: "3d531e169db92a16a9a8974f0ae6edf52e52659e" },
      { name: "order", type: :dir, target: "62cdb7020ff920e5aa642c3d4066950dd1f01f4d" },
      { name: "order.", type: :file, target: "0beec7b5ea3f0fdbc95d0dd47f3c5bc275da8a33" },
      { name: "order0", type: :file, target: "bbe960a25ea311d21d40669e93df2003ba9b90a2" }
    ]

    swhid = Swhid.from_directory(entries)

    assert_equal "d7ed3d2c31d608823be58b1cbe57605310615231", swhid.object_hash
  end

  def test_revision_linus_torvalds_matches_python
    # From Python: revision_example (Linus Torvalds, Linux 4.2-rc2)
    # Expected ID: bc0195aad0daa2ad5b0d76cce22b167bc3435590
    metadata = {
      directory: "85a74718d377195e1efd0843ba4f3260bad4fe07",
      parents: ["01e2d0627a9a6edb24c37db45db5ecb31e9de808"],
      author: "Linus Torvalds <torvalds@linux-foundation.org>",
      author_timestamp: 1436735430,
      author_timezone: "-0700",
      committer: "Linus Torvalds <torvalds@linux-foundation.org>",
      committer_timestamp: 1436735430,
      committer_timezone: "-0700",
      message: "Linux 4.2-rc2\n"
    }

    swhid = Swhid.from_revision(metadata)

    assert_equal "bc0195aad0daa2ad5b0d76cce22b167bc3435590", swhid.object_hash
  end

  def test_revision_with_extra_headers_matches_python
    # From Python: revision_with_extra_headers
    # Expected ID: 010d34f384fa99d047cdd5e2f41e56e5c2feee45
    metadata = {
      directory: "85a74718d377195e1efd0843ba4f3260bad4fe07",
      parents: ["01e2d0627a9a6edb24c37db45db5ecb31e9de808"],
      author: "Linus Torvalds <torvalds@linux-foundation.org>",
      author_timestamp: 1436735430,
      author_timezone: "-0700",
      committer: "Linus Torvalds <torvalds@linux-foundation.org>",
      committer_timestamp: 1436735430,
      committer_timezone: "-0700",
      message: "Linux 4.2-rc2\n",
      extra_headers: [
        ["svn-repo-uuid", "046f1af7-66c2-d61b-5410-ce57b7db7bff"],
        ["svn-revision", "10"]
      ]
    }

    swhid = Swhid.from_revision(metadata)

    assert_equal "010d34f384fa99d047cdd5e2f41e56e5c2feee45", swhid.object_hash
  end

  def test_revision_no_message_matches_python
    # From Python: revision_no_message
    # Expected ID: 4cfc623c9238fa92c832beed000ce2d003fd8333
    metadata = {
      directory: "b134f9b7dc434f593c0bab696345548b37de0558",
      parents: [
        "689664ae944b4692724f13b709a4e4de28b54e57",
        "c888305e1efbaa252d01b4e5e6b778f865a97514"
      ],
      author: "Jiang Xin <worldhello.net@gmail.com>",
      author_timestamp: 1428538899,
      author_timezone: "+0800",
      committer: "Jiang Xin <worldhello.net@gmail.com>",
      committer_timestamp: 1428538899,
      committer_timezone: "+0800"
    }

    swhid = Swhid.from_revision(metadata)

    assert_equal "4cfc623c9238fa92c832beed000ce2d003fd8333", swhid.object_hash
  end

  def test_revision_empty_message_matches_python
    # From Python: revision_empty_message
    # Expected ID: 7442cd78bd3b4966921d6a7f7447417b7acb15eb
    metadata = {
      directory: "b134f9b7dc434f593c0bab696345548b37de0558",
      parents: [
        "689664ae944b4692724f13b709a4e4de28b54e57",
        "c888305e1efbaa252d01b4e5e6b778f865a97514"
      ],
      author: "Jiang Xin <worldhello.net@gmail.com>",
      author_timestamp: 1428538899,
      author_timezone: "+0800",
      committer: "Jiang Xin <worldhello.net@gmail.com>",
      committer_timestamp: 1428538899,
      committer_timezone: "+0800",
      message: ""
    }

    swhid = Swhid.from_revision(metadata)

    assert_equal "7442cd78bd3b4966921d6a7f7447417b7acb15eb", swhid.object_hash
  end

  def test_release_linus_torvalds_matches_python
    # From Python: release_example (v2.6.14)
    # Expected ID: 2b10839e32c4c476e9d94492756bb1a3e1ec4aa8
    metadata = {
      name: "v2.6.14",
      target: { hash: "741b2252a5e14d6c60a913c77a6099abe73a854a", type: "rev" },
      author: "Linus Torvalds <torvalds@g5.osdl.org>",
      author_timestamp: 1130457753,
      author_timezone: "-0700",
      message: "Linux 2.6.14 release\n-----BEGIN PGP SIGNATURE-----\nVersion: GnuPG v1.4.1 (GNU/Linux)\n\niD8DBQBDYWq6F3YsRnbiHLsRAmaeAJ9RCez0y8rOBbhSv344h86l/VVcugCeIhO1\nwdLOnvj91G4wxYqrvThthbE=\n=7VeT\n-----END PGP SIGNATURE-----\n"
    }

    swhid = Swhid.from_release(metadata)

    assert_equal "2b10839e32c4c476e9d94492756bb1a3e1ec4aa8", swhid.object_hash
  end

  def test_release_no_author_matches_python
    # From Python: release_no_author
    # Expected ID: 26791a8bcf0e6d33f43aef7682bdb555236d56de
    metadata = {
      name: "v2.6.12",
      target: { hash: "9ee1c939d1cb936b1f98e8d81aeffab57bae46ab", type: "rev" },
      message: "This is the final 2.6.12 release\n-----BEGIN PGP SIGNATURE-----\nVersion: GnuPG v1.2.4 (GNU/Linux)\n\niD8DBQBCsykyF3YsRnbiHLsRAvPNAJ482tCZwuxp/bJRz7Q98MHlN83TpACdHr37\no6X/3T+vm8K3bf3driRr34c=\n=sBHn\n-----END PGP SIGNATURE-----\n"
    }

    swhid = Swhid.from_release(metadata)

    assert_equal "26791a8bcf0e6d33f43aef7682bdb555236d56de", swhid.object_hash
  end

  def test_release_no_message_matches_python
    # From Python: release_no_message
    # Expected ID: b6f4f446715f7d9543ef54e41b62982f0db40045
    metadata = {
      name: "v2.6.12",
      target: { hash: "9ee1c939d1cb936b1f98e8d81aeffab57bae46ab", type: "rev" },
      author: "Linus Torvalds <torvalds@g5.osdl.org>",
      author_timestamp: 1130457753,
      author_timezone: "-0700"
    }

    swhid = Swhid.from_release(metadata)

    assert_equal "b6f4f446715f7d9543ef54e41b62982f0db40045", swhid.object_hash
  end

  def test_release_empty_message_matches_python
    # From Python: release_empty_message
    # Expected ID: 71a0aea72444d396575dc25ac37fec87ee3c6492
    metadata = {
      name: "v2.6.12",
      target: { hash: "9ee1c939d1cb936b1f98e8d81aeffab57bae46ab", type: "rev" },
      author: "Linus Torvalds <torvalds@g5.osdl.org>",
      author_timestamp: 1130457753,
      author_timezone: "-0700",
      message: ""
    }

    swhid = Swhid.from_release(metadata)

    assert_equal "71a0aea72444d396575dc25ac37fec87ee3c6492", swhid.object_hash
  end

  def test_snapshot_empty_matches_python
    # From Python: empty snapshot
    # Expected ID: 1a8893e6a86f444e8be8e7bda6cb34fb1735a00e
    branches = []

    swhid = Swhid.from_snapshot(branches)

    assert_equal "1a8893e6a86f444e8be8e7bda6cb34fb1735a00e", swhid.object_hash
  end

  def test_snapshot_with_dangling_branch_matches_python
    # From Python: dangling_branch
    # Expected ID: c84502e821eb21ed84e9fd3ec40973abc8b32353
    branches = [
      { name: "HEAD", target_type: "dangling" }
    ]

    swhid = Swhid.from_snapshot(branches)

    assert_equal "c84502e821eb21ed84e9fd3ec40973abc8b32353", swhid.object_hash
  end

  def test_snapshot_with_alias_matches_python
    # From Python: unresolved alias
    # Expected ID: 84b4548ea486e4b0a7933fa541ff1503a0afe1e0
    branches = [
      { name: "foo", target_type: "alias", target: "bar" }
    ]

    swhid = Swhid.from_snapshot(branches)

    assert_equal "84b4548ea486e4b0a7933fa541ff1503a0afe1e0", swhid.object_hash
  end

  def test_snapshot_all_types_matches_python
    # From Python: snapshot_example
    # Expected ID: 6e65b86363953b780d92b0a928f3e8fcdd10db36
    branches = [
      { name: "directory", target_type: "directory", target: "1bd0e65f7d2ff14ae994de17a1e7fe65111dcad8" },
      { name: "content", target_type: "content", target: "fe95a46679d128ff167b7c55df5d02356c5a1ae1" },
      { name: "alias", target_type: "alias", target: "revision" },
      { name: "revision", target_type: "revision", target: "aafb16d69fd30ff58afdd69036a26047f3aebdc6" },
      { name: "release", target_type: "release", target: "7045404f3d1c54e6473c71bbb716529fbad4be24" },
      { name: "snapshot", target_type: "snapshot", target: "1a8893e6a86f444e8be8e7bda6cb34fb1735a00e" },
      { name: "dangling", target_type: "dangling" }
    ]

    swhid = Swhid.from_snapshot(branches)

    assert_equal "6e65b86363953b780d92b0a928f3e8fcdd10db36", swhid.object_hash
  end
end
