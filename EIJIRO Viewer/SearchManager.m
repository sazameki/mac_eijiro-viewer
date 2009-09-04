//
//  SearchManager.h
//  EIJIRO Viewer
//
//  Created by numata on November 11, 2004.
//  Copyright 2004 Satoshi NUMATA. All rights reserved.
//

#import "SearchManager.h"

//#import <OgreKit/OgreKit.h>
#import <sys/time.h>

#import "StringUtil.h"
#import "ApplicationManager.h"


//
//  SearchManager で内部的に使用するメンバメソッド
//

@interface SearchManager (Internal)

// メインスレッドでUIを変更するためのメソッド
- (void)clearResult:(NSNumber *)searchIDObj;		// 結果のクリア
- (void)addResultLine:(NSArray *)lineInfo;			// 結果の行を追加	
- (void)addSeparator:(NSNumber *)searchIDObj;		// 辞書間のセパレータの追加
- (void)prepareScrolling:(NSNumber *)searchIDObj;	// スクロール位置復元のための待ち合わせ
- (void)scrollToLastRect:(NSArray *)searchInfo;		// スクロール位置の復元
- (void)addNotFound:(NSArray *)searchInfo;			// 見つからなかった場合のメッセージの追加
- (void)addGuessForSearchWord:(NSString *)searchWord
					 searchID:(unsigned long)searchID;	// 修正候補の追加
- (void)addFullSearchNotFound:(NSNumber *)searchIDObj;	// 全文検索で対象が見つからなかった場合のメッセージの追加
- (void)addFullSearchCanceledSeparator;					// 全文検索のキャンセルを示すメッセージの追加

// 検索IDの生成
- (unsigned long)createSearchID;

// 通常検索のためのバイナリサーチ
- (int)searchForCString:(unsigned char *)cSearchStr
	   cSearchStrLength:(unsigned int)cSearchStrLength
				 inData:(NSData *)data
		   removeRubies:(BOOL)removeRubies
			searchIDObj:(NSNumber *)searchIDObj;

// 全文検索
- (void)fullSearchForString:(NSString *)searchStr
					 inData:(NSData *)data
			   removeRubies:(BOOL)removeRubies
			  currentLength:(unsigned int)currentLength
				totalLength:(unsigned int)totalLength
				   searchID:(unsigned long)searchID
				   titleStr:(NSString *)titleStr;

// 正規表現を使った全文検索
/*- (void)fullSearchForStringWithRegularExpression:(NSString *)searchStr
										  inData:(NSData *)data
									removeRubies:(BOOL)removeRubies
								   currentLength:(unsigned int)currentLength
									 totalLength:(unsigned int)totalLength
										searchID:(unsigned long)searchID
										titleStr:(NSString *)titleStr;*/

@end


//
//  英辞郎辞書の検索を行うクラス。
//
//  本当は全文検索と通常検索とを分けたいのだが、IDなどの共有がちょっとややこしいので、
//  ここにまとめて置いてある。
//

@implementation SearchManager

// 初期化
- (id)init {
	self = [super init];
	if (self) {
	}
	return self;
}

// クリーンアップ
- (void)dealloc {
	[firstGuess release];
	[secondGuess release];
	[super dealloc];
}

// 新しい検索IDの生成
- (unsigned long)createSearchID {
	struct timeval timeVal;
	gettimeofday(&timeVal, NULL);
	return timeVal.tv_usec + timeVal.tv_sec * 1000000;
}

// 与えられた文字列に対して全文検索を実行する
- (void)doFullSearchForString:(NSString *)searchStr {
	// 検索対象を検証
	if (!searchStr || [searchStr length] == 0) {
		NSBeep();
		return;
	}
	// 検索フィールドを検索対象の文字列で置き換え
	[searchField setStringValue:searchStr];
	// 結果表示ビューにフォーカスを移動
	[mainWindow makeFirstResponder:resultView];
	// 新しい検索IDを作成
	currentSearchID = [self createSearchID];
	// 全文検索スレッドを作成
	NSArray *threadInfo = [[NSArray alloc] initWithObjects:searchStr,
		[NSNumber numberWithUnsignedLong:currentSearchID], nil];
	[NSThread detachNewThreadSelector:@selector(fullSearchProc:)
							 toTarget:self
						   withObject:threadInfo];
	[threadInfo release];
}

// 全文検索スレッド用のメソッド
- (void)fullSearchProc:(NSArray *)threadInfo {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	[NSThread setThreadPriority:0.1];

	NSString *searchStr = [threadInfo objectAtIndex:0];
	unsigned long searchID = [[threadInfo objectAtIndex:1] unsignedLongValue];
	NSNumber *searchIDObj = [NSNumber numberWithUnsignedLong:searchID];
	
	id values = [[NSUserDefaultsController sharedUserDefaultsController] values];
	BOOL searchEijiro = [[values valueForKey:@"fullSearchEijiro"] boolValue];
	BOOL searchRyakugoro = [[values valueForKey:@"fullSearchRyakugoro"] boolValue];
	BOOL searchWaeijiro = [[values valueForKey:@"fullSearchWaeijiro"] boolValue];
	BOOL searchReijiro = [[values valueForKey:@"fullSearchReijiro"] boolValue];
	
	if (!searchEijiro && !searchRyakugoro && !searchWaeijiro && !searchReijiro) {
		NSBeep();
		return;
	}
	
	[self performSelectorOnMainThread:@selector(clearResult:)
						   withObject:searchIDObj
						waitUntilDone:YES];
	
	NSString *eijiroPath = [values valueForKey:@"eijiroPath"];
	NSString *ryakugoroPath = [values valueForKey:@"ryakugoroPath"];
	NSString *waeijiroPath = [values valueForKey:@"waeijiroPath"];
	NSString *reijiroPath = [values valueForKey:@"reijiroPath"];
	
	BOOL removeRubies = [[values valueForKey:@"removeRubies"] boolValue];
	
	NSData *eijiroData = [NSData dataWithContentsOfMappedFile:eijiroPath];
	NSData *ryakugoroData = [NSData dataWithContentsOfMappedFile:ryakugoroPath];
	NSData *waeijiroData = [NSData dataWithContentsOfMappedFile:waeijiroPath];
	NSData *reijiroData = [NSData dataWithContentsOfMappedFile:reijiroPath];

	unsigned int totalLength = 0;
	unsigned int currentLength = 0;
	if (searchEijiro) {
		totalLength += [eijiroData length];
	}
	if (searchRyakugoro) {
		totalLength += [ryakugoroData length];
	}
	if (searchWaeijiro) {
		totalLength += [waeijiroData length];
	}
	if (searchReijiro) {
		totalLength += [reijiroData length];
	}
	
	if (searchEijiro && currentSearchID == searchID) {
		NSString *titleStr = NSLocalizedString(@"FULLSEARCH_TITLE_EIJIRO", @"FULLSEARCH_TITLE_EIJIRO");
		[self fullSearchForString:searchStr
						   inData:eijiroData
					 removeRubies:removeRubies
					currentLength:currentLength
					  totalLength:totalLength
						 searchID:searchID
						 titleStr:titleStr];
		currentLength += [eijiroData length];
	}
	if (searchRyakugoro && currentSearchID == searchID) {
		NSString *titleStr = NSLocalizedString(@"FULLSEARCH_TITLE_RYAKUGORO", @"FULLSEARCH_TITLE_RYAKUGORO");
		[self fullSearchForString:searchStr
						   inData:ryakugoroData
					 removeRubies:removeRubies
					currentLength:currentLength
					  totalLength:totalLength
						 searchID:searchID
						 titleStr:titleStr];
		currentLength += [ryakugoroData length];
	}
	if (searchWaeijiro && currentSearchID == searchID) {
		NSString *titleStr = NSLocalizedString(@"FULLSEARCH_TITLE_WAEIJIRO", @"FULLSEARCH_TITLE_WAEIJIRO");
		[self fullSearchForString:searchStr
						   inData:waeijiroData
					 removeRubies:removeRubies
					currentLength:currentLength
					  totalLength:totalLength
						 searchID:searchID
						 titleStr:titleStr];
		currentLength += [waeijiroData length];
	}
	if (searchReijiro && currentSearchID == searchID) {
		NSString *titleStr = NSLocalizedString(@"FULLSEARCH_TITLE_REIJIRO", @"FULLSEARCH_TITLE_REIJIRO");
		[self fullSearchForString:searchStr
						   inData:reijiroData
					 removeRubies:removeRubies
					currentLength:currentLength
					  totalLength:totalLength
						 searchID:searchID
						 titleStr:titleStr];
	}
	
	NSArray *progInfo = [[NSArray alloc] initWithObjects:[NSNumber numberWithUnsignedLong:currentSearchID],
		[NSNumber numberWithDouble:0], nil];
	[self performSelectorOnMainThread:@selector(setProgress:)
						   withObject:progInfo
						waitUntilDone:YES];
	[progInfo release];

	[pool release];
}

// 与えられたデータに対して全文検索を行う
- (void)fullSearchForString:(NSString *)searchStr
					 inData:(NSData *)data
			   removeRubies:(BOOL)removeRubies
			  currentLength:(unsigned int)currentLength
				totalLength:(unsigned int)totalLength
				   searchID:(unsigned long)searchID
				   titleStr:(NSString *)titleStr
{
	NSNumber *searchIDObj = [NSNumber numberWithUnsignedLong:searchID];
	const unsigned char *bytes = [data bytes];
	unsigned int length = [data length];
	unsigned int pos = 0;
	unsigned int lineStartPos;
	unsigned int lineEndPos;
	int lineCount = 0;
	int matchedCount = 0;
	NSData *searchStrData = [searchStr dataUsingEncoding:NSShiftJISStringEncoding];
	NSArray *titleInfo = [[NSArray alloc] initWithObjects:searchIDObj, titleStr, nil];
	[self performSelectorOnMainThread:@selector(addResultLine:)
						   withObject:titleInfo
						waitUntilDone:NO];
	[titleInfo release];
	while (pos < length) {
		lineStartPos = pos;
		pos++;
		lineEndPos = -1;
		while (pos < length) {
			unsigned char c = bytes[pos];
			pos++;
			if (isFirst2BytesCharacter(c)) {
				if (pos < length) {
					pos++;
				}
			} else if (c == 0x0a || c == 0x0d) {
				lineEndPos = pos - 1;
				break;
			}
		}
		if (lineEndPos < 0) {
			lineEndPos = length - 1;
		}
		unsigned char c = bytes[pos];
		if (c == 0x0a || c == 0x0d) {
			pos++;
		}
		unsigned int lineLength = lineEndPos - lineStartPos + 1;
		if (strContainsStr(bytes + lineStartPos, lineLength,
						   [searchStrData bytes], [searchStrData length]))
		{
			NSData *lineData = [data subdataWithRange:NSMakeRange(lineStartPos, lineLength)];
			NSString *lineStr = [[NSString alloc] initWithData:lineData encoding:NSShiftJISStringEncoding];
			NSString *ver80FixStr;
			if (removeRubies) {
				lineStr = [lineStr stringByRemovingRubies];
			}
			lineStr = [lineStr pronunciationSymbolFixedString];
			lineStr = [lineStr ver80FixedString];
			[self performSelectorOnMainThread:@selector(addResultLine:)
								   withObject:[NSArray arrayWithObjects:searchIDObj, lineStr, nil]
								waitUntilDone:NO];
			matchedCount++;
		}
		lineCount++;
		if (currentSearchID != searchID) {
			return;
		}
		if (lineCount % 10000 == 0) {
			NSArray *progInfo = [[NSArray alloc] initWithObjects:searchIDObj,
				[NSNumber numberWithDouble:(((double) (currentLength + pos) / totalLength) * 100.0)], nil];
			[self performSelectorOnMainThread:@selector(setProgress:)
								   withObject:progInfo
								waitUntilDone:NO];
			[progInfo release];
		}
	}
	if (matchedCount == 0) {
		[self performSelectorOnMainThread:@selector(addFullSearchNotFound:)
							   withObject:searchIDObj
							waitUntilDone:NO];
	}
	[self performSelectorOnMainThread:@selector(addSeparator:)
						   withObject:searchIDObj
						waitUntilDone:NO];
}

// 与えられたデータに対して全文検索を行う
/*- (void)fullSearchForStringWithRegularExpression:(NSString *)searchStr
										  inData:(NSData *)data
									removeRubies:(BOOL)removeRubies
								   currentLength:(unsigned int)currentLength
									 totalLength:(unsigned int)totalLength
										searchID:(unsigned long)searchID
										titleStr:(NSString *)titleStr
{
	NSNumber *searchIDObj = [NSNumber numberWithUnsignedLong:searchID];
	const unsigned char *bytes = [data bytes];
	unsigned int length = [data length];
	unsigned int pos = 0;
	unsigned int lineStartPos;
	unsigned int lineEndPos;
	int lineCount = 0;
	int matchedCount = 0;
	NSData *searchStrData = [searchStr dataUsingEncoding:NSShiftJISStringEncoding];
	NSArray *titleInfo = [[NSArray alloc] initWithObjects:searchIDObj, titleStr, nil];
	[self performSelectorOnMainThread:@selector(addResultLine:)
						   withObject:titleInfo
						waitUntilDone:NO];
	[titleInfo release];
	while (pos < length) {
		lineStartPos = pos;
		pos++;
		lineEndPos = -1;
		while (pos < length) {
			unsigned char c = bytes[pos];
			pos++;
			if (isFirst2BytesCharacter(c)) {
				if (pos < length) {
					pos++;
				}
			} else if (c == 0x0a || c == 0x0d) {
				lineEndPos = pos - 1;
				break;
			}
		}
		if (lineEndPos < 0) {
			lineEndPos = length - 1;
		}
		unsigned char c = bytes[pos];
		if (c == 0x0a || c == 0x0d) {
			pos++;
		}
		unsigned int lineLength = lineEndPos - lineStartPos + 1;
		NSData *lineData = [data subdataWithRange:NSMakeRange(lineStartPos, lineLength)];
		NSString *lineStr = [[[NSString alloc] initWithData:lineData encoding:NSShiftJISStringEncoding] autorelease];
		NSRange matchingRange = [lineStr rangeOfRegularExpressionString:searchStr];
		if (matchingRange.location != NSNotFound) {
			if (removeRubies) {
				lineStr = [lineStr stringByRemovingRubies];
			}
			lineStr = [lineStr pronunciationSymbolFixedString];
			lineStr = [lineStr ver80FixedString];
			if (matchedCount == 0) {
				[self performSelectorOnMainThread:@selector(addResultLine:)
									   withObject:[NSArray arrayWithObjects:searchIDObj, titleStr, nil]
									waitUntilDone:NO];
			}
			[self performSelectorOnMainThread:@selector(addResultLine:)
								   withObject:[NSArray arrayWithObjects:searchIDObj, lineStr, nil]
								waitUntilDone:NO];
			matchedCount++;
		}
		lineCount++;
		if (currentSearchID != searchID) {
			return;
		}
		if (lineCount % 10000 == 0) {
			NSArray *progInfo = [[NSArray alloc] initWithObjects:searchIDObj,
				[NSNumber numberWithDouble:(((double) (currentLength + pos) / totalLength) * 100.0)], nil];
			[self performSelectorOnMainThread:@selector(setProgress:)
								   withObject:progInfo
								waitUntilDone:NO];
			[progInfo release];
		}
	}
	if (matchedCount == 0) {
		[self performSelectorOnMainThread:@selector(addFullSearchNotFound:)
							   withObject:searchIDObj
							waitUntilDone:NO];
	}
	[self performSelectorOnMainThread:@selector(addSeparator:)
						   withObject:searchIDObj
						waitUntilDone:NO];
}*/

// 結果表示ビューのクリア
- (void)clearResult:(NSNumber *)searchIDObj {
	if ([searchIDObj unsignedLongValue] == currentSearchID) {
		[resultView setString:@""];
	}
}

// 結果を追加
- (void)addResultLine:(NSArray *)lineInfo {
	unsigned long searchID = [[lineInfo objectAtIndex:0] unsignedLongValue];
	if (currentSearchID == searchID) {
		NSString *line = [lineInfo objectAtIndex:1];
		unichar linkingChars[] = { 0x3c, 0x2192 };
		NSString *linkingPrefix = [NSString stringWithCharacters:linkingChars length:2];
		unichar endCharacter = 0x3e;
		NSString *linkingSuffix = [NSString stringWithCharacters:&endCharacter length:1];
		NSTextStorage *resultStorage = [resultView textStorage];
		while (YES) {
			// →を見つける
			NSRange linkingRange = [line rangeOfString:linkingPrefix];
			if (linkingRange.location == NSNotFound) {
				NSAttributedString *attrStr = [[NSAttributedString alloc] initWithString:line attributes:[applicationManager resultAttributes]];
				[resultStorage appendAttributedString:attrStr];
				[attrStr release];
				attrStr = [[NSAttributedString alloc] initWithString:@"\n" attributes:[applicationManager resultAttributes]];
				[resultStorage appendAttributedString:attrStr];
				[attrStr release];
				break;
			} else {
				NSAttributedString *attrStr = [[NSAttributedString alloc] initWithString:[line substringToIndex:linkingRange.location+2] attributes:[applicationManager resultAttributes]];
				[resultStorage appendAttributedString:attrStr];
				[attrStr release];
				NSString *rest = [line substringFromIndex:linkingRange.location+2];
				NSRange endRange = [rest rangeOfString:linkingSuffix];
				if (endRange.location == NSNotFound) {
					NSAttributedString *attrStr = [[NSAttributedString alloc] initWithString:rest attributes:[applicationManager resultAttributes]];
					[resultStorage appendAttributedString:attrStr];
					[attrStr release];
					attrStr = [[NSAttributedString alloc] initWithString:@"\n" attributes:[applicationManager resultAttributes]];
					[resultStorage appendAttributedString:attrStr];
					[attrStr release];
					break;
				} else {
					NSString *linkingWord = [rest substringToIndex:endRange.location];
					NSMutableDictionary *linkAttrDict =
						[NSMutableDictionary dictionaryWithDictionary:[applicationManager resultAttributes]];
					[linkAttrDict setObject:linkingWord forKey:NSLinkAttributeName];
					[linkAttrDict setObject:[NSCursor pointingHandCursor] forKey:NSCursorAttributeName];
					NSAttributedString *attrStr = [[NSAttributedString alloc] initWithString:linkingWord attributes:linkAttrDict];
					[resultStorage appendAttributedString:attrStr];
					[attrStr release];
					[[resultView window] resetCursorRects];
					line = [rest substringFromIndex:endRange.location];
				}
			}
		}
	}
}

// 見つからなかった場合のメッセージの追加
- (void)addNotFound:(NSArray *)searchInfo {
	NSNumber *searchIDObj = [searchInfo objectAtIndex:0];
	unsigned long searchID = [searchIDObj unsignedLongValue];
	if (currentSearchID == searchID) {
		NSString *searchStr = [searchInfo objectAtIndex:1];
		NSString *notFoundString = [NSString stringWithFormat:
			NSLocalizedString(@"SEARCH_NOTFOUND", @""), searchStr];
		NSTextStorage *resultStorage = [resultView textStorage];
		NSAttributedString *attrStr = [[NSAttributedString alloc] initWithString:notFoundString
																	  attributes:[applicationManager resultAttributes]];
		[resultStorage appendAttributedString:attrStr];
		[attrStr release];
		[self addGuessForSearchWord:searchStr searchID:searchID];
	}
}

// 修正候補の追加
- (void)addGuessForSearchWord:(NSString *)searchStr searchID:(unsigned long)searchID {
	if (![searchStr isEnglishWord]) {
		return;
	}
	NSTextStorage *resultStorage = [resultView textStorage];
	NSSpellChecker *spellChecker = [NSSpellChecker sharedSpellChecker];
	NSArray *guesses = [spellChecker guessesForWord:searchStr];
	unsigned int count = [guesses count];
	if (count > 0) {
		if (currentSearchID != searchID) {
			return;
		}
		NSAttributedString *attrStr = [[NSAttributedString alloc] initWithString:
							   NSLocalizedString(@"GUESS_TITLE", @"") attributes:[applicationManager resultAttributes]];
		[resultStorage appendAttributedString:attrStr];
		[attrStr release];
		for (int i = 0; i < count; i++) {
			if (currentSearchID != searchID) {
				return;
			}
			NSString *guess = [guesses objectAtIndex:i];
			attrStr = [[NSAttributedString alloc] initWithString:
				[NSString stringWithFormat:@"\t%d. ", i+1]
													  attributes:[applicationManager resultAttributes]];
			[resultStorage appendAttributedString:attrStr];
			[attrStr release];
			NSMutableDictionary *linkAttrDict =
				[NSMutableDictionary dictionaryWithDictionary:[applicationManager resultAttributes]];
			[linkAttrDict setObject:guess forKey:NSLinkAttributeName];
			attrStr = [[NSAttributedString alloc] initWithString:guess
													  attributes:linkAttrDict];
			[resultStorage appendAttributedString:attrStr];
			[attrStr release];
			attrStr = [[NSAttributedString alloc] initWithString:@"\n"
													  attributes:[applicationManager resultAttributes]];
			[resultStorage appendAttributedString:attrStr];
			[attrStr release];
		}
		[firstGuess release];
		firstGuess = nil;
		[secondGuess release];
		secondGuess = nil;
		firstGuess = [[guesses objectAtIndex:0] retain];
		if (count > 1) {
			secondGuess = [[guesses objectAtIndex:1] retain];
		}
		[[resultView window] resetCursorRects];
	} else {
		NSAttributedString *attrStr = [[NSAttributedString alloc] initWithString:
							NSLocalizedString(@"GUESS_NOTFOUND", @"") attributes:[applicationManager resultAttributes]];
		[resultStorage appendAttributedString:attrStr];
		[attrStr release];
	}
}

// 辞書間のセパレータの追加
- (void)addSeparator:(NSNumber *)searchIDObj {
	if ([searchIDObj unsignedLongValue] == currentSearchID) {
		NSTextStorage *resultStorage = [resultView textStorage];
		NSAttributedString *attrStr = [[NSAttributedString alloc] initWithString:@"========================\n" attributes:[applicationManager resultAttributes]];
		[resultStorage appendAttributedString:attrStr];
		[attrStr release];
	}
}

// スクロール位置復元のためのタイミング待ちメソッド
- (void)prepareScrolling:(NSNumber *)searchIDObj {
	// 何もしない
}

// 全文検索で対象が見つからなかった場合のメッセージを追加
- (void)addFullSearchNotFound:(NSNumber *)searchIDObj {
	if ([searchIDObj unsignedLongValue] == currentSearchID) {
		NSTextStorage *resultStorage = [resultView textStorage];
		NSAttributedString *attrStr = [[NSAttributedString alloc] initWithString:
	NSLocalizedString(@"FULLSEARCH_NOTFOUND", @"FULLSEARCH_NOTFOUND") attributes:[applicationManager resultAttributes]];
		[resultStorage appendAttributedString:attrStr];
		[attrStr release];
	}
}

// キャンセル文字列の追加
- (void)addFullSearchCanceledSeparator {
	NSTextStorage *resultStorage = [resultView textStorage];
	NSAttributedString *attrStr = [[NSAttributedString alloc] initWithString:
		NSLocalizedString(@"CANCELED_SEPARATOR", @"CANCELED_SEPARATOR") attributes:[applicationManager resultAttributes]];
	[resultStorage appendAttributedString:attrStr];
	[attrStr release];
}

// スクロール位置の復元
- (void)scrollToLastRect:(NSArray *)searchInfo {
	NSNumber *searchIDObj = [searchInfo objectAtIndex:0];
	unsigned long searchID = [searchIDObj unsignedLongValue];
	if (currentSearchID == searchID) {
		NSString *searchStr = [searchInfo objectAtIndex:1];
		[applicationManager scrollToLastRectForString:searchStr];
	}
}

// 進行状況のセット
- (void)setProgress:(NSArray *)progInfo {
	unsigned long searchID = [[progInfo objectAtIndex:0] unsignedLongValue];
	if (currentSearchID == searchID) {
		double progress = [[progInfo objectAtIndex:1] doubleValue];
		[searchField setDoubleValue:progress];
	}
}

// 指定された文字列を検索
- (void)searchString:(NSString *)searchStr {
	// 新しい検索IDを作成
	currentSearchID = [self createSearchID];
	NSNumber *searchIDObj = [NSNumber numberWithUnsignedLong:currentSearchID];
	// 空文字列であれば検索結果をクリアして終了
	if (!searchStr || [searchStr length] == 0) {
		[self clearResult:searchIDObj];
		return;
	}
	// 検索スレッドを作成
	NSArray *threadInfo = [[NSArray alloc] initWithObjects:
		searchStr, searchIDObj, nil];
	[NSThread detachNewThreadSelector:@selector(mainSearchProc:)
							 toTarget:self
						   withObject:threadInfo];
	[threadInfo release];
}

// 検索スレッド用のメソッド
- (void)mainSearchProc:(NSArray *)threadInfo {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	NSString *searchStr = [threadInfo objectAtIndex:0];
	NSNumber *searchIDObj = [threadInfo objectAtIndex:1];
	unsigned long searchID = [searchIDObj unsignedLongValue];

	// 結果ビューをクリア
	[self performSelectorOnMainThread:@selector(clearResult:)
						   withObject:searchIDObj
						waitUntilDone:YES];
	
	// 別の検索が始まっている
	if (searchID != currentSearchID) {
		return;
	}
	
	// Shift-JISの比較用のデータを作成
	NSData *searchStrData = [searchStr dataUsingEncoding:NSShiftJISStringEncoding];
	unsigned int searchStrDataLength = [searchStrData length];
	unsigned int cSearchStrLength = searchStrDataLength + 2;
	unsigned char *cSearchStr = malloc(cSearchStrLength);
	[searchStrData getBytes:cSearchStr+2 length:searchStrDataLength];
	cSearchStr[0] = 0x81;
	cSearchStr[1] = 0xa1;

	// 環境設定を取得
	id values = [[NSUserDefaultsController sharedUserDefaultsController] values];
	BOOL removeRubies = [[values valueForKey:@"removeRubies"] boolValue];

	// 開始
	int searchCount = 0;
	if (isEnglishWordC(cSearchStr+2, searchStrDataLength)) {
		// 略語郎を検索
		if (isCapitalWordC(cSearchStr+2, searchStrDataLength)) {
			NSString *ryakugoroPath = [values valueForKey:@"ryakugoroPath"];
			NSData *ryakugoroData = [NSData dataWithContentsOfMappedFile:ryakugoroPath];
			searchCount += [self searchForCString:cSearchStr
								 cSearchStrLength:cSearchStrLength
										   inData:ryakugoroData
									 removeRubies:removeRubies
									  searchIDObj:searchIDObj];
			// 別の検索が始まっている
			if (searchID != currentSearchID) {
				free(cSearchStr);
				return;
			}			
		}
		// 英辞郎を検索
		NSString *eijiroPath = [values valueForKey:@"eijiroPath"];
		NSData *eijiroData = [NSData dataWithContentsOfMappedFile:eijiroPath];
		searchCount += [self searchForCString:cSearchStr
							 cSearchStrLength:cSearchStrLength
									   inData:eijiroData
								 removeRubies:removeRubies
								  searchIDObj:searchIDObj];
	} else {
		// 日本語には和英辞郎のみを検索
		NSString *waeijiroPath = [values valueForKey:@"waeijiroPath"];
		NSData *waeijiroData = [NSData dataWithContentsOfMappedFile:waeijiroPath];
		searchCount += [self searchForCString:cSearchStr
							 cSearchStrLength:cSearchStrLength
									   inData:waeijiroData
								 removeRubies:removeRubies
								  searchIDObj:searchIDObj];
	}
	// クリーンアップ
	free(cSearchStr);
	// 見つからなかった
	if (searchCount == 0) {
		[self performSelectorOnMainThread:@selector(addNotFound:)
							   withObject:[NSArray arrayWithObjects:searchIDObj, searchStr, nil]
							waitUntilDone:NO];
	}
	// メインスレッドで検索結果がすべてビューに追加されるのを待つ
	[self performSelectorOnMainThread:@selector(prepareScrolling:)
						   withObject:searchIDObj
						waitUntilDone:YES];
	// 以前のスクロール位置を復元する
	[self performSelectorOnMainThread:@selector(scrollToLastRect:)
						   withObject:[NSArray arrayWithObjects:searchIDObj, searchStr, nil]
						waitUntilDone:NO];
	
	[pool release];
}

// バイナリサーチの実装
- (int)searchForCString:(unsigned char *)cSearchStr
	   cSearchStrLength:(unsigned int)cSearchStrLength
				 inData:(NSData *)data
		   removeRubies:(BOOL)removeRubies
			searchIDObj:(NSNumber *)searchIDObj
{
	unsigned char *p = (unsigned char *) [data bytes];
	int dataLength = [data length];
	
	int startPos = 0;
	int endPos = dataLength - 1;
	int middlePos = 0;
	
	unsigned long searchID = [searchIDObj unsignedLongValue];

	while (startPos < endPos) {
		// 次の検索が始まっている
		if (searchID != currentSearchID) {
			return 0;
		}
		// 中央を計算する
		middlePos = startPos + (endPos - startPos) / 2;
		// 改行が見つかるか開始点に辿り着くまで逆戻り
		while (middlePos > startPos &&
			   (p[middlePos-1] != 0x0a && p[middlePos-1] != 0x0d ||
				p[middlePos] == 0x0a || p[middlePos] == 0x0d)) {
			middlePos--;
		}
		// 比較する
		int comparisonResult = mystrncmp(p+middlePos, cSearchStr, cSearchStrLength, YES);
		if (comparisonResult == 0) {
			// 検索文字列が見つかった。
			// middlePosが先頭のインデクスを保持している。
			break;
		} else if (comparisonResult < 0) {
			// 現在のインデクスよりも後ろの部分にしか検索文字列は存在しない
			startPos = middlePos;
			// その行の最後までインデクスを送る
			while (startPos < endPos && p[startPos] != 0x0a && p[startPos] != 0x0d) {
				if (isFirst2BytesCharacter(p[startPos])) {
					startPos++;
				}
				startPos++;
			}
			while (p[startPos] == 0x0a || p[startPos] == 0x0d) {
				startPos++;
			}
		} else {
			// 現在のインデクスよりも前の部分にしか検索文字列は存在しない
			endPos = middlePos - 1;
		}
	}
	
	// 見つからなかった
	if (startPos >= endPos) {
		return 0;
	}
	
	// 同じレベルの文字列を上方向に検索し、startPosをそのレベルの文字列が
	// 最初に現れる行の先頭のインデクス値とする。
	startPos = middlePos - 1;
	while (startPos > 0) {
		// 次の検索が始まっている
		if (searchID != currentSearchID) {
			return 0;
		}
		// 改行が見つかるかデータのゼロ地点に辿り着くまで逆戻り
		while (startPos > 0 &&
			   (p[startPos-1] != 0x0a && p[startPos-1] != 0x0d ||
				p[startPos] == 0x0a || p[startPos] == 0x0d))
		{
			startPos--;
		}
		// 比較する
		int comparisonResult = mystrncmp(p+startPos, cSearchStr, cSearchStrLength, YES);
		if (comparisonResult == 0) {
			middlePos = startPos;
			startPos = middlePos - 1;
		} else {
			break;
		}
	}
	startPos = middlePos;
	endPos = startPos + 1;
	
	// データを追加していく
	int addCount = 0;
	NSMutableString *addBuffer = [NSMutableString string];
	while (endPos < dataLength-1) {
		// 次の検索が始まっている
		if (searchID != currentSearchID) {
			return addCount;
		}
		// 行末を見つける
		while (endPos < dataLength-1 && p[endPos] != 0x0a && p[endPos] != 0x0d) {
			endPos++;
		}
		// 結果を追加
		NSData *resultData = [data subdataWithRange:NSMakeRange(middlePos, endPos-middlePos+1)];
		NSString *addStr = [[[NSString alloc] initWithData:resultData encoding:NSShiftJISStringEncoding] autorelease];
		if (removeRubies) {
			addStr = [addStr stringByRemovingRubies];
		}
		addStr = [addStr pronunciationSymbolFixedString];
		addStr = [addStr ver80FixedString];
		[addBuffer appendString:addStr];
		addCount++;
		if (addCount % 6 == 0) {
			[self performSelectorOnMainThread:@selector(addResultLine:)
								   withObject:[NSArray arrayWithObjects:searchIDObj, addBuffer, nil]
								waitUntilDone:NO];
			addBuffer = [NSMutableString string];
		}
		// 最大検索数を超えたら終了
		if (addCount > 60) {
			break;
		}
		// 次へ
		while (endPos < dataLength-1 && (p[endPos] == 0x0a || p[endPos] == 0x0d)) {
			endPos++;
		}
		// 次の検索が始まっている
		if (searchID != currentSearchID) {
			return addCount;
		}
		int comparisonResult = mystrncmp(p+endPos, cSearchStr, cSearchStrLength, YES);
		if (comparisonResult != 0) {
			break;
		}
		middlePos = endPos;
		endPos++;
	}
	// 次の検索が始まっている
	if (searchID != currentSearchID) {
		return addCount;
	}
	// 最後のバッファを吐き出し
	if ([addBuffer length] > 0) {
		[self performSelectorOnMainThread:@selector(addResultLine:)
							   withObject:[NSArray arrayWithObjects:searchIDObj, addBuffer, nil]
							waitUntilDone:NO];
	}
	// セパレータの追加
	if (addCount > 0) {
		[self performSelectorOnMainThread:@selector(addSeparator:)
							   withObject:searchIDObj
							waitUntilDone:NO];
	}
	return addCount;
}	

// 検索の中断
- (void)stopSearching {
	currentSearchID = [self createSearchID];
	NSNumber *searchIDObj = [NSNumber numberWithUnsignedLong:currentSearchID];
	NSArray *progInfo = [[NSArray alloc] initWithObjects:
		searchIDObj, [NSNumber numberWithDouble:0], nil];
	[self performSelectorOnMainThread:@selector(setProgress:)
						   withObject:progInfo
						waitUntilDone:NO];
	[progInfo release];
	[self performSelectorOnMainThread:@selector(addFullSearchCanceledSeparator)
						   withObject:nil
						waitUntilDone:NO];		
}

// 第1修正候補をリターンする
- (NSString *)firstGuess {
	return firstGuess;
}

// 第2修正候補をリターンする
- (NSString *)secondGuess {
	return secondGuess;
}

@end
