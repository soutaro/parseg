require "securerandom"

module Parseg
  class Parser
    attr_reader :grammar, :tokenizer, :factory
    attr_accessor :error_tolerant_enabled, :skip_unknown_tokens_enabled

    def initialize(grammar:, factory:)
      @grammar = grammar
      @factory = factory
      @skip_unknown_tokens_enabled = false
      @error_tolerant_enabled = true
      @parsing_changes_stack = []
    end

    def parse(non_terminal)
      skips = [] #: Array[Integer]

      if error_tolerant_enabled
        tree = push_stack(non_terminal.name, non_terminal.cut?) { parse_rule(non_terminal.rule, Set[], skips) }

        tree = Tree::NonTerminalTree.new(
          Grammar::Expression::NonTerminalSymbol.new(non_terminal),
          tree,
          next_tree: nil
        )
      else
        @exit_symbol = :"abort_on_parse_error(#{SecureRandom.base64(3)})"
        tree = catch(@exit_symbol) { parse_rule(non_terminal.rule, Set[], skips) }
      end

      Result.new(
        tree: tree,
        factory: factory,
        skip_tokens: skips
      )
    end

    def current_token_id
      factory.current_id
    end

    def current_token_id!
      factory.current_id!
    end

    def current_token_type
      if @leaving_change
        true
      else
        factory.current_type
      end
    end

    def current_token_included_in?(set)
      case type = current_token_type
      when true
        false
      else
        set.include?(type)
      end
    end

    def current_token_equals?(type)
      current_token_type == type
    end

    def advance_token
      before = factory.token_changed?()
      before_pos = factory.token_range(factory.current_id!).end
      factory.advance_token()
      after =
        if factory.current_id
          after_pos = factory.token_range(factory.current_id!).end
          factory.token_changed?()
        else
          before
        end

      case
      when !before && after
        STDERR.puts("Enter into changes with `#{factory.current_type}` in #{current_non_terminal_name}")
      when before && !after
        @leaving_change = true
        STDERR.puts("Leave from changes with `#{factory.current_type}` in #{current_non_terminal_name}")
      when !before && !after
        if factory.inserted_tokens.empty? && (first_deleted = factory.deleted_tokens.first)
          if after_pos
            if before_pos < first_deleted[1][1]
              if after_pos > first_deleted[1][1] + first_deleted[1][2].size
                STDERR.puts("Leave from changes with `#{factory.current_type}` in #{current_non_terminal_name}")
                consuming_changed_token()
                @leaving_change = true
              end
            end
          end
        end
      end
    end

    def current_non_terminal_name
      symbol, bool = @parsing_changes_stack.last

      symbol
    end

    def parsing_change?
      @parsing_changes_stack.last&.[](1) || false
    end

    def push_stack(name, cut)
      if cut
        @parsing_changes_stack.push(
          [
            name,
            parsing_change?
          ]
        )
      end
      yield
    ensure
      if cut
        @parsing_changes_stack.pop()
      end
    end

    def entered_to_changed?
      *_, prev, last = @parsing_changes_stack

      if prev && last
        !prev[1] && parsing_change?
      else
        false
      end
    end

    def consuming_changed_token
      if last = @parsing_changes_stack.last
        last[1] = true
      end
    end

    def skip_non_consumable_tokens(consumable_tokens, skip_tokens)
      if skip_unknown_tokens_enabled
        while type = current_token_type
          break if type == true
          break if current_token_included_in?(consumable_tokens)
          skip_tokens << current_token_id!
          advance_token()
        end
      end
    end

    def new_consumable_tokens(tokens, *exprs)
      tokens = tokens.dup
      exprs.each do |expr|
        if expr
          tokens.merge(expr.consumable_tokens)
        end
      end

      tokens
    end

    def parse_rule(expr, consumable_tokens, skip_tokens)
      summary =
        case expr
        when Grammar::Expression::TokenSymbol
          "token: " + expr.token.to_s
        when Grammar::Expression::NonTerminalSymbol
          "non_terminal: " + expr.non_terminal.name.to_s
        else
          expr.class.to_s.split(/::/).last.downcase + ":"
        end

      Parseg.logger.tagged("#parse_rule(#{summary})") do
        skip_non_consumable_tokens(consumable_tokens + expr.consumable_tokens, skip_tokens)

        case expr
        when Grammar::Expression::TokenSymbol
          if current_token_equals?(expr.token)
            id = current_token_id!
            if factory.token_changed?()
              consuming_changed_token()
            end
            advance_token()

            if expr.next_expr
              next_tree = parse_rule(expr.next_expr, consumable_tokens, skip_tokens)
            end

            Tree::TokenTree.new(expr, id, next_tree: next_tree)
          else
            id = current_token_id

            if error_tolerant_enabled
              if expr.next_expr
                next_tree = parse_rule(expr.next_expr, consumable_tokens, skip_tokens)
              end

              Tree::MissingTree.new(expr, id, next_tree: next_tree)
            else
              throw_error_tree(Tree::MissingTree.new(expr, id, next_tree: nil))
            end
          end

        when Grammar::Expression::NonTerminalSymbol
          push_stack(expr.non_terminal.name, expr.non_terminal.cut?) do
            first_tokens = expr.non_terminal.rule.first_tokens

            if current_token_included_in?(first_tokens)
              value = parse_rule(
                expr.non_terminal.rule,
                new_consumable_tokens(consumable_tokens, expr.next_expr),
                skip_tokens
              )

              if @leaving_change && entered_to_changed?
                STDERR.puts "leaved change from #{expr.non_terminal.name}"
                if expr.non_terminal.cut?
                  @leaving_change = false
                end
              end

              if expr.next_expr
                next_tree = parse_rule(expr.next_expr, consumable_tokens, skip_tokens)
              end

              Tree::NonTerminalTree.new(expr, value, next_tree: next_tree)
            else
              if first_tokens.include?(nil)
                # ok to skip the rule

                if expr.next_expr
                  next_tree = parse_rule(expr.next_expr, consumable_tokens, skip_tokens)
                end

                Tree::NonTerminalTree.new(expr, nil, next_tree: next_tree)
              else
                nid = current_token_id

                if error_tolerant_enabled
                  if expr.next_expr
                    next_tree = parse_rule(expr.next_expr, consumable_tokens, skip_tokens)
                  end

                  Tree::MissingTree.new(expr, nid, next_tree: next_tree)
                else
                  throw_error_tree Tree::MissingTree.new(expr, nid, next_tree: nil)
                end
              end
            end
          end

        when Grammar::Expression::Empty
          if expr.next_expr
            next_tree = parse_rule(expr.next_expr, consumable_tokens, skip_tokens)
          end
          Tree::EmptyTree.new(expr, next_tree: next_tree)

        when Grammar::Expression::Optional
          first_tokens = expr.expression.first_tokens

          if current_token_included_in?(first_tokens)
            value = parse_rule(
              expr.expression,
              new_consumable_tokens(consumable_tokens, expr.next_expr),
              skip_tokens
            )
          end

          if expr.next_expr
            next_tree = parse_rule(expr.next_expr, consumable_tokens, skip_tokens)
          end

          Tree::OptionalTree.new(expr, value, next_tree: next_tree)

        when Grammar::Expression::Alternation
          nid = current_token_id()

          expr.expressions.each do |opt|
            option_first_tokens = opt.first_tokens
            if current_token_included_in?(option_first_tokens) || option_first_tokens.include?(nil)
              value = parse_rule(
                opt,
                new_consumable_tokens(consumable_tokens, expr.next_expr),
                skip_tokens
              )

              if expr.next_expr
                next_tree = parse_rule(expr.next_expr, consumable_tokens, skip_tokens)
              end

              return Tree::AlternationTree.new(expr, value, next_tree: next_tree)
            end
          end

          if error_tolerant_enabled
            if expr.next_expr
              next_tree = parse_rule(expr.next_expr, consumable_tokens, skip_tokens)
            end

            Tree::MissingTree.new(expr, nid, next_tree: next_tree)
          else
            throw_error_tree Tree::MissingTree.new(expr, nid, next_tree: nil)
          end

        when Grammar::Expression::Repeat
          values = [] #: Array[Tree::t]

          consumable_for_content = new_consumable_tokens(consumable_tokens, expr.next_expr, expr.separator)
          if expr.separator.first_tokens.include?(nil)
            consumable_for_content.merge(expr.content.consumable_tokens)
          end
          consumable_for_separator = new_consumable_tokens(consumable_tokens, expr.next_expr, expr.content)
          if expr.content.first_tokens.include?(nil)
            consumable_for_content.merge(expr.separator.consumable_tokens)
          end

          while true
            last_token_id = current_token_id
            values << parse_rule(
              expr.content,
              consumable_for_content,
              skip_tokens
            )

            break unless current_token_id

            separator_first_tokens = expr.separator.first_tokens
            case
            when current_token_included_in?(separator_first_tokens)
              values << parse_rule(
                expr.separator,
                consumable_for_separator,
                skip_tokens
              )
            when separator_first_tokens.include?(nil)
              unless current_token_included_in?(expr.content.first_tokens)
                break
              end
            else
              break
            end

            # Stop loop when one content-separator iteration doesn't consume any token
            if last_token_id == current_token_id
              break
            end
          end

          if expr.next_expr
            next_tree = parse_rule(expr.next_expr, consumable_tokens, skip_tokens)
          end

          Tree::RepeatTree.new(expr, values, next_tree: next_tree)
        end
      end
    end

    def throw_error_tree(tree)
      sym = @exit_symbol
      raise unless sym
      throw sym, tree
    end
  end
end
