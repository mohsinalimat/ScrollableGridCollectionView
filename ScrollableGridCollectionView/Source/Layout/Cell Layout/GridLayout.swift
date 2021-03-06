//
//  GridLayout.swift
//  ScrollableGridCollectionView
//
//  Created by Kyle Zaragoza on 7/12/16.
//  Copyright © 2016 Kyle Zaragoza. All rights reserved.
//
//  Reference: (taken from https://www.raizlabs.com/dev/2014/02/animating-items-in-a-uicollectionview/)
//
//  Let’s consider the case where a cell at index path [0, 1] is removed from a collection view with three items.
//
//  1. Update the data source so that it will return the new item at the correct index path and the correct number of items for the section.
//  2. Call deleteItemsAtIndexPaths: on the collection view with an index path equal to [0, 1] – second item in the first section.
//  3. The layout receives prepareLayout.
//  4. The layout receives prepareForCollectionViewUpdates: with an array containing one update item representing the deleted item.
//  5. The layout receives finalLayoutAttributesForDisappearingItemAtIndexPath: with index path [0, 1] – this is in reference to the deleted item being removed
//     from the layout completely.
//  6. The layout receives finalLayoutAttributesForDisappearingItemAtIndexPath: with index path [0, 2] – this is in reference to the item previously at [0, 2]
//     “disappearing” as it moves to [0, 1]
//  7. The layout receives initialLayoutAttributesForAppearingItemAtIndexPath: with index path [0, 1] – this is in reference to the item previously at [0, 2]
//     “appearing” as it moves to [0, 1]
//  8. The layout receives finalizeCollectionViewUpdates.
//  9. The layout animates the cells to their new positions based on the attributes returned in steps 5-7.
//

import UIKit

struct GridLayoutConst {
    static let zIndexCell = 0
    static let zIndexScrollView = 1
}

class GridLayout: UICollectionViewLayout {
    
    /// Item size of cells
    var itemSize = CGSize(width: 200, height: 120)
    
    /// Spacing between each column
    var itemHorizontalSpacing: CGFloat = 7
    
    /// Spacing between each row
    var itemVerticalSpacing: CGFloat = 15
    
    /// The padding on the edges of the views bounds
    var edgeInsets = UIEdgeInsets(top: 15, left: 15, bottom: 15, right: 15)
    
    // Caches for keeping current/previous attributes
    private var currentCellAttributes = [Int: [UICollectionViewLayoutAttributes]]()
    private var currentScrollViewAttributes = [Int: ScrollViewSupplementaryLayoutAttributes]()
    
    // Containers for keeping track of changing items
    private var insertedIndexPaths = [NSIndexPath]()
    private var removedIndexPaths = [NSIndexPath]()
    private var insertedSectionIndices = [Int]()
    private var removedSectionIndices = [Int]()
    
    
    // MARK: - Layout attributes init
    
    private func computeEntireLayout(preserveScroll: Bool = true, newSize: CGSize) {
        // ensure we have a collection view
        guard let collectionView = self.collectionView, let dataSource = collectionView.dataSource else {
            currentCellAttributes = [Int: [UICollectionViewLayoutAttributes]]()
            currentScrollViewAttributes = [Int: ScrollViewSupplementaryLayoutAttributes]()
            return
        }
        // grab meta data needed for layout
        let numSections = dataSource.numberOfSectionsInCollectionView!(collectionView)
        // iterate sections
        for sectionIdx in 0..<numSections {
            let numCols = dataSource.collectionView(collectionView, numberOfItemsInSection: sectionIdx)
            var existingRowOffset: CGFloat = 0
            let scrollViewAtts = supplementaryScrollViewAttributes(sectionIdx, numOfItems: numCols)
            // attempt to preserve old offset if we have it
            if preserveScroll {
                if let oldSvAttributes = currentScrollViewAttributes[sectionIdx] {
                    existingRowOffset = oldSvAttributes.contentOffset.x
                    scrollViewAtts.contentOffset = CGPoint(x: existingRowOffset, y: 0)
                }
            }
            // cache items in row
            currentCellAttributes[sectionIdx] = layoutAttributes(sectionIdx, numOfItems: numCols, itemOffset: existingRowOffset)
            // cache scroll view
            currentScrollViewAttributes[sectionIdx] = scrollViewAtts
        }
        // remove sections outside of section count
        let remainingKeys = currentScrollViewAttributes.keys.filter() { $0 >= numSections }
        for sectionIdx in remainingKeys {
            currentScrollViewAttributes[sectionIdx] = nil
            currentCellAttributes[sectionIdx] = nil
        }
    }
    
    /// Convenience init for layout attributes of a supplementary scroll view in a particular row.
    private func supplementaryScrollViewAttributes(inRow: Int, numOfItems: Int) -> ScrollViewSupplementaryLayoutAttributes {
        guard numOfItems > 0 else {
            fatalError("shouldn't be requesting scroll view for a section with no items")
        }
        // compute content width of scroll view for numOfItems
        let rowHeight = itemSize.height + itemVerticalSpacing
        let rowContentWidth = edgeInsets.left + edgeInsets.right + CGFloat(numOfItems)*itemSize.width + CGFloat(numOfItems-1)*itemHorizontalSpacing
        // create attributes & set properties
        let svAttributes = ScrollViewSupplementaryLayoutAttributes(forSupplementaryViewOfKind: ScrollViewSupplementaryViewConst.kind,
                                                                   withIndexPath: NSIndexPath(forItem: 0, inSection: inRow))
        svAttributes.frame = CGRect(origin: CGPoint(x: 0, y: edgeInsets.top + CGFloat(inRow)*rowHeight),
                                    size: CGSize(width: self.collectionView!.bounds.width, height: itemSize.height))
        svAttributes.contentSize = CGSize(width: rowContentWidth,
                                          height: svAttributes.frame.height)
        svAttributes.section = inRow
        svAttributes.zIndex = GridLayoutConst.zIndexScrollView
        return svAttributes
    }
    
    /// Convenience init for layout attributes of cells in a particular row.
    private func layoutAttributes(inRow: Int, numOfItems: Int, itemOffset: CGFloat = 0) -> [UICollectionViewLayoutAttributes] {
        var rowAttributes = [UICollectionViewLayoutAttributes]()
        // first frame in row
        let rowHeight = itemSize.height + itemVerticalSpacing
        var itemFrame = CGRect(origin: CGPoint(x: edgeInsets.left, y: edgeInsets.top + CGFloat(inRow)*rowHeight),
                               size: itemSize)
        // create items
        for col in 0..<numOfItems {
            let indexPath = NSIndexPath(forItem: col, inSection: inRow)
            let attributes = UICollectionViewLayoutAttributes(forCellWithIndexPath: indexPath)
            attributes.transform3D = CATransform3DMakeTranslation(-itemOffset, 0, 0)
            attributes.frame = itemFrame
            attributes.zIndex = GridLayoutConst.zIndexCell
            rowAttributes.append(attributes)
            // increment to next items frame
            itemFrame.origin.x += itemSize.width + itemHorizontalSpacing
        }
        return rowAttributes
    }
    
    // Convenience init for a single item.
    private func layoutAttributesForCell(atIndexPath: NSIndexPath, itemOffset: CGFloat = 0) -> UICollectionViewLayoutAttributes {
        // compute position
        let rowHeight = itemSize.height + itemVerticalSpacing
        let rowWidth = itemSize.width + itemHorizontalSpacing
        let rowOrigin = CGPoint(x: edgeInsets.left + CGFloat(atIndexPath.item) * rowWidth,
                                y: edgeInsets.top + CGFloat(atIndexPath.section) * rowHeight)
        let itemFrame = CGRect(origin: rowOrigin,
                               size: itemSize)
        // create attributes
        let attributes = UICollectionViewLayoutAttributes(forCellWithIndexPath: atIndexPath)
        attributes.transform3D = CATransform3DMakeTranslation(-itemOffset, 0, 0)
        attributes.frame = itemFrame
        attributes.zIndex = GridLayoutConst.zIndexCell
        return attributes
    }
    
    
    // MARK: - Layout Updates
    
    func transitionToSize(size: CGSize) {
        computeEntireLayout(newSize: size)
        updateScrollViews(size.width)
    }
    
    func updateOffset(ofSection: Int, offset: CGFloat, invalidateLayout: Bool = true) {
        guard let scrollAttributes = currentScrollViewAttributes[ofSection], let rowAttributes = currentCellAttributes[ofSection] else {
            fatalError("should not be updating offset for row which doesn't exist")
        }
        // update cell attributes
        for attributes in rowAttributes {
            attributes.transform = CGAffineTransformMakeTranslation(-offset, 0)
        }
        // update supplementary attributes
        scrollAttributes.contentOffset = CGPoint(x: offset, y: 0)
        if invalidateLayout {
            self.invalidateLayout()
        }
    }
    
    
    // MARK: - Cell Layout Attributes
    
    override func layoutAttributesForItemAtIndexPath(indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes? {
        return currentCellAttributes[indexPath.section]?[indexPath.row]
    }
    
    override func layoutAttributesForElementsInRect(rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        var allAttributes = currentCellAttributes.flatMap() { $0.1 }
        let scrollAttributes = currentScrollViewAttributes.flatMap() { $0.1 }
        allAttributes.appendContentsOf(scrollAttributes as [UICollectionViewLayoutAttributes])
        return allAttributes
    }
    
    
    // MARK: - Supplementary Layout Attributes
    
    override func layoutAttributesForSupplementaryViewOfKind(elementKind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes? {
        if elementKind == ScrollViewSupplementaryViewConst.kind {
            return currentScrollViewAttributes[indexPath.section]
        } else {
            return nil
        }
    }
    
    
    // MARK: - Collection view updates
    
    override func invalidateLayoutWithContext(context: UICollectionViewLayoutInvalidationContext) {
        super.invalidateLayoutWithContext(context)
        if context.invalidateDataSourceCounts {
            // rebuild the world
            computeEntireLayout(newSize: self.collectionView!.bounds.size)
        }
    }
    
    override func prepareForCollectionViewUpdates(updateItems: [UICollectionViewUpdateItem]) {
        super.prepareForCollectionViewUpdates(updateItems)
        // Keep track of updates to items and sections so we can use this information to create nifty animations
        for item in updateItems {
            guard item.indexPathBeforeUpdate != nil || item.indexPathAfterUpdate != nil else { continue }
            if item.updateAction == .Insert {
                // If the update item's index path has an "item" value of NSNotFound, it means it was a section update, not an individual item.
                // This is 100% undocumented but 100% reproducible.
                guard let indexPath = item.indexPathAfterUpdate else { return }
                if indexPath.item == NSNotFound {
                    // track insert
                    insertedSectionIndices.append(indexPath.section)
                    // insert new row attributes
                    let numCols = self.collectionView!.dataSource!.collectionView(self.collectionView!, numberOfItemsInSection: indexPath.section)
                    let rowAttributes = layoutAttributes(indexPath.section,
                                                         numOfItems: numCols)
                    currentCellAttributes[indexPath.section] = rowAttributes
                    // insert scroll view
                    currentScrollViewAttributes[indexPath.section] = supplementaryScrollViewAttributes(indexPath.section, numOfItems: numCols)
                } else {
                    // track insert
                    insertedIndexPaths.append(indexPath)
                    // insert new row attributes
                    let rowAttributes = layoutAttributes(indexPath.section,
                                                         numOfItems: self.collectionView!.numberOfItemsInSection(indexPath.section))
                    currentCellAttributes[item.indexPathAfterUpdate!.section] = rowAttributes
                    // update scroll view
                    let oldScrollViewAttributes = currentScrollViewAttributes[indexPath.section]
                    let colCount = self.collectionView!.dataSource!.collectionView(self.collectionView!, numberOfItemsInSection: indexPath.section)
                    let newScrollViewAttributes = supplementaryScrollViewAttributes(indexPath.section, numOfItems: colCount)
                    newScrollViewAttributes.contentOffset = oldScrollViewAttributes?.contentOffset ?? CGPoint.zero
                    currentScrollViewAttributes[indexPath.section] = newScrollViewAttributes
                }
            } else if item.updateAction == .Delete {
                guard let indexPath = item.indexPathBeforeUpdate else { return }
                if indexPath.item == NSNotFound {
                    removedSectionIndices.append(indexPath.section)
                } else {
                    removedIndexPaths.append(indexPath)
                }
            }
        }
    }
    
    override func finalizeCollectionViewUpdates() {
        super.finalizeCollectionViewUpdates()
        // dump all tracked updates
        insertedIndexPaths = [NSIndexPath]()
        removedIndexPaths = [NSIndexPath]()
        insertedSectionIndices = [Int]()
        removedSectionIndices = [Int]()
    }
    
    
    // MARK: - Content Size
    
    override func collectionViewContentSize() -> CGSize {
        guard let collectionView = self.collectionView else {
            return CGSize.zero
        }
        let maxScrollViewY = currentScrollViewAttributes.values.reduce(0.0) { (maxY, attributes) -> CGFloat in
            if attributes.frame.maxY > maxY {
                return attributes.frame.maxY
            } else {
                return maxY
            }
        }
        let maxX = collectionView.bounds.width
        let maxY = maxScrollViewY + edgeInsets.bottom
        return CGSize(width: maxX, height: maxY)
    }
    
    
    // MARK: - Bounds change
    
    override func shouldInvalidateLayoutForBoundsChange(newBounds: CGRect) -> Bool {
        // only change if collection view size has changed
        if self.collectionView?.bounds.size != newBounds.size {
            return true
        } else {
            return false
        }
    }
    
    func updateScrollViews(toWidth: CGFloat) {
        for (_, scrollViewAttributes) in currentScrollViewAttributes {
            scrollViewAttributes.frame.size.width = toWidth
        }
    }
}
