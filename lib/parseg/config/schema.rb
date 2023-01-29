module Parseg
  class Config
    Schema = _ = StrongJSON.new do |schema|
      # @type self: StrongJSON & _ConfigSchema

      let :expression, enum()

      let :token_expression, object(token: string)
      expression.types << token_expression

      let :non_terminal_expression, object(non_terminal: string)
      expression.types << non_terminal_expression

      let :trailing, enum(literal("required"), literal("optional"), literal("prohibited"))

      let :repeating_non_terminal_expression, object(
        non_terminal: string,
        separator_token: string,
        allow_empty: boolean?,
        trailing: optional(trailing),
      )
      expression.types << repeating_non_terminal_expression

      let :alternation_expression, object(
        exprs: array(expression),
        allow_empty: boolean?
      )
      expression.types << alternation_expression

      let :production_rule, hash(array(expression))

      let :config, object(look_ahead_size: integer, rules: hash(production_rule))
    end
  end
end
