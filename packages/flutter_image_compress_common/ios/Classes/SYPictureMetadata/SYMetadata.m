//
//  SYMetadata.m
//  SYPictureMetadataExample
//
//  Updated for iOS 17 compatibility by removing deprecated APIs
//

#import <ImageIO/ImageIO.h>
#import "SYMetadata.h"
#import "NSDictionary+SY.h"

#define SYKeyForMetadata(name)          NSStringFromSelector(@selector(metadata##name))
#define SYDictionaryForMetadata(name)   SYPaste(SYPaste(kCGImageProperty,name),Dictionary)
#define SYClassForMetadata(name)        SYPaste(SYMetadata,name)
#define SYMappingPptyToClass(name)      SYKeyForMetadata(name):SYClassForMetadata(name).class
#define SYMappingPptyToKeyPath(name)    SYKeyForMetadata(name):(__bridge NSString *)SYDictionaryForMetadata(name)

@interface SYMetadata (Private)
- (void)refresh:(BOOL)force;
@end

@implementation SYMetadata

#pragma mark - Initialization

+ (instancetype)metadataWithDictionary:(NSDictionary *)dictionary
{
    if (!dictionary) return nil;
    
    NSError *error;
    SYMetadata *instance = [MTLJSONAdapter modelOfClass:self.class fromJSONDictionary:dictionary error:&error];
    
    if (instance)
        instance->_originalDictionary = dictionary;
    
    if (error)
        NSLog(@"[SYMetadata] Error creating %@ object: %@", NSStringFromClass(self.class), error);
    
    return instance;
}

// Removed deprecated ALAsset/PHAsset methods for iOS 17
+ (instancetype)metadataWithAsset:(id)asset
{
    // Deprecated since iOS 17
    return nil;
}

+ (instancetype)metadataWithAssetURL:(NSURL *)assetURL
{
    // No longer supported — fallback to empty metadata
    return [self metadataWithDictionary:nil];
}

+ (instancetype)metadataWithFileURL:(NSURL *)fileURL
{
    if (!fileURL) return nil;
    
    CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)fileURL, NULL);
    if (!source) return nil;
    
    NSDictionary *dictionary;
    NSDictionary *options = @{(NSString *)kCGImageSourceShouldCache : @(NO)};
    
    CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(source, 0, (__bridge CFDictionaryRef)options);
    if (properties) {
        dictionary = (__bridge_transfer NSDictionary *)properties;
    }
    
    CFRelease(source);
    return [self metadataWithDictionary:dictionary];
}

+ (instancetype)metadataWithImageData:(NSData *)imageData
{
    if (!imageData.length) return nil;
    
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)imageData, NULL);
    if (!source) return nil;
    
    NSDictionary *dictionary;
    NSDictionary *options = @{(NSString *)kCGImageSourceShouldCache : @(NO)};
    
    CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(source, 0, (__bridge CFDictionaryRef)options);
    if (properties) {
        dictionary = (__bridge_transfer NSDictionary *)properties;
    }
    
    CFRelease(source);
    return [self metadataWithDictionary:dictionary];
}

#pragma mark - Writing

+ (NSData *)dataWithImageData:(NSData *)imageData andMetadata:(SYMetadata *)metadata
{
    if (!imageData.length || !metadata) {
        NSLog(@"[SYMetadata] Invalid input for writing metadata");
        return nil;
    }
    
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)imageData, NULL);
    if (!source) {
        NSLog(@"[SYMetadata] Could not create image source");
        return nil;
    }
    
    CFStringRef type = CGImageSourceGetType(source);
    NSMutableData *outputData = [NSMutableData data];
    
    CGImageDestinationRef destination = CGImageDestinationCreateWithData(
        (__bridge CFMutableDataRef)outputData,
        type,
        1,
        NULL
    );
    
    if (!destination) {
        NSLog(@"[SYMetadata] Could not create image destination");
        CFRelease(source);
        return nil;
    }
    
    CGImageDestinationAddImageFromSource(destination, source, 0, (__bridge CFDictionaryRef)metadata.generatedDictionary);
    
    BOOL success = CGImageDestinationFinalize(destination);
    if (!success)
        NSLog(@"[SYMetadata] Failed to finalize image destination");
    
    CFRelease(destination);
    CFRelease(source);
    
    return success ? outputData : nil;
}

#pragma mark - Mapping

+ (NSDictionary *)JSONKeyPathsByPropertyKey
{
    NSMutableDictionary<NSString *, NSString *> *mappings = [NSMutableDictionary dictionary];
    
    [mappings addEntriesFromDictionary:@{
        SYMappingPptyToKeyPath(TIFF),
        SYMappingPptyToKeyPath(Exif),
        SYMappingPptyToKeyPath(GIF),
        SYMappingPptyToKeyPath(JFIF),
        SYMappingPptyToKeyPath(PNG),
        SYMappingPptyToKeyPath(IPTC),
        SYMappingPptyToKeyPath(GPS),
        SYMappingPptyToKeyPath(Raw),
        SYMappingPptyToKeyPath(CIFF),
        SYMappingPptyToKeyPath(MakerCanon),
        SYMappingPptyToKeyPath(MakerNikon),
        SYMappingPptyToKeyPath(MakerMinolta),
        SYMappingPptyToKeyPath(MakerFuji),
        SYMappingPptyToKeyPath(MakerOlympus),
        SYMappingPptyToKeyPath(MakerPentax),
        SYMappingPptyToKeyPath(8BIM),
        SYMappingPptyToKeyPath(DNG),
        SYMappingPptyToKeyPath(ExifAux)
    }];
    
    [mappings addEntriesFromDictionary:@{
        SYStringSel(fileSize):      (NSString *)kCGImagePropertyFileSize,
        SYStringSel(pixelHeight):   (NSString *)kCGImagePropertyPixelHeight,
        SYStringSel(pixelWidth):    (NSString *)kCGImagePropertyPixelWidth,
        SYStringSel(dpiHeight):     (NSString *)kCGImagePropertyDPIHeight,
        SYStringSel(dpiWidth):      (NSString *)kCGImagePropertyDPIWidth,
        SYStringSel(depth):         (NSString *)kCGImagePropertyDepth,
        SYStringSel(orientation):   (NSString *)kCGImagePropertyOrientation,
        SYStringSel(isFloat):       (NSString *)kCGImagePropertyIsFloat,
        SYStringSel(isIndexed):     (NSString *)kCGImagePropertyIsIndexed,
        SYStringSel(hasAlpha):      (NSString *)kCGImagePropertyHasAlpha,
        SYStringSel(colorModel):    (NSString *)kCGImagePropertyColorModel,
        SYStringSel(profileName):   (NSString *)kCGImagePropertyProfileName,
        SYStringSel(metadataApple):         (NSString *)kCGImagePropertyMakerAppleDictionary,
        SYStringSel(metadataPictureStyle):  (NSString *)kSYImagePropertyPictureStyle
    }];
    
    return [mappings copy];
}

+ (NSValueTransformer *)JSONTransformerForKey:(NSString *)key
{
    static NSDictionary<NSString *, Class> *classMappings;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        classMappings = @{
            SYMappingPptyToClass(TIFF),
            SYMappingPptyToClass(Exif),
            SYMappingPptyToClass(GIF),
            SYMappingPptyToClass(JFIF),
            SYMappingPptyToClass(PNG),
            SYMappingPptyToClass(IPTC),
            SYMappingPptyToClass(GPS),
            SYMappingPptyToClass(Raw),
            SYMappingPptyToClass(CIFF),
            SYMappingPptyToClass(MakerCanon),
            SYMappingPptyToClass(MakerNikon),
            SYMappingPptyToClass(MakerMinolta),
            SYMappingPptyToClass(MakerFuji),
            SYMappingPptyToClass(MakerOlympus),
            SYMappingPptyToClass(MakerPentax),
            SYMappingPptyToClass(8BIM),
            SYMappingPptyToClass(DNG),
            SYMappingPptyToClass(ExifAux)
        };
    });
    
    Class cls = classMappings[key];
    if (cls)
        return [NSValueTransformer sy_dictionaryTransformerForModelOfClass:cls];
    
    return [super JSONTransformerForKey:key];
}

#pragma mark - Diff

- (NSDictionary *)differencesFromOriginalMetadataToModel
{
    return [NSDictionary sy_differencesFrom:self.originalDictionary
                                         to:self.generatedDictionary
                        includeValuesInDiff:YES];
}

@end
