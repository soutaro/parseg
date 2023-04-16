require "test_helper"

class TokenFactoryTest < Minitest::Test
  Tokenizer = Parseg::StrscanTokenizer.new(
    {
      INTEGER: /\d+/,
      IDENT: /[a-z]\w*/
    },
    /(\s+)|(#[^\n]*)/
  )

  def test_inserted_tokens
    original = Parseg::TokenFactory.new(tokenizer: Tokenizer, prev: <<~TEXT.chomp)
      1 2 3
    TEXT

    changed = original.update(
      [
        [" 4", [1, 5], [1, 5]]
      ]
    )

    assert_equal "1 2 3 4", changed.input

    assert_equal(
      { 3 => [:INTEGER, 4, "3"], 4 => [:INTEGER, 6, "4"]},
      changed.inserted_tokens
    )

    assert_equal(
      {},
      changed.deleted_tokens
    )
  end

end
