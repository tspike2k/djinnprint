// Authors:   tspike (github.com/tspike2k)
// Copyright: Copyright (c) 2020
// License:   Boost Software License 1.0 (https://www.boost.org/LICENSE_1_0.txt)

import djinnprint;

@nogc nothrow:

enum longString = 
`1999. What appeared to be
a harmless meteorite
crashing into the Nevada
desert had turned out to
be Darc Seed, and evil
alien creature with
horrible powers. By
shooting strange magnetic
rays, Darc Seed had
turned the helpless
nation into zombies and
had brought the Stature of
Liberty to life to do his
dirty work.  These rays
had also given him
control over many deadly
weapons, but none were
more powerful than the
legendary samurai sword,
Shura. When the great
head of the samurai,
Namakubi, heard the
sword had fallen into
evil hands, he set off
immediately for the
United States. For only he
Possessed the strength
and knowledge needed to
recapture the magical
sword and free the U.S.
from the evil clutches of
Darc Seed.`;

void formatExamples()
{
    char[512] buffer;
    
    string fmt = "The numbers are {2} {0} {1}\n";
    int t = 42;
    auto result = format!fmt(buffer, 1, -2, t);
    printOut(result);

    char[] msg = cast(char[])"Hello, world!";
    float f = -32.0f;
    printOut(format!fmt(buffer, 2, msg, f, 92));
    
    foreach(i; 1 .. 10)
    {
        printOut(format!"Test {0}: {1}.\n"(buffer, i, i / 2));
    }
    
    printOut(format!"Test string `{0}`\n"(buffer, msg.ptr));
    
    char nullMessage = '\0';
    
    char* cString = cast(char*)"Test string";
    
    printOut(format!"Null string `{0}`\n"(buffer, &nullMessage));
    printOut(format!"This is an {{escape character test}.\n"(buffer, 1066));
    
    printOut(format!"\nLong  string: `{0}`\n"(buffer, longString));
    printOut(format!"\n\nLong cstring: `{0}`\n"(buffer, longString.ptr));
}

void printOutExamples()
{
    string fmt = "The numbers are {2} {0} {1}\n";
    int t = 42;
    printOut!fmt(1, -2, t);

    char[] msg = cast(char[])"Hello, world!";
    float f = -32.0f;
    printOut!fmt(2, msg, f, 92);
    
    foreach(i; 1 .. 10)
    {
        printOut!"Test {0}: {1}.\n"(i, i / 2);
    }
    
    printOut!"Test string `{0}`\n"(msg.ptr);
    
    char nullMessage = '\0';
    
    char* cString = cast(char*)"Test string";
    
    printOut!"Null string `{0}`\n"(&nullMessage);
    printOut!"This is an {{escape character test}.\n"(1066);
    printOut!"Another test \"{0}\"\n"(cString);
    
    printOut!"\nLong  string: `{0}`\n"(longString);
    printOut!"\nLong cstring: `{0}`\n"(longString.ptr);
    
    TestStruct test;
    test.a = 1;
    test.b = 2;
    test.f = 3.0f;
    
    printOut!"The struct is: {0}{1}\n"(typeof(test).stringof, test);
}

struct TestStruct
{
    int a, b;
    float f;
}

extern(C) int main()
{    
    static if (!djinnprint.useModuleConstructors)
    {
        djinnprint.init();
    }
    
    printOut!"----format(...) Examples----\n";
    formatExamples();
    
    printOut!"\n\n----printOut(...) Examples----\n";
    printOutExamples();
    
    char[512] buffer;
    char[28] fmt = cast(char[28])"Static array fmt test #{0}.\n";
    printOut(format!fmt(buffer, 1));
    printOut!fmt(2);
    
    return 0;
}