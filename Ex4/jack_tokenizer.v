// jack_tokenizer.v - Stage 1: Tokenizing
import os

// TokenType enum
enum TokenType {
	keyword
	symbol
	identifier
	int_const
	string_const
}

// Keywords in Jack language
const keywords = [
	'class', 'constructor', 'function', 'method', 'field', 'static', 'var',
	'int', 'char', 'boolean', 'void', 'true', 'false', 'null', 'this',
	'let', 'do', 'if', 'else', 'while', 'return'
]

// Symbols in Jack language
const symbols = ['{', '}', '(', ')', '[', ']', '.', ',', ';', '+', '-', '*', '/', '&', '|', '<', '>', '=', '~']

// JackTokenizer struct
struct JackTokenizer {
mut:
	input_text    string
	tokens        []Token
	current_token int
}

// Token struct
struct Token {
	type_name TokenType
	value     string
}

// Create new tokenizer
fn new_tokenizer(input string) JackTokenizer {
	mut tokenizer := JackTokenizer{
		input_text: input
		current_token: -1
	}
	tokenizer.tokenize()
	return tokenizer
}

// Tokenize the input
fn (mut t JackTokenizer) tokenize() {
	mut cleaned_input := t.remove_comments(t.input_text)
	mut i := 0
	
	for i < cleaned_input.len {
		ch := cleaned_input[i]
		
		// Skip whitespace
		if ch.is_space() {
			i++
			continue
		}
		
		// String constant
		if ch == `"` {
			mut str_const := ''
			i++ // Skip opening quote
			for i < cleaned_input.len && cleaned_input[i] != `"` {
				str_const += cleaned_input[i].ascii_str()
				i++
			}
			i++ // Skip closing quote
			t.tokens << Token{
				type_name: .string_const
				value: str_const
			}
			continue
		}
		
		// Symbol
		if ch.ascii_str() in symbols {
			t.tokens << Token{
				type_name: .symbol
				value: ch.ascii_str()
			}
			i++
			continue
		}
		
		// Number or identifier/keyword
		if ch.is_alnum() || ch == `_` {
			mut token := ''
			for i < cleaned_input.len && (cleaned_input[i].is_alnum() || cleaned_input[i] == `_`) {
				token += cleaned_input[i].ascii_str()
				i++
			}
			
			// Determine if it's a keyword, identifier, or number
			if token in keywords {
				t.tokens << Token{
					type_name: .keyword
					value: token
				}
			} else if token[0].is_digit() {
				t.tokens << Token{
					type_name: .int_const
					value: token
				}
			} else {
				t.tokens << Token{
					type_name: .identifier
					value: token
				}
			}
			continue
		}
		
		i++
	}
}

// Remove comments from input
fn (t JackTokenizer) remove_comments(input string) string {
	mut result := ''
	mut i := 0
	
	for i < input.len {
		// Single line comment
		if i < input.len - 1 && input[i] == `/` && input[i + 1] == `/` {
			// Skip to end of line
			for i < input.len && input[i] != `\n` {
				i++
			}
			continue
		}
		
		// Multi line comment
		if i < input.len - 1 && input[i] == `/` && input[i + 1] == `*` {
			i += 2
			for i < input.len - 1 {
				if input[i] == `*` && input[i + 1] == `/` {
					i += 2
					break
				}
				i++
			}
			continue
		}
		
		result += input[i].ascii_str()
		i++
	}
	
	return result
}

// Generate XML output for tokens
fn (t JackTokenizer) generate_tokens_xml() string {
	mut output := '<tokens>\n'
	
	for token in t.tokens {
		mut type_str := ''
		match token.type_name {
			.keyword { type_str = 'keyword' }
			.symbol { type_str = 'symbol' }
			.identifier { type_str = 'identifier' }
			.int_const { type_str = 'integerConstant' }
			.string_const { type_str = 'stringConstant' }
		}
		
		// Escape XML special characters
		escaped_value := token.value.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;').replace('"', '&quot;')
		
		output += '<$type_str> $escaped_value </$type_str>\n'
	}
	
	output += '</tokens>\n'
	return output
}

// Tokenize Jack file and create xxxT.xml
fn tokenize_jack_file(input_file string, output_file string) ! {
	content := os.read_file(input_file)!
	
	tokenizer := new_tokenizer(content)
	xml_output := tokenizer.generate_tokens_xml()
	
	os.write_file(output_file, xml_output)!
	println('Generated tokens file: $output_file')
}

// Main function for tokenizer
fn main() {
	args := os.args
	if args.len < 2 {
		println('Usage: jack_tokenizer <input.jack or directory>')
		println('This will generate xxxT.xml files with tokens')
		return
	}
	
	input_path := args[1]
	
	if os.is_dir(input_path) {
		// Process all .jack files in directory
		files := os.ls(input_path) or { panic('Cannot read directory') }
		for file in files {
			if file.ends_with('.jack') {
				input_file := os.join_path(input_path, file)
				output_file := input_file.replace('.jack', 'T.xml')
				tokenize_jack_file(input_file, output_file) or {
					println('Error processing $file: $err')
				}
			}
		}
	} else if input_path.ends_with('.jack') {
		// Process single file
		output_file := input_path.replace('.jack', 'T.xml')
		tokenize_jack_file(input_path, output_file) or {
			println('Error processing file: $err')
		}
	} else {
		println('Input must be a .jack file or directory containing .jack files')
	}
}