//
//  StringUtil.m
//  EIJIRO Viewer
//
//  Created by numata on October 21, 2002.
//  Copyright 2002-2004 Satoshi NUMATA. All rights reserved.
//

#import "StringUtil.h"


// Shift-JIS における2バイト文字の先頭文字であるかどうかを判定する。
inline BOOL isFirst2BytesCharacter(unsigned char c) {
	return (c >= 0x80 && c <= 0x9f || c >= 0xe0 && c <= 0xfc);
}

// 2バイト文字を含む文字列かどうかを判定する。
inline BOOL isEnglishWordC(const unsigned char *str, unsigned int length) {
	for (unsigned int i = 0; i < length; i++) {
		if (isFirst2BytesCharacter(str[i])) {
			return NO;
		}
	}
	return YES;
}

// 大文字で構成される文字列かどうかを判定する。
inline BOOL isCapitalWordC(const unsigned char *str, unsigned int length) {
	for (unsigned int i = 0; i < length; i++) {
		if (islower(str[i])) {
			return NO;
		}
	}
	return YES;
}

// 与えられたサイズで、大文字小文字を無視して文字列の比較を行う。
int mystrncmp(const unsigned char *str1, const unsigned char *str2, unsigned int size, BOOL hasEijiroPrefix) {
	// 英辞郎のデータには一部行頭が欠けているものがあるので、その対処
	// （実際には、StuffIt Expanderで書籍版のデータを解凍するとこの問題が起きる）。
	// 「■」の1バイト目を必ず読み飛ばして比較を行うようにする。
	if (hasEijiroPrefix) {
		if (*str1 == 0x81) {
			str1++;
		}
		if (*str2 == 0x81) {
			str2++;
		}
		size -= 1;
	}
	
	// 比較のメイン
	for (unsigned int i = 0; i < size; i++) {
		unsigned char c1 = str1[i];
		unsigned char c2 = str2[i];
		// '{' と ',' は単語の区切りと看做す。
		// "1,234" などがうまく検索できないが、とりあえず放っておこう。
		if (c1 == '{' || c1 == ',') {
			return -1;
		}
		// 文字コード順に並んでいない文字の対処。
		// '[', '\', '_' の順に 'z' よりも下に現れる。
		// これを '{', '|', '}' として扱うことで、とりあえず問題を回避できるだろう。
		if (c1 == '[') {
			c1 = '{';
		} else if (c1 == '\\') {
			c1 = '|';
		} else if (c1 == '_') {
			c1 = '}';
		}
		if (c2 == '[') {
			c2 = '{';
		} else if (c2 == '\\') {
			c2 = '|';
		} else if (c2 == '_') {
			c2 = '}';
		}
		// A～Z の文字は a～z に変換しておく
		if (c1 >= 'A' && c1 <= 'Z') {
			c1 = tolower(c1);
		}
		if (c2 >= 'A' && c2 <= 'Z') {
			c2 = tolower(c2);
		}
		// 比較する
		if (c1 != c2) {
			return c1 - c2;
		}
		// 2バイト文字の先頭文字であればもう1字を変換なしに比較する
		if (i < size && isFirst2BytesCharacter(c1)) {
			i++;
			c1 = str1[i];
			c2 = str2[i];
			if (c1 != c2) {
				return c1 - c2;
			}
		}
	}
	return 0;
}

// 文字列の中に文字列が含まれているかどうかを調べる
BOOL strContainsStr(const unsigned char *strTarget, unsigned int targetSize,
	const unsigned char *strSearch, unsigned int searchSize)
{
	unsigned char firstChar = strSearch[0];
	if (targetSize < searchSize) {
		return NO;
	}
	if (firstChar >= 'A' && firstChar <= 'Z') {
		firstChar = tolower(firstChar);
	}
	for (unsigned int i = 0; i < targetSize - searchSize + 1; i++) {
		unsigned char c = strTarget[i];
		if (c >= 'A' && c <= 'Z') {
			c = tolower(c);
		}
		if (c == firstChar) {
			if (mystrncmp(strTarget + i, strSearch, searchSize, NO) == 0) {
				return YES;
			}
		}
		if (isFirst2BytesCharacter(strTarget[i])) {
			i++;
		}
	}
	return NO;
}


//
//  英辞郎関係の文字列処理をサポートするためのカテゴリ
//

@implementation NSString (EijiroSupport)

static NSString *pronunciationPrefix;

// 初期化
+ (void)initialize {
	unichar c[3] = { 0x3010, 0x767a, 0x97f3 };
	pronunciationPrefix = [[NSString alloc] initWithCharacters:c length:3];
}

// 2バイト文字を含む文字列かどうかを判定する。
- (BOOL)isEnglishWord {
	NSData *data = [self dataUsingEncoding:NSShiftJISStringEncoding];
	unsigned char *p = (unsigned char *) [data bytes];
	unsigned int length = [data length];
	for (unsigned int i = 0; i < length; i++) {
		if (isFirst2BytesCharacter(p[i])) {
			return NO;
		}
	}
	return YES;
}

// ルビを除去した文字列をリターンする
- (NSString *)stringByRemovingRubies {
	unsigned int length = [self length];
	unichar *buffer = malloc(sizeof(unichar) * length);
	BOOL ignoring = NO;
	unsigned int pos = 0;
	for (unsigned int i = 0; i < length; i++) {
		unichar c = [self characterAtIndex:i];
		if (c == 0xff5b) {	// 全角の「｛」
			ignoring = YES;
		}
		if (!ignoring) {
			buffer[pos++] = c;
		}
		if (c == 0xff5d) {	// 全角の「｝」
			ignoring = NO;
		}
	}
	
	NSString *result = [NSString stringWithCharacters:buffer length:pos];
	free(buffer);
	return result;
}

// 英辞郎のデータVer.80で変更された用例表記を変換した文字列をリターンする
- (NSString *)ver80FixedString {
	NSMutableString *ret = nil;
	NSString *prefixStr = NSLocalizedString(@"VER80_EXAMPLE_PREFIX", @"VER80_EXAMPLE_PREFIX");
	BOOL isFirst = YES;
	unsigned int length = [self length];
	NSRange searchingRange = NSMakeRange(0, length);
	while (YES) {
		NSRange prefixRange = [self rangeOfString:prefixStr options:0 range:searchingRange];
		if (prefixRange.location == NSNotFound) {
			if (searchingRange.location == 0) {
				return self;
			} else {
				[ret appendString:[self substringWithRange:searchingRange]];
			}
			break;
		}
		if (!ret) {
			ret = [NSMutableString stringWithString:[self substringWithRange:
				NSMakeRange(searchingRange.location, prefixRange.location-searchingRange.location)]];
		} else {
			[ret appendString:[self substringWithRange:
				NSMakeRange(searchingRange.location, prefixRange.location-searchingRange.location)]];
		}
		if (isFirst) {
			[ret appendString:NSLocalizedString(@"EXAMPLE_FIRST_PREFIX", @"EXAMPLE_FIRST_PREFIX")];
			isFirst = NO;
		} else {
			[ret appendString:@" / "];
		}
		searchingRange.location = prefixRange.location + 2;
		searchingRange.length = length - prefixRange.location - 2;
	}
	return ret;
}

// 発音記号を補正した文字列をリターンする
- (NSString *)pronunciationSymbolFixedString {
	// 発音記号のプリフィクスを探す
	NSRange pronPrefixRange = [self rangeOfString:pronunciationPrefix];
	if (pronPrefixRange.location == NSNotFound) {
		return self;
	}
	// プリフィクスまでの部分を追加
	NSMutableString *ret = [NSMutableString stringWithString:
		[self substringToIndex:pronPrefixRange.location+4]];
	// 発音記号を変換
	unsigned int length = [self length];
	unichar *buffer = malloc(sizeof(unichar) * (length - pronPrefixRange.location - 4));
	unsigned int pos = 0;
	unsigned int i;
	for (i = pronPrefixRange.location+4; i < length; i++) {
		unichar c1 = [self characterAtIndex:i];
		// 発音記号の終了（「、」）
		if (c1 == 0x3001) {
			break;
		}
		// その他
		else {
			unichar c = c1;
			BOOL pass = NO;
			switch (c1) {
				case 0x0027:	// '
					c = 0x0301;
					break;
				case 0x003a:	// :
					c = 0x02d0;
					break;
				case 0x0060:	// `
					c = 0x0300;
					break;
				case 0x0061: // 傘の付いたa
							 // ae
					if (i+1 < length && [self characterAtIndex:i+1] == 0x65) {
						c = 0x00e6;
						i++;
					}
					break;
				case 0x044d:	// eのひっくり返ったa
					c = 0x0259;
					break;
				case 0x039b:	// ターンA
					c = 0x028c;
					break;
				case 0x03b1:	// a
					c = 0x0251;
					break;
				case 0x03b4:	// th（濁音）
					c = 0x00f0;
					break;
				case 0x03b7:	// ng
					c = 0x014b;
					break;
				case 0x03b8:	// th
					c = 0x03b8;
					break;
				case 0x0437:	// zg
					c = 0x0292;
					break;
				case 0x20dd:	// sh
					c = 0x0283;
					break;
				case 0x5c0f:	// 間に挟まっている正体不明の文字（ハイフン？）
					pass = YES;
					break;
				case 0xff4f:	// cがひっくり返ったo
					c = 0x0254;
					break;
			}
			// 変換した結果を追加
			if (!pass) {
				buffer[pos++] = c;
			}
		}
	}
	if (pos > 0) {
		[ret appendString:[NSString stringWithCharacters:buffer length:pos]];
	}
	free(buffer);
	// 残りの文字を吐き出す
	if (i < length) {
		[ret appendString:[self substringFromIndex:i]];
	}
	// リターン
	return ret;
}

// 最初にある無意味な文字を除去した文字列をリターンする
- (NSString *)stringByTrimmingFirstInvalidCharacters {
	unsigned int startIndex = 0;
	while (startIndex < [self length]) {
		unichar c = [self characterAtIndex:startIndex];
		if (c != ' ' && c != '\t' && c != '\r' && c != '\n' && c != 0x3000 &&
			c != ',' && c != '.' && c != ';' && c != ':' && c != '!' && c != '?' &&
			c != '(' && c != ')' && c != '<' && c != '>' && c != '{' && c != '}' &&
			c != '\'' && c != '\"')
		{
			break;
		}
		startIndex++;
	}
	if (startIndex < [self length]) {
		return [self substringFromIndex:startIndex];
	}
	return self;
}

// 最後にある無意味な文字を除去した文字列をリターンする
- (NSString *)stringByTrimmingLastInvalidCharacters {
	unsigned int lastIndex = [self length] - 1;
	while (lastIndex >= 0) {
		unichar c = [self characterAtIndex:lastIndex];
		if (c != ' ' && c != '\t' && c != '\r' && c != '\n' && c != 0x3000 &&
			c != ',' && c != '.' && c != ';' && c != ':' && c != '!' && c != '?' &&
			c != '(' && c != ')' && c != '<' && c != '>' && c != '{' && c != '}' &&
			c != '\'' && c != '\"')
		{
			break;
		}
		lastIndex--;
	}
	if (lastIndex >= 0) {
		return [self substringToIndex:lastIndex+1];
	}
	return self;
}

@end
