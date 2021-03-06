#include-once
#include <Array.au3>
#include <FileConstants.au3>
#include <GUIConstantsEx.au3>
#include <GuiEdit.au3>
#include <StringConstants.au3>
#include <WindowsConstants.au3>

#AutoIt3Wrapper_Au3Check_Parameters=-q -d -w 1 -w 2 -w 3 -w- 4 -w 5 -w 6 -w- 7

; #INDEX# =======================================================================================================================
; Title ............: TheDcoder's IRC UDF.
; AutoIt Version ...: 3.3.14.1
; Description ......: IRC UDF. Full compliance with RFC 2812 IRCv3.
; Author(s) ........: Damon Harris (TheDcoder)
; Special Thanks....: Robert C. Maehl (rcmaehl) for making his version of IRC UDF which taught me the basics of TCP and IRC :)
; Link .............: https://github.com/TheDcoder/IRC-UDF-for-AutoIt/
; Important Links ..: IRCv3                    - http://ircv3.net
;                     RFC 2812                 - https://tools.ietf.org/html/rfc2812
;                     List of all IRC Numerics - http://defs.ircdocs.horse/defs/numerics.html
;                     Formatting text in IRC   - http://en.wikichip.org/wiki/irc/colors
;                     CTCP Specs               - https://github.com/irchelp/wio/blob/gh-pages/irchelp/protocol/ctcpspec.md
; ===============================================================================================================================

; #CURRENT# =====================================================================================================================
; _IRC_AuthPlainSASL
; _IRC_CapRequire
; _IRC_CapEnd
; _IRC_Connect
; _IRC_Disconnect
; _IRC_FormatMessage
; _IRC_FormatPrivMsg
; _IRC_FormatText
; _IRC_Invite
; _IRC_IsChannel
; _IRC_JoinChannel
; _IRC_Kick
; _IRC_MakeMessage
; _IRC_MakePalette
; _IRC_Part
; _IRC_Pong
; _IRC_Quit
; _IRC_ReceiveRaw
; _IRC_SendCTCP
; _IRC_SendCTCPReply
; _IRC_SendMessage
; _IRC_SendNotice
; _IRC_SendRaw
; _IRC_SetMode
; _IRC_SetNick
; _IRC_SetUser
; _IRC_WaitForNextMsg
; ===============================================================================================================================

; #INTERNAL_USE_ONLY# ===========================================================================================================
; <None>
; ===============================================================================================================================

; #CONSTANTS# ===================================================================================================================
Global Enum $IRC_MSGFORMAT_PREFIX, $IRC_MSGFORMAT_COMMAND
Global Enum $IRC_PRIVMSG_SENDER, $IRC_PRIVMSG_SENDER_USERSTRING, $IRC_PRIVMSG_SENDER_HOSTMASK, $IRC_PRIVMSG_RECEIVER, $IRC_PRIVMSG_MSG, $IRC_PRIVMSG_REPLYTO

Global Const $IRC_MODE_ADD = '+'
Global Const $IRC_MODE_REMOVE = '-'

Global Const $IRC_TRAILING_PARAMETER_INDICATOR = ':'
Global Const $IRC_MESSAGE_SEGMENT_SEPARATOR = ' '
Global Const $IRC_CTCP_DELIMITER = ChrW(001)

Global Const $IRC_FORMATTING_CHAR_BOLD = ChrW(0x02)
Global Const $IRC_FORMATTING_CHAR_ITALIC = ChrW(0x1D)
Global Const $IRC_FORMATTING_CHAR_UNDERLINE = ChrW(0x1F)
Global Const $IRC_FORMATTING_CHAR_REVERSE = ChrW(0x16)
Global Const $IRC_FORMATTING_CHAR_PLAIN = ChrW(0x0F)
Global Const $IRC_FORMATTING_CHAR_COLOR = ChrW(0x03)

; Below are constants for colors in IRC, Check the "Color Formatting" section in this page for more details: http://en.wikichip.org/wiki/irc/colors
Global Const $IRC_COLOR_PLAIN = -1 ; Special Constant, indicates that there would be no change in color.
Global Const $IRC_COLOR_WHITE = 0
Global Const $IRC_COLOR_BLACK = 1
Global Const $IRC_COLOR_NAVY = 2
Global Const $IRC_COLOR_GREEN = 3
Global Const $IRC_COLOR_RED = 4
Global Const $IRC_COLOR_MAROON = 5
Global Const $IRC_COLOR_PURPLE = 6
Global Const $IRC_COLOR_OLIVE = 7
Global Const $IRC_COLOR_YELLOW = 8
Global Const $IRC_COLOR_LIGHTGREEN = 9
Global Const $IRC_COLOR_TEAL = 10
Global Const $IRC_COLOR_CYAN = 11
Global Const $IRC_COLOR_ROYALBLUE = 12
Global Const $IRC_COLOR_MAGENTA = 13
Global Const $IRC_COLOR_GRAY = 14
Global Const $IRC_COLOR_LIGHTGRAY = 15

Global Enum $IRC_COLOR_PALETTE_FOREGROUND, $IRC_COLOR_PALETTE_BACKGROUND, $IRC_COLOR_PALETTE_BOLD, $IRC_COLOR_PALETTE_ITALIC, $IRC_COLOR_PALETTE_UNDERLINE

; Constants for commands in IRC
Global Const $IRC_COMMAND_MESSAGE = "PRIVMSG"
Global Const $IRC_COMMAND_NOTICE = "NOTICE"
Global Const $IRC_COMMAND_PASSWORD = "PASS"
Global Const $IRC_COMMAND_NICKNAME = "NICK"
Global Const $IRC_COMMAND_USER = "USER"
Global Const $IRC_COMMAND_OPER = "OPER"
Global Const $IRC_COMMAND_MODE = "MODE"
Global Const $IRC_COMMAND_QUIT = "QUIT"
Global Const $IRC_COMMAND_JOIN = "JOIN"
Global Const $IRC_COMMAND_PART = "PART"
Global Const $IRC_COMMAND_TOPIC = "TOPIC"
Global Const $IRC_COMMAND_NAMES = "NAMES"
Global Const $IRC_COMMAND_LIST = "LIST"
Global Const $IRC_COMMAND_INVITE = "INVITE"
Global Const $IRC_COMMAND_KICK = "KICK"
Global Const $IRC_COMMAND_MOTD = "MOTD"
Global Const $IRC_COMMAND_WHOIS = "WHOIS"
Global Const $IRC_COMMAND_PING = "PING"
Global Const $IRC_COMMAND_PONG = "PONG"
Global Const $IRC_COMMAND_AWAY = "AWAY"

Global Const $IRC_SASL_LOGGEDIN = 900
Global Const $IRC_SASL_LOGGEDOUT = 901
Global Const $IRC_SASL_NICKLOCKED = 902
Global Const $IRC_SASL_SASLSUCCESS = 903
Global Const $IRC_SASL_SASLFAIL = 904
Global Const $IRC_SASL_SASLTOOLONG = 905
Global Const $IRC_SASL_SASLABORTED = 906
Global Const $IRC_SASL_SASLALREADY = 907
Global Const $IRC_SASL_SASLMECHS = 908
; ===============================================================================================================================

; #VARIABLES# ===================================================================================================================
Global $__g_iIRC_CharEncoding = $SB_UTF8 ; Use $SB_* Constants if you need to change the encoding (see doc for StringToBinary)
Global $__g_IRC_sLoggingFunction = "__IRC_DefaultLog"
; ===============================================================================================================================

TCPStartup() ; Start TCP Services

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_AuthPlainSASL
; Description ...: Authenticate yourself to the server using SASL PLAIN mech.
; Syntax ........: _IRC_AuthPlainSASL($iSocket, $sUsername, $sPassword, $bCensorAuthString = True)
; Parameters ....: $iSocket             - $iSocket from _IRC_Connect.
;                  $sUsername           - Your $sUsername.
;                  $sPassword           - Your $sPassoword.
;                  $bCensorAuthString   - [optional] If True, the string containing the password and the username is not logged. Default is True.
; Return values .: Success: True
;                  Failure: False & @error is set (refer to code of this function.)
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......:
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_AuthPlainSASL($iSocket, $sUsername, $sPassword, $bCensorAuthString = True)
	If Not _IRC_CapRequire($iSocket, 'multi-prefix sasl') Then Return SetError(6, 0, False)
	If @error Then Return SetError(2, @extended, False)
	_IRC_SendRaw($iSocket, "AUTHENTICATE" & $IRC_MESSAGE_SEGMENT_SEPARATOR & "PLAIN")
	If @error Then Return SetError(5, @extended, False)
	If Not _IRC_WaitForNextMsg($iSocket, True)[$IRC_MSGFORMAT_COMMAND] = "AUTHENTICATE" Then Return SetError(3, @extended, False)
	Local $sAuthString = StringReplace(__IRC_Base64_Encode($sUsername & Chr(0) & $sUsername & Chr(0) & $sPassword), @CRLF, '')
	Local $aParameters[1] = [$sAuthString]
	_IRC_SendRaw($iSocket, _IRC_MakeMessage("AUTHENTICATE", $aParameters, 1), $bCensorAuthString ? 'AUTHENTICATE ****' : "AUTHENTICATE " & $sAuthString)
	If @error Then Return SetError(5, @error, @extended)
	Local $aMessage = _IRC_WaitForNextMsg($iSocket, True)
	If @error Then Return SetError(4, @extended, False)
	If Not ($aMessage[$IRC_MSGFORMAT_COMMAND] = $IRC_SASL_LOGGEDIN Or $aMessage[$IRC_MSGFORMAT_COMMAND] = $IRC_SASL_SASLSUCCESS) Then Return SetError(1, $aMessage[$IRC_MSGFORMAT_COMMAND], False)
	_IRC_CapEnd($iSocket)
	Return True
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_CapRequire
; Description ...: Require a capacility.
; Syntax ........: _IRC_CapRequire($iSocket, $sCapability)
; Parameters ....: $iSocket             - $iSocket from _IRC_Connect.
;                  $sCapability         - Name of the the $sCapability.
; Return values .: Success: True if the capability is acknowlodged.
;                  Failure: False & @error is set if sending the message to the server failed, @extended is set to TCPSend's @error.
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......:
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_CapRequire($iSocket, $sCapability)
	Local $aParameters[2] = ["REQ", $sCapability]
	_IRC_SendRaw($iSocket, _IRC_MakeMessage("CAP", $aParameters, 2))
	If @error Then Return SetError(1, @extended, False)
	Local $aMessage
	Do
		$aMessage = _IRC_WaitForNextMsg($iSocket, True)
		If @error Then Return SetError(2, @extended, False)
	Until $aMessage[$IRC_MSGFORMAT_COMMAND] = "CAP"
	Return $aMessage[3] = "ACK"
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_CapEnd
; Description ...: Sends the CAP END message.
; Syntax ........: _IRC_CapEnd($iSocket)
; Parameters ....: $iSocket             - $iSocket from _IRC_Connect.
; Return values .: Success: True
;                  Failure: False & @extended set to TCPRecv's @error.
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......:
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_CapEnd($iSocket)
	Local $aParameters[1] = ["END"]
	_IRC_SendRaw($iSocket, _IRC_MakeMessage("CAP", $aParameters, 1))
	If @error Then SetError(1, @extended, False)
	Return True
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_Connect
; Description ...: Just a wrapper to TCPConnect, Use it to get the $iSocket used to send messages to the IRC Server.
; Syntax ........: _IRC_Connect($vServer, $iPort)
; Parameters ....: $vServer             - The IP or Address of the IRC Server.
;                  $iPort               - The port to connect. DONT USE SSL PORTS!.
; Return values .: Success: $iSocket
;                  Failure: False & @error set to:
;                           1 - If unable to resolve server address, @extended is set to TCPNameToIP's @error
;                           2 - If unable to establish a connection to the server, @extended is set to TCPConnect's @error
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......: SSL is not supported yet :(
; Related .......: TCPConnect
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_Connect($vServer, $iPort)
	$vServer = TCPNameToIP($vServer)
	If @error Then Return SetError(1, @error, False)
	Local $iSocket = TCPConnect($vServer, $iPort)
	If @error Then Return SetError(2, @error, False)
	Return $iSocket
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_Disconnect
; Description ...: Just a wrapper for TCPCloseSocket.
; Syntax ........: _IRC_Disconnect($iSocket)
; Parameters ....: $iSocket             - $iSocket from _IRC_Connect.
; Return values .: Success: True
;                  Failure: False & @error set to 1, @extended is set to TCPCloseSocket's @error.
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......:
; Related .......: TCPCloseSocket
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_Disconnect($iSocket)
	TCPCloseSocket($iSocket)
	If @error Then Return SetError(1, @error, False)
	Return True
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_FormatMessage
; Description ...: Formats a RAW message from to IRC into a neat array ;).
; Syntax ........: _IRC_FormatMessage($sMessage)
; Parameters ....: $sMessage            - The raw $sMessage from the server. (@CRLF is automatically deleted if it exists!)
; Return values .: Success: Formatted Array, See Remarks for format.
;                  Failure: Not gonna happen lol.
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......: Format of the returned array:
;                  $aArray[$IRC_MSGFORMAT_PREFIX]  = Prefix of the message (Refer to <prefix> in 2.3.1 section of RFC 1459)
;                  $aArray[$IRC_MSGFORMAT_COMMAND] = Command (like PRIVMSG, MODE etc.)
;                  $aArray[1 + n]                  = nth parameter (Example: The second parameter would be located in $aArray[3])
;
;                  Not all formatted arrays make sense :P
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_FormatMessage($sMessage)
	$sMessage = StringStripWS($sMessage ,$STR_STRIPTRAILING) ; Trim the trailing whitespace (@CRLF)
	If Not (StringLeft($sMessage, 1) = $IRC_TRAILING_PARAMETER_INDICATOR) Then
		$sMessage = ' ' & $sMessage
	Else
		$sMessage = StringTrimLeft($sMessage, 1) ; Trim $IRC_TRAILING_PARAMETER_INDICATOR
	EndIf
	Local $aMessage = StringSplit($sMessage, $IRC_MESSAGE_SEGMENT_SEPARATOR)
	Local $sLastParameter = ""
	Local $iLastParameterPos = StringInStr($sMessage, $IRC_TRAILING_PARAMETER_INDICATOR, $STR_NOCASESENSEBASIC, 1, StringLen($aMessage[0] > 0 ? $aMessage[1] : ""))
	Local $iLastParameterSpaces = 0
	Local $iMessageSpaces = $aMessage[0]
	If $iLastParameterPos = 0 Then
		$sLastParameter = $aMessage[$aMessage[0]]
	Else
		$sLastParameter = StringTrimLeft($sMessage, $iLastParameterPos)
		StringReplace($sLastParameter, $IRC_MESSAGE_SEGMENT_SEPARATOR, "", 0, $STR_NOCASESENSEBASIC)
		$iLastParameterSpaces = @extended
	EndIf
	Local $aFormattedMessage[$iMessageSpaces - $iLastParameterSpaces]
	For $i = 1 To $aMessage[0] - (1 + $iLastParameterSpaces)
		$aFormattedMessage[$i - 1] = $aMessage[$i]
	Next
	$aFormattedMessage[$i - 1] = $sLastParameter
	Return $aFormattedMessage
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_FormatPrivMsg
; Description ...: Formats a PRIVMSG into nice & readable array ;)
; Syntax ........: _IRC_FormatPrivMsg($vMessage)
; Parameters ....: $vMessage            - The RAW Message or Formatted Message from _IRC_FormatMessage.
; Return values .: Success: $aFormattedArray (See Remarks).
;                  Failure: Empty $aFormattedArray & @error is set to:
;                           1 - If the $vMessage is not a PRIV message.
;                           2 - If the $vMessage's prefix is faulty.
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......: Format of $aFormattedArray:
;                  $aFormattedArray[$IRC_PRIVMSG_SENDER] = <Nickname of the sender>
;                  $aFormattedArray[$IRC_PRIVMSG_SENDER_USERSTRING] = <The "user" string of the sender>
;                  $aFormattedArray[$IRC_PRIVMSG_SENDER_HOSTMASK] = <Hostmask of the sender>
;                  $aFormattedArray[$IRC_PRIVMSG_RECEIVER] = <Name of the channel/your nickname>
;                  $aFormattedArray[$IRC_PRIVMSG_MSG] = <Message sent>
;                  $aFormattedArray[$IRC_PRIVMSG_REPLYTO] = <Contains the $sTarget parameter need for _IRC_SendMessage>
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_FormatPrivMsg($vMessage)
	If Not IsArray($vMessage) Then
		$vMessage = _IRC_FormatMessage($vMessage)
		If @error Then Return SetError(1, 0, False)
	EndIf
	Local $aFormattedArray[6]
	If Not $vMessage[$IRC_MSGFORMAT_COMMAND] = "PRIVMSG" Then Return SetError(1, 0, $aFormattedArray)
	Local $aSenderDetails = StringSplit($vMessage[$IRC_MSGFORMAT_PREFIX], '!@')
	Local Enum $PARM_COUNT, $NICKNAME, $USERSTRING, $HOSTMASK
	If $aSenderDetails[$PARM_COUNT] < 3 Then Return SetError(2, 0, $aFormattedArray)
	$aFormattedArray[$IRC_PRIVMSG_SENDER] = $aSenderDetails[$NICKNAME]
	$aFormattedArray[$IRC_PRIVMSG_SENDER_USERSTRING] = $aSenderDetails[$USERSTRING]
	$aFormattedArray[$IRC_PRIVMSG_SENDER_HOSTMASK] = $aSenderDetails[$HOSTMASK]
	$aFormattedArray[$IRC_PRIVMSG_RECEIVER] = $vMessage[2]
	$aFormattedArray[$IRC_PRIVMSG_MSG] = $vMessage[3]
	$aFormattedArray[$IRC_PRIVMSG_REPLYTO] = (_IRC_IsChannel($aFormattedArray[$IRC_PRIVMSG_RECEIVER])) ? $aFormattedArray[$IRC_PRIVMSG_RECEIVER] : $aFormattedArray[$IRC_PRIVMSG_SENDER]
	Return $aFormattedArray
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_FormatText
; Description ...: Formats the text for IRC clients.
; Syntax ........: _IRC_FormatText($sText, $aPalette)
; Parameters ....: $sText               - $sText to format.
;                  $aPalette            - $aPalette from _IRC_MakePalette.
; Return values .: Success: Formatted $sText
;                  Failure: Unformatted $sText & @error set to 1
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......:
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_FormatText($sText, $aPalette)
	If Not (IsArray($aPalette) Or UBound($aPalette) = 5) Then
		Return SetError(1, 0, $sText)
	EndIf
	If Not ($aPalette[$IRC_COLOR_PALETTE_FOREGROUND] = $IRC_COLOR_PLAIN And $aPalette[$IRC_COLOR_PALETTE_BACKGROUND] = $IRC_COLOR_PLAIN) Then
		If $aPalette[$IRC_COLOR_PALETTE_FOREGROUND] = $IRC_COLOR_PLAIN Then $aPalette[$IRC_COLOR_PALETTE_FOREGROUND] = ""
		If $aPalette[$IRC_COLOR_PALETTE_BACKGROUND] = $IRC_COLOR_PLAIN Then
			$aPalette[$IRC_COLOR_PALETTE_BACKGROUND] = ""
		Else
			$aPalette[$IRC_COLOR_PALETTE_BACKGROUND] = ',' & $aPalette[$IRC_COLOR_PALETTE_BACKGROUND]
		EndIf
		$sText = $IRC_FORMATTING_CHAR_COLOR & $aPalette[$IRC_COLOR_PALETTE_FOREGROUND] & $aPalette[$IRC_COLOR_PALETTE_BACKGROUND] & $sText
	EndIf
	$sText = $aPalette[$IRC_COLOR_PALETTE_BOLD] ? $IRC_FORMATTING_CHAR_BOLD & $sText : $sText
	$sText = $aPalette[$IRC_COLOR_PALETTE_ITALIC] ? $IRC_FORMATTING_CHAR_ITALIC & $sText : $sText
	$sText = $aPalette[$IRC_COLOR_PALETTE_UNDERLINE] ? $IRC_FORMATTING_CHAR_UNDERLINE & $sText : $sText
	Return $sText
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_Invite
; Description ...: Invite a user to a channel
; Syntax ........: _IRC_Invite($iSocket, $sNick, $sChannel)
; Parameters ....: $iSocket             - $iSocket from _IRC_Connect.
;                  $sNick               - $sNickname of the use to invite.
;                  $sChannel            - $sChannel to invite.
; Return values .:Success: Raw data (most of the time, its a string).
;                  Failure: False & @error set to 1, @extended contains TCPRecv's @error.
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......:
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_Invite($iSocket, $sNick, $sChannel)
	Local $aParameters[2] = [$sNick, $sChannel]
	_IRC_SendRaw($iSocket, _IRC_MakeMessage($IRC_COMMAND_INVITE, $aParameters, 2))
	If @error Then Return SetError(1, @extended, False)
	Return True
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_IsChannel
; Description ...: Check if a string is a valid channel name
; Syntax ........: _IRC_IsChannel($sChannel)
; Parameters ....: $sChannel            - $sChannel name to check.
; Return values .: Success: True
;                  Failure: False
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......:
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_IsChannel($sChannel)
	Switch StringLeft($sChannel, 1)
		Case '&', '#', '+', '!' ; RFC 2812 Section 1.3: "Channels"
			Return True

		Case Else
			Return False
	EndSwitch
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_ReceiveRaw
; Description ...: Get RAW messages from the server.
; Syntax ........: _IRC_ReceiveRaw($iSocket, $bSplit)
; Parameters ....: $iSocket             - $iSocket from _IRC_Connect.
; Return values .: Success: Raw data (most of the time, its a string).
;                  Failure: False & @error set to 1, @extended contains TCPRecv's @error.
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......:
; Related .......: TCPRecv
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_ReceiveRaw($iSocket)
	Local Const $UNICODE_CR = 13
	Local Const $UNICODE_LF = 10
	Local Const $UNICODE_NULL = 0
	Local $vData = ""
	Do
		$vData &= TCPRecv($iSocket, 1)
		If @error Then Return SetError(1, @error, False)
	Until AscW(StringRight($vData, 1)) = $UNICODE_LF Or AscW(StringRight($vData, 1)) = $UNICODE_NULL
	If Not $vData = "" Then Call($__g_IRC_sLoggingFunction, $vData, False)
	Return $vData
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_SendCTCP
; Description ...: Sends a CTCP message to the $sTarget.
; Syntax ........: _IRC_SendCTCP($iSocket, $sTarget, $sMessage)
; Parameters ....: $iSocket             - $iSocket from _IRC_Connect.
;                  $sTarget             - Nickname of the $sTarget.
;                  $sMessage            - CTCP $sMessage to send.
; Return values .: Success: True
;                  Failure: False, @error & @extended are set to _IRC_SendMessage's @error & @extended.
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......:
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_SendCTCP($iSocket, $sTarget, $sMessage)
	_IRC_SendMessage($iSocket, $sTarget, $IRC_CTCP_DELIMITER & $sMessage & $IRC_CTCP_DELIMITER)
	If @error Then Return SetError(@error, @extended, False)
	Return True
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_SendCTCPReply
; Description ...: Sends a reply to a CTCP message.
; Syntax ........: _IRC_SendCTCPReply($iSocket, $sTarget, $sMessage, $sReply)
; Parameters ....: $iSocket             - $iSocket from _IRC_Connect.
;                  $sTarget             - Nickname of the $sTarget.
;                  $sMessage            - CTCP $sMessage to which you are replying to.
;                  $sReply              - The CTCP $sReply to send.
; Return values .: Success: True
;                  Failure: False & @extended set to TCPSend's @error.
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......:
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_SendCTCPReply($iSocket, $sTarget, $sMessage, $sReply)
	_IRC_SendNotice($iSocket, $sTarget, $IRC_CTCP_DELIMITER & $sMessage & ' ' & $sReply & $IRC_CTCP_DELIMITER)
	If @error Then Return SetError(@error, @extended, False)
	Return True
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_JoinChannel
; Description ...: Join a channel.
; Syntax ........: _IRC_JoinChannel($iSocket, $sChannel[, $sPassword = ""])
; Parameters ....: $iSocket             - $iSocket from _IRC_Connect.
;                  $sChannel            - Channel to join (Including the #).
;                  $sPassword           - [optional] Password of the channel (if any). Default is none ("").
; Return values .: Success: True (It does not check if Joining was successful or not.)
;                  Failure: False & @error set to:
;                           1 - If the channel's name is too long.
;                           2 - If sending the join message to the server failed, @extended is set to TCPSend's @error.
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......:
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_JoinChannel($iSocket, $sChannel, $sPassword = "")
	Local $aParameters[2] = [$sChannel, $sPassword]
	_IRC_SendRaw($iSocket, _IRC_MakeMessage($IRC_COMMAND_JOIN, $aParameters, $sPassword = "" ? 1 : 2))
	If @error Then Return SetError(@error, @extended, False)
	Return True
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_Pong
; Description ...: Reply to a server PING message.
; Syntax ........: _IRC_Pong($iSocket, $sServer)
; Parameters ....: $iSocket             - $iSocket from _IRC_Connect.
;                  $sServer             - Server's hostname.
; Return values .: Success: True
;                  Failure: False & @extended is set to TCPSend's @error.
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......:
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_Pong($iSocket, $sServer)
	Local $aParameters[1] = [$sServer]
	_IRC_SendRaw($iSocket, _IRC_MakeMessage($IRC_COMMAND_PONG, $aParameters, 1))
	If @error Then Return SetError(1, @extended, False)
	Return True
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_Kick
; Description ...: Kick a user from a channel.
; Syntax ........: _IRC_Kick($iSocket, $sChannel, $sNick, $sReason)
; Parameters ....: $iSocket             - $iSocket from _IRC_Connect.
;                  $sChannel            - In which $sChannel should the user kicked?
;                  $sNick               - $sNickname of the user to kick.
;                  $sReason             - [optional] Reason of kick, Default is "" (None).
; Return values .: Success: True
;                  Failure: False & @extended is set to TCPSend's @error.
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......:
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_Kick($iSocket, $sChannel, $sNick, $sReason = "")
	Local $aParameters[3] = [$sChannel, $sNick, $sReason]
	_IRC_SendRaw($iSocket, _IRC_MakeMessage($IRC_COMMAND_KICK, $aParameters, $sReason = "" ? 2 : 3))
	If @error Then Return SetError(1, @extended, False)
	Return True
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_MakeMessage
; Description ...: Generate messages which can be sent to the IRC server.
; Syntax ........: _IRC_MakeMessage($sCommand, $aParameters[, $iParameters = UBound($aParameters)])
; Parameters ....: $sCommand            - The $sCommand.
;                  $aParameters         - Array containing the parameter(s) for the $sCommand. See remarks for the format.
;                  $iParameters         - [optional] No. of $aParameters. Default is UBound($aParameter).
; Return values .: Success: The generated $sMessage
;                  Failure: N/A
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......: Remarks about $aParameters:
;                  $aParameters should contain the parameters for the $sCommand. Every element is considered as a parameter, so
;                  including additional information like the number of elements in the [0] element is NOT allowed.
;
;                  If you already know the number of parameters in the $aParameters array, you should pass the number to $iParameters,
;                  you will get a slight performance boost! ;)
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_MakeMessage($sCommand, $aParameters, $iParameters = UBound($aParameters))
	Local $sMessage = $sCommand & $IRC_MESSAGE_SEGMENT_SEPARATOR
	For $iParameter = 0 To $iParameters - 2
		$sMessage &= $aParameters[$iParameter] & $IRC_MESSAGE_SEGMENT_SEPARATOR
	Next
	$sMessage &= $IRC_TRAILING_PARAMETER_INDICATOR & $aParameters[$iParameters - 1]
	Return $sMessage
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_MakePalette
; Description ...: Creates a color palette to be used with _IRC_FormatText.
; Syntax ........: _IRC_MakePalette([$iColor = $IRC_COLOR_PLAIN[, $iBgColor = $IRC_COLOR_PLAIN[, $bBold = False[,
;                  $bItalic = False[, $bUnderline = False]]]]])
; Parameters ....: $iColor              - [optional] Color of the text. Default is $IRC_COLOR_PLAIN.
;                  $iBgColor            - [optional] Background color of the text. Default is $IRC_COLOR_PLAIN.
;                  $bBold               - [optional] Is the text Bold? Default is False.
;                  $bItalic             - [optional] Is the text Italic? Default is False.
;                  $bUnderline          - [optional] Is the text Underlined? Default is False.
; Return values .: Palette Array
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......:
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_MakePalette($iColor = $IRC_COLOR_PLAIN, $iBgColor = $IRC_COLOR_PLAIN, $bBold = False, $bItalic = False, $bUnderline = False)
	Local $aPalette[5]
	$aPalette[$IRC_COLOR_PALETTE_FOREGROUND] = $iColor
	$aPalette[$IRC_COLOR_PALETTE_BACKGROUND] = $iBgColor
	$aPalette[$IRC_COLOR_PALETTE_BOLD] = $bBold
	$aPalette[$IRC_COLOR_PALETTE_ITALIC] = $bItalic
	$aPalette[$IRC_COLOR_PALETTE_UNDERLINE] = $bUnderline
	Return $aPalette
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_Part
; Description ...: Part from a channel.
; Syntax ........: _IRC_Part($iSocket, $sChannel[, $sReason = ""])
; Parameters ....: $iSocket             - $iSocket from _IRC_Connect.
;                  $sChannel            - Name of the $sChannel to part (including the prefix).
;                  $sReason             - [optional] Reason for parting. Default is "" (None).
; Return values .: Success: True
;                  Failure: False & @extended is set to TCPSend's @error.
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......:
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_Part($iSocket, $sChannel, $sReason = "")
	Local $aParameters[2] = [$sChannel, $sReason]
	_IRC_SendRaw($iSocket, _IRC_MakeMessage($IRC_COMMAND_PART, $aParameters, $sReason = "" ? 1 : 2))
	If @error Then Return SetError(1, @extended, False)
	Return True
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_Quit
; Description ...: Quit from a IRC server.
; Syntax ........: _IRC_Quit($iSocket[, $sReason = ""])
; Parameters ....: $iSocket             - an integer value.
;                  $sReason             - [optional] a string value. Default is "".
; Return values .: Success: True
;                  Failure: False & @extended is set to TCPSend's @error.
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......:
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_Quit($iSocket, $sReason = "")
	Local $aParameters[1] = [$sReason]
	_IRC_SendRaw($iSocket, _IRC_MakeMessage($IRC_COMMAND_QUIT, $aParameters, $sReason = "" ? 0 : 1))
	If @error Then Return SetError(1, @extended, False)
	Return True
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_SendMessage
; Description ...: Use it to send a message/PM to a channel/user.
; Syntax ........: _IRC_SendMessage($iSocket, $sTarget, $sMessage)
; Parameters ....: $iSocket             - $iSocket from _IRC_Connect.
;                  $sTarget             - $sTarget or recipent of the messages, can be a channel or a nick.
;                  $sMessage            - $sMessage to send.
; Return values .: Success: True
;                  Failure: False & @error set to:
;                           1 - If the $sMessage is too long. (See _IRC_SendRaw's @error 1's reason)
;                           2 - If sending the message to the server failed, @extended is set to TCPSend's @error.
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......: WARNING: THIS FUNCTION DOES NOT SEND RAW MESSAGES TO THE SERVER, USE _IRC_SendRaw instead.
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_SendMessage($iSocket, $sTarget, $sMessage)
	Local $aParameters[2] = [$sTarget, $sMessage]
	_IRC_SendRaw($iSocket, _IRC_MakeMessage($IRC_COMMAND_MESSAGE, $aParameters, 2))
	If @error Then Return SetError(@error, @extended, False)
	Return True
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_SendNotice
; Description ...: Send a notice to a channel or user.
; Syntax ........: _IRC_SendNotice($iSocket, $sTarget, $sMessage)
; Parameters ....: $iSocket             - $iSocket from _IRC_Connect.
;                  $sTarget             - $sTarget of the notice, can be a channel or a user.
;                  $sMessage            - $sMessage of the notification.
; Return values .: Success: True
;                  Failure: False & @extended is set to TCPSend's @error.
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......:
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_SendNotice($iSocket, $sTarget, $sMessage)
	Local $aParameters[2] = [$sTarget, $sMessage]
	_IRC_SendRaw($iSocket, _IRC_MakeMessage($IRC_COMMAND_NOTICE, $aParameters, 2))
	If @error Then Return SetError(1, @extended, False)
	Return True
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_SendRaw
; Description ...: Just a wrapper for TCPSend, use it to send raw messeges to the IRC server.
; Syntax ........: _IRC_SendRaw($iSocket, $sRawMessage, $sLog = $sRawMessage)
; Parameters ....: $iSocket             - $iSocket from _IRC_Connect.
;                  $sRawMessage         - The $sRawMessage to send.
;                  $sLog                - [optional] The message which would be logged, Default is $sRawMessage.
; Return values .: Success: True. @extended is set to 1 if the $sRawMessage exceeds 512 chars. (This is required by protocol.)
;                  Failure: False & @error set to:
;                           1 - If the $sRawMessage is longer than 512 bytes.
;                           2 - If sending the message to the server failed, @extended is set to TCPSend's @error.
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......: 1. @CRLF is ALWAYS appended to the $sRawMessage. Its required by protocol.
;                  2. The $sRawMessage is converted to binary before sending it...
;                  3. Messages longer than 512 bytes are rejected by most of the IRC Server...
; Related .......: TCPSend
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_SendRaw($iSocket, $sRawMessage, $sLog = $sRawMessage)
	$sRawMessage &= @CRLF
	Local $dRawMessage = StringToBinary($sRawMessage, $__g_iIRC_CharEncoding)
	If BinaryLen($dRawMessage) > 512 Then SetError(1, 0, False)
	TCPSend($iSocket, $dRawMessage)
	If @error Then Return SetError(2, @error, False)
	Call($__g_IRC_sLoggingFunction, $sLog & @CRLF, True) ; Call the logging function
	Return True
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_SetNick
; Description ...: Changes or sets your nickname
; Syntax ........: _IRC_SetNick($iSocket, $sNick)
; Parameters ....: $iSocket             - $iSocket from _IRC_Connect.
;                  $sNick               - Nickname to set.
; Return values .: Success: True
;                  Failure: False & @extended is set to TCPSend's @error.
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......: WARNING: THE RETURN VALUES ONLY INDICATES THE DELIVARY OF THE MESSAGE, THERE IS NO GARUNTEE THAT YOU NICK HAS
;                           CHANGED.
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_SetNick($iSocket, $sNick)
	Local $aParameters[1] = [$sNick]
	_IRC_SendRaw($iSocket, _IRC_MakeMessage($IRC_COMMAND_NICKNAME, $aParameters, 1))
	If @error Then Return SetError(1, @extended, False)
	Return True
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_SetMode
; Description ...: Set a mode on a nick.
; Syntax ........: _IRC_SetMode($iSocket, $sNick, $sOperation, $sModes)
; Parameters ....: $iSocket             - $iSocket from _IRC_Connect.
;                  $sNick               - Nickname to apply the mode.
;                  $sOperation          - $IRC_MODE_ADD or $IRC_MODE_REMOVE.
;                  $sModes              - $sMode(s) (one char = one mode).
;                  $sParameters         - $sParameters if any, Default is "" (No parameters).
; Return values .: Success: True
;                  Failure: False & @extended is set to TCPSend's @error.
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......:
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_SetMode($iSocket, $sNick, $sOperation, $sModes, $sParameters = "")
	Local $aParameters[3] = [$sNick, $sOperation & $sModes, $sParameters]
	_IRC_SendRaw($iSocket, _IRC_MakeMessage($IRC_COMMAND_MODE, $aParameters, $sParameters = "" ? 2 : 3))
	If @error Then Return SetError(1, @extended, False)
	Return True
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_SetTopic
; Description ...: Set the topic of a channel.
; Syntax ........: _IRC_SetTopic($iSocket, $sChannel, $sTopic)
; Parameters ....: $iSocket             - $iSocket from _IRC_Connect.
;                  $sChannel            - $sChannel to set the topic.
;                  $sTopic              - The $sTopic to set, use "" to unset topic.
; Return values .: Success: True
;                  Failure: False & @extended is set to TCPSend's @error.
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......:
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_SetTopic($iSocket, $sChannel, $sTopic)
	Local $aParameters[2] = [$sChannel, $sTopic]
	_IRC_SendRaw($iSocket, _IRC_MakeMessage($IRC_COMMAND_TOPIC, $aParameters, 2))
	If @error Then Return SetError(1, @extended, False)
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_SetUser
; Description ...: Sends the required details of the client to the server.
; Syntax ........: _IRC_SetUser($iSocket, $sUsername, $sRealname, $sMode, $sUnused)
; Parameters ....: $iSocket             - $iSocket from _IRC_Connect.
;                  $sUsername           - Your $sUsername.
;                  $sRealname           - Your $sRealname.
;                  $sMode               - ???. Default is '0'.
;                  $sUnused             - ???. Default is '*'.
; Return values .: Success: True
;                  Failure: False & @extended is set to TCPSend's @error.
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......: You can safely ignore the last 2 parameters.
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_SetUser($iSocket, $sUsername, $sRealname, $sMode = '0', $sUnused = '*')
	Local $aParameters[4] = [$sUsername, $sMode, $sUnused, $sRealname]
	_IRC_SendRaw($iSocket, _IRC_MakeMessage($IRC_COMMAND_USER, $aParameters, 4))
	If @error Then Return SetError(1, @extended, False)
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _IRC_WaitForNextMsg
; Description ...: Waits until a message arrives from the IRC Server.
; Syntax ........: _IRC_WaitForNextMsg($iSocket, $bFormat = False)
; Parameters ....: $iSocket             - $iSocket from _IRC_Connect.
;                  $bFormat             - If True then the received message is formatted using _IRC_FormatMessage.
; Return values .: Success: The message received.
;                  Failure: Empty string & @extended is set to TCPRecv's @error
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......:
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _IRC_WaitForNextMsg($iSocket, $bFormat = False)
	Local $vMessage
	Do
		$vMessage = _IRC_ReceiveRaw($iSocket)
		If @error Then Return SetError(1, @extended, "")
		Sleep(10)
	Until Not $vMessage = ''
	If $bFormat Then $vMessage = _IRC_FormatMessage($vMessage)
	Return $vMessage
EndFunc

Func __IRC_Base64_Encode($vData)
    $vData = Binary($vData)
    Local $tByteStruct = DllStructCreate("byte[" & BinaryLen($vData) & "]")
    DllStructSetData($tByteStruct, 1, $vData)
    Local $tIntStruct = DllStructCreate("int")
    Local $aDllCall = DllCall("Crypt32.dll", "int", "CryptBinaryToString", _
            "ptr", DllStructGetPtr($tByteStruct), _
            "int", DllStructGetSize($tByteStruct), _
            "int", 1, _
            "ptr", 0, _
            "ptr", DllStructGetPtr($tIntStruct))
    If @error Or Not $aDllCall[0] Then
        Return SetError(1, 0, False) ; error calculating the length of the buffer needed
    EndIf
    Local $tCharStruct = DllStructCreate("char[" & DllStructGetData($tIntStruct, 1) & "]")
    $aDllCall = DllCall("Crypt32.dll", "int", "CryptBinaryToString", _
            "ptr", DllStructGetPtr($tByteStruct), _
            "int", DllStructGetSize($tByteStruct), _
            "int", 1, _
            "ptr", DllStructGetPtr($tCharStruct), _
            "ptr", DllStructGetPtr($tIntStruct))
    If @error Or Not $aDllCall[0] Then
        Return SetError(2, 0, False) ; error encoding
    EndIf
    Return DllStructGetData($tCharStruct, 1)
EndFunc ; https://www.autoitscript.com/forum/topic/139260-autoit-snippets/?do=findComment&comment=1304262

Func __IRC_DefaultLog($sMessage, $bOutgoing)
	Local Static $sFilePath = ""
	Local Static $hFileHandle
	Local $sTimestamp = '[' & @HOUR & ':' & @MIN & ':' & @SEC & ']'
	Local $sDirection = ""
	If $bOutgoing Then
		$sDirection = '>>>'
	Else
		$sDirection = '<<<'
	EndIf
	Local Const $FILE = @ScriptDir & '\IRC Logs\' & @YEAR & '\' & @MON & '\' & @MDAY & '.log'
	If Not $sFilePath = $FILE Then
		$sFilePath = $FILE
		FileClose($hFileHandle)
		$hFileHandle = FileOpen($sFilePath, $FO_APPEND + $FO_BINARY + $FO_CREATEPATH)
	EndIf
	Local $sData = $sTimestamp & ' ' & $sDirection & ' ' & $sMessage
	FileWrite($hFileHandle, $sData)
	ConsoleWrite($sData)
	Return True
EndFunc