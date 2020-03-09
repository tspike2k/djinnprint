# djinnprint

Type-safe, @nogc functions used to format data as text.

## Example

```D    
char[512] buffer;
auto result = bprint!"The numbers are {2}, {0}, and {1}."(buffer, 1, 2, 3);
printf("%s\n", result.ptr);
```

### Output

```
The numbers are 3, 1, and 2.
```

## About

The D programming language employs a garbage collector to automate memory management by default. This is not always desirable. Though garbage collection can easily be disabled by marking functions with the @nogc attribute, much of the standard library is reliant on the garbage collector and cannot be called from @nogc code. This limitation can be observed in std.format, the portion of the standard library which provides data-to-text formatting. The aim behind djinnprint is to fill this void by providing simple, @nogc compatible data formatting functions. An additional goal is to ease localization efforts by letting the format string determine the order arguments appear in the resulting output.

## Usage

### Format Specifiers

Format specifiers are sections of the format string that will be replaced with a formatted version of a given argument. A format specifier begins with an open curly brace and ends with a closed curly brace. The text between these characters determines which argument will be formatted and in what way. The format specifier must not contain whitespace and and must begin with a decimal indicating the index of the argument to format (starting with index 0). 

If two open curly braces appear next to one another djinnprint will not interpret either characters as the start of a format specifier; instead only one open curly brace will be copied and the rest of the format string will be copied as usual.

Note that formatting options are planned but not currently implemented.

### bprint

bprint is used to format arguments into a fixed size buffer, similar to the snprintf function in C. The format string is passed as a template argument. The function then takes the buffer followed by variadic arguments. The format string is copied into the buffer with each format specifier replaced by the textual representation of a given argument's value. To ensure compatibility with C the end of the resulting string is null terminated. Even if the resulting string is too long to fit in the buffer and is truncated, the last element of the buffer is the null terminator. A slice is returned containing how much was written into the buffer. For a demonstration of this function, see the bprint_examples.d file.

## Status

This project is currently a very early proof-of-concept and is in no way production ready. Further work is planned, however.

### Todo

* Additional function for printing to files (including stdout and stderr).
* Formatting options for variables.
* Support for additional data types (pointers, structs, etc.).
* Thorough testing.

## Installation

Simply copy the file djinnprint.d to the source tree of your project and import the module as you would any other D source code.

## License

[Boost Software License 1.0](https://www.boost.org/LICENSE_1_0.txt)

## Acknowledgments

* This project was inspired by Jonathan Blow and his [compiler/game programming streams](https://www.youtube.com/user/jblow888/videos) which indirectly made me interested in both the D programming language and writing a type-safe replacement for printf.

* Walter Bright deserves a medal for all his efforts on the D programming language. Both he and the D community have done the impossible; together they wrote a legible standard library which has been a tremendous help in learning to use the language.

* The influence of the C# programming language can be seen by the use of curly braces as format specifiers.