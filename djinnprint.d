// Authors:   tspike (github.com/tspike2k)
// Copyright: Copyright (c) 2020
// License:   Boost Software License 1.0 (https://www.boost.org/LICENSE_1_0.txt)

module djinnprint;

private @nogc nothrow:

//version = assertOnTruncation;

ulong formatArg(T)(T t, in FormatSpec spec, char[] buffer)
{
    import std.traits;
    
    ulong bytesWritten = 0;
    
    static if (isIntegral!T)
    {
        bytesWritten = intToString(buffer, t, 10);   
    }
    else static if (is(T == float))
    {
        // TODO: Eleminate our dependence on snprintf and use our own float formatting functions. Look to stb_sprintf?
        // Note that even Phobos (the D standard library) used snprintf to format floats. 
        import core.stdc.stdio : snprintf;
        bytesWritten = snprintf(buffer.ptr, buffer.length, "%f", t);
    }
    else static if(is(T == char*) || is(T == immutable(char)*))
    {
        foreach(charIndex; 0..buffer.length)
        {
            buffer[charIndex] = t[charIndex];
            if(t[charIndex] == '\0')
            {
                bytesWritten = charIndex;
                break;
            }
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
    else
    {
        pragma(msg, "ERR in print.formatArg(...): Unhandled type " ~ T.stringof);
        static assert(0);
    }
    
    return bytesWritten;
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

size_t intToString(T)(char[] buffer, T t, ubyte base)
{
    import std.traits;
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

char[] format(alias fmt, Args...)(char[] buffer, Args args)
{
    size_t copyToBuffer(alias fmt)(char[] buffer, size_t fmtStart, size_t fmtEnd)
    {
        size_t fmtDiff = fmtEnd - fmtStart;
        size_t bytesToCopy = buffer.length < fmtDiff ? buffer.length : fmtDiff;
        buffer[0..bytesToCopy] = fmt[fmtStart..fmtStart+bytesToCopy];
        return bytesToCopy;
    }
    
    size_t bufferWritten = 0;
    enum outputPolicy = ``;

    size_t fmtCursor = 0;
    size_t fmtCopyToBufferIndex = 0;
    
    while(fmtCursor < fmt.length)
    {        
        if (fmt[fmtCursor] == '{')
        {
            if (fmtCursor < fmt.length - 1 && fmt[fmtCursor+1] == '{')
            {
                fmtCursor++;
                bufferWritten += copyToBuffer!fmt(buffer[bufferWritten..buffer.length], fmtCopyToBufferIndex, fmtCursor);
                fmtCursor++;
                fmtCopyToBufferIndex = fmtCursor;
                
                continue;
            }
            
            bufferWritten += copyToBuffer!fmt(buffer[bufferWritten..buffer.length], fmtCopyToBufferIndex, fmtCursor);
        
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
                        bufferWritten += formatArg(args[i], formatSpec, buffer[bufferWritten .. buffer.length]);
                    } break outer;
                }
                
                default:
                {
                    assert(0,"ERR: Unable to access variadic argument.");
                } break outer;
            }
        }
        fmtCursor++;
    }
    fmtCursor = fmt.length;

    bufferWritten += copyToBuffer!fmt(buffer[bufferWritten..buffer.length], fmtCopyToBufferIndex, fmtCursor);
    
    assert(bufferWritten < buffer.length);
    buffer[bufferWritten] = '\0';
    return buffer[0..bufferWritten];
}

void print(T)(T output)
{
    static assert(is(T == string) || is(T == char[]));
    
    version(Windows)
    {
        // TODO: Test on Windows!
        import core.sys.windows;
        auto std_out = GetStdHandle(STD_OUTPUT_HANDLE); // TODO: Make this global?
        if(std_out)
        {
            WriteFile(std_out, output.ptr, output.length, null, null);        
        }
    }
    version(linux)
    {
        import core.sys.posix.unistd;
        enum int std_out = 1;
        
        write(std_out, output.ptr, output.length);
    }
    else
    {
        static assert(0, "Unsupported OS.");
    }
}