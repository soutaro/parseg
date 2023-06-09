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
        tree = push_stack(non_terminal.name, non_terminal.block?) { parse_rule(non_terminal.rule, Set[], skips) }

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
      if end_of_change?
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
        @boc = true
        Parseg.logger.debug { "Enter into changes with `#{factory.current_type}` in #{current_non_terminal_name}@#{@parsing_changes_stack.size}" }
      when before && !after
        if inside_block_in_change?
          @eoc = true
          Parseg.logger.debug { "Leave from changes with `#{factory.current_type}`(#{factory.current_token![2]}) in #{current_non_terminal_name}@#{@parsing_changes_stack.size}" }
        end
      else
        @boc = false
        @eoc = false
      end
    end

    def end_of_change?
      @eoc
    end

    def begin_of_change?
      @boc
    end

    def consume_end_of_change
      @eoc = false
    end

    def current_non_terminal_name
      symbol, bool = @parsing_changes_stack.last

      symbol
    end

    def parsing_change?
      if current_token_id
        factory.token_changed?
      else
        false
      end
    end

    def push_stack(name, block)
      if block
        @parsing_changes_stack.push(
          [
            name,
            parsing_change?
          ]
        )
      end
      yield
    ensure
      if block
        @parsing_changes_stack.pop()
      end
    end

    def inside_block_in_change?
      if current = @parsing_changes_stack.last
        current[1]
      else
        false
      end
    end

    def outer_most_block_in_change?
      *_, prev, current = @parsing_changes_stack

      case
      when prev && current
        current[1] && !prev[1]
      when prev
        # Prev fills before current
        prev[1]
      else
        false
      end
    end

    def skip_non_consumable_tokens(consumable_tokens, skip_tokens)
      if skip_unknown_tokens_enabled
        while type = current_token_type
          break if type == true
          break if current_token_included_in?(consumable_tokens)
          Parseg.logger.info { "Skipping token `#{current_token_type}`" }
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
      skip_non_consumable_tokens(consumable_tokens + expr.consumable_tokens, skip_tokens)

      case expr
      when Grammar::Expression::TokenSymbol
        if current_token_equals?(expr.token)
          id = current_token_id!
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
        Parseg.logger.tagged("NT(:#{expr.non_terminal.name})@#{parsing_change? ? "change" : ""}") do
          push_stack(expr.non_terminal.name, expr.non_terminal.block?) do
            first_tokens = expr.non_terminal.rule.first_tokens

            if current_token_included_in?(first_tokens)
              consumable_tokens_for_rule =
                if !first_tokens.include?(nil) && expr.non_terminal.block?
                  new_consumable_tokens(Set[], expr.next_expr)
                else
                  new_consumable_tokens(consumable_tokens, expr.next_expr)
                end

              value = parse_rule(
                expr.non_terminal.rule,
                consumable_tokens_for_rule,
                skip_tokens
              )

              if expr.non_terminal.block?
                Parseg.logger.debug {
                  {
                    outer_most_block: outer_most_block_in_change?,
                    current_token: factory.current_type
                  }.inspect
                }
              end

              if expr.non_terminal.block? && outer_most_block_in_change?
                consume_end_of_change()
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

    def throw_error_tree(tree)
      sym = @exit_symbol
      raise unless sym
      throw sym, tree
    end
  end
end
