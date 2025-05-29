// jack_parser.v - Stage 2: Parsing xxxT.xml to xxx.xml
import os

// Token struct for parsing
struct ParseToken {
	token_type string
	value      string
}

// CompilationEngine struct
struct CompilationEngine {
mut:
	tokens        []ParseToken
	current_token int
	output        string
	indent        int
}

// Create new compilation engine from tokens XML
fn new_compilation_engine_from_xml(tokens_xml string) CompilationEngine {
	mut engine := CompilationEngine{
		current_token: 0
		indent: 0
	}
	engine.parse_tokens_xml(tokens_xml)
	return engine
}

fn trim_single_spaces(s string) string {
    mut result := s
    
    // Check if the string starts with a space and remove it
    if result.len > 0 && result[0] == ` ` {
        result = result[1..]
    }
    
    // // Check if the string ends with a space and remove it
    if result.len > 0 && result[result.len - 1] == ` ` {
        result = result[..result.len - 1]
    }
    
    return result
}

// Parse tokens from XML file
fn (mut c CompilationEngine) parse_tokens_xml(xml_content string) {
	lines := xml_content.split('\n')
	
	for line in lines {
		trimmed := line.trim_space()
		if trimmed.starts_with('<') && trimmed.ends_with('>') && !trimmed.starts_with('</') && trimmed != '<tokens>' && trimmed != '</tokens>' {
			// Extract token type and value
			// Format: <tokenType> value </tokenType>
			
			// Find first > and last <
			first_close := trimmed.index('>') or { continue }
			last_open := trimmed.last_index('<') or { continue }
			
			if first_close >= last_open {
				continue
			}
			
			token_type := trimmed[1..first_close]
			value := trim_single_spaces(trimmed[first_close + 1..last_open])
			
			// Unescape XML entities
			unescaped_value := value.replace('&lt;', '<').replace('&gt;', '>').replace('&amp;', '&').replace('&quot;', '"')
			
			c.tokens << ParseToken{
				token_type: token_type
				value: unescaped_value
			}
		}
	}
}

// Check current token
fn (c CompilationEngine) current() ParseToken {
	if c.current_token < c.tokens.len {
		return c.tokens[c.current_token]
	}
	return ParseToken{'', ''}
}

// Check if current token matches expected
fn (c CompilationEngine) is_current(expected string) bool {
	return c.current().value == expected
}

// Check if current token is of expected type
fn (c CompilationEngine) is_current_type(expected_type string) bool {
	return c.current().token_type == expected_type
}

// Advance to next token
fn (mut c CompilationEngine) advance() {
	if c.current_token < c.tokens.len {
		c.current_token++
	}
}

// Write output with indentation
fn (mut c CompilationEngine) write(text string) {
	c.output += '  '.repeat(c.indent) + text + '\n'
}

// Write opening tag
fn (mut c CompilationEngine) write_open_tag(tag string) {
	c.write('<$tag>')
	c.indent++
}

// Write closing tag
fn (mut c CompilationEngine) write_close_tag(tag string) {
	c.indent--
	c.write('</$tag>')
}

// Write current token and advance
fn (mut c CompilationEngine) write_current_token() {
	token := c.current()
	if token.token_type != '' {
		escaped_value := token.value.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;').replace('"', '&quot;')
		c.write('<${token.token_type}> $escaped_value </${token.token_type}>')
		c.advance()
	}
}

// Eat expected token
fn (mut c CompilationEngine) eat(expected string) {
	if c.is_current(expected) {
		c.write_current_token()
	} else {
		println('Error: Expected "$expected" but got "${c.current().value}"')
	}
}

// Compile class
fn (mut c CompilationEngine) compile_class() {
	c.write_open_tag('class')
	
	// 'class'
	c.eat('class')
	
	// className
	c.write_current_token() // identifier
	
	// '{'
	c.eat('{')
	
	// classVarDec*
	for c.is_current('static') || c.is_current('field') {
		c.compile_class_var_dec()
	}
	
	// subroutineDec*
	for c.is_current('constructor') || c.is_current('function') || c.is_current('method') {
		c.compile_subroutine()
	}
	
	// '}'
	c.eat('}')
	
	c.write_close_tag('class')
}

// Compile class variable declaration
fn (mut c CompilationEngine) compile_class_var_dec() {
	c.write_open_tag('classVarDec')
	
	// ('static' | 'field')
	c.write_current_token()
	
	// type
	c.compile_type()
	
	// varName
	c.write_current_token() // identifier
	
	// (',' varName)*
	for c.is_current(',') {
		c.eat(',')
		c.write_current_token() // identifier
	}
	
	// ';'
	c.eat(';')
	
	c.write_close_tag('classVarDec')
}

// Compile type
fn (mut c CompilationEngine) compile_type() {
	if c.is_current('int') || c.is_current('char') || c.is_current('boolean') || c.is_current_type('identifier') {
		c.write_current_token()
	}
}

// Compile subroutine
fn (mut c CompilationEngine) compile_subroutine() {
	c.write_open_tag('subroutineDec')
	
	// ('constructor' | 'function' | 'method')
	c.write_current_token()
	
	// ('void' | type)
	if c.is_current('void') {
		//c.eat('void')
		c.write_current_token() 
	} else {
		c.compile_type()
	}
	
	// subroutineName
	c.write_current_token() // identifier
	
	// '('
	c.eat('(')
	
	// parameterList
	c.compile_parameter_list()
	
	// ')'
	c.eat(')')
	
	// subroutineBody
	c.compile_subroutine_body()
	
	c.write_close_tag('subroutineDec')
}

// Compile parameter list
fn (mut c CompilationEngine) compile_parameter_list() {
	c.write_open_tag('parameterList')
	
	if !c.is_current(')') {
		// type
		c.compile_type()
		
		// varName
		c.write_current_token() // identifier
		
		// (',' type varName)*
		for c.is_current(',') {
			c.eat(',')
			c.compile_type()
			c.write_current_token() // identifier
		}
	}
	
	c.write_close_tag('parameterList')
}

// Compile subroutine body
fn (mut c CompilationEngine) compile_subroutine_body() {
	c.write_open_tag('subroutineBody')
	
	// '{'
	c.eat('{')
	
	// varDec*
	for c.is_current('var') {
		c.compile_var_dec()
	}
	
	// statements
	c.compile_statements()
	
	// '}'
	c.eat('}')
	
	c.write_close_tag('subroutineBody')
}

// Compile variable declaration
fn (mut c CompilationEngine) compile_var_dec() {
	c.write_open_tag('varDec')
	
	// 'var'
	c.eat('var')
	
	// type
	c.compile_type()
	
	// varName
	c.write_current_token() // identifier
	
	// (',' varName)*
	for c.is_current(',') {
		c.eat(',')
		c.write_current_token() // identifier
	}
	
	// ';'
	c.eat(';')
	
	c.write_close_tag('varDec')
}

// Compile statements
fn (mut c CompilationEngine) compile_statements() {
	c.write_open_tag('statements')
	
	for c.is_current('let') || c.is_current('if') || c.is_current('while') || c.is_current('do') || c.is_current('return') {
		match c.current().value {
			'let' { c.compile_let() }
			'if' { c.compile_if() }
			'while' { c.compile_while() }
			'do' { c.compile_do() }
			'return' { c.compile_return() }
			else { break }
		}
	}
	
	c.write_close_tag('statements')
}

// Compile let statement
fn (mut c CompilationEngine) compile_let() {
	c.write_open_tag('letStatement')
	
	// 'let'
	c.eat('let')
	
	// varName
	c.write_current_token() // identifier
	
	// ('[' expression ']')?
	if c.is_current('[') {
		c.eat('[')
		c.compile_expression()
		c.eat(']')
	}
	
	// '='
	c.eat('=')
	
	// expression
	c.compile_expression()
	
	// ';'
	c.eat(';')
	
	c.write_close_tag('letStatement')
}

// Compile if statement
fn (mut c CompilationEngine) compile_if() {
	c.write_open_tag('ifStatement')
	
	// 'if'
	c.eat('if')
	
	// '('
	c.eat('(')
	
	// expression
	c.compile_expression()
	
	// ')'
	c.eat(')')
	
	// '{'
	c.eat('{')
	
	// statements
	c.compile_statements()
	
	// '}'
	c.eat('}')
	
	// ('else' '{' statements '}')?
	if c.is_current('else') {
		c.eat('else')
		c.eat('{')
		c.compile_statements()
		c.eat('}')
	}
	
	c.write_close_tag('ifStatement')
}

// Compile while statement
fn (mut c CompilationEngine) compile_while() {
	c.write_open_tag('whileStatement')
	
	// 'while'
	c.eat('while')
	
	// '('
	c.eat('(')
	
	// expression
	c.compile_expression()
	
	// ')'
	c.eat(')')
	
	// '{'
	c.eat('{')
	
	// statements
	c.compile_statements()
	
	// '}'
	c.eat('}')
	
	c.write_close_tag('whileStatement')
}

// Compile do statement
fn (mut c CompilationEngine) compile_do() {
	c.write_open_tag('doStatement')
	
	// 'do'
	c.eat('do')
	
	// subroutineCall
	c.compile_subroutine_call()
	
	// ';'
	c.eat(';')
	
	c.write_close_tag('doStatement')
}

// Compile return statement
fn (mut c CompilationEngine) compile_return() {
	c.write_open_tag('returnStatement')
	
	// 'return'
	c.eat('return')
	
	// expression?
	if !c.is_current(';') {
		c.compile_expression()
	}
	
	// ';'
	c.eat(';')
	
	c.write_close_tag('returnStatement')
}

// Compile expression
fn (mut c CompilationEngine) compile_expression() {
	c.write_open_tag('expression')
	
	// term
	c.compile_term()
	
	// (op term)*
	for c.is_current('+') || c.is_current('-') || c.is_current('*') || c.is_current('/') || 
		c.is_current('&') || c.is_current('|') || c.is_current('<') || c.is_current('>') || c.is_current('=') {
		c.write_current_token() // operator
		c.compile_term()
	}
	
	c.write_close_tag('expression')
}

// Compile term
fn (mut c CompilationEngine) compile_term() {
	c.write_open_tag('term')
	
	current_token := c.current()
	
	match current_token.token_type {
		'integerConstant', 'stringConstant' {
			c.write_current_token()
		}
		'keyword' {
			if current_token.value in ['true', 'false', 'null', 'this'] {
				c.write_current_token()
			}
		}
		'identifier' {
			mut next_token := c.tokens[c.current_token + 1].value // look ahead
			// Check for array access 
			if next_token == '[' {
				c.write_current_token()
				// Array access: varName '[' expression ']'
				c.eat('[')
				c.compile_expression()
				c.eat(']')
			} else if next_token == '(' || next_token == '.' {
				// Subroutine call - need to backtrack
				// c.current_token-- // Go back to identifier
				c.compile_subroutine_call_in_term()
			} else {
				// Just an identifier
				c.write_current_token()
			}
		}
		'symbol' {
			if current_token.value == '(' {
				// '(' expression ')'
				c.eat('(')
				c.compile_expression()
				c.eat(')')
			} else if current_token.value in ['-', '~'] {
				// unaryOp term
				c.write_current_token()
				c.compile_term()
			}
		}
		else {
			// Fallback
			c.write_current_token()
		}
	}
	
	c.write_close_tag('term')
}

// Compile subroutine call within term
fn (mut c CompilationEngine) compile_subroutine_call_in_term() {
	// identifier
	c.write_current_token()
	
	if c.is_current('.') {
		// className.subroutineName or varName.subroutineName
		c.eat('.')
		c.write_current_token() // subroutineName
	}
	
	// '('
	c.eat('(')
	
	// expressionList
	c.compile_expression_list()
	
	// ')'
	c.eat(')')
}

// Compile subroutine call
fn (mut c CompilationEngine) compile_subroutine_call() {
	// identifier
	c.write_current_token()
	
	if c.is_current('.') {
		// className.subroutineName or varName.subroutineName
		c.eat('.')
		c.write_current_token() // subroutineName
	}
	
	// '('
	c.eat('(')
	
	// expressionList
	c.compile_expression_list()
	
	// ')'
	c.eat(')')
}

// Compile expression list
fn (mut c CompilationEngine) compile_expression_list() {
	c.write_open_tag('expressionList')
	
	if !c.is_current(')') {
		c.compile_expression()
		
		for c.is_current(',') {
			c.eat(',')
			c.compile_expression()
		}
	}
	
	c.write_close_tag('expressionList')
}

// Parse tokens XML file and create syntax XML
fn parse_tokens_file(input_file string, output_file string) ! {
	content := os.read_file(input_file)!
	
	mut engine := new_compilation_engine_from_xml(content)
	engine.compile_class()
	
	os.write_file(output_file, engine.output)!
	println('Generated syntax file: $output_file')
}

// Main function for parser
fn main() {
	args := os.args
	if args.len < 2 {
		println('Usage: jack_parser <inputT.xml or directory>')
		println('This will generate xxx.xml files from xxxT.xml files')
		return
	}
	
	input_path := args[1]
	
	if os.is_dir(input_path) {
		// Process all T.xml files in directory
		files := os.ls(input_path) or { panic('Cannot read directory') }
		for file in files {
			if file.ends_with('T.xml') {
				input_file := os.join_path(input_path, file)
				output_file := input_file.replace('T.xml', '.xml')
				parse_tokens_file(input_file, output_file) or {
					println('Error processing $file: $err')
				}
			}
		}
	} else if input_path.ends_with('T.xml') {
		// Process single file
		output_file := input_path.replace('T.xml', '.xml')
		parse_tokens_file(input_path, output_file) or {
			println('Error processing file: $err')
		}
	} else {
		println('Input must be a xxxT.xml file or directory containing xxxT.xml files')
	}
}