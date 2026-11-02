#import <UIKit/UIKit.h>

#define kAlarmSection 1 // "Other"; section 0 is Sleep | Wake Up.

@interface MTAlarm : NSObject
-(NSString *)title;
-(NSString *)displayTitle;
@end

@interface MTAlarmDataSource : NSObject
-(NSUInteger)numberOfAlarms;
-(MTAlarm *)alarmAtRow:(NSUInteger)row;
@end

@protocol ASAlarmSearchHost <NSObject, UISearchResultsUpdating>
@property (nonatomic, strong) MTAlarmDataSource *dataSource;
// custom %properties
@property (nonatomic, retain) UISearchController *as_searchController;
@property (nonatomic, retain) NSArray *as_originalIndexPaths;
@end

@interface MTAAlarmTableViewController : UITableViewController <ASAlarmSearchHost>
-(void)setAlarmEnabled:(BOOL)enabled forCell:(UITableViewCell *)cell;
@end

@interface MTAAlarmCollectionViewController : UICollectionViewController <ASAlarmSearchHost>
@property (nonatomic, strong) NSArray *sections;
@property (nonatomic, strong) UIViewController *addEditAlarmController;
-(void)setAlarmEnabled:(BOOL)enabled forCell:(UICollectionViewCell *)cell;
-(void)removeAlarmAtIndexPath:(NSIndexPath *)indexPath;
@end

// The original toggle uses indexPathForCell: (a filtered row) to index into the
// unfiltered data source. Feed it the alarm for the cell instead.
@interface ASAlarmDataSourceProxy : NSObject
@property (nonatomic, strong) MTAlarmDataSource *target;
@property (nonatomic, strong) MTAlarm *alarm;
@end

@implementation ASAlarmDataSourceProxy
-(MTAlarm *)alarmAtRow:(NSUInteger)row {
	return self.alarm;
}

-(id)forwardingTargetForSelector:(SEL)selector {
	return self.target;
}
@end

static NSString *alarmTitle(MTAlarm *alarm) {
	NSString *title = [alarm title];
	return title.length ? title : [alarm displayTitle];
}

static BOOL isFiltering(id<ASAlarmSearchHost> vc) {
	NSString *query = vc.as_searchController.searchBar.text;
	return vc.as_searchController.active && query.length > 0;
}

static NSIndexPath *originalIndexPathForVisibleRow(id<ASAlarmSearchHost> vc, NSIndexPath *indexPath, NSInteger section) {
	if (!isFiltering(vc) || indexPath.section != section || indexPath.row >= (NSInteger)vc.as_originalIndexPaths.count) {
		return indexPath;
	}

	return vc.as_originalIndexPaths[(NSUInteger)indexPath.row];
}

static NSIndexPath *visibleIndexPathForOriginalRow(id<ASAlarmSearchHost> vc, NSIndexPath *indexPath, NSInteger section) {
	if (!isFiltering(vc)) return indexPath;

	if (indexPath.section != section) return nil;

	NSUInteger row = [vc.as_originalIndexPaths indexOfObject:indexPath];
	if (row == NSNotFound) return nil;

	return [NSIndexPath indexPathForRow:(NSInteger)row inSection:indexPath.section];
}

static NSArray *reloadFilter(id<ASAlarmSearchHost> vc, NSInteger section) {
	NSString *query = vc.as_searchController.searchBar.text;
	MTAlarmDataSource *dataSource = vc.dataSource;
	NSMutableArray *matches = [NSMutableArray array];

	if (query.length && dataSource) {
		NSUInteger count = [dataSource numberOfAlarms];
		for (NSUInteger row = 0; row < count; row++) {
			NSString *title = alarmTitle([dataSource alarmAtRow:row]);
			if ([title rangeOfString:query options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch].location != NSNotFound) {
				[matches addObject:[NSIndexPath indexPathForRow:(NSInteger)row inSection:section]];
			}
		}
	}

	vc.as_originalIndexPaths = matches;
	return matches;
}

static MTAlarmDataSource *installAlarmProxy(id<ASAlarmSearchHost> vc, MTAlarm *alarm) {
	MTAlarmDataSource *dataSource = vc.dataSource;
	ASAlarmDataSourceProxy *proxy = [[ASAlarmDataSourceProxy alloc] init];
	proxy.target = dataSource;
	proxy.alarm = alarm;
	vc.dataSource = (MTAlarmDataSource *)proxy;
	return dataSource;
}

static NSInteger collectionAlarmSection(MTAAlarmCollectionViewController *vc) {
	NSArray *sections = vc.sections;
	for (NSInteger section = (NSInteger)sections.count - 1; section >= 0; section--) {
		if ([sections[(NSUInteger)section] integerValue] != 0) return section;
	}

	return 0;
}

static void setupSearch(UIViewController<ASAlarmSearchHost> *vc) {
	if (vc.as_searchController) return;

	vc.as_searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
	vc.as_searchController.searchResultsUpdater = vc;
	vc.as_searchController.obscuresBackgroundDuringPresentation = NO;
	vc.navigationItem.searchController = vc.as_searchController;
	vc.navigationItem.hidesSearchBarWhenScrolling = NO;
	vc.definesPresentationContext = YES;
}

%hook MTAAlarmTableViewController
%property (nonatomic, retain) UISearchController *as_searchController;
%property (nonatomic, retain) NSArray *as_originalIndexPaths;

-(void)viewDidLoad {
	%orig;
	setupSearch(self);
}

%new
-(void)updateSearchResultsForSearchController:(UISearchController *)searchController {
	reloadFilter(self, kAlarmSection);
	[self.tableView reloadData];
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (isFiltering(self)) {
		return section == kAlarmSection ? (NSInteger)reloadFilter(self, kAlarmSection).count : 0;
	}

	return %orig;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	return %orig(tableView, originalIndexPathForVisibleRow(self, indexPath, kAlarmSection));
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	%orig(tableView, originalIndexPathForVisibleRow(self, indexPath, kAlarmSection));
}

-(void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	%orig(tableView, editingStyle, originalIndexPathForVisibleRow(self, indexPath, kAlarmSection));
}

-(void)setAlarmEnabled:(BOOL)enabled forCell:(UITableViewCell *)cell {
	if (!isFiltering(self) || !self.dataSource) {
		%orig;
		return;
	}

	NSIndexPath *indexPath = originalIndexPathForVisibleRow(self, [self.tableView indexPathForCell:cell], kAlarmSection);
	MTAlarmDataSource *dataSource = installAlarmProxy(self, [self.dataSource alarmAtRow:(NSUInteger)indexPath.row]);
	%orig(enabled, cell);
	self.dataSource = dataSource;
}

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	return isFiltering(self) && section != kAlarmSection ? CGFLOAT_MIN : %orig;
}

-(CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	return isFiltering(self) && section != kAlarmSection ? CGFLOAT_MIN : %orig;
}

-(UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	return isFiltering(self) && section != kAlarmSection ? nil : %orig;
}

-(UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	return isFiltering(self) && section != kAlarmSection ? nil : %orig;
}
%end

%hook MTAAlarmCollectionViewController
%property (nonatomic, retain) UISearchController *as_searchController;
%property (nonatomic, retain) NSArray *as_originalIndexPaths;

-(void)viewDidLoad {
	%orig;
	setupSearch(self);
}

%new
-(void)updateSearchResultsForSearchController:(UISearchController *)searchController {
	reloadFilter(self, collectionAlarmSection(self));
	[self.collectionView reloadData];
}

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
	if (isFiltering(self)) {
		NSInteger alarmSection = collectionAlarmSection(self);
		return section == alarmSection ? (NSInteger)reloadFilter(self, alarmSection).count : 0;
	}

	return %orig;
}

-(UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
	if (!isFiltering(self) || !self.dataSource) return %orig;

	NSInteger alarmSection = collectionAlarmSection(self);
	NSIndexPath *originalIndexPath = originalIndexPathForVisibleRow(self, indexPath, alarmSection);
	if (originalIndexPath == indexPath) return %orig;

	MTAlarmDataSource *dataSource = installAlarmProxy(self, [self.dataSource alarmAtRow:(NSUInteger)originalIndexPath.row]);
	UICollectionViewCell *cell = %orig(collectionView, indexPath);
	self.dataSource = dataSource;
	return cell;
}

-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
	if (!isFiltering(self) || !self.dataSource) {
		%orig;
		return;
	}

	NSInteger alarmSection = collectionAlarmSection(self);
	NSIndexPath *originalIndexPath = originalIndexPathForVisibleRow(self, indexPath, alarmSection);
	if (originalIndexPath == indexPath) {
		%orig;
		return;
	}

	MTAlarmDataSource *dataSource = installAlarmProxy(self, [self.dataSource alarmAtRow:(NSUInteger)originalIndexPath.row]);
	%orig(collectionView, indexPath);
	self.dataSource = dataSource;
}

-(void)removeAlarmAtIndexPath:(NSIndexPath *)indexPath {
	if (!isFiltering(self) || !self.dataSource) {
		%orig;
		return;
	}

	%orig(originalIndexPathForVisibleRow(self, indexPath, collectionAlarmSection(self)));
}

-(void)setAlarmEnabled:(BOOL)enabled forCell:(UICollectionViewCell *)cell {
	if (!isFiltering(self) || !self.dataSource) {
		%orig;
		return;
	}

	NSIndexPath *indexPath = originalIndexPathForVisibleRow(self, [self.collectionView indexPathForCell:cell], collectionAlarmSection(self));
	MTAlarmDataSource *dataSource = installAlarmProxy(self, [self.dataSource alarmAtRow:(NSUInteger)indexPath.row]);
	%orig(enabled, cell);
	self.dataSource = dataSource;
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)layout referenceSizeForHeaderInSection:(NSInteger)section {
	if (isFiltering(self) && section != collectionAlarmSection(self)) return CGSizeZero;
	return %orig;
}

// While search is active, the edit popover is presented above the search
// controller. The app dismisses it from the collection controller, which would
// otherwise dismiss search and leave the popover open.
-(void)dismissViewControllerAnimated:(BOOL)animated completion:(void (^)(void))completion {
	UIViewController *editController = self.addEditAlarmController;
	UIViewController *presented = editController.navigationController ?: editController;
	if (presented.presentingViewController) {
		[presented dismissViewControllerAnimated:animated completion:completion];
		return;
	}

	%orig;
}
%end

%hook UITableView
// fix crash when deleting a filtered alarm
-(void)deleteRowsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation {
	MTAAlarmTableViewController *vc = (MTAAlarmTableViewController *)self.delegate;

	if ([vc isKindOfClass:%c(MTAAlarmTableViewController)] && isFiltering(vc)) {
		NSMutableArray *visibleIndexPaths = [NSMutableArray arrayWithCapacity:indexPaths.count];
		for (NSIndexPath *indexPath in indexPaths) {
			NSIndexPath *visibleIndexPath = visibleIndexPathForOriginalRow(vc, indexPath, kAlarmSection);
			if (visibleIndexPath) [visibleIndexPaths addObject:visibleIndexPath];
		}

		if (!visibleIndexPaths.count) return;

		%orig(visibleIndexPaths, animation);
		return;
	}

	%orig;
}

// fix crash when renaming a filtered alarm
-(void)scrollToRowAtIndexPath:(NSIndexPath *)indexPath atScrollPosition:(UITableViewScrollPosition)position animated:(BOOL)animated {
	MTAAlarmTableViewController *vc = (MTAAlarmTableViewController *)self.delegate;

	if ([vc isKindOfClass:%c(MTAAlarmTableViewController)] && isFiltering(vc)) {
		NSArray *originalIndexPaths = reloadFilter(vc, kAlarmSection);
		NSUInteger visibleRow = [originalIndexPaths indexOfObject:indexPath];

		if (visibleRow != NSNotFound) {
			%orig([NSIndexPath indexPathForRow:(NSInteger)visibleRow inSection:indexPath.section], position, animated);
			return;
		}

		if (indexPath.section == kAlarmSection && indexPath.row >= [self numberOfRowsInSection:indexPath.section]) {
			return;
		}
	}

	%orig;
}
%end
