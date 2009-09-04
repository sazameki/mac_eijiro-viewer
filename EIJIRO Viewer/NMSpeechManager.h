//
//  SpeechManager.h
//  CocoaSpeechExample
//
//  Created by numata on September 30, 2002.
//  Copyright 2002-2004 Satoshi NUMATA. All rights reserved.

#import <Cocoa/Cocoa.h>


//
//  英文テキスト読み上げ機能をサポートするためのクラス。
//

@interface NMSpeechManager : NSObject {
	// 読み上げ機能をサポートするためのメンバ
    SpeechChannel	speechChannel;
	long			stopMode;

	// 各種状態
	BOOL	isSpeaking;
	int		currentPos;
	int		currentLength;
	OSErr	lastError;

	// コールバックのためのセレクタとターゲット
	id	target;
	SEL	speakingStartedMethod;
	SEL	speakingPosChangedMethod;
	SEL	speakingDoneMethod;
	SEL	errorOccuredMethod;
}

// 初期化メソッド
- (id)initWithStopMode:(long)stopMode_
	target:(id)target
	speakingStartedMethod:(SEL)speakingStartedMethod_
	speakingPosChangedMethod:(SEL)speakingPosChangedMethod_
	speakingDoneMethod:(SEL)speakingDoneMethod_
	errorOccuredMethod:(SEL)errorOccuredMethod_;
- (BOOL)createSpeechChannel;

// 読み上げの開始と終了メソッド
- (void)speakText:(NSString *)text;
- (void)stopSpeaking;

// 読み上げユーティリティ
- (NSString *)convertToSpeakableText:(NSString *)text;

// 各種状態の変更メソッド
- (void)setSpeaking:(BOOL)flag;
- (void)setCurrentSpeakingPos:(int)pos length:(int)length;
- (void)setError:(OSErr)error pos:(int)pos;

// 各種状態の取得メソッド
- (BOOL)isSpeaking;
- (int)currentPos;
- (int)currentLength;
- (OSErr)lastError;

@end


// コールバック関数のプロトタイプ
pascal void ErrorCallBackProc(
	SpeechChannel inSpeechChannel, long inRefCon, OSErr inError, long inBytePos);

pascal void TextDoneCallBackProc(
	SpeechChannel inSpeechChannel, long inRefCon,
	const void **nextBuf, unsigned long *byteLen, long *controlFlags);

pascal void SpeechDoneCallBackProc (SpeechChannel inSpeechChannel, long inRefCon);

pascal void WordCallBackProc(
	SpeechChannel inSpeechChannel, long inRefCon, long inWordPos, short inWordLen);

