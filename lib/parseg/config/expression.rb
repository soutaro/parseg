module Parseg
  class Config
    module Expression
      class TokenExpression
        attr_reader :token

        def initialize(token)
          @token = token
        end
      end

      class NonTerminalExpression
        attr_reader :name

        def initialize(name)
          @name = name
        end
      end

      class RepeatingNonTerminalExpression
        attr_reader :non_terminal, :separator_token, :allow_empty, :trailing_token

        def initialize(non_terminal:, separator_token:, allow_empty:, trailing_token:)
          @non_terminal = non_terminal
          @separator_token = separator_token
          @allow_empty = allow_empty
          @trailing_token = trailing_token
        end
      end

      class AlternationExpression
        attr_reader :exprs, :allow_empty

        def initialize(exprs:, allow_empty:)
          @exprs = exprs
          @allow_empty = allow_empty
        end
      end
    end
  end
end
