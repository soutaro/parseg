module Parseg
  class Grammar
    attr_reader :non_terminals

    module DSL
      def T(symbol)
        Expression::TokenSymbol.new(symbol)
      end

      def NT(non_terminal)
        Expression::NonTerminalSymbol.new(grammar[non_terminal])
      end

      def Opt(expr)
        Expression::Optional.new(expr)
      end

      def Repeat(expr, separator = Expression::Empty.instance)
        Expression::Repeat.new(content: expr, separator: separator)
      end

      def Alt(*exprs)
        Expression::Alternation.new(*exprs)
      end

      def Empty
        Expression::Empty.instance
      end
    end

    def initialize(*names, &block)
      @non_terminals = {}

      names.each do |name|
        self[name]
      end

      if block
        a = Object.new
        grammar = self
        a.singleton_class.define_method(:grammar) { grammar }

        a.extend(DSL)
        __skip__ = a.instance_exec(self, &block)
      end
    end

    def [](name)
      non_terminals[name] ||= NonTerminal.new(name)
    end

    class NonTerminal
      attr_reader :name

      attr_accessor :rule

      def initialize(name)
        @name = name
        @rule = Expression::Empty.instance
      end

      def closing_token
        if last_expr = rule #: Expression::t?
          while last_expr.next_expr
            last_expr = last_expr.next_expr
          end

          if last_expr.is_a?(Expression::TokenSymbol)
            return last_expr
          end
        end
      end
    end

    module Expression
      module FirstTokensUtil
        def first_tokens
          tokens = my_first_tokens()

          if tokens.include?(nil)
            if next_expr
              tokens.delete(nil)
              tokens.merge(next_expr.first_tokens)
            end
          end

          tokens
        end
      end

      class TokenSymbol
        attr_reader :token, :next_expr

        include FirstTokensUtil

        def initialize(tok, next_expr: nil)
          @token = tok
          @next_expr = next_expr
        end

        def first_tokens
          Set[token]
        end

        def +(expr)
          if next_expr
            self.class.new(token, next_expr: next_expr + expr)
          else
            self.class.new(token, next_expr: expr)
          end
        end

        def consumable_tokens
          Set[token] + (next_expr ? next_expr.consumable_tokens : Set[])
        end
      end

      class NonTerminalSymbol
        include FirstTokensUtil

        attr_reader :non_terminal, :next_expr

        def initialize(non_terminal, next_expr: nil)
          @non_terminal = non_terminal
          @next_expr = next_expr
        end

        def my_first_tokens
          non_terminal.rule.first_tokens
        end

        def +(expr)
          if next_expr
            self.class.new(non_terminal, next_expr: next_expr + expr)
          else
            self.class.new(non_terminal, next_expr: expr)
          end
        end

        def consumable_tokens
          toks = non_terminal.rule.consumable_tokens
          if next_expr
            toks.merge(next_expr.consumable_tokens)
          end
          toks
        end
      end

      class Empty
        include FirstTokensUtil

        @@instance = new

        def next_expr
          nil
        end

        def self.instance
          @@instance
        end

        def my_first_tokens
          Set[nil]
        end

        def +(t)
          t
        end

        def consumable_tokens
          if next_expr
            next_expr.consumable_tokens
          else
            Set[]
          end
        end
      end

      class Alternation
        include FirstTokensUtil

        attr_reader :expressions, :next_expr

        def initialize(*exprs, next_expr: nil)
          @expressions = exprs
          @next_expr = next_expr
        end

        def my_first_tokens
          tokens = Set[]

          expressions.each do |expr|
            tokens.merge(expr.first_tokens)
          end

          tokens
        end

        def +(expr)
          if next_expr
            Alternation.new(*expressions, next_expr: next_expr + expr)
          else
            Alternation.new(*expressions, next_expr: expr)
          end
        end

        def consumable_tokens
          toks = Set[] #: Set[Symbol]
          if next_expr
            toks.merge(next_expr.consumable_tokens)
          end

          # Only the first tokens of each alternation can be consumable
          expressions.each do |expr|
            expr.first_tokens.each do |tok|
              toks << tok if tok
            end
          end

          toks
        end
      end

      class Repeat
        include FirstTokensUtil

        attr_reader :content, :separator, :next_expr

        def initialize(content:, separator:, next_expr: nil)
          @content = content
          @separator = separator
          @next_expr = next_expr
        end

        def my_first_tokens
          tokens = Set[]

          tokens.merge(content.first_tokens)

          if tokens.include?(nil)
            tokens.delete(nil)
            tokens.merge(separator.first_tokens)
          end

          tokens
        end

        def +(expr)
          if next_expr
            Repeat.new(content: content, separator: separator, next_expr: next_expr + expr)
          else
            Repeat.new(content: content, separator: separator, next_expr: expr)
          end
        end

        def consumable_tokens
          toks = Set[] #: Set[Symbol]
          if next_expr
              toks.merge(next_expr.consumable_tokens)
          end

          [content, separator].each do |expr|
            expr.first_tokens.each do |tok|
              toks << tok if tok
            end
          end

          toks
        end
      end

      class Optional
        include FirstTokensUtil

        attr_reader :expression, :next_expr

        def initialize(expr, next_expr: nil)
          @expression = expr
          @next_expr = next_expr
        end

        def my_first_tokens
          expression.first_tokens + [nil]
        end

        def +(expr)
          if next_expr
            Optional.new(expression, next_expr: next_expr + expr)
          else
            Optional.new(expression, next_expr: expr)
          end
        end

        def consumable_tokens
          toks = Set[] #: Set[Symbol]
          if next_expr
              toks.merge(next_expr.consumable_tokens)
          end

          if expression
            expression.first_tokens.each do |tok|
              toks << tok if tok
            end
          end

          toks
        end
      end
    end
  end
end
