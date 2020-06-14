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

enum TestEnum
{
    ALPHA,
    BETA,
    GAMMA,
}

struct Inner
{
    TestEnum e;
    int a, b;
}

struct Outer
{
    Inner inner;
    float x;
}

struct TestStruct
{
    int a, b;
    float f;
}

union Vect2
{
    @toPrint struct {float x = 0.0f, y = 0.0f;};
    struct {float u, v;};
    float[2] c;
}

static assert(Vect2.sizeof == float.sizeof*2);

void formatExamples()
{
    printOut!"----format(...) Examples----\n";

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
    
    TestStruct test;
    test.a = 1;
    test.b = 2;
    test.f = 3.0f;
    
    printOut("\n");
    
    printOut(format!"The struct is: {0}{1}\n"(buffer, typeof(test).stringof, test));
    
    int[5] arrayTest = [0, 1, 2, 3, 4];
    printOut(format!"arrayTest: {0}\n"(buffer, arrayTest));
    
    TestEnum te = TestEnum.BETA;
    printOut(format!"The enum is {0}\n"(buffer, te));
    
    Vect2 vec = Vect2(2.0f, 3.0f);
    printOut(format!"Vect2 vec: {0}\n"(buffer, vec));
    
    Outer outer = Outer(Inner(TestEnum.GAMMA, 2, 4), 3.1415f);
    printOut(format!"outer == {0}\n"(buffer, outer));
    
    printOut(format!"The address of outer is {0}\n"(buffer, &outer));
}

void printOutExamples()
{
    printOut!"\n\n----printOut(...) Examples----\n";

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
    
    TestEnum te = TestEnum.BETA;
    printOut!"The enum is {0}\n"(te);
    
    int[5] arrayTest = [0, 1, 2, 3, 4];
    printOut!"arrayTest: {0}\n"(arrayTest);
    
    Vect2 vec = Vect2(2.0f, 3.0f);
    printOut!"Vect2 vec: {0}\n"(vec);
    
    Outer outer = Outer(Inner(TestEnum.GAMMA, 2, 4), 3.1415f);
    printOut!"outer == {0}\n"(outer);
    
    printOut!"The address of outer is {0}\n"(&outer);
}

enum EntityType
{
    NONE,
    PLAYER,
    DOOR,
}

struct Entity_Common
{
    EntityType type;
    Vect2 pos;
    Vect2 vel;
}

struct Entity_Player
{
    Entity_Common common;
    alias common this;
    string name;
}

struct Entity_Door
{
    Entity_Common common;
    alias common this;
    
    bool opened;
}

@toPrintWhen("common.type", [
    "EntityType.PLAYER", "player",
    "EntityType.DOOR", "door"
])
union Entity
{
    Entity_Common common;
    Entity_Player player;
    Entity_Door   door;    
}

void taggedUnionExample()
{
    printOut!"\n\n----Tagged union examples----\n";
    
    Entity player;
    auto p = &player.player;
    p.type = EntityType.PLAYER;
    p.name = "Rolf";
    
    printOut!"{0}"(player);
}

void miscExamples()
{
    printOut!"\n\n----Misc examples----\n";
    char[512] buffer;
    char[28] fmt = cast(char[28])"Static array fmt test #{0}.\n";
    printOut(format!fmt(buffer, 1));
    printOut!fmt(2);
}

extern(C) int main()
{    
    static if (!djinnprint.useModuleConstructors)
    {
        djinnprint.init();
    }
    
    formatExamples();
    
    printOutExamples();
    
    taggedUnionExample();
    
    miscExamples();
 
    return 0;
}