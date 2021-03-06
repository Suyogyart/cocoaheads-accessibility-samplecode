//
//  ColorNameFinder.m
//  AccessiblityDemo
//
//  Created by David Rönnqvist on 3/2/13.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of
// this software and associated documentation files (the "Software"), to deal in the
// Software without restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
// and to permit persons to whom the Software is furnished to do so, subject to the
// following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
// INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
// PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
// OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
// SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

//     _  _  ___ _____ ___   _   _____ _                  _               _   _    _
//    | \| |/ _ \_   _| __| (_) |_   _| |_  ___ _ _ ___  (_)___  _ _  ___| |_| |_ (_)_ _  __ _
//    | .` | (_) || | | _|   _    | | | ' \/ -_) '_/ -_) | (_-< | ' \/ _ \  _| ' \| | ' \/ _` |
//    |_|\_|\___/ |_| |___| (_)   |_| |_||_\___|_| \___| |_/__/ |_||_\___/\__|_||_|_|_||_\__, |
//          __            _             __           _   _             _                 |___/
//     ___ / _| __ ____ _| |_  _ ___   / _|___ _ _  | |_| |_  ___   __| |___ _ __  ___  | |_  ___ _ _ ___
//    / _ \  _| \ V / _` | | || / -_) |  _/ _ \ '_| |  _| ' \/ -_) / _` / -_) '  \/ _ \ | ' \/ -_) '_/ -_)
//    \___/_|    \_/\__,_|_|\_,_\___| |_| \___/_|    \__|_||_\___| \__,_\___|_|_|_\___/ |_||_\___|_| \___|
//

#import "ColorNameFinder.h"

static NSCache *foundNames;
static NSArray *allColorNames;


// Simple data type class for the RGB values and the name
@interface ColorNameObject : NSObject

@property (assign) NSInteger red;
@property (assign) NSInteger green;
@property (assign) NSInteger blue;

@property (strong) NSString *name;

- (id)initWithName:(NSString *)name;

@end





@interface ColorNameFinder (/*Private*/)

@property (nonatomic, readonly) NSArray *allColorNames;
@property (nonatomic, readonly) NSCache *foundNames;

@end

@implementation ColorNameFinder

// This method comes from an answer by Dave DeLong on StackOverflow
// url: http://stackoverflow.com/a/3805354/608157
void SKScanHexColor(NSString * hexString, float * red, float * green, float * blue, float * alpha) {
    NSString *cleanString = [hexString stringByReplacingOccurrencesOfString:@"#" withString:@""];
    if([cleanString length] == 3) {
        cleanString = [NSString stringWithFormat:@"%@%@%@%@%@%@",
                       [cleanString substringWithRange:NSMakeRange(0, 1)],[cleanString substringWithRange:NSMakeRange(0, 1)],
                       [cleanString substringWithRange:NSMakeRange(1, 1)],[cleanString substringWithRange:NSMakeRange(1, 1)],
                       [cleanString substringWithRange:NSMakeRange(2, 1)],[cleanString substringWithRange:NSMakeRange(2, 1)]];
    }
    if([cleanString length] == 6) {
        cleanString = [cleanString stringByAppendingString:@"ff"];
    }
    
    unsigned int baseValue;
    [[NSScanner scannerWithString:cleanString] scanHexInt:&baseValue];
    
    if (red) { *red = ((baseValue >> 24) & 0xFF)/255.0f; }
    if (green) { *green = ((baseValue >> 16) & 0xFF)/255.0f; }
    if (blue) { *blue = ((baseValue >> 8) & 0xFF)/255.0f; }
    if (alpha) { *alpha = ((baseValue >> 0) & 0xFF)/255.0f; }
}

- (NSArray *)allColorNames {
    if (!allColorNames) {
        NSString *filePath = [[NSBundle mainBundle] pathForResource:@"colorName" ofType:@"json"];
        NSError *error = nil;
        NSString *json = [[NSString alloc] initWithContentsOfFile:filePath
                                                         encoding:NSUTF8StringEncoding
                                                            error:&error];
        if (error) return nil;
        id data = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                                  options:NSJSONReadingAllowFragments
                                                    error:&error];
        if (error) return nil;
        if ([data isKindOfClass:[NSArray class]]) {
            NSMutableArray *names = [NSMutableArray new];
            
            [(NSArray *)data enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                NSString *name = obj[1];
                
                float red, green, blue, alpha;
                SKScanHexColor(obj[0], &red, &green, &blue, &alpha);
                
                ColorNameObject *color = [[ColorNameObject alloc] initWithName:name];
                color.red   = red   * 255;
                color.green = green * 255;
                color.blue  = blue  * 255;
                
                [names addObject:color];
            }];
            
            allColorNames = [names copy];
        }
    }
    return allColorNames;
}

- (NSCache *)foundNames {
    if (!foundNames) {
        foundNames = [NSCache new];
    }
    return foundNames;
}

- (NSString *)closestColorNameForColor:(UIColor *)color {
    NSString *cachedName = [self.foundNames objectForKey:color];
    if (cachedName) return cachedName;
    
    NSString *name = nil;
    
    CGFloat red   = 0.0;
    CGFloat green = 0.0;
    CGFloat blue  = 0.0;
    CGFloat alpha = 0.0;
    
    BOOL success = [color getRed:&red green:&green blue:&blue alpha:&alpha];
    if (!success) {
        CGFloat white = 0.0;
        [color getWhite:&blue alpha:&alpha];
        red = green = blue = white;
    }
    
    red   *= 255;
    green *= 255;
    blue  *= 255;
    
    NSInteger filterThreshhold = 50;
    NSPredicate *colorSubSet = [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        ColorNameObject *colorObject = evaluatedObject;
        return  ABS(colorObject.red   - red)   < filterThreshhold &&
                ABS(colorObject.green - green) < filterThreshhold &&
                ABS(colorObject.blue  - blue)  < filterThreshhold;
    }];
    
    NSArray *subset = [self.allColorNames filteredArrayUsingPredicate:colorSubSet];
    
    if (!subset || [subset count] == 0) subset = self.allColorNames;
    
    __block NSInteger closestDistance = NSIntegerMax;
    __block ColorNameObject *closestColor = nil;
    [subset enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        ColorNameObject *evaluatedColor = obj;
        NSInteger distance = powf(evaluatedColor.red   - red,   2) +
                             powf(evaluatedColor.green - green, 2) +
                             powf(evaluatedColor.blue  - blue,  2);
        if (distance < closestDistance) {
            closestDistance = distance;
            closestColor = evaluatedColor;
        }
    }];
    
    name = closestColor.name;
    
    [self.foundNames setObject:name forKey:[color copy]];
    return name;
}

@end


// Implementation with only a constructor with the name as a parameter
@implementation ColorNameObject

- (id)initWithName:(NSString *)name
{
    self = [super init];
    if (self) {
        _name = name;
    }
    return self;
}

@end
