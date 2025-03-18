// run command: v run main.v

import os

struct Totals {
    mut:
    buy f32
    sell f32
}


fn handle_file(mut write_file os.File, file_path string, mut totals Totals) {
  input_file := os.read_file(file_path) or { println('Failed to open file') return } // Read the file
  for line in input_file.split_into_lines() {
    words := line.split(' ')

    command := words[0]
    product := words[1]
    amount := words[2].int()   // Convert to integer
    price := words[3].f32()    // Convert to float

    //Process "buy" and "sell" commands
    match command {
        'buy' { handle_buy(mut write_file, product, amount, price, mut totals) }
        'sell' { handle_sell(mut write_file, product, amount, price, mut totals) }
        'cell' { handle_sell(mut write_file, product, amount, price, mut totals) }
        else {}
    }
    
  }
  return
}

fn handle_buy(mut output os.File, product string, amount int, price f32, mut totals Totals) {
  //Write the buy command to the output file
  buy_res := amount*price
  output.write_string('### BUY ${product} ### \n${buy_res}\n') or { println('Failed to write to file') }
  totals.buy += buy_res
  return
}

fn handle_sell(mut output os.File, product string, amount int, price f32, mut totals Totals) {
  // Write the sell command to the output file
  sell_res := amount*price
  output.write_string('$$$ SELL ${product} $$$ \n${sell_res}\n') or { println('Failed to write to file') }
  totals.sell += sell_res
}

fn main() {

  mut totals := Totals{buy: 0, sell: 0}

  // get first directory name
  folder_path := os.input('Enter path name: ')

  split_path := folder_path.rsplit('\\')
  println('Dir name:  ${split_path[0]}')

  // create write_file
  write_file_path := '${split_path[0]}.asm'
  mut write_file := os.create(write_file_path) or { println('Failed to create file') return }

  // get all read_files
  mut read_files := os.ls(folder_path) or { println('Failed to read directory') return }
  read_files = read_files.filter(it.ends_with('.vm'))
  println('read_files name:  ${read_files}')


  // go over read_files and write to write_file
  for read_file in read_files{
    // write file name to write_file
    read_file_name := read_file.trim('.vm')
    write_file.write_string('\n${read_file_name}\n') or { println('Failed to write to file') }

    full_path := os.join_path(folder_path, read_file)
    handle_file(mut write_file, full_path, mut totals)
  }

  // Print total buy and sell amounts to both console and output file
  write_file.writeln('\nTOTAL BUY: ${totals.buy}') or {}
  write_file.writeln('TOTAL SELL: ${totals.sell}') or {}

  println('\nTOTAL BUY: ${totals.buy}')
  println('TOTAL SELL: ${totals.sell}')


  // close file
  write_file.close()
  println('File written successfully!')
}

