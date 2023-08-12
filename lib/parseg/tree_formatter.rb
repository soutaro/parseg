module Parseg
  class TreeFormatter
    def format(tree, factory:)
      tree.flat_map do |tree|
        case tree
        when Parseg::Tree::TokenTree
          type, _offset, value = factory.token(tree.token_id)
          [
            [type, value]
          ]
        when Parseg::Tree::NonTerminalTree
          [
            {
              tree.expression.non_terminal.name => format(tree.tree, factory: factory)
            }
          ]
        when Parseg::Tree::EmptyTree
          []
        when Parseg::Tree::AlternationTree
          format(tree.tree, factory: factory)
        when Parseg::Tree::OptionalTree
          format(tree.tree, factory: factory)
        when Parseg::Tree::RepeatTree
          tree.trees.flat_map do |t|
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
