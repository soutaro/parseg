module Parseg
  class TreeFormatter
    def format(tree, factory:)
      tree.each.flat_map do |tree|
        case tree
        when Parseg::Tree::TokenTree
          type, _offset, value = factory.token(tree.token_id)
          [
            [type, value]
          ]
        when Parseg::Tree::NonTerminalTree
          if tree.value
            [
              {
                tree.expression.non_terminal.name => format(tree.value, factory: factory)
              }
            ]
          else
            {
              tree.expression.non_terminal.name => []
            }
          end
        when Parseg::Tree::EmptyTree
          []
        when Parseg::Tree::AlternationTree
          format(tree.value, factory: factory)
        when Parseg::Tree::OptionalTree
          if tree.value
            format(tree.value, factory: factory)
          else
            []
          end
        when Parseg::Tree::RepeatTree
          tree.values.flat_map do |t|
            format(t, factory: factory)
          end
        when Parseg::Tree::MissingTree
          if tree.token
            type, _, _value = factory.token(tree.token)
            [
              {
                unexpected: type
              }
            ]
          else
            [
              { unexpected: nil }
            ]
          end
        end
      end
    end
  end
end
