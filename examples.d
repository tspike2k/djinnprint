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
    int[2] ints;
    float f;
}

union Vect2
{
    @ToPrint struct {float x = 0.0f, y = 0.0f;};
    struct {float u, v;};
    float[2] c;
}

void formatExamples()
{
    printOut("----format(...) Examples----\n");
    
    char[512] buffer;
    
    string formatString = "Arguments can be printed out of order: {2} {0} {1}\n";
    int t = 42;
    auto result = format(formatString, buffer, 1, -2, t);
    printOut(result);

    char[] msg = cast(char[])"Hello, world!";
    float f = -32.0f;
    printOut(format(formatString, buffer, 2, msg, f));
    
    char[24] charArray = "This is a char array.";
    printOut(format("char array: `{0}`\n", buffer, charArray));
    
    printOut(format("Can even print cstrings: `{0}`\n", buffer, msg.ptr));
    
    char nullMessage = '\0';
    
    printOut(format("Null string: `{0}`\n", buffer, &nullMessage));
    printOut(format("This is an {{escape character test}.\n", buffer));

    printOut("\n");
    printOut(format("Long string: `{0}`\n", buffer, longString));
    printOut("\n\n");
    printOut(format("Long cstring: `{0}`\n", buffer, longString.ptr));
    printOut("\n\n");
    
    TestStruct test = TestStruct([1, 2], 3.0f);
    printOut(format("The struct is: {0}{1}\n", buffer, typeof(test).stringof, test));
    
    int[5] arrayTest = [0, 1, 2, 3, 4];
    printOut(format("arrayTest: {0}\n", buffer, arrayTest));
    
    TestEnum te = TestEnum.BETA;
    printOut(format("The enum is {0}\n", buffer, te));
    
    Vect2 vec = Vect2(2.0f, 3.0f);
    printOut(format("Vect2 vec: {0}\n", buffer, vec));
    
    Outer outer = Outer(Inner(TestEnum.GAMMA, 2, 4), 3.1415f);
    printOut(format("outer == {0}\n", buffer, outer));
    
    printOut(format("The address of outer is {0}\n", buffer, &outer));
}

void printOutExamples()
{
    printOut("\n\n----printOut(...) Examples----\n");

    string formatString = "Arguments can be printed out of order: {2} {0} {1}\n";
    int t = 42;
    printOut(formatString, 1, -2, t);

    char[] msg = cast(char[])"Hello, world!";
    float f = -32.0f;
    printOut(formatString, 2, msg, f);
    
    char[24] charArray = "This is a char array.";
    printOut("char array: `{0}`\n", charArray);
    
    printOut("Can even print cstrings: `{0}`\n", msg.ptr);
    
    char nullMessage = '\0';
    
    printOut("Null string: `{0}`\n", &nullMessage);
    printOut("This is an {{escape character test}.\n");

    printOut("\n");
    printOut("Long string: `{0}`\n", longString);
    printOut("\n\n");
    printOut("Long cstring: `{0}`\n", longString.ptr);
    printOut("\n\n");
    
    TestStruct test = TestStruct([1, 2], 3.0f);
    printOut("The struct is: {0}{1}\n", typeof(test).stringof, test);
    
    int[5] arrayTest = [0, 1, 2, 3, 4];
    printOut("arrayTest: {0}\n", arrayTest);
    
    TestEnum te = TestEnum.BETA;
    printOut("The enum is {0}\n", te);
    
    Vect2 vec = Vect2(2.0f, 3.0f);
    printOut("Vect2 vec: {0}\n", vec);
    
    Outer outer = Outer(Inner(TestEnum.GAMMA, 2, 4), 3.1415f);
    printOut("outer == {0}\n", outer);
    
    printOut("The address of outer is {0}\n", &outer);
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

@ToPrintWhen!EntityType("common.type",
    [EntityType.PLAYER, EntityType.DOOR], 
    ["player", "door"]
)
union Entity
{
    Entity_Common common;
    Entity_Player player;
    Entity_Door   door;
}

void taggedUnionExample()
{
    printOut("\n\n----Tagged union examples (WIP)----\n");
    
    char[512] buffer;
    
    Entity player;
    auto p = &player.player;
    p.pos = Vect2(2, 4);
    p.vel = Vect2(12, 16);
    p.type = EntityType.PLAYER;
    p.name = "Rolf";
    
    Entity door;
    auto d = &door.door;
    d.pos = Vect2(3, 9);
    d.type = EntityType.DOOR;
    d.opened = true;
    
    printOut("{0}\n", player);
    printOut(format("{0}\n", buffer, door));
}

extern(C) int main()
{    
    version(D_ModuleInfo){}
    else
    {
        // NOTE: You only need to call the .init() function manually if module constructors are disabled,
        // such as in the case when -betterC is used.
        djinnprint.init();
    }
    
    formatExamples();
    
    printOutExamples();
    
    taggedUnionExample();
 
    return 0;
}