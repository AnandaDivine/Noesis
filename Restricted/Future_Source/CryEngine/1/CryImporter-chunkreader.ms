-- Chunk reader for CryImporter
-- Copyright 2006 Takaro Pty. Ltd.
-- www.takaro.net

/* Notes:
		* Should typically be invoked with the following command:
				foo = ChunkReader chunkArchive:myChunkArchive log:myLoggingFunction
			
			The logging function is optional, and without specifying it, no logging will be performed.
			A valid function is the loggingUtil.log function, or any custom one with this signature:
				fn myLoggingFunction logLevel formatString argArray
*/

struct ChunkReader
(
	fn defaultLog logLevel formatString argArray = ok,
	
	chunkArchive,      -- CryChunkArchive
	log = defaultLog,  -- Function pointer to logging function
	bs,                -- BinStream
	fs,                -- FileStream
	
		
	fn isGeomFile high low = (high == FileType_GeomHigh) and (low == FileType_GeomLow),
				
	fn isAnimFile high low = (high == FileType_AnimHigh) and (low == FileType_AnimLow),
		
			
	---- Print to String Functions ----
		
	fn printColor s =
	(
		local out = StringStream ""
		format "R: %  G: %  B: %" s.r s.g s.b to:out
		out as string
	),
	
	fn printPoint s =
	(
		local out = StringStream ""
		format "X: %  Y: %  Z: %" s.x s.y s.z to:out
		out as string
	),
	
	fn printQuat s =
	(
		local out = StringStream ""
		format "X: %  Y: %  Z: %  W: %" s.x s.y s.z s.w to:out
		out as string
	),
	
	fn printVertex s =
	(
		local out = StringStream ""
		format "Position: (%)   Normal: (%)" (printPoint s.pos) (printPoint s.normal) to:out
		out as string
	),
	
	fn printFace s =
	(
		local out = StringStream ""
		format "v0: %  v1: %  v2: %  Material ID: %  Smoothing Group: %" \
						s.v0 s.v1 s.v2 s.matID s.smoothGroup to:out
		out as string
	),
	
	fn printTexFace s =
	(
		local out = StringStream ""
		format "t0: %  t1: %  t2: %" s.t0 s.t1 s.t2 to:out
		out as string
	),
	
	fn printMatrix44 s =
	(
		local out = StringStream ""
		format "%\n%\n%\n%" s.row1 s.row2 s.row3 s.row4 to:out
		out as string
	),
	
	fn printLink s =
	(
		local out = StringStream ""
		format "Bone ID: %  Offset: (%)  Blending: %" s.boneID (printPoint s.offset) s.blending to:out
		out as string
	),
	
	fn printVertAnimKey s =
	(
		local out = StringStream ""
		format "Key time: %  Vertices:" s.keyTime to:out
		for v in s.vertices do
			format " (%)" (printPoint v) to:out
		out as string
	),
	
	fn printRange s =
	(
		local out = StringStream ""
		format "%: start: %  end: %" s.name s.start s.end to:out
		out as string
	),
	
	fn printBonePhysics s =
	(
		local out = StringStream ""
		format "Mesh ID: %  Flags: %  Min: %  Max: %\n\tSpring [Angle: %, Tension: %]"  \
						s.meshId s.flags s.minimum s.maximum s.springAngle s.springTension to:out
		format "\n\tDamping: %  FrameMatrix: [% % %]"  \
						s.damping s.frameMatrix[1] s.frameMatrix[2] s.frameMatrix[3]to:out
		out as string
	),
	
	fn printBone s =
	(
		local out = StringStream ""
		format "Bone ID: %  Name: %  Parent ID: %  # children: %  Controller ID : % Misc: [%]"  \
						s.boneId s.name s.parentID s.numChildren s.ctrlID s.customProperty to:out
		format "\n\tPhysics: (%)" (printBonePhysics s.bonePhysics) to:out
		out as string
	),
	
	fn printBoneLightBind s =
	(
		local out = StringStream ""
		format "Light Chunk ID: %  Bone ID: %  Light offset: (%)  Light orientation: (%)"  \
						s.lightChunkID s.boneId (printPoint s.lightOffset) (printPoint s.rotLightOrientation)\
						to:out
		out as string
	),
	
	fn printMeshMorphTargetVertex s =
	(
		local out = StringStream ""
		format "Vertex ID: %  Target Point: (%)" s.vertexID (printPoint s.targetPoint) to:out
		out as string
	),
	
	fn printTexture s =
	(
		local out = StringStream ""
		
		-- Get type
		local type = stringTextureType s.type
				
		-- Get flags
		local flags = ""
		if (bit.and s.flags textureFlag_NoMipMap) != 0 then
			flags += "[NoMipMap]"
			
		format "Name: %  Type: %  Flags: %  Amount: %\n" s.name type flags s.amount to:out
		format "U [Tile: %, Mirror: %] V [Tile: %, Mirror: %]\n" s.uTile s.uMirror s.vTile s.vMirror \
						to:out
		format "Reflection [Nth frame: %, Size: %, Blur: %]\n" s.nthFrame s.refSize s.refBlur to:out
		format "Pos: U [Off: %, Scl: %, Rot: %] V [Off: %, Scl: %, Rot: %] W [Rot: %]\n" \
						s.uOffset s.uScale s.uRotation s.vOffset s.vScale s.vRotation s.wRotation to:out
		format "Controller IDs:\nU [Off: %, Scl: %, Rot: %]\nV [Off: %, Scl: %, Rot: %]\nW [Rot: %]"\
						s.uOffsetCtrlID s.uScaleCtrlID s.uRotationCtrlID s.vOffsetCtrlID s.vScaleCtrlID \
						s.vRotationCtrlID s.wRotationCtrlID to:out
		
		out as string
	),
	
	fn printSceneProp s =
	(
		local out = StringStream ""
		format "%: %" s.name s.value to:out
		out as string
	),
	
	fn printKey s =
	(
		local out = StringStream ""
		format "Time: %  Position: (%)  Log Rotation: (%)" \
						s.time (printPoint s.pos) (printPoint s.rotLog) to:out
		out as string
	),
	
	fn printLin1Key s =
	(
		local out = StringStream ""
		format "Time: %  Val: (%)" s.time s.val to:out
		out as string
	),
	
	fn printLin3Key s =
	(
		local out = StringStream ""
		format "Time: %  Val: (%)" s.time (printPoint s.val) to:out
		out as string
	),
	
	fn printLinQKey s =
	(
		local out = StringStream ""
		format "Time: %  Val: (%)" s.time (printQuat s.val) to:out
		out as string
	),
	
	fn printTCB1Key s =
	(
		local out = StringStream ""
		format "Time: %  Val: (%)\n" s.time s.val to:out
		format "Tension: %  Continuity: %  Bias: %  easeIn: %  easeOut: %" \
			s.t s.c s.b s.easeIn s.easeOut to:out
		out as string
	),
	
	fn printTCB3Key s =
	(
		local out = StringStream ""
		format "Time: %  Val: (%)\n" s.time (printPoint s.val) to:out
		format "Tension: %  Continuity: %  Bias: %  easeIn: %  easeOut: %" \
			s.t s.c s.b s.easeIn s.easeOut to:out
		out as string
	),
	
	fn printTCBQKey s =
	(
		local out = StringStream ""
		format "Time: %  Val: (%)\n" s.time (printQuat s.val) to:out
		format "Tension: %  Continuity: %  Bias: %  easeIn: %  easeOut: %" \
			s.t s.c s.b s.easeIn s.easeOut to:out
		out as string
	),
	
	fn printBez1Key s =
	(
		local out = StringStream ""
		format "Time: %  Val: (%) inTan: %  outTan: %" s.time s.val s.inTan s.outTan to:out
		out as string
	),
	
	fn printBez3Key s =
	(
		local out = StringStream ""
		format "Time: %  Val: (%)  inTan: (%)  outTan: (%)" s.time \
			(printPoint s.val) (printPoint s.inTan) (printPoint s.outTan) to:out
		out as string
	),
	
	fn printBezQKey s =
	(
		local out = StringStream ""
		format "Time: %  Val: (%)" s.time (printQuat s.val) to:out
		out as string
	),
	
	fn printBoneKey s =
	(
		local out = StringStream ""
		format "Time: %  AbsPos: (%)  RelPos: (%)  RelQuat: (%)" s.time \
			(printPoint s.abspos) (printPoint s.relpos) (printQuat s.relquat) to:out
		out as string
	),
	
	
	---- Print to Log Functions ----
	
	fn printChunkHeader header level =
	(		
		if (isKindOf header CryChunkHeader) == true then
		(
			if classOf level != Integer then level = 4
			local type = stringChunkType header.type
			log level "Chunk [Type: %, Version: %, Offset: %, ID: %]"	#(type, \
								(hexString header.version), (hexString header.fileOffset),	\
								(hexString header.chunkID))
		)
	),
	
	fn printMeshChunk chunk level =
	(
		if isKindOf chunk CryMeshChunk then
		(
			if classOf level != Integer then level = 4
			printChunkHeader chunk.header level
			log level "Verts: %  UVs: %  Faces: %  TexFaces: %  BoneLinks: %  VertCols: %  VertAnimID: %"\
								#(chunk.vertices.count, chunk.texVertices.count, chunk.faces.count, \
									chunk.texFaces.count, chunk.physique.count, chunk.vertexColors.count, \
									chunk.vertAnimID)
		)
	),
	
	fn printHelperChunk chunk level =
	(
		if isKindOf chunk CryHelperChunk then
		(
			if classOf level != Integer then level = 4
			printChunkHeader chunk.header level
			log level "Type: %  Size: (%)" #((stringHelperType chunk.type), (printPoint chunk.size))
		)
	),
	
	fn printVertAnimChunk chunk level =
	(
		if isKindOf chunk CryVertAnimChunk then
		(
			if classOf level != Integer then level = 4
			printChunkHeader chunk.header level
			log level "Mesh ID: %  Keys:" #(chunk.meshID)
			for x = 1 to chunk.keys.count do
				log level "%: %" #(x-1, (printVertAnimKey chunk.keys[x]))
		)
	),
	
	fn printBoneAnimChunk chunk level =
	(
		if isKindOf chunk CryBoneAnimChunk then
		(
			if classOf level != Integer then level = 4
			printChunkHeader chunk.header level
			log level "Bones: %" #(chunk.bones.count)
			for x = 1 to chunk.bones.count do
				log level "%: %" #(x-1, (printBone chunk.bones[x]))
		)
	),
	
	fn printBoneNameListChunk chunk level =
	(
		if isKindOf chunk CryBoneNameListChunk then
		(
			if classOf level != Integer then level = 4
			printChunkHeader chunk.header level
			for x = 1 to chunk.nameList.count do
				log level "%: %" #(x-1, chunk.nameList[x])
		)
	),
	
	fn printScenePropChunk chunk level =
	(
		if isKindOf chunk CryScenePropChunk then
		(
			if classOf level != Integer then level = 4
			printChunkHeader chunk.header level
			for x = 1 to chunk.props.count do
				log level "%: %" #(x-1, chunk.props[x])
		)
	),
	
	fn printLightChunk chunk level =
	(
		if isKindOf chunk CryLightChunk then
		(
			if classOf level != Integer then level = 4
			printChunkHeader chunk.header level
			
			-- Get type
			local type = stringLightType chunk.type
		
			log level "Type: %  On: %  Color: (%)  Intensity: %  Shadow: %"\
								#(type, chunk.isOn, (printColor chunk.color), chunk.intensity, chunk.shadow)
			log level "Spotlight [Direction: (%), Texture: (%)]" \
								#((printPoint chunk.spotDirection), chunk.spotTexture)											
			if chunk.useNearAttenuation then
				log level "Near Attenuation [Start: %, End: %]"\
								#(chunk.nearAttenuationStart, chunk.nearAttenuationEnd)
			if chunk.useFarAttenuation then
				log level "Far Attenuation [Start: %, End: %]"\
								#(chunk.farAttenuationStart, chunk.farAttenuationEnd)
			if (chunk.type == lightType_Spot) or (chunk.type == lightType_Direct) then
				log level "Hotspot: %  Falloff: %" #(chunk.hotSize, chunk.fallSize)					
		)
	),
	
	fn printNodeChunk chunk level =
	(
		if isKindOf chunk CryNodeChunk then
		(
			if classOf level != Integer then level = 4
			printChunkHeader chunk.header level
			
			log level "[%]  ObjectID: %  ParentID: (%)  MaterialID: %  # Children: %"\
								#(chunk.name, (hexString chunk.objectID), (hexString chunk.parentID), \
									(hexString chunk.materialID), chunk.childNodes.count)
			log level "Group [Head: %, Member: %]  Ctrl ID [pos: %, rot: %, scale: %]"\
								#(chunk.isGroupHead, chunk.isGroupMember, \
									chunk.posCtrlID, chunk.rotCtrlID, chunk.scaleCtrlID)							
			log level "Trans Matrix:\n%\nPosition: %\nRotation: %\nScale: %" \
								#((printMatrix44 chunk.transMatrix), (printPoint chunk.position), \
									(printQuat chunk.rotation), (printPoint chunk.scale))											
			if chunk.property != "" then
				log level "Property: (%)" #(chunk.property)
			if chunk.childNodes.count > 0 then
			(
				log level "Children:" #()
					for i = 1 to chunk.childNodes.count do
						log level "\t%: %" #(i, chunk.childNodes[i])
			)
		)
	),
	
	fn printMaterialChunk chunk level =
	(
		if isKindOf chunk CryMaterialChunk then
		(
			if classOf level != Integer then level = 4
			printChunkHeader chunk.header level
			
			-- Get type
			local type = stringMaterialType chunk.type
		
			log level "[%]  Shader: [%]  Surface: [%]  Type: %  AlphaTest: %"	\
			#(chunk.name, chunk.shaderName, chunk.surfaceName, type, chunk.alphaTest)
			if chunk.type == materialType_Multi then
			(
				local text = "Children: "
				for i = 1 to chunk.children.count do
						text += " " + (hexString chunk.children[i])	
				log level text #()
			)
			else
			(	
				-- Get flags
				local flags = ""
				if (bit.and chunk.flags materialFlag_Wire) != 0 then
					flags += "[Wire]"
				if (bit.and chunk.flags materialFlag_2Sided) != 0 then
					flags += "[TwoSided]"
				if (bit.and chunk.flags materialFlag_Facemap) != 0 then
					flags += "[FaceMap]"
				if (bit.and chunk.flags materialFlag_Faceted) != 0 then
					flags += "[Faceted]"
				if (bit.and chunk.flags materialFlag_Additive) != 0 then
					flags += "[Additive]"
				if (bit.and chunk.flags materialFlag_Subtractive) != 0 then
					flags += "[Subtractive]"
				if (bit.and chunk.flags materialFlag_CryShader) != 0 then
					flags += "[CryShader]"
				if (bit.and chunk.flags materialFlag_Physicalize) != 0 then
					flags += "[Physicalize]"
				if (bit.and chunk.flags materialFlag_AdditiveDecal) != 0 then
					flags += "[AdditiveDecal]"
				if (bit.and chunk.flags materialFlag_UseGlossiness) != 0 then
					flags += "[UseGlossiness]"
							
				log level "Diffuse: (%)  Specular: (%)  Ambient: (%)" \
							#((printColor chunk.diffuse), (printColor chunk.specular), (printColor chunk.ambient))
				log level "Specular [Level: %, Shininess: %]  Self Illum: %  Opacity: %" \
								#(chunk.specularLevel, chunk.specularShininess, chunk.selfIllumination, \
								chunk.opacity)
				log level "Flags: [%]  Dynamic [Bounce: %, Static Friction: %, Sliding Friction: %]" \
								#(flags, chunk.dynamicBounce, chunk.dynamicStaticFriction, \
								chunk.dynamicSlidingFriction)
								
				if chunk.texDiffuse != undefined then
					log level "\nDiffuse Texture:\n%" #(printTexture chunk.texDiffuse)
				if chunk.texSpecular != undefined then
					log level "\nSpecular Texture:\n%" #(printTexture chunk.texSpecular)
				if chunk.texAmbient != undefined then
					log level "\nAmbient Texture:\n%" #(printTexture chunk.texAmbient)
				if chunk.texOpacity != undefined then
					log level "\nOpacity Texture:\n%" #(printTexture chunk.texOpacity)
				if chunk.texBump != undefined then
					log level "\nBump Texture:\n%" #(printTexture chunk.texBump)
				if chunk.texGloss != undefined then
					log level "\nGloss Texture:\n%" #(printTexture chunk.texGloss)
				if chunk.texFilter != undefined then
					log level "\nFilter (Normal Map) Texture:\n%" #(printTexture chunk.texFilter)
				if chunk.texReflection != undefined then
					log level "\nReflection Texture:\n%" #(printTexture chunk.texReflection)
				if chunk.texSubSurface != undefined then
					log level "\nSubSurface Texture:\n%" #(printTexture chunk.texSubSurface)
				if chunk.texDetail != undefined then
					log level "\nDetail Texture:\n%" #(printTexture chunk.texDetail)			
			)
		)
	),
	
	fn printControllerChunk chunk level =
	(
		if isKindOf chunk CryControllerChunk then
		(
			if classOf level != Integer then level = 4
			printChunkHeader chunk.header level
			log level "Controller ID: %" #(chunk.ctrlID)
				
			if (chunk.header.version == 0x0826) then
			(
				-- Get type
				local type = stringControllerType chunk.type
		
				-- Get flags
				local flags = ""
				if (bit.and chunk.flags controllerFlag_ORTCycle) != 0 then
					flags += "[ORTCycle]"
				if (bit.and chunk.flags controllerFlag_ORTLoop) != 0 then
					flags += "[ORTLoop]"
				
				local tpf = chunkArchive.getTicksPerFrame()
				local	text = StringStream ""
				for i = 1 to chunk.keys.count do
				(
					if (mod i 25) == 1 then format "\n\t" to:text
					format " %" (chunk.keys[i].time/tpf as Integer) to:text
				)
				log level "% % Keys at frames (ticks/%):%" #(chunk.keys.count, type, tpf, text as String)					
				log level "Flags: [%]" #(flags)	
			)
			else if (chunk.header.version == 0x0827) then
			(
				local tpf = chunkArchive.getTicksPerFrame()
				local	text = StringStream ""
				for i = 1 to chunk.keys.count do
				(
					if (mod i 25) == 1 then format "\n\t" to:text
					format " %" (chunk.keys[i].time/tpf as Integer) to:text
				)
				log level "% Keys at frames (ticks/%):%" #(chunk.keys.count, tpf, text as String)
			)
		)
	),
	
	fn printTimingChunk chunk level =
	(
		if isKindOf chunk CryTimingChunk then
		(
			if classOf level != Integer then level = 4
			printChunkHeader chunk.header level
			log level "% seconds/tick   % ticks/frame" #(chunk.secsPerTick, chunk.ticksPerFrame)
			log level "%" #(printRange chunk.globalRange)
			for subrange in chunk.subRanges do
				log level "Subrange: %" #(printRange subrange)
		)
	),
	
	fn printBoneLightBindingChunk chunk level =
	(
		if isKindOf chunk CryBoneLightBindingChunk then
		(
			if classOf level != Integer then level = 4
			printChunkHeader chunk.header level
			log level "% Bindings:" #(chunk.boneLightBinds.count)
			for x in chunk.boneLightBinds do
				log level "\t%" #(printBoneLightBind x)
		)
	),
	
	fn printMeshMorphTargetChunk chunk level =
	(
		if isKindOf chunk CryMeshMorphTargetChunk then
		(
			if classOf level != Integer then level = 4
			printChunkHeader chunk.header level
			log level "[%] Mesh ID: %" #(chunk.name, chunk.meshChunkID)
			
			local text = StringStream ""
			for i = 1 to chunk.targetVertices.count do
			(
				if (mod i 20) == 1 then format "\n\t" to:text
				format "% " chunk.targetVertices[i].vertexID to:text
			)
			log level "% Morphed Vertices: %" #(chunk.targetVertices.count, text as String)
		)
	),
	
	fn printBoneInitialPosChunk chunk level =
	(
		if isKindOf chunk CryBoneInitialPosChunk then
		(
			if classOf level != Integer then level = 4
			printChunkHeader chunk.header level
			log level "Mesh ID: %    % bones" #(chunk.meshChunkID, chunk.initialPositions.count)
		)
	),
	
	fn printSourceInfoChunk chunk level =
	(
		if isKindOf chunk CrySourceInfoChunk then
		(
			if classOf level != Integer then level = 4
			printChunkHeader chunk.header level
			log level "Source file: %\nDate: %\nUser: %" #(chunk.sourceFile, chunk.date, chunk.user)
		)
	),
	
	fn printChunk chunk level =
	(
		-- Call appropriate function based on the chunk type
		case chunk.header.type of
		(
			0x0000: printMeshChunk chunk level
			0x0001: printHelperChunk chunk level
			0x0002: printVertAnimChunk chunk level
			0x0003: printBoneAnimChunk chunk level
			0x0004: log 3 "Obsolete chunk type in chunk header" #()
			0x0005: printBoneNameListChunk chunk level
			0x0006: log 3 "Obsolete chunk type in chunk header" #()
			0x0007: log 3 "Obsolete chunk type in chunk header" #()
			0x0008: printScenePropChunk chunk level
			0x0009: printLightChunk chunk level
			0x000A: log 3 "Non-implemented chunk type in chunk header" #()
			0x000B: printNodeChunk chunk level
			0x000C: printMaterialChunk chunk level
			0x000D: printControllerChunk chunk level
			0x000E: printTimingChunk chunk level
			0x000F: printBoneMeshChunk chunk level
			0x0010: printBoneLightBindingChunk chunk level
			0x0011: printMeshMorphTargetChunk chunk level
			0x0012: printBoneInitialPosChunk chunk level
			0x0013: printSourceInfoChunk chunk level
			default: log 2 "Invalid chunk type in chunk header"  #()
		)	
	),
	
	fn printChunks =
	(		
		if (isKindOf chunkArchive CryChunkArchive) == false then
			return "Not initialised with a valid chunk archive"
			
		log 1 "\n----------------------------------------------------------" #()
		log 1 "Chunk Archive Contents:\nNumber of chunks: %\n" #(chunkArchive.numChunks)
		
		if chunkArchive.meshChunks.count > 0 then
		(
			log 1 "Mesh chunks: %" #(chunkArchive.meshChunks.count)
			for chunk in chunkArchive.meshChunks do
			(
				log 2 "-------------------------------------------" #()
				printMeshChunk chunk 2
			)
			log 2 "-------------------------------------------\n" #()
		)
		if chunkArchive.helperChunks.count > 0 then
		(
			log 1 "Helper chunks: %" #(chunkArchive.helperChunks.count)
			for chunk in chunkArchive.helperChunks do
			(
				log 2 "-------------------------------------------" #()
				printHelperChunk chunk 2
			)
			log 2 "-------------------------------------------\n" #()
		)
		if chunkArchive.vertAnimChunks.count > 0 then
		(
			log 1 "VertAnim chunks: %" #(chunkArchive.vertAnimChunks.count)
			for chunk in chunkArchive.vertAnimChunks do
			(
				log 2 "-------------------------------------------" #()
				printVertAnimChunk chunk 2
			)
			log 2 "-------------------------------------------\n" #()
		)
		if chunkArchive.boneAnimChunks.count > 0 then
		(
			log 1 "BoneAnim chunks: %" #(chunkArchive.boneAnimChunks.count)
			for chunk in chunkArchive.boneAnimChunks do
			(
				log 2 "-------------------------------------------" #()
				printBoneAnimChunk chunk 2
			)
			log 2 "-------------------------------------------\n" #()
		)
		if chunkArchive.boneNameListChunks.count > 0 then
		(
			log 1 "BoneNameList chunks: %" #(chunkArchive.boneNameListChunks.count)
			for chunk in chunkArchive.boneNameListChunks do
			(
				log 2 "-------------------------------------------" #()
				printBoneNameListChunk chunk 2
			)
			log 2 "-------------------------------------------\n" #()
		)
		if chunkArchive.scenePropChunks.count > 0 then
		(
			log 1 "SceneProp chunks: %" #(chunkArchive.scenePropChunks.count)
			for chunk in chunkArchive.scenePropChunks do
			(
				log 2 "-------------------------------------------" #()
				printScenePropChunk chunk 2
			)
			log 2 "-------------------------------------------\n" #()
		)
		if chunkArchive.lightChunks.count > 0 then
		(
			log 1 "Light chunks: %" #(chunkArchive.lightChunks.count)
			for chunk in chunkArchive.lightChunks do
			(
				log 2 "-------------------------------------------" #()
				printLightChunk chunk 2
			)
			log 2 "-------------------------------------------\n" #()
		)
		if chunkArchive.nodeChunks.count > 0 then
		(
			log 1 "Node chunks: %" #(chunkArchive.nodeChunks.count)
			for chunk in chunkArchive.nodeChunks do
			(
				log 2 "-------------------------------------------" #()
				printNodeChunk chunk 2
			)
			log 2 "-------------------------------------------\n" #()
		)
		if chunkArchive.materialChunks.count > 0 then
		(
			log 1 "Material chunks: %" #(chunkArchive.materialChunks.count)
			for chunk in chunkArchive.materialChunks do
			(
				log 2 "-------------------------------------------" #()
				printMaterialChunk chunk 2
			)
			log 2 "-------------------------------------------\n" #()
		)
		if chunkArchive.controllerChunks.count > 0 then
		(
			log 1 "Controller chunks: %" #(chunkArchive.controllerChunks.count)
			for chunk in chunkArchive.controllerChunks do
			(
				log 2 "-------------------------------------------" #()
				printControllerChunk chunk 2
			)
			log 2 "-------------------------------------------\n" #()
		)
		if chunkArchive.timingChunks.count > 0 then
		(
			log 1 "Timing chunks: %" #(chunkArchive.timingChunks.count)
			for chunk in chunkArchive.timingChunks do
			(
				log 2 "-------------------------------------------" #()
				printTimingChunk chunk 2
			)
			log 2 "-------------------------------------------\n" #()
		)
		if chunkArchive.boneMeshChunks.count > 0 then
		(
			log 1 "BoneMesh chunks: %" #(chunkArchive.boneMeshChunks.count)
			for chunk in chunkArchive.boneMeshChunks do
			(
				log 2 "-------------------------------------------" #()
				printMeshChunk chunk 2
			)
			log 2 "-------------------------------------------\n" #()
		)
		if chunkArchive.boneLightBindingChunks.count > 0 then
		(
			log 1 "BoneLightBinding chunks: %" #(chunkArchive.boneLightBindingChunks.count)
			for chunk in chunkArchive.boneLightBindingChunks do
			(
				log 2 "-------------------------------------------" #()
				printBoneLightBindingChunk chunk 2
			)
			log 2 "-------------------------------------------\n" #()
		)
		if chunkArchive.meshMorphTargetChunks.count > 0 then
		(
			log 1 "MeshMorphTarget chunks: %" #(chunkArchive.meshMorphTargetChunks.count)
			for chunk in chunkArchive.meshMorphTargetChunks do
			(
				log 2 "-------------------------------------------" #()
				printMeshMorphTargetChunk chunk 2
			)
			log 2 "-------------------------------------------\n" #()
		)
		if chunkArchive.boneInitialPosChunks.count > 0 then
		(
			log 1 "BoneInitialPos chunks: %" #(chunkArchive.boneInitialPosChunks.count)
			for chunk in chunkArchive.boneInitialPosChunks do
			(
				log 2 "-------------------------------------------" #()
				printBoneInitialPosChunk chunk 2
			)
			log 2 "-------------------------------------------\n" #()
		)
		if chunkArchive.sourceInfoChunks.count > 0 then
		(
			log 1 "SourceInfo chunks: %" #(chunkArchive.sourceInfoChunks.count)
			for chunk in chunkArchive.sourceInfoChunks do
			(
				log 2 "-------------------------------------------" #()
				printSourceInfoChunk chunk 2
			)
			log 2 "-------------------------------------------\n" #()
		)
	),
	
	
	---- Reading Functions ----
	
	fn readRange =
	(
		local temp = CryRange()
		
		local p = ftell	bs
		temp.name = ReadString bs
		fseek bs (p + 32) #seek_set  -- skip to end of allocated string space
			
		temp.start = ReadLong bs
		temp.end = ReadLong bs
		
		temp
	),
	
	fn readPoint =
	(
		local temp = Point3 (ReadFloat bs) (ReadFloat bs) (ReadFloat bs)
		
		-- Do ugly check for invalid numbers since bit.isNaN() only exists in max 8
		--for i = 1 to 3 do
		--if (findstring (temp[i] as string) "NAN") != undefined then temp[i] = 0.0
	
		temp
	),
	
	fn readQuat =
	(
		local temp = quat (ReadFloat bs) (ReadFloat bs) (ReadFloat bs) (ReadFloat bs)
		temp
	),
	
	fn readVertex =
	(
		local temp = CryVertex()
		
		temp.pos = ReadPoint()
		temp.normal = ReadPoint()
		
		temp
	),
	
	fn readFace =
	(
		local temp = CryFace()
		
		temp.v0 = ReadLong bs #unsigned
		temp.v1 = ReadLong bs #unsigned
		temp.v2 = ReadLong bs #unsigned
		temp.matID = ReadLong bs #unsigned
		temp.smoothGroup = ReadLong bs #unsigned
		
		temp
	),
	
	fn readTexFace =
	(
		local temp = CryTexFace()
		
		temp.t0 = ReadLong bs #unsigned
		temp.t1 = ReadLong bs #unsigned
		temp.t2 = ReadLong bs #unsigned
		
		temp
	),
	
	fn readLink =
	(
		local temp = CryLink()
		
		temp.boneID = ReadLong bs
		temp.offset = ReadPoint()
		temp.blending = ReadFloat bs
		
		temp
	),
	
	fn readBoneLinks id =
	(
		local temp = CryBoneLinks()
		
		temp.vertexID = id
		local numLinks = ReadLong bs
		for x = 1 to numLinks do
			append temp.links (readLink())
		
		temp
	),
	
	fn readColor =
	(
		local temp = color (ReadByte bs #unsigned) (ReadByte bs #unsigned) (ReadByte bs #unsigned)
		temp
	),
	
	fn readVertAnimKey numVerts =
	(
		local temp = CryVertAnimKey()
		
		temp.keyTime = ReadLong bs
		for x = 1 to numVerts do
		(
			append temp.vertices (readPoint())
			fseek bs 12 #seek_cur -- skip normal
		)
		temp
	),
	
	fn readBonePhysics =
	(
		local temp = CryBonePhysics()
		
		temp.meshID = ReadLong bs
		temp.flags = ReadLong bs #unsigned
		temp.minimum = readPoint()
		temp.maximum = readPoint()
		temp.springAngle = readPoint()
		temp.springTension = readPoint()
		temp.damping = readPoint()
		temp.frameMatrix[1] = readPoint()
		temp.frameMatrix[2] = readPoint()
		temp.frameMatrix[3] = readPoint()
					
		temp
	),
	
	fn readBone =
	(
		local temp = CryBone()
		
		temp.boneID = ReadLong bs
		temp.parentID = ReadLong bs
		temp.numChildren = ReadLong bs
		local low = ReadShort bs #unsigned
		local high = ReadShort bs #unsigned
		temp.ctrlID = (bit.intAsHex high) + (bit.intAsHex low)
				
		local p = ftell	bs
		temp.customProperty = ReadString bs
		fseek bs (p + 32) #seek_set  -- skip to end of allocated string space
		
		temp.bonePhysics = readBonePhysics()
			
		temp
	),
	
	fn readMatrix44 =
	(
		local temp = CryMatrix44()
		
		temp.row1 = [ReadFloat bs, ReadFloat bs, ReadFloat bs, ReadFloat bs]
		temp.row2 = [ReadFloat bs, ReadFloat bs, ReadFloat bs, ReadFloat bs]
		temp.row3 = [ReadFloat bs, ReadFloat bs, ReadFloat bs, ReadFloat bs]
		temp.row4 = [ReadFloat bs, ReadFloat bs, ReadFloat bs, ReadFloat bs]
					
		temp
	),
	
	fn readSceneProp =
	(
		local temp = CrySceneProp()
		
		local p = ftell	bs
		temp.name = ReadString bs
		p += 32
		fseek bs p #seek_set  -- skip to end of allocated string space
		temp.value = ReadString bs
		fseek bs (p + 64) #seek_set  -- skip to end of allocated string space
		
		temp
	),
	
	fn readTexture chunkVersion =
	(
		local temp = CryTexture()
		
		local p = ftell	bs
		temp.name = ReadString bs
		
		-- Max length of name differs between v745 and v746 material chunks
		if chunkVersion == 0x0746 then 
			fseek bs (p + 128) #seek_set  -- skip to end of allocated string space
		else
			fseek bs (p + 32) #seek_set  -- skip to end of allocated string space
		
		if temp.name == "" then
		(
			-- no name means an undefined texture, so let's skip it
			if chunkVersion == 0x0746 then
				fseek bs 108 #seek_cur  -- skip to end of texture struct
			else
				fseek bs 76 #seek_cur  -- skip to end of texture struct
			
			return undefined
		)
		
		temp.type = ReadByte bs
		temp.flags = ReadByte bs
		temp.amount = ReadByte bs
		
		-- Reserved space differs between v745 and v746 material chunks
		if chunkVersion == 0x0746 then 
			fseek bs 32 #seek_cur  -- skip to end of reserved space
		else
			fseek bs 1 #seek_cur  -- skip to end of reserved space
		
		local uTile = ReadByte bs
		local uMirror = ReadByte bs
		local vTile = ReadByte bs
		local vMirror = ReadByte bs
		if chunkVersion == 0x0746 then
			fseek bs 1 #seek_cur  -- skip to end of 4 byte boundary
		
		temp.nthFrame = ReadLong bs
		temp.refSize = ReadLong bs
		temp.refBlur = ReadFloat bs
		
		temp.uOffset = ReadFloat bs
		temp.uScale = ReadFloat bs
		temp.uRotation = ReadFloat bs
		temp.vOffset = ReadFloat bs
		temp.vScale = ReadFloat bs
		temp.vRotation = ReadFloat bs
		temp.wRotation = ReadFloat bs
		
		local low = ReadShort bs #unsigned
		local high = ReadShort bs #unsigned
		temp.uOffsetCtrlID = (bit.intAsHex high) + (bit.intAsHex low)
		low = ReadShort bs #unsigned
		high = ReadShort bs #unsigned
		temp.uScaleCtrlID = (bit.intAsHex high) + (bit.intAsHex low)
		low = ReadShort bs #unsigned
		high = ReadShort bs #unsigned
		temp.uRotationCtrlID = (bit.intAsHex high) + (bit.intAsHex low)
		low = ReadShort bs #unsigned
		high = ReadShort bs #unsigned
		temp.vOffsetCtrlID = (bit.intAsHex high) + (bit.intAsHex low)
		low = ReadShort bs #unsigned
		high = ReadShort bs #unsigned
		temp.vScaleCtrlID = (bit.intAsHex high) + (bit.intAsHex low)
		low = ReadShort bs #unsigned
		high = ReadShort bs #unsigned
		temp.vRotationCtrlID = (bit.intAsHex high) + (bit.intAsHex low)
		low = ReadShort bs #unsigned
		high = ReadShort bs #unsigned
		temp.wRotationCtrlID = (bit.intAsHex high) + (bit.intAsHex low)
		
		if uTile > 0 then temp.uTile = true else temp.uTile = false
		if uMirror > 0 then temp.uMirror = true else temp.uMirror = false
		if vTile > 0 then temp.vTile = true else temp.vTile = false
		if vMirror > 0 then temp.vMirror = true else temp.vMirror = false
		
		temp
	),
	
	fn readBoneLightBind =
	(
		local temp = CryBoneLightBind()
		
		temp.lightChunkID = ReadLong bs #unsigned
		temp.boneID = ReadLong bs #unsigned
		temp.lightOffset = readPoint()
		temp.rotLightOrientation = readPoint()
			
		temp
	),
	
	fn readMeshMorphTargetVertex =
	(
		local temp = CryMeshMorphTargetVertex()
		
		temp.vertexID = ReadLong bs #unsigned
		temp.targetPoint = readPoint()
			
		temp
	),
	
	fn readKey =
	(
		local temp = CryKey()
		
		temp.time = ReadLong bs
		temp.pos = readPoint()
		temp.rotLog = readPoint()
		
		temp
	),
	
	fn readLin1Key =
	(
		local temp = CryLin1Key()
		
		temp.time = ReadLong bs
		temp.val = ReadFloat bs
		
		temp
	),
	
	fn readLin3Key =
	(
		local temp = CryLin3Key()
		
		temp.time = ReadLong bs
		temp.val = ReadPoint()
		
		temp
	),
	
	fn readLinQKey =
	(
		local temp = CryLinQKey()
		
		temp.time = ReadLong bs
		temp.val = ReadQuat()
		
		temp
	),
	
	fn readTCB1Key =
	(
		local temp = CryTCB1Key()
		
		temp.time = ReadLong bs
		temp.val = ReadFloat bs
		temp.t = ReadFloat bs
		temp.c = ReadFloat bs
		temp.b = ReadFloat bs
		temp.easeTo = ReadFloat bs
		temp.easeFrom = ReadFloat bs
		
		temp
	),
	
	fn readTCB3Key =
	(
		local temp = CryTCB3Key()
		
		temp.time = ReadLong bs
		temp.val = ReadPoint()
		temp.t = ReadFloat bs
		temp.c = ReadFloat bs
		temp.b = ReadFloat bs
		temp.easeTo = ReadFloat bs
		temp.easeFrom = ReadFloat bs
		
		temp
	),
	
	fn readTCBQKey =
	(
		local temp = CryTCBQKey()
		
		temp.time = ReadLong bs
		temp.val = ReadQuat()
		temp.t = ReadFloat bs
		temp.c = ReadFloat bs
		temp.b = ReadFloat bs
		temp.easeTo = ReadFloat bs
		temp.easeFrom = ReadFloat bs
		
		temp
	),
	
	fn readBez1Key =
	(
		local temp = CryBez1Key()
		
		temp.time = ReadLong bs
		temp.val = ReadFloat bs
		temp.inTan = ReadFloat bs
		temp.outTan = ReadFloat bs
		
		temp
	),
	
	fn readBez3Key =
	(
		local temp = CryBez3Key()
		
		temp.time = ReadLong bs
		temp.val = ReadPoint()
		temp.inTan = ReadPoint()
		temp.outTan = ReadPoint()
		
		temp
	),
	
	fn readBezQKey =
	(
		local temp = CryBezQKey()
		
		temp.time = ReadLong bs
		temp.val = ReadQuat()
		
		temp
	),
	
	fn readBoneKey =
	(
		local temp = CryBoneKey()
		
		temp.time = ReadLong bs
		temp.abspos = ReadPoint()
		temp.relpos = ReadPoint()
		temp.relquat = ReadQuat()
		
		temp
	),	
	
	
	fn readChunkHeader =
	(
		local header = CryChunkHeader()
		header.type = ReadShort bs #unsigned
		fseek bs 2 #seek_cur   -- skip low word of chunk type
		header.version = ReadLong bs #unsigned
		header.fileOffset = ReadLong bs #unsigned
		header.chunkID = ReadLong bs #unsigned
		
		header
	),
	
	fn readMeshChunk header nextChunkPos isBoneMesh:false =
	(
		fseek bs header.fileOffset #seek_set	
		fseek bs size_CHUNK_HEADER #seek_cur -- skip past header
		
		local temp = CryMeshChunk()
		temp.header = header
			
		-- Read in chunk descriptor data
		local hasBoneInfo = ReadByte bs
		local hasVertexColors = ReadByte bs
		fseek bs 2 #seek_cur -- skip two bytes (due to 4 byte boundaries I'm guessing)
		local numVerts = ReadLong bs
		local numTVerts = ReadLong bs
		local numFaces = ReadLong bs
		temp.vertAnimID = ReadLong bs
		
		local numTFaces = 0
		if (numTVerts > 0) then -- and (numVerts != numTVerts) then
			numTFaces = numFaces
				
		if hasBoneInfo > 0 then temp.hasBoneInfo = true else temp.hasBoneInfo = false
		if hasVertexColors > 0 then temp.hasVertexColors = true else temp.hasVertexColors = false
		
		-- Read in vertices
		log 4 "\tReading in % vertices for mesh chunk" #(numVerts)
		if numVerts > 0 then
		(
			for x = 1 to numVerts do
				append temp.vertices (readVertex())
		)	
			
		-- Read in faces
		log 4 "\tReading in % faces for mesh chunk" #(numFaces)
		if numFaces > 0 then
		(
			for x = 1 to numFaces do
				append temp.faces (readFace())
		)	
		
		-- Read in texture vertices
		log 4 "\tReading in % texture vertices for mesh chunk" #(numTVerts)
		if numTVerts > 0 then
		(
			for x = 1 to numTVerts do
				append temp.texVertices (Point3 (ReadFloat bs) (ReadFloat bs) 0.0)
		)	
		
		-- Read in texture faces
		log 4 "\tReading in % texture faces for mesh chunk" #(numTFaces)
		if numTFaces > 0 then
		(
			for x = 1 to numTFaces do
				append temp.texFaces (readTexFace())
		)	
				
		-- Read in physique data
		local numLinks = 0
		if temp.hasBoneInfo == true then
			numLinks = numVerts
		log 4 "\tReading in % bone links for mesh chunk" #(numLinks)
		if numLinks > 0 then
		(
			-- Check if we've reached end of chunk unexpectedly 
			local curPos = ftell bs
			if (curPos + size_BONE_LINK > nextChunkPos) then
			(
				temp.hasBoneInfo = false	
			) 
			else 
			-- Read in bone links
			(
				for x = 1 to numLinks do
					append temp.physique (readBoneLinks (x-1))
			)
		)	
		
		-- Read in vertex color data
		local numColors = 0
		if temp.hasVertexColors == true then
			numColors = numVerts -- According to doco this should be numTVerts, but
			                     -- cgfdump uses numVerts, and cgf files appear to reflect this
		log 4 "\tReading in % vertex colors for mesh chunk" #(numColors)
		
		temp.hasVertexColors = false
		if numColors > 0 then
		(
			for x = 1 to numColors do
				append temp.vertexColors (readColor())
		)	
		
		chunkArchive.add temp 	
	),
		
	fn readHelperChunk header nextChunkPos =
	(
		fseek bs header.fileOffset #seek_set	
		fseek bs size_CHUNK_HEADER #seek_cur -- skip past header
		
		local temp = CryHelperChunk()
		temp.header = header
			
		-- Read in chunk descriptor data
		temp.type = ReadLong bs
		temp.size = readPoint()
					
		chunkArchive.add temp
	),
		
	fn readVertAnimChunk header nextChunkPos =
	(
		fseek bs header.fileOffset #seek_set	
		fseek bs size_CHUNK_HEADER #seek_cur -- skip past header
		
		local temp = CryVertAnimChunk()
		temp.header = header
			
		-- Read in chunk descriptor data
		temp.meshID = ReadLong bs
		local numKeys = ReadLong bs
		local numVerts = ReadLong bs
		local numFaces = ReadLong bs
		
		log 4 "\tReading in % keys for vert anim chunk" #(numKeys)
		if numKeys > 0 then
		(
			for x = 1 to numKeys do
				append temp.keys (readVertAnimKey numVerts)
		)	
			
		chunkArchive.add temp	
	),
		
	fn readBoneAnimChunk header nextChunkPos =
	(
		fseek bs header.fileOffset #seek_set	
		fseek bs size_CHUNK_HEADER #seek_cur -- skip past header
		
		local temp = CryBoneAnimChunk()
		temp.header = header
			
		-- Read in chunk descriptor data
		local numBones = ReadLong bs
				
		log 4 "\tReading in % bones for bone anim chunk" #(numBones)
		if numBones > 0 then
		(
			for x = 1 to numBones do
			(
				local b = readBone()
				append temp.bones b
					
				-- check if bone has flag set to indicate that we should build a separate physics mesh
				if b.bonePhysics.flags != -1 then chunkArchive.separatePhysicsMesh = true
			)
		)	
			
		chunkArchive.add temp	
	),
	
	fn readBoneNameListChunk header nextChunkPos =
	(
		fseek bs header.fileOffset #seek_set	
		
		local temp = CryBoneNameListChunk()
		temp.header = header
			
		-- Different treatment between version 744 and 745 chunks
		if header.version == 0x0745 then
		(	
			-- Read in chunk descriptor data
			local numEntities = ReadLong bs #unsigned
			log 4 "\tReading in % names for bone name list chunk" #(numEntities)
			if numEntities > 0 then
				for x = 1 to numEntities do
					append temp.nameList (ReadString bs)
		)
		else
		(
			fseek bs size_CHUNK_HEADER #seek_cur -- skip past header
				
			-- Read in chunk descriptor data
			local numEntities = ReadLong bs #unsigned
			log 4 "\tReading in % names for bone name list chunk" #(numEntities)
			if numEntities > 0 then
			(
				for x = 1 to numEntities do
				(
					local p = ftell	bs
					append temp.nameList (ReadString bs)
					p += 64
					fseek bs p #seek_set -- skip to end of 64 byte string buffer
				)
			)	
		)	
		-- add names to boneanimlist chunk if possible
		if chunkArchive.boneAnimChunks.count > 0 then
		(
			local b = chunkArchive.boneAnimChunks[1]
			for i = 1 to temp.nameList.count do
				b.bones[i].name = temp.nameList[i]
		)
				
		chunkArchive.add temp	
	),
		
	fn readScenePropChunk header nextChunkPos =
	(
		fseek bs header.fileOffset #seek_set	
		fseek bs size_CHUNK_HEADER #seek_cur -- skip past header
		
		local temp = CryScenePropChunk()
		temp.header = header
			
		-- Read in chunk descriptor data
		local numProps = ReadLong bs
				
		log 4 "\tReading in % props for scene props chunk" #(numProps)
		if numProps > 0 then
		(
			for x = 1 to numProps do
				append temp.props (readSceneProp())
		)	
			
		chunkArchive.add temp	
	),
		
	fn readLightChunk header nextChunkPos =
	(
		fseek bs header.fileOffset #seek_set	
		fseek bs size_CHUNK_HEADER #seek_cur -- skip past header
		
		local temp = CryLightChunk()
		temp.header = header
			
		-- Read in chunk descriptor data
		temp.type = ReadLong bs
		local isOn = ReadByte bs -- No need to skip to end of 4 byte boundary since Color is 3 bytes
		temp.color = readColor()
		temp.intensity = ReadFloat bs	
		temp.hotSize = ReadFloat bs	
		temp.fallSize = ReadFloat bs	
		
		local una = ReadByte bs
		fseek bs 3 #seek_cur -- skip to 4 byte boundary
		temp.nearAttenuationStart = ReadFloat bs	
		temp.nearAttenuationEnd = ReadFloat bs	
		
		local ufa = ReadByte bs
		fseek bs 3 #seek_cur -- skip to 4 byte boundary
		temp.farAttenuationStart = ReadFloat bs	
		temp.farAttenuationEnd = ReadFloat bs	
		
		local shadow = ReadByte bs
		fseek bs 3 #seek_cur -- skip to 4 byte boundary
		temp.spotDirection = readPoint()
		
		local p = ftell	bs
		temp.spotTexture = ReadString bs
		fseek bs (p + 256) #seek_set  -- skip to end of allocated string space
		
		if isOn > 0 then temp.isOn = true else temp.isOn = false
		if una > 0 then temp.useNearAttenuation = true else temp.useNearAttenuation = false
		if ufa > 0 then temp.useFarAttenuation = true else temp.useFarAttenuation = false
		if shadow > 0 then temp.shadow = true else temp.shadow = false
		
		chunkArchive.add temp 	
	),
		
	fn readNodeChunk header nextChunkPos =
	(
		fseek bs header.fileOffset #seek_set	
		fseek bs size_CHUNK_HEADER #seek_cur -- skip past header
		
		local temp = CryNodeChunk()
		temp.header = header
			
		-- Read in chunk descriptor data
		local p = ftell	bs
		temp.name = ReadString bs
		fseek bs (p + 64) #seek_set  -- skip to end of allocated string space
		temp.objectID = ReadLong bs
		temp.parentID = ReadLong bs
		local numChildren = ReadLong bs
		temp.materialID = ReadLong bs
		local igh = ReadByte bs
		local igm = ReadByte bs
		fseek bs 2 #seek_cur -- skip to 4 byte boundary
		
		temp.transMatrix = readMatrix44()
		temp.position = readPoint()
		temp.rotation = readQuat()
		temp.scale = readPoint()
		
		local low = ReadShort bs #unsigned
		local high = ReadShort bs #unsigned
		temp.posCtrlID = (bit.intAsHex high) + (bit.intAsHex low)
		low = ReadShort bs #unsigned
		high = ReadShort bs #unsigned
		temp.rotCtrlID = (bit.intAsHex high) + (bit.intAsHex low)
		low = ReadShort bs #unsigned
		high = ReadShort bs #unsigned
		temp.scaleCtrlID = (bit.intAsHex high) + (bit.intAsHex low)
		
		propStrLen = ReadLong bs
		
		if propStrLen > 0 then
			temp.property = ReadString bs
		if numChildren > 0 then
		(
			for x = 1 to numChildren do
				append temp.childNodes (ReadLong bs)
		)
		
		if igh > 0 then temp.isGroupHead = true else temp.isGroupHead = false
		if igm > 0 then temp.isGroupMember = true else temp.isGroupMember = false
		
		chunkArchive.add temp	
	),
		
	fn readMaterialChunk header nextChunkPos =
	(
		fseek bs header.fileOffset #seek_set	
		fseek bs size_CHUNK_HEADER #seek_cur -- skip past header
		
		local temp = CryMaterialChunk()
		temp.header = header
		
		-- Make sure it's a supported version
		if header.version != 0x0745 and header.version != 0x0746 then
		(
			local message = "Version " + (hexString header.version) + " material chunks are not supported.\nPlease email adam@takaro.net and give details of\nthe file you were trying to import, so this can be\nfixed in future versions."
			messagebox message
			return undefined
		)
		
		-- Read in chunk descriptor data
		local p = ftell	bs
		local name = ReadString bs
		
		-- v745 does not have reserved space or alphatest param
		if header.version == 0x0745 then
		(
			fseek bs (p + 64) #seek_set  -- skip to end of allocated string space	
		)
		else
		(
			fseek bs (p + 124) #seek_set  -- skip to end of allocated string space + reserved space
			temp.alphaTest = ReadFloat bs
		)
		temp.type = ReadLong bs	
		
		-- Set name, pulling params out of name string if possible
		local sStart = findstring name "("
		local sEnd = findstring name ")"
		local mStart = findstring name "/"
		if sStart != undefined and sEnd != undefined then
			temp.shaderName = substring name (sStart + 1) (sEnd - sStart - 1)
		else
			temp.shaderName = ""
		if mStart != undefined then
			temp.surfaceName = substring name (mStart + 1) (name.count - mStart)
		else
			temp.surfaceName = ""
		if mStart != undefined and sStart == undefined then
			temp.name = substring name 1 (mStart - 1)
		else if sStart != undefined then
			temp.name = substring name 1 (sStart - 1)
		else
			temp.name = name
		
		if temp.type == materialType_Multi then
		(
			local numChildren = ReadLong bs
			
			-- skip to end of material chunk descriptor
			if header.version == 0x0746 then
				fseek bs (header.fileOffset + size_MTL_CHUNK_DESC_0746) #seek_set
			else
				fseek bs (header.fileOffset + size_MTL_CHUNK_DESC_0745) #seek_set
			
			for i = 1 to numChildren do
			(
				local child = ReadLong bs
				if child > 0 then
					append temp.children child		
			)
		)
		else
		(
			temp.diffuse = readColor()
			temp.specular = readColor()
			temp.ambient = readColor()
			fseek bs 3 #seek_cur -- skip to 4 byte boundary
			temp.specularLevel = ReadFloat bs	
			temp.specularShininess = ReadFloat bs	
			temp.selfIllumination = ReadFloat bs	
			temp.opacity = ReadFloat bs	
			
			temp.texAmbient = readTexture header.version
			temp.texDiffuse = readTexture header.version
			temp.texSpecular = readTexture header.version
			temp.texOpacity = readTexture header.version
			temp.texBump = readTexture header.version
			temp.texGloss = readTexture header.version
			temp.texFilter = readTexture header.version -- this is cubemap in v745, is actually detail texture
			temp.texReflection = readTexture header.version
			temp.texSubSurface = readTexture header.version
			temp.texDetail = readTexture header.version -- this is actually bump normals
							
			temp.flags = ReadLong bs
			temp.dynamicBounce = ReadFloat bs	
			temp.dynamicStaticFriction = ReadFloat bs	
			temp.dynamicSlidingFriction = ReadFloat bs	
		)
					
		chunkArchive.add temp	
	),
		
	fn readControllerChunk header nextChunkPos =
	(
		fseek bs header.fileOffset #seek_set	
		
		local temp = CryControllerChunk()
		temp.header = header
		
		-- check chunk version
		if (header.version == 0x0826) then
		(
			fseek bs size_CHUNK_HEADER #seek_cur -- skip past header
			
			-- Read in chunk descriptor data
			temp.type = ReadLong bs	
			local numKeys = ReadLong bs	
			temp.flags = ReadLong bs #unsigned	
			local low = ReadShort bs #unsigned
			local high = ReadShort bs #unsigned
			temp.ctrlID = (bit.intAsHex high) + (bit.intAsHex low)
				
			-- Determine key reading function
			local f
			case temp.type of
			(
				controllerType_CryBone       : f = ReadBoneKey
				controllerType_Linear1       : f = ReadLin1Key
				controllerType_Linear3       : f = ReadLin3Key
				controllerType_LinearQ       : f = ReadLinQKey
				controllerType_Bezier1       : f = ReadBez1Key
				controllerType_Bezier3       : f = ReadBez3Key
				controllerType_BezierQ       : f = ReadBezQKey
				controllerType_TCB1          : f = ReadTCB1Key
				controllerType_TCB3          : f = ReadTCB3Key
				controllerType_TCBQ          : f = ReadTCBQKey
				default                      : f = undefined
			)
			
			-- Read in Keys 
			if numKeys > 0 and f != undefined then
			(
				for x = 1 to numKeys do
					append temp.keys (f())
			)
		)
		else if (header.version == 0x0827) then
		(
			-- Read in chunk descriptor data
			local numKeys = ReadLong bs	
			local low = ReadShort bs #unsigned
			local high = ReadShort bs #unsigned
			temp.ctrlID = (bit.intAsHex high) + (bit.intAsHex low)
			
			-- Read in keys
			log 4 "\tReading in % keys for controller chunk" #(numKeys)
			if numKeys > 0 then
			(
				for x = 1 to numKeys do
					append temp.keys (readKey())
			)	
		)
		else
			return undefined
						
		chunkArchive.add temp	
	),
		
	fn readTimingChunk header nextChunkPos =
	(
		fseek bs header.fileOffset #seek_set	
		fseek bs size_CHUNK_HEADER #seek_cur -- skip past header
		
		local temp = CryTimingChunk()
		temp.header = header
			
		-- Read in chunk descriptor data
		temp.secsPerTick = ReadFloat bs	
		temp.ticksPerFrame = ReadLong bs
		temp.globalRange = readRange()
		
		-- Read in timing sub ranges
		local numSubRanges = ReadLong bs #unsigned
		log 4 "\tReading in % subranges for timing chunk" #(numSubRanges)
		if numSubRanges > 0 then
		(
			for x = 1 to numSubRanges do
				append temp.subRanges	(readRange())
		)	
					
		chunkArchive.add temp
	),
		
	fn readBoneLightBindingChunk header nextChunkPos =
	(
		fseek bs header.fileOffset #seek_set	
		
		local temp = CryBoneLightBindingChunk()
		temp.header = header
			
		-- Read in bindings
		local numBindings = ReadLong bs #unsigned
		log 4 "\tReading in % bindings for bone light binding chunk" #(numBindings)
		if numBindings > 0 then
		(
			for x = 1 to numBindings do
				append temp.boneLightBinds (readBoneLightBind())
		)	
					
		chunkArchive.add temp
	),
		
	fn readMeshMorphTargetChunk header nextChunkPos =
	(
		fseek bs header.fileOffset #seek_set	
		
		local temp = CryMeshMorphTargetChunk()
		temp.header = header
		
		-- Read in chunk descriptor data
		temp.meshChunkID = ReadLong bs #unsigned	
		
		-- Read in morph vertss
		local numVerts = ReadLong bs #unsigned
		log 4 "\tReading in % verts for mesh morph target chunk" #(numVerts)
		if numVerts > 0 then
		(
			for x = 1 to numVerts do
				append temp.targetVertices (readMeshMorphTargetVertex())
		)		
		
		temp.name = ReadString bs
		
		chunkArchive.add temp
	),
		
	fn readBoneInitialPosChunk header nextChunkPos =
	(
		fseek bs header.fileOffset #seek_set	
			
		local temp = CryBoneInitialPosChunk()
		temp.header = header
		
		-- Read in chunk descriptor data
		temp.meshChunkID = ReadLong bs #unsigned	
		
		-- Read in morph vertss
		local numBones = ReadLong bs #unsigned
		log 4 "\tReading in % bones for bone initial pos chunk" #(numBones)
		if numBones > 0 then
		(
			for x = 1 to numBones do
			(
				-- Read in Matrix3, a Max defined 4x3 matrix
				local m = Matrix3 [ReadFloat bs, ReadFloat bs, ReadFloat bs] \
													[ReadFloat bs, ReadFloat bs, ReadFloat bs] \
									 				[ReadFloat bs, ReadFloat bs, ReadFloat bs] \
									 				[ReadFloat bs, ReadFloat bs, ReadFloat bs]
				append temp.initialPositions m
			)
		)		
		
		chunkArchive.add temp
	),
		
	fn readSourceInfoChunk header nextChunkPos =
	(
		fseek bs header.fileOffset #seek_set			
		
		local temp = CrySourceInfoChunk()
		temp.header = header
			
		-- Read in strings
		temp.sourceFile = ReadString bs	
		temp.date = ReadString bs	
		temp.user = ReadString bs	
				
		-- Fix for newline character sometimes at end of date string
		if temp.date[temp.date.count] == "\n" then
		(
			local ss = StringStream temp.date
			temp.date = readDelimitedString ss "\n"
		)
		
		chunkArchive.add temp
	),
				
	fn readChunk header nextChunkPos =
	(
		-- Check that the fileoffset in the header points to a valid part of the file
		fseek bs header.fileOffset #seek_set
		if (readByte bs) == undefined then return undefined
			
		-- Call appropriate function based on the chunk type
		case header.type of
		(
			0x0000: readMeshChunk header nextChunkPos
			0x0001: readHelperChunk header nextChunkPos
			0x0002: readVertAnimChunk header nextChunkPos
			0x0003: readBoneAnimChunk header nextChunkPos
			0x0004: log 3 "Obsolete chunk type in chunk header" #()
			0x0005: readBoneNameListChunk header nextChunkPos
			0x0006: log 3 "Obsolete chunk type in chunk header" #()
			0x0007: log 3 "Obsolete chunk type in chunk header" #()
			0x0008: readScenePropChunk header nextChunkPos
			0x0009: readLightChunk header nextChunkPos
			0x000A: log 3 "Non-implemented chunk type in chunk header" #()
			0x000B: readNodeChunk header nextChunkPos
			0x000C: readMaterialChunk header nextChunkPos
			0x000D: readControllerChunk header nextChunkPos
			0x000E: readTimingChunk header nextChunkPos
			0x000F: readMeshChunk header nextChunkPos isBoneMesh:true
			0x0010: readBoneLightBindingChunk header nextChunkPos
			0x0011: readMeshMorphTargetChunk header nextChunkPos
			0x0012: readBoneInitialPosChunk header nextChunkPos
			0x0013: readSourceInfoChunk header nextChunkPos
			default: log 2 "Invalid chunk type in chunk header"  #()
		)
	),
	
	fn readFile filename filetype =
	(
		if (not DoesFileExist filename) then
			return "Invalid filename given"		
			
		if (isKindOf chunkArchive CryChunkArchive) == false then
			return "Not initialised with a valid chunk archive"
	
		-- We open both a BinStream and a FileStream, because each has methods that we want to use
		bs = fopen filename "rb"
		fs = openFile filename mode:"rb"
		
		-- Read file header and make sure it's valid
		if readChars fs 6 != "CryTek" then
			return "Not a valid CryTek file"
		
		-- Check that we have the correct file type
		fseek bs 8 #seek_set
		local low = ReadShort bs #unsigned
		local high = ReadShort bs #unsigned
		log 4 "high: %  low: %" #(high,low)
		log 4 "Is geom file: %  Is anim file: %" #((isGeomFile high low), (isAnimFile high low))
			
		if not ((isGeomFile high low) or (isAnimFile high low)) then
			return "Invalid file type"			
		if (isGeomFile high low) and (filetype == FileType_Anim) then
			return "Got a geometry file, expecting an animation file"			
		if (isAnimFile high low) and (filetype == FileType_Geom) then
			return "Got an animation file, expecting a geometry file"	
		
		-- Add filename of geometry file to chunk archive (to use for texture paths)
		if filetype == FileType_Geom then
			chunkArchive.geomFileName = filename
		
		-- Find Chunk table and get number of chunks in file
		fseek bs 16 #seek_set
		local chunkTablePos = ReadLong bs
		fseek bs chunkTablePos #seek_set
		local numChunks = ReadLong bs
		local chunkHeadersPos = ftell bs
		log 3 "Chunk table offset: % Number of chunks: %\n" #(chunkTablePos, numChunks)
				
		-- Read in chunk headers
		local headerArray = #()
		local headerPosArray = #()
		for x in 0 to (numChunks - 1) do
		(
			fseek bs (chunkHeadersPos + (x * size_CHUNK_HEADER)) #seek_set			
			append headerPosArray (ftell bs) -- store start position of this array
				
			local chunkHeader = readChunkHeader()
			printChunkHeader chunkHeader 3
			append headerArray chunkHeader
		)
		
		-- Read in the chunk associated with each header
		for x in 1 to numChunks do
		(
			local nextChunkPos = undefined
			if x < numChunks then
				nextChunkPos = headerPosArray[x+1] -- Start position of next chunk
			else
				nextChunkPos = chunkTablePos -- This comes after the last chunk
				
			readChunk headerArray[x] nextChunkPos
		)
	)
			
) -- End of ChunkReader struct
