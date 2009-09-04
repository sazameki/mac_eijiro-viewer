//
//  SearchManager.h
//  EIJIRO Viewer
//
//  Created by numata on November 11, 2004.
//  Copyright 2004 Satoshi NUMATA. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "NMTextField.h"


@class ApplicationManager;


//
//  英辞郎辞書の検索を行うクラス。
//

@interface SearchManager : NSObject {
	
	// アウトレット
    IBOutlet NSWindow		*mainWindow;	// メインウィンドウ
    IBOutlet NMTextField	*searchField;	// 検索フィールド
    IBOutlet NSTextView		*resultView;	// 結果表示ビュー
	IBOutlet ApplicationManager	*applicationManager;	// UIマネージャ
	
	// カレントの検索ID
	volatile unsigned long currentSearchID;
	
	// 修正候補
	NSString *firstGuess;
	NSString *secondGuess;
}

// 通常検索の開始
- (void)searchString:(NSString *)searchStr;

// 全文検索の開始
- (void)doFullSearchForString:(NSString *)searchStr;

// 検索の中断
- (void)stopSearching;

// 修正候補
- (NSString *)firstGuess;
- (NSString *)secondGuess;

@end


