// Authors:   tspike (github.com/tspike2k)
// Copyright: Copyright (c) 2020
// License:   Boost Software License 1.0 (https://www.boost.org/LICENSE_1_0.txt)

// TODO:

// - Do not use .stringof for code generation; use __traits(identifier, var) instead. See this page for details:
// https://dlang.org/spec/property.html#stringof

// - Print doubles

// - Testing on Windows

// - Custom float/double to string conversion that doesn't rely on snprintf

// - Put quotes around string values when printing functions/unions

// - Figure out how to reduce code duplication between the two versions of formatArg

// - Add formatting options for variables (commas for integers, hex output, etc.)
//   Additionally, there should be an option to print the name of each struct type before the value of its members. This could be useful in code generation.
//   For instance, printing `Vect2(1.0000f, 1.0000f)` would be useful for this case rather than `(1.0000, 1.000)`, the latter of which is the default behavior.

// NOTE: The order of members returned by __traits(allMembers) is not guaranteed to be in the orde they appear in the struct definiation.
// However, it SEEMS that the .tupleof property is expected (perhaps even required) to be ordered this way. This behavior is what we're relying on.
// Should it change, we're going to have to make some changes.
//
// See here for some discussions on this topic:
// https://forum.dlang.org/thread/bug-19036-3@https.issues.dlang.org%2F
// https://forum.dlang.org/thread/odpdhayvxaglheqcntwj@forum.dlang.org
// https://forum.dlang.org/post/stvphdwgugrlcgfkbyxc@forum.dlang.org

module djinnprint;

enum ToPrint;

struct ToPrintWhen(T)
{
    string unionTag;
    T[]      cases;
    string[] members;
}

private @nogc nothrow:

// Library configuration options:
enum assertOnTruncation     = false; // Trigger an assertion when formatting to a buffer results in a string larger than the buffer size
enum assertOnUnhandledUnion = false; // Assert when a union without ToPrint or ToPrintWhen UDAs is found while formatting.
enum use_cstdio             = true; // Use the standard C library output functions when printing to the console

import std.traits;

alias ArrayTarget(T : U[], U) = U;
enum bool isCString(T) = is(T == char*) || is(T == const(char)*) || is(T == immutable(char)*);
enum bool isCharArray(T) = isArray!T && (is(ArrayTarget!(T) == char) || is(ArrayTarget!(T) == immutable char) || is(ArrayTarget!(T) == const char));

static if(use_cstdio)
{
    import core.stdc.stdio : FILE, stdout, stderr;
    alias FileHandle = FILE*;
    alias stdOut = stdout;
    alias stdErr = stderr;

    public void init(){};
}
else
{
    version(Posix)
    {
        alias FileHandle = int;
        enum FileHandle stdOut = 1;
        enum FileHandle stdErr = 2;

        public void init(){};
    }
    else version(Windows)
    {
        // TODO: Test on Windows
        import core.sys.windows : FileHandle, GetStdHandle;
        alias FileHandle = HANDLE;
        __gshared FileHandle stdOut;
        __gshared FileHandle stdErr;

        public void init()
        {
            HANDLE stdOut = GetStdHandle(STD_OUTPUT_HANDLE);
            HANDLE stdErr = GetStdHandle(STD_ERROR_HANDLE);
        }

        version(D_ModuleInfo)
        {
            static this()
            {
                init();
            }
        }
    }
    else
    {
        static assert(0, "Unsupported OS.");
    }
}

immutable char[] intToCharTable = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f'];

size_t length(const(char*) s)
{
    size_t result = 0;

    while(s[result] != '\0')
    {
        result++;
    }

    return result;
}

ulong formatArg(T)(T t, in FormatSpec spec, char[] buffer)
{
    ulong bytesWritten = 0;
    bool truncated = false;

    static if (is(T == enum))
    {
        static foreach (i, member; EnumMembers!T)
        {
            if (t == member)
            {
                bytesWritten = safeCopy(buffer, __traits(identifier, EnumMembers!T[i]), &truncated);
            }
        }
    }
    else static if(is(T == bool))
    {
        if(t)
        {
            bytesWritten = safeCopy(buffer, "true", &truncated);
        }
        else
        {
            bytesWritten = safeCopy(buffer, "false", &truncated);
        }
    }
    else static if (isIntegral!T)
    {
        bytesWritten = intToString(buffer, t, 10, spec);
    }
    else static if (is(T == float))
    {
        // TODO: Eleminate our dependence on snprintf and use our own float formatting functions. Look to stb_sprintf?
        // Note that even Phobos (the D standard library) used snprintf to format floats.
        import core.stdc.stdio : snprintf;
        bytesWritten = snprintf(buffer.ptr, buffer.length, "%f", t);
    }
    else static if(isCString!T)
    {
        size_t srcLength = 0;
        while(t[srcLength] != '\0') srcLength++;

        bytesWritten = safeCopy(buffer, t[0 .. srcLength], &truncated);
    }
    else static if(isCharArray!T)
    {
        bytesWritten = safeCopy(buffer, t, &truncated);
    }
    else static if(is(T == struct))
    {
        bytesWritten += safeCopy(buffer[bytesWritten .. $], "(", &truncated);
        auto members = t.tupleof;
        static foreach(i, member; members)
        {
            bytesWritten += formatArg(member, spec, buffer[bytesWritten .. $]);
            static if(i < members.length - 1) bytesWritten += safeCopy(buffer[bytesWritten .. $], ", ", &truncated);
        }
        bytesWritten += safeCopy(buffer[bytesWritten .. $], ")", &truncated);
    }
    else static if(is(T == union))
    {
        alias toPrintMembers = getSymbolsByUDA!(T, ToPrint);
        static if (toPrintMembers.length > 0)
        {
            bytesWritten += safeCopy(buffer[bytesWritten .. $], "(", &truncated);
            static foreach(i, member; toPrintMembers)
            {
                bytesWritten += formatArg(mixin("t." ~ member.stringof), spec, buffer[bytesWritten .. $]);
                static if (i < toPrintMembers.length - 1)
                {
                    bytesWritten += safeCopy(buffer[bytesWritten .. $], ", ", &truncated);
                }
            }
            bytesWritten += safeCopy(buffer[bytesWritten .. $], ")", &truncated);
        }
        else if (hasUDA!(T, ToPrintWhen))
        {
            enum uda = getUDAs!(T, ToPrintWhen)[0];
            static assert(uda.cases.length == uda.members.length);

            tagSwitch: switch(mixin("t." ~ uda.unionTag))
            {
                static foreach(i, c; uda.cases)
                {
                    case c: bytesWritten += formatArg(mixin("t." ~ uda.members[i]), spec, buffer[bytesWritten .. $]);
                    break tagSwitch;
                }

                default: assert(0); break;
            }
        }
        else
        {
            static if(assertOnUnhandledUnion)
            {
                pragma(msg, "ERR: Unhandled union " ~ T.stringof ~ ". No @toPrint UDA found.");
                static assert(0);
            }

            bytesWritten += safeCopy(buffer[bytesWritten .. $], "union ", &truncated);
            bytesWritten += safeCopy(buffer[bytesWritten .. $], T.stringof, &truncated);
        }
    }
    else static if(isArray!T)
    {
        bytesWritten += safeCopy(buffer[bytesWritten .. $], "[", &truncated);

        foreach(i; 0 .. t.length)
        {
            bytesWritten += formatArg(t[i], spec, buffer[bytesWritten .. $]);
            if (i < t.length - 1)
            {
                bytesWritten += safeCopy(buffer[bytesWritten .. $], ", ", &truncated);
            }
        }

        bytesWritten += safeCopy(buffer[bytesWritten .. $], "]", &truncated);
    }
    else static if (isPointer!T)
    {
        bytesWritten = intToString(buffer, cast(size_t)t, 16, spec);
    }
    else
    {
        pragma(msg, "ERR in print.formatArg(...): Unhandled type " ~ T.stringof);
        static assert(0);
    }

    static if(assertOnTruncation) assert(!truncated);

    return bytesWritten;
}

void formatArg(T)(T t, in FormatSpec spec, FileHandle file)
{
    static if (is(T == enum))
    {
        static foreach (i, member; EnumMembers!T)
        {
            if (t == member)
            {
                printFile(file, __traits(identifier, EnumMembers!T[i]));
            }
        }
    }
    else static if(is(T == bool))
    {
        if(t)
        {
            printFile(file, "true");
        }
        else
        {
            printFile(file, "false");
        }
    }
    else static if (isIntegral!T)
    {
        char[30] buffer;
        auto length = intToString(buffer, t, 10, spec);
        printFile(file, buffer[0 .. length]);
    }
    else static if (is(T == float))
    {
        // TODO: Eleminate our dependence on snprintf and use our own float formatting functions. Look to stb_sprintf?
        // Note that even Phobos (the D standard library) used snprintf to format floats.
        import core.stdc.stdio : snprintf;
        char[512] buffer;
        auto written = snprintf(buffer.ptr, buffer.length, "%f", t);
        printFile(file, buffer[0..written]);
    }
    else static if(isCString!T)
    {
        auto msg = t[0 .. length(t)];
        printFile(file, msg);
    }
    else static if(isCharArray!T)
    {
        printFile(file, t);
    }
    else static if(is(T == struct))
    {
        printFile(file, "(");
        auto members = t.tupleof;
        static foreach(i, member; members)
        {
            formatArg(member, spec, file);
            static if(i < members.length - 1) printFile(file, ", ");
        }
        printFile(file, ")");
    }
    else static if(is(T == union))
    {
        alias toPrintMembers = getSymbolsByUDA!(T, ToPrint);
        static if (toPrintMembers.length > 0)
        {
            printFile(file, "(");
            static foreach(i, member; toPrintMembers)
            {
                formatArg(mixin("t." ~ member.stringof), spec, file);
                static if (i < toPrintMembers.length - 1)
                {
                    printFile(file, ", ");
                }
            }
            printFile(file, ")");
        }
        else if (hasUDA!(T, ToPrintWhen))
        {
            enum uda = getUDAs!(T, ToPrintWhen)[0];
            static assert(uda.cases.length == uda.members.length);

            tagSwitch: switch(mixin("t." ~ uda.unionTag))
            {
                static foreach(i, c; uda.cases)
                {
                    case c: formatArg(mixin("t." ~ uda.members[i]), spec, file);
                    break tagSwitch;
                }

                default: assert(0); break;
            }
        }
        else
        {
            static if(assertOnUnhandledUnion)
            {
                pragma(msg, "ERR: Unhandled union " ~ T.stringof ~ ". No @toPrint UDA found.");
                static assert(0);
            }
            printFile(file, "union ");
            printFile(file, T.stringof);
        }
    }
    else static if(isArray!T)
    {
        printFile(file, "[");

        foreach(i; 0 .. t.length)
        {
            formatArg(t[i], spec, file);
            if (i < t.length - 1)
            {
                printFile(file, ", ");
            }
        }

        printFile(file, "]");
    }
    else static if (isPointer!T)
    {
        char[30] buffer;
        auto length = intToString(buffer, cast(size_t)t, 16, spec);
        printFile(file, buffer[0 .. length]);
    }
    else
    {
        pragma(msg, "ERR in print.formatArg(...): Unhandled type " ~ T.stringof);
        static assert(0);
    }
}

struct FormatSpec
{
   // TODO: More format specifiers, such as 'h' for hex.
    uint argIndex;
}

bool isDigit(char c)
{
    return (c >= '0') && (c <= '9');
}

FormatSpec getFormatSpec(in char[] command)
{
    import core.stdc.stdlib : atoi;
    import core.stdc.string : memcpy;

    FormatSpec result;
    assert(isDigit(command[0]), "Format command must start with numeric argument index.");

    size_t end = 0;
    foreach(i, _; command)
    {
        end++;
        if (!isDigit(command[i]))
        {
            break;
        }
    }

    char[12] argIndexStr;
    assert(end < argIndexStr.length);
    memcpy(argIndexStr.ptr, command.ptr, end);
    argIndexStr[end] = '\0';
    uint argIndex = atoi(argIndexStr.ptr);
    result.argIndex = argIndex;

    return result;
}

size_t safeCopy(T)(char[] dest, T source, bool* truncated)
if (isCharArray!T)
{
    size_t bytesToCopy = void;

    if(dest.length < source.length)
    {
        bytesToCopy = dest.length;
        *truncated = true;
    }
    else
    {
        bytesToCopy = source.length;
    }

    dest[0 .. bytesToCopy] = source[0 .. bytesToCopy];
    return bytesToCopy;
}

size_t intToString(T)(char[] buffer, T t, ubyte base, FormatSpec spec)
if(isIntegral!T)
{
    static if (isSigned!T)
    {
        import std.math : abs, sgn;
        T sign = cast(T)sgn(t);
        t = abs(t); // NOTE: Strip off the sign to prevent the mod operator from giving us a negative array index.
    }

    char[30] conversion; // NOTE: This should be plenty large enough to hold even the maximum value of a ulong.
    size_t finish = conversion.length;

    foreach_reverse(place; 0..finish)
    {
        conversion[place] = intToCharTable[t % base];
        t /= base;

        // TODO: Add commas in the conversion string?

        if(t == 0)
        {
            static if (isSigned!T)
            {
                if (sign < 0 && place > 0)
                {
                    place--;
                    conversion[place] = '-';
                }
            }

            if(base == 16 && place >= 2)
            {
                conversion[--place] = 'x';
                conversion[--place] = '0';
            }

            finish = place;
            break;
        }
    }

    size_t charsWritten = conversion.length - finish;
    size_t minToCopy = void;
    if(charsWritten < buffer.length)
    {
        minToCopy = charsWritten;
    }
    else
    {
        static if(assertOnTruncation) assert(0, "ERR: buffer truncated.");
        minToCopy = buffer.length;
    }

    buffer[0..minToCopy] = conversion[finish..finish+minToCopy];
    return minToCopy;
}

public:

enum printCommon = `
    size_t fmtCursor = 0;
    size_t fmtCopyToBufferIndex = 0;

    while(fmtCursor < fmt.length)
    {
        if (fmt[fmtCursor] == '{')
        {
            if (fmtCursor < fmt.length - 1 && fmt[fmtCursor+1] == '{')
            {
                fmtCursor++;
                mixin(outputPolicy);
                fmtCursor++;
                fmtCopyToBufferIndex = fmtCursor;

                continue;
            }

            mixin(outputPolicy);

            fmtCursor++;
            size_t commandStart = fmtCursor;
            size_t commandEnd   = fmtCursor;
            while(fmtCursor < fmt.length)
            {
                if (fmt[fmtCursor] == '}')
                {
                    commandEnd = fmtCursor;
                    fmtCursor++;
                    break;
                }
                fmtCursor++;
            }

            fmtCopyToBufferIndex = fmtCursor;

            auto formatCommand = fmt[commandStart .. commandEnd];

            auto formatSpec = getFormatSpec(formatCommand);
            assert(formatSpec.argIndex < args.length, "ERR: Format index exceeds length of provided arguments.");

            // NOTE: Variadic template argument indexing based on std.format.getNth(...) from Phobos.
            outer: switch(formatSpec.argIndex)
            {
                static foreach(i, _; Args)
                {
                    case i:
                    {
                        mixin(formatPolicy);
                    } break outer;
                }

                default:
                {
                    assert(0,"ERR: Unable to access variadic argument.");
                } break outer;
            }
        }
        else
            fmtCursor++;
    }
    fmtCursor = fmt.length;

    mixin(outputPolicy);
`;

char[] format(T, Args...)(T fmt, char[] buffer, Args args)
if(isCharArray!T)
{
    size_t bufferWritten = 0;
    bool truncated = false;

    enum outputPolicy = `bufferWritten += safeCopy(buffer[bufferWritten..buffer.length], fmt[fmtCopyToBufferIndex .. fmtCursor], &truncated);`;
    enum formatPolicy = `bufferWritten += formatArg(args[i], formatSpec, buffer[bufferWritten .. buffer.length]);`;

    mixin(printCommon);

    size_t zeroIndex = bufferWritten < buffer.length ? bufferWritten : buffer.length - 1;
    buffer[zeroIndex] = '\0';

    static if(assertOnTruncation) assert(!truncated);

    return buffer[0..bufferWritten];
}

void printOut(T, Args...)(T fmt, Args args)
if(isCharArray!T)
{
    FileHandle file = stdOut;

    enum outputPolicy = `printFile(file, fmt[fmtCopyToBufferIndex .. fmtCursor]);`;
    enum formatPolicy = `formatArg(args[i], formatSpec, file);`;

    mixin(printCommon);
}

void printOut(T)(T msg)
if(isCharArray!T)
{
    FileHandle file = stdOut;
    printFile(file, msg);
}

void printErr(T, Args...)(T fmt, Args args)
if(isCharArray!T)
{
    FileHandle file = stdErr;

    enum outputPolicy = `printFile(file, fmt[fmtCopyToBufferIndex..fmtCursor]);`;
    enum formatPolicy = `formatArg(args[i], formatSpec, file);`;

    mixin(printCommon);
}

void printErr(T)(T msg)
if(isCharArray!T)
{
    FileHandle file = stdErr;
    printFile(file, msg);
}

void printFile(T, Args...)(FileHandle file, T fmt, Args args)
if(isCharArray!T)
{
    enum outputPolicy = `printFile(file, fmt[fmtCopyToBufferIndex .. fmtCursor]);`;
    enum formatPolicy = `formatArg(args[i], formatSpec, file);`;

    mixin(printCommon);
}

void printFile(T)(FileHandle file, T msg)
if(isCharArray!T)
{
    static if(use_cstdio)
    {
        import core.stdc.stdio: fwrite;
        if(file)
        {
            fwrite(msg.ptr, msg[0].sizeof, msg.length, file);
        }
    }
    else
    {
        version(Posix)
        {
            import core.sys.posix.unistd : write;
            if (file != -1)
            {
                write(file, msg.ptr, msg.length);
            }
        }
        else version(Windows)
        {
            import core.sys.windows : WriteFile, INVALID_HANDLE_VALUE;
            if(file != INVALID_HANDLE_VALUE)
            {
                WriteFile(file, msg.ptr, msg.length, null, null);
            }
        }
        else
        {
            static assert(0, "Unsupported OS.");
        }
    }
}
