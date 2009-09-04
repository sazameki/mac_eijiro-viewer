//
//  NMTextField.m
//
//  Created by numata on April 6, 2004.
//  Copyright 2003-2004 Satoshi NUMATA. All rights reserved.
//

#import "NMTextField.h"
#import "NMTextFieldCell.h"


//
//  プログレスバー機能を持ったテキストフィールド
//

@implementation NMTextField

// 初期化
- (id)initWithCoder:(NSCoder *)decoder {
	self = [super initWithCoder:decoder];
	if (self) {
		// 専用の内部セルの作成
		searchCell = [[[NMTextFieldCell alloc] init] autorelease];
		// 元のセルからプロパティをコピー
		NSCell *oldCell = [self cell];
		[searchCell setContinuous:[oldCell isContinuous]];
		[searchCell setSendsActionOnEndEditing:[oldCell sendsActionOnEndEditing]];
		[searchCell setEditable:[oldCell isEditable]];
		[searchCell setFont:[oldCell font]];
		[searchCell setFocusRingType:[oldCell focusRingType]];
		[searchCell setBordered:[oldCell isBordered]];
		[searchCell setBezeled:[oldCell isBezeled]];
		[searchCell setTarget:[oldCell target]];
		[searchCell setAction:[oldCell action]];
		// 内部セルの入れ換え
		[self setCell:searchCell];
	}
	return self;
}

// プログレスバーの最大値をリターンする
- (double)maxValue {
	return [(NMTextFieldCell *) searchCell maxValue];
}

// プログレスバーの最小値をリターンする
- (double)minValue {
	return [(NMTextFieldCell *) searchCell minValue];
}

// プログレスバーの最大値をセットする
- (void)setMaxValue:(double)newMaximum {
	[(NMTextFieldCell *) searchCell setMaxValue:newMaximum];
}

// プログレスバーの最小値をセットする
- (void)setMinValue:(double)newMinimum {
	[(NMTextFieldCell *) searchCell setMinValue:newMinimum];
}

// プログレスバーの現在値をリターンする
- (double)doubleValue {
	return [(NMTextFieldCell *) searchCell doubleValue];
}

// プログレスバーの現在値をセットする
- (void)setDoubleValue:(double)doubleValue {
	[(NMTextFieldCell *) searchCell setDoubleValue:doubleValue];
	[self setNeedsDisplay:YES];
}

// 専用のフィールドエディタをリターンする
- (NSText *)fieldEditor {
	return [searchCell fieldEditor];
}

@end
