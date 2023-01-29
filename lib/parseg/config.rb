module Parseg
  class Config
    attr_reader :production_rules, :look_ahead_size

    def initialize(look_ahead_size:)
      @look_ahead_size = look_ahead_size
      @production_rules = {}
    end

    def non_terminal_symbols
      Set.new(production_rules.each_key)
    end

    def token_types
      Set[]
    end

    def self.load(content)
      content = Schema.config.coerce(content)

      configuration = Config.new(look_ahead_size: content[:look_ahead_size])

      content[:rules].each do |non_terminal_name, rule|
        rules = {} #: Hash[Symbol, ProductionRule]

        rule.each do |rule_name, seqs|
          production_rule = ProductionRule.new(non_terminal: non_terminal_name, rule_name: rule_name)
          production_rule.sequence.replace(load_rule_seqs(seqs))
          rules[rule_name] = production_rule
        end

        configuration.production_rules[non_terminal_name] = rules
      end

      configuration
    end

    def self.load_rule_seqs(seqs)
      seqs.map do |e|
        case
        when e.key?(_ = :separator_token)
          expr = e #: repeating_non_terminal_expression_type

          Expression::RepeatingNonTerminalExpression.new(
            non_terminal: expr[:non_terminal].to_sym,
            separator_token: expr[:separator_token].to_sym,
            allow_empty: expr.fetch(:allow_empty, true) || raise,
            trailing_token:
              case expr[:trailing]
              when "required"
                :required
              when "optional"
                :optional
              else
                :prohibited
              end
          )
        when e.key?(_ = :non_terminal)
          expr = e #: non_terminal_expression_type
          Expression::NonTerminalExpression.new(expr[:non_terminal].to_sym)
        when e.key?(_ = :token)
          expr = e #: token_expression_type
          Expression::TokenExpression.new(expr[:token].to_sym)
        when e.key?(_ = :exprs)
          expr = e #: alternation_expression_type
          es = load_rule_seqs(expr[:exprs])
          Expression::AlternationExpression.new(exprs: es, allow_empty: expr[:allow_empty] || false)
        else
          raise
        end
      end
    end
  end
end
