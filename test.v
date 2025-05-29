fn main() {
	txt := ' Hello, World!  '
	println('Original: "$txt"')
	trimmed := txt.trim_right(' ').trim_left(' ')
	println('Trimmed: "$trimmed"')

	mut txt2 := '  '
	println('Original: "$txt2"')
	txt2 = trim_single_spaces(txt2)
	println('Original: "$txt2"')

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