module Parseg
  class Parser
    attr_reader :grammar, :tokenizer, :token_locator

    def initialize(grammar:, tokenizer:)
      @grammar = grammar
      @tokenizer = tokenizer
      @token_locator = TokenLocator.new()
      @token_id = 0
      @level = 0
    end

    def advance_token
      last_token = @next_token

      if (type, offset, value = tokenizer.next_token)
        @token_id += 1
        nt = @next_token = [@token_id, type, offset, value]
        token_locator.register_token(nt)
      else
        @next_token = nil
      end

      last_token
    end

    def advance_token!
      advance_token or raise
    end

    def next_token
      @next_token
    end

    def next_type
      next_token&.[](1)
    end

    def next_token!
      @next_token || raise
    end

    def parse(non_terminal)
      advance_token
      tree = parse_rule(non_terminal.rule)

      Result.new(tree: tree, token_locator: token_locator)
    end

    def parse_rule(expr)
      @level += 1

      case expr
      when Grammar::Expression::TokenSymbol
        puts((" " * @level) + "token: " + expr.token.to_s)
      when Grammar::Expression::NonTerminalSymbol
        puts((" " * @level) + "non_terminal: " + expr.non_terminal.name.to_s)
      else
        puts((" " * @level) + expr.class.to_s.split(/::/).last.downcase)
      end

      case expr
      when Grammar::Expression::TokenSymbol
        if next_type == expr.token
          id, _, _, _ = advance_token!

          if expr.next_expr
            next_tree = parse_rule(expr.next_expr)
          end

          Tree::TokenTree.new(expr, id, next_tree: next_tree)
        else
          raise "Unexpected token: #{next_token} where #{expr.token} is expected"
        end

      when Grammar::Expression::NonTerminalSymbol
        first_tokens = expr.non_terminal.rule.first_tokens
        if first_tokens.include?(next_type)
          value = parse_rule(expr.non_terminal.rule)

          if expr.next_expr
            next_tree = parse_rule(expr.next_expr)
          end

          Tree::NonTerminalTree.new(expr, value, next_tree: next_tree)
        else
          if first_tokens.include?(nil)
            # ok to skip the rule

            if expr.next_expr
              next_tree = parse_rule(expr.next_expr)
            end

            Tree::NonTerminalTree.new(expr, nil, next_tree: next_tree)
          else
            raise "Unexpected token: #{next_token} where #{first_tokens} is expected for #{expr.non_terminal.name}"
          end
        end

      when Grammar::Expression::Empty
        if expr.next_expr
          next_tree = parse_rule(expr.next_expr)
        end
        Tree::EmptyTree.new(expr, next_tree: next_tree)

      when Grammar::Expression::Optional
        first_tokens = expr.expression.first_tokens

        if first_tokens.include?(next_type)
          value = parse_rule(expr.expression)
        end

        if expr.next_expr
          next_tree = parse_rule(expr.next_expr)
        end

        Tree::OptionalTree.new(expr, value, next_tree: next_tree)

      when Grammar::Expression::Alternation
        expr.expressions.each do |opt|
          if opt.first_tokens.include?(next_type)
            value = parse_rule(opt)

            if expr.next_expr
              next_tree = parse_rule(expr.next_expr)
            end

            return Tree::AlternationTree.new(expr, value, next_tree: next_tree)
          end
        end

        raise "Unexpected token: #{next_token} where #{expr.first_tokens} is expected"

      when Grammar::Expression::Repeat
        values = [] #: Array[Tree::t]

        case expr.leading
        when :required
          values << parse_rule(expr.separator)
        when :optional
          if expr.separator.first_tokens.include?(next_type)
            values << parse_rule(expr.separator)
          end
        when false
          # skip
        end

        while true
          values << parse_rule(expr.content)

          case expr.trailing
          when :required
            values << parse_rule(expr.separator)

            unless expr.content.first_tokens.include?(next_type)
              break
            end
          when :optional
            if expr.separator.first_tokens.include?(next_type)
              values << parse_rule(expr.separator)
            end

            unless expr.content.first_tokens.include?(next_type)
              break
            end
          when false
            if expr.separator.first_tokens.include?(next_type)
              values << parse_rule(expr.separator)
            else
              break
            end
          end
        end

        if expr.next_expr
          next_tree = parse_rule(expr.next_expr)
        end

        Tree::RepeatTree.new(expr, values, next_tree: next_tree)
      end
    ensure
      @level -= 1
    end
  end
end
