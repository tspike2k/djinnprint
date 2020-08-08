// Authors:   tspike (github.com/tspike2k)
// Copyright: Copyright (c) 2020
// License:   Boost Software License 1.0 (https://www.boost.org/LICENSE_1_0.txt)

// TODO:

// - Do not use .stringof for code generation; use __traits(identifier, <var>) instead. See this page for details:
// https://dlang.org/spec/property.html#stringof

// - Print doubles

// - Figure out how to make ToPrintWhen -betterC compatible

// - Testing on Windows

// - Custom float/double to string conversion that doesn't rely on snprintf

// - Add formatting options for variable (commas for integers, hex output, etc.)
//   Additionally, there should be an option to print the name of each struct type before the value of its members. This could be useful in code generation.
//   For instance, printing `Vect2(1.0000f, 1.0000f)` would be useful for this case rather than `(1.0000, 1.000)`, the latter of which is the default behavior.

module djinnprint;

private:

import std.traits;

// NOTE: Uncomment the lines below to alter the behavior of the library.
//version = assertOnTruncation; // Trigger an assertion when formatting to a buffer results in a string larger than the buffer size
//version = assertOnUnhandledUnion; // Assert when a union without ToPrint or ToPrintWhen UDAs is found while formatting.

public enum ToPrint;

public struct ToPrintWhen(T)
{
    string unionTag;
    T[]      cases;
    string[] members;
}

string genUDASwitchStatement(alias uda, string formatBegin, string formatEnd)()
{
    string result;
    static if(!disableToPrintWhen)
    {   
        static if (is(typeof(uda.cases[0]) == enum))
        {
            alias tagType = OriginalType!(typeof(uda.cases[0]));
        }
        else
        {
            alias tagType = typeof(uda.cases[0]);
        }
        
        char[30] buffer; 
        FormatSpec spec;
        
        result ~= "switch (cast(" ~ tagType.stringof ~ ")t." ~ uda.unionTag ~ ")\n{\n";
        static foreach(i; 0 .. uda.cases.length)
        {
            {
                size_t len = intToString(buffer, cast(tagType)uda.cases[i], 10, spec);
                result ~= "    case " ~ buffer[0 .. len] ~ ": " ~ formatBegin ~ "t." ~ uda.members[i] ~ formatEnd ~ "; break;\n";                     
            }
        }
        
        result ~= "    default: assert(0, \"Unable to print union: union tag type unhandled\"); break;";
        result ~= "\n}";
    }
    
    return result;
}

@nogc nothrow:

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

version(D_ModuleInfo)
{
    enum disableToPrintWhen = false;
}
else
{
    enum disableToPrintWhen = true;
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
    
    static if (is(T == enum))
    {
        static foreach (i, member; EnumMembers!T)
        {
            if (t == member)
            {
                bytesWritten = safeCopy(buffer, __traits(identifier, EnumMembers!T[i]));
            }
        }
    }
    else static if(is(T == bool))
    {
        if(t)
        {
            bytesWritten = safeCopy(buffer, "true");
        }
        else
        {
            bytesWritten = safeCopy(buffer, "false");
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
    else static if(is(T == char*) || is(T == const(char)*) || is(T == immutable(char)*))
    {
        version(assertOnTruncation)
        {
            bytesWritten = size_t.max;
        }
        else
        {
            bytesWritten = buffer.length - 1;
        }
    
        foreach(charIndex; 0 .. buffer.length - 1)
        {
            buffer[charIndex] = t[charIndex];
            if(t[charIndex] == '\0')
            {
                bytesWritten = charIndex;
                break;
            }
        }
        
        version(assertOnTruncation)
        {
            assert(bytesWritten != size_t.max);
        }
    }
    else static if((isArray!T && is(typeof(t[0]) == char)) || is(T == string))
    {
        if (buffer.length < t.length)
        {
            bytesWritten = buffer.length;
            version(assertOnTruncation) assert(0, "ERR: buffer truncated.");
        }
        else
        {
            bytesWritten = t.length;
        }
        
        buffer[0..bytesWritten] = t[0..bytesWritten];
    }
    else static if(is(T == struct))
    {
        // TODO: Test how this behaves when it runs out of room.
        // TODO: Assert on truncation
        bytesWritten += safeCopy(buffer, "(");
        alias allMembers = __traits(allMembers, T);
        static foreach(i, memberString; allMembers)
        {
            bytesWritten += formatArg(mixin("t." ~ memberString), spec, buffer[bytesWritten .. $]);
            static if(i < allMembers.length - 1)
            {
                bytesWritten += safeCopy(buffer[bytesWritten .. $], ", ");
            }
        }
        
        bytesWritten += safeCopy(buffer[bytesWritten .. $], ")");
    }
    else static if(is(T == union))
    {
        alias toPrintMembers = getSymbolsByUDA!(T, ToPrint);
        static if (toPrintMembers.length > 0)
        {
            bytesWritten += safeCopy(buffer[bytesWritten .. $], "(");
            static foreach(i, member; toPrintMembers)
            {
                bytesWritten += formatArg(mixin("t." ~ member.stringof), spec, buffer[bytesWritten .. $]);
                static if (i < toPrintMembers.length - 1)
                {
                    bytesWritten += safeCopy(buffer[bytesWritten .. $], ", ");
                }
            }
            bytesWritten += safeCopy(buffer[bytesWritten .. $], ")");
        }
        else if (hasUDA!(T, ToPrintWhen) && !disableToPrintWhen)
        {
            enum uda = getUDAs!(T, ToPrintWhen)[0];
            static assert(uda.cases.length == uda.members.length);
            
            mixin(genUDASwitchStatement!(uda, "bytesWritten += formatArg(", ", spec, buffer[bytesWritten .. $])"));
        }
        else
        {
            version(assertOnUnhandledUnion)
            {
                pragma(msg, "ERR: Unhandled union " ~ T.stringof ~ ". No @toPrint UDA found.");
                static assert(0);
            }
        
            bytesWritten += safeCopy(buffer[bytesWritten .. $], "union ");
            bytesWritten += safeCopy(buffer[bytesWritten .. $], T.stringof);
        }
    }
    else static if(isArray!T)
    {
        bytesWritten += safeCopy(buffer[bytesWritten .. $], "[");
        
        foreach(i; 0 .. t.length)
        {
            bytesWritten += formatArg(t[i], spec, buffer[bytesWritten .. $]);        
            if (i < t.length - 1)
            {
                bytesWritten += safeCopy(buffer[bytesWritten .. $], ", ");
            }
        }
        
        bytesWritten += safeCopy(buffer[bytesWritten .. $], "]");
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
    else static if(is(T == char*) || is(T == const(char)*) || is(T == immutable(char)*))
    {   
        auto msg = t[0 .. length(t)];
        printFile(file, msg);
    }
    else static if((isArray!T && is(typeof(t[0]) == char)) || is(T == string))
    {
        printFile(file, t);
    }
    else static if(is(T == struct))
    {
        printFile(file, "(");
        alias allMembers = __traits(allMembers, T);
        static foreach(i, memberString; allMembers)
        {
            formatArg(mixin("t." ~ memberString), spec, file);
            static if (i < allMembers.length - 1)
            {
                printFile(file, ", ");
            }
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
        else if (hasUDA!(T, ToPrintWhen) && !disableToPrintWhen)
        {
            enum uda = getUDAs!(T, ToPrintWhen)[0];
            static assert(uda.cases.length == uda.members.length);
            
            mixin(genUDASwitchStatement!(uda, "formatArg(", ", spec, file)"));
        }
        else
        {
            version(assertOnUnhandledUnion)
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

size_t safeCopy(T)(char[] dest, T source)
if(isSomeString!T || isSomeChar!(source([0])))
{
    size_t bytesToCopy = dest.length < source.length ? dest.length : source.length;
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
        version(assertOnTruncation) assert(0, "ERR: buffer truncated.");
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
if(isArray!(typeof(fmt)) && isSomeChar!(typeof(fmt[0])))
{  
    size_t bufferWritten = 0;
    enum outputPolicy = `bufferWritten += safeCopy(buffer[bufferWritten..buffer.length], fmt[fmtCopyToBufferIndex .. fmtCursor]);`;
    enum formatPolicy = `bufferWritten += formatArg(args[i], formatSpec, buffer[bufferWritten .. buffer.length]);`;
    
    mixin(printCommon);
    
    size_t zeroIndex = bufferWritten < buffer.length ? bufferWritten : buffer.length - 1;
    buffer[zeroIndex] = '\0';
    return buffer[0..bufferWritten];
}

void printOut(T, Args...)(T fmt, Args args)
if(isArray!(typeof(fmt)) && isSomeChar!(typeof(fmt[0])))
{
    FileHandle file = stdOut;
    
    enum outputPolicy = `printFile(file, fmt[fmtCopyToBufferIndex .. fmtCursor]);`;
    enum formatPolicy = `formatArg(args[i], formatSpec, file);`;

    mixin(printCommon);
}

void printOut(T)(T msg)
if(isArray!(typeof(msg)) && isSomeChar!(typeof(msg[0])))
{
    FileHandle file = stdOut;
    printFile(file, msg);
}

void printErr(T, Args...)(T fmt, Args args)
if(isArray!(typeof(fmt)) && isSomeChar!(typeof(fmt[0])))
{
    FileHandle file = stdErr;
    
    enum outputPolicy = `printFile(file, fmt[fmtCopyToBufferIndex..fmtCursor]);`;
    enum formatPolicy = `formatArg(args[i], formatSpec, file);`;

    mixin(printCommon);
}

void printErr(T)(T msg)
if(isArray!(typeof(msg)) && isSomeChar!(typeof(msg[0])))
{
    FileHandle file = stdErr;
    printFile(file, msg);
}

void printFile(T, Args...)(FileHandle file, T fmt, Args args)
if(isArray!(typeof(fmt)) && isSomeChar!(typeof(fmt[0])))
{
    enum outputPolicy = `printFile(file, fmt[fmtCopyToBufferIndex .. fmtCursor]);`;
    enum formatPolicy = `formatArg(args[i], formatSpec, file);`;

    mixin(printCommon);
}

void printFile(T)(FileHandle file, T msg)
if(isArray!(typeof(msg)) && isSomeChar!(typeof(msg[0])))
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