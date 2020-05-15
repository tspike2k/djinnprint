// Authors:   tspike (github.com/tspike2k)
// Copyright: Copyright (c) 2020
// License:   Boost Software License 1.0 (https://www.boost.org/LICENSE_1_0.txt)

module djinnprint;

private @nogc nothrow:

public enum useModuleConstructors = true;
//version = assertOnTruncation;

import std.traits;

version(Posix)
{
    import core.sys.posix.unistd : write;
    
    alias FileHandle = int;
    enum FileHandle stdOut = 1;
    enum FileHandle stdErr = 2;
    
    void init(){};
}
else version(Windows)
{
    // TODO: Test on Windows
    import core.sys.windows;
    alias FileHandle = HANDLE;
    __gshared FileHandle stdOut;
    __gshared FileHandle stdErr;
    
    void init()
    {
        HANDLE stdOut = GetStdHandle(STD_OUTPUT_HANDLE);
        HANDLE stdErr = GetStdHandle(STD_ERROR_HANDLE);
    }
    
    static if (useModuleConstructors)
    {
        this()
        {
            init();
        }
    }
}
else
{
    static assert(0, "Unsupported OS.");
}

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
    
    static if (isIntegral!T)
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
    else static if(is(T == char[]) || is(T == string))
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
        if (bytesWritten < buffer.length) buffer[bytesWritten++] = '(';
        alias allMembers = __traits(allMembers, T);
        static foreach(i, memberString; allMembers)
        {
            // TODO: Format more than builtin members
            static if (isBuiltinType!(typeof(mixin(t.stringof ~ "." ~ memberString))))
            {
                bytesWritten += formatArg(mixin(t.stringof ~ "." ~ memberString), spec, buffer[bytesWritten .. $]);
                static if(i < allMembers.length - 1)
                {
                    if (bytesWritten + 1 < buffer.length)
                    {
                        buffer[bytesWritten++] = ',';
                        buffer[bytesWritten++] = ' ';
                    }
                }
            }
        }
        if (bytesWritten < buffer.length) buffer[bytesWritten++] = ')';
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
    static if (isIntegral!T)
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
    else static if(is(T == char[]) || is(T == string))
    {
        printFile(file, t);
    }
    else static if(is(T == struct))
    {
        printFile(file, "(");
        alias allMembers = __traits(allMembers, T);
        static foreach(i, memberString; allMembers)
        {
            // TODO: Format more than builtin members
            static if (isBuiltinType!(typeof(mixin(t.stringof ~ "." ~ memberString))))
            {
                formatArg(mixin(t.stringof ~ "." ~ memberString), spec, file);
                static if(i < allMembers.length - 1) printFile(file, ", ");
            }
        }
        printFile(file, ")");
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

size_t intToString(T)(char[] buffer, T t, ubyte base, FormatSpec spec)
{
    import std.math;
    
    static assert(isIntegral!T);
    
    static if (isSigned!T)
    {
        auto sign = sgn(t);
        t = t*sign; // NOTE: Strip off the sign to prevent the mod operator from giving us a negative array index.
    }
    
    char[30] conversion; // NOTE: This should be plenty large enough to hold even the maximum value of a ulong.
    size_t finish = conversion.length;
    
    foreach_reverse(place; 0..finish)
    {
        conversion[place] = cast(char)('0' + (t % base));
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

char[] format(alias fmt, Args...)(char[] buffer, Args args)
if(isSomeString!(typeof(fmt)) || isSomeChar!(typeof(fmt[0])))
{
    size_t copyToBuffer(alias fmt)(char[] buffer, size_t fmtStart, size_t fmtEnd)
    {
        size_t fmtDiff = fmtEnd - fmtStart;
        size_t bytesToCopy = buffer.length < fmtDiff ? buffer.length : fmtDiff;
        buffer[0..bytesToCopy] = fmt[fmtStart..fmtStart+bytesToCopy];
        return bytesToCopy;
    }
    
    size_t bufferWritten = 0;
    enum outputPolicy = `bufferWritten += copyToBuffer!fmt(buffer[bufferWritten..buffer.length], fmtCopyToBufferIndex, fmtCursor);`;
    enum formatPolicy = `bufferWritten += formatArg(args[i], formatSpec, buffer[bufferWritten .. buffer.length]);`;
    
    mixin(printCommon);
    
    //assert(bufferWritten < buffer.length);
    buffer[buffer.length-1] = '\0';
    return buffer[0..bufferWritten];
}

void printOut(alias fmt, Args...)(Args args)
if(isSomeString!(typeof(fmt)) || isSomeChar!(typeof(fmt[0])))
{
    FileHandle file = stdOut;
    
    enum outputPolicy = `printFile(file, fmt[fmtCopyToBufferIndex..fmtCursor]);`;
    enum formatPolicy = `formatArg(args[i], formatSpec, file);`;

    mixin(printCommon);
}

void printOut(T)(T msg)
if(isSomeString!T || isSomeChar!(typeof(msg[0])))
{
    FileHandle file = stdOut;
    printFile(file, msg);
}

void printErr(alias fmt, Args...)(Args args)
if(isSomeString!(typeof(fmt)) || isSomeChar!(typeof(fmt[0])))
{
    FileHandle file = stdErr;
    
    enum outputPolicy = `printFile(file, fmt[fmtCopyToBufferIndex..fmtCursor]);`;
    enum formatPolicy = `formatArg(args[i], formatSpec, file);`;

    mixin(printCommon);
}

void printErr(T)(T msg)
if(isSomeString!T || isSomeChar!(typeof(msg[0])))
{
    FileHandle file = stdErr;
    printFile(file, msg);
}

void printFile(T)(FileHandle file, T msg)
if(isSomeString!T || isSomeChar!(typeof(msg[0])))
{
    version(Posix)
    {
        if (file != -1)
        {
            write(file, msg.ptr, msg.length);        
        }
    }
    else version(Windows)
    {
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