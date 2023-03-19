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
      last_token = @current_token

      if (type, offset, value = tokenizer.next_token)
        @token_id += 1
        nt = @current_token = [@token_id, type, offset, value]
        token_locator.register_token(nt)
      else
        @current_token = nil
      end

      last_token
    end

    def advance_token!
      advance_token or raise
    end

    def current_token
      @current_token
    end

    def current_token!
      @current_token || raise
    end

    def token_id
      @current_token&.first
    end

    def token_id!
      token_id or raise
    end

    def token_type
      current_token&.[](1)
    end

    def parse(non_terminal)
      advance_token
      skips = [] #: Array[Integer]
      tree = parse_rule(non_terminal.rule, Set[], skips)

      Result.new(tree: tree, token_locator: token_locator, skip_tokens: skips)
    end

    def with_next_tokens(next_tokens, next_expr)
      if next_expr
        fts = next_expr.first_tokens
        yield(next_tokens + next_expr.first_tokens)
      else
        yield next_tokens
      end
    end

    def skip_unknown_tokens(next_tokens, next_expr, skip_tokens)
      STDERR.puts((" " * (@level + 2)) + ">> skipping tokens other than: #{next_tokens.inspect}")

      with_next_tokens(next_tokens, next_expr) do |next_tokens|
        while token_type
          break if next_tokens.include?(token_type)
          skip_tokens << token_id!
          STDERR.puts((" " * @level) + "  | Skipped #{current_token}")
          advance_token
        end

        current_token
      end
    end

    def parse_rule(expr, next_tokens, skip_tokens)
      @level += 1

      case expr
      when Grammar::Expression::TokenSymbol
        STDERR.puts((" " * @level) + "token: " + expr.token.to_s + ", next_tokens: #{next_tokens}")
      when Grammar::Expression::NonTerminalSymbol
        STDERR.puts((" " * @level) + "non_terminal: " + expr.non_terminal.name.to_s + ", next_tokens: #{next_tokens}")
      else
        STDERR.puts((" " * @level) + expr.class.to_s.split(/::/).last.downcase + ":"  + ", next_tokens: #{next_tokens}")
      end

      skip_unknown_tokens(expr.first_tokens + next_tokens, nil, skip_tokens)

      case expr
      when Grammar::Expression::TokenSymbol
        if token_type == expr.token
          id, _, _, _ = advance_token!

          if expr.next_expr
            next_tree = parse_rule(expr.next_expr, next_tokens, skip_tokens)
          end

          Tree::TokenTree.new(expr, id, next_tree: next_tree)
        else
          id = token_id

          if expr.next_expr
            next_tree = parse_rule(expr.next_expr, next_tokens, skip_tokens)
          end

          Tree::MissingTree.new(expr, id, next_tree: next_tree)
        end

      when Grammar::Expression::NonTerminalSymbol
        first_tokens = expr.non_terminal.rule.first_tokens

        if first_tokens.include?(token_type)
          value = with_next_tokens(next_tokens, expr.next_expr) do |next_tokens|
            parse_rule(expr.non_terminal.rule, next_tokens, skip_tokens)
          end

          if expr.next_expr
            next_tree = parse_rule(expr.next_expr, next_tokens, skip_tokens)
          end

          Tree::NonTerminalTree.new(expr, value, next_tree: next_tree)
        else
          if first_tokens.include?(nil)
            # ok to skip the rule

            if expr.next_expr
              next_tree = parse_rule(expr.next_expr, next_tokens, skip_tokens)
            end

            Tree::NonTerminalTree.new(expr, nil, next_tree: next_tree)
          else
            nid = token_id

            if expr.next_expr
              next_tree = parse_rule(expr.next_expr, next_tokens, skip_tokens)
            end

            Tree::MissingTree.new(expr, nid, next_tree: next_tree)
          end
        end

      when Grammar::Expression::Empty
        if expr.next_expr
          next_tree = parse_rule(expr.next_expr, next_tokens, skip_tokens)
        end
        Tree::EmptyTree.new(expr, next_tree: next_tree)

      when Grammar::Expression::Optional
        first_tokens = expr.expression.first_tokens

        if first_tokens.include?(token_type)
          value = with_next_tokens(next_tokens, expr.next_expr) do |next_tokens|
            parse_rule(expr.expression, next_tokens, skip_tokens)
          end
        end

        if expr.next_expr
          next_tree = parse_rule(expr.next_expr, next_tokens, skip_tokens)
        end

        Tree::OptionalTree.new(expr, value, next_tree: next_tree)

      when Grammar::Expression::Alternation
        nid = token_id()

        expr.expressions.each do |opt|
          if opt.first_tokens.include?(token_type)
            value = with_next_tokens(next_tokens, expr.next_expr) do |next_tokens|
              parse_rule(opt, next_tokens, skip_tokens)
            end

            if expr.next_expr
              next_tree = parse_rule(expr.next_expr, next_tokens, skip_tokens)
            end

            return Tree::AlternationTree.new(expr, value, next_tree: next_tree)
          end
        end

        if expr.next_expr
          next_tree = parse_rule(expr.next_expr, next_tokens, skip_tokens)
        end

        Tree::MissingTree.new(expr, nid, next_tree: next_tree)

      when Grammar::Expression::Repeat
        values = [] #: Array[Tree::t]

        tokens_before_content = with_next_tokens(next_tokens, expr.next_expr) {|next_tokens| next_tokens + expr.content.first_tokens }
        tokens_before_separator = with_next_tokens(next_tokens, expr.next_expr) {|next_tokens| next_tokens + expr.separator.first_tokens }
        if expr.separator.first_tokens.include?(nil)
          tokens_before_separator.merge(expr.content.first_tokens)
        end

        case expr.leading
        when :required
          values << parse_rule(expr.separator, tokens_before_content, skip_tokens)
        when :optional
          if expr.separator.first_tokens.include?(token_type)
            values << parse_rule(expr.separator, tokens_before_content, skip_tokens)
          end
        when false
          # skip
        end

        while current_token
          values << parse_rule(expr.content, tokens_before_separator, skip_tokens)

          if expr.separator.first_tokens.include?(nil)
            if expr.content.first_tokens.include?(token_type)
              next
            end
          end

          case expr.trailing
          when :required
            values << parse_rule(expr.separator, tokens_before_content, skip_tokens)

            unless expr.content.first_tokens.include?(token_type)
              break
            end
          when :optional
            if expr.separator.first_tokens.include?(token_type)
              values << parse_rule(expr.separator, tokens_before_content, skip_tokens)
            end

            unless expr.content.first_tokens.include?(token_type)
              break
            end
          when false
            if expr.separator.first_tokens.include?(token_type)
              values << parse_rule(expr.separator, tokens_before_content, skip_tokens)
            else
              break
            end
          end
        end

        if expr.next_expr
          next_tree = parse_rule(expr.next_expr, next_tokens, skip_tokens)
        end

        Tree::RepeatTree.new(expr, values, next_tree: next_tree)
      end
    ensure
      @level -= 1
    end
  end
end
