import regex
import os

const comment_pattern = r'(//.*)|(/\*([^*]|[\r\n]|(\*+([^*/]|[\r\n])))*\*+/)'
const empty_text_pattern = r'\s*'
const key_word_pattern = r'^\s*(class|constructor|function|method|static|field|var|int|char|boolean|void|true|false|null|this|let|do|if|else|while|return)\s*'
const symbol_pattern = r'^\s*([{}()\[\].,;+\-*/&|<>=~])\s*'
const digit_pattern = r'^\s*(\d+)\s*'
const string_pattern = r'^\s*"(.*)"\s*'
const identifier_pattern = r'^\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*'

const debugging = true // Set to false to disable debugging output

enum TokenType {
	keyword = 0
	symbol = 1
	int_const = 2
	string_const = 3
	identifier = 4
}

struct JackTokenizer {
mut:
	text          string
	token_type    TokenType
	current_token string
	keywords      []string = ['CLASS', 'METHOD', 'FUNCTION', 'CONSTRUCTOR', 'INT',
		'BOOLEAN', 'CHAR', 'VOID', 'VAR', 'STATIC', 'FIELD', 'LET',
		'DO', 'IF', 'ELSE', 'WHILE', 'RETURN', 'TRUE', 'FALSE',
		'NULL', 'THIS']
}

fn JackTokenizer.new(input_file_path string) !JackTokenizer {
	text := os.read_file(input_file_path) or {
		return error('Failed to read file: ${input_file_path}')
	}
	
	mut tokenizer := JackTokenizer{
		text: text
	}
	tokenizer.clear_all_comments()
	
	return tokenizer
}

fn (mut t JackTokenizer) clear_all_comments() {
	mut re := regex.regex_opt(comment_pattern) or { panic('Invalid regex pattern') }
	t.text = re.replace(t.text, '')
}

fn (t &JackTokenizer) has_more_tokens() bool {
	// Check if text contains only whitespace or is empty
	trimmed := t.text.trim_space()
	return trimmed.len > 0
}

fn (mut t JackTokenizer) advance() {
	if !t.has_more_tokens() {
		return
	}
	
	original_text_len := t.text.len
	
	// Try keyword pattern
	mut re := regex.regex_opt(key_word_pattern) or { panic('Invalid regex pattern') }
	mut start, mut end := re.match_string(t.text)
	if start >= 0 {	// if not found start=-1, end=0
		groups := re.get_group_list()
		if groups.len > 1 {
			t.current_token = groups[1].str()
			t.token_type = .keyword
			t.text = t.text[end..].trim_left(' \t\n\r')
			return
		}
	}
	
	// Try symbol pattern
	re = regex.regex_opt(symbol_pattern) or { panic('Invalid regex pattern') }
	start, end = re.match_string(t.text)
	if start >= 0 {
		groups := re.get_group_list()
		if groups.len > 1 {
			t.current_token = groups[1].str()
			t.token_type = .symbol
			t.text = t.text[end..].trim_left(' \t\n\r')
			return
		}
	}
	
	// Try digit pattern
	re = regex.regex_opt(digit_pattern) or { panic('Invalid regex pattern') }
	start, end = re.match_string(t.text)
	if start >= 0 {
		groups := re.get_group_list()
		if groups.len > 1 {
			t.current_token = groups[1].str()
			t.token_type = .int_const
			t.text = t.text[end..].trim_left(' \t\n\r')
			return
		}
	}
	
	// Try string pattern
	re = regex.regex_opt(string_pattern) or { panic('Invalid regex pattern') }
	start, end = re.match_string(t.text)
	if start >= 0 {
		groups := re.get_group_list()
		if groups.len > 1 {
			t.current_token = groups[1].str()
			t.token_type = .string_const
			t.text = t.text[end..].trim_left(' \t\n\r')
			return
		}
	}
	
	// Try identifier pattern
	re = regex.regex_opt(identifier_pattern) or { panic('Invalid regex pattern') }
	start, end = re.match_string(t.text)
	if start >= 0 {
		groups := re.get_group_list()
		if groups.len > 1 {
			t.current_token = groups[1].str()
			t.token_type = .identifier
			t.text = t.text[end..].trim_left(' \t\n\r')
			return
		}
	}
	
	// Safety check - if we get here and text wasn't modified, skip one character
	if t.text.len == original_text_len && t.text.len > 0 {
		println('Warning: Skipping unrecognized character: ${t.text[0]}')
		t.text = t.text[1..]
	}
}

fn (t &JackTokenizer) token_type() TokenType {
	return t.token_type
}

fn (t &JackTokenizer) key_word() string {
	return t.current_token
}

fn (t &JackTokenizer) symbol() string {
	return t.current_token
}

fn (t &JackTokenizer) identifier() string {
	return t.current_token
}

fn (t &JackTokenizer) int_val() int {
	return t.current_token.int()
}

fn (t &JackTokenizer) string_val() string {
	return t.current_token
}

fn main() {
	if debugging {
		mut tokenizer := JackTokenizer.new('C:\\Users\\YAFIT\\Desktop\\nand2tetris\\projects\\10\\Square\\Square.jack') or {
			println('Error: ${err}')
			return
		}
		
		for tokenizer.has_more_tokens() {
			tokenizer.advance()
			println(tokenizer.key_word())
		}
	}
}