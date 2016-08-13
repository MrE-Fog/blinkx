////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016 Blink Mobile Shell Project
//
// This file is part of Blink.
//
// Blink is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Blink is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Blink. If not, see <http://www.gnu.org/licenses/>.
//
// In addition, Blink is also subject to certain additional terms under
// GNU GPL version 3 section 7.
//
// You should have received a copy of these additional terms immediately
// following the terms and conditions of the GNU General Public License
// which accompanied the Blink Source Code. If not, see
// <http://www.github.com/blinksh/blink>.
//
////////////////////////////////////////////////////////////////////////////////

#include <stdio.h>
#include <string.h>

#include "linenoise.h"

#import "MCPSession.h"
#import "MoshSession.h"
#import "PKCard.h"
#import "SSHCopyIDSession.h"
#import "SSHSession.h"

#define MCP_MAX_LINE 4096

@implementation MCPSession {
  Session *childSession;
}

- (NSArray *)splitCommandAndArgs:(NSString *)cmdline
{
  NSRange rng = [cmdline rangeOfString:@" "];
  if (rng.location == NSNotFound) {
    return @[ cmdline, @"" ];
  } else {
    return @[
      [cmdline substringToIndex:rng.location],
      [cmdline substringFromIndex:rng.location + 1]
    ];
  }
}

- (void)setTitle
{
  fprintf(_stream.control.termout, "\033]0;blink\007");
}

- (int)main:(int)argc argv:(char **)argv
{
  char *line;
  argc = 0;
  argv = nil;

  NSString *docsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
  NSString *filePath = [docsPath stringByAppendingPathComponent:@"history.txt"];

  const char *history = [filePath UTF8String];

  linenoiseHistoryLoad(history);

  while ((line = [self linenoise:"blink> "]) != nil) {
    if (line[0] != '\0' && line[0] != '/') {
      linenoiseHistoryAdd(line);
      linenoiseHistorySave(history);

      NSString *cmdline = [[NSString alloc] initWithFormat:@"%s", line];
      NSArray *arr = [self splitCommandAndArgs:cmdline];
      NSString *cmd = arr[0];

      if ([cmd isEqualToString:@"help"]) {
	[self showHelp];
      } else if ([cmd isEqualToString:@"mosh"]) {
	// At some point the parser will be in the JS, and the call will, through JSON, will include what is needed.
	// Probably passing a Server struct of some type.

	[self runMoshWithArgs:cmdline];
      } // else if ([cmd isEqualToString:@"ssh"]) {
      //   // At some point the parser will be in the JS, and the call will, through JSON, will include what is needed.
      //	// Probably passing a Server struct of some type.

      //   [self runSSHWithArgs:cmdline];
      // }
      else if ([cmd isEqualToString:@"exit"]) {
	break;
      } else if ([cmd isEqualToString:@"ssh-copy-id"]) {
	[self runSSHCopyIDWithArgs:cmdline];
      } else if ([cmd isEqualToString:@"config"]) {
	[self showConfig];
      } else {
	[self out:"Unknown command. Type 'help' for a list of available operations"];
      }
    }

    [self setTitle]; // Temporary, until the apps restore the right state.

    free(line);
  }

  [self out:"Bye!"];

  return 0;
}

- (void)showConfig
{
  UIStoryboard *sb = [UIStoryboard storyboardWithName:@"Settings" bundle:nil];
  UINavigationController *vc = [sb instantiateViewControllerWithIdentifier:@"NavSettingsController"];
  dispatch_sync(dispatch_get_main_queue(), ^{
    [_stream.control presentViewController:vc animated:YES completion:NULL];
  });
}

- (void)runSSHCopyIDWithArgs:(NSString *)args
{
  childSession = [[SSHCopyIDSession alloc] initWithStream:_stream];
  [childSession executeAttachedWithArgs:args];
  childSession = nil;
}

- (void)runMoshWithArgs:(NSString *)args
{
  childSession = [[MoshSession alloc] initWithStream:_stream];
  [childSession executeAttachedWithArgs:args];
  childSession = nil;
}

- (void)runSSHWithArgs:(NSString *)args
{
  childSession = [[SSHSession alloc] initWithStream:_stream];
  [childSession executeAttachedWithArgs:args];
  childSession = nil;
}

- (NSString *)shortVersionString
{
  NSString *compileDate = [NSString stringWithUTF8String:__DATE__];
  
  NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
  NSString *appDisplayName = [infoDictionary objectForKey:@"CFBundleName"];
  NSString *majorVersion = [infoDictionary objectForKey:@"CFBundleShortVersionString"];
  NSString *minorVersion = [infoDictionary objectForKey:@"CFBundleVersion"];
  
  return [NSString stringWithFormat:@"%@: v%@.%@. %@",
          appDisplayName, majorVersion, minorVersion, compileDate];
}

- (void)showHelp
{
  NSString *help = [@[
    @"",
    [self shortVersionString],
    @"",
    @"Available commands:",
    @"  mosh: Start a mosh session.",
    //  @"  ssh: Send a command through ssh.",
    @"  ssh-copy-id: Copy an identity to the server.",
    @"  help: Prints this.",
    @"  exit: Close this window.",
    @"",
    @"Available gestures:",
    @"  two fingers tap: New window.",
    @"  two fingers swipe down: Close window.",
    @"  one finger swipe left/right: Switch between windows.",
    @"  pinch: Change font size.",
    @""
  ] componentsJoinedByString:@"\r\n"];
    
  [self out:help.UTF8String];
}

- (void)out:(const char *)str
{
  fprintf(_stream.out, "%s\r\n", str);
}

- (char *)linenoise:(char *)prompt
{
  char buf[MCP_MAX_LINE];
  if (_stream.in == NULL) {
    return nil;
  }

  int count = linenoiseEdit(fileno(_stream.in), _stream.out, buf, MCP_MAX_LINE, prompt, _stream.sz);
  if (count == -1) {
    return nil;
  }

  return strdup(buf);
}

- (void)sigwinch
{
  if (childSession != nil) {
    [childSession sigwinch];
  }
}

- (void)kill
{
  if (childSession != nil) {
    [childSession kill];
  }

  // Close stdin to end the linenoise loop.
  if (_stream.in) {
    fclose(_stream.in);
    _stream.in = NULL;
  }
}

@end
