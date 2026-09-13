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

@interface MTAAlarmTableViewController : UITableViewController <UISearchResultsUpdating>
@property (nonatomic, strong, retain) MTAlarmDataSource *dataSource;
// custom %properties
@property (nonatomic, retain) UISearchController *as_searchController;
@property (nonatomic, retain) NSArray *as_originalIndexPaths;
@end

static NSString *alarmTitle(MTAlarm *alarm) {
	NSString *title = [alarm title];
	return title.length ? title : [alarm displayTitle];
}

static BOOL isFiltering(MTAAlarmTableViewController *vc) {
	NSString *query = vc.as_searchController.searchBar.text;
	return vc.as_searchController.active && query.length > 0;
}

static NSIndexPath *originalIndexPathForVisibleRow(MTAAlarmTableViewController *vc, NSIndexPath *indexPath) {
	if (!isFiltering(vc) || indexPath.section != kAlarmSection || indexPath.row >= (NSInteger)vc.as_originalIndexPaths.count) {
		return indexPath;
	}

	return vc.as_originalIndexPaths[(NSUInteger)indexPath.row];
}

static NSIndexPath *visibleIndexPathForOriginalRow(MTAAlarmTableViewController *vc, NSIndexPath *indexPath) {
	if (!isFiltering(vc)) return indexPath;

	if (indexPath.section != kAlarmSection) return nil;

	NSUInteger row = [vc.as_originalIndexPaths indexOfObject:indexPath];
	if (row == NSNotFound) return nil;

	return [NSIndexPath indexPathForRow:(NSInteger)row inSection:indexPath.section];
}

static NSArray *reloadFilter(MTAAlarmTableViewController *vc) {
	NSString *query = vc.as_searchController.searchBar.text;
	MTAlarmDataSource *dataSource = vc.dataSource;
	NSMutableArray *matches = [NSMutableArray array];

	if (query.length && dataSource) {
		NSUInteger count = [dataSource numberOfAlarms];
		for (NSUInteger row = 0; row < count; row++) {
			NSString *title = alarmTitle([dataSource alarmAtRow:row]);
			if ([title rangeOfString:query options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch].location != NSNotFound) {
				[matches addObject:[NSIndexPath indexPathForRow:(NSInteger)row inSection:kAlarmSection]];
			}
		}
	}

	vc.as_originalIndexPaths = matches;
	return matches;
}

%hook MTAAlarmTableViewController
%property (nonatomic, retain) UISearchController *as_searchController;
%property (nonatomic, retain) NSArray *as_originalIndexPaths;

-(void)viewDidLoad {
	%orig;

	if (self.as_searchController) return;

	self.as_searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
	self.as_searchController.searchResultsUpdater = self;
	self.as_searchController.obscuresBackgroundDuringPresentation = NO;
	self.navigationItem.searchController = self.as_searchController;
	self.navigationItem.hidesSearchBarWhenScrolling = NO;
	self.definesPresentationContext = YES;
}

%new
-(void)updateSearchResultsForSearchController:(UISearchController *)searchController {
	reloadFilter(self);
	[self.tableView reloadData];
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (isFiltering(self)) {
		return section == kAlarmSection ? (NSInteger)reloadFilter(self).count : 0;
	}

	return %orig;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	return %orig(tableView, originalIndexPathForVisibleRow(self, indexPath));
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	%orig(tableView, originalIndexPathForVisibleRow(self, indexPath));
}

-(void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	%orig(tableView, editingStyle, originalIndexPathForVisibleRow(self, indexPath));
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

%hook UITableView
// fix crash when deleting a filtered alarm
-(void)deleteRowsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation {
	MTAAlarmTableViewController *vc = (MTAAlarmTableViewController *)self.delegate;

	if ([vc isKindOfClass:%c(MTAAlarmTableViewController)] && isFiltering(vc)) {
		NSMutableArray *visibleIndexPaths = [NSMutableArray arrayWithCapacity:indexPaths.count];
		for (NSIndexPath *indexPath in indexPaths) {
			NSIndexPath *visibleIndexPath = visibleIndexPathForOriginalRow(vc, indexPath);
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
		NSArray *originalIndexPaths = reloadFilter(vc);
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
