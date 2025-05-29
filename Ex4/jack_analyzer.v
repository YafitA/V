// jack_analyzer.v - Master program that runs both stages
import os

fn main() {
	args := os.args
	if args.len < 2 {
		println('Jack Analyzer - Nand2Tetris Project 10')
		println('Usage: jack_analyzer <input.jack or directory>')
		println('')
		println('This program performs two stages:')
		println('1. Tokenizing: .jack -> T.xml (tokens)')
		println('2. Parsing: T.xml -> .xml (syntax tree)')
		println('')
		return
	}
	
	input_path := args[1]
	
	if !os.exists(input_path) {
		println('Error: Input path does not exist: $input_path')
		return
	}
	
	os.execute('v run jack_tokenizer.v $input_path')
	os.execute('v run jack_parser.v $input_path') 
}
