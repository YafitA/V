// run command: v run ex2.v

//	Yafit Aton 		211816103
//	Naomi Belenky	212887640

module main

import os

fn bootstrap_code(mut lg LabelGenerator) string {
	return "// Bootstrap code" +
			"\n@256\nD=A\n@SP\nM=D" +"
			\n// call Sys.init 0\n" +
			translate_function("call", ["Sys.init", "0"], mut lg, "Sys") +
			"\n// End of bootstrap code\n\n\n"
			
}

struct LabelGenerator {
mut:
	eq_count int
	gt_count int
	lt_count int
	call_count int
}

// Unique label generator for arithmetic/logical and call-return commands
fn (mut lg LabelGenerator) unique_label(base string) string {
	match base {
		"EQ_TRUE", "EQ_END" {
			label_name := "${base}_${lg.eq_count}"
			lg.eq_count++
			return label_name
		}
		"GT_TRUE", "GT_END" {
			label_name := "${base}_${lg.gt_count}"
			lg.gt_count++
			return label_name
		}
		"LT_TRUE", "LT_END" {
			label_name := "${base}_${lg.lt_count}"
			lg.lt_count++
			return label_name
		}
		"RETURN_ADDRESS" {
			label_name := "${base}_${lg.call_count}"
			lg.call_count++
			return label_name
		
		}
		else {
			return "${base}_UNKNOWN"
		}
	}
}

const segment_map = {
	"local":    "LCL"
	"argument": "ARG"
	"this":     "THIS"
	"that":     "THAT"
}

fn translate_push(segment string, index string, file_name string) string {
	match segment {
		"constant" { return "// push constant ${index}\n@${index}\nD=A\n@SP\nA=M\nM=D\n@SP\nM=M+1" }
		"local", "argument", "this", "that" {
			base := segment_map[segment]
			return "// push ${segment} ${index}\n@${index}\nD=A\n@${base}\nA=M+D\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1"
		}
		"temp" {
			temp_address := 5 + index.int()
			return "// push temp ${index}\n@${temp_address}\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1"
		}
		"static" {
			return "// push static ${index}\n@${file_name}.${index}\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1"
		}
		"pointer" {
			base := if index == "0" { "THIS" } else { "THAT" }
			return "// push pointer ${index}\n@${base}\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1"
		}
		else { return "// Unsupported push segment: ${segment}" }
	}
}

fn translate_pop(segment string, index string, file_name string) string {
	match segment {
		"local", "argument", "this", "that" {
			base := segment_map[segment]
			return "// pop ${segment} ${index}\n@${index}\nD=A\n@${base}\nD=M+D\n@R13\nM=D\n@SP\nAM=M-1\nD=M\n@R13\nA=M\nM=D"
		}
		"temp" {
			temp_address := 5 + index.int()
			return "// pop temp ${index}\n@SP\nAM=M-1\nD=M\n@${temp_address}\nM=D"
		}
		"static" {
			return "// pop static ${index}\n@SP\nAM=M-1\nD=M\n@${file_name}.${index}\nM=D"
		}
		"pointer" {
			base := if index == "0" { "THIS" } else { "THAT" }
			return "// pop pointer ${index}\n@SP\nAM=M-1\nD=M\n@${base}\nM=D"
		}
		else { return "// Unsupported pop segment: ${segment}" }
	}
}

fn translate_arithmetic_logic(command string, mut lg LabelGenerator) string {
	match command {
		"add" { return "// add\n@SP\nAM=M-1\nD=M\nA=A-1\nM=M+D" }
		"sub" { return "// sub\n@SP\nAM=M-1\nD=M\nA=A-1\nM=M-D" }
		"neg" { return "// neg\n@SP\nA=M-1\nM=-M" }
		"eq" {
			eq_true := lg.unique_label("EQ_TRUE")
			eq_end := lg.unique_label("EQ_END")
			return "// eq\n@SP\nAM=M-1\nD=M\nA=A-1\nD=M-D\n@$eq_true\nD;JEQ\n@SP\nA=M-1\nM=0\n@$eq_end\n0;JMP\n($eq_true)\n@SP\nA=M-1\nM=-1\n($eq_end)"
		}
		"gt" {
			gt_true := lg.unique_label("GT_TRUE")
			gt_end := lg.unique_label("GT_END")
			return "// gt\n@SP\nAM=M-1\nD=M\nA=A-1\nD=M-D\n@$gt_true\nD;JGT\n@SP\nA=M-1\nM=0\n@$gt_end\n0;JMP\n($gt_true)\n@SP\nA=M-1\nM=-1\n($gt_end)"
		}
		"lt" {
			lt_true := lg.unique_label("LT_TRUE")
			lt_end := lg.unique_label("LT_END")
			return "// lt\n@SP\nAM=M-1\nD=M\nA=A-1\nD=M-D\n@$lt_true\nD;JLT\n@SP\nA=M-1\nM=0\n@$lt_end\n0;JMP\n($lt_true)\n@SP\nA=M-1\nM=-1\n($lt_end)"
		}
		"and" { return "// and\n@SP\nAM=M-1\nD=M\nA=A-1\nM=M&D" }
		"or"  { return "// or\n@SP\nAM=M-1\nD=M\nA=A-1\nM=M|D" }
		"not" { return "// not\n@SP\nA=M-1\nM=!M" }
		else  { return "// Unsupported command: $command" }
	}
}

fn translate_program_flow(command string, label string, file_name string) string {
	match command {
		"label" { return "// label $label\n(${file_name}.${label})" }
		"goto" { return "// goto $label\n@${file_name}.${label}\n0;JMP" }
		"if-goto" { return "// if-goto $label\n@SP\nAM=M-1\nD=M\n@${file_name}.${label}\nD;JNE" }
		else { return "// Unsupported program flow command: $command" }
	}
}

fn translate_function(command string, args []string, mut lg LabelGenerator, file_name string) string {
	match command {
		"function" {
			func_name := args[0]
			num_locals := args[1].int()
			mut init_locals := []string{}
			for _ in 0 .. num_locals {
				init_locals << "@SP\nA=M\nM=0\n@SP\nM=M+1"
			}
			return "// function $func_name $num_locals in $file_name\n(${file_name}.${func_name})\n" + init_locals.join("\n")
		}
		"call" {
			func_name := args[0]
			num_args := args[1]
			return_address := lg.unique_label("RETURN_ADDRESS")
			return "// call $func_name $num_args" +
				   "\n@$return_address\nD=A\n@SP\nA=M\nM=D\n@SP\nM=M+1" +
			       "\n@LCL\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1" +
			       "\n@ARG\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1" +
			       "\n@THIS\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1" +
			       "\n@THAT\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1" +
			       "\n@SP\nD=M\n@$num_args\nD=D-A\n@5\nD=D-A\n@ARG\nM=D" +
			       "\n@SP\nD=M\n@LCL\nM=D" +
			       "\n@${file_name}.${func_name}\n0;JMP\n($return_address)"
		}
		"return" {
			return "// return\n@LCL\nD=M\n@R13\nM=D" +
					"\n@5\nA=D-A\nD=M\n@R14\nM=D" +
					"\n@SP\nAM=M-1\nD=M\n@ARG\nA=M\nM=D" +
					"\n@ARG\nD=M+1\n@SP\nM=D" +
					"\n@R13\nAM=M-1\nD=M\n@THAT\nM=D" +
					"\n@R13\nAM=M-1\nD=M\n@THIS\nM=D" +
					"\n@R13\nAM=M-1\nD=M\n@ARG\nM=D" +
					"\n@R13\nAM=M-1\nD=M\n@LCL\nM=D" +
					"\n@R14\nA=M\n0;JMP"
		}
		else { return "// Unsupported function call/return command: $command" }
	}
}

fn translate_vm_file(file_path string, mut lg LabelGenerator) !string {
	lines := os.read_lines(file_path) or { return error("Error reading file $file_path") }

	mut translated_lines := []string{}
	file_name := os.file_name(file_path).all_before(".vm")
	translated_lines << "// Translated from $file_path"

	for line in lines {
		mut trimmed := line.trim_space()
		if trimmed.len == 0 || trimmed.starts_with("//") { continue }

		if trimmed.contains("//") {
        	trimmed = trimmed.all_before("//").trim_space()
    	}	
		
		words := trimmed.split(" ")
		command := words[0]

		if command == "push" && words.len == 3 {
			translated_lines << translate_push(words[1], words[2], file_name)
		} else if command == "pop" && words.len == 3 {
			translated_lines << translate_pop(words[1], words[2], file_name)
		} else if command in ["label", "goto", "if-goto"] && words.len == 2 {
			translated_lines << translate_program_flow(command, words[1], file_name)
		} else if command in ["function", "call"] && words.len == 3 {
			translated_lines << translate_function(command, words[1..], mut lg, file_name)
		} else if command == "return" {
			translated_lines << translate_function(command, [], mut lg, file_name)
		} else {
			translated_lines << translate_arithmetic_logic(command, mut lg)
		}
	}

	return translated_lines.join("\n")
}

fn main() {
	println("Enter the directory path containing VM files:")
	dir_path := os.input("> ")

	if !os.is_dir(dir_path) {
		println("Error: The provided path is not a directory.")
		return
	}

	files := os.ls(dir_path) or {
		println("Error reading directory.")
		return
	}
	
	mut output_lines := []string{}
	split_path := dir_path.rsplit('\\')
	write_file_path := '${split_path[0]}.asm'
	output_file := os.join_path(dir_path, write_file_path)

	mut label_gen := LabelGenerator{}
	// Add bootstrap code at the beginning of the output
	if "Sys.vm" in files {
		output_lines << bootstrap_code(mut label_gen)
	}
	

	for file in files {
		if file.ends_with(".vm") {
			full_path := os.join_path(dir_path, file)
			translated := translate_vm_file(full_path, mut label_gen) or {
				println("Skipping $file due to an error.")
				continue
			}
			output_lines << translated
		}
	}

	if output_lines.len > 0 {
		os.write_file(output_file, output_lines.join("\n\n")) or {
			println("Error writing output file.")
			return
		}
		println("Translation complete! Output saved to $output_file")
	} else {
		println("No VM files found in the directory.")
	}
}
