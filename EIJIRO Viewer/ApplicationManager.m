//
//  ApplicationManager.m
//  EIJIRO Viewer
//
//  Created by numata on November 11, 2004.
//  Copyright 2004 Satoshi NUMATA. All rights reserved.
//

#import "ApplicationManager.h"

#import "NMTextField.h"
#import "NMFontTransformer.h"
#import "SearchManager.h"


//
//  ApplicationManagerで内部的に使用するメソッド
//

@interface ApplicationManager (Internal)

// 与えられたパスを元に、設定されていない辞書データのパスを補完する
- (void)setUnsetPathsWithPath:(NSString *)path;

// 移動コントロールのアクティベート
- (void)activateMoveControl;

@end


//
//  ユーザインタフェースを管理し、入力処理の振り分けなどを行うクラス
//

@implementation ApplicationManager

// 初回起動時にウィンドウを中央に移動させるためのフラグ
static BOOL isFirstRun;

// バインディングの初期値設定
+ (void)initialize {
	// フォント情報表示のためのトランスフォーマの登録
	[NSValueTransformer setValueTransformer:[[[NMFontTransformer alloc] init] autorelease]
									forName:@"NMFontTransformer"];
	
	// 環境設定初期値の設定
    NSDictionary *initialValues =
		[NSDictionary dictionaryWithObjectsAndKeys:
			// ルビの除去（基本的に鬱陶しいだろうからONをデフォルトにする）
			[NSNumber numberWithBool:YES], @"removeRubies",
			// 全文検索の対象
			[NSNumber numberWithBool:YES], @"fullSearchEijiro",
			[NSNumber numberWithBool:YES], @"fullSearchRyakugoro",
			[NSNumber numberWithBool:YES], @"fullSearchWaijiro",
			[NSNumber numberWithBool:YES], @"fullSearchReijiro",
			// デフォルトフォント
			@"HiraKakuPro-W3,12.000000", @"font",
			nil];
    NSUserDefaultsController *defaultsController =
        [NSUserDefaultsController sharedUserDefaultsController];
    [defaultsController setInitialValues:initialValues];

	// 初回起動時かどうかを判定する
	isFirstRun = ([[NSUserDefaults standardUserDefaults] boolForKey:@"NSWindow Frame EIJIRO Viewer"] == nil);
}

// 初期化
- (void)awakeFromNib {
	// 読み上げマネージャの初期化
	speechManager = [[NMSpeechManager alloc] initWithStopMode:kImmediate
													   target:self
										speakingStartedMethod:@selector(speakingStarted)
									 speakingPosChangedMethod:@selector(speakingPosChanged:)
										   speakingDoneMethod:@selector(speakingDone)
										   errorOccuredMethod:@selector(speakingErrorOccured:)];
	
	// 結果表示用辞書とキャッシュフォントの作成
	NSString *fontDesc = [[[NSUserDefaultsController sharedUserDefaultsController] defaults]
		valueForKey:@"font"];
	if (fontDesc) {
		int commaPos = [fontDesc rangeOfString:@","].location;
		if (commaPos != NSNotFound) {
			NSString *fontName = [fontDesc substringToIndex:commaPos];
			float fontSize = [[fontDesc substringFromIndex:commaPos+1] floatValue];
			if (fontSize == 0.0) {
				fontSize = 12.0;
			}
			font = [NSFont fontWithName:fontName size:fontSize];
		}
	}
	if (!font) {
		font = [NSFont fontWithName:@"HiraKakuPro-W3" size:12.0];
	}
	resultAttributes = [[NSMutableDictionary dictionary] retain];
	[resultAttributes setObject:font forKey:NSFontAttributeName];
	
	// スクロール場所保存用変数の初期化
	visibleRectDict = [[NSMutableDictionary dictionary] retain];

	// ヒストリ用変数の初期化
	searchWordList = [[NSMutableArray array] retain];
	historyPos = 0;

	// ヒストリ確定に関するフラグの初期化
	isWordJustFixed = NO;
	wasFullSearch = NO;
	
	// 移動コントロールの初期化
	[[moveControl cell] setTrackingMode:NSSegmentSwitchTrackingMomentary];
	[moveControl setSegmentCount:2];
    [moveControl setImage:[NSImage imageNamed:@"back"] forSegment:0];
    [moveControl setImage:[NSImage imageNamed:@"forward"] forSegment:1];
	[moveControl setEnabled:NO forSegment:0];
	[moveControl setEnabled:NO forSegment:1];
	[moveControl setAction:@selector(moveControlPressed:)];
	[moveControl setTarget:self];

	// ツールバーをセット
	NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier:@"EIJIRO Viewer"];
	[toolbar setAllowsUserCustomization:YES];
	[toolbar setAutosavesConfiguration:YES];
	[toolbar setDelegate:self];
	[mainWindow setToolbar:toolbar];
	
	// 初回起動時はメインウィンドウを中央に移動して、ツールバーの表示モードをアイコンのみに設定
	if (isFirstRun) {
		[toolbar setDisplayMode:NSToolbarDisplayModeIconOnly];
		[mainWindow center];
	}
	
	// メインウィンドウの表示
	[mainWindow makeKeyAndOrderFront:self];
	[mainWindow makeFirstResponder:searchField];
}

// クリーンアップ
- (void)dealloc {
	[resultAttributes release];
	[visibleRectDict release];
	[searchWordList release];
	[speechManager release];
	[super dealloc];
}

// 全文検索シートの表示
- (IBAction)fullSearch:(id)sender {
	[[[NSUserDefaultsController sharedUserDefaultsController] values]
			setValue:@"" forKey:@"fullSearchNotification"];
	// 検索フィールドの文字列を検索対象にする
	[fullSearchField setStringValue:[searchField stringValue]];
	// シートの表示
	[NSApp beginSheet:fullSearchWindow
	   modalForWindow:mainWindow
		modalDelegate:self
	   didEndSelector:@selector(fullSearchSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:nil];
}

// 全文検索シートの処理
- (void)fullSearchSheetDidEnd:(NSWindow *)sheet
				   returnCode:(int)returnCode
				  contextInfo:(void *)contextInfo
{
	// シートを隠す
	[fullSearchWindow orderOut:self];
	// 開始が選択された場合
	if (returnCode == 0) {
		// 現在の文字列を確定
		[self fixCurrentSearchString];
		// ヒストリ参照時に全文検索を反映させないためにフラグを立てておく
		wasFullSearch = YES;
		// 全文検索の開始
		[searchManager doFullSearchForString:[fullSearchField stringValue]];
	}
}

// 全文検索シートで開始が選択された場合
- (IBAction)startFullSearch:(id)sender {
	if ([[fullSearchField stringValue] length] == 0) {
		[[[NSUserDefaultsController sharedUserDefaultsController] values]
			setValue:NSLocalizedString(@"FullSearchNoTarget", @"") forKey:@"fullSearchNotification"];
		NSBeep();
		return;
	}
	id values = [[NSUserDefaultsController sharedUserDefaultsController] values];
	BOOL searchEijiro = [[values valueForKey:@"fullSearchEijiro"] boolValue];
	BOOL searchRyakugoro = [[values valueForKey:@"fullSearchRyakugoro"] boolValue];
	BOOL searchWaeijiro = [[values valueForKey:@"fullSearchWaeijiro"] boolValue];
	BOOL searchReijiro = [[values valueForKey:@"fullSearchReijiro"] boolValue];
	if (!searchEijiro && !searchRyakugoro && !searchWaeijiro && !searchReijiro) {
		[[[NSUserDefaultsController sharedUserDefaultsController] values]
			setValue:NSLocalizedString(@"FullSearchNoDictionary", @"") forKey:@"fullSearchNotification"];
		NSBeep();
		return;
	}
	[NSApp endSheet:fullSearchWindow returnCode:0];
}

// 全文検索シートでキャンセルが選択された場合
- (IBAction)cancelFullSearch:(id)sender {
	[NSApp endSheet:fullSearchWindow returnCode:1];
}

// 環境設定パネルを表示
- (IBAction)showPreferences:(id)sender {
	[preferencesWindow center];
	[preferencesWindow makeKeyAndOrderFront:self];
}

// すべての辞書データのパスをクリア
- (IBAction)clearDictionaryPaths:(id)sender {
	id values = [[NSUserDefaultsController sharedUserDefaultsController] values];
	[values setValue:@"" forKey:@"eijiroPath"];
	[values setValue:@"" forKey:@"ryakugoroPath"];
	[values setValue:@"" forKey:@"waeijiroPath"];
	[values setValue:@"" forKey:@"reijiroPath"];
}

// 英辞郎データのパスを指定
- (IBAction)referEijiroPath:(id)sender {
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	int ret = [openPanel runModalForTypes:[NSArray arrayWithObject:@"txt"]];
	if (ret == NSOKButton) {
		NSString *filePath = [openPanel filename];
		[[[NSUserDefaultsController sharedUserDefaultsController] values]
			setValue:filePath forKey:@"eijiroPath"];
		[self setUnsetPathsWithPath:filePath];
	}
}

// 例辞郎データのパスを指定
- (IBAction)referReijiroPath:(id)sender {
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	int ret = [openPanel runModalForTypes:[NSArray arrayWithObject:@"txt"]];
	if (ret == NSOKButton) {
		NSString *filePath = [openPanel filename];
		[[[NSUserDefaultsController sharedUserDefaultsController] values]
			setValue:filePath forKey:@"reijiroPath"];
		[self setUnsetPathsWithPath:filePath];
	}
}

// 略語郎データのパスを指定
- (IBAction)referRyakugoroPath:(id)sender {
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	int ret = [openPanel runModalForTypes:[NSArray arrayWithObject:@"txt"]];
	if (ret == NSOKButton) {
		NSString *filePath = [openPanel filename];
		[[[NSUserDefaultsController sharedUserDefaultsController] values]
			setValue:filePath forKey:@"ryakugoroPath"];
		[self setUnsetPathsWithPath:filePath];
	}
}

// 和英辞郎データのパスを指定
- (IBAction)referWaeijiroPath:(id)sender {
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	int ret = [openPanel runModalForTypes:[NSArray arrayWithObject:@"txt"]];
	if (ret == NSOKButton) {
		NSString *filePath = [openPanel filename];
		[[[NSUserDefaultsController sharedUserDefaultsController] values]
			setValue:filePath forKey:@"waeijiroPath"];
		[self setUnsetPathsWithPath:filePath];
	}
}

// 与えられたパスを元に、設定されていない辞書データのパスを補完する
- (void)setUnsetPathsWithPath:(NSString *)aPath {
	id values = [[NSUserDefaultsController sharedUserDefaultsController] values];
	NSString *eijiroPath = [values valueForKey:@"eijiroPath"];
	NSString *ryakugoroPath = [values valueForKey:@"ryakugoroPath"];
	NSString *waeijiroPath = [values valueForKey:@"waeijiroPath"];
	NSString *reijiroPath = [values valueForKey:@"reijiroPath"];
	
	NSString *basePath = [aPath stringByDeletingLastPathComponent];
	NSString *versionStr =
		[[aPath stringByDeletingPathExtension] substringFromIndex:[aPath length]-6];
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	if (!eijiroPath || [eijiroPath length] == 0) {
		eijiroPath = [basePath stringByAppendingPathComponent:
			[NSString stringWithFormat:@"EIJIRO%@.TXT", versionStr]];
		if ([fileManager fileExistsAtPath:eijiroPath]) {
			[values setValue:eijiroPath forKey:@"waeijiroPath"];
		}
	}
	if (!ryakugoroPath || [ryakugoroPath length] == 0) {
		ryakugoroPath = [basePath stringByAppendingPathComponent:
			[NSString stringWithFormat:@"RYAKU%@.TXT", versionStr]];
		if ([fileManager fileExistsAtPath:ryakugoroPath]) {
			[values setValue:ryakugoroPath forKey:@"ryakugoroPath"];
		}
	}
	if (!waeijiroPath || [waeijiroPath length] == 0) {
		waeijiroPath = [basePath stringByAppendingPathComponent:
			[NSString stringWithFormat:@"WAEIJI%@.TXT", versionStr]];
		if ([fileManager fileExistsAtPath:waeijiroPath]) {
			[values setValue:waeijiroPath forKey:@"waeijiroPath"];
		}
	}
	if (!reijiroPath || [reijiroPath length] == 0) {
		reijiroPath = [basePath stringByAppendingPathComponent:
			[NSString stringWithFormat:@"REIJI%@.TXT", versionStr]];
		if ([fileManager fileExistsAtPath:reijiroPath]) {
			[values setValue:reijiroPath forKey:@"reijiroPath"];
		}
	}
}

// フォント選択パネルを表示する
- (IBAction)selectFont:(id)sender {
	NSFontManager *fontManager = [NSFontManager sharedFontManager];
	[fontManager setSelectedFont:font isMultiple:NO];
	[fontManager setDelegate:self];
	[fontManager orderFrontFontPanel:self];
}

// フォントが変更されたときに呼び出されるメソッド
- (void)changeFont:(id)sender {
	font = [sender convertFont:font];
	[resultAttributes setObject:font forKey:NSFontAttributeName];
	NSTextStorage *resultStorage = [resultView textStorage];
	[resultStorage setAttributes:resultAttributes range:NSMakeRange(0, [resultStorage length])];
	[[[NSUserDefaultsController sharedUserDefaultsController] defaults]
		setValue:[NSString stringWithFormat:@"%@,%f", [font fontName], [font pointSize]]
		  forKey:@"font"];
}

// ツールバー項目を取得するためにコールされるメソッド
- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar
	 itemForItemIdentifier:(NSString *)itemIdentifier
 willBeInsertedIntoToolbar:(BOOL)flag
{
	NSToolbarItem *item = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
	
	[item setLabel:NSLocalizedString(itemIdentifier, itemIdentifier)];
	[item setPaletteLabel:NSLocalizedString(itemIdentifier, itemIdentifier)];
	
	// 移動コントロール
	if ([itemIdentifier isEqualToString:@"TBI Move"]) {
		[item setView:moveView];
		NSSize viewSize = [moveView bounds].size;
		[item setMinSize:viewSize];
		[item setMaxSize:viewSize];
	}
	// 発音ボタン
	else if ([itemIdentifier isEqualToString:@"TBI Pronounce"]) {
		[item setView:pronounceView];
		NSSize viewSize = [pronounceView bounds].size;
		[item setMinSize:viewSize];
		[item setMaxSize:viewSize];
	}
	// 全文検索ボタン
	else if ([itemIdentifier isEqualToString:@"TBI FullSearch"]) {
		[item setView:fullSearchView];
		NSSize viewSize = [fullSearchView bounds].size;
		[item setMinSize:viewSize];
		[item setMaxSize:viewSize];
	}
	// 検索フィールド
	else if ([itemIdentifier isEqualToString:@"TBI Search"]) {
		[item setView:searchView];
		float viewHeight = [searchView bounds].size.height;
		[item setMinSize:NSMakeSize(40, viewHeight)];
		[item setMaxSize:NSMakeSize(400, viewHeight)];
	}
	return item;
}

// 使用可能なツールバー項目
- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
	return [NSArray arrayWithObjects:
		@"TBI Move",
		@"TBI Pronounce",
		@"TBI Search",
		@"TBI FullSearch",
		NSToolbarSeparatorItemIdentifier,
		NSToolbarSpaceItemIdentifier,
		NSToolbarFlexibleSpaceItemIdentifier,
		NSToolbarCustomizeToolbarItemIdentifier,
		NSToolbarPrintItemIdentifier,
		nil];
}

// デフォルトのツールバー項目
- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
	return [NSArray arrayWithObjects:
		@"TBI Move",
		NSToolbarSeparatorItemIdentifier,
		@"TBI Pronounce",
		@"TBI Search",
		nil];
}

// 検索フィールドの専用エディタをリターンする
- (id)windowWillReturnFieldEditor:(NSWindow *)sender toObject:(id)anObject {
	if (anObject == searchField) {
		return [(NMTextField *) searchField fieldEditor];
	}
	return nil;
}

// アプリケーションがアクティブになったときに検索フィールドにフォーカスを合わせる
- (void)applicationDidBecomeActive:(NSNotification *)aNotification {
	[mainWindow makeFirstResponder:searchField];
}

// アプリケーションが非アクティブになるときに文字列を確定する
- (void)applicationDidResignActive:(NSNotification *)aNotification {
	[self fixCurrentSearchString];
}

// ApplicationManager と SearchManager をメインスレッドの辞書に登録して、
// 外部から参照できるようにする。
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	// メインスレッドの辞書にApplicationManagerとSearchManagerを登録して、
	// 外部から参照できるようにする
	NSMutableDictionary *threadDict = [[NSThread currentThread] threadDictionary];
	[threadDict setValue:self forKey:@"ApplicationManager"];
	[threadDict setValue:searchManager forKey:@"SearchManager"];

	// このオブジェクトをサービス機能のプロバイダとして登録する
	[NSApp setServicesProvider:self];
	
	// 辞書データのパスが設定されていなければ環境設定パネルを表示
 	id values = [[NSUserDefaultsController sharedUserDefaultsController] values];
	NSString *eijiroPath = [values valueForKey:@"eijiroPath"];
	NSString *ryakugoroPath = [values valueForKey:@"ryakugoroPath"];
	NSString *waeijiroPath = [values valueForKey:@"waeijiroPath"];
	NSString *reijiroPath = [values valueForKey:@"reijiroPath"];
	if (!eijiroPath && !ryakugoroPath && !waeijiroPath && !reijiroPath) {
		[self showPreferences:self];
	}
}

// 最後のウィンドウが閉じられたら終了する
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication {
	return YES;
}

// メインウィンドウが閉じられたら終了する
- (void)windowWillClose:(NSNotification *)aNotification {
	// 環境設定ウィンドウのdelegateは指定していないので、
	// このメソッドはメインウィンドウからのみ呼び出される。
	[NSApp terminate:self];
}

// 検索結果表示のための属性を指定した辞書をリターンする
- (NSDictionary *)resultAttributes {
	return resultAttributes;
}

// 読み上げ開始時にコールバックされる
- (void)speakingStarted {
	[pronounceButton setState:NSOnState];
}

// 読み上げ位置の変化時にコールバックされる
- (void)speakingPosChanged:(id)sender {
	// 読み上げ対象の単語を選択する
	NSRange currentRange = NSMakeRange([speechManager currentPos] + speechStartPos,
									   [speechManager currentLength]);
	[speakingView scrollRangeToVisible:currentRange];
	[speakingView setSelectedRange:currentRange];
	[speakingView display];
}

// 読み上げ終了時にコールバックされる
- (void)speakingDone {
	// 読み上げボタンをOFFにする
	[pronounceButton setState:NSOffState];
	// 読み上げ対象のビューの選択範囲を元に戻す
	[speakingView setSelectedRange:selectionRange];
}

// 読み上げ中にエラーが起きたときにコールバックされる
- (void)speakingErrorOccured:(id)sender {
	NSRunAlertPanel(@"Speech Error",
					[NSString stringWithFormat:@"Error %d occurred.", [speechManager lastError]],
					@"OK", nil, nil);
}

// 結果表示ビューの特殊キーの横取り
- (BOOL)textView:(NSTextView *)aTextView
                    doCommandBySelector:(SEL)aSelector
{
	// ESCキーで検索（全文検索のみ）を中断
	if (aSelector == @selector(cancel:)) {
		[searchManager stopSearching];
		return YES;
	}
	// タブキーで検索フィールドにフォーカスを移動させる
	else if (aSelector == @selector(insertTab:)) {
		[mainWindow makeFirstResponder:searchField];
		return YES;
	}
	// リターンキーで検索フィールドにフォーカスを移動させる
	else if (aSelector == @selector(insertNewline:)) {
		[mainWindow makeFirstResponder:searchField];
		return YES;
	}
	// Cmd+左で前に移動
	else if (aSelector == @selector(moveToBeginningOfLine:)) {
		[self searchPrevious:self];
		return YES;
	}
	// Cmd+右で次に移動
	else if (aSelector == @selector(moveToEndOfLine:)) {
		[self searchNext:self];
		return YES;
	}
	return NO;
}

// 検索文字フィールドの特殊キーの横取り
- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command {
	// ESCキーで検索（全文検索のみ）を中断
	if (command == @selector(cancel:)) {
		[searchManager stopSearching];
		return YES;
	}
	// タブキーでフォーカスを結果表示ビューに移動する
	else if (command == @selector(insertTab:)) {
		// ヒストリ追加を確定
		[self fixCurrentSearchString];
		// フォーカスを結果表示ビューに移動
		[mainWindow makeFirstResponder:resultView];
		return YES;
	}
	// スクロールホームを結果表示ビューに伝える
	else if (command == @selector(scrollToBeginningOfDocument:)) {
		[resultView doCommandBySelector:@selector(scrollToBeginningOfDocument:)];
		return YES;
	}
	// スクロールエンドを結果表示ビューに伝える
	else if (command == @selector(scrollToEndOfDocument:)) {
		[resultView doCommandBySelector:@selector(scrollToEndOfDocument:)];
		return YES;
	}
	// スクロールダウンを結果表示ビューに伝える
	else if (command == @selector(scrollPageDown:)) {
		[resultView doCommandBySelector:@selector(scrollPageDown:)];
		return YES;
	}
	// スクロールアップを結果表示ビューに伝える
	else if (command == @selector(scrollPageUp:)) {
		[resultView doCommandBySelector:@selector(scrollPageUp:)];
		return YES;
	}
	// Cmd+左で次に移動
	else if (command == @selector(moveToBeginningOfLine:)) {
		[self searchPrevious:self];
		return YES;
	}
	// Cmd+右で次に移動
	else if (command == @selector(moveToEndOfLine:)) {
		[self searchNext:self];
		return YES;
	}
	return NO;
}

// 一般的な検索語の入力はここに渡される。
// リターンキー入力時にはfixSearchString:アクションがコールされる。
- (void)controlTextDidChange:(NSNotification *)aNotification {
	wasFullSearch = NO;
	// ヒストリを参照している場合には、現在位置以降を削除する
	if (historyPos > 0) {
		[searchWordList removeObjectsInRange:NSMakeRange([searchWordList count]-historyPos, historyPos)];
		historyPos = 0;
	}
	// ヒストリ追加確定直後であれば直前の単語のスクロール位置を保存
	if (isWordJustFixed) {
		if ([searchWordList count] > 0) {
			NSString *lastSearchWord = [searchWordList lastObject];
			[visibleRectDict setValue:NSStringFromRect([resultView visibleRect]) forKey:lastSearchWord];
		}
		isWordJustFixed = NO;
	}
	// 移動コントロールのアクティベート
	[self activateMoveControl];
	// 読み上げ中であれば中断
	if ([speechManager isSpeaking]) {
		[speechManager stopSpeaking];
		selectionRange = NSMakeRange(0, 0);
		[resultView setSelectedRange:selectionRange];
	}
	// 読み上げボタンのアクティベート
	[self activatePronounceButton];
	// カレントの検索ワードのスクロール位置情報をクリア
	NSString *searchStr = [searchField stringValue];
	[visibleRectDict removeObjectForKey:searchStr];
	// 検索
	[searchManager searchString:searchStr];
}

// 検索文字のヒストリ追加を確定して、検索フィールドを全選択する
- (IBAction)fixSearchString:(id)sender {
	[self fixCurrentSearchString];
	[mainWindow makeFirstResponder:searchField];
}

// 検索文字列のヒストリ追加を確定する
- (void)fixCurrentSearchString {
	// ヒストリ参照中であれば何もしない
	if (historyPos > 0) {
		return;
	}
	// ヒストリの最後と一致しない場合にはヒストリを追加
	NSString *searchString = [searchField stringValue];
	if (searchString && [searchString length] > 0 &&
		[searchString compare:[searchWordList lastObject]] != NSOrderedSame)
	{
		[searchWordList addObject:searchString];
	}
	// スクロール位置保存用にヒストリを確定したフラグを立てる
	isWordJustFixed = YES;
	// 移動コントロールのアクティベート
	[self activateMoveControl];
}

// 移動コントロールのアクティベート
- (void)activateMoveControl {
	NSString *searchString = [searchField stringValue];
	unsigned int historyCount = [searchWordList count];
	if (historyPos == 0 && [searchString length] > 0 &&
		![searchString isEqualToString:[searchWordList lastObject]])
	{
		historyCount++;
	}
	[moveControl setEnabled:(historyCount > 1 && historyPos < historyCount-1) forSegment:0];
	[moveControl setEnabled:(historyPos > 0) forSegment:1];
}

// 移動コントロールが押されたときにコールされる
- (IBAction)moveControlPressed:(id)sender {
	if ([moveControl selectedSegment] == 0) {
		[self searchPrevious:self];
	} else {
		[self searchNext:self];
	}
}

// 前を検索
- (IBAction)searchPrevious:(id)sender {
	// 移動できることを確認
	unsigned int historyCount = [searchWordList count];
	NSString *searchString = [searchField stringValue];
	if (historyPos == 0 && [searchString length] > 0 &&
		![searchString isEqualToString:[searchWordList lastObject]])
	{
		historyCount++;
	}
	if (historyCount <= 1 || historyPos >= historyCount-1) {
		NSBeep();
		return;
	}
	// 現在のスクロール位置を保存
	[visibleRectDict setValue:NSStringFromRect([resultView visibleRect]) forKey:[searchField stringValue]];
	// カレントの検索文字列を確定
	if (historyPos == 0) {
		if (wasFullSearch) {
			[searchField setStringValue:[searchWordList lastObject]];
			[mainWindow makeFirstResponder:searchField];
			[searchManager searchString:[searchField stringValue]];
			wasFullSearch = NO;
			return;
		} else {
			[self fixCurrentSearchString];
		}
	}
	// 移動する
	wasFullSearch = NO;
	historyPos++;
	[searchField setStringValue:[searchWordList objectAtIndex:[searchWordList count]-1-historyPos]];
	[mainWindow makeFirstResponder:searchField];
	// 移動コントロールのアクティベート
	[self activateMoveControl];
	// 検索
	[searchManager searchString:[searchField stringValue]];
}

// 次を検索
- (IBAction)searchNext:(id)sender {
	// 移動できることを確認
	if (historyPos == 0) {
		NSBeep();
		return;
	}
	// 現在のスクロール位置を保存
	[visibleRectDict setValue:NSStringFromRect([resultView visibleRect]) forKey:[searchField stringValue]];
	// 移動する
	wasFullSearch = NO;
	historyPos--;
	[searchField setStringValue:[searchWordList objectAtIndex:[searchWordList count]-1-historyPos]];
	[mainWindow makeFirstResponder:searchField];
	// 移動コントロールのアクティベート
	[self activateMoveControl];
	// 検索
	[searchManager searchString:[searchField stringValue]];
}

// リンクがクリックされたときに呼び出されるメソッド
- (BOOL)textView:(NSTextView *)textView
   clickedOnLink:(id)link
		 atIndex:(unsigned)charIndex
{
	// 現在のスクロール位置を保存
	[visibleRectDict setValue:NSStringFromRect([resultView visibleRect]) forKey:[searchField stringValue]];
	// ヒストリを参照している場合には、現在位置以降を削除する
	[self clearSubsequentHistory];
	// 現在の文字列（修正対象になっているもの）を確定
	[self fixCurrentSearchString];
	// 修正文字列で検索フィールドを置き換え
	[searchField setStringValue:link];
	// 修正した文字列を確定
	[self fixCurrentSearchString];
	[mainWindow makeFirstResponder:searchField];
	// 検索
	[searchManager searchString:[searchField stringValue]];
	return YES;
}

// 与えられた文字列を最後に参照したときのスクロール位置に戻す
- (void)scrollToLastRectForString:(NSString *)searchWord {
	if (!searchWord) {
		return;
	}
	NSString *rectStr = [visibleRectDict valueForKey:searchWord];
	if (!rectStr) {
		return;
	}
	[resultView scrollRectToVisible:NSRectFromString(rectStr)];
}

// 読み上げを開始/停止する
- (IBAction)pronounce:(id)sender {
	if ([speechManager isSpeaking]) {
		[self stopSpeaking:self];
	} else {
		[self startSpeaking:self];
	}
}

// 読み上げを開始する
- (IBAction)startSpeaking:(id)sender {
	// 読み上げ中であれば一旦中止する
	if ([speechManager isSpeaking]) {
		[self stopSpeaking:self];
	}
	// 検索フィールドにフォーカスがあれば検索フィールドを、そうでなければ結果ビューを読み上げ対象にする
	BOOL searchWordFieldFocused = [[searchField window] firstResponder] == [searchField currentEditor];
	speakingView = searchWordFieldFocused?
		((NSTextView *) [searchField currentEditor]): resultView;
	if (!speakingView) {
		return;
	}
	// 現在の選択範囲を記憶しておく
	selectionRange = [speakingView selectedRange];
	NSString *targetText;
	if (selectionRange.length == 0) {
		targetText = [speakingView string];
		speechStartPos = 0;
	} else {
		targetText = [[speakingView string] substringWithRange:selectionRange];
		speechStartPos = selectionRange.location;
	}
	// 読み上げ対象の長さをチェック
	if ([targetText length] == 0) {
		return;
	}
	// 開始
	[speechManager speakText:targetText];
}

// 読み上げの中止
- (IBAction)stopSpeaking:(id)sender {
	if ([speechManager isSpeaking]) {
		[speechManager stopSpeaking];
		[resultView setSelectedRange:selectionRange];
	}
	[pronounceButton setState:NSOffState];
}

// 第1修正候補を選択する
- (IBAction)searchFirstGuess:(id)sender {
	wasFullSearch = NO;
	// ヒストリを参照している場合には、現在位置以降を削除する
	[self clearSubsequentHistory];
	// 現在の入力文字列を確定
	[self fixCurrentSearchString];
	// 修正候補を反映させる
	NSString *firstGuess = [searchManager firstGuess];
	[searchField setStringValue:firstGuess];
	// 修正した文字列を確定
	[self fixCurrentSearchString];
	// 検索フィールドを全選択
	[mainWindow makeFirstResponder:searchField];
	// 検索
	[searchManager searchString:firstGuess];
}

// 第2修正候補を選択する
- (IBAction)searchSecondGuess:(id)sender {
	wasFullSearch = NO;
	// ヒストリを参照している場合には、現在位置以降を削除する
	[self clearSubsequentHistory];
	// 現在の入力文字列を確定
	[self fixCurrentSearchString];
	// 修正候補を反映させる
	NSString *secondGuess = [searchManager secondGuess];
	[searchField setStringValue:secondGuess];
	// 修正した文字列を確定
	[self fixCurrentSearchString];
	// 検索フィールドを全選択
	[mainWindow makeFirstResponder:searchField];
	// 検索
	[searchManager searchString:secondGuess];
}

// 現在の位置以降のヒストリを削除する
- (void)clearSubsequentHistory {
	if (historyPos > 0) {
		[searchWordList removeObjectsInRange:NSMakeRange([searchWordList count]-historyPos, historyPos)];
		historyPos = 0;
	}
}

// メニュー項目のアクティベート
- (BOOL)validateMenuItem:(id <NSMenuItem>)menuItem {
	switch ([menuItem tag]) {
		// 「前に戻る」
		case 50: {
			unsigned int historyCount = [searchWordList count];
			NSString *searchString = [searchField stringValue];
			if (historyPos == 0 && [searchString length] > 0 &&
					![searchString isEqualToString:[searchWordList lastObject]])
			{
				historyCount++;
			}
			return (historyCount > 1 && historyPos < historyCount-1);
		}
		// 「次に進む」
		case 51:
			return (historyPos > 0);
		// 「最初の修正候補」
		case 52:
			return ([searchManager firstGuess] != nil);
		// 「次の修正候補」
		case 53:
			return ([searchManager secondGuess] != nil);
	}
	return YES;
}

// 文字列の検索を行う
- (IBAction)performFindPanelAction:(id)sender {
	[mainWindow makeFirstResponder:resultView];
	[resultView performFindPanelAction:sender];
}

// 選択範囲にジャンプ
- (IBAction)centerSelectionInVisibleArea:(id)sender {
	[mainWindow makeFirstResponder:resultView];
	[resultView centerSelectionInVisibleArea:sender];
}

// サービス機能からの検索
- (void)searchStringForService:(NSPasteboard *)pboard
					  userData:(NSString *)userData
						 error:(NSString **)error
{
	// ペーストボードから文字列が取得できることを確認する
	if (![[pboard types] containsObject:NSStringPboardType]) {
		*error = @"Error: couldn't get text.";
		return;
	}

	// 検索文字列を取得
	NSString *pboardString = [pboard stringForType:NSStringPboardType];
	if (!pboardString) {
		*error = @"Error: couldn't get text.";
		return;
	}
	
	// 検索フィールドに検索文字列をセット
	[searchField setStringValue:pboardString];
	
	// アプリケーションをアクティブにする
	[NSApp activateIgnoringOtherApps:YES];
	
	// 検索文字列を確定
	[self fixSearchString:self];
	
	// 読み上げボタンのアクティベート
	[self activatePronounceButton];
	
	// 検索
	[searchManager searchString:pboardString];
}

// 読み上げボタンのアクティベート
- (void)activatePronounceButton {
	if ([[searchField stringValue] length] == 0) {
		[pronounceButton setEnabled:NO];
	} else {
		[pronounceButton setEnabled:YES];
	}
}

@end
