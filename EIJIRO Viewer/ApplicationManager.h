//
//  ApplicationManager.h
//  EIJIRO Viewer
//
//  Created by numata on November 11, 2004.
//  Copyright 2004 Satoshi NUMATA. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "NMSpeechManager.h"


@class SearchManager;


//
//  ユーザインタフェースを管理し、入力処理の振り分けなどを行うクラス
//

@interface ApplicationManager : NSObject {

	// アウトレット
    IBOutlet NSWindow		*mainWindow;		// メインウィンドウ
	IBOutlet NSWindow		*preferencesWindow;	// 環境設定ウィンドウ
    IBOutlet NSWindow		*fullSearchWindow;	// 全文検索ウィンドウ
	IBOutlet NSTextField	*searchField;		// 検索フィールド
	IBOutlet NSTextField	*fullSearchField;	// 全文検索の単語フィールド
    IBOutlet NSTextView		*resultView;		// 結果表示ビュー
    IBOutlet NSButton		*pronounceButton;	// 発音ボタン
    IBOutlet SearchManager	*searchManager;		// 検索マネージャ
    IBOutlet NSSegmentedControl	*moveControl;	// 移動コントロール
	
	// ツールバー用のアウトレット
    IBOutlet NSView			*moveView;			// 移動コントロールのビュー
    IBOutlet NSView			*searchView;		// 検索フィールドのビュー
    IBOutlet NSView			*pronounceView;		// 発音ボタンのビュー
    IBOutlet NSView			*fullSearchView;	// 発音ボタンのビュー
	
	// 結果表示用フォントのキャッシュ
	NSFont				*font;				// フォント
	NSMutableDictionary	*resultAttributes;	// フォント指定を含んだ辞書
	
	// ヒストリ機能のサポート
	NSMutableArray		*searchWordList;	// ヒストリリスト
	unsigned int		historyPos;			// どこまでヒストリを遡ったか）
	NSMutableDictionary	*visibleRectDict;	// スクロール位置の保存

	// ヒストリ確定に関するフラグ
	BOOL isWordJustFixed;	// リターンキー、タブキー、非アクティブ化によって
							// ヒストリが確定した直後であることを示すフラグ
	BOOL wasFullSearch;	// ヒストリ参照時に全文検索を反映させないためのフラグ
	
	// 読み上げのサポート
	NMSpeechManager	*speechManager;		// 管理クラス
	NSTextView		*speakingView;		// カレントの読み上げ対象ビュー
	NSRange			selectionRange;		// 読み上げ前の選択範囲
	unsigned int	speechStartPos;		// 読み上げ開始点
}

// 検索パネル表示管理のためのアクション
- (IBAction)performFindPanelAction:(id)sender;
- (IBAction)centerSelectionInVisibleArea:(id)sender;

// 全文検索のためのアクション
- (IBAction)fullSearch:(id)sender;
- (IBAction)startFullSearch:(id)sender;
- (IBAction)cancelFullSearch:(id)sender;

// ヒストリ機能のためのアクション
- (IBAction)searchPrevious:(id)sender;
- (IBAction)searchNext:(id)sender;

- (IBAction)fixSearchString:(id)sender;	// カレントの検索文字列を確定してフォーカスを検索フィールドに

// 修正候補選択のためのアクション
- (IBAction)searchFirstGuess:(id)sender;
- (IBAction)searchSecondGuess:(id)sender;

// 読み上げのためのアクション
- (IBAction)pronounce:(id)sender;
- (IBAction)startSpeaking:(id)sender;
- (IBAction)stopSpeaking:(id)sender;

// 環境設定アクション
- (IBAction)showPreferences:(id)sender;

- (IBAction)referEijiroPath:(id)sender;
- (IBAction)referReijiroPath:(id)sender;
- (IBAction)referRyakugoroPath:(id)sender;
- (IBAction)referWaeijiroPath:(id)sender;
- (IBAction)clearDictionaryPaths:(id)sender;

- (IBAction)selectFont:(id)sender;

// 結果表示フォントの指定を含んだ辞書をリターンする
- (NSDictionary *)resultAttributes;

// スクロール位置を復元する
- (void)scrollToLastRectForString:(NSString *)searchWord;

// 読み上げボタンのアクティベート
- (void)activatePronounceButton;

// ヒストリ機能のためのメソッド
- (void)clearSubsequentHistory;	// カレント以降のヒストリを削除
- (void)fixCurrentSearchString;	// カレントの検索文字列を確定する

@end
