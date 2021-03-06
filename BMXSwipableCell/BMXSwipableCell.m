//
// BMXSwipableCell.m
//
// Copyright (c) 2013 Massimiliano Bigatti.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import "BMXSwipableCell.h"

#define DEFAULT_CATCH_WIDTH 120
#define UITABLEVIEW_DELETE_CONTROL_WIDTH (47 - 12)

NSString *const BMXSwipableCellEnclosingTableViewDidBeginScrollingNotification = @"BMXSwipableCellEnclosingTableViewDidScrollNotification";
NSString *const BMXSwipableCellScrollViewKey = @"BMXSwipableCellScrollViewKey";


@interface BMXSwipableCell ()

@property (nonatomic, strong, readwrite) UITableView *tableView;

// Overridden properties from header file
@property (nonatomic, assign, readwrite) BOOL showingBasement;
@property (nonatomic, strong, readwrite) UIScrollView *scrollView;
@property (nonatomic, strong, readwrite) BMXSwipableCellContentView *scrollViewContentView;
@property (nonatomic, strong, readwrite) UIView *basementView;

@end


@implementation BMXSwipableCell {
    BOOL _userTouchedCellWhenBasementOpen;
}


#pragma mark - Lifecycle

- (void)awakeFromNib {
    [super awakeFromNib];
    [self initialize];
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self initialize];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver: self
                                                    name: BMXSwipableCellEnclosingTableViewDidBeginScrollingNotification
                                                  object: nil];
}


#pragma mark - Properties

- (void)setCatchWidth:(CGFloat)catchWidth
{
    _catchWidth = catchWidth;
    [self setNeedsLayout];
}


#pragma mark - UITableViewCell Overrides

- (void)didMoveToSuperview {
    [super didMoveToSuperview];
    
    //
    // search for the parent table view
    //
    UIView *view = self.superview;
    while (! [view isKindOfClass: [UITableView class]]) {
        view = view.superview;
    }
    
    NSAssert([view isKindOfClass: [UITableView class]], @"UITableView not found");
    
    self.tableView = (UITableView*)view;
}

//
// in case of device rotation, subviews positions are corrected
//
- (void)layoutSubviews {
    [super layoutSubviews];
    
    //
    // move storyboard / custom cell subviews into the scroll view
    //
    {
        NSArray *subviews = self.contentView.subviews;
        for (UIView *view in subviews) {
            if (view != self.scrollView) {
                [view removeFromSuperview];
                [self.scrollViewContentView addSubview: view];
                
                //NSLog(@"moved %@", [view description]);
            }
        }
        [self.contentView addSubview: self.scrollView];
    }
    
    //
    // resize views
    //
    {
        CGFloat w = CGRectGetWidth(self.bounds);
        CGFloat h = CGRectGetHeight(self.bounds);
        
        self.scrollView.contentSize = CGSizeMake(w + self.catchWidth, h);
        self.scrollView.frame = CGRectMake(0, 0, w, h);
        self.basementView.frame = CGRectMake(w - self.catchWidth, 0, self.catchWidth, h);
        
        if (self.editing) {
            w -= UITABLEVIEW_DELETE_CONTROL_WIDTH;
        }
        self.scrollViewContentView.frame = CGRectMake(0, 0, w, h);
    }
}

- (void)prepareForReuse {
    [super prepareForReuse];
    
    [self.scrollView setContentOffset: CGPointZero
                             animated: NO];
}

- (void)setSelected:(BOOL)selected {
    if (self.selected != selected) {
        [super setSelected: selected];
        [self coverAllBasementAndSetBasementHidden: YES];
    }
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    if (self.selected != selected) {
        [super setSelected: selected animated: animated];
        [self coverAllBasementAndSetBasementHidden: YES];
    }
}

- (void)setHighlighted:(BOOL)highlighted {
    if (self.highlighted != highlighted) {
        [super setHighlighted: highlighted];
        [self coverAllBasementAndSetBasementHidden: YES];
    }
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    if (self.highlighted != highlighted) {
        [super setHighlighted: highlighted animated: animated];
        [self coverAllBasementAndSetBasementHidden: YES];
    }
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing: editing animated: animated];
    
    self.scrollView.scrollEnabled = !editing;
    
    if (self.showingBasement) {
        //
        // hide basement if currently shown
        //
        [self coverBasement];
    }
}


#pragma mark - Privates

- (void)initialize {
    self.catchWidth = DEFAULT_CATCH_WIDTH;
    
    //
    // setup scroll view
    //
    {
        self.scrollView = [[UIScrollView alloc] initWithFrame: CGRectZero];
        self.scrollView.showsHorizontalScrollIndicator = NO;
        self.scrollView.delegate = self;
    }
    
    //
    // setup basement view (for buttons or other custom content)
    //
    {
        self.basementView = [[UIView alloc] initWithFrame: CGRectZero];
        self.basementView.backgroundColor = [UIColor clearColor];
        
        [self.scrollView addSubview: self.basementView];
    }
    
    //
    // setup scroll content view
    //
    {
        self.scrollViewContentView = [[BMXSwipableCellContentView alloc] initWithFrame: CGRectZero cell: self];
        self.scrollViewContentView.backgroundColor = self.contentView.backgroundColor;
        
        [self.scrollView addSubview: self.scrollViewContentView];
    }
    
    //
    // close basement when table scrolls
    //
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(enclosingTableViewDidScroll:)
                                                 name: BMXSwipableCellEnclosingTableViewDidBeginScrollingNotification
                                               object: nil];
}

/**
 Closes the basement of all cells
 */
- (void)coverBasementOfAllCellsExcept:(UIScrollView*)scrollView {
    if (scrollView != nil) {
        //
        // close cells basement if user start swiping on a cell
        // object parameter is the view to be ignored
        //
        [[NSNotificationCenter defaultCenter] postNotificationName: BMXSwipableCellEnclosingTableViewDidBeginScrollingNotification
                                                            object: nil
                                                          userInfo: @{ BMXSwipableCellScrollViewKey: scrollView} ];
    }
}

- (void)dispatchDidDeselectMessageForIndexPath:(NSIndexPath*)indexPath {
    if ([self.tableView.delegate respondsToSelector: @selector(tableView:didDeselectRowAtIndexPath:)]) {
        [self.tableView.delegate tableView: self.tableView
             didDeselectRowAtIndexPath: indexPath];
    }
}

/**
 Covers the basement restoring the scroll view to origin point
 */
- (void)coverBasement
{
    if (!self.showingBasement) {
        return;
    }
    
    [self.scrollView setContentOffset: CGPointZero
                             animated: YES];
    
    self.showingBasement = NO;
    self.basementView.hidden = YES;
    self.accessoryView.transform = CGAffineTransformIdentity;
    
    //
    // notify cell delegate about change in visibility of basement
    //
    if ([self.delegate respondsToSelector:@selector(cell:basementVisibilityChanged:)]) {
        [self.delegate cell: self basementVisibilityChanged: self.showingBasement];
    }
}

- (void)deselectCurrentCell
{
    //
    // deselect current cell if dragging
    //
    NSIndexPath *indexPath = [self.tableView indexPathForCell: self];
    
    [self.tableView deselectRowAtIndexPath: indexPath
                              animated: NO];
    
    [self dispatchDidDeselectMessageForIndexPath: indexPath];
}

- (void)coverAllBasementAndSetBasementHidden:(BOOL)hidden
{
    [self coverBasementOfAllCellsExcept: self.scrollView];
    self.basementView.hidden = hidden;
    self.showingBasement = NO;
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset {
//    if (self.editing) {
//        return;
//    }
    
	if (scrollView.contentOffset.x > self.catchWidth) {
		targetContentOffset->x = self.catchWidth;
        
        //
        // moved logic here so the event fires when user finish
        // dragging and not when the basement is fully visible
        //
        if (!self.editing) {
            if (!self.showingBasement) {
                self.showingBasement = YES;
                
                if ([self.delegate respondsToSelector:@selector(cell:basementVisibilityChanged:)]) {
                    [self.delegate cell: self basementVisibilityChanged: self.showingBasement];
                }
            }
        }
        
	} else {
		*targetContentOffset = CGPointZero;
		
		// Need to call this subsequently to remove flickering. Strange.
		dispatch_async(dispatch_get_main_queue(), ^{
			[scrollView setContentOffset: CGPointZero
                          animated: YES];
		});
	}
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    if (self.editing) {
        return;
    }
    
    [self coverBasementOfAllCellsExcept: scrollView];
    
    //
    // if user starts dragging a cell, deselect other cells in the table
    //
    NSArray *selectedCells = [self.tableView indexPathsForSelectedRows];
    for (NSIndexPath *indexPath in selectedCells) {
        [self.tableView deselectRowAtIndexPath: indexPath animated: NO];
        [self dispatchDidDeselectMessageForIndexPath: indexPath];
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (self.editing) {
        return;
    }
    
    if (scrollView.contentOffset.x < 0) {
        // prevent scrolling to right
        scrollView.contentOffset = CGPointZero;
        self.accessoryView.transform = CGAffineTransformIdentity;
        
    } else if (scrollView.contentOffset.x == 0) {
        // cover basement
        [self coverBasement];
        
        if (self.selected) {
            [self deselectCurrentCell];
        }
        
	} else {
        // slide view
        self.basementView.hidden = NO;
        self.basementView.frame = CGRectMake(scrollView.contentOffset.x + (CGRectGetWidth(self.bounds) - self.catchWidth),
                                             0.0f,
                                             self.catchWidth,
                                             CGRectGetHeight(self.bounds));
     
        self.accessoryView.transform = CGAffineTransformMakeTranslation(-scrollView.contentOffset.x, 0);
    }
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
    if (_userTouchedCellWhenBasementOpen) {
        [self _cellTouchedUp];
        _userTouchedCellWhenBasementOpen = NO;
    }
}


#pragma mark - Notifications

- (void)enclosingTableViewDidScroll:(NSNotification*)notification {
    //
    // ignore reset on scroll view passed as parameter
    //
    NSObject *scrollView = [notification.userInfo objectForKey: BMXSwipableCellScrollViewKey];
    
    if (scrollView == self.scrollView) {
        return;
    }
    
//    [self.scrollView setContentOffset: CGPointZero
//                             animated: YES];
    [self coverBasement];
}


#pragma mark - Content view callbacks

- (void)cellTouchedDown {
    //
    // if touch began and cell is showing menu, does not
    // trigger cell selection
    //
    if (self.showingBasement) {
        return;
    }
    
    NSIndexPath *indexPath = [self.tableView indexPathForCell: self];
    id<UITableViewDelegate> delegate = self.tableView.delegate;
    
    BOOL canHighlight = (self.editing && self.tableView.allowsSelectionDuringEditing) ||
    (!self.editing && self.tableView.allowsSelection);
    
    BOOL shouldHighlight = NO;
    
    if (canHighlight) {
        // default: do highlight
        shouldHighlight = YES;
        
        //
        // if delegate agrees, highlight the cell
        //
        if ([delegate respondsToSelector: @selector(tableView:shouldHighlightRowAtIndexPath:)]) {
            shouldHighlight = [delegate tableView: self.tableView
                    shouldHighlightRowAtIndexPath: indexPath];
        }
    }
    
    if (shouldHighlight) {
        self.highlighted = YES;
        
        if ([delegate respondsToSelector: @selector(tableView:didHighlightRowAtIndexPath:)]) {
            [delegate tableView: self.tableView didHighlightRowAtIndexPath: indexPath];
        }
    }
    
}


- (void)cellTouchedUp {
    if (self.showingBasement) {
        _userTouchedCellWhenBasementOpen = YES;
        
        //
        // cover basement
        //
        [self coverBasement];
        
    } else {
        [self _cellTouchedUp];
        
    }
}

- (void)_cellTouchedUp {
    id<UITableViewDelegate> delegate = self.tableView.delegate;
    NSIndexPath *indexPath = [self.tableView indexPathForCell: self];
    
    //
    // unhighlight
    //
    BOOL shouldUnhighlight = self.highlighted;
    
    //
    // if delegate agrees, unhighlight the cell
    //
    if ([delegate respondsToSelector: @selector(tableView:shouldHighlightRowAtIndexPath:)]) {
        shouldUnhighlight = [delegate tableView: self.tableView
                  shouldHighlightRowAtIndexPath: indexPath];
    }
    if (shouldUnhighlight) {
        self.highlighted = NO;
        
        if ([delegate respondsToSelector: @selector(tableView:didHighlightRowAtIndexPath:)]) {
            [delegate tableView: self.tableView didUnhighlightRowAtIndexPath: indexPath];
        }
    }
    
    //
    // cell deselection supported in following cases
    //
    BOOL shouldTryToDeselect = NO;
    
    // 1. if in editing mode and allows multiple selection and cell is selected
    if (self.editing && self.tableView.allowsMultipleSelectionDuringEditing && self.selected) {
        shouldTryToDeselect = YES;
    }
    
    // 2. if in normal mode and allow selection and cell is selected
    if (!self.editing && self.tableView.allowsSelection && self.selected) {
        shouldTryToDeselect = YES;
    }
    
    // try to deselect cell
    if (shouldTryToDeselect) {
        BOOL doDeselect = YES;
        
        // check if row can be deselected
        if ([delegate respondsToSelector: @selector(tableView:willDeselectRowAtIndexPath:)]) {
            NSIndexPath *requestedIndexPath = [delegate tableView: self.tableView willDeselectRowAtIndexPath: indexPath];
            
            if (requestedIndexPath == nil) {
                doDeselect = NO;
            } else {
                indexPath = requestedIndexPath;
            }
        }
        
        // deselect row
        if (doDeselect) {
            [self.tableView deselectRowAtIndexPath: indexPath
                                          animated: NO];
            
            if ([delegate respondsToSelector: @selector(tableView:didDeselectRowAtIndexPath:)]) {
                [delegate tableView: self.tableView didDeselectRowAtIndexPath: indexPath];
            }
        }
        
        // prevent cell selection if just deselected
        return;
    }
    
    //
    // cell selection supported in following cases
    //
    BOOL shouldTryToSelect = NO;
    
    if (self.editing && self.tableView.allowsSelectionDuringEditing) {
        shouldTryToSelect = YES;
    }
    if (!self.editing && self.tableView.allowsSelection) {
        shouldTryToSelect = YES;
    }
    
    BOOL doSelect = shouldTryToSelect;
    
    if (shouldTryToSelect) {
        if ([delegate respondsToSelector: @selector(tableView:willSelectRowAtIndexPath:)]) {
            if (!self.tableView.editing || (self.tableView.editing && self.tableView.allowsSelectionDuringEditing)) {
                
                NSIndexPath *requestedIndexPath = [delegate tableView: self.tableView willSelectRowAtIndexPath: indexPath];
                
                if (requestedIndexPath == nil) {
                    doSelect = NO;
                } else {
                    indexPath = requestedIndexPath;
                }
            }
        }
    }
    
    //
    // select row
    //
    if (doSelect) {
        [self.tableView selectRowAtIndexPath: indexPath
                                    animated: NO
                              scrollPosition: UITableViewScrollPositionNone];
        
        if ([delegate respondsToSelector: @selector(tableView:didSelectRowAtIndexPath:)]) {
            [delegate tableView: self.tableView didSelectRowAtIndexPath: indexPath];
        }
    }
    
}

- (void)cellTouchCancelled
{
    self.highlighted = NO;
}


#pragma mark - Class methods

+ (void)coverBasementOfAllCells
{
    [[NSNotificationCenter defaultCenter] postNotificationName: BMXSwipableCellEnclosingTableViewDidBeginScrollingNotification
                                                        object: nil];
}

@end


#undef DEFAULT_CATCH_WIDTH
#undef UITABLEVIEW_DELETE_CONTROL_WIDTH
