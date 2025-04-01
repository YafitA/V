module main

import os

// מבנה שמנהל תוויות ייחודיות לכל סוג פקודה
struct LabelGenerator {
mut:
	eq_count int
	gt_count int
	lt_count int
}

// פונקציה ליצירת שם תווית ייחודי
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
		else {
			return "${base}_UNKNOWN"
		}
	}
}

// מפה שמתרגמת שמות מקטעים לכתובות
const segment_map = {
	"local":    "LCL"
	"argument": "ARG"
	"this":     "THIS"
	"that":     "THAT"
}

// פונקציה לתרגום פקודת push
fn translate_push(segment string, index string, file_name string) string {
	match segment {
		"constant" { return "// push constant $index\n@$index\nD=A\n@SP\nA=M\nM=D\n@SP\nM=M+1" }
		"local", "argument", "this", "that" {
			base := segment_map[segment]
			return "// push $segment $index\n@$index\nD=A\n@$base\nA=M+D\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1"
		}
		"temp" {
			temp_address := 5 + index.int()
			return "// push temp $index\n@$temp_address\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1"
		}
		"static" {
			return "// push static $index from '$file_name.vm'\n@$file_name.$index\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1"
		}
		"pointer" {
			base := if index == "0" { "THIS" } else { "THAT" }
			return "// push pointer $index\n@$base\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1"
		}
		else { return "// Unsupported push segment: $segment" }
	}
}

// פונקציה לתרגום פקודת pop
fn translate_pop(segment string, index string, file_name string) string {
	match segment {
		"local", "argument", "this", "that" {
			base := segment_map[segment]
			return "// pop $segment $index\n@$index\nD=A\n@$base\nD=M+D\n@R13\nM=D\n@SP\nAM=M-1\nD=M\n@R13\nA=M\nM=D"
		}
		"temp" {
			temp_address := 5 + index.int()
			return "// pop temp $index\n@SP\nAM=M-1\nD=M\n@$temp_address\nM=D"
		}
		"static" {
			return "// pop static $index from '$file_name.vm'\n@SP\nAM=M-1\nD=M\n@$file_name.$index\nM=D"
		}
		"pointer" {
			base := if index == "0" { "THIS" } else { "THAT" }
			return "// pop pointer $index\n@SP\nAM=M-1\nD=M\n@$base\nM=D"
		}
		else { return "// Unsupported pop segment: $segment" }
	}
}

// פונקציה לקריאת קובץ VM ותרגומו לשפת HACK
fn translate_vm_file(file_path string, mut lg LabelGenerator) !string {
	lines := os.read_lines(file_path) or { return error("Error reading file $file_path") }

	mut translated_lines := []string{}
	file_name := os.file_name(file_path).all_before(".vm")
	translated_lines << "// Translated from $file_path"

	for line in lines {
		trimmed := line.trim_space()
		if trimmed.len == 0 || trimmed.starts_with("//") { continue } // דילוג על שורות ריקות והערות

		words := trimmed.split(" ")
		command := words[0]

		if command == "push" && words.len == 3 {
			translated_lines << translate_push(words[1], words[2], file_name)
		} else if command == "pop" && words.len == 3 {
			translated_lines << translate_pop(words[1], words[2], file_name)
		} else {
			translated_lines << translate_command(command, mut lg)
		}
	}

	return translated_lines.join("\n")
}

// פונקציה ראשית
fn main() {
	println("Enter the directory path containing VM files:")
	dir_path := os.input("> ")

	if !os.is_dir(dir_path) {
		println("Error: The provided path is not a directory.")
		return
	}

	vm_files := os.ls(dir_path) or {
		println("Error reading directory.")
		return
	}

	mut output_lines := []string{}
	split_path := dir_path.rsplit('\\')
	write_file_path := '${split_path[0]}.asm'
	output_file := os.join_path(dir_path, write_file_path)

	mut label_gen := LabelGenerator{} // יצירת מחולל תוויות

	for file in vm_files {
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
