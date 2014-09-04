-- Utilities for CryImporter
-- Copyright 2006 Takaro Pty. Ltd.
-- www.takaro.net

/* Notes:
	* Log levels: 1 = highest importance, 5 = most trivial
	* The pathString value supplied to the logging.init function should be a string
    containing the absolute path to this instance of the logging structure, e.g.
    	utility myWidget "my widget"
    	(
    		include "CryImporter-utils.ms"
    		logger = LoggingUtil()
    		logger.init true 1 "myWidget.logger"
    	) 		
*/

fn minimum x y = if x > y then y else x
	
fn maximum x y = if x > y then x else y

fn isDigit x =
(
	if x=="1" or x=="2" or x=="3" or x=="4" or x=="5" or x=="6" or x=="7" or \
	   x=="8" or x=="9" or x=="0"  then true else false
)

fn isBoolean x =
( 
	if x=="true" or x=="false" then true else false
)


-- Convert single integer into hex format as a string
fn hexString val =
(
	if classOf val == Integer then
		val = bit.intAsHex val
	else
		val = ""
	
	("0x" + val)
)

-- Convert high and low integers into a single hex format value as a string
fn hexString2 high low =
(
	if classOf high == Integer then
		high = bit.intAsHex high
	else
		high = ""
	if classOf low == Integer then
		low = bit.intAsHex low
	else
		low = ""
	
	("0x" + high + low)
)

fn parseBoolean s =
(
	if isBoolean s then 
	(
		if s == "true" then
			true
		else
			false	
	)
	else
		undefined	
)

-- Do a binary search for the given item 
-- Assumes sorted list, and directly comparable data (i.e. x > y, x < y, x == y)
-- Returns index if found, returns undefined otherwise
fn binarySearch array item =
(
	local mn = 1
	local mx = array.count
	local mid = mx/2
	
	-- do some basic bounds checks to keep main loop simpler
	if array.count == 0 then
		return undefined -- empty array
	else if array[mn] == item then
		return mn -- item in first position
	else if array[mx] == item then
		return mx -- item in last position
		
	while mid > mn and mid < mx do
	(
		if array[mid] == item then 
			return mid -- found it!
		else if item < array[mid] then
			mx = mid -- check bottom half
		else 
			mn = mid -- check top half
			
		mid = ((mx - mn) / 2) + mn
	)
	
	return undefined -- item not found 
)

fn parseInteger s =
(
	for i = 1 to s.count do
		if not isDigit s[i] then return undefined
	
	s as Integer
)

fn getSetting iniFile group setting type:"string" default:undefined=
(
	local ret
	if (classOf	iniFile != String) or (classOf group != String) or \
	   (classOf	setting != String) or (classOf type != String) then
		return default
	
	local s = getIniSetting iniFile group setting
	if s == undefined then return default
	
	if type == "boolean" then
	(
		local val = parseBoolean s
		if val == undefined then
			ret = default
		else
			ret = val
	)
	else if type == "integer" then
	(
		local val = parseInteger s
		if val == undefined then
			ret = default
		else
			ret = val
	)
	else -- assume string
		ret = s
	
	ret
)

struct CALReader
(
	STATE_STARTLINE = 0,
	STATE_GETNAME = 1,
	STATE_GETEQUALS = 2,
	STATE_GETPATH = 3,
	state = STATE_STARTLINE,
	animList = #(),
	currentCAF,
	
	-- read next token in string l at position pos and return it as a string
	fn readToken l &pos =
	(
		local t = undefined
		
		-- skip whitespace
		local start = pos
		while start <= l.count and isSpace l[start] do
			start += 1
		
		-- get to next whitespace
		local end = start + 1
		while end <= l.count and (isSpace l[end] == false) do
			end += 1
		
		-- return substring
		pos = end + 1
		if start <= l.count then 
			t = substring l start (end - start)
		return t			
	),
		
	fn processState l &pos =
	(
		case state of
		(
			STATE_STARTLINE:
			(
				if l.count > 2 and l[1] == "/" and l[2] == "/" then return() -- comment line
				if l.count > 1 and l[1] == "$" then return() -- directive we can ignore
				
				currentCAF = CAFRecord()
				state = STATE_GETNAME
				processState l &pos
			)
			
			STATE_GETNAME:
			(
				currentCAF.name = readToken l &pos
				if currentCAF.name != undefined then
				(
					state = STATE_GETEQUALS
					processState l &pos
				)						
			)
			
			STATE_GETEQUALS:
			(
				if (readToken l &pos) == "=" then
				(
					state = STATE_GETPATH
					processState l &pos
				)
			)
			
			STATE_GETPATH:
			(
				currentCAF.path = readToken l &pos
				if currentCAF.path != undefined then
					append animList currentCAF
			)	
		)	
	),
	
	fn readCALFile filename =
	(
		animList = #()
			
		if (not DoesFileExist filename) then
			return "Invalid filename given"
			
		fs = openFile filename mode:"rb"
			
		-- Extract tokens from file
		while eof fs == false do
		(
			state = STATE_STARTLINE
			local pos = 1
			local l = readLine fs
			processState l &pos
		)	
		
		if animList.count == 0 then
			return (filename + " contained no animation filenames to import")
		else
			return ok
	),
	
	fn getFileList =
	(
		return animList
	),
	
	-- Pad string out with spaces to the specified length, adding to end of string
	fn padString s len =
	(
		if s.count >= len then return s
		
		for i in 1 to (len - s.count) do
			s = s + " "	
		return s
	),
	
	fn formatAnimListString list =
	(
		local s = StringStream ""
		local maxName = 1
		local maxPath = 1
		
		-- Iterate through list and find longest name and path
		for x in list do
		(
			if x.name.count > maxName then maxName = x.name.count
			if x.path.count > maxPath then maxPath = x.path.count
		)
		
		-- Build up string
		for x in list do
		(
			format "%   %   Start: %  End: %\n" (padString x.name maxName) (padString x.path maxPath)\
				(padString (x.startFrame as string) 5) (padString (x.endFrame as string) 5) to:s	
		)
		return s as string
	)
)

struct LoggingUtil
(
	-- Modifiable params
	flushAt = 10,  -- Flush log after this many log commands
	logOutputMinHeight = 550,
	logRolloutHeightDiff = 20,  -- How much bigger the rollout is compared to logOutput height
	logWindowHeight = 600,
	logWindowWidth = 600,
	linePixelSize = 13.2,   -- This should never need changing, as it should be same for all 3ds maxs
	
	-- Do not modify
	logWindow,    -- handle for the logging window
	logRollout,   -- handle for the logging rollout inside the logging window
	logOutput,    -- handle for the edittext component inside the logging rollout
	logText,      -- handle for a stringstream (required for execute function inside log())
	doLog = true,
	logLevel = 1,
	pathString = "",
	newlineCount = 0,
	bufferFormatString = "",
	bufferArgString = "",
	bufferNumLogs = 0,
	
	fn resize =
	(
		if doLog then
		(
			if ((maxVersion())[1] > 7000) then
			(
				logOutput.height = maximum logOutputMinHeight (newlineCount * linePixelSize)
				logRollout.height = logOutput.height + logRolloutHeightDiff		
				logRollout.scrollPos = logRollout.height -- Scroll to bottom
			)
		)
	),
	
	fn init enabled level path =
	(
		if classOf enabled == BooleanClass then
			doLog = enabled
		
		if classOf level == Integer then
			logLevel = level
		
		if classOf path == String then
			pathString = path
			
		if doLog then
		(
			rollout loggingRollout "Logging"
			(
				local ps
				edittext logOutput text:"" height:logOutputMinHeight readOnly:true		
				
				on loggingRollout close do
				(
					execute(ps + ".doLog = false")	
				)	
			)
				
			logWindow = newRolloutFloater "Logging Window" logWindowHeight logWindowWidth
			addRollout loggingRollout logWindow
			loggingRollout.ps = pathString
			logOutput = loggingRollout.logOutput
			logRollout = loggingRollout
			
			logText = StringStream ""
			resize()
		)
	),
	
	fn close =
	(
		if logWindow != undefined then
			closeRolloutFloater logWindow
	),
	
	fn reset =
	(
		newlineCount = 0
		bufferFormatString = ""
		bufferArgString = ""
		bufferNumLogs = 0
		logText = StringStream ""
			
		if classOf logOutput == EditTextControl then
		(
			logOutput.text = ""
			resize()
		)
	),
	
	fn flush =
	(
		if doLog then
		(
			execString = "format \"" + bufferFormatString + "\" " + bufferArgString + "to:" + \
				pathString + ".logText"
			execute (execString)
			
			-- Add text to logging window	
			logOutput.text = logText as string
				
			-- Count number of newlines in log text, and resize logging textbox to match
			newlineCount = 0
			for i = 1 to logOutput.text.count do
				if logOutput.text[i] == "\n" then
					newlineCount += 1
			resize()		
			
			bufferFormatString = ""
			bufferArgString = ""
			bufferNumLogs = 0
		)
	),
	
	fn log level formatString argArray =
	(
		if doLog and (level <= logLevel) then
		(
			bufferFormatString += formatString + "\\n"	
			
			if classOf argArray == Array and argArray.count > 0 then
			(
				for i = 1 to argArray.count do
					if classOf argArray[i] == String then
						bufferArgString += "\"" + argArray[i] + "\" "
					else
						bufferArgString += argArray[i] as string + " "
			)
			
			if bufferNumLogs >= flushAt then flush()			
		)
	)
)



