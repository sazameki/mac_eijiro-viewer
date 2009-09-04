//
//  NMFontTransformer.m
//  EIJIRO Viewer
//
//  Created by numata on November 12, 2004.
//  Copyright 2004 Satoshi NUMATA. All rights reserved.
//

#import "NMFontTransformer.h"


//
//  フォント情報を表す文字列とユーザに見せるフォント情報を変換する。
//  元になる文字列は、「フォント名,ポイントサイズ」となっている。
//

@implementation NMFontTransformer

// 表示に使うだけなので、逆はないから無視しておく。
- (id)reverseTransformedValue:(id)value {
	return nil;
}

// 「HiraKakuPro-W3,12.000000」の形式から、「ヒラギノ角ゴ W3 - 12.0」の形式に変換する。
- (id)transformedValue:(id)value {
	int commaPos = [value rangeOfString:@","].location;
	if (commaPos == NSNotFound) {
		return @"";
	}
	NSString *fontName = [value substringToIndex:commaPos];
	float fontSize = [[value substringFromIndex:commaPos+1] floatValue];
	if (fontSize == 0.0) {
		fontSize = 12.0;
	}
	NSFont *font = [NSFont fontWithName:fontName size:fontSize];
	return [NSString stringWithFormat:@"%@ - %.1f", [font displayName], [font pointSize]];
}

@end
