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
    end

    def parse(non_terminal)
      skips = [] #: Array[Integer]

      if error_tolerant_enabled
        tree = parse_rule(non_terminal.rule, Set[], skips)

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

    def skip_non_consumable_tokens(consumable_tokens, skip_tokens)
      if skip_unknown_tokens_enabled
        while factory.current_type
          break if consumable_tokens.include?(factory.current_type)
          skip_tokens << factory.current_id!
          factory.advance_token()
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
          if factory.current_type == expr.token
            id = factory.current_id!()
            factory.advance_token

            if expr.next_expr
              next_tree = parse_rule(expr.next_expr, consumable_tokens, skip_tokens)
            end

            Tree::TokenTree.new(expr, id, next_tree: next_tree)
          else
            id = factory.current_id

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
          first_tokens = expr.non_terminal.rule.first_tokens

          if first_tokens.include?(factory.current_type)
            value = parse_rule(
              expr.non_terminal.rule,
              new_consumable_tokens(consumable_tokens, expr.next_expr),
              skip_tokens
            )

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
              nid = factory.current_id

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

        when Grammar::Expression::Empty
          if expr.next_expr
            next_tree = parse_rule(expr.next_expr, consumable_tokens, skip_tokens)
          end
          Tree::EmptyTree.new(expr, next_tree: next_tree)

        when Grammar::Expression::Optional
          first_tokens = expr.expression.first_tokens

          if first_tokens.include?(factory.current_type)
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
          nid = factory.current_id()

          expr.expressions.each do |opt|
            option_first_tokens = opt.first_tokens
            if option_first_tokens.include?(factory.current_type) || option_first_tokens.include?(nil)
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
            last_token_id = factory.current_id
            values << parse_rule(
              expr.content,
              consumable_for_content,
              skip_tokens
            )

            break unless factory.current_id

            separator_first_tokens = expr.separator.first_tokens
            case
            when separator_first_tokens.include?(factory.current_type)
              values << parse_rule(
                expr.separator,
                consumable_for_separator,
                skip_tokens
              )
            when separator_first_tokens.include?(nil)
              unless expr.content.first_tokens.include?(factory.current_type)
                break
              end
            else
              break
            end

            # Stop loop when one content-separator iteration doesn't consume any token
            if last_token_id == factory.current_id
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
