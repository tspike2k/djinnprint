// Authors:   tspike (github.com/tspike2k)
// Copyright: Copyright (c) 2020
// License:   Boost Software License 1.0 (https://www.boost.org/LICENSE_1_0.txt)

import djinnprint;

@nogc nothrow:

void main()
{
    import core.stdc.stdio;
    
    char[512] buffer;
    
    string fmt = "The numbers are {2} {0} {1}";
    int t = 42;
    auto result = bprint!fmt(buffer, 1, -2, t);
    printf("%s\n", result.ptr);
    
    char[] msg = cast(char[])"Hello, world!";
    float f = -32.0f;
    result = bprint!fmt(buffer, 2, msg, f, 92);
    printf("%s\n", result.ptr);
    
    foreach(i; 1 .. 10)
    {
        auto res = bprint!("Test {0}: {1}.")(buffer, i, i / 2);
        printf("%s\n", res.ptr);
    }
    
    result = bprint!"Test string `{0}`"(buffer, msg.ptr);
    printf("%s\n", result.ptr);
    
    char nullMessage = '\0';
    
    result = bprint!"Null string `{0}`"(buffer, &nullMessage);
    printf("%s\n", result.ptr);
    
    result = bprint!"This is an {{escape character test}."(buffer, 1066);
    printf("%s\n", result.ptr);
}