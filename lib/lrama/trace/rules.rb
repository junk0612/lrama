# rbs_inline: enabled
# frozen_string_literal: true

module Lrama
  class Trace
    class Rules
      # @rbs (IO io, bool rules, bool only_explicit, **untyped _) -> void
      def initialize(io, rules: false, only_explicit: false, **_)
        @io = io
        @rules = rules
        @only_explicit = only_explicit
      end

      # @rbs (Lrama::Grammar grammar) -> void
      def trace(grammar)
        return if !@rules || @only_explicit

        @io << "Grammar rules:" << "\n"
        grammar.rules.each { |rule| @io << rule.display_name << "\n" }
      end
    end
  end
end
