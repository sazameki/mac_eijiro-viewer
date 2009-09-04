//
//  NMSearchFieldCell.m
//
//  Created by numata on July 28, 2003.
//  Copyright 2003-2004 Satoshi NUMATA. All rights reserved.
//

#import "NMTextFieldCell.h"
#import "NMTextField.h"
#import "ApplicationManager.h"
#import "SearchManager.h"
#import "StringUtil.h"


//
//  NMTextField専用のフィールドエディタ
//

@implementation NMSearchTextView

// 初期化
- (id)init {
	self = [super init];
	if (self) {
		[self registerForDraggedTypes:[NSArray arrayWithObject:NSStringPboardType]];
	}
	return self;
}

// ドラッグ終了時の処理
- (void)concludeDragOperation:(id <NSDraggingInfo>)sender {
	NSPasteboard *draggingPasteboard = [sender draggingPasteboard];
	NSString *pasteStr = [draggingPasteboard stringForType:NSStringPboardType];
	pasteStr = [pasteStr stringByTrimmingFirstInvalidCharacters];
	pasteStr = [pasteStr stringByTrimmingLastInvalidCharacters];
	[self setString:pasteStr];
	[NSApp activateIgnoringOtherApps:YES];
	ApplicationManager *applicationManager =
		[[[NSThread currentThread] threadDictionary] valueForKey:@"ApplicationManager"];
	SearchManager *searchManager =
		[[[NSThread currentThread] threadDictionary] valueForKey:@"SearchManager"];
	[applicationManager activatePronounceButton];
	[applicationManager clearSubsequentHistory];
	[applicationManager fixSearchString:self];
	[searchManager searchString:pasteStr];
}

// …なんだっけ？
// コメント追加前に作ったので覚えてない。。。
- (BOOL)readSelectionFromPasteboard:(NSPasteboard *)pboard type:(NSString *)type {
	if ([type isEqualToString:NSStringPboardType]) {
		NSString *pasteStr = [pboard stringForType:NSStringPboardType];
		pasteStr = [pasteStr stringByTrimmingFirstInvalidCharacters];
		pasteStr = [pasteStr stringByTrimmingLastInvalidCharacters];
		[pboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
		[pboard setString:pasteStr forType:NSStringPboardType];
	}
	return [super readSelectionFromPasteboard:pboard type:type];
}

@end


//
//  NMTextField内部のセル
//

@implementation NMTextFieldCell

// 初期化
- (id)init {
	self = [super initTextCell:@""];
	if (self) {
		// 専用のフィールドエディタ
		fieldEditor = [[NMSearchTextView alloc] init];
		[fieldEditor setFieldEditor:YES];

		// 最大値・最小値・現在値
		minValue = 0;
		maxValue = 100;
		value = 0;

		// プログレスバー描画のための画像
		progLeftImage = [NSImage imageNamed:@"Location_Left_Progress"];
		progMiddleImage = [NSImage imageNamed:@"Location_Middle_Progress"];
		progRightImage = [NSImage imageNamed:@"Location_Right_Progress"];
		[progLeftImage setFlipped:YES];
		[progMiddleImage setFlipped:YES];
		[progRightImage setFlipped:YES];
	}
	return self;
}

// クリーンアップ
- (void)dealloc {
	[fieldEditor release];
	[super dealloc];
}

// フォーカスリングは表示
- (BOOL)showsFirstResponder {
    return YES;
}

// 背景の描画はOFFにして自分で描画
- (BOOL)drawsBackground {
    return NO;
}

// 折り返し制御
- (BOOL)wraps {
    return NO;
}

// スクロール制御
- (BOOL)isScrollable {
    return YES;
}

// フィールドエディタのセットアップ
- (NSText *)setUpFieldEditorAttributes:(NSText *)textObj {
	[super setUpFieldEditorAttributes:fieldEditor];
	return fieldEditor;
}

// 描画のオーバーライド
- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
	// プログレスバーの描画
	double progress = (value - minValue) / (maxValue - minValue);
	double indicatorWidth = cellFrame.size.width * progress;
	double leftSize = (indicatorWidth > 18)? 18: indicatorWidth;
	[progLeftImage drawInRect:NSMakeRect(1, 2, leftSize-1, 19)
					 fromRect:NSMakeRect(0, 0, leftSize-1, 19)
					operation:NSCompositeSourceOver
					 fraction:1.0];
	if (indicatorWidth > 18) {
		double midSize = (indicatorWidth-18 > cellFrame.size.width-18-3)?
			cellFrame.size.width-18-3: indicatorWidth-18;
		[progMiddleImage drawInRect:NSMakeRect(18, 2, midSize, 19)
						   fromRect:NSMakeRect(0, 0, 32, 19)
						  operation:NSCompositeSourceOver
						   fraction:1.0];
		if (indicatorWidth-18-midSize > 0) {
			double rightSize = indicatorWidth-18-midSize;
			[progRightImage drawInRect:NSMakeRect(cellFrame.size.width-3, 2, rightSize, 19)
							  fromRect:NSMakeRect(0, 0, rightSize, 19)
							 operation:NSCompositeSourceOver
							  fraction:1.0];
		}
	}
	
	// 残りの部分の描画
	[super drawInteriorWithFrame:cellFrame inView:controlView];
}

// 現在値をリターンする
- (double)doubleValue {
	return value;
}

// 最大値をリターンする
- (double)maxValue {
	return maxValue;
}

// 最小値をリターンする
- (double)minValue {
	return minValue;
}

// 現在値をセットする
- (void)setDoubleValue:(double)doubleValue {
	value = doubleValue;
}

// 最大値をセットする
- (void)setMaxValue:(double)newMaximum {
	maxValue = newMaximum;
}

// 最小値をセットする
- (void)setMinValue:(double)newMinimum {
	minValue = newMinimum;
}

// 専用のフィールドエディタをリターンする
- (NSText *)fieldEditor {
	return fieldEditor;
}

@end


