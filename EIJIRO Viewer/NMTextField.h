//
//  NMTextField.h
//
//  Created by numata on April 6, 2004.
//  Copyright 2003-2004 Satoshi NUMATA. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class NMTextFieldCell;


//
//  プログレスバー機能を持ったテキストフィールド
//

@interface NMTextField : NSTextField {
	
	// アウトレット
	NMTextFieldCell	*searchCell;	// 内部のセル
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
