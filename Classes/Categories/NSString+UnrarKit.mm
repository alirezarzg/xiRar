//
//  NSString+UnrarKit.m
//  UnrarKit
//
//

#import "NSString+UnrarKit.h"
#import "UnrarKitMacros.h"

RarHppIgnore
#import "rar.hpp"
#pragma clang diagnostic pop

#include <vector>

@implementation NSString (UnrarKit)

+ (instancetype)stringWithUnichars:(wchar_t *)unichars {
    std::vector<uint32_t> scalars;
    for (size_t index = 0; unichars[index] != 0; index++) {
        uint32_t unit = static_cast<uint32_t>(unichars[index]);
        if (unit >= 0xD800 && unit <= 0xDBFF) {
            uint32_t next = static_cast<uint32_t>(unichars[index + 1]);
            if (next < 0xDC00 || next > 0xDFFF) {
                return nil;
            }
            scalars.push_back(0x10000 + ((unit - 0xD800) << 10) + (next - 0xDC00));
            index++;
            continue;
        }
        if ((unit >= 0xDC00 && unit <= 0xDFFF) || unit > 0x10FFFF) {
            return nil;
        }
        scalars.push_back(unit);
    }
    return [[NSString alloc] initWithBytes:scalars.data()
                                    length:scalars.size() * sizeof(uint32_t)
                                  encoding:NSUTF32LittleEndianStringEncoding];
}

@end
