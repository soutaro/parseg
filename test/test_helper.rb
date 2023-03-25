# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "parseg"

require "minitest/autorun"

module TreeAssertion
  def assert_tree(tree, pred, locator:)
    assert_equal [pred], translate(tree, locator: locator)
  end

  def translate(tree, locator:)
    tree.each.flat_map do |tree|
      case tree
      when Parseg::Tree::TokenTree
        _id, type, _offset, value = locator.token(tree.token_id)
        [
          [type, value]
        ]
      when Parseg::Tree::NonTerminalTree
        [
          {
            tree.expression.non_terminal.name => translate(tree.value, locator: locator)
          }
        ]
      when Parseg::Tree::EmptyTree
        []
      when Parseg::Tree::AlternationTree
        translate(tree.value, locator: locator)
      when Parseg::Tree::OptionalTree
        if tree.value
          translate(tree.value, locator: locator)
        else
          []
        end
      when Parseg::Tree::RepeatTree
        tree.values.flat_map do |t|
          translate(t, locator: locator)
        end
      when Parseg::Tree::MissingTree
        if tree.token
          _, type, _, _value = locator.token(tree.token)
          {
            unexpected: type
          }
        else
          { unexpected: nil }
        end
      end
    end
  end
end
