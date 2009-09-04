//
//  StringUtil.h
//  EIJIRO Viewer
//
//  Created by numata on October 21, 2002.
//  Copyright 2002-2004 Satoshi NUMATA. All rights reserved.
//

#import <Cocoa/Cocoa.h>


// Shift-JIS における2バイト文字の先頭文字であるかどうかを判定する。
inline BOOL isFirst2BytesCharacter(unsigned char c);

// 2バイト文字を含む文字列かどうかを判定する。
BOOL isEnglishWordC(const unsigned char *str, unsigned int length);
BOOL isCapitalWordC(const unsigned char *str, unsigned int length);

// 与えられたサイズで、大文字小文字を無視して文字列の比較を行う。
int mystrncmp(const unsigned char *str1, const unsigned char *str2, unsigned int size, BOOL hasEijiroPrefix);

// 文字列の中に文字列が含まれているかどうかを調べる
BOOL strContainsStr(const unsigned char *strTarget, unsigned int targetSize,
	const unsigned char *strSearch, unsigned int searchSize);


//
//  英辞郎関係の文字列処理をサポートするためのカテゴリ
//

@interface NSString (EijiroSupport)

// 2バイト文字を含む文字列かどうかを判定する。
- (BOOL)isEnglishWord;

// ルビを除去した文字列をリターンする。
- (NSString *)stringByRemovingRubies;

// Ver.80形式の「■・」から始まる用例のプリフィクスを変換した文字列をリターンする。
- (NSString *)ver80FixedString;

// 疑似発音記号を修正した文字列をリターンする。
- (NSString *)pronunciationSymbolFixedString;

// 最初にある無意味な文字を除去した文字列をリターンする。
- (NSString *)stringByTrimmingFirstInvalidCharacters;

// 最後にある無意味な文字を除去した文字列をリターンする。
- (NSString *)stringByTrimmingLastInvalidCharacters;

@end


