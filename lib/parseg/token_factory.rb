module Parseg
  class TokenFactory
    attr_reader :tokenizer, :changed_input, :original_input, :tokens, :changes, :current_token, :current_id, :enumerator

    def initialize(tokenizer:, input:, changes: [])
      @tokenizer = tokenizer
      @original_input = input
      @changes = changes
      @tokens = {}

      @changed_input = changes.each.with_object(original_input.dup) do |change, string|
        str, start_loc, end_loc = change

        buf = RBS::Buffer.new(name: "", content: string)
        start_pos = buf.loc_to_pos(start_loc)
        end_pos = buf.loc_to_pos(end_loc)

        string[start_pos...end_pos] = str
      end

      @max_id = 0

      @enumerator = Enumerator.new do |y|
        tokenizer.each_token(changed_input) do |tok|
          y << tok
        end
      end

      advance_token()
    end

    def next_id
      @max_id += 1
    end

    def advance_token
      if tok = enumerator.next
        new_id = next_id

        tokens[new_id] = tok
        @current_id = new_id
        @current_token = tok

        [new_id, tok]
      else
        @current_id = nil
        @current_token = nil
      end
    rescue StopIteration
      @current_id = nil
      @current_token = nil
    end

    def advance_token!
      advance_token or raise
    end

    def current_token!
      current_token or raise
    end

    def current_id!
      current_id or raise
    end

    def current_type
      if current_token
        current_token[0]
      end
    end

    def current_type!
      current_type or raise
    end

    def current_range
      if id = current_id
        token_range(id)
      end
    end

    def current_range!
      current_range or raise
    end

    def token_range(id)
      tok = tokens[id] or raise
      _, start, str = tok
      start...(start + str.size)
    end

    def token_string(id)
      if (_, _, string = token(id))
        string
      end
    end

    def token_string!(id)
      token_string(id) or raise
    end

    def token_type(id)
      if (type, _, _ = token(id))
        type
      end
    end

    def token_type!(id)
      token_type(id) or raise
    end

    def token(id)
      raise unless tokens.key?(id)
      tokens[id] or raise
    end

    def surrounding_changed_range
    first_change, *changes = self.changes()
    return unless first_change

    buf = RBS::Buffer.new(name: "", content: changed_input)

    @surrounding_changed_range ||= begin
        str, start_loc, end_loc = first_change

        surrounding_begin = buf.loc_to_pos(start_loc)
        surrounding_end = surrounding_begin + str.size

        changes.each do |(str, start_loc, end_loc)|
          be = buf.loc_to_pos(start_loc)
          changed = be...(be + str.size)

          if surrounding_begin > changed.begin
            surrounding_begin  = changed.begin
          end

          if surrounding_end < changed.end
            surrounding_end = changed.end
          end
        end

        surrounding_begin ... surrounding_end
      end
    end

    def token_changed?(id = current_id!)
      range = token_range(id)

      case sr = surrounding_changed_range
      when Range
        return false if range.end < sr.begin
        return false if range.begin > sr.end
        true
      when nil
        false
      end
    end

    def update(changes)
      TokenFactory.new(tokenizer: tokenizer, input: original_input, changes: self.changes + changes)
    end

    def reset(string)
      TokenFactory.new(tokenizer: tokenizer, input: string)
    end
  end
end
