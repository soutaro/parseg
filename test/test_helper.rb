# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "parseg"

require "minitest/autorun"

module TreeAssertion
  def assert_tree(tree, pred, factory:)
    assert_equal [pred], Parseg::TreeFormatter.new.format(tree, factory: factory)
  end
end
