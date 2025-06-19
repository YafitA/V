// jack_code_generator.v - Stage 11: Code Generation
import os

// TokenType enum (from tokenizer)
enum TokenType {
	keyword
	symbol
	identifier
	int_const
	string_const
}

// Token struct (from tokenizer)
struct Token {
	type_name TokenType
	value     string
}

// Variable kinds for symbol table
enum VarKind {
	static_var   // static
	field_var    // field
	arg_var      // argument
	var_var      // local variable
	none         // not found
}

// Symbol table entry
struct Symbol {
	mut:
		name  string
		type_ string
		kind  VarKind
		index int
}

// Symbol table for scopes
struct SymbolTable {
mut:
	class_table    map[string]Symbol
	subroutine_table map[string]Symbol
	static_count   int
	field_count    int
	arg_count      int
	var_count      int
}

// Create new symbol table
fn new_symbol_table() SymbolTable {
	return SymbolTable{}
}

// Start new subroutine scope
fn (mut st SymbolTable) start_subroutine() {
	st.subroutine_table.clear()
	st.arg_count = 0
	st.var_count = 0
}

// Define variable in symbol table
fn (mut st SymbolTable) define(name string, type_ string, kind VarKind) {
	mut symbol := Symbol{
		name: name
		type_: type_
		kind: kind
		index: 0
	}
	
	match kind {
		.static_var {
			symbol.index = st.static_count
			st.static_count++
			st.class_table[name] = symbol
		}
		.field_var {
			symbol.index = st.field_count
			st.field_count++
			st.class_table[name] = symbol
		}
		.arg_var {
			symbol.index = st.arg_count
			st.arg_count++
			st.subroutine_table[name] = symbol
		}
		.var_var {
			symbol.index = st.var_count
			st.var_count++
			st.subroutine_table[name] = symbol
		}
		else {}
	}
}

// Lookup variable in symbol table
fn (st SymbolTable) lookup(name string) Symbol {
	if name in st.subroutine_table {
		return st.subroutine_table[name]
	}
	if name in st.class_table {
		return st.class_table[name]
	}
	return Symbol{kind: .none}
}

// Get variable count by kind
fn (st SymbolTable) var_count(kind VarKind) int {
	match kind {
		.static_var { return st.static_count }
		.field_var { return st.field_count }
		.arg_var { return st.arg_count }
		.var_var { return st.var_count }
		else { return 0 }
	}
}

// VM Writer for generating VM code
struct VMWriter {
mut:
	output []string
}

// Create new VM writer
fn new_vm_writer() VMWriter {
	return VMWriter{}
}

// Write push command
fn (mut vm VMWriter) write_push(segment string, index int) {
	vm.output << 'push $segment $index'
}

// Write pop command
fn (mut vm VMWriter) write_pop(segment string, index int) {
	vm.output << 'pop $segment $index'
}

// Write arithmetic command
fn (mut vm VMWriter) write_arithmetic(command string) {
	vm.output << command
}

// Write label
fn (mut vm VMWriter) write_label(label string) {
	vm.output << 'label $label'
}

// Write goto
fn (mut vm VMWriter) write_goto(label string) {
	vm.output << 'goto $label'
}

// Write if-goto
fn (mut vm VMWriter) write_if(label string) {
	vm.output << 'if-goto $label'
}

// Write call
fn (mut vm VMWriter) write_call(name string, n_args int) {
	vm.output << 'call $name $n_args'
}

// Write function
fn (mut vm VMWriter) write_function(name string, n_locals int) {
	vm.output << 'function $name $n_locals'
}

// Write return
fn (mut vm VMWriter) write_return() {
	vm.output << 'return'
}

// Get output as string
fn (vm VMWriter) get_output() string {
	return vm.output.join('\n') + '\n'
}

// Jack Compiler - Code Generator
struct JackCompiler {
mut:
	tokens        []Token
	current_token int
	symbol_table  SymbolTable
	vm_writer     VMWriter
	class_name    string
	if_label_num  int
	while_label_num int
}

// Create new compiler
fn new_compiler(tokens []Token) JackCompiler {
	return JackCompiler{
		tokens: tokens
		current_token: 0
		symbol_table: new_symbol_table()
		vm_writer: new_vm_writer()
		if_label_num: 0
		while_label_num: 0
	}
}

// Current token
fn (c JackCompiler) current_token() Token {
	if c.current_token < c.tokens.len {
		return c.tokens[c.current_token]
	}
	return Token{}
}

// Advance to next token
fn (mut c JackCompiler) advance() {
	if c.current_token < c.tokens.len - 1 {
		c.current_token++
	}
}

// Peek at next token
fn (c JackCompiler) peek() Token {
	if c.current_token + 1 < c.tokens.len {
		return c.tokens[c.current_token + 1]
	}
	return Token{}
}

// Convert VarKind to VM segment
fn var_kind_to_segment(kind VarKind) string {
	match kind {
		.static_var { return 'static' }
		.field_var { return 'this' }
		.arg_var { return 'argument' }
		.var_var { return 'local' }
		else { return '' }
	}
}

// Compile class
fn (mut c JackCompiler) compile_class() {
	// class
	c.advance()
	
	// className
	c.class_name = c.current_token().value
	c.advance()
	
	// {
	c.advance()
	
	// classVarDec*
	for c.current_token().value in ['static', 'field'] {
		c.compile_class_var_dec()
	}
	
	// subroutineDec*
	for c.current_token().value in ['constructor', 'function', 'method'] {
		c.compile_subroutine_dec()
	}
	
	// }
}

// Compile class variable declaration
fn (mut c JackCompiler) compile_class_var_dec() {
	// static | field
	kind_str := c.current_token().value
	kind := if kind_str == 'static' { VarKind.static_var } else { VarKind.field_var }
	c.advance()
	
	// type
	type_ := c.current_token().value
	c.advance()
	
	// varName
	name := c.current_token().value
	c.symbol_table.define(name, type_, kind)
	c.advance()
	
	// (, varName)*
	for c.current_token().value == ',' {
		c.advance() // ,
		name2 := c.current_token().value
		c.symbol_table.define(name2, type_, kind)
		c.advance()
	}
	
	// ;
	c.advance()
}

// Compile subroutine declaration
fn (mut c JackCompiler) compile_subroutine_dec() {
	c.symbol_table.start_subroutine()
	
	// constructor | function | method
	subroutine_type := c.current_token().value
	c.advance()
	
	// void | type
	c.advance()
	
	// subroutineName
	subroutine_name := c.current_token().value
	c.advance()
	
	// If method, add 'this' as first argument
	if subroutine_type == 'method' {
		c.symbol_table.define('this', c.class_name, .arg_var)
	}
	
	// (
	c.advance()
	
	// parameterList
	c.compile_parameter_list()
	
	// )
	c.advance()
	
	// subroutineBody
	c.compile_subroutine_body(subroutine_name, subroutine_type)
}

// Compile parameter list
fn (mut c JackCompiler) compile_parameter_list() {
	if c.current_token().value != ')' {
		// type
		type_ := c.current_token().value
		c.advance()
		
		// varName
		name := c.current_token().value
		c.symbol_table.define(name, type_, .arg_var)
		c.advance()
		
		// (, type varName)*
		for c.current_token().value == ',' {
			c.advance() // ,
			type2 := c.current_token().value
			c.advance()
			name2 := c.current_token().value
			c.symbol_table.define(name2, type2, .arg_var)
			c.advance()
		}
	}
}

// Compile subroutine body
fn (mut c JackCompiler) compile_subroutine_body(subroutine_name string, subroutine_type string) {
	// {
	c.advance()
	
	// varDec*
	for c.current_token().value == 'var' {
		c.compile_var_dec()
	}
	
	// Generate function declaration
	n_locals := c.symbol_table.var_count(.var_var)
	c.vm_writer.write_function('${c.class_name}.$subroutine_name', n_locals)
	
	// Handle constructor/method setup
	if subroutine_type == 'constructor' {
		// Allocate memory for object
		n_fields := c.symbol_table.var_count(.field_var)
		c.vm_writer.write_push('constant', n_fields)
		c.vm_writer.write_call('Memory.alloc', 1)
		c.vm_writer.write_pop('pointer', 0)
	} else if subroutine_type == 'method' {
		// Set this pointer
		c.vm_writer.write_push('argument', 0)
		c.vm_writer.write_pop('pointer', 0)
	}
	
	// statements
	c.compile_statements()
	
	// }
	c.advance()
}

// Compile variable declaration
fn (mut c JackCompiler) compile_var_dec() {
	// var
	c.advance()
	
	// type
	type_ := c.current_token().value
	c.advance()
	
	// varName
	name := c.current_token().value
	c.symbol_table.define(name, type_, .var_var)
	c.advance()
	
	// (, varName)*
	for c.current_token().value == ',' {
		c.advance() // ,
		name2 := c.current_token().value
		c.symbol_table.define(name2, type_, .var_var)
		c.advance()
	}
	
	// ;
	c.advance()
}

// Compile statements
fn (mut c JackCompiler) compile_statements() {
	for c.current_token().value in ['let', 'if', 'while', 'do', 'return'] {
		match c.current_token().value {
			'let' { c.compile_let() }
			'if' { c.compile_if() }
			'while' { c.compile_while() }
			'do' { c.compile_do() }
			'return' { c.compile_return() }
			else { break }
		}
	}
}

// Compile let statement
fn (mut c JackCompiler) compile_let() {
	// let
	c.advance()
	
	// varName
	var_name := c.current_token().value
	symbol := c.symbol_table.lookup(var_name)
	c.advance()
	
	mut is_array := false
	
	// [expression]?
	if c.current_token().value == '[' {
		is_array = true
		c.advance() // [
		
		// Push array base address
		c.vm_writer.write_push(var_kind_to_segment(symbol.kind), symbol.index)
		
		// expression (index)
		c.compile_expression()
		
		// Add base + index
		c.vm_writer.write_arithmetic('add')
		
		c.advance() // ]
	}
	
	// =
	c.advance()
	
	// expression
	c.compile_expression()
	
	if is_array {
		// Store in array
		c.vm_writer.write_pop('temp', 0)    // Store value
		c.vm_writer.write_pop('pointer', 1) // Set THAT pointer
		c.vm_writer.write_push('temp', 0)   // Push value back
		c.vm_writer.write_pop('that', 0)    // Store in array
	} else {
		// Store in variable
		c.vm_writer.write_pop(var_kind_to_segment(symbol.kind), symbol.index)
	}
	
	// ;
	c.advance()
}

// Compile if statement
fn (mut c JackCompiler) compile_if() {
	// if
	c.advance()
	
	// (
	c.advance()
	
	// expression
	c.compile_expression()
	
	// )
	c.advance()
	
	// Generate labels
	if_true := 'IF_TRUE${c.if_label_num}'
	if_false := 'IF_FALSE${c.if_label_num}'
	if_end := 'IF_END${c.if_label_num}'
	c.if_label_num++
	
	// If condition is true, goto IF_TRUE
	c.vm_writer.write_if(if_true)
	c.vm_writer.write_goto(if_false)
	c.vm_writer.write_label(if_true)
	
	// {
	c.advance()
	
	// statements
	c.compile_statements()
	
	// }
	c.advance()
	
	// else?
	if c.current_token().value == 'else' {
		c.vm_writer.write_goto(if_end)
		c.vm_writer.write_label(if_false)
		
		c.advance() // else
		c.advance() // {
		
		c.compile_statements()
		
		c.advance() // }
		
		c.vm_writer.write_label(if_end)
	} else {
		c.vm_writer.write_label(if_false)
	}
}

// Compile while statement
fn (mut c JackCompiler) compile_while() {
	// Generate labels
	while_exp := 'WHILE_EXP${c.while_label_num}'
	while_end := 'WHILE_END${c.while_label_num}'
	c.while_label_num++
	
	c.vm_writer.write_label(while_exp)
	
	// while
	c.advance()
	
	// (
	c.advance()
	
	// expression
	c.compile_expression()
	
	// )
	c.advance()
	
	// Negate and check condition
	c.vm_writer.write_arithmetic('not')
	c.vm_writer.write_if(while_end)
	
	// {
	c.advance()
	
	// statements
	c.compile_statements()
	
	// }
	c.advance()
	
	c.vm_writer.write_goto(while_exp)
	c.vm_writer.write_label(while_end)
}

// Compile do statement
fn (mut c JackCompiler) compile_do() {
	// do
	c.advance()
	
	// subroutineCall
	c.compile_subroutine_call()
	
	// Pop returned value (do statements ignore return value)
	c.vm_writer.write_pop('temp', 0)
	
	// ;
	c.advance()
}

// Compile return statement
fn (mut c JackCompiler) compile_return() {
	// return
	c.advance()
	
	if c.current_token().value != ';' {
		// expression
		c.compile_expression()
	} else {
		// void return - push 0
		c.vm_writer.write_push('constant', 0)
	}
	
	c.vm_writer.write_return()
	
	// ;
	c.advance()
}

// Compile expression
fn (mut c JackCompiler) compile_expression() {
	// term
	c.compile_term()
	
	// (op term)*
	for c.current_token().value in ['+', '-', '*', '/', '&', '|', '<', '>', '='] {
		op := c.current_token().value
		c.advance()
		
		c.compile_term()
		
		// Generate VM arithmetic
		match op {
			'+' { c.vm_writer.write_arithmetic('add') }
			'-' { c.vm_writer.write_arithmetic('sub') }
			'*' { c.vm_writer.write_call('Math.multiply', 2) }
			'/' { c.vm_writer.write_call('Math.divide', 2) }
			'&' { c.vm_writer.write_arithmetic('and') }
			'|' { c.vm_writer.write_arithmetic('or') }
			'<' { c.vm_writer.write_arithmetic('lt') }
			'>' { c.vm_writer.write_arithmetic('gt') }
			'=' { c.vm_writer.write_arithmetic('eq') }
			else {}
		}
	}
}

// Compile term
fn (mut c JackCompiler) compile_term() {
	token := c.current_token()
	
	match token.type_name {
		.int_const {
			// Integer constant
			c.vm_writer.write_push('constant', token.value.int())
			c.advance()
		}
		.string_const {
			// String constant
			str_len := token.value.len
			c.vm_writer.write_push('constant', str_len)
			c.vm_writer.write_call('String.new', 1)
			
			for ch in token.value {
				c.vm_writer.write_push('constant', int(ch))
				c.vm_writer.write_call('String.appendChar', 2)
			}
			c.advance()
		}
		.keyword {
			match token.value {
				'true' {
					c.vm_writer.write_push('constant', 0)
					c.vm_writer.write_arithmetic('not')
				}
				'false', 'null' {
					c.vm_writer.write_push('constant', 0)
				}
				'this' {
					c.vm_writer.write_push('pointer', 0)
				}
				else {}
			}
			c.advance()
		}
		.identifier {
			// Variable, array access, or subroutine call
			if c.peek().value == '[' {
				// Array access
				symbol := c.symbol_table.lookup(token.value)
				c.advance() // varName
				c.advance() // [
				
				// Push array base
				c.vm_writer.write_push(var_kind_to_segment(symbol.kind), symbol.index)
				
				// expression (index)
				c.compile_expression()
				
				// Add base + index
				c.vm_writer.write_arithmetic('add')
				c.vm_writer.write_pop('pointer', 1)
				c.vm_writer.write_push('that', 0)
				
				c.advance() // ]
			} else if c.peek().value in ['(', '.'] {
				// Subroutine call
				c.compile_subroutine_call()
			} else {
				// Variable
				symbol := c.symbol_table.lookup(token.value)
				c.vm_writer.write_push(var_kind_to_segment(symbol.kind), symbol.index)
				c.advance()
			}
		}
		.symbol {
			if token.value == '(' {
				// (expression)
				c.advance() // (
				c.compile_expression()
				c.advance() // )
			} else if token.value in ['-', '~'] {
				// Unary operator
				op := token.value
				c.advance()
				c.compile_term()
				
				if op == '-' {
					c.vm_writer.write_arithmetic('neg')
				} else {
					c.vm_writer.write_arithmetic('not')
				}
			}
		}
		//else {}
	}
}

// Compile subroutine call
fn (mut c JackCompiler) compile_subroutine_call() {
	mut n_args := 0
	mut function_name := ''
	
	if c.peek().value == '(' {
		// Method call on current object
		function_name = '${c.class_name}.${c.current_token().value}'
		c.advance() // subroutineName
		c.advance() // (
		
		// Push 'this' as first argument
		c.vm_writer.write_push('pointer', 0)
		n_args = 1
		
		n_args += c.compile_expression_list()
		
		c.advance() // )
	} else {
		// className.subroutineName or varName.subroutineName
		name := c.current_token().value
		c.advance()
		c.advance() // .
		
		subroutine_name := c.current_token().value
		c.advance()
		c.advance() // (
		
		// Check if it's a variable (method call) or class name (function call)
		symbol := c.symbol_table.lookup(name)
		if symbol.kind != .none {
			// Method call on object
			function_name = '${symbol.type_}.$subroutine_name'
			c.vm_writer.write_push(var_kind_to_segment(symbol.kind), symbol.index)
			n_args = 1
		} else {
			// Function call
			function_name = '${name}.${subroutine_name}'
		}
		
		n_args += c.compile_expression_list()
		
		c.advance() // )
	}
	
	c.vm_writer.write_call(function_name, n_args)
}

// Compile expression list
fn (mut c JackCompiler) compile_expression_list() int {
	mut n_expressions := 0
	
	if c.current_token().value != ')' {
		c.compile_expression()
		n_expressions++
		
		for c.current_token().value == ',' {
			c.advance() // ,
			c.compile_expression()
			n_expressions++
		}
	}
	
	return n_expressions
}

// Compile Jack file to VM code
fn compile_jack_file(input_file string, output_file string) ! {
	// Read and tokenize
	content := os.read_file(input_file)!
	
	// Create tokenizer (assuming we have the tokenizer from stage 10)
	mut tokenizer := new_tokenizer(content)
	
	// Create compiler
	mut compiler := new_compiler(tokenizer.tokens)
	
	// Compile
	compiler.compile_class()
	
	// Write output
	vm_code := compiler.vm_writer.get_output()
	os.write_file(output_file, vm_code)!
	println('Generated VM file: $output_file')
}

// Tokenizer (simplified version for this stage)
struct JackTokenizer {
mut:
	input_text string
	tokens     []Token
}

fn new_tokenizer(input string) JackTokenizer {
	mut tokenizer := JackTokenizer{
		input_text: input
	}
	tokenizer.tokenize()
	return tokenizer
}

fn (mut t JackTokenizer) tokenize() {
	// Keywords and symbols (same as stage 10)
	keywords := ['class', 'constructor', 'function', 'method', 'field', 'static', 'var',
		'int', 'char', 'boolean', 'void', 'true', 'false', 'null', 'this',
		'let', 'do', 'if', 'else', 'while', 'return']
	
	symbols := ['{', '}', '(', ')', '[', ']', '.', ',', ';', '+', '-', '*', '/', '&', '|', '<', '>', '=', '~']
	
	mut cleaned_input := t.remove_comments(t.input_text)
	mut i := 0
	
	for i < cleaned_input.len {
		ch := cleaned_input[i]
		
		if ch.is_space() {
			i++
			continue
		}
		
		if ch == `"` {
			mut str_const := ''
			i++
			for i < cleaned_input.len && cleaned_input[i] != `"` {
				str_const += cleaned_input[i].ascii_str()
				i++
			}
			i++
			t.tokens << Token{
				type_name: .string_const
				value: str_const
			}
			continue
		}
		
		if ch.ascii_str() in symbols {
			t.tokens << Token{
				type_name: .symbol
				value: ch.ascii_str()
			}
			i++
			continue
		}
		
		if ch.is_alnum() || ch == `_` {
			mut token := ''
			for i < cleaned_input.len && (cleaned_input[i].is_alnum() || cleaned_input[i] == `_`) {
				token += cleaned_input[i].ascii_str()
				i++
			}
			
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

fn (t JackTokenizer) remove_comments(input string) string {
	mut result := ''
	mut i := 0
	
	for i < input.len {
		if i < input.len - 1 && input[i] == `/` && input[i + 1] == `/` {
			for i < input.len && input[i] != `\n` {
				i++
			}
			continue
		}
		
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

// Main function
fn main() {
	args := os.args
	if args.len < 2 {
		println('Usage: jack_compiler <input.jack or directory>')
		println('This will generate .vm files with VM code')
		return
	}
	
	input_path := args[1]
	
	if os.is_dir(input_path) {
		// Process all .jack files in directory
		files := os.ls(input_path) or { panic('Cannot read directory') }
		for file in files {
			if file.ends_with('.jack') {
				input_file := os.join_path(input_path, file)
				output_file := input_file.replace('.jack', '.vm')
				compile_jack_file(input_file, output_file) or {
					println('Error processing $file: $err')
				}
			}
		}
	} else if input_path.ends_with('.jack') {
		// Process single file
		output_file := input_path.replace('.jack', '.vm')
		compile_jack_file(input_path, output_file) or {
			println('Error processing file: $err')
		}
	} else {
		println('Input must be a .jack file or directory containing .jack files')
	}
}