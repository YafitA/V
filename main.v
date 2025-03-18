import os



fn main(){
  // get first directory name
  folder_path := os.input('Enter path name: ')
    split_path := folder_path.rsplit('\\')
    println('Dir name:  ${split_path[0]}')

  // get all read_files
  read_files := os.ls(folder_path) or {
        println('Failed to read directory')
        return
    }
    read_files.filter(it.ends_with('.vm'))
  println('read_files name:  ${read_files}')

  // create write_file
    write_file_path := '${split_path[0]}.asm'
  mut write_file := os.create(write_file_path) or { 
        println('Failed to create file')
        return
    }

  for read_file in read_files{
    full_path := os.join_path(folder_path, read_file)
    read_file_name:=read_file.trim('.vm')
        write_file.write_string('${read_file_name}\n') or {
             println('Failed to write to file')
         }
  }

  write_file.close()
    println('File written successfully!')

}