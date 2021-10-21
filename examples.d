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
    struct {float x = 0.0f, y = 0.0f;};
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

    const(char)[] msg = "Hello, world!";
    float f = -32.0f;
    printOut(format(formatString, buffer, 2, msg, f));

    char[39] mutableFormatString = "We can use mutable format strings: {0}\n";
    printOut(format(mutableFormatString, buffer, msg));

    char testChar = 'T';
    printOut(format("We can print chars: {0}\n", buffer, testChar));

    char[21] charArray = "This is a char array.";
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

void formatOutExamples()
{
    formatOut("\n\n----formatOut(...) Examples----\n");

    string formatString = "Arguments can be printed out of order: {2} {0} {1}\n";
    int t = 42;
    formatOut(formatString, 1, -2, t);

    const(char)[] msg = "Hello, world!";
    float f = -32.0f;
    formatOut(formatString, 2, msg, f);

    char[39] mutableFormatString = "We can use mutable format strings: {0}\n";

    formatOut(mutableFormatString, msg);

    char testChar = 'T';
    formatOut("We can print chars: {0}\n", testChar);

    char[21] charArray = "This is a char array.";
    formatOut("char array: `{0}`\n", charArray);

    formatOut("Can even print cstrings: `{0}`\n", msg.ptr);

    char nullMessage = '\0';

    formatOut("Null string: `{0}`\n", &nullMessage);
    formatOut("This is an {{escape character test}.\n");

    formatOut("\n");
    formatOut("Long string: `{0}`\n", longString);
    formatOut("\n\n");
    formatOut("Long cstring: `{0}`\n", longString.ptr);
    formatOut("\n\n");

    TestStruct test = TestStruct([1, 2], 3.0f);
    formatOut("The struct is: {0}{1}\n", typeof(test).stringof, test);

    int[5] arrayTest = [0, 1, 2, 3, 4];
    formatOut("arrayTest: {0}\n", arrayTest);

    TestEnum te = TestEnum.BETA;
    formatOut("The enum is {0}\n", te);

    Vect2 vec = Vect2(2.0f, 3.0f);
    formatOut("Vect2 vec: {0}\n", vec);

    Outer outer = Outer(Inner(TestEnum.GAMMA, 2, 4), 3.1415f);
    formatOut("outer == {0}\n", outer);

    formatOut("The address of outer is {0}\n", &outer);
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

union Entity
{
    Entity_Common common;
    Entity_Player player;
    Entity_Door   door;

    @nogc nothrow size_t toPrintIndex()
    {
        return cast(size_t)(common.type);
    }
}

enum AnonUnionType
{
    NAME,
    ID
}

struct AnonUnion
{
    AnonUnionType type;

    union
    {
        char[512] name;
        int id;
    };

    double t;
}

void unionExamples()
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

    formatOut("{0}\n", player);
    formatOut(format("{0}\n", buffer, door));

    AnonUnion au;
    au.type = AnonUnionType.ID;
    au.name = cast(char[])"Anon union name";
    au.t = 16.32;
    formatOut("{0}\n", au);
}

struct BufferRange
{
    char[2048] e;
    uint count;

    nothrow @nogc:

    void put(in char[] c)
    {
        auto bytesLeft = e.length - count;
        auto toWrite = c.length > bytesLeft ? bytesLeft : c.length;
        e[count .. count+toWrite] = c[0 .. toWrite];
        count += toWrite;
    }

    auto opSlice(int start, int end)
    {
        return e[start..end];
    }

    uint opDollar() { return count; }
}

void rangeExamples()
{
    import std.range;
    import std.algorithm;

    printOut("\n\n----Range examples----\n");
    int a, b, c;
    a = 1;
    b = 2;
    c = 4;
    BufferRange range;
    format("The numbers are {0}, {1}, {2}", range, a, b, c);
    formatOut("OutputRange: {0}\n", range[0..$]);

    auto r = iota(7) // Generates numbers in the range of [0 .. 7)
            .cycle    // Infinitely repeates a given range
            .take(16) // Takes a given number of elements off an infinite range
            .retro() // Reverses a given range
            .filter!(a => a % 2 == 0); // Filter out odd numbers from the given range

    formatOut("InputRange: {0}\n", r);
}

void formatOptionsExamples()
{
    formatOut("Hex version of number {0}: {1x}\n", 255, 255);
    formatOut("Hex (uppercase) version of number {0}: {1X}\n", 255, 255);

    formatOut("{0}\n", 1);
    formatOut("{0+}\n", 1);
    formatOut("{0X+}\n", 1);
    formatOut("{0+}\n", -249);

    formatOut("{0E}\n", 123.456789);
    import core.stdc.stdio;
    printf("%E\n", 123.456789);


    formatOut("With commas: {0,}\n", long.min+1); // TODO: for some reason, std.math.abs doesn't work correctly when passing in long.min. Perhaps this is a bug in Phobos? Ask in the forums. Or, better yet, read the source.
}

extern(C) int main()
{
    formatExamples();

    formatOutExamples();

    unionExamples();

    rangeExamples();

    formatOptionsExamples;

    return 0;
}
