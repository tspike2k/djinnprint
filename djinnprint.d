// Authors:   tspike (github.com/tspike2k)
// Copyright: Copyright (c) 2020
// License:   Boost Software License 1.0 (https://www.boost.org/LICENSE_1_0.txt)

// TODO:

// - Testing on Windows

// - Better handling of structs with anonymous union members (see format() in Phobos and search for `#{overlap`).

// - Add formatting options for variables (commas for integers, hex output, padding, etc.)
//   Additionally, there should be an option to print the name of each struct type before the value of its members. This could be useful in code generation.
//   For instance, printing `Vect2(1.0000f, 1.0000f)` would be useful for this case rather than `(1.0000, 1.000)`, the latter of which is the default behavior.

// NOTE: The order of members returned by __traits(allMembers) is not guaranteed to be in the order they appear in the struct definition.
// However, it SEEMS that the .tupleof property is expected (perhaps even required) to be ordered this way. This behavior is what we're relying on.
// Should this break in the future, we're going to have to make some changes.
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
enum use_cstdio             = true; // Use the standard C library output functions when printing to the console

import std.traits;
import std.math : pow;
import std.range;

alias ArrayTarget(T : U[], U) = U;
enum bool isCString(T) = is(T == char*) || is(T == const(char)*) || is(T == immutable(char)*);
enum bool isCharArray(T) = isArray!T && (is(ArrayTarget!(T) == char) || is(ArrayTarget!(T) == immutable char) || is(ArrayTarget!(T) == const char));

template useQuotes(T)
{
    enum useQuotes = isCharArray!T || isCString!T;
}

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

ulong formatArg(T, Dest)(ref T t, in FormatSpec spec, auto ref Dest dest)
if(is(Dest == FileHandle) || (isArray!Dest && is(ArrayTarget!Dest == char)) || (isOutputRange!(Dest, char) && !isArray!Dest)) 
{
    // NOTE: The return value of formatArg is meaningless when dest is a FileHandle.
    ulong bytesWritten = 0;
    
    size_t getHighestOffset(T, size_t memberCutoffIndex)()
    if(is(T == struct) || is(T == union))
    {
        size_t result = 0;
        static foreach(i, member; T.tupleof)
        {
            static if(i < memberCutoffIndex)
            {
                result = result < T.tupleof[i].offsetof ? T.tupleof[i].offsetof : result;            
            }
        }
        return result;
    }

    static if (is(Dest == FileHandle))
    {
        void outPolicy(T)(in T t)
        if(isCharArray!T)
        {
            pragma(inline, true);
            printFile(dest, t);
        }

        template formatPolicy(string name)
        {
            enum formatPolicy = "formatArg(" ~ name ~ ", spec, dest);";
        }
    }
    else static if(isOutputRange!(Dest, char) && !isArray!Dest)
    {
        void outPolicy(T)(in T t)
        if(isCharArray!T)
        {
            pragma(inline, true)
            dest.put(t);
        }
        
        template formatPolicy(string name)
        {
            enum formatPolicy = "formatArg(" ~ name ~ ", spec, dest);";
        }
    }
    else
    {
        void outPolicy(T)(in T t)
        if(isCharArray!T)
        {
            pragma(inline, true)
            bytesWritten += safeCopy(dest[bytesWritten .. $], t);
        }

        template formatPolicy(string name)
        {
            enum formatPolicy = "bytesWritten += formatArg(" ~ name ~ ", spec, dest[bytesWritten .. $]);";
        }
    }

    static if (is(T == enum))
    {
        static foreach (i, member; EnumMembers!T)
        {
            if (t == member)
            {
                outPolicy(__traits(identifier, EnumMembers!T[i]));
            }
        }
    }
    else static if(is(T == bool))
    {
        if(t)
        {
            outPolicy("true");
        }
        else
        {
            outPolicy("false");
        }
    }
    else static if (isIntegral!T)
    {
        char[30] intBuffer;
        auto result = intToString(intBuffer, t, 10, spec);
        outPolicy(result);
    }
    else static if (is(T == char))
    {
        char[1] temp = t;
        outPolicy(temp);
    }
    else static if (is(T == float) || is(T == double))
    {
        char[512] buffer;
        auto result = formatDouble(buffer, t);
        static if(is(Dest == FileHandle))
        {
            printFile(dest, result);
        }
        else
        {
            outPolicy(result);
        }
    }
    else static if(isCString!T)
    {
        size_t srcLength = 0;
        while(t[srcLength] != '\0') srcLength++;
        outPolicy(t[0 .. srcLength]);
    }
    else static if(isCharArray!T)
    {
        size_t endIndex = t.length;
        foreach(i; 0 .. t.length)
        {
            if(t[i] == '\0')
            {
                endIndex = i; 
                break;
            }
        }
        outPolicy(t[0 .. endIndex]);
    }
    else static if(isInputRange!T)
    {
        size_t i = 0;
        foreach(ref v; t)
        {
            if(i > 0) outPolicy(", ");
            mixin(formatPolicy!`v`);        
            i++;
        }
    }
    else static if(is(T == struct))
    {
        outPolicy("(");
        
        auto members = t.tupleof;
        static foreach(i, member; members)
        {{
            enum highestOffset = getHighestOffset!(T, i);
            static if(highestOffset == 0 || t.tupleof[i].offsetof > highestOffset)
            {
                static if(i > 0) outPolicy(", ");
                
                enum surroundWithQuotes = useQuotes!(typeof(member));
                static if(surroundWithQuotes) outPolicy("\"");
                mixin(formatPolicy!`member`);
                static if(surroundWithQuotes) outPolicy("\"");
            }
        }}
        outPolicy(")");
    }
    else static if(is(T == union))
    {
        alias taggedToPrintMembers = getSymbolsByUDA!(T, ToPrint);
        static if (taggedToPrintMembers.length > 0)
        {
            outPolicy("(");
            static foreach(i, member; taggedToPrintMembers)
            {{
                enum surroundWithQuotes = useQuotes!(typeof(member));
                static if(surroundWithQuotes) outPolicy("\"");
                mixin(formatPolicy!`t.tupleof[i]`);
                static if(surroundWithQuotes) outPolicy("\"");
                static if (i < taggedToPrintMembers.length - 1) outPolicy(", ");
            }}
            outPolicy(")");
        }
        else static if (hasUDA!(T, ToPrintWhen))
        {
            enum uda = getUDAs!(T, ToPrintWhen)[0];
            static assert(uda.cases.length == uda.members.length);

            tagSwitch: switch(mixin("t." ~ uda.unionTag))
            {
                static foreach(i, c; uda.cases)
                {
                    case c:
                    {
                        enum surroundWithQuotes = useQuotes!(typeof(mixin("t." ~ uda.members[i])));
                        static if(surroundWithQuotes) outPolicy("\"");
                        mixin(formatPolicy!`mixin("t." ~ uda.members[i])`);
                        static if(surroundWithQuotes) outPolicy("\"");
                    } break tagSwitch;
                }

                default: assert(0, "Unable to find matching @ToPrintWhen member"); break;
            }
        }
        else
        {
            outPolicy("(");
            static foreach(i, member; T.tupleof)
            {{
                enum highestOffset = getHighestOffset!(T, i);
                static if(highestOffset == 0 || t.tupleof[i].offsetof > highestOffset)
                {
                    static if(i > 0) outPolicy(", ");
                    
                    enum surroundWithQuotes = useQuotes!(typeof(member));
                    static if(surroundWithQuotes) outPolicy("\"");
                    mixin(formatPolicy!`t.tupleof[i]`);
                    static if(surroundWithQuotes) outPolicy("\"");
                }
            }}
            outPolicy(")");
        }
    }
    else static if(isArray!T)
    {
        outPolicy("[");

        foreach(i; 0 .. t.length)
        {
            mixin(formatPolicy!`t[i]`);
            if (i < t.length - 1)
            {
                outPolicy(", ");
            }
        }

        outPolicy("]");
    }
    else static if (isPointer!T)
    {
        char[30] intBuffer;
        auto result = intToString(intBuffer, cast(size_t)t, 16, spec);
        outPolicy(result);
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

    auto argIndexStr = command[0 .. end];
    uint argIndex = 0;
    uint place = 0;
    foreach_reverse(ref c; argIndexStr)
    {
        argIndex += (c - '0') * pow(10, place);
        place++;
    }
    
    result.argIndex = argIndex;

    return result;
}

size_t safeCopy(T)(char[] dest, T source)
if (isCharArray!T)
{
    size_t bytesToCopy = void;
    bool truncated = false;
    
    if(dest.length < source.length)
    {
        bytesToCopy = dest.length;
        truncated = true;
    }
    else
    {
        bytesToCopy = source.length;
    }
    
    static if (assertOnTruncation) assert(!truncated);

    dest[0 .. bytesToCopy] = source[0 .. bytesToCopy];
    return bytesToCopy;
}

char[] intToString(T)(ref char[30] buffer, T t, ubyte base, FormatSpec spec)
if(isIntegral!T)
{
    static if (isSigned!T)
    {
        import std.math : abs, sgn;
        T sign = cast(T)sgn(t);
        t = abs(t); // NOTE: Strip off the sign to prevent the mod operator from giving us a negative array index.
    }

    size_t finish = buffer.length;

    foreach_reverse(place; 0..finish)
    {
        buffer[place] = intToCharTable[t % base];
        t /= base;

        // TODO: Add commas in the conversion string?

        if(t == 0)
        {
            static if (isSigned!T)
            {
                if (sign < 0 && place > 0)
                {
                    place--;
                    buffer[place] = '-';
                }
            }

            if(base == 16 && place >= 2)
            {
                buffer[--place] = 'x';
                buffer[--place] = '0';
            }

            finish = place;
            break;
        }
    }

    size_t charsWritten = buffer.length - finish;
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

    return buffer[finish..finish+minToCopy];
}

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
            }
            else
            {            
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
        }
        else
            fmtCursor++;
    }
    fmtCursor = fmt.length;

    mixin(outputPolicy);
`;

public:

char[] format(T, Args...)(T fmt, char[] buffer, Args args)
if(isCharArray!T)
{
    size_t bufferWritten = 0;

    enum outputPolicy = `bufferWritten += safeCopy(buffer[bufferWritten..buffer.length], fmt[fmtCopyToBufferIndex .. fmtCursor]);`;
    enum formatPolicy = `bufferWritten += formatArg(args[i], formatSpec, buffer[bufferWritten .. buffer.length]);`;

    mixin(printCommon);

    size_t zeroIndex = bufferWritten < buffer.length ? bufferWritten : buffer.length - 1;
    buffer[zeroIndex] = '\0';

    return buffer[0..zeroIndex];
}

char[] format(T, U, Args...)(T fmt, ref U buffer, Args args)
if(isCharArray!T && isOutputRange!(U, char) && !isCharArray!U)
{
    size_t bufferWritten = 0;

    enum outputPolicy = `buffer.put(fmt[fmtCopyToBufferIndex .. fmtCursor]);`;
    enum formatPolicy = `formatArg(args[i], formatSpec, buffer);`;

    mixin(printCommon);

    return buffer[0..$];
}

void formatOut(T, Args...)(T fmt, Args args)
if(isCharArray!T)
{
    FileHandle file = stdOut;

    enum outputPolicy = `printFile(file, fmt.ptr[fmtCopyToBufferIndex .. fmtCursor]);`;
    enum formatPolicy = `formatArg(args[i], formatSpec, file);`;

    mixin(printCommon);
}

void formatErr(T, Args...)(T fmt, Args args)
if(isCharArray!T)
{
    FileHandle file = stdErr;

    enum outputPolicy = `printFile(file, fmt.ptr[fmtCopyToBufferIndex .. fmtCursor]);`;
    enum formatPolicy = `formatArg(args[i], formatSpec, file);`;

    mixin(printCommon);
}

void printOut(T)(T msg)
if(isCharArray!T)
{
    FileHandle file = stdOut;
    printFile(file, msg);
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

private:

////
//
// Floating point conversion code based on stb_sprintf.
// Original author Jeff Roberts. Further developed by Sean Barrett and many others.
// https://github.com/nothings/stb/
// License: Public domain
//
////

char[] formatDouble(return ref char[512] buf, double fv)
{
    //char const *h;
    char[512] num = 0;
    stbsp__uint32 l, n, cs; // l == length
    stbsp__uint64 n64;
    
    stbsp__int32 fw, pr, tz; // pr == precision?
    stbsp__uint32 fl;
    
    stbsp__int32 dp; // decimal position

    char[8] tail = 0;
    char[8] lead = 0;
    char* s;
    char *sn;
    char* bf = buf.ptr;
    
    void stbsp__cb_buf_clamp(T, U)(ref T cl, ref U v) {
        pragma(inline, true);
         cl = v;
         /*if (callback) {                                \
            int lg = STB_SPRINTF_MIN - (int)(bf - buf); \
            if (cl > lg)                                \
               cl = lg;                                 \
         }*/
    }
    
    void stbsp__chk_cb_buf(size_t bytes){
        /*if (callback) {               \
           stbsp__chk_cb_bufL(bytes); \
        } */
    }

    pr = 6; // default is 6
    // read the double into a string
    if (stbsp__real_to_str(&sn, &l, num.ptr, &dp, fv, pr))
        fl |= STBSP__NEGATIVE;
        
    stbsp__lead_sign(fl, lead.ptr);
    
    if (dp == STBSP__SPECIAL) {
        s = cast(char *)sn;
        cs = 0;
        pr = 0;
    }
    else
    {        
        s = num.ptr + 64;

         // handle the three decimal varieties
         if (dp <= 0) {
            stbsp__int32 i;
            // handle 0.000*000xxxx
            *s++ = '0';
            if (pr)
               *s++ = stbsp__period;
            n = -dp;
            if (cast(stbsp__int32)n > pr)
               n = pr;
            i = n;
            while (i) {
               if (((cast(stbsp__uintptr)s) & 3) == 0)
                  break;
               *s++ = '0';
               --i;
            }
            while (i >= 4) {
               *(cast(stbsp__uint32 *)s) = 0x30303030;
               s += 4;
               i -= 4;
            }
            while (i) {
               *s++ = '0';
               --i;
            }
            if (cast(stbsp__int32)(l + n) > pr)
               l = pr - n;
            i = l;
            while (i) {
               *s++ = *sn++;
               --i;
            }
            tz = pr - (n + l);
            cs = 1 + (3 << 24); // how many tens did we write (for commas below)
         } else {
            cs = (fl & STBSP__TRIPLET_COMMA) ? ((600 - cast(stbsp__uint32)dp) % 3) : 0;
            if (cast(stbsp__uint32)dp >= l) {
               // handle xxxx000*000.0
               n = 0;
               for (;;) {
                  if ((fl & STBSP__TRIPLET_COMMA) && (++cs == 4)) {
                     cs = 0;
                     *s++ = stbsp__comma;
                  } else {
                     *s++ = sn[n];
                     ++n;
                     if (n >= l)
                        break;
                  }
               }
               if (n < cast(stbsp__uint32)dp) {
                  n = dp - n;
                  if ((fl & STBSP__TRIPLET_COMMA) == 0) {
                     while (n) {
                        if (((cast(stbsp__uintptr)s) & 3) == 0)
                           break;
                        *s++ = '0';
                        --n;
                     }
                     while (n >= 4) {
                        *(cast(stbsp__uint32 *)s) = 0x30303030;
                        s += 4;
                        n -= 4;
                     }
                  }
                  while (n) {
                     if ((fl & STBSP__TRIPLET_COMMA) && (++cs == 4)) {
                        cs = 0;
                        *s++ = stbsp__comma;
                     } else {
                        *s++ = '0';
                        --n;
                     }
                  }
               }
               cs = cast(int)(s - (num.ptr + 64)) + (3 << 24); // cs is how many tens
               if (pr) {
                  *s++ = stbsp__period;
                  tz = pr;
               }
            } else {
               // handle xxxxx.xxxx000*000
               n = 0;
               for (;;) {
                  if ((fl & STBSP__TRIPLET_COMMA) && (++cs == 4)) {
                     cs = 0;
                     *s++ = stbsp__comma;
                  } else {
                     *s++ = sn[n];
                     ++n;
                     if (n >= cast(stbsp__uint32)dp)
                        break;
                  }
               }
               cs = cast(int)(s - (num.ptr + 64)) + (3 << 24); // cs is how many tens
               if (pr)
                  *s++ = stbsp__period;
               if ((l - dp) > cast(stbsp__uint32)pr)
                  l = pr + dp;
               while (n < l) {
                  *s++ = sn[n];
                  ++n;
               }
               tz = pr - (l - dp);
            }
         }
         pr = 0;

         // get the length that we copied
         l = cast(stbsp__uint32)(s - (num.ptr + 64));
         s = num.ptr + 64;    
    }

         // get fw=leading/trailing space, pr=leading zeros
         if (pr < cast(stbsp__int32)l)
            pr = l;
         n = pr + lead[0] + tail[0] + tz;
         if (fw < cast(stbsp__int32)n)
            fw = n;
         fw -= n;
         pr -= l;

         // handle right justify and leading zeros
         if ((fl & STBSP__LEFTJUST) == 0) {
            if (fl & STBSP__LEADINGZERO) // if leading zeros, everything is in pr
            {
               pr = (fw > pr) ? fw : pr;
               fw = 0;
            } else {
               fl &= ~STBSP__TRIPLET_COMMA; // if no leading zeros, then no commas
            }
         }

         // copy the spaces and/or zeros
         if (fw + pr) {
            stbsp__int32 i;
            stbsp__uint32 c;

            // copy leading spaces (or when doing %8.4d stuff)
            if ((fl & STBSP__LEFTJUST) == 0)
               while (fw > 0) {
                  stbsp__cb_buf_clamp(i, fw);
                  fw -= i;
                  while (i) {
                     if (((cast(stbsp__uintptr)bf) & 3) == 0)
                        break;
                     *bf++ = ' ';
                     --i;
                  }
                  while (i >= 4) {
                     *(cast(stbsp__uint32 *)bf) = 0x20202020;
                     bf += 4;
                     i -= 4;
                  }
                  while (i) {
                     *bf++ = ' ';
                     --i;
                  }
                  stbsp__chk_cb_buf(1);
               }

            // copy leader
            sn = lead.ptr + 1;
            while (lead[0]) {
               stbsp__cb_buf_clamp(i, lead[0]);
               lead[0] -= cast(char)i;
               while (i) {
                  *bf++ = *sn++;
                  --i;
               }
               stbsp__chk_cb_buf(1);
            }

            // copy leading zeros
            c = cs >> 24;
            cs &= 0xffffff;
            cs = (fl & STBSP__TRIPLET_COMMA) ? (cast(stbsp__uint32)(c - ((pr + cs) % (c + 1)))) : 0;
            while (pr > 0) {
               stbsp__cb_buf_clamp(i, pr);
               pr -= i;
               if ((fl & STBSP__TRIPLET_COMMA) == 0) {
                  while (i) {
                     if (((cast(stbsp__uintptr)bf) & 3) == 0)
                        break;
                     *bf++ = '0';
                     --i;
                  }
                  while (i >= 4) {
                     *(cast(stbsp__uint32 *)bf) = 0x30303030;
                     bf += 4;
                     i -= 4;
                  }
               }
               while (i) {
                  if ((fl & STBSP__TRIPLET_COMMA) && (cs++ == c)) {
                     cs = 0;
                     *bf++ = stbsp__comma;
                  } else
                     *bf++ = '0';
                  --i;
               }
               stbsp__chk_cb_buf(1);
            }
         }

         // copy leader if there is still one
         sn = lead.ptr + 1;
         while (lead[0]) {
            stbsp__int32 i;
            stbsp__cb_buf_clamp(i, lead[0]);
            lead[0] -= cast(char)i;
            while (i) {
               *bf++ = *sn++;
               --i;
            }
            stbsp__chk_cb_buf(1);
         }

         // copy the string
         n = l;
         while (n) {
            stbsp__int32 i;
            stbsp__cb_buf_clamp(i, n);
            n -= i;
/+
            STBSP__UNALIGNED(while (i >= 4) {
               *(stbsp__uint32 volatile *)bf = *(stbsp__uint32 volatile *)s;
               bf += 4;
               s += 4;
               i -= 4;
            })
            +/
            while (i) {
               *bf++ = *s++;
               --i;
            }
            stbsp__chk_cb_buf(1);
         }

         // copy trailing zeros
         while (tz) {
            stbsp__int32 i;
            stbsp__cb_buf_clamp(i, tz);
            tz -= i;
            while (i) {
               if (((cast(stbsp__uintptr)bf) & 3) == 0)
                  break;
               *bf++ = '0';
               --i;
            }
            while (i >= 4) {
               *(cast(stbsp__uint32 *)bf) = 0x30303030;
               bf += 4;
               i -= 4;
            }
            while (i) {
               *bf++ = '0';
               --i;
            }
            stbsp__chk_cb_buf(1);
         }

         // copy tail if there is one
         sn = tail.ptr + 1;
         while (tail[0]) {
            stbsp__int32 i;
            stbsp__cb_buf_clamp(i, tail[0]);
            tail[0] -= cast(char)i;
            while (i) {
               *bf++ = *sn++;
               --i;
            }
            stbsp__chk_cb_buf(1);
         }

         // handle the left justify
         if (fl & STBSP__LEFTJUST)
            if (fw > 0) {
               while (fw) {
                  stbsp__int32 i;
                  stbsp__cb_buf_clamp(i, fw);
                  fw -= i;
                  while (i) {
                     if (((cast(stbsp__uintptr)bf) & 3) == 0)
                        break;
                     *bf++ = ' ';
                     --i;
                  }
                  while (i >= 4) {
                     *(cast(stbsp__uint32 *)bf) = 0x20202020;
                     bf += 4;
                     i -= 4;
                  }
                  while (i--)
                     *bf++ = ' ';
                  stbsp__chk_cb_buf(1);
               }
            }
         
    return buf[0 .. bf - buf.ptr];
}

void stbsp__lead_sign(stbsp__uint32 fl, char *sign)
{
   sign[0] = 0;
   if (fl & STBSP__NEGATIVE) {
      sign[0] = 1;
      sign[1] = '-';
   } else if (fl & STBSP__LEADINGSPACE) {
      sign[0] = 1;
      sign[1] = ' ';
   } else if (fl & STBSP__LEADINGPLUS) {
      sign[0] = 1;
      sign[1] = '+';
   }
}

alias stbsp__uint16 = ushort;
alias stbsp__int32 = int;
alias stbsp__uint32 = uint;
alias stbsp__int64 = long;
alias stbsp__uint64 = ulong;
alias stbsp__uintptr = size_t;

enum STBSP__LEFTJUST = 1;
enum STBSP__LEADINGPLUS = 2;
enum STBSP__LEADINGSPACE = 4;
enum STBSP__LEADING_0X = 8;
enum STBSP__LEADINGZERO = 16;
enum STBSP__INTMAX = 32;
enum STBSP__TRIPLET_COMMA = 64;
enum STBSP__NEGATIVE = 128;
enum STBSP__METRIC_SUFFIX = 256;
enum STBSP__HALFWIDTH = 512;
enum STBSP__METRIC_NOSPACE = 1024;
enum STBSP__METRIC_1024 = 2048;
enum STBSP__METRIC_JEDEC = 4096;
enum STBSP__SPECIAL = 0x7000;

immutable char stbsp__period = '.';
immutable char stbsp__comma = ',';

immutable double[23] stbsp__bot = [
   1e+000, 1e+001, 1e+002, 1e+003, 1e+004, 1e+005, 1e+006, 1e+007, 1e+008, 1e+009, 1e+010, 1e+011,
   1e+012, 1e+013, 1e+014, 1e+015, 1e+016, 1e+017, 1e+018, 1e+019, 1e+020, 1e+021, 1e+022
];

immutable double[22] stbsp__negbot = [
   1e-001, 1e-002, 1e-003, 1e-004, 1e-005, 1e-006, 1e-007, 1e-008, 1e-009, 1e-010, 1e-011,
   1e-012, 1e-013, 1e-014, 1e-015, 1e-016, 1e-017, 1e-018, 1e-019, 1e-020, 1e-021, 1e-022
];

immutable double[22] stbsp__negboterr = [
   -5.551115123125783e-018,  -2.0816681711721684e-019, -2.0816681711721686e-020, -4.7921736023859299e-021, -8.1803053914031305e-022, 4.5251888174113741e-023,
   4.5251888174113739e-024,  -2.0922560830128471e-025, -6.2281591457779853e-026, -3.6432197315497743e-027, 6.0503030718060191e-028,  2.0113352370744385e-029,
   -3.0373745563400371e-030, 1.1806906454401013e-032,  -7.7705399876661076e-032, 2.0902213275965398e-033,  -7.1542424054621921e-034, -7.1542424054621926e-035,
   2.4754073164739869e-036,  5.4846728545790429e-037,  9.2462547772103625e-038,  -4.8596774326570872e-039
];

immutable double[13] stbsp__top = [
   1e+023, 1e+046, 1e+069, 1e+092, 1e+115, 1e+138, 1e+161, 1e+184, 1e+207, 1e+230, 1e+253, 1e+276, 1e+299
];

immutable double[13] stbsp__negtop = [
   1e-023, 1e-046, 1e-069, 1e-092, 1e-115, 1e-138, 1e-161, 1e-184, 1e-207, 1e-230, 1e-253, 1e-276, 1e-299
];

immutable double[13] stbsp__toperr = [
   8388608,
   6.8601809640529717e+028,
   -7.253143638152921e+052,
   -4.3377296974619174e+075,
   -1.5559416129466825e+098,
   -3.2841562489204913e+121,
   -3.7745893248228135e+144,
   -1.7356668416969134e+167,
   -3.8893577551088374e+190,
   -9.9566444326005119e+213,
   6.3641293062232429e+236,
   -5.2069140800249813e+259,
   -5.2504760255204387e+282
];

immutable double[13] stbsp__negtoperr = [
   3.9565301985100693e-040,  -2.299904345391321e-063,  3.6506201437945798e-086,  1.1875228833981544e-109,
   -5.0644902316928607e-132, -6.7156837247865426e-155, -2.812077463003139e-178,  -5.7778912386589953e-201,
   7.4997100559334532e-224,  -4.6439668915134491e-247, -6.3691100762962136e-270, -9.436808465446358e-293,
   8.0970921678014997e-317L
];

immutable stbsp__uint64[20] stbsp__powten = [
   1,
   10,
   100,
   1000,
   10000,
   100000,
   1000000,
   10000000,
   100000000,
   1000000000,
   10000000000UL,
   100000000000UL,
   1000000000000UL,
   10000000000000UL,
   100000000000000UL,
   1000000000000000UL,
   10000000000000000UL,
   100000000000000000UL,
   1000000000000000000UL,
   10000000000000000000UL
];

enum stbsp__uint64 stbsp__tento19th = 1000000000000000000;

struct stbsp__digitpair_t
{
   short temp; // force next field to be 2-byte aligned
   char[201] pair;
}

const stbsp__digitpair_t stbsp__digitpair =
stbsp__digitpair_t(
  0,
   "00010203040506070809101112131415161718192021222324" ~
   "25262728293031323334353637383940414243444546474849" ~
   "50515253545556575859606162636465666768697071727374" ~
   "75767778798081828384858687888990919293949596979899"
);

void stbsp__raise_to_power10(double *ohi, double *olo, double d, stbsp__int32 power) // power can be -323 to +350
{
   double ph, pl;
   if ((power >= 0) && (power <= 22)) {
      stbsp__ddmulthi(ph, pl, d, stbsp__bot[power]);
   } else {
      stbsp__int32 e, et, eb;
      double p2h, p2l;

      e = power;
      if (power < 0)
         e = -e;
      et = (e * 0x2c9) >> 14; /* %23 */
      if (et > 13)
         et = 13;
      eb = e - (et * 23);

      ph = d;
      pl = 0.0;
      if (power < 0) {
         if (eb) {
            --eb;
            stbsp__ddmulthi(ph, pl, d, stbsp__negbot[eb]);
            stbsp__ddmultlos(ph, pl, d, stbsp__negboterr[eb]);
         }
         if (et) {
            stbsp__ddrenorm(ph, pl);
            --et;
            stbsp__ddmulthi(p2h, p2l, ph, stbsp__negtop[et]);
            stbsp__ddmultlo(p2h, p2l, ph, pl, stbsp__negtop[et], stbsp__negtoperr[et]);
            ph = p2h;
            pl = p2l;
         }
      } else {
         if (eb) {
            e = eb;
            if (eb > 22)
               eb = 22;
            e -= eb;
            stbsp__ddmulthi(ph, pl, d, stbsp__bot[eb]);
            if (e) {
               stbsp__ddrenorm(ph, pl);
               stbsp__ddmulthi(p2h, p2l, ph, stbsp__bot[e]);
               stbsp__ddmultlos(p2h, p2l, stbsp__bot[e], pl);
               ph = p2h;
               pl = p2l;
            }
         }
         if (et) {
            stbsp__ddrenorm(ph, pl);
            --et;
            stbsp__ddmulthi(p2h, p2l, ph, stbsp__top[et]);
            stbsp__ddmultlo(p2h, p2l, ph, pl, stbsp__top[et], stbsp__toperr[et]);
            ph = p2h;
            pl = p2l;
         }
      }
   }
   stbsp__ddrenorm(ph, pl);
   *ohi = ph;
   *olo = pl;
}


void STBSP__COPYFP(T, U)(ref T dest, in U src)
{
    pragma(inline, true);
    int cn = void;
    for(cn = 0; cn < 8; cn++)
        (cast(char*)&dest)[cn] = (cast(char*)&src)[cn];
}

void stbsp__ddmulthi(T)(ref T oh, ref T ol, ref T xh, const ref T yh)
{
    pragma(inline, true);
    double ahi = 0, alo, bhi = 0, blo;
    stbsp__int64 bt;
    oh = xh * yh;
    STBSP__COPYFP(bt, xh);
    bt &= ((~cast(stbsp__uint64)0) << 27);
    STBSP__COPYFP(ahi, bt);
    alo = xh - ahi;
    STBSP__COPYFP(bt, yh);
    bt &= ((~cast(stbsp__uint64)0) << 27);
    STBSP__COPYFP(bhi, bt);
    blo = yh - bhi;
    ol = ((ahi * bhi - oh) + ahi * blo + alo * bhi) + alo * blo;
}

void stbsp__ddmultlo(T)(ref T oh, ref T ol, ref T xh, ref T xl, const ref T yh, const ref T yl)
{
    pragma(inline, true);
    ol = ol + (xh * yl + xl * yh);
}

void stbsp__ddmultlos(T)(ref T oh, ref T ol, const ref T xh, const ref T yl)
{
    pragma(inline, true);
    ol = ol + (xh * yl);
}

void stbsp__ddtoS64(T, U)(ref T ob, const ref U xh, const ref U xl)
{
    pragma(inline, true);
    double ahi = 0, alo, vh, t;
    ob = cast(stbsp__int64)xh;
    vh = cast(double)ob;
    ahi = (xh - vh);
    t = (ahi - xh);
    alo = (xh - (ahi - t)) - (vh + t);
    ob += cast(stbsp__int64)(ahi + alo + xl);
}

void stbsp__ddrenorm(T)(ref T oh, ref T ol)
{
    pragma(inline, true);
    double s;
    s = oh + ol;
    ol = ol - (s - oh);
    oh = s;
}

// given a float value, returns the significant bits in bits, and the position of the
//   decimal point in decimal_pos.  +/-INF and NAN are specified by special values
//   returned in the decimal_pos parameter.
// frac_digits is absolute normally, but if you want from first significant digits (got %g and %e), or in 0x80000000
stbsp__int32 stbsp__real_to_str(char** start, stbsp__uint32* len, char* outp, stbsp__int32* decimal_pos, double value, stbsp__uint32 frac_digits)
{
   double d;
   stbsp__int64 bits = 0;
   stbsp__int32 expo, e, ng, tens;

   d = value;
   STBSP__COPYFP(bits, d);
   expo = cast(stbsp__int32)((bits >> 52) & 2047);
   ng = cast(stbsp__int32)(cast(stbsp__uint64)bits >> 63);
   if (ng)
      d = -d;

   if (expo == 2047) // is nan or inf?
   {
      *start = (bits & (((cast(stbsp__uint64)1) << 52) - 1)) ? cast(char*)"NaN" : cast(char*)"Inf";
      *decimal_pos = STBSP__SPECIAL;
      *len = 3;
      return ng;
   }

   if (expo == 0) // is zero or denormal
   {
      if ((cast(stbsp__uint64) bits << 1) == 0) // do zero
      {
         *decimal_pos = 1;
         *start = outp;
         outp[0] = '0';
         *len = 1;
         return ng;
      }
      // find the right expo for denormals
      {
         stbsp__int64 v = (cast(stbsp__uint64)1) << 51;
         while ((bits & v) == 0) {
            --expo;
            v >>= 1;
         }
      }
   }

   // find the decimal exponent as well as the decimal bits of the value
   {
      double ph, pl;

      // log10 estimate - very specifically tweaked to hit or undershoot by no more than 1 of log10 of all expos 1..2046
      tens = expo - 1023;
      tens = (tens < 0) ? ((tens * 617) / 2048) : (((tens * 1233) / 4096) + 1);

      // move the significant bits into position and stick them into an int
      stbsp__raise_to_power10(&ph, &pl, d, 18 - tens);

      // get full as much precision from double-double as possible
      stbsp__ddtoS64(bits, ph, pl);

      // check if we undershot
      if ((cast(stbsp__uint64)bits) >= stbsp__tento19th)
         ++tens;
   }

   // now do the rounding in integer land
   frac_digits = (frac_digits & 0x80000000) ? ((frac_digits & 0x7ffffff) + 1) : (tens + frac_digits);
   if ((frac_digits < 24)) {
      stbsp__uint32 dg = 1;
      if (cast(stbsp__uint64)bits >= stbsp__powten[9])
         dg = 10;
      while (cast(stbsp__uint64)bits >= stbsp__powten[dg]) {
         ++dg;
         if (dg == 20)
            goto noround;
      }
      if (frac_digits < dg) {
         stbsp__uint64 r;
         // add 0.5 at the right position and round
         e = dg - frac_digits;
         if (cast(stbsp__uint32)e >= 24)
            goto noround;
         r = stbsp__powten[e];
         bits = bits + (r / 2);
         if (cast(stbsp__uint64)bits >= stbsp__powten[dg])
            ++tens;
         bits /= r;
      }
   noround:;
   }

   // kill long trailing runs of zeros
   if (bits) {
      stbsp__uint32 n;
      for (;;) {
         if (bits <= 0xffffffff)
            break;
         if (bits % 1000)
            goto donez;
         bits /= 1000;
      }
      n = cast(stbsp__uint32)bits;
      while ((n % 1000) == 0)
         n /= 1000;
      bits = n;
   donez:;
   }

   // convert to string
   outp += 64;
   e = 0;
   for (;;) {
      stbsp__uint32 n;
      char *o = outp - 8;
      // do the conversion in chunks of U32s (avoid most 64-bit divides, worth it, constant denomiators be damned)
      if (bits >= 100000000) {
         n = cast(stbsp__uint32)(bits % 100000000);
         bits /= 100000000;
      } else {
         n = cast(stbsp__uint32)bits;
         bits = 0;
      }
      while (n) {
         outp -= 2;
         *cast(stbsp__uint16 *)outp = *cast(stbsp__uint16 *)&stbsp__digitpair.pair[(n % 100) * 2];
         n /= 100;
         e += 2;
      }
      if (bits == 0) {
         if ((e) && (outp[0] == '0')) {
            ++outp;
            --e;
         }
         break;
      }
      while (outp != o) {
         *--outp = '0';
         ++e;
      }
   }

   *decimal_pos = tens;
   *start = outp;
   *len = e;
   return ng;
}
