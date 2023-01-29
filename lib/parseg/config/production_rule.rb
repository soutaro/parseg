module Parseg
  class Config
    class ProductionRule
      attr_reader :non_terminal, :rule_name, :sequence

      def initialize(non_terminal:, rule_name:)
        @non_terminal = non_terminal
        @rule_name = rule_name
        @sequence = []
      end
    end
  end
end
