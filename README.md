# djinnprint

Type-safe, @nogc functions used to format data as text. Also -betterC compatible.

## Example

```D    
// Format to a buffer:
char[512] buffer;
printOut(format!"The numbers are {2}, {0}, and {1}.\n"(buffer, 1, 2, 3));

// Format directly to stdout:
printOut!"The numbers are {1}, {2}, and {0}.\n"(1, 2, 3);
```

### Output

```
The numbers are 3, 1, and 2.
The numbers are 2, 3, and 1.
```

## About

The D programming language employs a garbage collector to automate memory management by default. This is not always desirable. Though garbage collection can easily be disabled by marking functions with the @nogc attribute, much of the standard library is reliant on the garbage collector and cannot be called from @nogc code. This limitation can be observed in std.format, the portion of the standard library which provides data-to-text formatting. The aim behind djinnprint is to fill this void by providing simple, @nogc compatible data formatting functions. An additional goal is to ease localization efforts by letting the format string determine the order arguments appear in the resulting output.

For a demonstration of this code, see the examples.d file.

## Usage

### Format Specifiers

The formatting and printing functions provided by djinnprint each take a format string as a template argument. This string will be copied to the output as-is, except for any format specifiers. A format specifier is a portion of the format string that begins with a single open curly brace ("{") and ends with a closed curly brace ("}"). The text between these characters determines which argument will be formatted and in what way. The format specifier must not contain whitespace and and must begin with a number indicating the index of the argument whose value is to be formatted (indices start at zero). 

If two open curly braces appear next to one another djinnprint will not interpret either characters as the start of a format specifier; instead only one open curly brace will be copied to the output and the rest of the format string will be copied as usual.

Note that formatting options are planned but not currently implemented.

### format()

The format function is used to format arguments into a fixed size buffer, similar to the snprintf function in C. The format string is passed as a template argument. The function then takes the buffer followed by variadic arguments. The format string is copied into the buffer with each format specifier replaced by the textual representation of a given argument's value. To ensure compatibility with C the end of the resulting string is null terminated. Even if the resulting string is too long to fit in the buffer and is truncated, the last element of the buffer is the null terminator. A slice is returned containing how much was written into the buffer.

### printOut(), printErr()

Much like the format() function, these functions take a format string as a template argument. The format string is copied to an output stream with each format specifier replaced by the textual representation of a given argument's value. The result of printOut is sent to the standard output stream while the result of printErr is sent to the standard error stream.

For convenience, alternate versions of printOut() and printErr() are provided that simply take a string and send it to the standard output or standard error stream, respectively. This is especially useful for quickly logging the result of the format() function.

### Formatting unions (experimental)

Unions are an odd case. Under some conditions certain members will be in an invalid state. This could be mitigated by asking the user to supply a toString() method with every union they wish to format. But the union itself shouldn't need to know HOW to format their arguments. After all, that's the responsibility of the formatting functions. Rather the responsibility of the union should be to tell the library which members should be formatted. This is done by adding a toPrint enum on the union. This enum is an array of strings containing the names of every member that should be formatted. If no such enum is provided the resulting output will be the identifier of the union itself.

In the future the toPrint enum will likely be changed to allow arbitrary logic to be run by the formatting functions. 

### Initializing djinnprint

Under some platforms (such as Windows) djinnprint will need to be initialized in order to set up pointers to the standard output/error streams. This is done automatically if module constructors are enabled. If module constructors are disabled (in the case of compiling without the D-runtime or using the -betterC compiler switch in DMD) djinnprint.useModuleConstructors must be set to false and djinnprint.init should be called before calling any of the printing functions provided by djinnprint. 

## Status

This project is currently a very early proof-of-concept and is in no way production ready. Further work is planned, however.

### Todo

* Add formatting options for variables.
* Support for additional data types (pointers, structs, etc.).
* Testing on Windows.
* Thorough testing.
* Float to string conversion that doesn't rely on snprintf.
* Improve union formatting by allowing arbitrary logic in the toPrint enum that will determine the list of members to format.

## Installation

Simply copy the file djinnprint.d to the source tree of your project and import the module as you would any other D source code. It's that simple.

## License

[Boost Software License 1.0](https://www.boost.org/LICENSE_1_0.txt)

## Acknowledgments

* This project was inspired by Jonathan Blow and his [compiler/game programming streams](https://www.youtube.com/user/jblow888/videos) which indirectly made me interested in both the D programming language and writing a type-safe replacement for printf.

* Walter Bright deserves a medal for all his efforts on the D programming language. Both he and the D community have done the impossible; together they wrote a legible standard library which has been a tremendous help in learning to use the language.

* The influence of the C# programming language can be seen by the use of curly braces as format specifiers.