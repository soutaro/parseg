module Parseg
  class Change
    attr_reader :range, :text

    def initialize(range, text)
      @range = range
      @text = text
    end

    def self.apply(source, changes)
      source = source.dup
      min = changes[0].range.begin
      max = changes[0].range.end

      changes.each do |change|
        source[change.range] = change.text
        min = change.range.begin if min < change.range.begin
        max = change.range.end if max > change.range.end
      end

      [source, min...max]
    end
  end
end
