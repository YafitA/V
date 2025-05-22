module main

import os
import regex

enum TokenType {
    keyword
    symbol
    identifier
    integer_const
    string_const
    none
}

const keywords = [
    'class', 'constructor', 'function', 'method', 'field', 'static', 'var',
    'int', 'char', 'boolean', 'void', 'true', 'false', 'null', 'this',
    'let', 'do', 'if', 'else', 'while', 'return',
]

const symbols = ['{','}','(',')','[',']','.',';',',','+','-','*','/','&','|','<','>','=','~']

fn escape_xml(s string) string {
    return s.replace_each([
        '&', '&amp;',
        '<', '&lt;',
        '>', '&gt;',
        '"', '&quot;',
    ])
}

struct Token {
    token_type TokenType
    value      string
}

struct JackTokenizer {
    source      string
    tokens      []Token
    current_pos int
}

fn remove_comments(text string) string {
    mut result := ''
    mut in_block_comment := false
    lines := text.split_into_lines()
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
        if line.contains('/*') {
            in_block_comment = true
            line = line.all_before('/*')
        }
        result += line + '\n'
    }
    return result
}

fn (mut t JackTokenizer) tokenize() {
    int_pat := r'^\d+'
    str_pat := r'^"[^"\n]*"'
    id_pat := r'^[a-zA-Z_]\w*'
    sym_pat := r'^[' + regex.escape(symbols.join('')) + ']'

    mut i := 0
    for i < t.source.len {
        ch := t.source[i]
        if ch.is_space() {
            i++
            continue
        }

        remainder := t.source[i..]

        if remainder.starts_with('"') {
            match := regex.regex_find_first_str(str_pat, remainder) or { '' }
            if match.len > 0 {
                t.tokens << Token{TokenType.string_const, match[1..match.len-1]}
                i += match.len
                continue
            }
        }

        match := regex.regex_find_first_str(int_pat, remainder) or { '' }
        if match.len > 0 {
            num := match.int()
            if num >= 0 && num <= 32767 {
                t.tokens << Token{TokenType.integer_const, match}
            }
            i += match.len
            continue
        }

        match = regex.regex_find_first_str(sym_pat, remainder) or { '' }
        if match.len > 0 {
            t.tokens << Token{TokenType.symbol, match}
            i += match.len
            continue
        }

        match = regex.regex_find_first_str(id_pat, remainder) or { '' }
        if match.len > 0 {
            if match in keywords {
                t.tokens << Token{TokenType.keyword, match}
            } else {
                t.tokens << Token{TokenType.identifier, match}
            }
            i += match.len
            continue
        }

        i++
    }
}

fn write_xml(tokens []Token, output_path string) ? {
    mut xml := '<tokens>\n'
    for token in tokens {
        value := escape_xml(token.value)
        match token.token_type {
            .keyword      { xml += '  <keyword> ${value} </keyword>\n' }
            .symbol       { xml += '  <symbol> ${value} </symbol>\n' }
            .identifier   { xml += '  <identifier> ${value} </identifier>\n' }
            .integer_const{ xml += '  <integerConstant> ${value} </integerConstant>\n' }
            .string_const { xml += '  <stringConstant> ${value} </stringConstant>\n' }
            else {}
        }
    }
    xml += '</tokens>\n'
    os.write_file(output_path, xml)?
}

fn process_file(jack_path string) {
    contents := os.read_file(jack_path) or {
        eprintln('Failed to read $jack_path')
        return
    }

    clean_source := remove_comments(contents)
    mut tokenizer := JackTokenizer{
        source: clean_source
    }
    tokenizer.tokenize()

    output_path := jack_path.replace('.jack', 'T.xml')
    write_xml(tokenizer.tokens, output_path) or {
        eprintln('Failed to write $output_path')
        return
    }
    println('✅ Tokenized: ${os.file_name(jack_path)} → ${os.file_name(output_path)}')
}

fn main() {
    // ✏️ שימי כאן את הנתיב לתיקייה שלך (אפשר גם קובץ .jack ישירות)
    input_path := './YourJackFolder'

    if os.is_dir(input_path) {
        println('📁 Reading directory: $input_path')
        for entry in os.ls(input_path) or { panic('Failed to list dir') } {
            if entry.ends_with('.jack') {
                full_path := os.join_path(input_path, entry)
                process_file(full_path)
            }
        }
    } else if input_path.ends_with('.jack') {
        process_file(input_path)
    } else {
        println('❌ Please provide a .jack file or a directory containing .jack files.')
    }
}
