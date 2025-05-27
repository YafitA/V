import regex
fn main() {
	string_pattern := r'^\s*"(.*)"\s*'
	txt := '"hello" and "world"'

	mut re := regex.regex_opt(string_pattern) or { panic('Invalid regex pattern') }
	mut start, mut end := re.match_string(txt)

	println('Matched: $start $end')

	if start >= 0 {
		groups := re.get_group_list()
		
		println(groups)
		
	}

}