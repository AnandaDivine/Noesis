-- Constants, struct declarations, and constant identifier functions for CryImporter
-- Copyright 2006 Takaro Pty. Ltd.
-- www.takaro.net

/* Notes:
	* Max integers are 32 bit signed, but a hex constant such as 0xFFFF0000 is treated as a large
		+ve number, so it will be converted to a float, losing precision. To avoid this, constants
		>= 0x80000000 will be represented as high and low components, and will need to be treated
		appropriately in the code.
*/

---- Constants ----
	
-- File Constants
local fileSignature = "CryTek"

local fileType_Geom     = 1       -- These two constants are for our own convenience
local fileType_Anim     = 2

local fileType_GeomHigh = 0xFFFF  -- These 4 are the Crytek consts broken into high and low parts
local fileType_GeomLow  = 0x0000
local fileType_AnimHigh = 0xFFFF
local fileType_AnimLow  = 0x0001

local fileVersion_Geom  = 0x0744
local fileVersion_Anim  = 0x0744

-- Chunk types
local chunkType_High             = 0xCCCC
local chunkType_Mesh             = 0x0000
local chunkType_Helper           = 0x0001
local chunkType_VertAnim         = 0x0002
local chunkType_BoneAnim         = 0x0003
local chunkType_GeomNameList     = 0x0004  -- Obsolete
local chunkType_BoneNameList     = 0x0005
local chunkType_MaterialList     = 0x0006  -- Obsolete
local chunkType_MRM              = 0x0007  -- Obsolete
local chunkType_SceneProp        = 0x0008
local chunkType_Light            = 0x0009
local chunkType_PatchMesh        = 0x000A  -- Not implemented
local chunkType_Node             = 0x000B
local chunkType_Material         = 0x000C
local chunkType_Controller       = 0x000D
local chunkType_Timing           = 0x000E
local chunkType_BoneMesh         = 0x000F
local chunkType_BoneLightBinding = 0x0010  -- Describes the lights bound to bones
local chunkType_MeshMorphTarget  = 0x0011  -- Describes a morph target of a mesh chunk
local chunkType_BoneInitialPos   = 0x0012  -- Describes the initial position (4x3 matrix) of each
																					 -- bone; just an array of 4x3 matrices
local chunkType_SourceInfo       = 0x0013  -- Describes the source from which the cgf was exported:
																					 -- source max file, machine and user

-- Material types
local materialType_Unknown   = 0
local materialType_Standard  = 1
local materialType_Multi     = 2
local materialType_2Sided    = 3

-- Material flags
local materialFlag_Wire           = 0x001
local materialFlag_2Sided         = 0x002
local materialFlag_Facemap        = 0x004
local materialFlag_Faceted        = 0x008
local materialFlag_Additive       = 0x010
local materialFlag_Subtractive    = 0x020
local materialFlag_CryShader      = 0x040
local materialFlag_Physicalize    = 0x080
local materialFlag_AdditiveDecal  = 0x100
local materialFlag_UseGlossiness  = 0x200

-- Texture Mapping types
local textureType_Normal            = 0
local textureType_Environment       = 1
local textureType_ScreenEnvironment = 2
local textureType_Cubic             = 3
local textureType_AutoCubic         = 4

-- Texture Mapping flags
local textureFlag_NoMipMap = 1

-- Light types
local lightType_Omni     = 0
local lightType_Spot     = 1
local lightType_Direct   = 2
local lightType_Ambient  = 3

-- Controller types (v826 only)
local controllerType_None             = 0
local controllerType_CryBone          = 1
local controllerType_Linear1          = 2   -- float
local controllerType_Linear3          = 3   -- point3
local controllerType_LinearQ          = 4   -- quat
local controllerType_Bezier1          = 5   -- float
local controllerType_Bezier3          = 6   -- point3
local controllerType_BezierQ          = 7   -- quat
local controllerType_TCB1             = 8   -- float
local controllerType_TCB3             = 9   -- point3
local controllerType_TCBQ             = 10  -- quat
local controllerType_BSpline2Open     = 11  -- 2 byte fixed values, open   
local controllerType_BSpline1Open     = 12  -- 1 byte fixed values, open
local controllerType_BSpline2Closed   = 13  -- 2 byte fixed values, closed
local controllerType_BSpline1Closed   = 14  -- 1 byte fixed values, closed
local controllerType_Constant         = 15  -- Constant position and rotation

-- Controller flags (v826 only)
local controllerFlag_ORTCycle  = 0x01
local controllerFlag_ORTLoop   = 0x02

-- Helper types
local helperType_Point   = 0
local helperType_Dummy   = 1

-- Sizes of structures in chunk files
local size_CHUNK_HEADER = 16
local size_MTL_CHUNK_DESC_0746 = 2552
local size_MTL_CHUNK_DESC_0745 = 1208
local size_BONE_LINK = 20

-- Misc Constants
local defaultTicksPerFrame = 160


---- Structs ----

-- Chunk Related Structs --

-- Stores chunks from files
struct CryChunkArchive
(
	meshChunks = #(),
	helperChunks = #(),
	vertAnimChunks = #(),
	boneAnimChunks = #(),
	boneNameListChunks = #(),
	scenePropChunks = #(),
	lightChunks = #(),
	nodeChunks = #(),
	materialChunks = #(),
	controllerChunks = #(),
	timingChunks = #(),		
	boneMeshChunks = #(),   -- these are just CryMeshChunks
	boneLightBindingChunks = #(),
	meshMorphTargetChunks = #(),
	boneInitialPosChunks = #(),
	sourceInfoChunks = #(),
	numChunks = 0,
	geomFileName = undefined,
	separatePhysicsMesh = false,
	
	fn add chunk =
	(
		case chunk.header.type of
		(
			0x0000: append meshChunks chunk
			0x0001: append helperChunks chunk
			0x0002: append vertAnimChunks chunk
			0x0003: append boneAnimChunks chunk
			0x0004: return ok
			0x0005: append boneNameListChunks chunk
			0x0006: return ok
			0x0007: return ok
			0x0008: append scenePropChunks chunk
			0x0009: append lightChunks chunk
			0x000A: return ok
			0x000B: append nodeChunks chunk
			0x000C: append materialChunks chunk
			0x000D: append controllerChunks chunk
			0x000E: append timingChunks chunk
			0x000F: append boneMeshChunks chunk
			0x0010: append boneLightBindingChunks chunk
			0x0011: append meshMorphTargetChunks chunk
			0x0012: append boneInitialPosChunks chunk
			0x0013: append sourceInfoChunks chunk
			default: return ok
		)	
		numChunks += 1
	),
	
	fn merge src =
	(
		for x in src.meshChunks do
			append meshChunks x
		for x in src.helperChunks do
			append helperChunks x
		for x in src.vertAnimChunks do
			append vertAnimChunks x
		for x in src.boneAnimChunks do
			append boneAnimChunks x
		for x in src.boneNameListChunks do
			append boneNameListChunks x
		for x in src.scenePropChunks do
			append scenePropChunks x
		for x in src.lightChunks do
			append lightChunks x
		for x in src.nodeChunks do
			append nodeChunks x
		for x in src.materialChunks do
			append materialChunks x
		for x in src.controllerChunks do
			append controllerChunks x
		for x in src.timingChunks do
			append timingChunks x
		for x in src.boneMeshChunks do
			append boneMeshChunks x
		for x in src.boneLightBindingChunks do
			append boneLightBindingChunks x
		for x in src.meshMorphTargetChunks do
			append meshMorphTargetChunks x
		for x in src.boneInitialPosChunks do
			append boneInitialPosChunks x
		for x in src.sourceInfoChunks do
			append sourceInfoChunks x
		numChunks += src.numChunks	
		if src.geomFileName != undefined then geomFileName = src.geomFileName	
	),
	
	fn getTicksPerFrame =
	(		
		if timingChunks.count == 0 then
			return defaultTicksPerFrame
		else
			return timingChunks[1].ticksPerFrame -- Take value from 1st timing chunk (usually only 1)
	),
	
	fn getBoneName boneID =
	(
		local i = boneID + 1 -- since boneID starts at zero
		if boneNameListChunks[1].nameList.count >= i then
			return boneNameListChunks[1].nameList[i] -- Take value from 1st chunk (usually only 1)	
		else
			return undefined
	),
	
	fn hasBoneInitialPos =
	(
		if boneInitialPosChunks.count > 0 then true else false
	),
	
	fn getBoneInitialPos boneID =
	(
		local i = boneID + 1 -- since boneID starts at zero
		if boneInitialPosChunks.count > 0 then
			return boneInitialPosChunks[1].initialPositions[i] -- Take value from 1st chunk (usually only 1)	
		else 
			return undefined
	),
	
	fn getBoneMeshFromChunkID chunkID =
	(
		for x in boneMeshChunks do
			if x.header.chunkID == chunkID then return x
			
		return undefined
	),
	
	fn getBoneMeshFromBoneID boneID =
	(
		local i = boneID + 1
		if boneMeshChunks.count >= i then boneMeshChunks[i] else undefined
	),
	
	fn getChildBones parentBoneID boneAnimChunk =
	(
		local children = #()
		for x in boneAnimChunk.bones do
			if x.parentID == parentBoneID then append children x

		return children			
	),
	
	fn getBoneIDFromSubString sub =
	(
		-- Take value from 1st chunk (usually only 1)
		if boneNameListChunks.count > 0 then
		(
			local list = boneNameListChunks[1].nameList
			for i = 1 to list.count do
				if (findstring list[i] sub) != undefined then return (i - 1)
		)	
		return undefined
	),
	
	fn getNode objectID =
	(
		for x in nodeChunks do
			if x.objectID == objectID then return x
		return undefined
	),
	
	fn getMaterialName chunkID =
	(
		for x in materialChunks do
			if x.header.chunkID == chunkID then return x.name
		return undefined
	),
	
	fn getMaterialChunk chunkID =
	(
		for x in materialChunks do
			if x.header.chunkID == chunkID then return x
		return undefined
	),
	
	fn getLightName chunkID =
	(
		for x in lightChunks do
		(
			if x.header.chunkID == chunkID then 
			(
				local n = getNode chunkID
				if n != undefined then
					return n.name
			)
		)
		return undefined
	),
	
	fn hasMorphs meshID =
	(
		for x in meshMorphTargetChunks do
		(
			if x.meshChunkID == meshID then
				return true
		)
		return false
	),
	
	fn getMorphs meshID =
	(
		local morphs = #()
		for x in meshMorphTargetChunks do
		(
			if x.meshChunkID == meshID then
				append morphs x
		)
		return morphs
	),
	
	fn getVertAnim chunkID =
	(
		for x in vertAnimChunks do
		(
			if x.header.chunkID == chunkID then
				return x
		)
		return undefined
	)
)


struct CryChunkHeader
(
	type,         -- integer, one of chunk type constants defined above
	version,           -- integer
	fileOffset,        -- integer
	chunkID	           -- integer
)

struct CryMeshChunk
(
	header,	            -- CryChunkHeader
	hasBoneInfo,        -- boolean
	hasVertexColors,    -- boolean
	vertAnimID,         -- integer, ID of the related vertAnim chunk if present, -1 otherwise
	vertices = #(),     -- Array of CryVertex
	faces = #(),        -- Array of CryFace
	texVertices = #(),  -- Array of point3
	texFaces = #(),     -- Array of CryTexFace
  physique = #(),     -- Array of CryBoneLinks
  vertexColors = #()  -- Array of color
)

struct CryHelperChunk
(
	header,	  -- CryChunkHeader
	type,     -- integer, one of the helper type constants defined above
	size      -- point3, size in local x, y, z axes (for dummy only)
)

struct CryVertAnimChunk
(
	header,	           -- CryChunkHeader
	meshID,            -- integer, ID of the related mesh chunk
	keys = #()         -- Array of CryVertAnimKey
)

struct CryBoneAnimChunk
(
	header,	     -- CryChunkHeader
	bones = #()  -- Array of CryBone
)

struct CryBoneNameListChunk
(
	header,	           -- CryChunkHeader
	nameList = #()    -- list of strings
)

struct CryScenePropChunk
(
	header,	           -- CryChunkHeader
	props = #()        -- Array of CrySceneProp
)

struct CryLightChunk
(
	header,	               -- CryChunkHeader
	type,                  -- integer, one of the light type constants defined above
	isOn,                  -- boolean, light is on
	color,                 -- color
	intensity,             -- float, multiplier value
	hotSize,               -- float, spot and direct light hotspot value
	fallSize,              -- float, spot and direct light falloff value

	useNearAttenuation,    -- boolean, near attenuation is on
	nearAttenuationStart,  -- float
	nearAttenuationEnd,    -- float
	useFarAttenuation,     -- boolean, far attenuation is on
	farAttenuationStart,   -- float
	farAttenuationEnd,     -- float
	
	shadow,                -- boolean, shadow is on
	spotDirection,         -- point3, spot light direction
	spotTexture            -- string, up to 255 characters, spot light texture
)

struct CryNodeChunk
(
	header,	            -- CryChunkHeader
	name,               -- string, up to 63 characters
	objectID,           -- integer, ID of this nodes object chunk (if present)
	parentID,           -- integer, ID of parent node's chunk
	materialID,         -- integer, ID of material chunk
	isGroupHead,        -- boolean
	isGroupMember,      -- boolean
	
	transMatrix,        -- CryMatrix44, transformation matrix
	position,           -- point3, position component of matrix
	rotation,           -- quat, rotation component of matrix
	scale,              -- point3, scale component of matrix
	
	posCtrlID,          -- string, position controller ID
	rotCtrlID,          -- string, rotation controller ID
	scaleCtrlID,        -- string, scale controller ID
	
	property = "",      -- string, user defined property string
	childNodes = #()    -- Array of integers, list of chunk IDs of child nodes to this node	
)

struct CryMaterialChunk
(
	header,	          -- CryChunkHeader
	name,             -- string, up to 63 characters
	shaderName,       -- string, sub shader type of Crytek Shader
	surfaceName,      -- string, name of physical material this material represents
	type,             -- integer, one of material type constants defined above
	alphaTest,      	-- float, not sure what this is (only present in v746)
	children = #(),   -- array of integers, representing chunk IDs of submaterials if Multi material
	
	diffuse,                -- color
	specular,               -- color
	ambient,                -- color
	specularLevel,          -- float
	specularShininess,      -- float
	selfIllumination,       -- float
	opacity,                -- float (0-1)
	
	texDiffuse,             -- CryTexture
	texSpecular,            -- CryTexture
	texAmbient,             -- CryTexture
	texOpacity,             -- CryTexture
	texBump,                -- CryTexture
	texGloss,               -- CryTexture
	texFilter,              -- CryTexture (is actually detail map)
	texReflection,          -- CryTexture
	texSubSurface,          -- CryTexture (Subsurface Scattering Texture settings)
	texDetail,              -- CryTexture (this seems to be normal maps)
	
	flags,                  -- integer, can include any of the material flags listed above
	dynamicBounce,          -- float
	dynamicStaticFriction,  -- float
	dynamicSlidingFriction  -- float	
)

struct CryControllerChunk
(
	header,	     -- CryChunkHeader
	ctrlID,      -- string, controller ID
	keys = #(),  -- Array of CryKey for v827, various depending on type for v826
	
	-- These values are only used for v826	
	type = controllerType_None,  -- integer
	flags									       -- integer
)

struct CryTimingChunk
(
	header,	         -- CryChunkHeader
	secsPerTick,     -- float, seconds/tick
	ticksPerFrame,   -- integer, ticks/frame
	globalRange,     -- CryRange
	subRanges = #()  -- array of CryRange, sub-ranges within global range
)

struct CryBoneLightBindingChunk
(
	header,	              -- CryChunkHeader
	boneLightBinds = #()  -- Array of CryBoneLightBind
)

struct CryMeshMorphTargetChunk
(
	header,	              -- CryChunkHeader
	meshChunkID,          -- integer, chunk ID of the mesh chunk that this morph targets
	name,                 -- string, name of morph target
	targetVertices = #()  -- Array of CryMeshMorphTargetVertex
)

struct CryBoneInitialPosChunk
(
	header,	  -- CryChunkHeader
	meshChunkID,          -- integer, chunk ID of the mesh chunk that this bone info refers to
	initialPositions = #()  -- Array of Matrix3 (this is a 4x3 matrix built in to 3ds max)
)

struct CrySourceInfoChunk
(
	header,	     -- CryChunkHeader
	sourceFile,  -- string
	date,        -- string
	user         -- string
)


-- Other Structs --

struct CryVertex
(
	pos,    -- point3, Position
	normal	-- point3, Normal
)

struct CryFace
(
	v0, v1, v2,   -- integers, vertex indices
	matID,        -- integer, Material ID
	smoothGroup   -- integer, Smoothing group
)

struct CryTexFace
(
	t0, t1, t2  -- integers, texture vertex indices
)

struct CryMatrix44
(
	row1, row2, row3, row4  -- Point4
)

struct CryLink
(
	boneID,   -- integer, ID of bone associated with this link
	offset,   -- point3, position of the vertex in the local coordinates of the bone
	blending  -- float, weight of bone for given vertex
)

struct CryBoneLinks
(
	vertexID,    -- integer, ID of vertex associated with these links
	links = #()  -- array of CryLink
)

struct CryVertAnimKey
(
	keyTime,        -- integer, in ticks
	vertices = #()  -- Array of point3	
)

struct CryRange
(
	name,     -- string, up to 31 characters
	start,    -- integer
	end       -- integer
)

struct CryBone
(
	boneID,            -- integer
	name,              -- string
	parentID,          -- integer
	numChildren,       -- integer
	ctrlID,            -- string
	customProperty,    -- string, up to 31 characters, user defined information
	bonePhysics        -- CryBonePhysics
)

struct CryBonePhysics
(
	meshID,            -- ID of mesh that describes this bone
	flags,             -- integer
	minimum,           -- Point3 of floats
	maximum,           -- Point3 of floats
	springAngle,       -- Point3 of floats
	springTension,     -- Point3 of floats
	damping,           -- Point3 of floats
	frameMatrix = #()  -- Array of 3 Point3 of floats (i.e. a 3x3 array of floats)
)

struct CryBoneLightBind
(
	lightChunkID,          -- integer, chunk ID of light that's bound to bone
	boneID,                -- integer, boneID
	lightOffset,           -- point3, light position in the parent bone coordinate system
	rotLightOrientation    -- point3, logarithm of quaternion that describes the light orientation
												 -- relative to the parent bone
)

struct CryMeshMorphTargetVertex
(
	vertexID,    -- integer, vertex index in the original (mesh) array of vertices
	targetPoint  -- point3, the target point of the morph target
)

struct CryTexture
(
	name,           -- string, up to 127 characters (up to 31 characters for v745 materials)
	type,           -- integer, one of the texture mapping types listed above
	flags = 0,      -- integer, can include any of the texture mapping flags listed above
	amount,         -- integer, texture strength
	
	-- Tiling and mirror
	uTile,            -- boolean
	uMirror,          -- boolean
	vTile,            -- boolean
	vMirror,          -- boolean
	nthFrame,         -- integer, update reflection every nth frame
	refSize,          -- integer, reflection size
	refBlur,          -- float, reflection blur
	
	-- Texture position values
	uOffset,          -- float
	uScale,           -- float
	uRotation,        -- float
	vOffset,          -- float
	vScale,           -- float
	vRotation,        -- float
	wRotation,        -- float
	
	-- Texture position controller chunk IDs (if not animated they are -1)
	uOffsetCtrlID,     -- string
	uScaleCtrlID,      -- string
	uRotationCtrlID,   -- string
	vOffsetCtrlID,     -- string
	vScaleCtrlID,      -- string
	vRotationCtrlID,   -- string
	wRotationCtrlID    -- string
)

struct CrySceneProp
(
	name,  -- string, up to 31 characters
	value  -- string, up to 63 characters
)

-- Controller Key structures

struct CryKey -- equiv to CryKeyPQLog, used by v827 controller only
(
	time,   -- integer, in ticks
	pos,    -- point3, position
	rotLog  -- point3, logarithm of the rotation
)

struct CryLin1Key
(
	time,   -- integer, in ticks
	val     -- float
)

struct CryLin3Key
(
	time,   -- integer, in ticks
	val     -- point3
)

struct CryLinQKey
(
	time,   -- integer, in ticks
	val     -- quat
)

struct CryTCB1Key
(
	time,     -- integer, in ticks
	val,      -- float
	t,        -- float, tension
	c,        -- float, continuity
	b,        -- float, bias
	easeTo,   -- float
	easeFrom  -- float
)

struct CryTCB3Key
(
	time,     -- integer, in ticks
	val,      -- point3
	t,        -- float, tension
	c,        -- float, continuity
	b,        -- float, bias
	easeTo,   -- float
	easeFrom  -- float
)

struct CryTCBQKey
(
	time,     -- integer, in ticks
	val,      -- quat
	t,        -- float, tension
	c,        -- float, continuity
	b,        -- float, bias
	easeTo,   -- float
	easeFrom  -- float
)

struct CryBez1Key
(
	time,   -- integer, in ticks
	val,    -- float
	inTan,  -- float
	outTan  -- float
)

struct CryBez3Key
(
	time,   -- integer, in ticks
	val,    -- point3
	inTan,  -- point3
	outTan  -- point3
)

struct CryBezQKey
(
	time,   -- integer, in ticks
	val     -- quat
)

struct CryBoneKey
(
	time,    -- integer, in ticks
	abspos,  -- point3
	relpos,  -- point3
	relquat  -- quat
)

struct CAFRecord
(
	name="",
	path="",
	startFrame,
	endFrame	
)

---- Functions ----

fn stringFileType type =
(
	case type of
	(
		fileType_Geom: return "Geom"
		fileType_Anim: return "Anim"
		default: return "unknown"
	)
)

fn stringChunkType type =
(
	case type of
	(
		chunkType_Mesh            : return "Mesh"
		chunkType_Helper          : return "Helper"
		chunkType_VertAnim        : return "VertAnim"
		chunkType_BoneAnim        : return "BoneAnim"
		chunkType_GeomNameList    : return "GeomNameList"
		chunkType_BoneNameList    : return "BoneNameList"
		chunkType_MaterialList    : return "MaterialList"
		chunkType_MRM             : return "MRM"
		chunkType_SceneProp       : return "SceneProp"
		chunkType_Light           : return "Light"
		chunkType_PatchMesh       : return "PatchMesh"
		chunkType_Node            : return "Node"
		chunkType_Material        : return "Material"
		chunkType_Controller      : return "Controller"
		chunkType_Timing          : return "Timing"
		chunkType_BoneMesh        : return "BoneMesh"
		chunkType_BoneLightBinding: return "BoneLightBinding"
		chunkType_MeshMorphTarget : return "MeshMorphTarget"
		chunkType_BoneInitialPos  : return "BoneInitialPos"
		chunkType_SourceInfo      : return "SourceInfo"
		default                   : return "Unknown"
	)
)

fn stringTextureType type =
(
	case type of
	(
		textureType_Normal           : return "Normal"
		textureType_Environment      : return "Environment"
		textureType_ScreenEnvironment: return "ScreenEnvironment"
		textureType_Cubic            : return "Cubic"
		textureType_AutoCubic        : return "AutoCubic"
		default                      : return "Unknown"
	)
)
		
fn stringHelperType type =
(
	case type of
	(
		helperType_Point: return "Point"
		helperType_Dummy: return "Dummy"
		default         : return "Unknown"
	)
)

fn stringMaterialType type =
(
	case type of
	(
		materialType_Unknown : return "Unknown"
		materialType_Standard: return "Standard"
		materialType_Multi   : return "Multi"
		materialType_2Sided  : return "TwoSided"
		default              : return "Unknown"
	)
)

fn stringLightType type =
(
	case type of
	(
		lightType_Omni   : return "Omni"
		lightType_Spot   : return "Spot"
		lightType_Direct : return "Direct"
		lightType_Ambient: return "Ambient"
		default          : return "Unknown"
	)
)

fn stringControllerType type =
(
	case type of
	(
		controllerType_None          : return "None"
		controllerType_CryBone       : return "CryBone"
		controllerType_Linear1       : return "Linear1"
		controllerType_Linear3       : return "Linear3"
		controllerType_LinearQ       : return "LinearQ"
		controllerType_Bezier1       : return "Bezier1"
		controllerType_Bezier3       : return "Bezier3"
		controllerType_BezierQ       : return "BezierQ"
		controllerType_TCB1          : return "TCB1"
		controllerType_TCB3          : return "TCB3"
		controllerType_TCBQ          : return "TCBQ"
		controllerType_BSpline2Open  : return "BSpline2Open"
		controllerType_BSpline1Open  : return "BSpline1Open"
		controllerType_BSpline2Closed: return "BSpline2Closed"
		controllerType_BSpline1Closed: return "BSpline1Closed"
		controllerType_Constant      : return "Constant"
		default                      : return "Unknown"
	)
)