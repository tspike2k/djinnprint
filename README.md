# djinnprint

Type-safe, @nogc functions used to format data as text. Also -betterC compatible.

## Example

```D
import djinnprint;

// Format to a buffer:
char[512] buffer;
printOut(format("The numbers are {2}, {0}, and {1}.\n", buffer, 1, 2, 3)); // prints: The numbers are 3, 1, and 2.

// Format directly to stdout:
formatOut("The numbers are {1}, {2}, and {0}.\n", 1, 2, 3); // prints: The numbers are 2, 3, and 1.

// Format structs:
struct TestStruct
{
    int[2] ints;
    float f;
}

TestStruct test = TestStruct([1, 2], 3.0f);
formatOut("TestStruct{0}\n", test); // prints: TestStruct([1, 2], 3.000000)
```

## About

The D programming language employs a garbage collector to automate memory management by default. This is not always desirable. Though garbage collection can easily be disabled by marking functions with the @nogc attribute, much of the standard library is reliant on the garbage collector and cannot be called from @nogc code. This limitation can be observed in std.format, the portion of the standard library which provides data-to-text formatting. The aim behind djinnprint is to fill this void by providing simple, @nogc compatible data formatting functions. An additional goal is to ease localization efforts by letting the format string determine the order arguments appear in the resulting output.

For a more detailed demonstration of this code, see the included examples.d file.

## Usage

### Format Specifiers

The formatting and printing functions provided by djinnprint each take a format string as the first argument. This string will be copied to the output as-is, except for any format specifiers. A format specifier is a portion of the format string that begins with a single open curly brace ("{") and ends with a closed curly brace ("}"). The text between these characters determines which argument will be formatted and in what way. This text must not contain whitespace and must begin with a number indicating the index of the argument whose value is to be formatted (indices start at zero).

If two open curly braces appear next to one another djinnprint will not interpret the characters as the start of a format specifier; instead it will only output one open curly brace and will continue to copy the rest of the format string as usual, without interpreting either character as the start of a format specifier. In this way, double open curly braces ("{{") act as an escape character.

Special characters within the format specifier allow the user to configure how values will be formatted. Here is a full list of these modifiers and what the effect they have:

* __x__: Real and integer values are formatted in lowercase hexadecimal.
* __X__: Real and integer values are formatted in uppercase hexadecimal.
* __e__: Real values are formatted using lowercase scientific notation.
* __E__: Real values are formatted using uppercase scientific notation.
* __,__: Real and integer values introduce commas at every three non-fractional digits.
* __+__: Real and integer values begin with a plus sign when positive.
* __p*n*__: Real values have their precision set to *n* digits. This determines how many digits should be shown after the decimal point. The default precision for real values is six.
* __z*n*__: Set the desired minimum leading zeroes to *n* digits. This determines determines the number of digits to be printed after the sign character (if applicable) and the leading "0x" designator (if using hexadecimal formatting). If the result is smaller than the minimum number of digits, trailing zeroes are added as needed.

```D
    formatOut("{0X}\n", 255); // prints: 0xFF
    formatOut("{0,+}\n", 12300); // prints: +12,300
    formatOut("{0z6x}\n", 12); // prints: 0x00000c
    formatOut("{0p2}\n", 3.14159); // prints: 3.14q
    formatOut("{0e}\n", 3.14159); // prints: 3.141590e+00
```

### format()

The format function is used to format arguments into a fixed size buffer, similar to the snprintf function in C. The format string is passed as the first argument. The function then takes the buffer followed by variadic arguments. The format string is copied into the buffer with each format specifier replaced by the textual representation of a given argument's value. To ensure compatibility with C the end of the resulting string is null terminated. Even if the resulting string is too long to fit in the buffer and is truncated, the last element of the buffer will be set to the null terminator. A slice containing how much text was written into the buffer is returned.

### formatOut(), formatErr()

Much like the format() function, these functions take a format string as the first argument. The format string is copied to an output stream with each format specifier replaced by the textual representation of a given argument's value. The result of formatOut is sent to the standard output stream while the result of formatErr is sent to the standard error stream.

### printOut(), printErr()

For convenience, printOut() and printErr() are provided to simply take a string and send it to the standard output or standard error streams, respectively. This is especially useful for quickly logging the result of the format() function.

### Formatting unions (experimental)

Unions are an odd case. As union members share the same memory layout, to format each member is redundant. Even worse, under some conditions certain members will be in an invalid state. This could be mitigated by asking the user to supply a toString() method with every union they wish to format. But the union itself shouldn't need to know *how* to format its members. After all, that's the responsibility of this library. Rather the responsibility of the union should be to tell the library which members should be formatted and under what conditions.

By default, only the first member of a union is formatted. If another union member should be formatted instead it can be marked with the @ToPrint UDA. In the case of tagged/discriminated unions, it makes sense to only format a given union member when the union is flagged as being an appropriate type. This can be done by adding a method called toPrintIndex to the union that returns the index of the union member that should be printed. This method must be marked as "nothrow" and "@nogc". See the examples.d file for a demonstration of how to apply this to tagged/discriminated union.

Anonymous unions are a bit trickier. D doesn't provide introspection features for detecting if struct members are part of an anonymous union beyond testing the byte offset of each member. In Phobos, std.format handles anonymous unions by marking members sharing the same memory with __#{overlap ...}__ (see std.format.formatValueImpl() for details). For now, this library simply prints the first member of the anonymous union; the @ToPrint UDA currently can't be used to narrow down which member of an anonymous union should be printed.

### Library initialization

Under normal circumstances the library does not need to perform any initialization logic to run as intended. There are some circumstances, however, where certain library features will not work correctly unless an initialization function is called beforehand. For instance, if the use_cstdio flag is set to false under Windows, the library will need to query Windows for handles to STDOUT and STDERR or any functions that output to either of these streams will not work as expected.

The library will only supply an init function under the conditions where initialization is advisable. This way the user can test at compile-time for the existence of an init function and call it only should that be the case:

```D
static if(__traits(compiles, djinnprint.init()))
{
    djinnprint.init();
}
```

## Status

This project is currently a very early proof-of-concept and is in no way production ready. Further work is planned, however.

### Todo

* Testing on Windows (only tested through Wine on Linux).
* Allow toPrintIndex to work for structs as well as unions. This would enable users to specify how to format, say, a custom tagged union type.

## Installation

Copy the file djinnprint.d to the source tree of your project and import the module as you would any other D source code. It's that simple.

## Acknowledgments

* This project was inspired by Jonathan Blow and his [compiler/game programming streams](https://www.youtube.com/user/jblow888/videos) which indirectly made me interested in both the D programming language and writing a type-safe replacement for printf.

* Walter Bright deserves a medal for all his efforts on the D programming language. Both he and the D community have done the impossible; together they wrote a legible standard library which has been a tremendous help in learning to use the language.

* The influence of the C# programming language can be seen by the use of curly braces as format specifiers.

## License

[Boost Software License 1.0](https://www.boost.org/LICENSE_1_0.txt)
