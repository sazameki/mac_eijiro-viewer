//
//  NMSearchFieldCell.h
//
//  Created by numata on July 28, 2003.
//  Copyright (c) 2003-2004 Satoshi NUMATA. All rights reserved.
//

#import <Cocoa/Cocoa.h>


//
//  NMTextField専用のフィールドエディタ
//

@interface NMSearchTextView : NSTextView

@end


//
//  NMTextField内部のセル
//

@interface NMTextFieldCell : NSTextFieldCell {
	// 最大値・最小値・現在値
	double value;
	double maxValue;
	double minValue;

	// 専用のフィールドエディタ
	NMSearchTextView	*fieldEditor;

	// プログレスバー描画のための画像
	NSImage *progLeftImage;
	NSImage *progMiddleImage;
	NSImage *progRightImage;
}

// 最大値・最小値・現在値のSetter/Getter
- (double)doubleValue;
- (double)maxValue;
- (double)minValue;

- (void)setDoubleValue:(double)doubleValue;
- (void)setMaxValue:(double)newMaximum;
- (void)setMinValue:(double)newMinimum;

// 専用のフィールドエディタ
- (NSText *)fieldEditor;

@end






