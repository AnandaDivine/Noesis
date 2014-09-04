-- Scene Builder for CryImporter
-- Copyright 2006 Takaro Pty. Ltd.
-- www.takaro.net

/* Notes:
		* Converts imported chunks into equivalent Max scene objects
*/

struct ShaderIdent
(
	material = "",
	submaterial = "",
	shader = "",
	useOpacity = false
)

struct ControllerRef
(
	object,   -- Pointer to object being animated by controller
	property  -- string naming the property being controlled
)

struct ControllerIndex
(
	ids = #(),         -- Array of controller ID strings
	controllers = #()  -- Array of ControllerRef
)

struct SceneBuilder
(
	fn defaultLog logLevel formatString argArray = ok,
	
	-- Alterable parameters
	rootBoneSize = 5,      -- The length and width of the root bone
	childBoneScale = 0.85,  -- The size of a child bone in proportion to its parent
	boneProportion = 0.4,   -- The desired ratio of height/width to length
	boneDefaultLength = 5,  -- Length of bones that don't have any children
	boneEndTolerance = 3.0, -- How close the actual end point of a bone must be to the calculated
	                        -- end point. This is here because transforms can rotate bones in
	                        -- unexpected directions (e.g. if they were initially boxes, where this
	                        -- kind of rotation would go unnoticed), and if this happens, the best
	                        -- option is to shrink the bone to a small size
	safeApplyTolerance = 0.0001,
	                        
	-- Do not alter these
	chunkArchive,				       -- CryChunkArchive
	log = defaultLog,		       -- Function pointer to logging function
	assetBasePath = "",        -- Path to primary asset source
	assetAltBasePath = "",     -- Path to alternate asset source (e.g. mod)
	meshes = #(),				       -- Max meshes created for scene
	bones = #(),				       -- Max bones created for scene
	helpers = #(),             -- Max helpers created for scene
	lights = #(),              -- Max lights created for scene
	sceneProps = #(),          -- Max sceneProps created for scene
	morphMeshes = #(),         -- Max meshes created for scene for Morpher modifier
	materials = #(),           -- Max materials created for scene
	materialChunks = #(),      -- Chunk IDs corresponding to each material in materials array
	matIDToMaxMatID = #(),     -- Array mapping matIDs in chunk to effective matID for each face 
	matIDToMaxMaterial = #(),  -- Array mapping matIDs in chunk to effective material for each mesh 
	shaderList = #(),          -- Array of ShaderIdent
	ctrlIndex = ControllerIndex(),
	timingOffset = 0,
	validKeyRange = Interval 0 0,  
	wireColor = color 150 150 150 150, -- Color of all mesh objects in wireframe mode
	
	fn getCtrl ctrlID =
	(
		for i = 1 to ctrlIndex.ids.count do
			if ctrlIndex.ids[i] == ctrlID then return ctrlIndex.controllers[i]
		undefined
	),
	
	fn addCtrl ctrlID obj prop =
	(
		append ctrlIndex.ids ctrlID
		append ctrlIndex.controllers (ControllerRef object:obj property:prop)	
	),
	
	fn getBone boneName =
	(
		for x in bones do
			if x.name == boneName then return x
		undefined
	),
	
	fn getLight lightName =
	(
		for x in lights do
			if x.name == lightName then return x
		undefined
	),
	
	fn getMaterialByName matName =
	(
		for x in materials do
			if x.name == matName then return x
		undefined
	),
	
	fn getMaterialByChunkID chunkID =
	(
		for i = 1 to materialChunks.count do
			if materialChunks[i].header.chunkID == chunkID then return materials[i]
		undefined
	),
	
	fn getKeyIndex keyArray time =
	(
		for i = 1 to keyArray.count do
			if keyArray[i].time == time then return i
		return -1	
	),
	
	fn setAssetBasePath path =
	(
		if classOf path == String then assetBasePath = path
	),
	
	fn setAssetAltBasePath path =
	(
		if classOf path == String then assetAltBasePath = path
	),
	
	fn setTiming timingChunk bAppendRange:false=
	(
		if bAppendRange == true then 
		(
			-- Set timing to immediately follow current timing range
			local rangeStart = animationRange.end + 1
			local rangeEnd = rangeStart + (timingChunk.globalRange.end - timingChunk.globalRange.start)
			if rangeEnd > rangeStart then
				animationRange = interval rangeStart rangeEnd	
		) 
		else
		(	
			-- Set timing to start at zero
			local rangeEnd = (timingChunk.globalRange.end - timingChunk.globalRange.start)
			if rangeEnd > 0 then	
				animationRange = interval 0 rangeEnd
		)
		
		ticksPerFrame = timingChunk.ticksPerFrame
		frameRate = (1 / (timingChunk.secsPerTick * timingChunk.ticksPerFrame)) as Integer
		timingOffset = animationRange.start - timingChunk.globalRange.start
		validKeyRange = interval timingChunk.globalRange.start timingChunk.globalRange.end
		
		-- Ignore subranges for now
		
	),
	
	fn getFullFilename name =
	(
		-- test for file via alternate path first
		local fullname = assetAltBasePath + "\\" + name
		if doesFileExist fullname then return fullname
		
		-- then test for file via primary path
		fullname = assetBasePath + "\\" + name
		if doesFileExist fullname then return fullname
		
		-- test for file in same directory as model
		local localPath = getFilenamePath chunkArchive.geomFileName
		fullname = localPath + "\\" + name
		if doesFileExist fullname then 
		(
			messagebox ("Loaded texture [" + name + "] from local path [" + localPath + "].\nA portion of this path will end up in your exported file,\nwhich might cause problems when you try to load it into the game.\nUse with caution.")
			return fullname
		)
		
		messagebox ("Unable to find texture [" + name + "] in the given paths")
			
		return undefined
	),
	
	fn showHeadOnly m meshChunk =
	(
		if meshChunk.hasBoneInfo == false then return undefined
		
		-- Get bone ID for head bone
		local boneIDs = #()
		local headID = chunkArchive.getBoneIDFromSubString " head"
		
		if headID != undefined then append boneIDs headID
		if boneIDs.count == 0 then return undefined
		
		-- Generate list of vertices that are influenced by head and neck bones
		local vList = #()
		-- iterate through vertices in physique data
		for x in meshChunk.physique do
		(
			local v = x.vertexID + 1
			local count = vList.count
			-- iterate through bones that are linked to current vertex
			for y in x.links while count == vList.count do -- if vList grows, we've already included this vertex
			(
				-- iterate through list of target boneIDs (usually two, head and neck)
				for z in boneIDs do
				(
					if z == y.boneID and 
						 (count == 0 or vList[count] != v) then -- make sure we didn't just add this vertex
						append vList v
				)
			)	
		)
		sort vList
		
		-- Go through mesh faces and hide all that contain a vertex not in our list
		faceList = #()
		for i in 1 to (getNumFaces m) do
		(
			local face = getFace m i
			if (binarySearch vList face[1]) == undefined and
				 (binarySearch vList face[2]) == undefined and
				 (binarySearch vList face[3]) == undefined then
				 	append faceList i
		)
		meshop.setHiddenFaces m faceList
		
		return true
	),
	
	-- Mesh chunks use an odd representation for specifying the material ID for each face:
	--   If you list all standard materials in a file sequentially, starting at 0, and excluding multi
	--   materials, you then take the number of this standard material as the matID.
	-- To make this useful in Max, we need to generate two mappings:
	--   1. Find which multi material a standard material belongs to (if any), so we can set correct material
	--      for that mesh. Not a problem if mesh has a node chunk, but bone meshes don't have one.
	--   2. Find the actual matID of the standard material within the multi that it belongs to. This will result
	--      in a matID of 1 for the face if it doesn't belong to a multi material.
	-- This function generates the two mapping arrays, matIDToMaxMatID and matIDToMaxMaterial
	fn buildMatMappings =
	(
		-- Get number of standard materials (this will tell us the required size of the mapping arrays)
		local numStandardMats = 0
		local tempStandardMatArray = #()
		local tempMultiMatArray = #()
		for i = 1 to materials.count do
		(
			if materialChunks[i].type == materialType_Standard then 
			(
				numStandardMats += 1	
				append tempStandardMatArray materials[i]
			) 
			else if materialChunks[i].type == materialType_Multi then 
			(
				append tempMultiMatArray materials[i]
			)
		)
		
		-- Iterate through list of standard materials and determine parent multi material (if any) for each one
		-- Also determine number of submaterial within multi to get correct matID
		for i = 1 to numStandardMats do
		(
			local mat = tempStandardMatArray[i]
			local mapping = undefined
			local matID = undefined
			
			-- Go through multis and see if material is one of their submaterials
			for x in tempMultiMatArray while mapping == undefined do
			(
				for j = 1 to x.materiallist.count while mapping == undefined do
				(
					if x.materiallist[j] == mat then 
					(
						mapping = x
						matID = j
					)
				)
			)
			
			if mapping == undefined then 
			(
				mapping = mat -- material has no parent, just maps to itself
				matID = 1
			)
			
			matIDToMaxMaterial[i] = mapping
			matIDToMaxMatID[i] = matID
		)	
	),
	
	fn createTexture tex =
	(
			local filename = getFullFilename tex.name
			if filename == undefined then return undefined	
			
			local t = bitmaptexture filename:filename
			t.name = tex.name
			
			-- fill in params
			t.coords.U_Mirror = tex.uMirror
			t.coords.U_Tile = tex.uTile
			t.coords.V_Mirror = tex.vMirror
			t.coords.V_Tile = tex.vTile
			t.coords.U_Offset = tex.uOffset
			t.coords.U_Tiling = tex.uScale
			t.coords.U_Angle = tex.uRotation
			t.coords.V_Offset = tex.vOffset
			t.coords.V_Tiling = tex.vScale
			t.coords.V_Angle = tex.vRotation
			t.coords.W_Angle = tex.wRotation
			
			-- add controller IDs to controller index
			if tex.uOffsetCtrlID != "ffffffff" and (getCtrl tex.uOffsetCtrlID) == undefined then
				addCtrl tex.uOffsetCtrlID t "coords.U_Offset"
			if tex.uScaleCtrlID != "ffffffff" and (getCtrl tex.uScaleCtrlID) == undefined then
				addCtrl tex.uScaleCtrlID t "coords.U_Tiling"
			if tex.uRotationCtrlID != "ffffffff" and (getCtrl tex.uRotationCtrlID) == undefined then
				addCtrl tex.uRotationCtrlID t "coords.U_Angle"
			if tex.vOffsetCtrlID != "ffffffff" and (getCtrl tex.vOffsetCtrlID) == undefined then
				addCtrl tex.vOffsetCtrlID t "coords.V_Offset"
			if tex.vScaleCtrlID != "ffffffff" and (getCtrl tex.vScaleCtrlID) == undefined then
				addCtrl tex.vScaleCtrlID t "coords.V_Tiling"
			if tex.vRotationCtrlID != "ffffffff" and (getCtrl tex.vRotationCtrlID) == undefined then
				addCtrl tex.vRotationCtrlID t "coords.V_Angle"
			if tex.wRotationCtrlID != "ffffffff" and (getCtrl tex.wRotationCtrlID) == undefined then
				addCtrl tex.wRotationCtrlID t "coords.W_Angle"
			
			return t
	),
	
	fn createSceneProps propChunk =
	(
		for x in propChunk.props do
			fileProperties.addProperty #custom x.name x.value	
	),
	
	fn setNodeDetails node nodeChunk =
	(
		node.name = nodeChunk.name
		
		-- Turn Matrix44 into Max Matrix 3
		local m = nodeChunk.transMatrix
		local m3 = Matrix3 [m.row1[1], m.row1[2], m.row1[3]] \
		                   [m.row2[1], m.row2[2], m.row2[3]] \
		                   [m.row3[1], m.row3[2], m.row3[3]] \
		                   [m.row4[1], m.row4[2], m.row4[3]]	
		node.transform = m3	
		
		-- Set material for node (this is now done in createBasicMesh)
		-- node.material = (getMaterialByChunkID nodeChunk.materialID)
		
		-- add controller IDs to controller index
		if nodeChunk.posCtrlID != "ffffffff" and (getCtrl nodeChunk.posCtrlID) == undefined then
			addCtrl nodeChunk.posCtrlID node "position"
		if nodeChunk.rotCtrlID != "ffffffff" and (getCtrl nodeChunk.rotCtrlID) == undefined then
			addCtrl nodeChunk.rotCtrlID node "rotation"
		if nodeChunk.scaleCtrlID != "ffffffff" and (getCtrl nodeChunk.scaleCtrlID) == undefined then
			addCtrl nodeChunk.scaleCtrlID node "scale"
			
		-- Set user defined properties if necessary
		if nodeChunk.property != undefined and nodeChunk.property != "" then
			setUserPropBuffer node nodeChunk.property
	),
	
	fn createBasicMesh meshChunk =
	(
		-- Create vertex position and normal arrays
		local va = #()
		local vna = #()
		for x in meshChunk.vertices do
		(
			append va x.pos
			append vna x.normal
		)
		
		-- Create face, material ID, and smoothing group arrays
		local fa = #()
		local ma = #()
		local sga = #()
		for x in meshChunk.faces do
		(
			append fa [x.v0 + 1, x.v1 + 1, x.v2 + 1]
			append ma matIDToMaxMatID[x.matID + 1]
			-- fix entry if the material ID was out of range
			if ma[ma.count] == undefined then ma[ma.count] = 1
			
			append sga x.smoothGroup
		)	
		
		-- Create texture vertex face array
		local tvfa = #()
		if meshChunk.texFaces.count > 0 then
		(
			for x in meshChunk.texFaces do
			(
				append tvfa [x.t0 + 1, x.t1 + 1, x.t2 + 1]
			)
		)
		else
			tvfa = fa -- texture faces are the same as regular faces for this mesh
					
		-- Create mesh
		local m = mesh vertices:va faces:fa
				
		-- Add vertex normals
		for i = 1 to m.mesh.numverts do
			setNormal m.mesh i vna[i]
		
		-- set mesh material
		local matID = meshChunk.faces[1].matID      -- Get a sample matID from mesh
		m.material = matIDToMaxMaterial[matID + 1]  -- Use array to map matID to parent material
		m.wireColor = wireColor -- Set wireframe color of all objects to grey
		-- Set face material IDs and smoothing groups
		for i = 1 to m.mesh.numfaces do
		(
			if ma[i] != undefined then
				setFaceMatID m.mesh i ma[i]
			if sga[i] != undefined then
				setFaceSmoothGroup m.mesh i sga[i]
		)
		
		-- Add Texture vertices and texture faces if applicable
		if meshChunk.texVertices.count > 0 then
		(
			setnumTVerts m.mesh meshChunk.texVertices.count
			buildTVFaces m.mesh
			for i = 1 to meshChunk.texVertices.count do
				setTVert m.mesh i meshChunk.texVertices[i]
			for i = 1 to tvfa.count do
				setTVFace m.mesh i tvfa[i]
		)
			
		-- build vertex colors for mesh if applicable
		if meshChunk.hasVertexColors then
		(
			setNumCPVVerts m.mesh meshChunk.vertexColors.count
			buildVCFaces m.mesh
			for i = 1 to meshChunk.vertexColors.count do
				setVertColor m.mesh i meshChunk.vertexColors[i]
				
			for i = 1 to fa.count do
				setVCFace m.mesh i fa[i] -- vertex color faces are the same as regular vertex faces
		)		
			
		return m
	),
	
	fn commonBoneCreationRoutine maxbone bonedata =
	(
		-- Add controller ID to controller index
		if bonedata.ctrlID != "ffffffff" and (getCtrl bonedata.ctrlID) == undefined then
			addCtrl bonedata.ctrlID maxbone ""
		
		-- Set user defined properties if necessary
		if bonedata.customProperty != undefined and bonedata.customProperty != "" then
			setUserPropBuffer maxbone bonedata.customProperty
	),
	
	fn createBoneStructure =
	(
		for x in chunkArchive.boneAnimChunks[1].bones do
		(	
			-- determine parent
			local parent = undefined
			if x.parentID != -1 then
				parent = bones[x.parentID + 1] -- getBone (chunkArchive.getBoneName x.parentID)	
		 
			-- Check if bone is actually a light (due to boneLightBind), and handle differently
			local light = getLight x.name
			if light != undefined then
			(
				light.parent = parent
				append bones light -- Add to bones array too, to keep bone name list consistent
				
				commonBoneCreationRoutine light x
				
				continue
			)
			
			-- Create bone mesh if we have a bone mesh chunk for this bone
			if x.bonePhysics.meshID > 0 then 
			(
				local boneMesh = chunkArchive.getBoneMeshFromChunkID x.bonePhysics.meshID
				if boneMesh != undefined then
				(
					local b = createBasicMesh boneMesh	
					
					b.name = x.name
					b.parent = parent
					b.transform = chunkArchive.getBoneInitialPos x.boneID
					append bones b
						
					commonBoneCreationRoutine b x
					
					continue
				)
			)
			
			-- If we get to this point we just create a standard bone with what data we have
			
			if (chunkArchive.getBoneInitialPos x.boneID) == undefined then continue -- Can't build bone without this
				
				
			-- determine bone start and end points based on parent and child bone positions
			local start = (chunkArchive.getBoneInitialPos x.boneID)[4] -- get xlate component of TM
			local end
			local children = chunkArchive.getChildBones x.BoneID chunkArchive.boneAnimChunks[1]
			if children.count == 0 then
			(
				local len = length start
				local extra = boneDefaultLength
				if parent != undefined and classof parent == BoneGeometry then 
					extra = (parent.height + parent.width) / 2
				end = ((extra + len) / len) * start
			)
			else if children.count == 1 then
			(  
				end = (chunkArchive.getBoneInitialPos children[1].boneID)[4] -- get xlate component of TM
			)
			else
			(
				end = [0,0,0]
				for x in children do
					end += (chunkArchive.getBoneInitialPos x.boneID)[4] -- get xlate component of TM
				
				end /= children.count
			)
				
			local b = BoneSys.createBone start end [0,0,0]
			b.name = x.name
			b.parent = parent
			b.transform = chunkArchive.getBoneInitialPos x.boneID
				
			-- set height and width of bone
			if b.parent == undefined or classof b.parent != BoneGeometry then
			(
				b.height = rootBoneSize
				b.width = rootBoneSize
			)
			else
			(
				if children.count > 0 then
				(
					local newProp = (b.length * boneProportion)
					-- Handle differently if parent bone is much shorter
					if b.parent.length < (b.length * 0.3) then 
					(
						b.height = minimum newProp rootBoneSize
						b.width = b.height
					)
					else
					(
						b.height = minimum (b.parent.height * childBoneScale) newProp
						b.width = minimum (b.parent.width * childBoneScale) newProp			
					)	
				)
				else
				(
					-- Special treatment for nub bones
					b.height = (b.parent.height * childBoneScale) 
					b.width = (b.parent.width * childBoneScale)
				)
			)
				
			-- Adjust length of bone if transform has put it on an axis away from its expected endpoint
			local actualEnd = [b.length,0,0] * b.transform
			if (distance end actualEnd) > boneEndTolerance then
				b.length = (b.height + b.width) / 2			
			
			commonBoneCreationRoutine b x
								
			append bones b
		)
	),
	
	fn createMaterial mtlChunk subMaterial:false parentMatName:"" =
	(
		local mtl
		
		-- Determine material type
		if mtlChunk.type == materialType_Multi then
		(
			mtl = multimaterial numsubs:mtlChunk.children.count
			mtl.name = mtlChunk.name
		
			-- Create the submaterials
			local count = 0
			for i = 1 to mtlChunk.children.count do
			(
				local submtl = chunkArchive.getMaterialChunk mtlChunk.children[i]
				if submtl == undefined then
				(
					log 2 "Invalid submaterial chunk ID: %" #(mtlChunk.children[i])
				)
				else
				(
					count += 1
					
					-- Check if submaterial already exists
					local tempSubMtl = getMaterialByChunkID submtl.header.chunkID
					if tempSubMtl != undefined then
						mtl.materialList[count] = tempSubMtl
					else
						mtl.materialList[count] = createMaterial submtl subMaterial:true parentMatName:mtl.name
				)
			)
		)
		else if mtlChunk.type == materialType_Standard then
		(
				mtl = standard()
				
				-- Set flags
				if (bit.and mtlChunk.flags materialFlag_Wire) != 0 then
					mtl.wire = true
				if (bit.and mtlChunk.flags materialFlag_2Sided) != 0 then
					mtl.twoSided = true
				if (bit.and mtlChunk.flags materialFlag_Facemap) != 0 then
					mtl.faceMap = true
				if (bit.and mtlChunk.flags materialFlag_Faceted) != 0 then
					mtl.faceted = true
				if (bit.and mtlChunk.flags materialFlag_Additive) != 0 then
					mtl.opacityType = 1
				if (bit.and mtlChunk.flags materialFlag_Subtractive) != 0 then
					mtl.opacityType = 2
				--if (bit.and mtlChunk.flags materialFlag_CryShader) != 0 then
				mtl.shaderByName = "Crytek Shader" -- For now make all materials use CryShader
				if (bit.and mtlChunk.flags materialFlag_Physicalize) != 0 then
					mtl.physicalizeMaterial = true
				if (bit.and mtlChunk.flags materialFlag_AdditiveDecal) != 0 then
					mtl.additiveDecal = true
				if (bit.and mtlChunk.flags materialFlag_UseGlossiness) != 0 then
					mtl.useGlossiness = true -- Not sure if this is what this flag should do
					
				-- Set other params
				mtl.name = mtlChunk.name
				if mtlChunk.shaderName != "" then mtl.shaderName = mtlChunk.shaderName
				if mtlChunk.surfaceName != "" then mtl.surfaceName = mtlChunk.surfaceName
				mtl.diffuse = mtlChunk.diffuse
				mtl.ambient = mtlChunk.ambient
				mtl.specular = mtlChunk.specular
				mtl.specularLevel = mtlChunk.specularLevel
				mtl.Glossiness = mtlChunk.specularShininess
				mtl.selfIllumAmount = mtlChunk.selfIllumination
				mtl.opacity = mtlChunk.opacity * 100
				mtl.bounce = mtlChunk.dynamicBounce
				mtl.staticFriction = mtlChunk.dynamicStaticFriction
				mtl.slidingFriction = mtlChunk.dynamicSlidingFriction
				if mtlChunk.alphaTest != undefined then mtl.alphaTest = mtlChunk.alphaTest
				
				-- Add shader name to shaderlist for user to change later
				if mtlChunk.shaderName != "" then
				(
					local si = ShaderIdent()
					si.shader = mtlChunk.shaderName
					if subMaterial == true then
					(
						si.submaterial = mtl.name
						si.material = parentMatName 
					)
					else
						si.material = mtl.name
					
					if mtlChunk.opacity > 0 and mtlChunk.opacity < 1 then 
						si.useOpacity = true -- need to set opacity checkbox manually
					
					append shaderList si
				)
						
				-- Set texture maps
				if mtlChunk.texDiffuse != undefined then
				(
					mtl.diffuseMap = createTexture mtlChunk.texDiffuse
					if mtl.diffuseMap != undefined then 
					(
						mtl.diffuseMapAmount = mtlChunk.texDiffuse.amount
						mtl.diffuseMapEnable = true
					)
				)
				if mtlChunk.texSpecular != undefined then
				(
					mtl.specularMap = createTexture mtlChunk.texSpecular
					if mtl.specularMap != undefined then 
					(
						mtl.specularMapAmount = mtlChunk.texSpecular.amount
						mtl.specularMapEnable = true
					)
				)
				if mtlChunk.texAmbient != undefined then
				(
					mtl.ambientMap = createTexture mtlChunk.texAmbient
					if mtl.ambientMap != undefined then 
					(
						mtl.ambientMapAmount = mtlChunk.texAmbient.amount
						mtl.ambientMapEnable = true
					)
				)
				if mtlChunk.texOpacity != undefined then
				(
					mtl.opacityMap = createTexture mtlChunk.texOpacity
					if mtl.opacityMap != undefined then 
					(
						mtl.opacityMapAmount = mtlChunk.texOpacity.amount
						mtl.opacityMapEnable = true
					)
				)
				if mtlChunk.texBump != undefined then
				(
					mtl.bumpMap = createTexture mtlChunk.texBump
					if mtl.bumpMap != undefined then 
					(
						mtl.bumpMapAmount = mtlChunk.texBump.amount
						mtl.bumpMapEnable = true
					)
				)
				if mtlChunk.texGloss != undefined then
				(
					mtl.glossinessMap = createTexture mtlChunk.texGloss
					if mtl.glossinessMap != undefined then 
					(
						mtl.glossinessMapAmount = mtlChunk.texGloss.amount
						mtl.glossinessMapEnable = true
					)
				)
				if mtlChunk.texFilter != undefined then
				(
					-- This should be treated as a detail map
					mtl.detailMap = createTexture mtlChunk.texFilter
					if mtl.detailMap != undefined then 
					(
						mtl.detailMapAmount = mtlChunk.texFilter.amount
						mtl.detailMapEnable = true
					)
				)
				if mtlChunk.texReflection != undefined then
				(
					mtl.reflectionMap = createTexture mtlChunk.texReflection
					if mtl.reflectionMap != undefined then 
					(
						mtl.reflectionMapAmount = mtlChunk.texReflection.amount
						mtl.reflectionMapEnable = true
					)
				)
				if mtlChunk.texSubSurface != undefined then
				(
					mtl.subsurfaceMap = createTexture mtlChunk.texSubSurface
					if mtl.subsurfaceMap != undefined then 
					(
						mtl.subsurfaceMapAmount = mtlChunk.texSubSurface.amount
						mtl.subsurfaceMapEnable = true
					)
				)
				if mtlChunk.texDetail != undefined then
				(
					-- this should be treated as a normal map
					mtl.normalMap = createTexture mtlChunk.texDetail
					if mtl.normalMap != undefined then 
					(
						mtl.normalMapAmount = mtlChunk.texDetail.amount
						mtl.normalMapEnable = true
					)
				)				
		)
		else 
		(
			log 1 "No handling for 2Sided materials at this time: %" #(mtlChunk.name)
			return ok
		)
		
		-- Set materials to appear in viewports
		showTextureMap mtl on 
		
		append materials mtl	
		append materialChunks mtlChunk
		
		-- Add the material to material editor if it's not a submaterial
		if subMaterial == false then
		(
			-- Find next slot in material editor that's a standard material and doesn't use the crytek shader
			-- or have a slash in it (like arm/mat_arm)
			local slotNum = -1
			for i = 1 to meditMaterials.count while slotNum == -1 do
			(
				if (classof meditMaterials[i]) == Standardmaterial and
					 meditMaterials[i].shaderName != "Crytek Shader" and
					 (findstring meditMaterials[i].shaderName "/") == undefined then
					 slotNum = i
			)
			
			-- No free slots, so just stick it in first slot. Probably not best solution
			if slotNum == -1 then
				slotNum = 1
				
			setMeditMaterial slotNum mtl
		)
		else
		(
			-- Return submaterial back to the caller
			return mtl 
		)
	),
	
	fn createHelper helperChunk =
	(
		local h
		if helperChunk.type == helperType_Point then
		(
			h = point()	
		)
		else if helperChunk.type == helperType_Dummy then
		(
			h = dummy boxsize:helperChunk.size	
		)
		else
		(
			log 1 "Got invalid helper type: %" #(helperChunk.type)
			return undefined
		)
		
		-- Find corresponding node chunk if applicable and add it's details to mesh
		local nodeChunk = chunkArchive.getNode helperChunk.header.chunkID
		setNodeDetails h nodeChunk	
		
		append helpers h
	),
	
	fn createLight lightChunk =
	(
		local l
		if lightChunk.type == lightType_Spot then l = freeSpot()
		else if lightChunk.type == lightType_Direct then l = directionalLight()
		else l = omniLight()
		
		if lightChunk.type == lightType_Ambient then l.ambientOnly = true
		
		-- set params
		l.enabled = lightChunk.isOn
		l.rgb = lightChunk.color
		l.multiplier = lightChunk.intensity
		l.castShadows = lightChunk.shadow
		
		if lightChunk.useNearAttenuation then
		(
			l.useNearAtten = true
			l.showNearAtten = true
			l.nearAttenStart = lightChunk.nearAttenuationStart
			l.nearAttenEnd = lightChunk.nearAttenuationEnd
		)
		if lightChunk.useFarAttenuation then
		(
			l.useFarAtten = true
			l.showFarAtten = true
			l.farAttenStart = lightChunk.farAttenuationStart
			l.farAttenEnd = lightChunk.farAttenuationEnd
		)
		
		if lightChunk.type == lightType_Spot or lightChunk.type == lightType_Direct then
		(
			l.hotspot = hotSize
			l.falloff = fallSize	
		)
		
		-- Find corresponding node chunk if applicable and add it's details to mesh
		local nodeChunk = chunkArchive.getNode lightChunk.header.chunkID
		setNodeDetails l nodeChunk
		
		append lights l
	),

	fn createBoneLightBind blb =
	(
		local name = chunkArchive.getLightName blb.lightChunkID
		local light = getLight name
		local b = bones[blb.boneID + 1]
		
		light.parent = b -- Set binding, although this was probably already done when creating bones
		
		-- Set light position and orientation relative to bone
		local r = blb.rotLightOrientation
		local q = exp (quat r.x r.y r.z 0)
		light.rotation = q * b.transform
		light.pos = (blb.lightoffset * b.transform)
	),
	
	fn addVertAnim meshNode vaChunk meshChunk =
	(
		-- vaChunk doesn't cater for duplicate verts, so we need to create a new vert mapping
		-- that collects together all duplicate verts so we change all the verts not just the 
		-- first in each duplicate set
		local vertArray = #()	
			
		-- Add first vert to vertArray to simplify for loop
		append vertArray #(getvert meshNode 1, #(1))
			
		-- Iterate through verts in mesh and see if they're duplicates or not		
		local tolerance = 0.001	
		for i = 2 to (getnumverts meshNode) do
		(
			local isDuplicate = false
			local v = getvert meshNode i
			for testMapping in vertArray while isDuplicate == false do
			(
				if length (testMapping[1] - v) < tolerance then
				(
					-- It's a duplicate!
					append testMapping[2] i
					isDuplicate = true
				)
			)
			
			if isDuplicate == false then 
				append vertArray #(v, #(i)) -- add new mapping to vertArray	
		)
			
		-- Add animation keys to the controller
		animate on
		(
			for k in vaChunk.keys do
			(
				local t = (k.keyTime / ticksperframe)				
				for i = 1 to k.vertices.count do
				(
					-- set all verts specified in the mapping array
					for j = 1 to vertArray[i][2].count do
						 at time t setProperty meshNode ("Vertex_" + vertArray[i][2][j] as string) k.vertices[i]	
					--at time t meshop.setVert meshNode vertArray[i][2] k.vertices[i]
											
				)				
			)
		)	
	),
	
	fn addMeshMorph meshNode morph meshMorphChunk meshChunk safeVertArray xpos =
	(
		-- Make copy of mesh 
		local m = copy meshNode
		m.name = meshMorphChunk.name
		m.pos.x = xpos 
		hide m
		deleteModifier m m.morpher
		deleteModifier m m.skin
				
		-- Modify mesh based on meshMorph information
		for x in meshMorphChunk.targetVertices do
		(
			local vertID = safeVertArray[x.vertexID + 1]
			
			-- Safe Apply assigns -1 to modified verts that we can't safely morph
			if vertID != -1 then 
			(
				-- Check if vert has changed from position in original mesh
				if meshChunk.vertices[vertID].pos != x.targetPoint then
					meshop.setVert m vertID (x.targetPoint * m.transform)	
			)
		)
		
		-- Assign new mesh to first available morph slot
		local channel
		local i = 1
		for i = 1 to 100 while channel == undefined do
		(	
			if (WM3_MC_HasTarget morph i) == false then
				channel = i
		)
			
		WM3_MC_SetActive morph channel true
		WM3_MC_SetName morph channel meshMorphChunk.name
		WM3_MC_BuildFromNode morph channel m		
		
		append morphMeshes m
	),
	
	fn applyMorpher meshNode meshChunk safeApply =
	(
		local morphChunks = chunkArchive.getMorphs meshChunk.header.chunkID
		if morphChunks.count > 0 then
		(
			undo off
			(
				local morph = Morpher()
				addModifier meshNode morph
				
				disableSceneRedraw()
					
				-- Vertices array maps vert IDs from mesh chunk to actual scene mesh. If nothing has changed in
				-- scene mesh, this should just be a direct mapping, but if not, and we're using Safe Apply, 
				-- we need to create a proper mapping by testing every vert in the actual mesh to see which one
				-- corresponds to each vert in the mesh chunk
				local vertices = #()
				if safeApply == true then
				(
					-- Make a temp array of verts in actual mesh, since Max seems to waste ridiculous amounts
					-- of memory when I use getvert, and crashes after about 10000 calls
					local tempMeshNodeVerts = #()
					for i = 1 to meshNode.numverts do
						tempMeshNodeVerts[i] = getvert meshNode.mesh i
					gc()
						
					-- iterate through mesh chunk verts, and see if a vert in actual mesh corresponds to it
					-- Note that this might result in errors if more than one vert exists at the exact same spot
					for i = 1 to meshChunk.vertices.count do
					(
						vertices[i] = -1
						for j = 1 to tempMeshNodeVerts.count while vertices[i] == -1 do
						(
							-- Check each component of the verts separately, since they probably won't be exact,
							-- so we need to just make sure they're within a suitable tolerance
							if abs (tempMeshNodeVerts[j].x - meshChunk.vertices[i].pos.x) < safeApplyTolerance and 
								 abs (tempMeshNodeVerts[j].y - meshChunk.vertices[i].pos.y) < safeApplyTolerance and
								 abs (tempMeshNodeVerts[j].z - meshChunk.vertices[i].pos.z) < safeApplyTolerance then
							(
								vertices[i] = j		
							)
						)
					)				
					
				)
				else
				(
					-- Create a direct mapping. Not most efficient way, but it keeps the next function cleaner
					for i = 1 to meshChunk.vertices.count do
						vertices[i] = i
				)
				
				-- Create copy of mesh and hide all but the head faces
				local m = copy meshNode
				showHeadOnly m meshChunk
				
				local xpos = m.pos.x + 75
				for x in morphChunks do
				(
					xpos = xpos + 25
					addMeshMorph m morph x meshChunk vertices xpos
				)
				
				delete m
				
				enableSceneRedraw()	
			)
		)
		
	),
	
	fn createMesh meshChunk bSeeThrough:false bApplyMorph:true =
	(
		-- Create bone structure for this mesh if applicable
		if meshChunk.hasBoneInfo then
			createBoneStructure() 
			
		local m = createBasicMesh meshChunk
		
		if bSeeThrough then m.xray = true	
		append meshes m
				
		-- Find corresponding node chunk and add it's details to mesh
		local nodeChunk = chunkArchive.getNode meshChunk.header.chunkID
		setNodeDetails m nodeChunk
		
		/* ALR We'll just disable vert anims for the moment, since I some of them seem screwey, and I
		       can't figure out how to fix them yet
		-- Add vert anims to this mesh if applicable, but only if it doesn't have bone information
		-- Both on the same model seems to be rare, but I've had trouble making it work. Ignoring'
		-- vert anims in this case seems to give the desired result, so I'm not sure why they're here
		if meshChunk.vertAnimID != -1 and meshChunk.hasBoneInfo == false then
		(
			local vaChunk = chunkArchive.getVertAnim meshChunk.vertAnimID
			if vaChunk != undefined then
			(
				disableSceneRedraw()
				
				animateVertex m #all
				addVertAnim m vaChunk meshChunk
				
				enableSceneRedraw()	
			)
		)
		*/
		
		-- Add Skin and set vertex weights if applicable
		if meshChunk.hasBoneInfo then
		(
			disableSceneRedraw() 
			
			-- Adjust mesh verts to line up correctly with bones
			local weights = meshChunk.physique
			for i = 1 to weights.count do
			(
				local v = weights[i].vertexID + 1
				local p = [0,0,0]
				for x in weights[i].links do
				(
					local tm = bones[x.boneID + 1].transform
					p += x.offset * tm * x.blending 	
				)
				meshop.setVert m v p
			)
			
			-- Apply skin
			local s = skin()
			addModifier m s
			setcommandpaneltaskmode mode:#modify
			modpanel.setcurrentobject s ui:true
			
			-- Add bones to modifier
			for i = 1 to bones.count do
			(
				if i < bones.count then
					skinOps.addbone s bones[i] 0
				else
					skinOps.addbone s bones[i] 1 -- Only update skin system on final bone	
			)	
						
			update m.mesh
							
			-- Set weights in skin
			local weights = meshChunk.physique
			for i = 1 to weights.count do
			(
				local v = weights[i].vertexID + 1
				local boneArray = #()
				local weightArray = #()
				
				for x in weights[i].links do
				(
					append boneArray (x.boneID + 1)
					append weightArray x.blending 	
				)
				
				skinops.ReplaceVertexWeights s v boneArray weightArray
			)		
			
			enableSceneRedraw()		
		)
		
		-- Add mesh morphs to this mesh if applicable
		if bApplyMorph == true then applyMorpher m meshChunk false
			
		update m.mesh
	),
	
	fn clampLimits vector =
	(
		local v = vector * (180/PI) -- Convert to degrees
		for i = 1 to 3 do
			if v[i] < -180 or v[i] > 180 then v[i] = 0.0
			
		return v
	),
	
	fn setIKData b phys =
	(
		local bits = #{}
		
		-- Set axis active flags 
		-- For some reason these are stored inverted, so we check for ==0 rather than !=0
		bits[1] = (bit.and phys.flags (2^0)) == 0 
		bits[2] = (bit.and phys.flags (2^1)) == 0
		bits[3] = (bit.and phys.flags (2^2)) == 0
		ik.setAxisActive b #rotational bits	
		
		-- Clamp any axis limit amounts to 0 if they are outside of (-180,180)
		local minimumVec = clampLimits phys.minimum
		local maximumVec = clampLimits phys.maximum
		
		-- Set axis limited flags for any axis that is flagged active, and has a non-zero
		-- minimum or maximum limit
		for i = 1 to 3 do
			if bits[i] == true and (minimumVec[i] != 0.0 or maximumVec[i] != 0.0) then
				bits[i] = true
			else
				bits[i] = false
		ik.setAxisLimit b #rotational bits 
		
		/* None of these flags appear to ever be set		
		-- Set axis limited flags
		bits[1] = (bit.and phys.flags (2^3)) != 0
		bits[2] = (bit.and phys.flags (2^4)) != 0
		bits[3] = (bit.and phys.flags (2^5)) != 0
		ik.setAxisLimit b #rotational bits	
		
		-- Set axis ease flags
		bits[1] = (bit.and phys.flags (2^6)) != 0
		bits[2] = (bit.and phys.flags (2^7)) != 0
		bits[3] = (bit.and phys.flags (2^8)) != 0
		ik.setAxisEase b #rotational bits	
		
		-- Set axis spring flags
		bits[1] = (bit.and phys.flags (2^9)) != 0
		bits[2] = (bit.and phys.flags (2^10)) != 0
		bits[3] = (bit.and phys.flags (2^11)) != 0
		ik.setAxisSpringOn b #rotational bits	
		*/
		
		-- Set other params
		ik.setAxisMin b #rotational minimumVec 
		ik.setAxisMax b #rotational maximumVec
		ik.setAxisDamping b #rotational phys.damping
		ik.setAxisSpring b #rotational (phys.springAngle * (180/PI))
		ik.setAxisSpringTension b #rotational (phys.springTension	* 0.02) -- Don't know why we need to div by 50
	),
	
	fn createPhysicsMesh =
	(
		local physBones = #()
		for i = 1 to chunkArchive.boneAnimChunks[1].bones.count do
		(	
			local x = chunkArchive.boneAnimChunks[1].bones[i]
			
			-- Check if we need to build a physics mesh for this bone
			if x.bonePhysics.meshID <= 0 then
			(
				physBones[i] = undefined
				continue
			)
			
			-- Create bone mesh
			local boneMesh = chunkArchive.getBoneMeshFromChunkID x.bonePhysics.meshID
			if boneMesh != undefined then
			(
				local b = createBasicMesh boneMesh	
				
				hide b -- Phys mesh should default to hidden
				b.name = x.name + " Phys"
				b.transform = chunkArchive.getBoneInitialPos x.boneID
				
				-- Offset physics mesh to the right and back of real mesh (from our POV)
				b.pos.x += 200 
				b.pos.y += 50
					
				-- determine parent
				local parentID = x.parentID
				local parent = undefined
				
				-- Find nearest parent physics mesh (unless this ends up being the root physics mesh)
				while parentID > 0 and parent == undefined do
				(
					if physBones[parentID + 1] != undefined then
					(
						-- Found parent!
						parent = physBones[parentID + 1]
					)
					else
					(
						-- Look further up the chain
						local bonedata = chunkArchive.boneAnimChunks[1].bones[parentID + 1]
						parentID = bonedata.parentID
					)
				)			
				b.parent = parent			
				
				-- Set IK data
				setIKData b x.bonePhysics
					
				physBones[i] = b	
				
				-- Do we need to add in a 'Parent Frame' bone between this one and it's current parent
				if b.parent != undefined then
				(
					local parentPhys = chunkArchive.boneAnimChunks[1].bones[parentID + 1].bonePhysics
					
					-- Not certain if this test is a reliable one, but all examples so far seem to have
					-- framematrix[1][1] = 100 normally, and to equal a small value (-1,1) if the parent
					-- is a parent frame node
					if x.bonePhysics.frameMatrix[1][1] < parentPhys.frameMatrix[1][1] then
					(
						-- Make copy of parent mesh 
						local m = copy b.parent 
						m.wireColor = wireColor -- Set wireframe color of all objects to grey
						m.name = b.name + " ParentFrame"
						m.parent = b.parent
						b.parent = m	
						setIKData m parentPhys	-- Parent frame has mesh and physics of parent bone			
						hide m							
					)
				)
			)
			else
			(
				-- We should never get here, but just in case...
				physBones[i] = undefined
			)
		)
	),
	
	fn createController826 controllerChunk =
	(
		local c = controllerChunk
		local ctrl = getCtrl c.ctrlID
		
		if ctrl == undefined then return undefined
		
		-- This is used by all controllers except CryBone
		local ctrlString = ""
		if ctrl.property == "" then 
			ctrlString = "controller"
		else
			ctrlString = ctrl.property + ".controller"
				
		-- Deal with controller based on type
		if c.type == controllerType_CryBone then
		--- CRYBONE CONTROLLER ---
		(
			-- We use a PRS controller
			ctrl.object.controller = prs()
			
			-- Add animation keys to the controller
			animate on
			(
				for k in c.keys do
				(
					local t = (k.time / ticksperframe)
					if t < validKeyRange.start or t > validKeyRange.end then continue
					t += timingOffset -- Adjust time to be within current animation range
					
					at time t
					(
						ctrl.object.controller.rotation = k.relquat	
						ctrl.object.controller.position = k.relpos					
					)
				)	
				
				-- Add last key to final frame if there isn't one there already
				createLockKey ctrl.object.controller animationrange.end 0
					
			)	
						
		) else if c.type == controllerType_Linear1 or \
		          c.type == controllerType_Linear3 or \
		          c.type == controllerType_LinearQ then
		--- LINEAR CONTROLLER ---
		(	
			-- We use a linear controller
			local f
			case c.type of
			(
				controllerType_Linear1: f = linear_float
				controllerType_Linear3: f = linear_position
				controllerType_LinearQ: f = linear_rotation
			)
			if ctrl.property == "position" then
				f = linear_position
			else if ctrl.property == "scale" then
				f = linear_scale
				
			setproperty ctrl.object ctrlString (f())
				 
			-- Add animation keys to the controller
			local controller = getproperty ctrl.object ctrlString
			for k in c.keys do
			(
				local t = (k.time / ticksperframe) 
				if t < validKeyRange.start or t > validKeyRange.end then continue
				t += timingOffset -- Adjust time to be within current animation range
				
				addNewKey controller t
				
				local i = getKeyIndex controller.keys t
				controller.keys[i].value = k.val
			)
			
			-- Add last key to final frame if there isn't one there already
			createLockKey controller animationrange.end 0	
						
		) else if c.type == controllerType_TCB1 or \
		          c.type == controllerType_TCB3 or \
		          c.type == controllerType_TCBQ then
		--- TCB CONTROLLER ---
		(
			-- We use a TCB controller
			local f
			case c.type of
			(
				controllerType_TCB1: f = TCB_float
				controllerType_TCB3: f = TCB_point3
				controllerType_TCBQ: f = TCB_rotation
			)
			if ctrl.property == "position" then
				f = TCB_position
			else if ctrl.property == "scale" then
				f = TCB_scale
				
			setproperty ctrl.object ctrlString (f())
				 
			-- Add animation keys to the controller
			local controller = getproperty ctrl.object ctrlString
			for k in c.keys do
			(
				local t = (k.time / ticksperframe) 
				if t < validKeyRange.start or t > validKeyRange.end then continue
				t += timingOffset -- Adjust time to be within current animation range
					
				addNewKey controller t
				
				local i = getKeyIndex controller.keys t
				controller.keys[i].value = k.val
				controller.keys[i].tension = k.t
				controller.keys[i].continuity = k.c
				controller.keys[i].bias = k.b
				controller.keys[i].easeTo = k.easeTo
				controller.keys[i].easeFrom = k.easeFrom
			)		
			
			-- Add last key to final frame if there isn't one there already
			createLockKey controller animationrange.end 0	
			
		)	else if c.type == controllerType_Bezier1 or \
		          c.type == controllerType_Bezier3 or \
		          c.type == controllerType_BezierQ then
		--- BEZIER CONTROLLER ---
		(
			-- We use a Bezier controller
			local f
			case c.type of
			(
				controllerType_Bezier1: f = Bezier_float
				controllerType_Bezier3: f = Bezier_point3
				controllerType_BezierQ: f = Bezier_rotation
			)
			if ctrl.property == "position" then
				f = Bezier_position
			else if ctrl.property == "scale" then
				f = Bezier_scale
			
			setproperty ctrl.object ctrlString (f())
				 
			-- Add animation keys to the controller
			local controller = getproperty ctrl.object ctrlString
			for k in c.keys do
			(
				local t = (k.time / ticksperframe) 
				if t < validKeyRange.start or t > validKeyRange.end then continue
				t += timingOffset -- Adjust time to be within current animation range
					
				addNewKey controller t
				
				local i = getKeyIndex controller.keys t
				controller.keys[i].value = k.val
				
				if c.type != controllerType_BezierQ then
				(
					controller.keys[i].inTangent = k.inTan
					controller.keys[i].outTangent = k.outTan
				)
				
				-- Add last key to final frame if there isn't one there already
				createLockKey controller animationrange.end 0
			)			
		)	
		
	),
	
	fn createController827 controllerChunk =
	(
		local c = controllerChunk
		local ctrl = getCtrl c.ctrlID
		
		if ctrl == undefined then return undefined
		
		-- V827 controllers contain pos and rot
		-- We use a PRS controller
		ctrl.object.controller = prs()
		
		-- Add animation keys to the controller
		animate on
		(
			for k in c.keys do
			(
				local t = (k.time / ticksperframe) 
				if t < validKeyRange.start or t > validKeyRange.end then continue
				t += timingOffset -- Adjust time to be within current animation range
					
				at time t
				(
					ctrl.object.controller.position = k.pos
					local r = (exp (quat k.rotLog.x k.rotLog.y k.rotLog.z 0))
					ctrl.object.controller.rotation = r			
				)
				
				-- Add last key to final frame if there isn't one there already
				createLockKey ctrl.object.controller animationrange.end 0
			)				
		)	
	),
	
	fn createController controllerChunk =
	(
		disableSceneRedraw()
			
		case controllerChunk.header.version of
		(
			0x0826:	createController826 controllerChunk 
			0x0827: createController827 controllerChunk 
		)		
		
		-- set slider time to start of time range
		sliderTime = animationRange.start
		
		enableSceneRedraw()
	),
	
	fn newScene =
	(
		meshes = #()
		bones = #()
		helpers = #()
		lights = #()
		sceneProps = #()
		morphMeshes = #()
		materials = #()
		materialChunks = #()
		matIDToMaxMatID = #()    
		matIDToMaxMaterial = #()  
		shaderList = #()
		ctrlIndex = ControllerIndex()
	),
	
	fn addGeom geomChunkArchive bSeeThrough:false bApplyMorph:false =
	(
		if (isKindOf geomChunkArchive CryChunkArchive) == false then
			return "Not initialised with a valid chunk archive"
		chunkArchive = geomChunkArchive
			
		set coordsys world
		
		-- Set timing values from timing chunk (take last timing chunk if more than one
		if chunkArchive.timingChunks.count > 0 then
			setTiming chunkArchive.timingChunks[chunkArchive.timingChunks.count]
		
		for x in chunkArchive.materialChunks do
		(
			-- check that material isn't already defined, since multis create their submaterials
			if (getMaterialByName x.name) == undefined then  
				createMaterial x
		)
		buildMatMappings() -- Build material mapping arrays so mesh chunks get proper material values
		
		for x in chunkArchive.lightChunks do
			createLight x
		
		for x in chunkArchive.meshChunks do
			createMesh x bSeeThrough:bSeeThrough bApplyMorph:bApplyMorph
		
		for x in chunkArchive.helperChunks do
			createHelper x	
				
		for x in chunkArchive.boneLightBindingChunks do
			for y in x.boneLightBinds do
				createBoneLightBind y
		
		for x in chunkArchive.controllerChunks do
			createController x
			
		for x in chunkArchive.scenePropChunks do
			createSceneProps x
		
		-- Build separate physics mesh if required
		if chunkArchive.separatePhysicsMesh == true then
			createPhysicsMesh()
				
		-- Print out shader details that user has to fix into the MaxScript Listener
		clearListener()
		local s = StringStream ""
		
		for x in shaderList do
		(
			if x.useOpacity == true then
				format "Material: [%] Sub-material: [%] Shader: [%]\n          [Activate Transparency->Opacity checkbox]\n" \
					x.material x.submaterial x.shader to:s
			else
				format "Material: [%] Sub-material: [%] Shader: [%]\n" x.material x.submaterial x.shader to:s
		)
		if chunkArchive.meshMorphTargetChunks.count > 0 then
			format "\nBefore exporting with CryExporter, set 'Morph target min offset' to 0.001\n" to:s
			
		format "Set the following shaders for the given materials:\n%" (s as String)
			
		messagebox ("Press F11 to open the MaxScript Listener window for a list of\n" + \
			          "settings that must be done manually by the user")
		        
	),
	
	fn addMorpher morphChunkArchive safeApply:false =
	(
		if (isKindOf morphChunkArchive CryChunkArchive) == false then
			return "Not initialised with a valid chunk archive"
		chunkArchive = morphChunkArchive
		
		-- Run through mesh chunks and see if any have associated morph chunks
		local count = 0;
		for x in chunkArchive.meshChunks do
		(
			if chunkArchive.hasMorphs x.header.chunkID == true then
			(
				-- Find corresponding node chunk and get mesh name
				local nodeChunk = chunkArchive.getNode x.header.chunkID
				
				if nodeChunk != undefined then
				(
					-- See if the scene contains a node with the given name
					local node = getNodeByName nodeChunk.name
					
					if node != undefined then
					(		
						-- Warn user if mesh has less verts than it should
						if safeApply == false and node.verts.count < x.vertices.count then
							messagebox "Mesh has had vertices deleted, morpher may not apply properly"
										
						count += 1
						applyMorpher node x safeApply
					)
				)
			)
		)
		
		if count > 0 then
			messagebox "Successfully applied morpher modifier to model"
		else
			messagebox "Unable to apply morpher modifier to any meshes in the scene"
	),
	
	fn addAnim animChunkArchive bAppendAnim:true =
	(
		if (isKindOf animChunkArchive CryChunkArchive) == false then
			return "Not initialised with a valid chunk archive"
		chunkArchive = animChunkArchive
			
		set coordsys world
		
		-- Set timing values from timing chunk (take last timing chunk if more than one)
		if chunkArchive.timingChunks.count > 0 then
			setTiming chunkArchive.timingChunks[chunkArchive.timingChunks.count] bAppendRange:bAppendAnim
		
		for x in chunkArchive.controllerChunks do
			createController x
	)	
) -- End of SceneBuilder struct