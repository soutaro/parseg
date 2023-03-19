# frozen_string_literal: true

require_relative "parseg/version"

require "yaml"
require "active_support"
require "active_support/tagged_logging"
require "language_server-protocol"

module Parseg
  def self.logger
    @logger ||= begin
      ActiveSupport::TaggedLogging.new(
        Logger.new(STDERR, level: ENV["PARSEG_LOGLEVEL"] || "INFO")
      ).tagged("parseg:#{Parseg::VERSION}")
    end
  end
end

require "parseg/grammar"
require "parseg/token_locator"
require "parseg/result"
require "parseg/tree"
require "parseg/parser"
require "parseg/tree_formatter"
require "parseg/change"
require "parseg/lsp_tree_formatter"
