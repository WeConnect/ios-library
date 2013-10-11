/*
 Copyright 2009-2013 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "UAAction+Operators.h"
#import "UAAction+Internal.h"
#import "UAGlobal.h"

@implementation UAAction (Operators)

- (UAAction *)continueWith:(UAAction *)continuationAction {
    UAAction *aggregateAction = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler){

        [self runWithArguments:args withCompletionHandler:^(UAActionResult *selfResult){

            if (!selfResult.error && continuationAction) {
                UAActionArguments *continuationArgs = [UAActionArguments argumentsWithValue:selfResult.value
                                                                              withSituation:args.situation];
                continuationArgs.name = args.name;

                [continuationAction runWithArguments:continuationArgs withCompletionHandler:^(UAActionResult *continuationResult){
                    completionHandler(continuationResult);
                }];
            } else {
                //Todo: different log level?
                UA_LINFO(@"%@", selfResult.error.localizedDescription);
                completionHandler(selfResult);
            }
        }];
    }];

    aggregateAction.acceptsArgumentsBlock = ^(UAActionArguments *args) {
        return [self acceptsArguments:args];
    };

    return aggregateAction;
}

- (UAAction *)filter:(UAActionPredicate)filterBlock {
    UAAction *aggregateAction = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler){
        [self runWithArguments:args withCompletionHandler:completionHandler];
    }];

    aggregateAction.acceptsArgumentsBlock = ^(UAActionArguments *args) {
        if (filterBlock && !filterBlock(args)) {
            return NO;
        }
        return [self acceptsArguments:args];
    };

    return aggregateAction;
}

- (UAAction *)map:(UAActionMapArgumentsBlock)mapArgumentsBlock {
    UAAction *aggregateAction = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler handler){
        if (mapArgumentsBlock) {
            [self runWithArguments:mapArgumentsBlock(args) withCompletionHandler:handler];
        } else {
            [self runWithArguments:args withCompletionHandler:handler];
        }
    }];

    aggregateAction.acceptsArgumentsBlock = ^(UAActionArguments *args) {
        if (mapArgumentsBlock) {
            return [self acceptsArguments:mapArgumentsBlock(args)];
        } else {
            return [self acceptsArguments:args];
        }
    };

    return aggregateAction;
}

- (UAAction *)preExecution:(UAActionPreExecutionBlock)preExecutionBlock {
    UAAction *aggregateAction = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler){
        if (preExecutionBlock) {
            preExecutionBlock(args);
        }
        [self runWithArguments:args withCompletionHandler:completionHandler];
    }];

    aggregateAction.acceptsArgumentsBlock = ^(UAActionArguments *args) {
        return [self acceptsArguments:args];
    };

    return aggregateAction;
}

- (UAAction *)postExecution:(UAActionPostExecutionBlock)postExecutionBlock {
    UAAction *aggregateAction = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler){
        [self runWithArguments:args withCompletionHandler:^(UAActionResult *result){
            if (postExecutionBlock){
                postExecutionBlock(args, result);
            };
            completionHandler(result);
        }];
    }];

    aggregateAction.acceptsArgumentsBlock = ^(UAActionArguments *args) {
        return [self acceptsArguments:args];
    };

    return aggregateAction;
}

- (UAAction *)take:(NSUInteger)n {
    __block NSUInteger count = 0;

    UAAction *aggregateAction = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler){
        [self runWithArguments:args withCompletionHandler:completionHandler];
    }];

    aggregateAction.acceptsArgumentsBlock = ^(UAActionArguments *arguments){
        BOOL accepts = [self acceptsArguments:arguments];
        accepts = accepts && count <= n;
        return accepts;
    };

    aggregateAction.onRunBlock = ^{
        count++;
    };

    return aggregateAction;
}

- (UAAction *)skip:(NSUInteger)n {
    __block NSUInteger count = 0;

    UAAction *aggregateAction = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler){
        [self runWithArguments:args withCompletionHandler:completionHandler];
    }];

    aggregateAction.acceptsArgumentsBlock = ^(UAActionArguments *arguments){
        BOOL accepts = [self acceptsArguments:arguments];
        accepts = accepts && count > n;
        return accepts;
    };

    aggregateAction.onRunBlock = ^{
        count++;
    };

    return aggregateAction;
}

- (UAAction *)nth:(NSUInteger)n {
    if (n == 0) {
        // Never run
        return [self take:0];
    }
    return [[self take:1] skip:n-1];
}

- (UAAction *)distinctUntilChanged {
    __block id lastValue = nil;

    UAAction *aggregateAction = [[self preExecution:^(UAActionArguments *args){
        lastValue = args.value;
    }] filter:^(UAActionArguments *args){
        return (BOOL)![args.value isEqual:lastValue];
    }];
    
    return aggregateAction;
}

@end