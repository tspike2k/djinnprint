// Authors:   tspike (github.com/tspike2k)
// Copyright: Copyright (c) 2020
// License:   Boost Software License 1.0 (https://www.boost.org/LICENSE_1_0.txt)

import djinnprint;

@nogc nothrow:

extern(C) int main()
{    
    char[512] buffer;
    
    string fmt = "The numbers are {2} {0} {1}\n";
    int t = 42;
    auto result = format!fmt(buffer, 1, -2, t);
    print(result);
    
    char[] msg = cast(char[])"Hello, world!";
    float f = -32.0f;
    print(format!fmt(buffer, 2, msg, f, 92));
    
    foreach(i; 1 .. 10)
    {
        print(format!"Test {0}: {1}.\n"(buffer, i, i / 2));
    }
    
    print(format!"Test string `{0}`\n"(buffer, msg.ptr));
    
    char nullMessage = '\0';
    
    print(format!"Null string `{0}`\n"(buffer, &nullMessage));
    print(format!"This is an {{escape character test}.\n"(buffer, 1066));
    
    return 0;
}