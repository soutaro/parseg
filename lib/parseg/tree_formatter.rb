module Parseg
  class TreeFormatter
    def format(result)
      {
        tree: format0(result.tree, result.factory),
        skips: result.skip_tokens.map do |id|
          result.factory.token(id)
        end
      }
    end

    def format0(tree, factory)
      tree.each.map do |t|
        case t
        when Tree::EmptyTree
          nil
        when Tree::TokenTree
          "#{t.expression.token}:`#{factory.token_string!(t.token_id)}`"
        when Tree::NonTerminalTree
          if t.value
            { t.expression.non_terminal.name => format0(t.value, factory) }
          else
            { t.expression.non_terminal.name => nil }
          end

        when Tree::AlternationTree
          format0(t.value, factory)
        when Tree::OptionalTree
          if t.value
            format0(t.value, factory)
          end
        when Tree::RepeatTree
          {
            repeat: t.values.map {|t| format0(t, factory) }
          }
        when Tree::MissingTree
          if id = t.token
            {
              :"🚨🚨🚨missing🚨🚨🚨" => "given=`#{factory.token_string!(id)}`"
            }
          else
            {
              :"🚨🚨🚨missing🚨🚨🚨" => "given=EOF",
              expected: t.expression.first_tokens
            }
          end
        end
      end
    end
  end
end
