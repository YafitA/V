// v run JackTokenizer.v
// C:\Users\YAFIT\Desktop\nand2tetris\projects\10\ArrayTest
import os
import regex
import strings

const keywords = [
    'class', 'constructor', 'function', 'method', 'field', 'static', 'var',
    'int', 'char', 'boolean', 'void', 'true', 'false', 'null', 'this',
    'let', 'do', 'if', 'else', 'while', 'return',
]

const symbols = [
    '{', '}', '(', ')', '[', ']', '.', ',', ';',
    '+', '-', '*', '/', '&', '|', '<', '>', '=', '~',
]

fn escape_symbol(sym string) string {
    return match sym {
        '<' { '&lt;' }
        '>' { '&gt;' }
        '&' { '&amp;' }
        '"' { '&quot;' }
        else { sym }
    }
}

fn tokenize(content string) []string {
    mut tokens := []string{}
    mut pattern := r'(".*?")|(/\*.*?\*/)|(//.*?$)|\b\w+\b|[{}\(\)\[\].,;+\-*/&|<>=~]'
    mut re := regex.regex_opt(pattern) or { panic(err) }

    for token in re.find_all_str(content) {
        if token.starts_with('//') || token.starts_with('/*') {
            continue
        }
        tokens << token
    }
    return tokens
}

fn token_type(token string) string {
    if token in keywords {
        return 'keyword'
    } else if token in symbols {
        return 'symbol'
    } else if token.starts_with('"') && token.ends_with('"') {
        return 'stringConstant'
    } else if token[0].is_digit() {
        return 'integerConstant'
    } else {
        return 'identifier'
    }
}

fn clean_token(token string) string {
    if token_type(token) == 'stringConstant' {
        return token.trim('"')
    }
    return token
}

fn remove_comments(text string) string {
    mut result := ''
    mut in_block_comment := false
    mut lines := text.split_into_lines()
    for mut line in lines {
        line = line.trim_space()
        if in_block_comment {
            if line.contains('*/') {
                in_block_comment = false
                line = line.all_after('*/')
            } else {
                continue
            }
        }
        if line.starts_with('//') {
            continue
        }
        if line.contains('//') {
            line = line.all_before('//')
        }
        if line.contains('/*') {
            in_block_comment = true
            line = line.all_before('/*')
        }
        result = result + line + '\n'
    }
    return result
}

fn process_file(filename string) {
    println('Processing $filename ...')
    content := os.read_file(filename) or {
        println('Failed to read $filename')
        return
    }

    // Remove multiline comments (/* ... */) and inline comments (// ...)
    mut cleaned := remove_comments(content)

    tokens := tokenize(cleaned)

    out_filename := filename.replace('.jack', 'T.xml')
    mut xml := strings.new_builder(1000)
    xml.writeln('<tokens>')
    for token in tokens {
        ttype := token_type(token)
        val := escape_symbol(clean_token(token))
        xml.writeln('  <$ttype> $val </$ttype>')
    }
    xml.writeln('</tokens>')
    os.write_file(out_filename, xml.str()) or {
        println('Failed to write to $out_filename')
    }
}

fn main() {
    println("Enter the directory path containing Jack files:")
	input_path := os.input("> ")

    if os.is_dir(input_path) {
        println('📁 Reading directory: $input_path')
        for file in os.ls(input_path) or { panic('Failed to list dir') } {
            if file.ends_with('.jack') {
                full_path := os.join_path(input_path, file)
                process_file(full_path)
            }
        }
    } else if input_path.ends_with('.jack') {
        process_file(input_path)
    } else {
        println('❌ Please provide a .jack file or a directory containing .jack files.')
    }
}
