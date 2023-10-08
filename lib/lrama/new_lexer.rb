require "strscan"
require "lrama/lexer/token"

module Lrama
  class NewLexer
    attr_accessor :end_symbol

    # FIXME: Remove this when renaming this class to Lexer
    Token = Lrama::Lexer::Token

    SYMBOLS = %w(%{ %} %% { } \[ \] : \| ;)
    PERCENT_TOKENS = %w(
      %union
      %token
      %type
      %left
      %right
      %noassoc
      %expect
      %define
      %require
      %printer
      %lex-param
      %parse-param
      %initial-action
      %prec
      %error-token
    )

    def initialize(text)
      @scanner = StringScanner.new(text)
      @head = @scanner.pos
      @line = 1
      @end_symbol = nil
    end

    def line
      @line
    end

    def column
      @scanner.pos - @head
    end

    def lex_token
      while !@scanner.eos? do
        case
        when @scanner.scan(/\n/)
          newline
        when @scanner.scan(/\s+/)
          # noop
        when @scanner.scan(/\/\*/)
          lex_comment
        else
          break
        end
      end

      @head_line = line
      @head_column = column

      case
      when @scanner.eos?
        return
      when @scanner.scan(/#{SYMBOLS.join('|')}/)
        return [@scanner.matched, @scanner.matched]
      when @scanner.scan(/#{PERCENT_TOKENS.join('|')}/)
        return [@scanner.matched, @scanner.matched]
      when @scanner.scan(/<\w+>/)
        return [:TAG, build_token(type: Token::Tag, s_value: @scanner.matched)]
      when @scanner.scan(/'.'/)
        return [:CHARACTER, build_token(type: Token::Char, s_value: @scanner.matched)]
      when @scanner.scan(/'\\\\'|'\\t'|'\\f'|'\\r'|'\\n'|'\\13'/)
        return [:CHARACTER, build_token(type: Token::Char, s_value: @scanner.matched)]
      when @scanner.scan(/"/)
        return [:STRING, %Q("#{@scanner.scan_until(/"/)})]
      when @scanner.scan(/\d+/)
        return [:INTEGER, Integer(@scanner.matched)]
      when @scanner.scan(/([a-zA-Z_.][-a-zA-Z0-9_.]*)/)
        return [:IDENTIFIER, build_token(type: Token::Ident, s_value: @scanner.matched)]
      else
        raise
      end
    end

    def lex_c_code
      nested = 0
      code = ''
      while !@scanner.eos? do
        case
        when @scanner.scan(/{/)
          code += @scanner.matched
          nested += 1
        when @scanner.scan(/}/)
          if nested == 0 && @end_symbol == '}'
            @scanner.unscan
            return [:C_DECLARATION, build_token(type: Token::User_code, s_value: code, references: [])]
          else
            code += @scanner.matched
            nested -= 1
          end
        when @scanner.check(/#{@end_symbol}/)
          return [:C_DECLARATION, build_token(type: Token::User_code, s_value: code, references: [])]
        when @scanner.scan(/\n/)
          code += @scanner.matched
          newline
        when @scanner.scan(/"/)
          matched = @scanner.scan_until(/"/)[0..-2]
          code += %Q("#{matched}")
          @line += matched.count("\n")
        else
          code += @scanner.getch
        end
      end
      raise
    end

    private

    def lex_comment
      while !@scanner.eos? do
        case
        when @scanner.scan(/\n/)
          newline
        when @scanner.scan(/\*\//)
          return
        else
          @scanner.getch
        end
      end
    end

    def lex_string
      str = '"'
      while @scanner.eos? do
        case
        when @scanner.scan(/\\"/)
          str += @scanner.matched
        when @scanner.scan(/\n/)
          str += @scanner.matched
          newline
        when @scanner.matched(/"/)
          str += @scanner.matched
          return str
        else
          str += @scanner.getch
        end
      end
      raise
    end


    def build_token(type:, s_value:, **options)
      token = Lrama::Lexer::Token.new(type: type, s_value: s_value)
      token.line = @head_line
      token.column = @head_column
      options.each do |attr, value|
        token.public_send("#{attr}=", value)
      end

      token
    end

    def newline
      @line += 1
      @head = @scanner.pos + 1
    end
  end
end
