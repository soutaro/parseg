require "test_helper"

class TokenFactoryTest < Minitest::Test
  Tokenizer = Parseg::StrscanTokenizer.new(
    {
      INTEGER: /\d+/,
      IDENT: /[a-z]\w*/
    },
    /(\s+)|(#[^\n]*)/
  )

  def test_tokens_inserted
    original = Parseg::TokenFactory.new(tokenizer: Tokenizer, status: <<~TEXT.chomp)
      1 2 3
    TEXT

    changed = original.update(
      [
        [" 4", [1, 5], [1, 5]]
      ]
    )

    assert_equal "1 2 3 4", changed.source

    assert_equal(
      { 3 => [:INTEGER, 4, "3"], 4 => [:INTEGER, 6, "4"]},
      changed.inserted_tokens
    )

    assert_equal(
      {},
      changed.deleted_tokens
    )
  end

  def test_tokens_changed
    original = Parseg::TokenFactory.new(tokenizer: Tokenizer, status: <<~TEXT.chomp)
      1 2 3
    TEXT

    changed = original.update(
      [
        ["x", [1, 2], [1, 3]]
      ]
    )

    assert_equal "1 x 3", changed.source

    assert_equal(
      { 2 => [:IDENT, 2, "x"] },
      changed.inserted_tokens
    )

    assert_equal(
      { 2 => [:INTEGER, 2, "2"] },
      changed.deleted_tokens
    )
  end

  def test_tokens_deleted
    original = Parseg::TokenFactory.new(tokenizer: Tokenizer, status: <<~TEXT.chomp)
      1 2 3
    TEXT

    changed = original.update(
      [
        [" ", [1, 2], [1, 3]]
      ]
    )

    assert_equal "1   3", changed.source

    assert_equal(
      {},
      changed.inserted_tokens
    )

    assert_equal(
      { 2 => [:INTEGER, 2, "2"] },
      changed.deleted_tokens
    )
  end
end
