import Base
import ./text.bend as Text

def close_and_return(file: File, s: String) -> IO(String):
  do IO<String>:
    File.close(file)
    return s

def reject_oversize(file: File) -> IO(String):
  do IO<String>:
    File.close(file)
    IO.die(String, 1, "InputTooLarge")

def finish_read_gate(file: File, s: String, too_big: Bool) -> IO(String):
  match too_big:
    case True{}:
      reject_oversize(file)
    case False{}:
      close_and_return(file, s)

def finish_read(p: File & Result<&1, &1, (U32 & String), String>, +max: U32) -> IO(String):
  (file, result) = p
  do IO<String>:
    +s : String <- IO.pass(String, result)
    finish_read_gate(file, s, U32.is_lt(max, U32.from_nat(Text.utf8_length(s))))

def read_file_limited_unchecked(+path: String, +max: U32) -> IO(String):
  do IO<String>:
    f : File <- IO.try(File, File.open(path, "r"))
    p : File & Result<&1, &1, (U32 & String), String> <- File.read(f, U32.add(max, 1))
    finish_read(p, max)

def read_file_limited_gate(+path: String, +max: U32, valid: Bool) -> IO(String):
  match valid:
    case True{}:
      read_file_limited_unchecked(path, max)
    case False{}:
      IO.die(String, 1, "InvalidInputLimit")

def read_file_limited(+path: String, +max: U32) -> IO(String):
  read_file_limited_gate(path, max, U32.is_ne(max, 4294967295))

def read_stdin_limited(+max: U32) -> IO(String):
  read_file_limited("/dev/stdin", max)
