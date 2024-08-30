#import "AppDelegate.h"
#import <sqlite3.h>

@interface RecordObject : NSObject
@property (nonatomic) NSInteger index;
@property (nonatomic, retain) NSString *timestamp;
@property (nonatomic, retain) NSString *phonenumber;
@end
@implementation RecordObject
@synthesize timestamp, phonenumber;
@end

@interface AppDelegate ()
@property (strong) IBOutlet NSWindow *window;
@property (strong) NSTableView *table;
@property NSMutableArray<RecordObject *> *sqliteData;
@end
@interface AppDelegate (Action)
- (IBAction)openDBFileDirectory:(id)sender;
- (IBAction)updateTimestamp:(id)sender;
- (IBAction)copyDBFileFromAppResource:(id)sender;
- (IBAction)createDBFileByThisApp:(id)sender;
- (IBAction)insert10Recodes:(id)sender;
@end

@implementation AppDelegate (custum)
static NSDateFormatter *dateFormatter= nil;
+ (NSDateFormatter *) dateFormatter{ @synchronized(self) { return dateFormatter; } }
+ (void) setDateFormatter:(NSDateFormatter *)val{ @synchronized(self) { dateFormatter = val; } }
static NSString *alphabet= @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
+ (NSButton *)constructorBtn:(NSString *)title rightBtn:(NSButton *)rightBtn row:(NSUInteger)row
{
    NSUInteger xpos= !rightBtn?10:NSMaxX(rightBtn.frame);
    NSButton *btn= [[NSButton alloc] initWithFrame:NSMakeRect(xpos+10, 10+40*row, 0, 0)];
    btn.title= title;
    btn.bezelStyle= NSBezelStyleRounded;
    [btn sizeToFit];
    return btn;
}
- (void)constructor:(NSView *)firstView
{
    NSRect r= firstView.bounds;
    r.size.height-=90;
    r.origin.y=90;
    NSScrollView * tableContainer = [[NSScrollView alloc] initWithFrame:r];
    [firstView addSubview:tableContainer];
    self.table= [[NSTableView alloc] initWithFrame:tableContainer.frame];
    [tableContainer setDocumentView:self.table];
    for(NSString *str in @[@"Index", @"Timestamp", @"Phonenumber"]) {
        NSTableColumn *column= [[NSTableColumn alloc] initWithIdentifier:str];
        [column.headerCell setTitle:[column identifier]];
        [self.table addTableColumn:column];
    }
    self.table.dataSource= self;
    self.table.columnAutoresizingStyle= NSTableViewUniformColumnAutoresizingStyle;
    [self.table sizeToFit];

    NSButton *restoreBtn= [AppDelegate constructorBtn:@"restore the DB File" rightBtn:nil row:1];
    restoreBtn.action= @selector(copyDBFileFromAppResource:);
    [firstView addSubview:restoreBtn];

    NSButton *createBtn= [AppDelegate constructorBtn:@"create the DB File" rightBtn:restoreBtn row:1];
    createBtn.action= @selector(createDBFileByThisApp:);
    [firstView addSubview:createBtn];
    
    NSButton *insertBtn= [AppDelegate constructorBtn:@"insert 10 Dummy Data" rightBtn:createBtn row:1];
    insertBtn.action= @selector(insert10Recodes:);
    [firstView addSubview:insertBtn];
    
    NSButton *openBtn= [AppDelegate constructorBtn:@"open the DB File Directory" rightBtn:nil  row:0];
    openBtn.action= @selector(openDBFileDirectory:);
    [firstView addSubview:openBtn];

    NSButton *updateBtn= [AppDelegate constructorBtn:@"update the Timestamp of Selected Row" rightBtn:openBtn  row:0];
    updateBtn.action= @selector(updateTimestamp:);
    [firstView addSubview:updateBtn];
}
+ (NSString *)dateString
{
    if (AppDelegate.dateFormatter == nil) {
        AppDelegate.dateFormatter = [[NSDateFormatter alloc] init];
        [AppDelegate.dateFormatter setLocale:[NSLocale localeWithLocaleIdentifier:@"ja_JP"]];
        [AppDelegate.dateFormatter setDateFormat:@"yyyyMMdd'T'HHmmss"];
        [AppDelegate.dateFormatter setCalendar:[NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian]];
    }
    return [self.dateFormatter stringFromDate:[NSDate date]];
}
+ (NSString *)phonenumberString {
    NSMutableString *s= [NSMutableString stringWithCapacity:13];
    for (NSUInteger i= 0; i < 13; i++) {
        if (i==0||i==2){[s appendString:@"0"];continue;}
        if (i==3||i==8){[s appendString:@"-"];continue;}
        [s appendFormat:@"%C", [alphabet characterAtIndex:(arc4random() % [alphabet length])]];
    }
    return s;
}
+ (NSString *)srcDBPath
{
    return [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"BasicData.db"];
}
+ (NSString *)distDBPath
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    return [documentsDirectory stringByAppendingPathComponent:@"BasicData.db"];
}
@end
@implementation AppDelegate (sqlite)
+ (NSString *)execSQL:(const char *)sql database:(sqlite3 *)database ary:(NSMutableArray *)ary
{
    NSString *ret= nil;
    char *err;
    if(sqlite3_exec(database, sql, packToSQLiteData, (__bridge void *)(ary), &err)!=SQLITE_OK) {
        NSAlert *alert= [[NSAlert alloc] init];
        ret= [NSString stringWithUTF8String:err];
        alert.messageText= ret;
        if ([alert.messageText hasPrefix:@"no such table:"])
            alert.informativeText= @"use the 'create the DB File' Button";
        [alert runModal];
    }
    return ret;
}
+ (BOOL)createTable
{
    BOOL ret= NO;
    sqlite3 *database;
    if (sqlite3_open([[AppDelegate distDBPath] UTF8String], &database) == SQLITE_OK) {
        NSMutableString *sql= [NSMutableString string];
        [sql appendString:@"DROP TABLE IF EXISTS \"Records\";"];
        [sql appendString:@"CREATE TABLE \"Records\" ("];
        [sql appendString:@"\"Index\" integer NOT NULL PRIMARY KEY AUTOINCREMENT,"];
        [sql appendString:@"\"Timestamp\" text,"];
        [sql appendString:@"\"Phonenumber\" text"];
        [sql appendString:@");"];
        if (![AppDelegate execSQL:[sql UTF8String] database:database ary:nil]) ret= YES;
    }
    sqlite3_close(database);
    return ret;
}
static int packToSQLiteData(void *data, int argc, char **argv, char **azColName){
    RecordObject *record = [[RecordObject alloc] init];
    record.index= [[NSString stringWithUTF8String:argv[0]] integerValue];
    record.timestamp= argv[1]?[NSString stringWithUTF8String:argv[1]]:NULL;
    record.phonenumber= argv[2]?[NSString stringWithUTF8String:argv[2]]:NULL;
    [((__bridge NSMutableArray *)data) addObject:record];
    return 0;
}
static int callback(void *data, int argc, char **argv, char **azColName){
    for(int i=0; i<argc; i++) printf("%s = %s\n", azColName[i], argv[i] ? argv[i] : "NULL");printf("\n");
    return 0;
}
+ (NSString *)packSQLiteData:(NSMutableArray *)ary
{
    NSString *ret= nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:[AppDelegate distDBPath]]) return @"The DB File not found.";
    if (ary==nil)ary= [[NSMutableArray alloc] init];else [ary removeAllObjects];
    sqlite3 *database;
    if (sqlite3_open([[AppDelegate distDBPath] UTF8String], &database) == SQLITE_OK) {
        const char *sql = "SELECT \"Index\", Timestamp, Phonenumber FROM Records";
        ret= [AppDelegate execSQL:sql database:database ary:ary];
    }
    sqlite3_close(database);
    return ret;
}
+ (BOOL)insertDummyData:(NSUInteger)n
{
    BOOL ret= NO;
    sqlite3 *database;
    if (sqlite3_open([[AppDelegate distDBPath] UTF8String], &database) == SQLITE_OK) {
        NSMutableString *sqls= [NSMutableString string];
        for(NSUInteger i=0; i<n; i++) {
            NSMutableString *sql= [NSMutableString string];
            [sql appendString:@"INSERT INTO \"Records\" (\"Timestamp\", \"Phonenumber\") VALUES"];
            [sql appendFormat:@" (\"%@\", \"%@\");",
            [AppDelegate dateString], [AppDelegate phonenumberString]];
            [sqls appendString:sql];
        }
        if (![AppDelegate execSQL:[sqls UTF8String] database:database ary:nil]) ret= YES;
    }
    sqlite3_close(database);
    return ret;
}
+ (BOOL)updateTimestampWithIndex:(NSUInteger)index
{
    BOOL ret= NO;
    sqlite3 *database;
    if (sqlite3_open([[AppDelegate distDBPath] UTF8String], &database) == SQLITE_OK) {
        NSMutableString *sql= [NSMutableString string];
        [sql appendString:@"UPDATE \"Records\" SET"];
        [sql appendFormat:@" \"Timestamp\"=\"%@\" WHERE \"Index\" = %lu", [AppDelegate dateString], index];
        if (![AppDelegate execSQL:[sql UTF8String] database:database ary:nil]) ret= YES;
    }
    sqlite3_close(database);
    return ret;
}
@end
@implementation AppDelegate (dbfile)
+ (BOOL)copyEditableFileOfDatabase
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *srcDBPath = [AppDelegate srcDBPath];
    NSString *distDBPath = [AppDelegate distDBPath];
    if ([fm fileExistsAtPath:distDBPath])
        [fm removeItemAtPath:distDBPath error:nil];
    if (![fm copyItemAtPath:srcDBPath toPath:distDBPath error:nil])
        return NO;
    return YES;
}
+ (BOOL)copyEditableFileOfDatabaseForced
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *srcDBPath = [AppDelegate srcDBPath];
    if (!srcDBPath || ![fm fileExistsAtPath:srcDBPath]) {
        return NO;
    }
    return [AppDelegate copyEditableFileOfDatabase];
}
+ (BOOL)createEditableFileOfDatabaseForced
{
    NSString *distDBPath = [AppDelegate distDBPath];
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:distDBPath]) {
        NSError *err;
        [fm removeItemAtPath:distDBPath error:&err];
        if (err) return NO;
    }
    return [AppDelegate createTable];
}
@end
@implementation AppDelegate (NSTableViewDataSource)
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return self.sqliteData.count;
}
- (nullable id)tableView:(NSTableView *)tableView
objectValueForTableColumn:(nullable NSTableColumn *)tableColumn
                     row:(NSInteger)row
{
    if (!(row < self.sqliteData.count)) return NULL;
    RecordObject *employeeObject = [self.sqliteData objectAtIndex:row];
    NSString *title= tableColumn.identifier;
    if ([title isEqualToString:@"Index"]) return [NSNumber numberWithInteger:employeeObject.index];
    if ([title isEqualToString:@"Timestamp"]) return employeeObject.timestamp;
    if ([title isEqualToString:@"Phonenumber"]) return employeeObject.phonenumber;
    return nil;
}
@end
@implementation AppDelegate (Action)
- (IBAction)openDBFileDirectory:(id)sender
{
    NSMutableArray *ary= [NSMutableArray arrayWithArray:[[AppDelegate distDBPath] pathComponents]];
    [ary removeLastObject];
    [[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPathComponents:ary]];
}
- (IBAction)updateTimestamp:(id)sender
{
    NSInteger idx= self.table.selectedRow;
    if (idx<0) {NSBeep(); return;}
    RecordObject *obj= [self.sqliteData objectAtIndex:idx];
    if (!obj) {NSBeep(); return;}
    [AppDelegate updateTimestampWithIndex:obj.index];
    [AppDelegate packSQLiteData:self.sqliteData];
    [self.table display];
    return;
}
- (IBAction)copyDBFileFromAppResource:(id)sender
{
    [self.sqliteData removeAllObjects];
    if (![AppDelegate copyEditableFileOfDatabaseForced]) {
        NSAlert *alert= [[NSAlert alloc] init];
        alert.messageText= @"Copying file failed.";
        alert.informativeText= @"Please prepare the source SQLite file ('BasicData.db').";
        [alert runModal];
        /**
         CREATE TABLE "Records" (
            "Index" integer NOT NULL PRIMARY KEY AUTOINCREMENT,
            "Timestamp" text,
            "Phonenumber" text
         );
         */
    }
    [self.table deselectAll:nil];
    [AppDelegate packSQLiteData:self.sqliteData];
    [self.table reloadData];
    return;
}
- (IBAction)createDBFileByThisApp:(id)sender
{
    [self.sqliteData removeAllObjects];
    [AppDelegate createEditableFileOfDatabaseForced];
    [self.table deselectAll:nil];
    [AppDelegate packSQLiteData:self.sqliteData];
    [self.table display];
    return;
}
- (IBAction)insert10Recodes:(id)sender
{
    if (![AppDelegate insertDummyData:10]) return;
    [self.table deselectAll:nil];
    [AppDelegate packSQLiteData:self.sqliteData];
    [self.table reloadData];
    return;
}
@end
@implementation AppDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    self.sqliteData= [NSMutableArray array];
    [self.table deselectAll:nil];
    [AppDelegate packSQLiteData:self.sqliteData];
    self.window.contentSize= NSMakeSize(500, 300);
    [self constructor:self.window.contentView];
}
- (void)applicationWillTerminate:(NSNotification *)aNotification {
}
- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}
@end
