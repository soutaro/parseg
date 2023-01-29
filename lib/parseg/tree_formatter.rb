module Parseg
  class TreeFormatter
    def format(result)
      format0(result.tree, result.token_locator)
    end

    def format0(tree, locator)
      tree.each.map do |t|
        case t
        when Tree::EmptyTree
          nil
        when Tree::TokenTree
          "#{t.expression.token}:`#{locator.string(t.token_id)}`"
        when Tree::NonTerminalTree
          if t.value
            { t.expression.non_terminal.name => format0(t.value, locator) }
          else
            { t.expression.non_terminal.name => nil }
          end

        when Tree::AlternationTree
          format0(t.value, locator)
        when Tree::OptionalTree
          if t.value
            format0(t.value, locator)
          end
        when Tree::RepeatTree
          {
            repeat: t.values.map {|t| format0(t, locator) }
          }
        end
      end
    end
  end
end
