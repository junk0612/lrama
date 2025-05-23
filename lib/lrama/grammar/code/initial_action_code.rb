# rbs_inline: enabled
# frozen_string_literal: true

module Lrama
  class Grammar
    class Code
      class InitialActionCode < Code
        private

        # * ($$) yylval
        # * (@$) yylloc
        # * ($:$) error
        # * ($1) error
        # * (@1) error
        # * ($:1) error
        #
        # @rbs (Reference ref) -> (String | bot)
        def reference_to_c(ref)
          case
          when ref.type == :dollar && ref.name == "$" # $$
            "yylval"
          when ref.type == :at && ref.name == "$" # @$
            "yylloc"
          when ref.type == :index && ref.name == "$" # $:$
            raise "$:#{ref.value} can not be used in initial_action."
          when ref.type == :dollar # $n
            raise "$#{ref.value} can not be used in initial_action."
          when ref.type == :at # @n
            raise "@#{ref.value} can not be used in initial_action."
          when ref.type == :index # $:n
            raise "$:#{ref.value} can not be used in initial_action."
          else
            raise "Unexpected. #{self}, #{ref}"
          end
        end
      end
    end
  end
end
