//
//  NMSpeechManager.m
//  EIJIRO Viewer
//
//  Created by numata on September 30, 2002.
//  Copyright 2002-2004 Satoshi NUMATA. All rights reserved.
//

#import "NMSpeechManager.h"


//
//  英文テキスト読み上げ機能をサポートするためのクラス。
//

@implementation NMSpeechManager

// 初期化
// stopMode には、kImmediate、kEndOfWord、kEndOfSentenceのいずれかを指定する
- (id)initWithStopMode:(long)stopMode_
		target:(id)target_
		speakingStartedMethod:(SEL)speakingStartedMethod_
		speakingPosChangedMethod:(SEL)speakingPosChangedMethod_
		speakingDoneMethod:(SEL)speakingDoneMethod_
		errorOccuredMethod:(SEL)errorOccuredMethod_;
{
	self = [super init];
	if (self) {
		stopMode = stopMode_;
		target = target_;
		speakingStartedMethod = speakingStartedMethod_;
		speakingPosChangedMethod = speakingPosChangedMethod_;
		speakingDoneMethod = speakingDoneMethod_;
		errorOccuredMethod = errorOccuredMethod_;
		speechChannel = NULL;
		if (![self createSpeechChannel]) {
			[self dealloc];
			return nil;
		}
	}
	return self;
}

// クリーンアップ
- (void)dealloc {
	if (isSpeaking) {
		[self stopSpeaking];
	}
	if (speechChannel) {
		DisposeSpeechChannel(speechChannel);
    }
	[super dealloc];
}

// スピーチチャンネルの生成
- (BOOL)createSpeechChannel {
    OSErr error;

	// スピーチチャンネルの生成
	error = NewSpeechChannel(NULL, &speechChannel);
	if (error != noErr) {
		[self setError:error pos:-1];
		return NO;
	}
    
	// コールバック関数からこのクラスにアクセスするために、RefCon にこのクラスのポインタを設定しておく
	error = SetSpeechInfo(speechChannel, soRefCon, (Ptr) self);
	if (error != noErr) {
		return NO;
	}

	// 以下、各種コールバックのセット
	error = SetSpeechInfo(speechChannel, soSpeechDoneCallBack, SpeechDoneCallBackProc);
	if (error != noErr) {
		return NO;
	}
	error = SetSpeechInfo(speechChannel, soTextDoneCallBack, TextDoneCallBackProc);
	if (error != noErr) {
		return NO;
	}
	error = SetSpeechInfo(speechChannel, soWordCallBack, WordCallBackProc);
	if (error != noErr) {
		return NO;
	}
	error = SetSpeechInfo(speechChannel, soErrorCallBack, ErrorCallBackProc);
	if (error != noErr) {
		return NO;
	}

    return YES;
}

// テキスト読み上げの開始
- (void)speakText:(NSString *)text {
	OSErr error;
	NSString *speakableText;

	// 読み上げ中であれば停止してから再生を行う
	if (isSpeaking) {
		[self stopSpeaking];
	}

	// 読み上げができる文字のみに変換する
	speakableText = [self convertToSpeakableText:text];

	// 読み上げ開始
	error = SpeakText(
			speechChannel, [speakableText cString], [speakableText cStringLength]);
	if (error != noErr) {
		[self setError:error pos:0];
	} else {
		[self setSpeaking:YES];
	}
}

// 読み上げの停止
- (void)stopSpeaking {
	OSErr error;

	if (!isSpeaking) {
		return;
	}

	error = StopSpeechAt(speechChannel, stopMode);
	if (error != noErr) {
		[self setError:error pos:0];
	} else {
		[self setSpeaking:NO];
	}
}

// 与えられたテキストを、読み上げ可能なテキストに変換する
- (NSString *)convertToSpeakableText:(NSString *)text {
	NSString *modifiedText;
	unichar *fromBuffer = malloc(sizeof(unichar) * [text length]);
	unichar *toBuffer = malloc(sizeof(unichar) * [text length]);
	unichar c[5];
	BOOL pass = NO;
	BOOL pronunciation = NO;
	BOOL level = NO;
	[text getCharacters:fromBuffer];
	unsigned int length = [text length];
	for (unsigned int i = 0; i < length; i++) {
		// 「{}」と「【】」の間の文字は読み飛ばす
		if (!pass && (fromBuffer[i] == 0x7b || fromBuffer[i] == 0x3010)) {
			pass = YES;
			// 読み上げられない文字は、「/」に変換するとスキップされる
			toBuffer[i] = 0x2f;
			// 発音記号も読み飛ばす
			if (i + 3 < [text length]) {
				c[0] = fromBuffer[i];
				c[1] = fromBuffer[i+1];
				c[2] = fromBuffer[i+2];
				c[3] = fromBuffer[i+3];
				if (c[0] == 0x3010 && c[1] == 0x767a && c[2] == 0x97f3 && c[3] == 0x3011) {
					pronunciation = YES;
				} else if (i + 4 < [text length]) {
					c[4] = fromBuffer[i+4];
					if (c[0] == 0x3010 && c[1] == 0x767a && c[2] == 0x97f3 &&
							c[3] == 0xff01 && c[4] == 0x3011) {
						pronunciation = YES;
					} else if (c[0] == 0x3010 && c[1] == 0x30ec && c[2] == 0x30d9 &&
							c[3] == 0x30eb && c[4] == 0x3011) {
						level = YES;
					}
				}
			}
		} else if (pass) {
			toBuffer[i] = 0x2f;
			if (!pronunciation && !level && (fromBuffer[i] == 0x7d || fromBuffer[i] == 0x3011)) {
				pass = NO;
			} else if (pronunciation && fromBuffer[i] == 0x3001) {
				pronunciation = NO;
				pass = NO;
			} else if (level &&
					(fromBuffer[i] == 0x3001 || fromBuffer[i] == 0x0d || fromBuffer[i] == 0x0a)) {
				level = NO;
				pass = NO;
			}
		}
		// 日本語は読めない
		else if (fromBuffer[i] > 0x7e) {
			// 読み上げられない文字は、「/」に変換するとスキップされる
			toBuffer[i] = 0x2f;
		}
		// 「/」は区切り文字として使われている。「;」に変換して区切りを読ませる
		else if (fromBuffer[i] == 0x2f) {
			toBuffer[i] = 0x3b;
		}
		// 読める文字
		else {
			toBuffer[i] = fromBuffer[i];
		}
	}
	modifiedText = [NSString stringWithCharacters:toBuffer length:[text length]];
	free(fromBuffer);
	free(toBuffer);
	return modifiedText;
}

// 読み上げの開始/終了時にフラグをセットし、コールバックのセレクタをトリガする
- (void)setSpeaking:(BOOL)flag {
	isSpeaking = flag;
	if (isSpeaking) {
		if (target && speakingStartedMethod) {
			[target performSelector:speakingStartedMethod withObject:self];
		}
	} else {
		if (target && speakingDoneMethod) {
			[target performSelector:speakingDoneMethod withObject:self];
		}
	}
}

// これから読み上げる場所をcurrentPosにセットして、コールバックのセレクタをトリガする
- (void)setCurrentSpeakingPos:(int)pos length:(int)length {
	currentPos = pos;
	currentLength = length;
	if (target && speakingPosChangedMethod) {
		[target performSelector:speakingPosChangedMethod withObject:self];
	}
}

// lastError変数にエラー番号をセットし、エラーが起こった場所をcurrentPosにセットして、
// エラー専用のコールバックのセレクタをトリガする
- (void)setError:(OSErr)error pos:(int)pos {
	lastError = error;
	currentPos = pos;
	[self setSpeaking:NO];
	if (target && errorOccuredMethod) {
		[target performSelector:errorOccuredMethod withObject:self];
	}
}

// 読み上げ中かどうか
- (BOOL)isSpeaking {
	return isSpeaking;
}

// カレントの読み上げ位置
- (int)currentPos {
	return currentPos;
}

// カレントの読み上げ文字列の長さ
- (int)currentLength {
	return currentLength;
}

// エラー番号
- (OSErr)lastError {
	return lastError;
}

@end


///// 以下、各種コールバックルーチン

// カレントの単語が処理されたときにコールされる。
// 追加のテキストを渡して処理を継続させることもできる。
pascal void TextDoneCallBackProc(
		SpeechChannel inSpeechChannel, long inRefCon,
		const void **nextBuf, unsigned long *byteLen, long *controlFlags)
{
	*nextBuf = NULL;
}

// 単語を生成しようとする毎に、新しい位置と長さを引数に入れてコールされる。
pascal void WordCallBackProc(
	SpeechChannel inSpeechChannel, long inRefCon, long inWordPos, short inWordLen)
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NMSpeechManager *speechManager = (NMSpeechManager *) inRefCon;
	[speechManager setCurrentSpeakingPos:inWordPos length:inWordLen];
	[pool release];
}

// すべての読み上げが完了したときにコールされる
pascal void SpeechDoneCallBackProc(SpeechChannel inSpeechChannel, long inRefCon)
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NMSpeechManager *speechManager = (NMSpeechManager *) inRefCon;
	[speechManager setSpeaking:NO];
	[pool release];
}

// テキスト読み上げ中にエラーが起こった場合にコールされる
pascal void ErrorCallBackProc(
	SpeechChannel inSpeechChannel, long inRefCon, OSErr inError, long inBytePos)
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NMSpeechManager *speechManager = (NMSpeechManager *) inRefCon;
	[speechManager setError:inError pos:inBytePos];
	[pool release];
}



