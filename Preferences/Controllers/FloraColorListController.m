#import "FloraColorListController.h"
#import <GcUniversal/GcColorPickerUtils.h>
#import <objc/message.h>

@interface FloraColorListController () {
    NSMutableArray *_allSpecifiers; // unfiltered
    NSString *_searchText;
}
@end

@implementation FloraColorListController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UISearchBar *searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.table.bounds.size.width, 44)];
    searchBar.delegate = self;
    searchBar.placeholder = @"Search colors...";
    self.table.tableHeaderView = searchBar;
}

- (NSArray *)specifiers {
    return _specifiers;
}

- (NSMutableArray *)getColorSpecifiersWithFilter:(BOOL (^)(NSString *name))filter parser:(NSString *(^)(NSString *name))parser {
    NSMutableArray *specifiers = [NSMutableArray array];
    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:BUNDLE_ID];
    
    [Utilities loopUIColorWithBlock:^(unsigned int index, SEL selector, NSString *name, Method method, Class uiColorClass) {
        if (!filter(name)) return;
        
        // Get default color from original implementation
        UIColor *defaultColor = nil;
        if ([uiColorClass respondsToSelector:selector]) {
            // ARC-safe: use objc_msgSend directly with proper cast
            defaultColor = ((UIColor *(*)(id, SEL))objc_msgSend)(uiColorClass, selector);
        }
        NSString *defaultHex = defaultColor ? [Utilities hexStringFromColor:defaultColor] : @"#000000FF";
        
        // Get saved color
        NSString *savedHex = [prefs objectForKey:name] ?: defaultHex;
        NSString *parsedName = parser ? parser(name) : name;
        
        PSSpecifier *spec = [self generateSpecifierWithName:name parsedName:parsedName hexColor:savedHex];
        [spec setProperty:defaultHex forKey:@"fallback"];
        [specifiers addObject:spec];
    }];
    
    _allSpecifiers = [specifiers copy];
    _specifiers = [self filterSpecifiers:_allSpecifiers withSearchText:_searchText];
    return _specifiers;
}

- (PSSpecifier *)generateSpecifierWithName:(NSString *)name parsedName:(NSString *)parsedName hexColor:(NSString *)hexColor {
    PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:parsedName
                                                        target:self
                                                           set:@selector(setPreferenceValue:specifier:)
                                                           get:@selector(readPreferenceValue:)
                                                        detail:nil
                                                          cell:PSLinkCell
                                                          edit:nil];
    [spec setProperty:name forKey:@"key"];
    [spec setProperty:BUNDLE_ID forKey:@"defaults"];
    [spec setProperty:@"GcColorPickerCell" forKey:@"cellClass"];
    [spec setProperty:@1 forKey:@"style"];
    [spec setProperty:hexColor forKey:@"fallback"];
    return spec;
}

- (NSString *)parseName:(NSString *)name {
    if ([name length] > 0) {
        return [name stringByReplacingCharactersInRange:NSMakeRange(0,1) withString:[[name substringToIndex:1] capitalizedString]];
    }
    return name;
}

- (NSMutableArray *)filterSpecifiers:(NSArray *)specifiers withSearchText:(NSString *)searchText {
    if (!searchText || [searchText length] == 0) return [specifiers mutableCopy];
    NSMutableArray *filtered = [NSMutableArray array];
    for (PSSpecifier *spec in specifiers) {
        NSString *label = [spec name];
        if ([label localizedCaseInsensitiveContainsString:searchText]) {
            [filtered addObject:spec];
        }
    }
    return filtered;
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    _searchText = searchText;
    _specifiers = [self filterSpecifiers:_allSpecifiers withSearchText:searchText];
    [self reloadSpecifiers];
    self.lastSearchBarTextLength = searchText.length;
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

@end
