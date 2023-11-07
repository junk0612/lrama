module Lrama
  class Grammar
    class RuleBuilder
      attr_accessor :lhs, :line
      attr_reader :rhs, :user_code, :precedence_sym

      def initialize(rule_counter, midrule_action_counter)
        @rule_counter = rule_counter
        @midrule_action_counter = midrule_action_counter

        @lhs = nil
        @rhs = []
        @user_code = nil
        @precedence_sym = nil
        @line = nil
        @code_to_new_token = {}
      end

      def add_rhs(rhs)
        if !@line
          @line = rhs.line
        end

        flush_user_code

        @rhs << rhs
      end

      def user_code=(user_code)
        flush_user_code

        @user_code = user_code
      end

      def precedence_sym=(precedence_sym)
        flush_user_code

        @precedence_sym = precedence_sym
      end

      def freeze_rhs
        @rhs.freeze
      end

      def preprocess_references
        numberize_references
        setup_references
      end

      def midrule_action_rules
        @midrule_action_rules ||= rhs.select do |token|
          token.is_a?(Lrama::Lexer::Token::UserCode)
        end.each_with_index.map do |code, i|
          prefix = code.referred ? "@" : "$@"
          new_token = Lrama::Lexer::Token::Ident.new(s_value: prefix + @midrule_action_counter.increment.to_s)
          @code_to_new_token[code] = new_token
          Rule.new(id: @rule_counter.increment, lhs: new_token, rhs: [], token_code: code, lineno: code.line)
        end
      end

      def rhs_with_new_tokens
        rhs.map do |token|
          @code_to_new_token[token] || token
        end
      end

      def build_rules
        tokens = rhs_with_new_tokens

        # Expand Parameterizing rules
        if tokens.any? {|r| r.is_a?(Lrama::Lexer::Token::Parameterizing) }
          expand_parameterizing_rules
        else
          [Rule.new(id: @rule_counter.increment, lhs: lhs, rhs: tokens, token_code: user_code, precedence_sym: precedence_sym, lineno: line)]
        end
      end

      private

      def expand_parameterizing_rules
        rhs = rhs_with_new_tokens
        rules = []
        token = Lrama::Lexer::Token::Ident.new(s_value: rhs[0].s_value)

        if rhs.any? {|r| r.is_a?(Lrama::Lexer::Token::Parameterizing) && r.option? }
          option_token = Lrama::Lexer::Token::Ident.new(s_value: "option_#{rhs[0].s_value}")
          rules << Rule.new(id: @rule_counter.increment, lhs: lhs, rhs: [option_token], token_code: user_code, precedence_sym: precedence_sym, lineno: line)
          rules << Rule.new(id: @rule_counter.increment, lhs: option_token, rhs: [], token_code: user_code, precedence_sym: precedence_sym, lineno: line)
          rules << Rule.new(id: @rule_counter.increment, lhs: option_token, rhs: [token], token_code: user_code, precedence_sym: precedence_sym, lineno: line)
        elsif rhs.any? {|r| r.is_a?(Lrama::Lexer::Token::Parameterizing) && r.nonempty_list? }
          nonempty_list_token = Lrama::Lexer::Token::Ident.new(s_value: "nonempty_list_#{rhs[0].s_value}")
          rules << Rule.new(id: @rule_counter.increment, lhs: lhs, rhs: [nonempty_list_token], token_code: user_code, precedence_sym: precedence_sym, lineno: line)
          rules << Rule.new(id: @rule_counter.increment, lhs: nonempty_list_token, rhs: [token], token_code: user_code, precedence_sym: precedence_sym, lineno: line)
          rules << Rule.new(id: @rule_counter.increment, lhs: nonempty_list_token, rhs: [nonempty_list_token, token], token_code: user_code, precedence_sym: precedence_sym, lineno: line)
        elsif rhs.any? {|r| r.is_a?(Lrama::Lexer::Token::Parameterizing) && r.list? }
          list_token = Lrama::Lexer::Token::Ident.new(s_value: "list_#{rhs[0].s_value}")
          rules << Rule.new(id: @rule_counter.increment, lhs: lhs, rhs: [list_token], token_code: user_code, precedence_sym: precedence_sym, lineno: line)
          rules << Rule.new(id: @rule_counter.increment, lhs: list_token, rhs: [], token_code: user_code, precedence_sym: precedence_sym, lineno: line)
          rules << Rule.new(id: @rule_counter.increment, lhs: list_token, rhs: [list_token, token], token_code: user_code, precedence_sym: precedence_sym, lineno: line)
        end

        rules
      end

      def numberize_references
        (rhs + [user_code]).compact.each do |token|
          next unless token.is_a?(Lrama::Lexer::Token::UserCode)

          token.references.each do |ref|
            ref_name = ref.value
            if ref_name.is_a?(::String) && ref_name != '$'
              value =
                if lhs.referred_by?(ref_name)
                  '$'
                else
                  index = rhs.find_index {|token| token.referred_by?(ref_name) }

                  if index
                    index + 1
                  else
                    raise "'#{ref_name}' is invalid name."
                  end
                end

              ref.value = value
              ref
            end
          end
        end
      end

      def setup_references
        # Bison n'th component is 1-origin
        (rhs + [user_code]).compact.each.with_index(1) do |token, i|
          if token.is_a?(Lrama::Lexer::Token::UserCode)
            token.references.each do |ref|
              # Need to keep position_in_rhs for actions in the middle of RHS
              ref.position_in_rhs = i - 1
              next if ref.type == :at
              # $$, $n, @$, @n can be used in any actions

              if ref.value == "$"
                # TODO: Should be postponed after middle actions are extracted?
                ref.referring_symbol = lhs
              elsif ref.value.is_a?(Integer)
                raise "Can not refer following component. #{ref.value} >= #{i}. #{token}" if ref.value >= i
                rhs[ref.value - 1].referred = true
                ref.referring_symbol = rhs[ref.value - 1]
              elsif ref.value.is_a?(String)
                target_tokens = ([lhs] + rhs + [user_code]).compact.first(i)
                referring_symbol_candidate = target_tokens.filter {|token| token.referred_by?(ref.value) }
                raise "Referring symbol `#{ref.value}` is duplicated. #{token}" if referring_symbol_candidate.size >= 2
                raise "Referring symbol `#{ref.value}` is not found. #{token}" unless referring_symbol = referring_symbol_candidate.first

                referring_symbol.referred = true
                ref.referring_symbol = referring_symbol
              end
            end
          end
        end
      end

      def flush_user_code
        if c = @user_code
          @rhs << c
          @user_code = nil
        end
      end
    end
  end
end