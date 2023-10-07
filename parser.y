class Lrama::NewParser
rule
  input: prologue_declarations bison_declarations "%%" grammar epilogue_opt

  prologue_declarations: # empty
                       | prologue_declarations prologue_declaration

  prologue_declaration: "%{" {@status = :c_declaration; @lexer.end_symbol = '%}'; @grammar.prologue_first_lineno = @lexer.line} C_DECLARATION {@status = :initial; @lexer.end_symbol = nil} "%}" { @grammar.prologue = val[2] }
                      | "%require" STRING

  bison_declarations: /* empty */ { result = "" }
                    | bison_declarations bison_declaration

  bison_declaration: grammar_declaration
                   | "%expect" INTEGER
                   | "%define" variable value
                   | "%require" STRING
                   | "%param" params
                   | "%lex-param" params { val[1].each {|token| token.references = []; @grammar.lex_param = @grammar.build_code(:lex_param, token).token_code.s_value} }
                   | "%parse-param" params { val[1].each {|token| token.references = []; @grammar.parse_param = @grammar.build_code(:parse_param, token).token_code.s_value} }
                   | "%initial-action" "{" {@status = :c_declaration; @lexer.end_symbol = '}'; @lineno.push(@lexer.line); @column.push(@lexer.col)} C_DECLARATION {@status = :initial; @lexer.end_symbol = nil} "}" { code = build_token(type: :User_code, s_value: val[3], line: @lineno.pop, column: @column.pop); code.references = []; @grammar.initial_action = @grammar.build_code(:initial_action, code) }
                   | ";"

  grammar_declaration: "%union" "{" {@status = :c_declaration; @lexer.end_symbol = '}'; @lineno.push(@lexer.line); @column.push(@lexer.col)} C_DECLARATION {@status = :initial; @lexer.end_symbol = nil} "}" { code = build_token(type: :User_code, s_value: val[3], line: @lineno.pop, column: @column.pop); code.references = []; @grammar.set_union(@grammar.build_code(:union, code), code.line) }
                     | symbol_declaration
                     | "%destructor" "{" {@status = :c_declaration; @lexer.end_symbol = '}'} C_DECLARATION {@status = :initial; @lexer.end_symbol = nil} "}" generic_symlist
                     | "%printer" "{" {@status = :c_declaration; @lexer.end_symbol = '}'; @lineno.push(@lexer.line); @column.push(@lexer.col)} C_DECLARATION {@status = :initial; @lexer.end_symbol = nil} "}" generic_symlist { code = build_token(type: :User_code, s_value: val[3], line: @lineno.pop, column: @column.pop); code.references = []; @grammar.add_printer(ident_or_tags: val[6], code: @grammar.build_code(:printer, code), lineno: code.line) }
                     | "%error-token" "{" {@status = :c_declaration; @lexer.end_symbol = '}'; @lineno.push(@lexer.line); @column.push(@lexer.col)} C_DECLARATION {@status = :initial; @lexer.end_symbol = nil} "}" generic_symlist { code = build_token(type: :User_code, s_value: val[3], line: @lineno.pop, column: @column.pop); code.references = []; @grammar.add_error_token(ident_or_tags: val[6], code: @grammar.build_code(:error_token, code), lineno: code.line) }

  symbol_declaration: "%token" token_declarations
                    | "%type" symbol_declarations { val[1].each {|hash| hash[:tokens].each {|id| @grammar.add_type(id: id, tag: hash[:tag]) } } }
                    | "%left" token_declarations_for_precedence { val[1].each {|hash| hash[:tokens].each {|id| sym = @grammar.add_term(id: id); @grammar.add_left(sym, @precedence_number) } }; @precedence_number += 1 }
                    | "%right" token_declarations_for_precedence { val[1].each {|hash| hash[:tokens].each {|id| sym = @grammar.add_term(id: id); @grammar.add_right(sym, @precedence_number) } }; @precedence_number += 1 }
                    | "%nonassoc" token_declarations_for_precedence { val[1].each {|hash| hash[:tokens].each {|id| sym = @grammar.add_term(id: id); @grammar.add_nonassoc(sym, @precedence_number) } }; @precedence_number += 1 }

  token_declarations: token_declaration_list { val[0].each {|token_declaration| @grammar.add_term(id: token_declaration[0], alias_name: token_declaration[2], token_id: token_declaration[1], tag: nil, replace: true) } }
                    | TAG token_declaration_list { val[1].each {|token_declaration| @grammar.add_term(id: token_declaration[0], alias_name: token_declaration[2], token_id: token_declaration[1], tag: Lrama::Lexer::Token.new(type: Lrama::Lexer::Token::Tag, s_value: val[0]), replace: true) } }
                    | token_declarations TAG token_declaration_list { val[2].each {|token_declaration| @grammar.add_term(id: token_declaration[0], alias_name: token_declaration[2], token_id: token_declaration[1], tag: Lrama::Lexer::Token.new(type: Lrama::Lexer::Token::Tag, s_value: val[1]), replace: true) } }

  token_declaration_list: token_declaration { result = [val[0]] }
                        | token_declaration_list token_declaration { result = val[0].append(val[1]) }

  token_declaration: id int_opt alias { result = val }

  int_opt: # empty
         | INTEGER { result = Integer(val[0]) }

  alias: # empty
       | string_as_id
       | STRING { result = %Q("#{val[0]}") }

  symbol_declarations: symbol_declaration_list { result = [{tag: nil, tokens: val[0]}] }
                     | TAG symbol_declaration_list { result = [{tag: Lrama::Lexer::Token.new(type: Lrama::Lexer::Token::Tag, s_value: val[0]), tokens: val[1]}] }
                     | symbol_declarations TAG symbol_declaration_list { result = val[0].append({tag: Lrama::Lexer::Token.new(type: Lrama::Lexer::Token::Tag, s_value: val[1]), tokens: val[2]}) }

  symbol_declaration_list: symbol { result = [val[0]] }
                         | symbol_declaration_list symbol { result = val[0].append(val[1]) }

  symbol: id

  params: params "{" {@status = :c_declaration; @lexer.end_symbol = '}'; @lineno.push(@lexer.line); @column.push(@lexer.col)} C_DECLARATION {@status = :initial; @lexer.end_symbol = nil} "}" { result = val[0].append(build_token(type: :User_code, s_value: val[3], line: @lineno.pop, column: @column.pop)) }
        | "{" {@status = :c_declaration; @lexer.end_symbol = '}'; @lineno.push(@lexer.line); @column.push(@lexer.col)} C_DECLARATION {@status = :initial; @lexer.end_symbol = nil} "}" { result = [build_token(type: :User_code, s_value: val[2], line: @lineno.pop, column: @column.pop)] }

  token_declarations_for_precedence: token_declaration_list_for_precedence { result = [{tag: nil, tokens: val[0]}] }
                                   | TAG token_declaration_list_for_precedence { result = [{tag: Lrama::Lexer::Token.new(type: Lrama::Lexer::Token::Tag, s_value: val[0]), tokens: val[1]}] }
                                   | token_declarations_for_precedence token_declaration_list_for_precedence { result = val[0].append({tag: nil, tokens: val[1]}) }

  token_declaration_list_for_precedence: token_declaration_for_precedence { result = [val[0]] }
                                       | token_declaration_list_for_precedence token_declaration_for_precedence { result = val[0].append(val[1]) }

  token_declaration_for_precedence: id

  id: { @lineno.push(@lexer.line); @column.push(@lexer.col) } IDENTIFIER { result = build_token(type: :Ident, s_value: val[1], line: @lineno.pop, column: @column.pop) }
    | { @lineno.push(@lexer.line); @column.push(@lexer.col) } CHARACTER { result = build_token(type: :Char, s_value: val[1], line: @lineno.pop, column: @column.pop) }

  grammar: rules_or_grammar_declaration
         | grammar rules_or_grammar_declaration

  rules_or_grammar_declaration: rules
                              | grammar_declaration ";"

  rules: id_colon named_ref_opt ":" rhs_list { lhs = val[0]; lhs.alias = val[1]; val[3].each {|hash| @grammar.add_rule(lhs: lhs, rhs: hash[:rhs], lineno: hash[:lineno]) } }

  rhs_list: { @lineno.push(@lexer.line) } rhs { result = [{rhs: val[1], lineno: @lineno.pop}] }
          | rhs_list "|" { @lineno.push(@lexer.line) } rhs { result = val[0].append({rhs: val[3], lineno: @lineno.pop}) }
          | rhs_list ";"

  rhs: /* empty */ { result = [] }
     | rhs symbol named_ref_opt { token = val[1]; val[1].alias = val[2]; result = val[0].append(token) }
     | rhs "{" {@status = :c_declaration; @lexer.end_symbol = '}'; @lineno.push(@lexer.line); @column.push(@lexer.col)} C_DECLARATION {@status = :initial; @lexer.end_symbol = nil} "}" named_ref_opt { result = val[0].append(build_token(type: :User_code, s_value: val[1..5].join, line: @lineno.pop, column: @column.pop, alias_name: val[6])) }
     | "{" {@status = :c_declaration; @lexer.end_symbol = '}'; @lineno.push(@lexer.line); @column.push(@lexer.col)} C_DECLARATION {@status = :initial; @lexer.end_symbol = nil} "}" named_ref_opt { result = [build_token(type: :User_code, s_value: val[0..4].join, line: @lineno.pop, column: @column.pop, alias_name: val[5])] }
     | rhs "%prec" symbol { sym = @grammar.find_symbol_by_id!(val[2]); result = val[0].append(sym) }

  named_ref_opt: # empty
               | '[' IDENTIFIER ']' { result = val[1] }

  id_colon: id

  epilogue_opt: # empty
              | "%%" {@status = :c_declaration; @lexer.end_symbol = '\Z'; @grammar.epilogue_first_lineno = @lexer.line + 1} C_DECLARATION {@status = :initial; @lexer.end_symbol = nil; @grammar.epilogue = val[2] }

  variable: id

  value: # empty
       | IDENTIFIER
       | STRING
       | "{...}"

  generic_symlist: generic_symlist_item { result = [val[0]] }
                 | generic_symlist generic_symlist_item { result = val[0].append(val[1]) }

  generic_symlist_item: symbol
                      | tag

  tag: TAG { result = Lrama::Lexer::Token.new(type: Lrama::Lexer::Token::Tag, s_value: val[0]) }
     | "<*>"
     | "<>"
end

---- inner

def initialize(text)
  @text = text
  @lineno = []
  @column = []
end

def parse
  @status = :initial
  @lexer = Lrama::NewLexer.new(@text)
  @grammar = Lrama::Grammar.new
  @precedence_number = 0
  do_parse
  @grammar.extract_references
  @grammar.prepare
  @grammar.compute_nullable
  @grammar.validate!
  @grammar
end

def next_token
  case @status
  when :initial
    @lexer.lex_token
  when :c_declaration
    @lexer.lex_c_code
  end
end

def build_token(type:, s_value:, line:, column:, alias_name: nil)
  token_type = Lrama::Lexer::Token.const_get(type)
  token = Lrama::Lexer::Token.new(type: token_type, s_value: s_value)
  token.line = line
  token.column = column
  token.alias = alias_name

  token
end
