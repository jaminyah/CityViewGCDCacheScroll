//
//  CityTVController.m
//  CityView
//
//  Created by macbook on 11/2/17.
//  Copyright © 2017 Jaminya. All rights reserved.
//

#import "CityTVController.h"

@interface CityTVController ()

@property (nonatomic, strong) NSMutableArray *jsonObjects;
@property (nonatomic, strong) NSCache *imageCache;

@end

@implementation CityTVController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    // Adjust for overlapping the transparent status bar
    UIEdgeInsets contentInset = self.tableView.contentInset;
    contentInset.top = 20;
    [self.tableView setContentInset:contentInset];
    
    _imageCache = [[NSCache alloc] init];
    [self.imageCache setCountLimit:20];

    // Downloaded JSON data
    self.jsonObjects = [NSMutableArray array];
    
}

-(void)viewDidAppear:(BOOL)animated {
    
    // fetch json data on a separate thread
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        
        NSURL *url = [NSURL URLWithString:@"http://cdn.jaminya.com/json/cities.json"];
        NSData *data = [NSData dataWithContentsOfURL:url];
        NSError *jsonError = nil;
        
        if (data) {
        NSDictionary *jsonData = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&jsonError];
            self.jsonObjects = [jsonData objectForKey:@"major_cities"];
            
            // refresh table with text data from downloaded JSON
            [self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];

        } else {
            NSLog(@"Network error");
            
            // Display alert on the main thread
            dispatch_async(dispatch_get_main_queue(), ^{
                UIAlertController *alertView = [UIAlertController
                                            alertControllerWithTitle:@"Network Status"
                                            message:@"Check Wifi"
                                            preferredStyle:UIAlertControllerStyleActionSheet];
                UIAlertAction* ok = [UIAlertAction
                                 actionWithTitle:@"OK"
                                 style:UIAlertActionStyleDefault
                                 handler:^(UIAlertAction * action)
                                 {
                                     [alertView dismissViewControllerAnimated:YES completion:nil];
                                 }];
                [alertView addAction:ok];
                [self presentViewController:alertView animated:YES completion:nil];
            });
        } // else
    }); // get_global_queue
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.jsonObjects count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
   UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"CellIdentifier" forIndexPath:indexPath];
    
    // Configure the cell...
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"CellIdentifier"];
    }
    
    cell.imageView.image = [UIImage imageNamed:@"Placeholder.png"];
    
    // Parse city name from downloaded JSON data
    cell.textLabel.text = [[self.jsonObjects objectAtIndex:indexPath.row] objectForKey:@"city"];
    
    
    if (self.tableView.dragging == NO && self.tableView.decelerating == NO) {
        [self asyncFetchImage:cell forIndexPath:indexPath];
    }
   
    return cell;
 }

// -------------------------------------------------------------------------------
//	startIconDownload:forIndexPath:
// -------------------------------------------------------------------------------
- (void)startIconDownload:(NSArray *)jsonData forIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
    [self asyncFetchImage:cell forIndexPath:indexPath];
}

-(void)asyncFetchImage:(UITableViewCell *)cell forIndexPath:(NSIndexPath *)indexPath {
    
    // Display activity view indicator while downloading flag image
    UIActivityIndicatorView *activityView =
    [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [cell setAccessoryView:activityView];
    
    // Get image from cache if available
    NSString *imageSlug = [[self.jsonObjects objectAtIndex:indexPath.row] objectForKey:@"slug"];
    NSData *cacheData = [self.imageCache objectForKey:imageSlug];
    UIImage *cachedImage = [UIImage imageWithData:cacheData];
    
    if (cacheData) {
       [activityView setHidden:NO];
       [activityView startAnimating];
        
        cell.imageView.image = cachedImage;
        
        // Stop activity indicator
        [activityView stopAnimating];
        [activityView setHidesWhenStopped:YES];
        
        // Debug
        NSLog(@"Retrieving cached image: %@",imageSlug);
    } else {
        [activityView setHidden:NO];
        [activityView startAnimating];

        // Asyncronously download icon image
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            
            NSURL *flagUrl = [NSURL URLWithString:[[self.jsonObjects objectAtIndex:indexPath.row] objectForKey:@"flagUrl"]];
            NSData *data = [NSData dataWithContentsOfURL:flagUrl];
            UIImage *downloadedImage = [[UIImage alloc] initWithData:data];
            
            // Cache downloaded image
            [self.imageCache setObject:data forKey:imageSlug];
            
            // Debug
            NSLog(@"Caching images: %@", imageSlug);
            
            // Display images on the main thread
            dispatch_async(dispatch_get_main_queue(), ^{
                cell.imageView.image = downloadedImage;
                
                // Stop activity indicator
                [activityView stopAnimating];
                [activityView setHidesWhenStopped:YES];
                
            }); // get_main_queue
        }); // get_global_queue
    } // else
}

// -------------------------------------------------------------------------------
//	loadImagesForOnscreenRows
//  This method is used in case the user scrolled into a set of cells that don't
//  have their app icons yet.
// -------------------------------------------------------------------------------
- (void)loadImagesForOnscreenRows
{
    if (self.jsonObjects.count > 0)
    {
        NSArray *visiblePaths = [self.tableView indexPathsForVisibleRows];
        for (NSIndexPath *indexPath in visiblePaths)
        {
                [self startIconDownload:self.jsonObjects forIndexPath:indexPath];
        }
    }
}


#pragma mark - UIScrollViewDelegate

// -------------------------------------------------------------------------------
//	scrollViewDidEndDragging:willDecelerate:
//  Load images for all onscreen rows when scrolling is finished.
// -------------------------------------------------------------------------------
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (!decelerate)
    {
        [self loadImagesForOnscreenRows];
    }
}

// -------------------------------------------------------------------------------
//	scrollViewDidEndDecelerating:scrollView
//  When scrolling stops, proceed to load the app icons that are on screen.
// -------------------------------------------------------------------------------
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    [self loadImagesForOnscreenRows];
}


/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
