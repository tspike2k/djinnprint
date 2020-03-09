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

This project was inspired by Jonathan Blow and his [compiler/game programming streams](https://www.youtube.com/user/jblow888/videos) which indirectly made me interested in both the D programming language and writing a type-safe replacement for printf. Walter Bright deserves a medal for all his efforts on the D programming language. Both he and the D community have done the impossible; together they wrote a legible standard library which has been a tremendous help in learning to use the language. The influence of the C# programming language can be seen by the use of curly braces as format specifiers.