# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "parseg"

require "minitest/autorun"

module TreeAssertion
  def assert_tree(tree, pred, factory:)
    assert_equal [pred], translate(tree, factory: factory)
  end

  def translate(tree, factory:)
    tree.each.flat_map do |tree|
      case tree
      when Parseg::Tree::TokenTree
        type, _offset, value = factory.token(tree.token_id)
        [
          [type, value]
        ]
      when Parseg::Tree::NonTerminalTree
        [
          {
            tree.expression.non_terminal.name => translate(tree.value, factory: factory)
          }
        ]
      when Parseg::Tree::EmptyTree
        []
      when Parseg::Tree::AlternationTree
        translate(tree.value, factory: factory)
      when Parseg::Tree::OptionalTree
        if tree.value
          translate(tree.value, factory: factory)
        else
          []
        end
      when Parseg::Tree::RepeatTree
        tree.values.flat_map do |t|
          translate(t, factory: factory)
        end
      when Parseg::Tree::MissingTree
        if tree.token
          type, _, _value = factory.token(tree.token)
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
