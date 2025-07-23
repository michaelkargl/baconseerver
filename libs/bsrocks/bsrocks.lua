--[[
The MIT License (MIT)

Copyright (c) 2015-2016 SquidDev

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.


Diff Match and Patch

Copyright 2006 Google Inc.
	http://code.google.com/p/google-diff-match-patch/

Based on the JavaScript implementation by Neil Fraser
Ported to Lua by Duncan Cross

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

]]
local loading = {}
local oldRequire, preload, loaded = require, {}, { startup = loading }

local function require(name)
	local result = loaded[name]

	if result ~= nil then
		if result == loading then
			error("loop or previous error loading module '" .. name .. "'", 2)
		end

		return result
	end

	loaded[name] = loading
	local contents = preload[name]
	if contents then
		result = contents(name)
	elseif oldRequire then
		result = oldRequire(name)
	else
		error("cannot load '" .. name .. "'", 2)
	end

	if result == nil then result = true end
	loaded[name] = result
	return result
end
preload["bsrocks.rocks.rockspec"] = function(...)
local dependencies = require "bsrocks.rocks.dependencies"
local fileWrapper = require "bsrocks.lib.files"
local manifest = require "bsrocks.rocks.manifest"
local unserialize = require "bsrocks.lib.serialize".unserialize
local utils = require "bsrocks.lib.utils"

local log, warn, verbose, error = utils.log, utils.warn, utils.verbose, utils.error

local rockCache = {}

local function findRockspec(name)
	for server, manifest in pairs(manifest.fetchAll()) do
		if manifest.repository and manifest.repository[name] then
			return manifest
		end
	end

	return
end

local function latestVersion(manifest, name, constraints)
	local module = manifest.repository[name]
	if not module then error("Cannot find " .. name) end

	local version
	for name, dat in pairs(module) do
		local ver = dependencies.parseVersion(name)
		if constraints then
			if dependencies.matchConstraints(ver, constraints) then
				if not version or ver > version then
					version = ver
				end
			end
		elseif not version or ver > version then
			version = ver
		end
	end

	if not version then error("Cannot find version for " .. name) end

	return version.name
end

local function fetchRockspec(server, name, version)
	local whole = name .. "-" .. version

	local rockspec = rockCache[whole]
	if rockspec then return rockspec end

	log("Fetching rockspec " .. whole)
	verbose("Using '" .. server .. name .. '-' .. version .. ".rockspec' for " .. whole)

	local handle = http.get(server .. name .. '-' .. version .. '.rockspec')
	if not handle then
		error("Canot fetch " .. name .. "-" .. version .. " from " .. server, 0)
	end

	local contents = handle.readAll()
	handle.close()

	rockspec = unserialize(contents)
	rockCache[whole] = rockspec
	return rockspec
end

--- Extract files to download from rockspec
-- @see https://github.com/keplerproject/luarocks/wiki/Rockspec-format
local function extractFiles(rockspec, blacklist)
	local files, fileN = {}, 0
	blacklist = blacklist or {}

	local build = rockspec.build
	if build then
		if build.modules then
			for _, file in pairs(build.modules) do
				if not blacklist[file] then
					fileN = fileN + 1
					files[fileN] = file
				end
			end
		end

		-- Extract install locations
		if build.install then
			for _, install in pairs(build.install) do
				for _, file in pairs(install) do
					if not blacklist[file] then
						fileN = fileN + 1
						files[fileN] = file
					end
				end
			end
		end
	end

	return files
end

return {
	findRockspec = findRockspec,
	fetchRockspec = fetchRockspec,
	latestVersion = latestVersion,

	extractFiles = extractFiles
}

end
preload["bsrocks.rocks.patchspec"] = function(...)
local diff = require "bsrocks.lib.diff"
local fileWrapper = require "bsrocks.lib.files"
local manifest = require "bsrocks.rocks.manifest"
local patch = require "bsrocks.lib.patch"
local patchDirectory = require "bsrocks.lib.settings".patchDirectory
local unserialize = require "bsrocks.lib.serialize".unserialize
local utils = require "bsrocks.lib.utils"

local log, warn, verbose, error = utils.log, utils.warn, utils.verbose, utils.error

local patchCache = {}

local function findPatchspec(name)
	for server, manifest in pairs(manifest.fetchAll()) do
		if manifest.patches and manifest.patches[name] then
			return manifest
		end
	end

	return
end

local function fetchPatchspec(server, name)
	local result = patchCache[name] or false
	if result then return result end

	log("Fetching patchspec " .. name)
	verbose("Using '" .. server .. name .. ".patchspec' for " .. name)

	local handle = http.get(server .. name .. '.patchspec')
	if not handle then
		error("Canot fetch " .. name .. " from " .. server, 0)
	end

	local contents = handle.readAll()
	handle.close()

	result = unserialize(contents)
	result.server = server
	patchCache[name] = result

	return result
end

local installed = nil
local function getAll()
	if not installed then
		installed = {}
		local dir = fs.combine(patchDirectory, "rocks")
		for _, file in ipairs(fs.list(dir)) do
			if file:match("%.patchspec$") then
				local path = fs.combine(dir, file)
				local patchspec = unserialize(fileWrapper.read(path))
				installed[file:gsub("%.patchspec$", "")] = patchspec
			end
		end
	end

	return installed
end

local function extractFiles(patch)
	local files, n = {}, 0

	if patch.added then
		for _, file in ipairs(patch.added) do
			n = n + 1

			files[n] = file
		end
	end

	if patch.patches then
		for _, file in ipairs(patch.patches) do
			n = n + 1

			files[n] = file .. ".patch"
		end
	end

	return files
end

local function extractSource(rockS, patchS)
	local source = patchS and patchS.source
	if source then
		local version = rockS.version
		local out = {}
		for k, v in pairs(source) do
			if type(v) == "string" then v = v:gsub("%%{version}", version) end
			out[k] = v
		end
		return out
	end

	return rockS.source
end

local function makePatches(original, changed)
	local patches, remove = {}, {}
	local files = {}

	for path, originalContents in pairs(original) do
		local changedContents = changed[path]
		if changedContents then
			local diffs = diff(originalContents, changedContents)

			os.queueEvent("diff")
			coroutine.yield("diff")

			local patchData = patch.makePatch(diffs)
			if #patchData > 0 then
				patches[#patches + 1] = path
				files[path .. ".patch"] = patch.writePatch(patchData, path)
			end

			os.queueEvent("diff")
			coroutine.yield("diff")
		else
			remove[#remove + 1] = path
		end
	end

	local added = {}
	for path, contents in pairs(changed) do
		if not original[path] then
			added[#added + 1] = path
			files[path] = contents
		end
	end

	return files, patches, added, remove
end

local function applyPatches(original, files, patches, added, removed)
	assert(type(original) == "table", "exected table for original")
	assert(type(files) == "table", "exected table for replacement")
	assert(type(patches) == "table", "exected table for patches")
	assert(type(added) == "table", "exected table for added")
	assert(type(removed) == "table", "exected table for removed")

	local changed = {}
	local modified = {}
	local issues = false
	for _, file in ipairs(patches) do
		local patchContents = files[file .. ".patch"]
		local originalContents = original[file]

		if not patchContents then error("Cannot find patch " .. file .. ".patch") end
		if not originalContents then error("Cannot find original " .. file) end

		verbose("Applying patch to " .. file)
		local patches = patch.readPatch(patchContents)
		local success, message = patch.applyPatch(patches, originalContents, file)

		if not success then
			warn("Cannot apply " .. file .. ": " .. message)
			issues = true
		else
			changed[file] = success
			modified[file] = true
		end

		os.queueEvent("diff")
		coroutine.yield("diff")
	end

	if issues then
		error("Issues occured when patching", 0)
	end

	for _, file in ipairs(removed) do
		modified[file] = true
	end

	for _, file in ipairs(added) do
		local changedContents = files[file]
		if not changedContents then error("Cannot find added file " .. file) end

		changed[file] = changedContents
		modified[file] = true
	end

	for file, contents in pairs(original) do
		if not modified[file] then
			changed[file] = contents
		end
	end

	return changed
end

return {
	findPatchspec = findPatchspec,
	fetchPatchspec = fetchPatchspec,
	makePatches = makePatches,
	extractSource = extractSource,
	applyPatches = applyPatches,
	extractFiles = extractFiles,
	getAll = getAll,
}

end
preload["bsrocks.rocks.manifest"] = function(...)
local fileWrapper = require "bsrocks.lib.files"
local log = require "bsrocks.lib.utils".log
local settings = require "bsrocks.lib.settings"
local unserialize = require "bsrocks.lib.serialize".unserialize

local manifestCache = {}
local servers = settings.servers
local patchDirectory = settings.patchDirectory

local function fetchManifest(server)
	local manifest = manifestCache[server]
	if manifest then return manifest end

	log("Fetching manifest " .. server)

	local handle = http.get(server .. "manifest-5.1")
	if not handle then
		error("Cannot fetch manifest: " .. server, 0)
	end

	local contents = handle.readAll()
	handle.close()

	manifest = unserialize(contents)
	manifest.server = server
	manifestCache[server] = manifest
	return manifest
end

local function fetchAll()
	local toFetch, n = {}, 0
	for _, server in ipairs(servers) do
		if not manifestCache[server] then
			n = n + 1
			toFetch[n] = function() fetchManifest(server) end
		end
	end

	if n > 0 then
		if n == 1 then
			toFetch[1]()
		else
			parallel.waitForAll(unpack(toFetch))
		end
	end

	return manifestCache
end

local function loadLocal()
	local path = fs.combine(patchDirectory, "rocks/manifest-5.1")
	if not fs.exists(path) then
		return {
			repository = {},
			commands = {},
			modules = {},
			patches = {},
		}, path
	else
		return unserialize(fileWrapper.read(path)), path
	end
end

return {
	fetchManifest = fetchManifest,
	fetchAll = fetchAll,
	loadLocal = loadLocal,
}

end
preload["bsrocks.rocks.install"] = function(...)
local dependencies = require "bsrocks.rocks.dependencies"
local download = require "bsrocks.downloaders"
local fileWrapper = require "bsrocks.lib.files"
local patchspec = require "bsrocks.rocks.patchspec"
local rockspec = require "bsrocks.rocks.rockspec"
local serialize = require "bsrocks.lib.serialize"
local settings = require "bsrocks.lib.settings"
local tree = require "bsrocks.downloaders.tree"
local utils = require "bsrocks.lib.utils"

local installDirectory = settings.installDirectory
local log, warn, verbose, error = utils.log, utils.warn, utils.verbose, utils.error

local fetched = false
local installed = {}
local installedPatches = {}

local function extractFiles(rockS, patchS)
	local blacklist = {}
	if patchS and patchS.remove then
		for _, v in ipairs(patchS.remove) do blacklist[v] = true end
	end

	return rockspec.extractFiles(rockS, blacklist)
end

local function findIssues(rockS, patchS, files)
	files = files or extractFiles(rockS, patchS)

	local issues = {}
	local error = false

	local source = patchspec.extractSource(rockS, patchS)
	if not download(source, false) then
		issues[#issues + 1] = { "Cannot find downloader for " .. source.url .. ". Please suggest this package to be patched.", true }
		error = true
	end

	for _, file in ipairs(files) do
		if type(file) == "table" then
			issues[#issues + 1] = { table.concat(file, ", ") .. " are packaged into one module. This will not work.", true }
		else
			local ext = file:match("[^/]%.(%w+)$")
			if ext and ext ~= "lua" then
				if ext == "c" or ext == "cpp" or ext == "h" or ext == "hpp" then
					issues[#issues + 1] = { file .. " is a C file. This will not work.", true }
					error = true
				else
					issues[#issues + 1] = { "File extension is not lua (for " .. file .. "). It may not work correctly.", false }
				end
			end
		end
	end

	return error, issues
end

local function save(rockS, patchS)
	local files = extractFiles(rockS, patchS)

	local errored, issues = findIssues(rockS, patchS, files)
	if #issues > 0 then
		utils.printColoured("This package is incompatible", colors.red)

		for _, v in ipairs(issues) do
			local color = colors.yellow
			if v[2] then color = colors.red end

			utils.printColoured("  " .. v[1], color)
		end

		if errored then
			error("This package is incompatible", 0)
		end
	end

	local source = patchspec.extractSource(rockS, patchS)
	local downloaded = download(source, files)

	if not downloaded then
		-- This should never be reached.
		error("Cannot find downloader for " .. source.url .. ".", 0)
	end

	if patchS then
		local patchFiles = patchspec.extractFiles(patchS)
		local downloadPatch = tree(patchS.server .. rockS.package .. '/', patchFiles)

		downloaded = patchspec.applyPatches(downloaded, downloadPatch, patchS.patches or {}, patchS.added or {}, patchS.removed or {})
	end

	local build = rockS.build
	if build then
		if build.modules then
			local moduleDir = fs.combine(installDirectory, "lib")
			for module, file in pairs(build.modules) do
				verbose("Writing module " .. module)
				fileWrapper.writeLines(fs.combine(moduleDir, module:gsub("%.", "/") .. ".lua"), downloaded[file])
			end
		end

		-- Extract install locations
		if build.install then
			for name, install in pairs(build.install) do
				local dir = fs.combine(installDirectory, name)
				for name, file in pairs(install) do
					verbose("Writing " .. name .. " to " .. dir)
					if type(name) == "number" and name >= 1 and name <= #install then
						name = file
					end
					fileWrapper.writeLines(fs.combine(dir, name .. ".lua"), downloaded[file])
				end
			end
		end
	end

	fileWrapper.write(fs.combine(installDirectory, rockS.package .. ".rockspec"), serialize.serialize(rockS))

	if patchS then
		fileWrapper.write(fs.combine(installDirectory, rockS.package .. ".patchspec"), serialize.serialize(patchS))
	end

	installed[rockS.package] = rockS
end

local function remove(rockS, patchS)
	local blacklist = {}
	if patchspec and patchspec.remove then
		for _, v in ipairs(patchspec.remove) do blacklist[v] = true end
	end

	local files = rockspec.extractFiles(rockS, blacklist)

	local build = rockS.build
	if build then
		if build.modules then
			local moduleDir = fs.combine(installDirectory, "lib")
			for module, file in pairs(build.modules) do
				fs.delete(fs.combine(moduleDir, module:gsub("%.", "/") .. ".lua"))
			end
		end

		-- Extract install locations
		if build.install then
			for name, install in pairs(build.install) do
				local dir = fs.combine(installDirectory, name)
				for name, file in pairs(install) do
					fs.delete(fs.combine(dir, name .. ".lua"))
				end
			end
		end
	end

	fs.delete(fs.combine(installDirectory, rockS.package .. ".rockspec"))
	installed[rockS.package] = nil
end

local function getInstalled()
	if not fetched then
		fetched = true

		for name, version in pairs(settings.existing) do
			installed[name:lower()] = { version = version, package = name, builtin = true }
		end

		if fs.exists(installDirectory) then
			for _, file in ipairs(fs.list(installDirectory)) do
				if file:match("%.rockspec") then
					local data = serialize.unserialize(fileWrapper.read(fs.combine(installDirectory, file)))
					installed[data.package:lower()] = data
				elseif file:match("%.patchspec") then
					local name = file:gsub("%.patchspec", ""):lower()
					local data = serialize.unserialize(fileWrapper.read(fs.combine(installDirectory, file)))
					installedPatches[name] = data
				end
			end
		end
	end

	return installed, installedPatches
end

local function install(name, version, constraints)
	name = name:lower()
	verbose("Preparing to install " .. name .. " " .. (version or ""))

	-- Do the cheapest action ASAP
	local installed = getInstalled()
	local current = installed[name]
	if current and ((version == nil and constraints == nil) or current.version == version) then
		error(name .. " already installed", 0)
	end

	local rockManifest = rockspec.findRockspec(name)

	if not rockManifest then
		error("Cannot find '" .. name .. "'", 0)
	end

	local patchManifest = patchspec.findPatchspec(name)

	if not version then
		if patchManifest then
			version = patchManifest.patches[name]
		else
			version = rockspec.latestVersion(rockManifest, name, constraints)
		end
	end

	if current and current.version == version then
		error(name .. " already installed", 0)
	end

	local patchspec = patchManifest and patchspec.fetchPatchspec(patchManifest.server, name)
	local rockspec = rockspec.fetchRockspec(rockManifest.server, name, version)

	if rockspec.build and rockspec.build.type ~= "builtin" then
		error("Cannot build type '" .. rockspec.build.type .. "'. Please suggest this package to be patched.", 0)
	end

	local deps = rockspec.dependencies
	if patchspec and patchspec.dependencies then
		deps = patchspec.dependencies
	end
	for _, deps in ipairs(deps or {}) do
		local dependency = dependencies.parseDependency(deps)
		local name = dependency.name:lower()
		local current = installed[name]

		if current then
			local version = dependencies.parseVersion(current.version)
			if not dependencies.matchConstraints(version, dependency.constraints) then
				log("Updating dependency " .. name)
				install(name, nil, dependency.constraints)
			end
		else
			log("Installing dependency " .. name)
			install(name, nil, dependency.constraints)
		end
	end

	save(rockspec, patchspec)
end

return {
	getInstalled = getInstalled,
	install = install,
	remove = remove,
	findIssues = findIssues,
}

end
preload["bsrocks.rocks.dependencies"] = function(...)
local deltas = {
	scm =    1100,
	cvs =    1000,
	rc =    -1000,
	pre =   -10000,
	beta =  -100000,
	alpha = -1000000
}

local versionMeta = {
	--- Equality comparison for versions.
	-- All version numbers must be equal.
	-- If both versions have revision numbers, they must be equal;
	-- otherwise the revision number is ignored.
	-- @param v1 table: version table to compare.
	-- @param v2 table: version table to compare.
	-- @return boolean: true if they are considered equivalent.
	__eq = function(v1, v2)
		if #v1 ~= #v2 then
			return false
		end
		for i = 1, #v1 do
			if v1[i] ~= v2[i] then
				return false
			end
		end
		if v1.revision and v2.revision then
			return (v1.revision == v2.revision)
		end
		return true
	end,

	--- Size comparison for versions.
	-- All version numbers are compared.
	-- If both versions have revision numbers, they are compared;
	-- otherwise the revision number is ignored.
	-- @param v1 table: version table to compare.
	-- @param v2 table: version table to compare.
	-- @return boolean: true if v1 is considered lower than v2.
	__lt = function(v1, v2)
		for i = 1, math.max(#v1, #v2) do
			local v1i, v2i = v1[i] or 0, v2[i] or 0
			if v1i ~= v2i then
				return (v1i < v2i)
			end
		end

		if v1.revision and v2.revision then
			return (v1.revision < v2.revision)
		end

		-- They are equal, so we must escape
		return false
	end,

	--- Size comparison for versions.
	-- All version numbers are compared.
	-- If both versions have revision numbers, they are compared;
	-- otherwise the revision number is ignored.
	-- @param v1 table: version table to compare.
	-- @param v2 table: version table to compare.
	-- @return boolean: true if v1 is considered lower or equal than v2.
	__le = function(v1, v2)
		for i = 1, math.max(#v1, #v2) do
			local v1i, v2i = v1[i] or 0, v2[i] or 0
			if v1i ~= v2i then
				return (v1i <= v2i)
			end
		end

		if v1.revision and v2.revision then
			return (v1.revision <= v2.revision)
		end
		return true
	end,
}

--- Parse a version string, converting to table format.
-- A version table contains all components of the version string
-- converted to numeric format, stored in the array part of the table.
-- If the version contains a revision, it is stored numerically
-- in the 'revision' field. The original string representation of
-- the string is preserved in the 'string' field.
-- Returned version tables use a metatable
-- allowing later comparison through relational operators.
-- @param vstring string: A version number in string format.
-- @return table or nil: A version table or nil
-- if the input string contains invalid characters.
local function parseVersion(vstring)
	vstring = vstring:match("^%s*(.*)%s*$")
	local main, revision = vstring:match("(.*)%-(%d+)$")

	local version = {name=vstring}
	local i = 1

	if revision then
		vstring = main
		version.revision = tonumber(revision)
	end

	while #vstring > 0 do
		-- extract a number
		local token, rest = vstring:match("^(%d+)[%.%-%_]*(.*)")
		if token then
			local number = tonumber(token)
			version[i] = version[i] and version[i] + number/100000 or number
			i = i + 1
		else
			-- extract a word
			token, rest = vstring:match("^(%a+)[%.%-%_]*(.*)")
			if not token then
				error("Warning: version number '"..vstring.."' could not be parsed.", 0)

				if not version[i] then version[i] = 0 end
				break
			end
			local number = deltas[token] or (token:byte() / 1000)
			version[i] = version[i] and version[i] + number/100000 or number
		end
		vstring = rest
	end

	return setmetatable(version, versionMeta)
end

local operators = {
	["=="] = "==", ["~="] = "~=",
	[">"] = ">",   ["<"] = "<",
	[">="] = ">=", ["<="] = "<=", ["~>"] = "~>",

	-- plus some convenience translations
	[""] = "==", ["="] = "==", ["!="] = "~="
}

--- Consumes a constraint from a string, converting it to table format.
-- For example, a string ">= 1.0, > 2.0" is converted to a table in the
-- format {op = ">=", version={1,0}} and the rest, "> 2.0", is returned
-- back to the caller.
-- @param input string: A list of constraints in string format.
-- @return (table, string) or nil: A table representing the same
-- constraints and the string with the unused input, or nil if the
-- input string is invalid.
local function parseConstraint(constraint)
	assert(type(constraint) == "string")

	local no_upgrade, op, version, rest = constraint:match("^(@?)([<>=~!]*)%s*([%w%.%_%-]+)[%s,]*(.*)")
	local _op = operators[op]
	version = parseVersion(version)
	if not _op then
		return nil, "Encountered bad constraint operator: '" .. tostring(op) .. "' in '" .. input .. "'"
	end
	if not version then
		return nil, "Could not parse version from constraint: '" .. input .. "'"
	end

	return { op = _op, version = version, no_upgrade = no_upgrade=="@" and true or nil }, rest
end

--- Convert a list of constraints from string to table format.
-- For example, a string ">= 1.0, < 2.0" is converted to a table in the format
-- {{op = ">=", version={1,0}}, {op = "<", version={2,0}}}.
-- Version tables use a metatable allowing later comparison through
-- relational operators.
-- @param input string: A list of constraints in string format.
-- @return table or nil: A table representing the same constraints,
-- or nil if the input string is invalid.
local function parseConstraints(input)
	assert(type(input) == "string")

	local constraints, constraint, oinput = {}, nil, input
	while #input > 0 do
		constraint, input = parseConstraint(input)
		if constraint then
			table.insert(constraints, constraint)
		else
			return nil, "Failed to parse constraint '"..tostring(oinput).."' with error: ".. input
		end
	end
	return constraints
end

--- Convert a dependency from string to table format.
-- For example, a string "foo >= 1.0, < 2.0"
-- is converted to a table in the format
-- {name = "foo", constraints = {{op = ">=", version={1,0}},
-- {op = "<", version={2,0}}}}. Version tables use a metatable
-- allowing later comparison through relational operators.
-- @param dep string: A dependency in string format
-- as entered in rockspec files.
-- @return table or nil: A table representing the same dependency relation,
-- or nil if the input string is invalid.
local function parseDependency(dep)
	assert(type(dep) == "string")

	local name, rest = dep:match("^%s*([a-zA-Z0-9][a-zA-Z0-9%.%-%_]*)%s*(.*)")
	if not name then return nil, "failed to extract dependency name from '" .. tostring(dep) .. "'" end
	local constraints, err = parseConstraints(rest)
	if not constraints then return nil, err end
	return { name = name, constraints = constraints }
end

--- A more lenient check for equivalence between versions.
-- This returns true if the requested components of a version
-- match and ignore the ones that were not given. For example,
-- when requesting "2", then "2", "2.1", "2.3.5-9"... all match.
-- When requesting "2.1", then "2.1", "2.1.3" match, but "2.2"
-- doesn't.
-- @param version string or table: Version to be tested; may be
-- in string format or already parsed into a table.
-- @param requested string or table: Version requested; may be
-- in string format or already parsed into a table.
-- @return boolean: True if the tested version matches the requested
-- version, false otherwise.
local function partialMatch(version, requested)
	assert(type(version) == "string" or type(version) == "table")
	assert(type(requested) == "string" or type(version) == "table")

	if type(version) ~= "table" then version = parseVersion(version) end
	if type(requested) ~= "table" then requested = parseVersion(requested) end
	if not version or not requested then return false end

	for i, ri in ipairs(requested) do
		local vi = version[i] or 0
		if ri ~= vi then return false end
	end
	if requested.revision then
		return requested.revision == version.revision
	end
	return true
end

--- Check if a version satisfies a set of constraints.
-- @param version table: A version in table format
-- @param constraints table: An array of constraints in table format.
-- @return boolean: True if version satisfies all constraints,
-- false otherwise.
local function matchConstraints(version, constraints)
	assert(type(version) == "table")
	assert(type(constraints) == "table")

	local ok = true
	for _, constraint in pairs(constraints) do
		if type(constraint.version) == "string" then
			constraint.version = parseVersion(constraint.version)
		end

		local constraintVersion, constraintOp = constraint.version, constraint.op
		if     constraintOp == "==" then ok = version == constraintVersion
		elseif constraintOp == "~=" then ok = version ~= constraintVersion
		elseif constraintOp == ">"  then ok = version >  constraintVersion
		elseif constraintOp == "<"  then ok = version <  constraintVersion
		elseif constraintOp == ">=" then ok = version >= constraintVersion
		elseif constraintOp == "<=" then ok = version <= constraintVersion
		elseif constraintOp == "~>" then ok = partialMatch(version, constraintVersion)
		end
		if not ok then break end
	end
	return ok
end

return {
	parseVersion = parseVersion,
	parseConstraints = parseConstraints,
	parseDependency = parseDependency,
	matchConstraints = matchConstraints,
}

end
preload["bsrocks.lib.utils"] = function(...)
local logFile = require "bsrocks.lib.settings".logFile

if fs.exists(logFile) then fs.delete(logFile) end

--- Checks an argument has the correct type
-- @param arg The argument to check
-- @tparam string argType The type that it should be
local function checkType(arg, argType)
	local t = type(arg)
	if t ~= argType then
		error(argType .. " expected, got " .. t, 3)
	end
	return arg
end

--- Generate a temp name for a file
-- Pretty safe, though not 100% accurate
local function tmpName()
	return "/tmp/" .. os.clock() .. "-" .. math.random(1, 2^31-1)
end

local function traceback(thread, message, level)
	if type(thread) ~= "thread" then
		level = message
		message = thread
	end

	local level = checkType(level or 1, "number")

	local result = {"stack traceback: "}
	for i = 2, 20 do
		local _, err = pcall(error, "", i + level)
		if err == "" or err == "nil:" then
			break
		end

		result[i] = err
	end

	local contents = table.concat(result, "\n\t")
	if message then
		return tostring(message) .. "\n" .. contents
	end
	return contents
end

local printColoured, writeColoured
if term.isColour() then
	printColoured = function(text, colour)
		term.setTextColour(colour)
		print(text)
		term.setTextColour(colours.white)
	end

	writeColoured = function(text, colour)
		term.setTextColour(colour)
		write(text)
		term.setTextColour(colours.white)
	end
else
	printColoured = function(text) print(text) end
	writeColoured = write
end

local function doLog(msg)
	local handle
	if fs.exists(logFile) then
		handle = fs.open(logFile, "a")
	else
		handle = fs.open(logFile, "w")
	end

	handle.writeLine(msg)
	handle.close()
end

local function verbose(msg)
	doLog("[VERBOSE] " .. msg)
end

local function log(msg)
	doLog("[LOG] " .. msg)
	printColoured(msg, colours.lightGrey)
end

local function warn(msg)
	doLog("[WARN] " .. msg)
	printColoured(msg, colours.yellow)
end

local nativeError = error
local function error(msg, level)
	doLog("[ERROR] " .. msg)

	if level == nil then level = 2
	elseif level ~= 0 then level = level + 1 end

	nativeError(msg, level)
end

local matches = {
	["^"] = "%^", ["$"] = "%$", ["("] = "%(", [")"] = "%)",
	["%"] = "%%", ["."] = "%.", ["["] = "%[", ["]"] = "%]",
	["*"] = "%*", ["+"] = "%+", ["-"] = "%-", ["?"] = "%?",
	["\0"] = "%z",
}

--- Escape a string for using in a pattern
-- @tparam string pattern The string to escape
-- @treturn string The escaped pattern
local function escapePattern(pattern)
	return (pattern:gsub(".", matches))
end

local term = term
local function printIndent(text, indent)
	if type(text) ~= "string" then error("string expected, got " .. type(text), 2) end
	if type(indent) ~= "number" then error("number expected, got " .. type(indent), 2) end
	if stdout and stdout.isPiped then
		return stdout.writeLine(text)
	end

	local w, h = term.getSize()
	local x, y = term.getCursorPos()

	term.setCursorPos(indent + 1, y)

	local function newLine()
		if y + 1 <= h then
			term.setCursorPos(indent + 1, y + 1)
		else
			term.setCursorPos(indent + 1, h)
			term.scroll(1)
		end
		x, y = term.getCursorPos()
	end

	-- Print the line with proper word wrapping
	while #text > 0 do
		local whitespace = text:match("^[ \t]+")
		if whitespace then
			-- Print whitespace
			term.write(whitespace)
			x, y = term.getCursorPos()
			text = text:sub(#whitespace + 1 )
		end

		if text:sub(1, 1) == "\n" then
			-- Print newlines
			newLine()
			text = text:sub(2)
		end

		local subtext = text:match("^[^ \t\n]+")
		if subtext then
			text = text:sub(#subtext + 1)
			if #subtext > w then
				-- Print a multiline word
				while #subtext > 0 do
					if x > w then newLine() end
					term.write(subtext)
					subtext = subtext:sub((w-x) + 2)
					x, y = term.getCursorPos()
				end
			else
				-- Print a word normally
				if x + #subtext - 1 > w then newLine() end
				term.write(subtext)
				x, y = term.getCursorPos()
			end
		end
	end

	if y + 1 <= h then
		term.setCursorPos(1, y + 1)
	else
		term.setCursorPos(1, h)
		term.scroll(1)
	end
end


return {
	checkType = checkType,
	escapePattern = escapePattern,
	log = log,
	printColoured = printColoured,
	writeColoured = writeColoured,
	printIndent = printIndent,
	tmpName = tmpName,
	traceback = traceback,
	warn = warn,
	verbose = verbose,
	error = error,
}

end
preload["bsrocks.lib.settings"] = function(...)
local currentSettings = {
	patchDirectory = "/rocks-patch",
	installDirectory = "/rocks",
	servers = {
		'https://luarocks.org/m/root/',
		--'http://luarocks.org/',
		--'https://raw.githubusercontent.com/SquidDev-CC/Blue-Shiny-Rocks/rocks/',
		-- 'https://raw.githubusercontent.com/michaelkargl/lua-rocks-manifest/refs/heads/master/'
	},
	tries = 3,
	existing = {
		lua = "5.1",
		bit32 = "5.2.2-1", -- https://luarocks.org/modules/siffiejoe/bit32
		computercraft = (_HOST and _HOST:match("ComputerCraft ([%d%.]+)")) or _CC_VERSION or "1.0"
	},
	libPath = {
		"./?.lua",
		"./?/init.lua",
		"%{patchDirectory}/rocks/lib/?.lua",
		"%{patchDirectory}/rocks/lib/?/init.lua",
		"%{installDirectory}/lib/?.lua",
		"%{installDirectory}/lib/?/init.lua",
	},
	binPath = {
		"/rocks/bin/?.lua",
		"/rocks/bin/?",
	},
	logFile = "bsrocks.log"
}

if fs.exists(".bsrocks") then
	local serialize = require "bsrocks.lib.serialize"

	local handle = fs.open(".bsrocks", "r")
	local contents = handle.readAll()
	handle.close()

	for k, v in pairs(serialize.unserialize(contents)) do
		currentSettings[k] = v
	end
end

if settings then
	if fs.exists(".settings") then settings.load(".settings") end

	for k, v in pairs(currentSettings) do
		currentSettings[k] = settings.get("bsrocks." .. k, v)
	end
end

--- Add trailing slashes to servers
local function patchServers(servers)
	for i, server in ipairs(servers) do
		if server:sub(#server) ~= "/" then
			servers[i] = server .. "/"
		end
	end
end

patchServers(currentSettings.servers)

return currentSettings

end
preload["bsrocks.lib.serialize"] = function(...)
local function unserialize(text)
	local table = {}
	assert(load(text, "unserialize", "t", table))()
	table._ENV = nil
	return table
end

local keywords = {
	[ "and" ] = true, [ "break" ] = true, [ "do" ] = true, [ "else" ] = true,
	[ "elseif" ] = true, [ "end" ] = true, [ "false" ] = true, [ "for" ] = true,
	[ "function" ] = true, [ "if" ] = true, [ "in" ] = true, [ "local" ] = true,
	[ "nil" ] = true, [ "not" ] = true, [ "or" ] = true, [ "repeat" ] = true, [ "return" ] = true,
	[ "then" ] = true, [ "true" ] = true, [ "until" ] = true, [ "while" ] = true,
}

local function serializeImpl(value, tracking, indent, root)
	local vType = type(value)
	if vType == "table" then
		if tracking[value] ~= nil then error("Cannot serialize table with recursive entries") end
		tracking[value] = true

		if next(value) == nil then
			-- Empty tables are simple
			if root then
				return ""
			else
				return "{}"
			end
		else
			-- Other tables take more work
			local result, resultN = {}, 0
			local subIndent = indent
			if not root then
				resultN = resultN + 1
				result[resultN] = "{\n"
				subIndent = indent  .. "  "
			end

			local seen = {}
			local finish = "\n"
			if not root then finish = ",\n" end
			for k,v in ipairs(value) do
				seen[k] = true

				resultN = resultN + 1
				result[resultN] = subIndent .. serializeImpl(v, tracking, subIndent, false) .. finish
			end
			local keys, keysN, allString = {}, 0, true
			local t
			for k,v in pairs(value) do
				if not seen[k] then
					allString = allString and type(k) == "string"
					keysN = keysN + 1
					keys[keysN] = k
				end
			end

			if allString then
				table.sort(keys)
			end

			for _, k in ipairs(keys) do
				local entry
				local v = value[k]
				if type(k) == "string" and not keywords[k] and string.match( k, "^[%a_][%a%d_]*$" ) then
					entry = k .. " = " .. serializeImpl(v, tracking, subIndent)
				else
					entry = "[ " .. serializeImpl(k, tracking, subIndent) .. " ] = " .. serializeImpl(v, tracking, subIndent)
				end
				resultN = resultN + 1
				result[resultN] = subIndent .. entry .. finish
			end

			if not root then
				resultN = resultN + 1
				result[resultN] = indent .. "}"
			end

			return table.concat(result)
		end

	elseif vType == "string" then
		return string.format( "%q", value )

	elseif vType == "number" or vType == "boolean" or vType == "nil" then
		return tostring(value)
	else
		error("Cannot serialize type " .. type, 0)
	end
end

local function serialize(table)
	return serializeImpl(table, {}, "", true)
end

return {
	unserialize = unserialize,
	serialize = serialize,
}

end
preload["bsrocks.lib.patch"] = function(...)
local CONTEXT_THRESHOLD = 3

local function makePatch(diff)
	local out, n = {}, 0

	local oLine, nLine = 1, 1

	local current, cn = nil, 0
	local context = 0

	for i = 1, #diff do
		local data = diff[i]
		local mode, lines = data[1], data[2]

		if mode == "=" then
			oLine = oLine + #lines
			nLine = nLine + #lines

			if current then
				local change
				local finish = false
				if #lines > context + CONTEXT_THRESHOLD then
					-- We're not going to merge into the next group
					-- so just write the remaining items
					change = context
					finish = true
				else
					-- We'll merge into another group, so write everything
					change = #lines
				end

				for i = 1, change do
					cn = cn + 1
					current[cn] = { mode, lines[i] }
				end

				current.oCount = current.oCount + change
				current.nCount = current.nCount + change

				if finish then
					-- We've finished this run, and there is more remaining, so
					-- we shouldn't continue this patch
					context = 0
					current = nil
				else
					context = context - change
				end
			end
		else
			context = CONTEXT_THRESHOLD

			if not current then
				current = {
					oLine = oLine,
					oCount = 0,
					nLine = nLine,
					nCount = 0,
				}
				cn = 0

				local previous = diff[i - 1]
				if previous and previous[1] == "=" then
					local lines = previous[2]
					local change = math.min(CONTEXT_THRESHOLD, #lines)
					current.oCount = current.oCount + change
					current.nCount = current.nCount + change

					current.oLine = current.oLine - change
					current.nLine = current.nLine - change

					for i = #lines - change + 1, #lines do
						cn = cn + 1
						current[cn] = { "=", lines[i] }
					end
				end

				n = n + 1
				out[n] = current
			end

			if mode == "+" then
				nLine = nLine + #lines
				current.nCount = current.nCount + #lines
			elseif mode == "-" then
				oLine = oLine + #lines
				current.oCount = current.oCount + #lines
			else
				error("Unknown mode " .. tostring(mode))
			end

			for i = 1, #lines do
				cn = cn + 1
				current[cn] = { mode, lines[i] }
			end
		end
	end

	return out
end

local function writePatch(patch, name)
	local out, n = {}, 0

	if name then
		n = 2
		out[1] = "--- " .. name
		out[2] = "+++ " .. name
	end

	for i = 1, #patch do
		local p = patch[i]

		n = n + 1
		out[n] = ("@@ -%d,%d +%d,%d @@"):format(p.oLine, p.oCount, p.nLine, p.nCount)

		for i = 1, #p do
			local row = p[i]
			local mode = row[1]
			if mode == "=" then mode = " " end

			n = n + 1

			out[n] = mode .. row[2]
		end
	end

	return out
end

local function readPatch(lines)
	if lines[1]:sub(1, 3) ~= "---" then error("Invalid patch format on line #1") end
	if lines[2]:sub(1, 3) ~= "+++" then error("Invalid patch format on line #2") end

	local out, n = {}, 0
	local current, cn = nil, 0

	for i = 3, #lines do
		local line = lines[i]
		if line:sub(1, 2) == "@@" then
			local oLine, oCount, nLine, nCount = line:match("^@@ %-(%d+),(%d+) %+(%d+),(%d+) @@$")
			if not oLine then error("Invalid block on line #" .. i .. ": " .. line) end

			current = {
				oLine = oLine,
				oCount = oCount,
				nLine = nLine,
				nCount = nCount,
			}
			cn = 0

			n = n + 1
			out[n] = current
		else
			local mode = line:sub(1, 1)
			local data = line:sub(2)

			if mode == " " or mode == "" then
				-- Allow empty lines (when whitespace has been stripped)
				mode = "="
			elseif mode ~= "+" and mode ~= "-" then
				error("Invalid mode on line #" .. i .. ": " .. line)
			end

			cn = cn + 1
			if not current then error("No block for line #" .. i) end

			current[cn] = { mode, data }
		end
	end

	return out
end

local function applyPatch(patch, lines, file)
	local out, n = {}, 0

	local oLine = 1
	for i = 1, #patch do
		local data = patch[i]

		for i = oLine, data.oLine - 1 do
			n = n + 1
			out[n] = lines[i]
			oLine = oLine + 1
		end

		if oLine ~= data.oLine and oLine + 0 ~= data.oLine + 0 then
			return false, "Incorrect lines. Expected: " .. data.oLine .. ", got " .. oLine .. ". This may be caused by overlapping patches."
		end

		for i = 1, #data do
			local mode, line = data[i][1], data[i][2]

			if mode == "=" then
				if line ~= lines[oLine] then
					return false, "line #" .. oLine .. " is not equal."
				end

				n = n + 1
				out[n] = line
				oLine = oLine + 1
			elseif mode == "-" then
				if line ~= lines[oLine] then
					-- TODO: Diff the texts, compute difference, etc...
					-- print(("%q"):format(line))
					-- print(("%q"):format(lines[oLine]))
					-- return false, "line #" .. oLine .. " does not exist"
				end
				oLine = oLine + 1
			elseif mode == "+" then
				n = n + 1
				out[n] = line
			end
		end
	end

	for i = oLine, #lines do
		n = n + 1
		out[n] = lines[i]
	end

	return out
end

return {
	makePatch = makePatch,
	applyPatch = applyPatch,

	writePatch = writePatch,
	readPatch = readPatch,
}

end
preload["bsrocks.lib.parse"] = function(...)
--- Check if a Lua source is either invalid or incomplete

local setmeta = setmetatable
local function createLookup(tbl)
	for _, v in ipairs(tbl) do tbl[v] = true end
	return tbl
end

--- List of white chars
local whiteChars = createLookup { ' ', '\n', '\t', '\r' }

--- Lookup of escape characters
local escapeLookup = { ['\r'] = '\\r', ['\n'] = '\\n', ['\t'] = '\\t', ['"'] = '\\"', ["'"] = "\\'" }

--- Lookup of lower case characters
local lowerChars = createLookup {
	'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm',
	'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z'
}

--- Lookup of upper case characters
local upperChars = createLookup {
	'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
	'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'
}

--- Lookup of digits
local digits = createLookup { '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' }

--- Lookup of hex digits
local hexDigits = createLookup {
	'0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
	'A', 'a', 'B', 'b', 'C', 'c', 'D', 'd', 'E', 'e', 'F', 'f'
}

--- Lookup of valid symbols
local symbols = createLookup { '+', '-', '*', '/', '^', '%', ',', '{', '}', '[', ']', '(', ')', ';', '#' }

--- Lookup of valid keywords
local keywords = createLookup {
	'and', 'break', 'do', 'else', 'elseif',
	'end', 'false', 'for', 'function', 'goto', 'if',
	'in', 'local', 'nil', 'not', 'or', 'repeat',
	'return', 'then', 'true', 'until', 'while',
}

--- Keywords that end a block
local statListCloseKeywords = createLookup { 'end', 'else', 'elseif', 'until' }

--- Unary operators
local unops = createLookup { '-', 'not', '#' }

--- Stores a list of tokens
-- @type TokenList
-- @tfield table tokens List of tokens
-- @tfield number pointer Pointer to the current
-- @tfield table savedPointers A save point
local TokenList = {}
do
	--- Get this element in the token list
	-- @tparam int offset The offset in the token list
	function TokenList:Peek(offset)
		local tokens = self.tokens
		offset = offset or 0
		return tokens[math.min(#tokens, self.pointer + offset)]
	end

	--- Get the next token in the list
	-- @tparam table tokenList Add the token onto this table
	-- @treturn Token The token
	function TokenList:Get(tokenList)
		local tokens = self.tokens
		local pointer = self.pointer
		local token = tokens[pointer]
		self.pointer = math.min(pointer + 1, #tokens)
		if tokenList then
			table.insert(tokenList, token)
		end
		return token
	end

	--- Check if the next token is of a type
	-- @tparam string type The type to compare it with
	-- @treturn bool If the type matches
	function TokenList:Is(type)
		return self:Peek().Type == type
	end

	--- Check if the next token is a symbol and return it
	-- @tparam string symbol Symbol to check (Optional)
	-- @tparam table tokenList Add the token onto this table
	-- @treturn [ 0 ] ?|token If symbol is not specified, return the token
	-- @treturn [ 1 ] boolean If symbol is specified, return true if it matches
	function TokenList:ConsumeSymbol(symbol, tokenList)
		local token = self:Peek()
		if token.Type == 'Symbol' then
			if symbol then
				if token.Data == symbol then
					self:Get(tokenList)
					return true
				else
					return nil
				end
			else
				self:Get(tokenList)
				return token
			end
		else
			return nil
		end
	end

	--- Check if the next token is a keyword and return it
	-- @tparam string kw Keyword to check (Optional)
	-- @tparam table tokenList Add the token onto this table
	-- @treturn [ 0 ] ?|token If kw is not specified, return the token
	-- @treturn [ 1 ] boolean If kw is specified, return true if it matches
	function TokenList:ConsumeKeyword(kw, tokenList)
		local token = self:Peek()
		if token.Type == 'Keyword' and token.Data == kw then
			self:Get(tokenList)
			return true
		else
			return nil
		end
	end

	--- Check if the next token matches is a keyword
	-- @tparam string kw The particular keyword
	-- @treturn boolean If it matches or not
	function TokenList:IsKeyword(kw)
		local token = self:Peek()
		return token.Type == 'Keyword' and token.Data == kw
	end

	--- Check if the next token matches is a symbol
	-- @tparam string symbol The particular symbol
	-- @treturn boolean If it matches or not
	function TokenList:IsSymbol(symbol)
		local token = self:Peek()
		return token.Type == 'Symbol' and token.Data == symbol
	end

	--- Check if the next token is an end of file
	-- @treturn boolean If the next token is an end of file
	function TokenList:IsEof()
		return self:Peek().Type == 'Eof'
	end
end

--- Create a list of @{Token|tokens} from a Lua source
-- @tparam string src Lua source code
-- @treturn TokenList The list of @{Token|tokens}
local function lex(src)
	--token dump
	local tokens = {}

	do -- Main bulk of the work
		--line / char / pointer tracking
		local pointer = 1
		local line = 1
		local char = 1

		--get / peek functions
		local function get()
			local c = src:sub(pointer,pointer)
			if c == '\n' then
				char = 1
				line = line + 1
			else
				char = char + 1
			end
			pointer = pointer + 1
			return c
		end
		local function peek(n)
			n = n or 0
			return src:sub(pointer+n,pointer+n)
		end
		local function consume(chars)
			local c = peek()
			for i = 1, #chars do
				if c == chars:sub(i,i) then return get() end
			end
		end

		--shared stuff
		local function generateError(err, resumable)
			if resumable == true then
				resumable = 1
			else
				resumable = 0
			end
			error(line..":"..char..":"..resumable..":"..err, 0)
		end

		local function tryGetLongString()
			local start = pointer
			if peek() == '[' then
				local equalsCount = 0
				local depth = 1
				while peek(equalsCount+1) == '=' do
					equalsCount = equalsCount + 1
				end
				if peek(equalsCount+1) == '[' then
					--start parsing the string. Strip the starting bit
					for _ = 0, equalsCount+1 do get() end

					--get the contents
					local contentStart = pointer
					while true do
						--check for eof
						if peek() == '' then
							generateError("Expected `]"..string.rep('=', equalsCount).."]` near <eof>.", true)
						end

						--check for the end
						local foundEnd = true
						if peek() == ']' then
							for i = 1, equalsCount do
								if peek(i) ~= '=' then foundEnd = false end
							end
							if peek(equalsCount+1) ~= ']' then
								foundEnd = false
							end
						else
							if peek() == '[' then
								-- is there an embedded long string?
								local embedded = true
								for i = 1, equalsCount do
									if peek(i) ~= '=' then
										embedded = false
										break
									end
								end
								if peek(equalsCount + 1) == '[' and embedded then
									-- oh look, there was
									depth = depth + 1
									for i = 1, (equalsCount + 2) do
										get()
									end
								end
							end
							foundEnd = false
						end

						if foundEnd then
							depth = depth - 1
							if depth == 0 then
								break
							else
								for i = 1, equalsCount + 2 do
									get()
								end
							end
						else
							get()
						end
					end

					--get the interior string
					local contentString = src:sub(contentStart, pointer-1)

					--found the end. Get rid of the trailing bit
					for i = 0, equalsCount+1 do get() end

					--get the exterior string
					local longString = src:sub(start, pointer-1)

					--return the stuff
					return contentString, longString
				else
					return nil
				end
			else
				return nil
			end
		end

		--main token emitting loop
		while true do
			--get leading whitespace. The leading whitespace will include any comments
			--preceding the token. This prevents the parser needing to deal with comments
			--separately.
			local longStr = false
			while true do
				local c = peek()
				if c == '#' and peek(1) == '!' and line == 1 then
					-- #! shebang for linux scripts
					get()
					get()
					while peek() ~= '\n' and peek() ~= '' do
						get()
					end
				end
				if c == ' ' or c == '\t' or  c == '\n' or c == '\r' then
					get()
				elseif c == '-' and peek(1) == '-' then
					--comment
					get() get()
					local _, wholeText = tryGetLongString()
					if not wholeText then
						while peek() ~= '\n' and peek() ~= '' do
							get()
						end
					end
				else
					break
				end
			end

			--get the initial char
			local thisLine = line
			local thisChar = char
			local errorAt = ":"..line..":"..char..":> "
			local c = peek()

			--symbol to emit
			local toEmit = nil

			--branch on type
			if c == '' then
				--eof
				toEmit = { Type = 'Eof' }

			elseif upperChars[c] or lowerChars[c] or c == '_' then
				--ident or keyword
				local start = pointer
				repeat
					get()
					c = peek()
				until not (upperChars[c] or lowerChars[c] or digits[c] or c == '_')
				local dat = src:sub(start, pointer-1)
				if keywords[dat] then
					toEmit = {Type = 'Keyword', Data = dat}
				else
					toEmit = {Type = 'Ident', Data = dat}
				end

			elseif digits[c] or (peek() == '.' and digits[peek(1)]) then
				--number const
				local start = pointer
				if c == '0' and peek(1) == 'x' then
					get();get()
					while hexDigits[peek()] do get() end
					if consume('Pp') then
						consume('+-')
						while digits[peek()] do get() end
					end
				else
					while digits[peek()] do get() end
					if consume('.') then
						while digits[peek()] do get() end
					end
					if consume('Ee') then
						consume('+-')

						if not digits[peek()] then generateError("Expected exponent") end
						repeat get() until not digits[peek()]
					end

					local n = peek():lower()
					if (n >= 'a' and n <= 'z') or n == '_' then
						generateError("Invalid number format")
					end
				end
				toEmit = {Type = 'Number', Data = src:sub(start, pointer-1)}

			elseif c == '\'' or c == '\"' then
				local start = pointer
				--string const
				local delim = get()
				local contentStart = pointer
				while true do
					local c = get()
					if c == '\\' then
						get() --get the escape char
					elseif c == delim then
						break
					elseif c == '' or c == '\n' then
						generateError("Unfinished string near <eof>")
					end
				end
				local content = src:sub(contentStart, pointer-2)
				local constant = src:sub(start, pointer-1)
				toEmit = {Type = 'String', Data = constant, Constant = content}

			elseif c == '[' then
				local content, wholetext = tryGetLongString()
				if wholetext then
					toEmit = {Type = 'String', Data = wholetext, Constant = content}
				else
					get()
					toEmit = {Type = 'Symbol', Data = '['}
				end

			elseif consume('>=<') then
				if consume('=') then
					toEmit = {Type = 'Symbol', Data = c..'='}
				else
					toEmit = {Type = 'Symbol', Data = c}
				end

			elseif consume('~') then
				if consume('=') then
					toEmit = {Type = 'Symbol', Data = '~='}
				else
					generateError("Unexpected symbol `~` in source.")
				end

			elseif consume('.') then
				if consume('.') then
					if consume('.') then
						toEmit = {Type = 'Symbol', Data = '...'}
					else
						toEmit = {Type = 'Symbol', Data = '..'}
					end
				else
					toEmit = {Type = 'Symbol', Data = '.'}
				end

			elseif consume(':') then
				if consume(':') then
					toEmit = {Type = 'Symbol', Data = '::'}
				else
					toEmit = {Type = 'Symbol', Data = ':'}
				end

			elseif symbols[c] then
				get()
				toEmit = {Type = 'Symbol', Data = c}

			else
				local contents, all = tryGetLongString()
				if contents then
					toEmit = {Type = 'String', Data = all, Constant = contents}
				else
					generateError("Unexpected Symbol `"..c.."` in source.")
				end
			end

			--add the emitted symbol, after adding some common data
			toEmit.line = thisLine
			toEmit.char = thisChar
			tokens[#tokens+1] = toEmit

			--halt after eof has been emitted
			if toEmit.Type == 'Eof' then break end
		end
	end

	--public interface:
	local tokenList = setmetatable({
		tokens = tokens,
		pointer = 1
	}, {__index = TokenList})

	return tokenList
end

--- Create a AST tree from a Lua Source
-- @tparam TokenList tok List of tokens from @{lex}
-- @treturn table The AST tree
local function parse(tok)
	--- Generate an error
	-- @tparam string msg The error message
	-- @raise The produces error message
	local function GenerateError(msg) error(msg, 0) end

	local ParseExpr,
	      ParseStatementList,
	      ParseSimpleExpr

	--- Parse the function definition and its arguments
	-- @tparam Scope.Scope scope The current scope
	-- @treturn Node A function Node
	local function ParseFunctionArgsAndBody()
		if not tok:ConsumeSymbol('(') then
			GenerateError("`(` expected.")
		end

		--arg list
		while not tok:ConsumeSymbol(')') do
			if tok:Is('Ident') then
				tok:Get()
				if not tok:ConsumeSymbol(',') then
					if tok:ConsumeSymbol(')') then
						break
					else
						GenerateError("`)` expected.")
					end
				end
			elseif tok:ConsumeSymbol('...') then
				if not tok:ConsumeSymbol(')') then
					GenerateError("`...` must be the last argument of a function.")
				end
				break
			else
				GenerateError("Argument name or `...` expected")
			end
		end

		ParseStatementList()

		if not tok:ConsumeKeyword('end') then
			GenerateError("`end` expected after function body")
		end
	end

	--- Parse a simple expression
	-- @tparam Scope.Scope scope The current scope
	-- @treturn Node the resulting node
	local function ParsePrimaryExpr()
		if tok:ConsumeSymbol('(') then
			ParseExpr()
			if not tok:ConsumeSymbol(')') then
				GenerateError("`)` Expected.")
			end
			return { AstType = "Paren" }
		elseif tok:Is('Ident') then
			tok:Get()
		else
			GenerateError("primary expression expected")
		end
	end

	--- Parse some table related expressions
	-- @tparam boolean onlyDotColon Only allow '.' or ':' nodes
	-- @treturn Node The resulting node
	function ParseSuffixedExpr(onlyDotColon)
		--base primary expression
		local prim = ParsePrimaryExpr() or { AstType = ""}

		while true do
			local tokenList = {}

			if tok:ConsumeSymbol('.') or tok:ConsumeSymbol(':') then
				if not tok:Is('Ident') then
					GenerateError("<Ident> expected.")
				end
				tok:Get()

				prim = { AstType = 'MemberExpr' }
			elseif not onlyDotColon and tok:ConsumeSymbol('[') then
				ParseExpr()
				if not tok:ConsumeSymbol(']') then
					GenerateError("`]` expected.")
				end

				prim = { AstType = 'IndexExpr' }
			elseif not onlyDotColon and tok:ConsumeSymbol('(') then
				while not tok:ConsumeSymbol(')') do
					ParseExpr()
					if not tok:ConsumeSymbol(',') then
						if tok:ConsumeSymbol(')') then
							break
						else
							GenerateError("`)` Expected.")
						end
					end
				end

				prim = { AstType = 'CallExpr' }
			elseif not onlyDotColon and tok:Is('String') then
				--string call
				tok:Get()
				prim = { AstType = 'StringCallExpr' }
			elseif not onlyDotColon and tok:IsSymbol('{') then
				--table call
				ParseSimpleExpr()
				prim = { AstType   = 'TableCallExpr' }
			else
				break
			end
		end
		return prim
	end

	--- Parse a simple expression (strings, numbers, booleans, varargs)
	-- @treturn Node The resulting node
	function ParseSimpleExpr()
		if tok:Is('Number') or tok:Is('String') then
			tok:Get()
		elseif tok:ConsumeKeyword('nil') or tok:ConsumeKeyword('false') or tok:ConsumeKeyword('true') or tok:ConsumeSymbol('...') then
		elseif tok:ConsumeSymbol('{') then
			while true do
				if tok:ConsumeSymbol('[') then
					--key
					ParseExpr()

					if not tok:ConsumeSymbol(']') then
						GenerateError("`]` Expected")
					end
					if not tok:ConsumeSymbol('=') then
						GenerateError("`=` Expected")
					end

					ParseExpr()
				elseif tok:Is('Ident') then
					--value or key
					local lookahead = tok:Peek(1)
					if lookahead.Type == 'Symbol' and lookahead.Data == '=' then
						--we are a key
						local key = tok:Get()

						if not tok:ConsumeSymbol('=') then
							GenerateError("`=` Expected")
						end

						ParseExpr()
					else
						--we are a value
						ParseExpr()

					end
				elseif tok:ConsumeSymbol('}') then
					break

				else
					ParseExpr()
				end

				if tok:ConsumeSymbol(';') or tok:ConsumeSymbol(',') then
					--all is good
				elseif tok:ConsumeSymbol('}') then
					break
				else
					GenerateError("`}` or table entry Expected")
				end
			end
		elseif tok:ConsumeKeyword('function') then
			return ParseFunctionArgsAndBody()
		else
			return ParseSuffixedExpr()
		end
	end

	local unopprio = 8
	local priority = {
		['+'] = {6,6},
		['-'] = {6,6},
		['%'] = {7,7},
		['/'] = {7,7},
		['*'] = {7,7},
		['^'] = {10,9},
		['..'] = {5,4},
		['=='] = {3,3},
		['<'] = {3,3},
		['<='] = {3,3},
		['~='] = {3,3},
		['>'] = {3,3},
		['>='] = {3,3},
		['and'] = {2,2},
		['or'] = {1,1},
	}

	--- Parse an expression
	-- @tparam int level Current level (Optional)
	-- @treturn Node The resulting node
	function ParseExpr(level)
		level = level or 0
		--base item, possibly with unop prefix
		if unops[tok:Peek().Data] then
			local op = tok:Get().Data
			ParseExpr(unopprio)
		else
			ParseSimpleExpr()
		end

		--next items in chain
		while true do
			local prio = priority[tok:Peek().Data]
			if prio and prio[1] > level then
				local tokenList = {}
				tok:Get()
				ParseExpr(prio[2])
			else
				break
			end
		end
	end

	--- Parse a statement (if, for, while, etc...)
	-- @treturn Node The resulting node
	local function ParseStatement()
		if tok:ConsumeKeyword('if') then
			--clauses
			repeat
				ParseExpr()

				if not tok:ConsumeKeyword('then') then
					GenerateError("`then` expected.")
				end

				ParseStatementList()
			until not tok:ConsumeKeyword('elseif')

			--else clause
			if tok:ConsumeKeyword('else') then
				ParseStatementList()
			end

			--end
			if not tok:ConsumeKeyword('end') then
				GenerateError("`end` expected.")
			end
		elseif tok:ConsumeKeyword('while') then
			--condition
			ParseExpr()

			--do
			if not tok:ConsumeKeyword('do') then
				return GenerateError("`do` expected.")
			end

			--body
			ParseStatementList()

			--end
			if not tok:ConsumeKeyword('end') then
				GenerateError("`end` expected.")
			end
		elseif tok:ConsumeKeyword('do') then
			--do block
			ParseStatementList()
			if not tok:ConsumeKeyword('end') then
				GenerateError("`end` expected.")
			end
		elseif tok:ConsumeKeyword('for') then
			--for block
			if not tok:Is('Ident') then
				GenerateError("<ident> expected.")
			end
			tok:Get()
			if tok:ConsumeSymbol('=') then
				--numeric for
				ParseExpr()
				if not tok:ConsumeSymbol(',') then
					GenerateError("`,` Expected")
				end
				ParseExpr()
				if tok:ConsumeSymbol(',') then
					ParseExpr()
				end
				if not tok:ConsumeKeyword('do') then
					GenerateError("`do` expected")
				end

				ParseStatementList()
				if not tok:ConsumeKeyword('end') then
					GenerateError("`end` expected")
				end
			else
				--generic for
				while tok:ConsumeSymbol(',') do
					if not tok:Is('Ident') then
						GenerateError("for variable expected.")
					end
					tok:Get(tokenList)
				end
				if not tok:ConsumeKeyword('in') then
					GenerateError("`in` expected.")
				end
				ParseExpr()
				while tok:ConsumeSymbol(',') do
					ParseExpr()
				end

				if not tok:ConsumeKeyword('do') then
					GenerateError("`do` expected.")
				end

				ParseStatementList()
				if not tok:ConsumeKeyword('end') then
					GenerateError("`end` expected.")
				end
			end
		elseif tok:ConsumeKeyword('repeat') then
			ParseStatementList()

			if not tok:ConsumeKeyword('until') then
				GenerateError("`until` expected.")
			end

			ParseExpr()
		elseif tok:ConsumeKeyword('function') then
			if not tok:Is('Ident') then
				GenerateError("Function name expected")
			end
			ParseSuffixedExpr(true) --true => only dots and colons
			ParseFunctionArgsAndBody()
		elseif tok:ConsumeKeyword('local') then
			if tok:Is('Ident') then
				tok:Get()
				while tok:ConsumeSymbol(',') do
					if not tok:Is('Ident') then
						GenerateError("local var name expected")
					end
					tok:Get()
				end

				if tok:ConsumeSymbol('=') then
					repeat
						ParseExpr()
					until not tok:ConsumeSymbol(',')
				end

			elseif tok:ConsumeKeyword('function') then
				if not tok:Is('Ident') then
					GenerateError("Function name expected")
				end

				tok:Get(tokenList)
				ParseFunctionArgsAndBody()
			else
				GenerateError("local var or function def expected")
			end
		elseif tok:ConsumeSymbol('::') then
			if not tok:Is('Ident') then
				GenerateError('Label name expected')
			end
			tok:Get()
			if not tok:ConsumeSymbol('::') then
				GenerateError("`::` expected")
			end
		elseif tok:ConsumeKeyword('return') then
			local exList = {}
			local token = tok:Peek()
			if token.Type == "Eof" or token.Type ~= "Keyword" or not statListCloseKeywords[token.Data] then
				ParseExpr()
				local token = tok:Peek()
				while tok:ConsumeSymbol(',') do
					ParseExpr()
				end
			end
		elseif tok:ConsumeKeyword('break') then
		elseif tok:ConsumeKeyword('goto') then
			if not tok:Is('Ident') then
				GenerateError("Label expected")
			end
			tok:Get(tokenList)
		else
			--statementParseExpr
			local suffixed = ParseSuffixedExpr()

			--assignment or call?
			if tok:IsSymbol(',') or tok:IsSymbol('=') then
				--check that it was not parenthesized, making it not an lvalue
				if suffixed.AstType == "Paren" then
					GenerateError("Can not assign to parenthesized expression, is not an lvalue")
				end

				--more processing needed
				while tok:ConsumeSymbol(',') do
					ParseSuffixedExpr()
				end

				--equals
				if not tok:ConsumeSymbol('=') then
					GenerateError("`=` Expected.")
				end

				--rhs
				ParseExpr()
				while tok:ConsumeSymbol(',') do
					ParseExpr()
				end
			elseif suffixed.AstType == 'CallExpr' or
				   suffixed.AstType == 'TableCallExpr' or
				   suffixed.AstType == 'StringCallExpr'
			then
				--it's a call statement
			else
				GenerateError("Assignment Statement Expected")
			end
		end

		tok:ConsumeSymbol(';')
	end

	--- Parse a a list of statements
	-- @tparam Scope.Scope scope The current scope
	-- @treturn Node The resulting node
	function ParseStatementList()
		while not statListCloseKeywords[tok:Peek().Data] and not tok:IsEof() do
			ParseStatement()
		end
	end

	return ParseStatementList()
end

return {
	lex = lex,
	parse = parse,
}

end
preload["bsrocks.lib.match"] = function(...)
--[[
* Diff Match and Patch
*
* Copyright 2006 Google Inc.
* http://code.google.com/p/google-diff-match-patch/
*
* Based on the JavaScript implementation by Neil Fraser.
* Ported to Lua by Duncan Cross.
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*	 http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
--]]

local band, bor, lshift = bit32.band, bit32.bor, bit32.lshift
local error = error
local strsub, strbyte, strchar, gmatch, gsub = string.sub, string.byte, string.char, string.gmatch, string.gsub
local strmatch, strfind, strformat = string.match, string.find, string.format
local tinsert, tremove, tconcat = table.insert, table.remove, table.concat
local max, min, floor, ceil, abs = math.max, math.min, math.floor, math.ceil, math.abs

local Match_Distance = 1000
local Match_Threshold = 0.3
local Match_MaxBits = 32

local function indexOf(a, b, start)
	if (#b == 0) then
		return nil
	end
	return strfind(a, b, start, true)
end

-- ---------------------------------------------------------------------------
--	MATCH API
-- ---------------------------------------------------------------------------

local _match_bitap, _match_alphabet

--[[
* Locate the best instance of 'pattern' in 'text' near 'loc'.
* @param {string} text The text to search.
* @param {string} pattern The pattern to search for.
* @param {number} loc The location to search around.
* @return {number} Best match index or -1.
--]]
local function match_main(text, pattern, loc)
	-- Check for null inputs.
	if text == nil or pattern == nil then error('Null inputs. (match_main)') end

	if text == pattern then
		-- Shortcut (potentially not guaranteed by the algorithm)
		return 1
	elseif #text == 0 then
		-- Nothing to match.
		return -1
	end
	loc = max(1, min(loc or 0, #text))
	if strsub(text, loc, loc + #pattern - 1) == pattern then
		-- Perfect match at the perfect spot!	(Includes case of null pattern)
		return loc
	else
		-- Do a fuzzy compare.
		return _match_bitap(text, pattern, loc)
	end
end

--[[
* Initialise the alphabet for the Bitap algorithm.
* @param {string} pattern The text to encode.
* @return {Object} Hash of character locations.
* @private
--]]
function _match_alphabet(pattern)
	local s = {}
	local i = 0
	for c in gmatch(pattern, '.') do
		s[c] = bor(s[c] or 0, lshift(1, #pattern - i - 1))
		i = i + 1
	end
	return s
end

--[[
* Locate the best instance of 'pattern' in 'text' near 'loc' using the
* Bitap algorithm.
* @param {string} text The text to search.
* @param {string} pattern The pattern to search for.
* @param {number} loc The location to search around.
* @return {number} Best match index or -1.
* @private
--]]
function _match_bitap(text, pattern, loc)
	if #pattern > Match_MaxBits then
		error('Pattern too long.')
	end

	-- Initialise the alphabet.
	local s = _match_alphabet(pattern)

	--[[
	* Compute and return the score for a match with e errors and x location.
	* Accesses loc and pattern through being a closure.
	* @param {number} e Number of errors in match.
	* @param {number} x Location of match.
	* @return {number} Overall score for match (0.0 = good, 1.0 = bad).
	* @private
	--]]
	local function _match_bitapScore(e, x)
		local accuracy = e / #pattern
		local proximity = abs(loc - x)
		if (Match_Distance == 0) then
			-- Dodge divide by zero error.
			return (proximity == 0) and 1 or accuracy
		end
		return accuracy + (proximity / Match_Distance)
	end

	-- Highest score beyond which we give up.
	local score_threshold = Match_Threshold
	-- Is there a nearby exact match? (speedup)
	local best_loc = indexOf(text, pattern, loc)
	if best_loc then
		score_threshold = min(_match_bitapScore(0, best_loc), score_threshold)
		-- LUANOTE: Ideally we'd also check from the other direction, but Lua
		-- doesn't have an efficent lastIndexOf function.
	end

	-- Initialise the bit arrays.
	local matchmask = lshift(1, #pattern - 1)
	best_loc = -1

	local bin_min, bin_mid
	local bin_max = #pattern + #text
	local last_rd
	for d = 0, #pattern - 1, 1 do
		-- Scan for the best match; each iteration allows for one more error.
		-- Run a binary search to determine how far from 'loc' we can stray at this
		-- error level.
		bin_min = 0
		bin_mid = bin_max
		while (bin_min < bin_mid) do
			if (_match_bitapScore(d, loc + bin_mid) <= score_threshold) then
				bin_min = bin_mid
			else
				bin_max = bin_mid
			end
			bin_mid = floor(bin_min + (bin_max - bin_min) / 2)
		end
		-- Use the result from this iteration as the maximum for the next.
		bin_max = bin_mid
		local start = max(1, loc - bin_mid + 1)
		local finish = min(loc + bin_mid, #text) + #pattern

		local rd = {}
		for j = start, finish do
			rd[j] = 0
		end
		rd[finish + 1] = lshift(1, d) - 1
		for j = finish, start, -1 do
			local charMatch = s[strsub(text, j - 1, j - 1)] or 0
			if (d == 0) then	-- First pass: exact match.
				rd[j] = band(bor((rd[j + 1] * 2), 1), charMatch)
			else
				-- Subsequent passes: fuzzy match.
				-- Functions instead of operators make this hella messy.
				rd[j] = bor(
					band(
						bor(
							lshift(rd[j + 1], 1),
							1
						),
						charMatch
					),
					bor(
						bor(
							lshift(bor(last_rd[j + 1], last_rd[j]), 1),
							1
						),
						last_rd[j + 1]
					)
				)
			end
			if (band(rd[j], matchmask) ~= 0) then
				local score = _match_bitapScore(d, j - 1)
				-- This match will almost certainly be better than any existing match.
				-- But check anyway.
				if (score <= score_threshold) then
					-- Told you so.
					score_threshold = score
					best_loc = j - 1
					if (best_loc > loc) then
						-- When passing loc, don't exceed our current distance from loc.
						start = max(1, loc * 2 - best_loc)
					else
						-- Already passed loc, downhill from here on in.
						break
					end
				end
			end
		end
		-- No hope for a (better) match at greater error levels.
		if (_match_bitapScore(d + 1, loc) > score_threshold) then
			break
		end
		last_rd = rd
	end
	return best_loc
end

return match_main

end
preload["bsrocks.lib.files"] = function(...)
local function read(file)
	local handle = fs.open(file, "r")
	local contents = handle.readAll()
	handle.close()
	return contents
end

local function readLines(file)
	local handle = fs.open(file, "r")
	local out, n = {}, 0

	for line in handle.readLine do
		n = n + 1
		out[n] = line
	end

	handle.close()

	-- Trim trailing lines
	while out[n] == "" do
		out[n] = nil
		n = n - 1
	end

	return out
end

local function write(file, contents)
	local handle = fs.open(file, "w")
	handle.write(contents)
	handle.close()
end

local function writeLines(file, contents)
	local handle = fs.open(file, "w")
	for i = 1, #contents do
		handle.writeLine(contents[i])
	end
	handle.close()
end

local function assertExists(file, name, level)
	if not fs.exists(file) then
		error("Cannot find " .. name .. " (Looking for " .. file .. ")", level or 1)
	end
end

local function readDir(directory, reader)
	reader = reader or read
	local offset = #directory + 2
	local stack, n = { directory }, 1

	local files = {}

	while n > 0 do
		local top = stack[n]
		n = n - 1

		if fs.isDir(top) then
			for _, file in ipairs(fs.list(top)) do
				n = n + 1
				stack[n] = fs.combine(top, file)
			end
		else
			files[top:sub(offset)] = reader(top)
		end
	end

	return files
end

local function writeDir(dir, files, writer)
	writer = writer or write
	for file, contents in pairs(files) do
		writer(fs.combine(dir, file), contents)
	end
end

return {
	read = read,
	readLines = readLines,
	readDir = readDir,

	write = write,
	writeLines = writeLines,
	writeDir = writeDir,

	assertExists = assertExists,
}

end
preload["bsrocks.lib.dump"] = function(...)
local keywords = {
	[ "and" ] = true, [ "break" ] = true, [ "do" ] = true, [ "else" ] = true,
	[ "elseif" ] = true, [ "end" ] = true, [ "false" ] = true, [ "for" ] = true,
	[ "function" ] = true, [ "if" ] = true, [ "in" ] = true, [ "local" ] = true,
	[ "nil" ] = true, [ "not" ] = true, [ "or" ] = true, [ "repeat" ] = true, [ "return" ] = true,
	[ "then" ] = true, [ "true" ] = true, [ "until" ] = true, [ "while" ] = true,
}

local function serializeImpl(t, tracking, indent, tupleLength)
	local objType = type(t)
	if objType == "table" and not tracking[t] then
		tracking[t] = true

		if next(t) == nil then
			if tupleLength then
				return "()"
			else
				return "{}"
			end
		else
			local shouldNewLine = false
			local length = tupleLength or #t

			local builder = 0
			for k,v in pairs(t) do
				if type(k) == "table" or type(v) == "table" then
					shouldNewLine = true
					break
				elseif type(k) == "number" and k >= 1 and k <= length and k % 1 == 0 then
					builder = builder + #tostring(v) + 2
				else
					builder = builder + #tostring(v) + #tostring(k) + 2
				end

				if builder > 30 then
					shouldNewLine = true
					break
				end
			end

			local newLine, nextNewLine, subIndent = "", ", ", ""
			if shouldNewLine then
				newLine = "\n"
				nextNewLine = ",\n"
				subIndent = indent .. " "
			end

			local result, n = {(tupleLength and "(" or "{") .. newLine}, 1

			local seen = {}
			local first = true
			for k = 1, length do
				seen[k] = true
				n = n + 1
				local entry = subIndent .. serializeImpl(t[k], tracking, subIndent)

				if not first then
					entry = nextNewLine .. entry
				else
					first = false
				end

				result[n] = entry
			end

			for k,v in pairs(t) do
				if not seen[k] then
					local entry
					if type(k) == "string" and not keywords[k] and string.match( k, "^[%a_][%a%d_]*$" ) then
						entry = k .. " = " .. serializeImpl(v, tracking, subIndent)
					else
						entry = "[" .. serializeImpl(k, tracking, subIndent) .. "] = " .. serializeImpl(v, tracking, subIndent)
					end

					entry = subIndent .. entry

					if not first then
						entry = nextNewLine .. entry
					else
						first = false
					end

					n = n + 1
					result[n] = entry
				end
			end

			n = n + 1
			result[n] = newLine .. indent .. (tupleLength and ")" or "}")
			return table.concat(result)
		end

	elseif objType == "string" then
		return (string.format("%q", t):gsub("\\\n", "\\n"))
	else
		return tostring(t)
	end
end

local function serialize(t, n)
	return serializeImpl(t, {}, "", n)
end

return serialize

end
preload["bsrocks.lib.diffmatchpatch"] = function(...)
--[[
* Diff Match and Patch
*
* Copyright 2006 Google Inc.
* http://code.google.com/p/google-diff-match-patch/
*
* Based on the JavaScript implementation by Neil Fraser.
* Ported to Lua by Duncan Cross.
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*	 http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
--]]

--[[
-- Lua 5.1 and earlier requires the external BitOp library.
-- This library is built-in from Lua 5.2 and later as 'bit32'.
require 'bit'	 -- <http://bitop.luajit.org/>
local band, bor, lshift
		= bit.band, bit.bor, bit.lshift
--]]

local band, bor, lshift = bit32.band, bit32.bor, bit32.lshift
local type, setmetatable, ipairs, select = type, setmetatable, ipairs, select
local unpack, tonumber, error = unpack, tonumber, error
local strsub, strbyte, strchar, gmatch, gsub = string.sub, string.byte, string.char, string.gmatch, string.gsub
local strmatch, strfind, strformat = string.match, string.find, string.format
local tinsert, tremove, tconcat = table.insert, table.remove, table.concat
local max, min, floor, ceil, abs = math.max, math.min, math.floor, math.ceil, math.abs
local clock = os.clock


-- Utility functions.

local percentEncode_pattern = '[^A-Za-z0-9%-=;\',./~!@#$%&*%(%)_%+ %?]'
local function percentEncode_replace(v)
	return strformat('%%%02X', strbyte(v))
end

local function tsplice(t, idx, deletions, ...)
	local insertions = select('#', ...)
	for i = 1, deletions do
		tremove(t, idx)
	end
	for i = insertions, 1, -1 do
		-- do not remove parentheses around select
		tinsert(t, idx, (select(i, ...)))
	end
end

local function strelement(str, i)
	return strsub(str, i, i)
end

local function indexOf(a, b, start)
	if (#b == 0) then
		return nil
	end
	return strfind(a, b, start, true)
end

local htmlEncode_pattern = '[&<>\n]'
local htmlEncode_replace = {
	['&'] = '&amp;', ['<'] = '&lt;', ['>'] = '&gt;', ['\n'] = '&para;<br>'
}

-- Public API Functions
-- (Exported at the end of the script)

local
	diff_main,
	diff_cleanupSemantic,
	diff_cleanupEfficiency,
	diff_levenshtein,
	diff_prettyHtml

local match_main

local
	patch_make,
	patch_toText,
	patch_fromText,
	patch_apply

--[[
* The data structure representing a diff is an array of tuples:
* {{DIFF_DELETE, 'Hello'}, {DIFF_INSERT, 'Goodbye'}, {DIFF_EQUAL, ' world.'}}
* which means: delete 'Hello', add 'Goodbye' and keep ' world.'
--]]
local DIFF_DELETE = -1
local DIFF_INSERT = 1
local DIFF_EQUAL = 0

-- Number of seconds to map a diff before giving up (0 for infinity).
local Diff_Timeout = 1.0
-- Cost of an empty edit operation in terms of edit characters.
local Diff_EditCost = 4
-- At what point is no match declared (0.0 = perfection, 1.0 = very loose).
local Match_Threshold = 0.5
-- How far to search for a match (0 = exact location, 1000+ = broad match).
-- A match this many characters away from the expected location will add
-- 1.0 to the score (0.0 is a perfect match).
local Match_Distance = 1000
-- When deleting a large block of text (over ~64 characters), how close do
-- the contents have to be to match the expected contents. (0.0 = perfection,
-- 1.0 = very loose).	Note that Match_Threshold controls how closely the
-- end points of a delete need to match.
local Patch_DeleteThreshold = 0.5
-- Chunk size for context length.
local Patch_Margin = 4
-- The number of bits in an int.
local Match_MaxBits = 32

local function settings(new)
	if new then
		Diff_Timeout = new.Diff_Timeout or Diff_Timeout
		Diff_EditCost = new.Diff_EditCost or Diff_EditCost
		Match_Threshold = new.Match_Threshold or Match_Threshold
		Match_Distance = new.Match_Distance or Match_Distance
		Patch_DeleteThreshold = new.Patch_DeleteThreshold or Patch_DeleteThreshold
		Patch_Margin = new.Patch_Margin or Patch_Margin
		Match_MaxBits = new.Match_MaxBits or Match_MaxBits
	else
		return {
			Diff_Timeout = Diff_Timeout;
			Diff_EditCost = Diff_EditCost;
			Match_Threshold = Match_Threshold;
			Match_Distance = Match_Distance;
			Patch_DeleteThreshold = Patch_DeleteThreshold;
			Patch_Margin = Patch_Margin;
			Match_MaxBits = Match_MaxBits;
		}
	end
end

-- ---------------------------------------------------------------------------
--	DIFF API
-- ---------------------------------------------------------------------------

-- The private diff functions
local
	_diff_compute,
	_diff_bisect,
	_diff_bisectSplit,
	_diff_halfMatchI,
	_diff_halfMatch,
	_diff_cleanupSemanticScore,
	_diff_cleanupSemanticLossless,
	_diff_cleanupMerge,
	_diff_commonPrefix,
	_diff_commonSuffix,
	_diff_commonOverlap,
	_diff_xIndex,
	_diff_text1,
	_diff_text2,
	_diff_toDelta,
	_diff_fromDelta

--[[
* Find the differences between two texts.	Simplifies the problem by stripping
* any common prefix or suffix off the texts before diffing.
* @param {string} text1 Old string to be diffed.
* @param {string} text2 New string to be diffed.
* @param {boolean} opt_checklines Has no effect in Lua.
* @param {number} opt_deadline Optional time when the diff should be complete
*		 by.	Used internally for recursive calls.	Users should set DiffTimeout
*		 instead.
* @return {Array.<Array.<number|string>>} Array of diff tuples.
--]]
function diff_main(text1, text2, opt_checklines, opt_deadline)
	-- Set a deadline by which time the diff must be complete.
	if opt_deadline == nil then
		if Diff_Timeout <= 0 then
			opt_deadline = 2 ^ 31
		else
			opt_deadline = clock() + Diff_Timeout
		end
	end
	local deadline = opt_deadline

	-- Check for null inputs.
	if text1 == nil or text1 == nil then
		error('Null inputs. (diff_main)')
	end

	-- Check for equality (speedup).
	if text1 == text2 then
		if #text1 > 0 then
			return {{DIFF_EQUAL, text1}}
		end
		return {}
	end

	-- LUANOTE: Due to the lack of Unicode support, Lua is incapable of
	-- implementing the line-mode speedup.
	local checklines = false

	-- Trim off common prefix (speedup).
	local commonlength = _diff_commonPrefix(text1, text2)
	local commonprefix
	if commonlength > 0 then
		commonprefix = strsub(text1, 1, commonlength)
		text1 = strsub(text1, commonlength + 1)
		text2 = strsub(text2, commonlength + 1)
	end

	-- Trim off common suffix (speedup).
	commonlength = _diff_commonSuffix(text1, text2)
	local commonsuffix
	if commonlength > 0 then
		commonsuffix = strsub(text1, -commonlength)
		text1 = strsub(text1, 1, -commonlength - 1)
		text2 = strsub(text2, 1, -commonlength - 1)
	end

	-- Compute the diff on the middle block.
	local diffs = _diff_compute(text1, text2, checklines, deadline)

	-- Restore the prefix and suffix.
	if commonprefix then
		tinsert(diffs, 1, {DIFF_EQUAL, commonprefix})
	end
	if commonsuffix then
		diffs[#diffs + 1] = {DIFF_EQUAL, commonsuffix}
	end

	_diff_cleanupMerge(diffs)
	return diffs
end

--[[
* Reduce the number of edits by eliminating semantically trivial equalities.
* @param {Array.<Array.<number|string>>} diffs Array of diff tuples.
--]]
function diff_cleanupSemantic(diffs)
	local changes = false
	local equalities = {}	-- Stack of indices where equalities are found.
	local equalitiesLength = 0	-- Keeping our own length var is faster.
	local lastequality = nil
	-- Always equal to diffs[equalities[equalitiesLength]][2]
	local pointer = 1	-- Index of current position.
	-- Number of characters that changed prior to the equality.
	local length_insertions1 = 0
	local length_deletions1 = 0
	-- Number of characters that changed after the equality.
	local length_insertions2 = 0
	local length_deletions2 = 0

	while diffs[pointer] do
		if diffs[pointer][1] == DIFF_EQUAL then	-- Equality found.
			equalitiesLength = equalitiesLength + 1
			equalities[equalitiesLength] = pointer
			length_insertions1 = length_insertions2
			length_deletions1 = length_deletions2
			length_insertions2 = 0
			length_deletions2 = 0
			lastequality = diffs[pointer][2]
		else	-- An insertion or deletion.
			if diffs[pointer][1] == DIFF_INSERT then
				length_insertions2 = length_insertions2 + #(diffs[pointer][2])
			else
				length_deletions2 = length_deletions2 + #(diffs[pointer][2])
			end
			-- Eliminate an equality that is smaller or equal to the edits on both
			-- sides of it.
			if lastequality
					and (#lastequality <= max(length_insertions1, length_deletions1))
					and (#lastequality <= max(length_insertions2, length_deletions2)) then
				-- Duplicate record.
				tinsert(diffs, equalities[equalitiesLength],
				 {DIFF_DELETE, lastequality})
				-- Change second copy to insert.
				diffs[equalities[equalitiesLength] + 1][1] = DIFF_INSERT
				-- Throw away the equality we just deleted.
				equalitiesLength = equalitiesLength - 1
				-- Throw away the previous equality (it needs to be reevaluated).
				equalitiesLength = equalitiesLength - 1
				pointer = (equalitiesLength > 0) and equalities[equalitiesLength] or 0
				length_insertions1, length_deletions1 = 0, 0	-- Reset the counters.
				length_insertions2, length_deletions2 = 0, 0
				lastequality = nil
				changes = true
			end
		end
		pointer = pointer + 1
	end

	-- Normalize the diff.
	if changes then
		_diff_cleanupMerge(diffs)
	end
	_diff_cleanupSemanticLossless(diffs)

	-- Find any overlaps between deletions and insertions.
	-- e.g: <del>abcxxx</del><ins>xxxdef</ins>
	--	 -> <del>abc</del>xxx<ins>def</ins>
	-- e.g: <del>xxxabc</del><ins>defxxx</ins>
	--	 -> <ins>def</ins>xxx<del>abc</del>
	-- Only extract an overlap if it is as big as the edit ahead or behind it.
	pointer = 2
	while diffs[pointer] do
		if (diffs[pointer - 1][1] == DIFF_DELETE and
				diffs[pointer][1] == DIFF_INSERT) then
			local deletion = diffs[pointer - 1][2]
			local insertion = diffs[pointer][2]
			local overlap_length1 = _diff_commonOverlap(deletion, insertion)
			local overlap_length2 = _diff_commonOverlap(insertion, deletion)
			if (overlap_length1 >= overlap_length2) then
				if (overlap_length1 >= #deletion / 2 or
						overlap_length1 >= #insertion / 2) then
					-- Overlap found.	Insert an equality and trim the surrounding edits.
					tinsert(diffs, pointer,
							{DIFF_EQUAL, strsub(insertion, 1, overlap_length1)})
					diffs[pointer - 1][2] =
							strsub(deletion, 1, #deletion - overlap_length1)
					diffs[pointer + 1][2] = strsub(insertion, overlap_length1 + 1)
					pointer = pointer + 1
				end
			else
				if (overlap_length2 >= #deletion / 2 or
						overlap_length2 >= #insertion / 2) then
					-- Reverse overlap found.
					-- Insert an equality and swap and trim the surrounding edits.
					tinsert(diffs, pointer,
							{DIFF_EQUAL, strsub(deletion, 1, overlap_length2)})
					diffs[pointer - 1] = {DIFF_INSERT,
							strsub(insertion, 1, #insertion - overlap_length2)}
					diffs[pointer + 1] = {DIFF_DELETE,
							strsub(deletion, overlap_length2 + 1)}
					pointer = pointer + 1
				end
			end
			pointer = pointer + 1
		end
		pointer = pointer + 1
	end
end

--[[
* Reduce the number of edits by eliminating operationally trivial equalities.
* @param {Array.<Array.<number|string>>} diffs Array of diff tuples.
--]]
function diff_cleanupEfficiency(diffs)
	local changes = false
	-- Stack of indices where equalities are found.
	local equalities = {}
	-- Keeping our own length var is faster.
	local equalitiesLength = 0
	-- Always equal to diffs[equalities[equalitiesLength]][2]
	local lastequality = nil
	-- Index of current position.
	local pointer = 1

	-- The following four are really booleans but are stored as numbers because
	-- they are used at one point like this:
	--
	-- (pre_ins + pre_del + post_ins + post_del) == 3
	--
	-- ...i.e. checking that 3 of them are true and 1 of them is false.

	-- Is there an insertion operation before the last equality.
	local pre_ins = 0
	-- Is there a deletion operation before the last equality.
	local pre_del = 0
	-- Is there an insertion operation after the last equality.
	local post_ins = 0
	-- Is there a deletion operation after the last equality.
	local post_del = 0

	while diffs[pointer] do
		if diffs[pointer][1] == DIFF_EQUAL then	-- Equality found.
			local diffText = diffs[pointer][2]
			if (#diffText < Diff_EditCost) and (post_ins == 1 or post_del == 1) then
				-- Candidate found.
				equalitiesLength = equalitiesLength + 1
				equalities[equalitiesLength] = pointer
				pre_ins, pre_del = post_ins, post_del
				lastequality = diffText
			else
				-- Not a candidate, and can never become one.
				equalitiesLength = 0
				lastequality = nil
			end
			post_ins, post_del = 0, 0
		else	-- An insertion or deletion.
			if diffs[pointer][1] == DIFF_DELETE then
				post_del = 1
			else
				post_ins = 1
			end
			--[[
			* Five types to be split:
			* <ins>A</ins><del>B</del>XY<ins>C</ins><del>D</del>
			* <ins>A</ins>X<ins>C</ins><del>D</del>
			* <ins>A</ins><del>B</del>X<ins>C</ins>
			* <ins>A</del>X<ins>C</ins><del>D</del>
			* <ins>A</ins><del>B</del>X<del>C</del>
			--]]
			if lastequality and (
					(pre_ins+pre_del+post_ins+post_del == 4)
					or
					(
						(#lastequality < Diff_EditCost / 2)
						and
						(pre_ins+pre_del+post_ins+post_del == 3)
					)) then
				-- Duplicate record.
				tinsert(diffs, equalities[equalitiesLength],
						{DIFF_DELETE, lastequality})
				-- Change second copy to insert.
				diffs[equalities[equalitiesLength] + 1][1] = DIFF_INSERT
				-- Throw away the equality we just deleted.
				equalitiesLength = equalitiesLength - 1
				lastequality = nil
				if (pre_ins == 1) and (pre_del == 1) then
					-- No changes made which could affect previous entry, keep going.
					post_ins, post_del = 1, 1
					equalitiesLength = 0
				else
					-- Throw away the previous equality.
					equalitiesLength = equalitiesLength - 1
					pointer = (equalitiesLength > 0) and equalities[equalitiesLength] or 0
					post_ins, post_del = 0, 0
				end
				changes = true
			end
		end
		pointer = pointer + 1
	end

	if changes then
		_diff_cleanupMerge(diffs)
	end
end

--[[
* Compute the Levenshtein distance; the number of inserted, deleted or
* substituted characters.
* @param {Array.<Array.<number|string>>} diffs Array of diff tuples.
* @return {number} Number of changes.
--]]
function diff_levenshtein(diffs)
	local levenshtein = 0
	local insertions, deletions = 0, 0
	for x, diff in ipairs(diffs) do
		local op, data = diff[1], diff[2]
		if (op == DIFF_INSERT) then
			insertions = insertions + #data
		elseif (op == DIFF_DELETE) then
			deletions = deletions + #data
		elseif (op == DIFF_EQUAL) then
			-- A deletion and an insertion is one substitution.
			levenshtein = levenshtein + max(insertions, deletions)
			insertions = 0
			deletions = 0
		end
	end
	levenshtein = levenshtein + max(insertions, deletions)
	return levenshtein
end

--[[
* Convert a diff array into a pretty HTML report.
* @param {Array.<Array.<number|string>>} diffs Array of diff tuples.
* @return {string} HTML representation.
--]]
function diff_prettyHtml(diffs)
	local html = {}
	for x, diff in ipairs(diffs) do
		local op = diff[1]	 -- Operation (insert, delete, equal)
		local data = diff[2]	-- Text of change.
		local text = gsub(data, htmlEncode_pattern, htmlEncode_replace)
		if op == DIFF_INSERT then
			html[x] = '<ins style="background:#e6ffe6;">' .. text .. '</ins>'
		elseif op == DIFF_DELETE then
			html[x] = '<del style="background:#ffe6e6;">' .. text .. '</del>'
		elseif op == DIFF_EQUAL then
			html[x] = '<span>' .. text .. '</span>'
		end
	end
	return tconcat(html)
end

-- ---------------------------------------------------------------------------
-- UNOFFICIAL/PRIVATE DIFF FUNCTIONS
-- ---------------------------------------------------------------------------

--[[
* Find the differences between two texts.	Assumes that the texts do not
* have any common prefix or suffix.
* @param {string} text1 Old string to be diffed.
* @param {string} text2 New string to be diffed.
* @param {boolean} checklines Has no effect in Lua.
* @param {number} deadline Time when the diff should be complete by.
* @return {Array.<Array.<number|string>>} Array of diff tuples.
* @private
--]]
function _diff_compute(text1, text2, checklines, deadline)
	if #text1 == 0 then
		-- Just add some text (speedup).
		return {{DIFF_INSERT, text2}}
	end

	if #text2 == 0 then
		-- Just delete some text (speedup).
		return {{DIFF_DELETE, text1}}
	end

	local diffs

	local longtext = (#text1 > #text2) and text1 or text2
	local shorttext = (#text1 > #text2) and text2 or text1
	local i = indexOf(longtext, shorttext)

	if i ~= nil then
		-- Shorter text is inside the longer text (speedup).
		diffs = {
			{DIFF_INSERT, strsub(longtext, 1, i - 1)},
			{DIFF_EQUAL, shorttext},
			{DIFF_INSERT, strsub(longtext, i + #shorttext)}
		}
		-- Swap insertions for deletions if diff is reversed.
		if #text1 > #text2 then
			diffs[1][1], diffs[3][1] = DIFF_DELETE, DIFF_DELETE
		end
		return diffs
	end

	if #shorttext == 1 then
		-- Single character string.
		-- After the previous speedup, the character can't be an equality.
		return {{DIFF_DELETE, text1}, {DIFF_INSERT, text2}}
	end

	-- Check to see if the problem can be split in two.
	do
		local
		 text1_a, text1_b,
		 text2_a, text2_b,
		 mid_common				= _diff_halfMatch(text1, text2)

		if text1_a then
			-- A half-match was found, sort out the return data.
			-- Send both pairs off for separate processing.
			local diffs_a = diff_main(text1_a, text2_a, checklines, deadline)
			local diffs_b = diff_main(text1_b, text2_b, checklines, deadline)
			-- Merge the results.
			local diffs_a_len = #diffs_a
			diffs = diffs_a
			diffs[diffs_a_len + 1] = {DIFF_EQUAL, mid_common}
			for i, b_diff in ipairs(diffs_b) do
				diffs[diffs_a_len + 1 + i] = b_diff
			end
			return diffs
		end
	end

	return _diff_bisect(text1, text2, deadline)
end

--[[
* Find the 'middle snake' of a diff, split the problem in two
* and return the recursively constructed diff.
* See Myers 1986 paper: An O(ND) Difference Algorithm and Its Variations.
* @param {string} text1 Old string to be diffed.
* @param {string} text2 New string to be diffed.
* @param {number} deadline Time at which to bail if not yet complete.
* @return {Array.<Array.<number|string>>} Array of diff tuples.
* @private
--]]
function _diff_bisect(text1, text2, deadline)
	-- Cache the text lengths to prevent multiple calls.
	local text1_length = #text1
	local text2_length = #text2
	local _sub, _element
	local max_d = ceil((text1_length + text2_length) / 2)
	local v_offset = max_d
	local v_length = 2 * max_d
	local v1 = {}
	local v2 = {}
	-- Setting all elements to -1 is faster in Lua than mixing integers and nil.
	for x = 0, v_length - 1 do
		v1[x] = -1
		v2[x] = -1
	end
	v1[v_offset + 1] = 0
	v2[v_offset + 1] = 0
	local delta = text1_length - text2_length
	-- If the total number of characters is odd, then
	-- the front path will collide with the reverse path.
	local front = (delta % 2 ~= 0)
	-- Offsets for start and end of k loop.
	-- Prevents mapping of space beyond the grid.
	local k1start = 0
	local k1end = 0
	local k2start = 0
	local k2end = 0
	for d = 0, max_d - 1 do
		-- Bail out if deadline is reached.
		if clock() > deadline then
			break
		end

		-- Walk the front path one step.
		for k1 = -d + k1start, d - k1end, 2 do
			local k1_offset = v_offset + k1
			local x1
			if (k1 == -d) or ((k1 ~= d) and
					(v1[k1_offset - 1] < v1[k1_offset + 1])) then
				x1 = v1[k1_offset + 1]
			else
				x1 = v1[k1_offset - 1] + 1
			end
			local y1 = x1 - k1
			while (x1 <= text1_length) and (y1 <= text2_length)
					and (strelement(text1, x1) == strelement(text2, y1)) do
				x1 = x1 + 1
				y1 = y1 + 1
			end
			v1[k1_offset] = x1
			if x1 > text1_length + 1 then
				-- Ran off the right of the graph.
				k1end = k1end + 2
			elseif y1 > text2_length + 1 then
				-- Ran off the bottom of the graph.
				k1start = k1start + 2
			elseif front then
				local k2_offset = v_offset + delta - k1
				if k2_offset >= 0 and k2_offset < v_length and v2[k2_offset] ~= -1 then
					-- Mirror x2 onto top-left coordinate system.
					local x2 = text1_length - v2[k2_offset] + 1
					if x1 > x2 then
						-- Overlap detected.
						return _diff_bisectSplit(text1, text2, x1, y1, deadline)
					end
				end
			end
		end

		-- Walk the reverse path one step.
		for k2 = -d + k2start, d - k2end, 2 do
			local k2_offset = v_offset + k2
			local x2
			if (k2 == -d) or ((k2 ~= d) and
					(v2[k2_offset - 1] < v2[k2_offset + 1])) then
				x2 = v2[k2_offset + 1]
			else
				x2 = v2[k2_offset - 1] + 1
			end
			local y2 = x2 - k2
			while (x2 <= text1_length) and (y2 <= text2_length)
					and (strelement(text1, -x2) == strelement(text2, -y2)) do
				x2 = x2 + 1
				y2 = y2 + 1
			end
			v2[k2_offset] = x2
			if x2 > text1_length + 1 then
				-- Ran off the left of the graph.
				k2end = k2end + 2
			elseif y2 > text2_length + 1 then
				-- Ran off the top of the graph.
				k2start = k2start + 2
			elseif not front then
				local k1_offset = v_offset + delta - k2
				if k1_offset >= 0 and k1_offset < v_length and v1[k1_offset] ~= -1 then
					local x1 = v1[k1_offset]
					local y1 = v_offset + x1 - k1_offset
					-- Mirror x2 onto top-left coordinate system.
					x2 = text1_length - x2 + 1
					if x1 > x2 then
						-- Overlap detected.
						return _diff_bisectSplit(text1, text2, x1, y1, deadline)
					end
				end
			end
		end
	end
	-- Diff took too long and hit the deadline or
	-- number of diffs equals number of characters, no commonality at all.
	return {{DIFF_DELETE, text1}, {DIFF_INSERT, text2}}
end

--[[
 * Given the location of the 'middle snake', split the diff in two parts
 * and recurse.
 * @param {string} text1 Old string to be diffed.
 * @param {string} text2 New string to be diffed.
 * @param {number} x Index of split point in text1.
 * @param {number} y Index of split point in text2.
 * @param {number} deadline Time at which to bail if not yet complete.
 * @return {Array.<Array.<number|string>>} Array of diff tuples.
 * @private
--]]
function _diff_bisectSplit(text1, text2, x, y, deadline)
	local text1a = strsub(text1, 1, x - 1)
	local text2a = strsub(text2, 1, y - 1)
	local text1b = strsub(text1, x)
	local text2b = strsub(text2, y)

	-- Compute both diffs serially.
	local diffs = diff_main(text1a, text2a, false, deadline)
	local diffsb = diff_main(text1b, text2b, false, deadline)

	local diffs_len = #diffs
	for i, v in ipairs(diffsb) do
		diffs[diffs_len + i] = v
	end
	return diffs
end

--[[
* Determine the common prefix of two strings.
* @param {string} text1 First string.
* @param {string} text2 Second string.
* @return {number} The number of characters common to the start of each
*		string.
--]]
function _diff_commonPrefix(text1, text2)
	-- Quick check for common null cases.
	if (#text1 == 0) or (#text2 == 0) or (strbyte(text1, 1) ~= strbyte(text2, 1))
			then
		return 0
	end
	-- Binary search.
	-- Performance analysis: http://neil.fraser.name/news/2007/10/09/
	local pointermin = 1
	local pointermax = min(#text1, #text2)
	local pointermid = pointermax
	local pointerstart = 1
	while (pointermin < pointermid) do
		if (strsub(text1, pointerstart, pointermid)
				== strsub(text2, pointerstart, pointermid)) then
			pointermin = pointermid
			pointerstart = pointermin
		else
			pointermax = pointermid
		end
		pointermid = floor(pointermin + (pointermax - pointermin) / 2)
	end
	return pointermid
end

--[[
* Determine the common suffix of two strings.
* @param {string} text1 First string.
* @param {string} text2 Second string.
* @return {number} The number of characters common to the end of each string.
--]]
function _diff_commonSuffix(text1, text2)
	-- Quick check for common null cases.
	if (#text1 == 0) or (#text2 == 0)
			or (strbyte(text1, -1) ~= strbyte(text2, -1)) then
		return 0
	end
	-- Binary search.
	-- Performance analysis: http://neil.fraser.name/news/2007/10/09/
	local pointermin = 1
	local pointermax = min(#text1, #text2)
	local pointermid = pointermax
	local pointerend = 1
	while (pointermin < pointermid) do
		if (strsub(text1, -pointermid, -pointerend)
				== strsub(text2, -pointermid, -pointerend)) then
			pointermin = pointermid
			pointerend = pointermin
		else
			pointermax = pointermid
		end
		pointermid = floor(pointermin + (pointermax - pointermin) / 2)
	end
	return pointermid
end

--[[
* Determine if the suffix of one string is the prefix of another.
* @param {string} text1 First string.
* @param {string} text2 Second string.
* @return {number} The number of characters common to the end of the first
*		 string and the start of the second string.
* @private
--]]
function _diff_commonOverlap(text1, text2)
	-- Cache the text lengths to prevent multiple calls.
	local text1_length = #text1
	local text2_length = #text2
	-- Eliminate the null case.
	if text1_length == 0 or text2_length == 0 then
		return 0
	end
	-- Truncate the longer string.
	if text1_length > text2_length then
		text1 = strsub(text1, text1_length - text2_length + 1)
	elseif text1_length < text2_length then
		text2 = strsub(text2, 1, text1_length)
	end
	local text_length = min(text1_length, text2_length)
	-- Quick check for the worst case.
	if text1 == text2 then
		return text_length
	end

	-- Start by looking for a single character match
	-- and increase length until no match is found.
	-- Performance analysis: http://neil.fraser.name/news/2010/11/04/
	local best = 0
	local length = 1
	while true do
		local pattern = strsub(text1, text_length - length + 1)
		local found = strfind(text2, pattern, 1, true)
		if found == nil then
			return best
		end
		length = length + found - 1
		if found == 1 or strsub(text1, text_length - length + 1) ==
										 strsub(text2, 1, length) then
			best = length
			length = length + 1
		end
	end
end

--[[
* Does a substring of shorttext exist within longtext such that the substring
* is at least half the length of longtext?
* This speedup can produce non-minimal diffs.
* Closure, but does not reference any external variables.
* @param {string} longtext Longer string.
* @param {string} shorttext Shorter string.
* @param {number} i Start index of quarter length substring within longtext.
* @return {?Array.<string>} Five element Array, containing the prefix of
*		longtext, the suffix of longtext, the prefix of shorttext, the suffix
*		of shorttext and the common middle.	Or nil if there was no match.
* @private
--]]
function _diff_halfMatchI(longtext, shorttext, i)
	-- Start with a 1/4 length substring at position i as a seed.
	local seed = strsub(longtext, i, i + floor(#longtext / 4))
	local j = 0	-- LUANOTE: do not change to 1, was originally -1
	local best_common = ''
	local best_longtext_a, best_longtext_b, best_shorttext_a, best_shorttext_b
	while true do
		j = indexOf(shorttext, seed, j + 1)
		if (j == nil) then
			break
		end
		local prefixLength = _diff_commonPrefix(strsub(longtext, i),
				strsub(shorttext, j))
		local suffixLength = _diff_commonSuffix(strsub(longtext, 1, i - 1),
				strsub(shorttext, 1, j - 1))
		if #best_common < suffixLength + prefixLength then
			best_common = strsub(shorttext, j - suffixLength, j - 1)
					.. strsub(shorttext, j, j + prefixLength - 1)
			best_longtext_a = strsub(longtext, 1, i - suffixLength - 1)
			best_longtext_b = strsub(longtext, i + prefixLength)
			best_shorttext_a = strsub(shorttext, 1, j - suffixLength - 1)
			best_shorttext_b = strsub(shorttext, j + prefixLength)
		end
	end
	if #best_common * 2 >= #longtext then
		return {best_longtext_a, best_longtext_b,
						best_shorttext_a, best_shorttext_b, best_common}
	else
		return nil
	end
end

--[[
* Do the two texts share a substring which is at least half the length of the
* longer text?
* @param {string} text1 First string.
* @param {string} text2 Second string.
* @return {?Array.<string>} Five element Array, containing the prefix of
*		text1, the suffix of text1, the prefix of text2, the suffix of
*		text2 and the common middle.	Or nil if there was no match.
* @private
--]]
function _diff_halfMatch(text1, text2)
	if Diff_Timeout <= 0 then
		-- Don't risk returning a non-optimal diff if we have unlimited time.
		return nil
	end
	local longtext = (#text1 > #text2) and text1 or text2
	local shorttext = (#text1 > #text2) and text2 or text1
	if (#longtext < 4) or (#shorttext * 2 < #longtext) then
		return nil	-- Pointless.
	end

	-- First check if the second quarter is the seed for a half-match.
	local hm1 = _diff_halfMatchI(longtext, shorttext, ceil(#longtext / 4))
	-- Check again based on the third quarter.
	local hm2 = _diff_halfMatchI(longtext, shorttext, ceil(#longtext / 2))
	local hm
	if not hm1 and not hm2 then
		return nil
	elseif not hm2 then
		hm = hm1
	elseif not hm1 then
		hm = hm2
	else
		-- Both matched.	Select the longest.
		hm = (#hm1[5] > #hm2[5]) and hm1 or hm2
	end

	-- A half-match was found, sort out the return data.
	local text1_a, text1_b, text2_a, text2_b
	if (#text1 > #text2) then
		text1_a, text1_b = hm[1], hm[2]
		text2_a, text2_b = hm[3], hm[4]
	else
		text2_a, text2_b = hm[1], hm[2]
		text1_a, text1_b = hm[3], hm[4]
	end
	local mid_common = hm[5]
	return text1_a, text1_b, text2_a, text2_b, mid_common
end

--[[
* Given two strings, compute a score representing whether the internal
* boundary falls on logical boundaries.
* Scores range from 6 (best) to 0 (worst).
* @param {string} one First string.
* @param {string} two Second string.
* @return {number} The score.
* @private
--]]
function _diff_cleanupSemanticScore(one, two)
	if (#one == 0) or (#two == 0) then
		-- Edges are the best.
		return 6
	end

	-- Each port of this function behaves slightly differently due to
	-- subtle differences in each language's definition of things like
	-- 'whitespace'.	Since this function's purpose is largely cosmetic,
	-- the choice has been made to use each language's native features
	-- rather than force total conformity.
	local char1 = strsub(one, -1)
	local char2 = strsub(two, 1, 1)
	local nonAlphaNumeric1 = strmatch(char1, '%W')
	local nonAlphaNumeric2 = strmatch(char2, '%W')
	local whitespace1 = nonAlphaNumeric1 and strmatch(char1, '%s')
	local whitespace2 = nonAlphaNumeric2 and strmatch(char2, '%s')
	local lineBreak1 = whitespace1 and strmatch(char1, '%c')
	local lineBreak2 = whitespace2 and strmatch(char2, '%c')
	local blankLine1 = lineBreak1 and strmatch(one, '\n\r?\n$')
	local blankLine2 = lineBreak2 and strmatch(two, '^\r?\n\r?\n')

	if blankLine1 or blankLine2 then
		-- Five points for blank lines.
		return 5
	elseif lineBreak1 or lineBreak2 then
		-- Four points for line breaks.
		return 4
	elseif nonAlphaNumeric1 and not whitespace1 and whitespace2 then
		-- Three points for end of sentences.
		return 3
	elseif whitespace1 or whitespace2 then
		-- Two points for whitespace.
		return 2
	elseif nonAlphaNumeric1 or nonAlphaNumeric2 then
		-- One point for non-alphanumeric.
		return 1
	end
	return 0
end

--[[
* Look for single edits surrounded on both sides by equalities
* which can be shifted sideways to align the edit to a word boundary.
* e.g: The c<ins>at c</ins>ame. -> The <ins>cat </ins>came.
* @param {Array.<Array.<number|string>>} diffs Array of diff tuples.
--]]
function _diff_cleanupSemanticLossless(diffs)
	local pointer = 2
	-- Intentionally ignore the first and last element (don't need checking).
	while diffs[pointer + 1] do
		local prevDiff, nextDiff = diffs[pointer - 1], diffs[pointer + 1]
		if (prevDiff[1] == DIFF_EQUAL) and (nextDiff[1] == DIFF_EQUAL) then
			-- This is a single edit surrounded by equalities.
			local diff = diffs[pointer]

			local equality1 = prevDiff[2]
			local edit = diff[2]
			local equality2 = nextDiff[2]

			-- First, shift the edit as far left as possible.
			local commonOffset = _diff_commonSuffix(equality1, edit)
			if commonOffset > 0 then
				local commonString = strsub(edit, -commonOffset)
				equality1 = strsub(equality1, 1, -commonOffset - 1)
				edit = commonString .. strsub(edit, 1, -commonOffset - 1)
				equality2 = commonString .. equality2
			end

			-- Second, step character by character right, looking for the best fit.
			local bestEquality1 = equality1
			local bestEdit = edit
			local bestEquality2 = equality2
			local bestScore = _diff_cleanupSemanticScore(equality1, edit)
					+ _diff_cleanupSemanticScore(edit, equality2)

			while strbyte(edit, 1) == strbyte(equality2, 1) do
				equality1 = equality1 .. strsub(edit, 1, 1)
				edit = strsub(edit, 2) .. strsub(equality2, 1, 1)
				equality2 = strsub(equality2, 2)
				local score = _diff_cleanupSemanticScore(equality1, edit)
						+ _diff_cleanupSemanticScore(edit, equality2)
				-- The >= encourages trailing rather than leading whitespace on edits.
				if score >= bestScore then
					bestScore = score
					bestEquality1 = equality1
					bestEdit = edit
					bestEquality2 = equality2
				end
			end
			if prevDiff[2] ~= bestEquality1 then
				-- We have an improvement, save it back to the diff.
				if #bestEquality1 > 0 then
					diffs[pointer - 1][2] = bestEquality1
				else
					tremove(diffs, pointer - 1)
					pointer = pointer - 1
				end
				diffs[pointer][2] = bestEdit
				if #bestEquality2 > 0 then
					diffs[pointer + 1][2] = bestEquality2
				else
					tremove(diffs, pointer + 1, 1)
					pointer = pointer - 1
				end
			end
		end
		pointer = pointer + 1
	end
end

--[[
* Reorder and merge like edit sections.	Merge equalities.
* Any edit section can move as long as it doesn't cross an equality.
* @param {Array.<Array.<number|string>>} diffs Array of diff tuples.
--]]
function _diff_cleanupMerge(diffs)
	diffs[#diffs + 1] = {DIFF_EQUAL, ''}	-- Add a dummy entry at the end.
	local pointer = 1
	local count_delete, count_insert = 0, 0
	local text_delete, text_insert = '', ''
	local commonlength
	while diffs[pointer] do
		local diff_type = diffs[pointer][1]
		if diff_type == DIFF_INSERT then
			count_insert = count_insert + 1
			text_insert = text_insert .. diffs[pointer][2]
			pointer = pointer + 1
		elseif diff_type == DIFF_DELETE then
			count_delete = count_delete + 1
			text_delete = text_delete .. diffs[pointer][2]
			pointer = pointer + 1
		elseif diff_type == DIFF_EQUAL then
			-- Upon reaching an equality, check for prior redundancies.
			if count_delete + count_insert > 1 then
				if (count_delete > 0) and (count_insert > 0) then
					-- Factor out any common prefixies.
					commonlength = _diff_commonPrefix(text_insert, text_delete)
					if commonlength > 0 then
						local back_pointer = pointer - count_delete - count_insert
						if (back_pointer > 1) and (diffs[back_pointer - 1][1] == DIFF_EQUAL)
								then
							diffs[back_pointer - 1][2] = diffs[back_pointer - 1][2]
									.. strsub(text_insert, 1, commonlength)
						else
							tinsert(diffs, 1,
									{DIFF_EQUAL, strsub(text_insert, 1, commonlength)})
							pointer = pointer + 1
						end
						text_insert = strsub(text_insert, commonlength + 1)
						text_delete = strsub(text_delete, commonlength + 1)
					end
					-- Factor out any common suffixies.
					commonlength = _diff_commonSuffix(text_insert, text_delete)
					if commonlength ~= 0 then
						diffs[pointer][2] =
						strsub(text_insert, -commonlength) .. diffs[pointer][2]
						text_insert = strsub(text_insert, 1, -commonlength - 1)
						text_delete = strsub(text_delete, 1, -commonlength - 1)
					end
				end
				-- Delete the offending records and add the merged ones.
				if count_delete == 0 then
					tsplice(diffs, pointer - count_insert,
					count_insert, {DIFF_INSERT, text_insert})
				elseif count_insert == 0 then
					tsplice(diffs, pointer - count_delete,
					count_delete, {DIFF_DELETE, text_delete})
				else
					tsplice(diffs, pointer - count_delete - count_insert,
					count_delete + count_insert,
					{DIFF_DELETE, text_delete}, {DIFF_INSERT, text_insert})
				end
				pointer = pointer - count_delete - count_insert
						+ (count_delete>0 and 1 or 0) + (count_insert>0 and 1 or 0) + 1
			elseif (pointer > 1) and (diffs[pointer - 1][1] == DIFF_EQUAL) then
				-- Merge this equality with the previous one.
				diffs[pointer - 1][2] = diffs[pointer - 1][2] .. diffs[pointer][2]
				tremove(diffs, pointer)
			else
				pointer = pointer + 1
			end
			count_insert, count_delete = 0, 0
			text_delete, text_insert = '', ''
		end
	end
	if diffs[#diffs][2] == '' then
		diffs[#diffs] = nil	-- Remove the dummy entry at the end.
	end

	-- Second pass: look for single edits surrounded on both sides by equalities
	-- which can be shifted sideways to eliminate an equality.
	-- e.g: A<ins>BA</ins>C -> <ins>AB</ins>AC
	local changes = false
	pointer = 2
	-- Intentionally ignore the first and last element (don't need checking).
	while pointer < #diffs do
		local prevDiff, nextDiff = diffs[pointer - 1], diffs[pointer + 1]
		if (prevDiff[1] == DIFF_EQUAL) and (nextDiff[1] == DIFF_EQUAL) then
			-- This is a single edit surrounded by equalities.
			local diff = diffs[pointer]
			local currentText = diff[2]
			local prevText = prevDiff[2]
			local nextText = nextDiff[2]
			if strsub(currentText, -#prevText) == prevText then
				-- Shift the edit over the previous equality.
				diff[2] = prevText .. strsub(currentText, 1, -#prevText - 1)
				nextDiff[2] = prevText .. nextDiff[2]
				tremove(diffs, pointer - 1)
				changes = true
			elseif strsub(currentText, 1, #nextText) == nextText then
				-- Shift the edit over the next equality.
				prevDiff[2] = prevText .. nextText
				diff[2] = strsub(currentText, #nextText + 1) .. nextText
				tremove(diffs, pointer + 1)
				changes = true
			end
		end
		pointer = pointer + 1
	end
	-- If shifts were made, the diff needs reordering and another shift sweep.
	if changes then
		-- LUANOTE: no return value, but necessary to use 'return' to get
		-- tail calls.
		return _diff_cleanupMerge(diffs)
	end
end

--[[
* loc is a location in text1, compute and return the equivalent location in
* text2.
* e.g. 'The cat' vs 'The big cat', 1->1, 5->8
* @param {Array.<Array.<number|string>>} diffs Array of diff tuples.
* @param {number} loc Location within text1.
* @return {number} Location within text2.
--]]
function _diff_xIndex(diffs, loc)
	local chars1 = 1
	local chars2 = 1
	local last_chars1 = 1
	local last_chars2 = 1
	local x
	for _x, diff in ipairs(diffs) do
		x = _x
		if diff[1] ~= DIFF_INSERT then	 -- Equality or deletion.
			chars1 = chars1 + #diff[2]
		end
		if diff[1] ~= DIFF_DELETE then	 -- Equality or insertion.
			chars2 = chars2 + #diff[2]
		end
		if chars1 > loc then	 -- Overshot the location.
			break
		end
		last_chars1 = chars1
		last_chars2 = chars2
	end
	-- Was the location deleted?
	if diffs[x + 1] and (diffs[x][1] == DIFF_DELETE) then
		return last_chars2
	end
	-- Add the remaining character length.
	return last_chars2 + (loc - last_chars1)
end

--[[
* Compute and return the source text (all equalities and deletions).
* @param {Array.<Array.<number|string>>} diffs Array of diff tuples.
* @return {string} Source text.
--]]
function _diff_text1(diffs)
	local text = {}
	for x, diff in ipairs(diffs) do
		if diff[1] ~= DIFF_INSERT then
			text[#text + 1] = diff[2]
		end
	end
	return tconcat(text)
end

--[[
* Compute and return the destination text (all equalities and insertions).
* @param {Array.<Array.<number|string>>} diffs Array of diff tuples.
* @return {string} Destination text.
--]]
function _diff_text2(diffs)
	local text = {}
	for x, diff in ipairs(diffs) do
		if diff[1] ~= DIFF_DELETE then
			text[#text + 1] = diff[2]
		end
	end
	return tconcat(text)
end

--[[
* Crush the diff into an encoded string which describes the operations
* required to transform text1 into text2.
* E.g. =3\t-2\t+ing	-> Keep 3 chars, delete 2 chars, insert 'ing'.
* Operations are tab-separated.	Inserted text is escaped using %xx notation.
* @param {Array.<Array.<number|string>>} diffs Array of diff tuples.
* @return {string} Delta text.
--]]
function _diff_toDelta(diffs)
	local text = {}
	for x, diff in ipairs(diffs) do
		local op, data = diff[1], diff[2]
		if op == DIFF_INSERT then
			text[x] = '+' .. gsub(data, percentEncode_pattern, percentEncode_replace)
		elseif op == DIFF_DELETE then
			text[x] = '-' .. #data
		elseif op == DIFF_EQUAL then
			text[x] = '=' .. #data
		end
	end
	return tconcat(text, '\t')
end

--[[
* Given the original text1, and an encoded string which describes the
* operations required to transform text1 into text2, compute the full diff.
* @param {string} text1 Source string for the diff.
* @param {string} delta Delta text.
* @return {Array.<Array.<number|string>>} Array of diff tuples.
* @throws {Errorend If invalid input.
--]]
function _diff_fromDelta(text1, delta)
	local diffs = {}
	local diffsLength = 0	-- Keeping our own length var is faster
	local pointer = 1	-- Cursor in text1
	for token in gmatch(delta, '[^\t]+') do
		-- Each token begins with a one character parameter which specifies the
		-- operation of this token (delete, insert, equality).
		local tokenchar, param = strsub(token, 1, 1), strsub(token, 2)
		if (tokenchar == '+') then
			local invalidDecode = false
			local decoded = gsub(param, '%%(.?.?)',
					function(c)
						local n = tonumber(c, 16)
						if (#c ~= 2) or (n == nil) then
							invalidDecode = true
							return ''
						end
						return strchar(n)
					end)
			if invalidDecode then
				-- Malformed URI sequence.
				error('Illegal escape in _diff_fromDelta: ' .. param)
			end
			diffsLength = diffsLength + 1
			diffs[diffsLength] = {DIFF_INSERT, decoded}
		elseif (tokenchar == '-') or (tokenchar == '=') then
			local n = tonumber(param)
			if (n == nil) or (n < 0) then
				error('Invalid number in _diff_fromDelta: ' .. param)
			end
			local text = strsub(text1, pointer, pointer + n - 1)
			pointer = pointer + n
			if (tokenchar == '=') then
				diffsLength = diffsLength + 1
				diffs[diffsLength] = {DIFF_EQUAL, text}
			else
				diffsLength = diffsLength + 1
				diffs[diffsLength] = {DIFF_DELETE, text}
			end
		else
			error('Invalid diff operation in _diff_fromDelta: ' .. token)
		end
	end
	if (pointer ~= #text1 + 1) then
		error('Delta length (' .. (pointer - 1)
				.. ') does not equal source text length (' .. #text1 .. ').')
	end
	return diffs
end

-- ---------------------------------------------------------------------------
--	MATCH API
-- ---------------------------------------------------------------------------

local _match_bitap, _match_alphabet

--[[
* Locate the best instance of 'pattern' in 'text' near 'loc'.
* @param {string} text The text to search.
* @param {string} pattern The pattern to search for.
* @param {number} loc The location to search around.
* @return {number} Best match index or -1.
--]]
function match_main(text, pattern, loc)
	-- Check for null inputs.
	if text == nil or pattern == nil then
		error('Null inputs. (match_main)')
	end

	if text == pattern then
		-- Shortcut (potentially not guaranteed by the algorithm)
		return 1
	elseif #text == 0 then
		-- Nothing to match.
		return -1
	end
	loc = max(1, min(loc or 0, #text))
	if strsub(text, loc, loc + #pattern - 1) == pattern then
		-- Perfect match at the perfect spot!	(Includes case of null pattern)
		return loc
	else
		-- Do a fuzzy compare.
		return _match_bitap(text, pattern, loc)
	end
end

-- ---------------------------------------------------------------------------
-- UNOFFICIAL/PRIVATE MATCH FUNCTIONS
-- ---------------------------------------------------------------------------

--[[
* Initialise the alphabet for the Bitap algorithm.
* @param {string} pattern The text to encode.
* @return {Object} Hash of character locations.
* @private
--]]
function _match_alphabet(pattern)
	local s = {}
	local i = 0
	for c in gmatch(pattern, '.') do
		s[c] = bor(s[c] or 0, lshift(1, #pattern - i - 1))
		i = i + 1
	end
	return s
end

--[[
* Locate the best instance of 'pattern' in 'text' near 'loc' using the
* Bitap algorithm.
* @param {string} text The text to search.
* @param {string} pattern The pattern to search for.
* @param {number} loc The location to search around.
* @return {number} Best match index or -1.
* @private
--]]
function _match_bitap(text, pattern, loc)
	if #pattern > Match_MaxBits then
		error('Pattern too long.')
	end

	-- Initialise the alphabet.
	local s = _match_alphabet(pattern)

	--[[
	* Compute and return the score for a match with e errors and x location.
	* Accesses loc and pattern through being a closure.
	* @param {number} e Number of errors in match.
	* @param {number} x Location of match.
	* @return {number} Overall score for match (0.0 = good, 1.0 = bad).
	* @private
	--]]
	local function _match_bitapScore(e, x)
		local accuracy = e / #pattern
		local proximity = abs(loc - x)
		if (Match_Distance == 0) then
			-- Dodge divide by zero error.
			return (proximity == 0) and 1 or accuracy
		end
		return accuracy + (proximity / Match_Distance)
	end

	-- Highest score beyond which we give up.
	local score_threshold = Match_Threshold
	-- Is there a nearby exact match? (speedup)
	local best_loc = indexOf(text, pattern, loc)
	if best_loc then
		score_threshold = min(_match_bitapScore(0, best_loc), score_threshold)
		-- LUANOTE: Ideally we'd also check from the other direction, but Lua
		-- doesn't have an efficent lastIndexOf function.
	end

	-- Initialise the bit arrays.
	local matchmask = lshift(1, #pattern - 1)
	best_loc = -1

	local bin_min, bin_mid
	local bin_max = #pattern + #text
	local last_rd
	for d = 0, #pattern - 1, 1 do
		-- Scan for the best match; each iteration allows for one more error.
		-- Run a binary search to determine how far from 'loc' we can stray at this
		-- error level.
		bin_min = 0
		bin_mid = bin_max
		while (bin_min < bin_mid) do
			if (_match_bitapScore(d, loc + bin_mid) <= score_threshold) then
				bin_min = bin_mid
			else
				bin_max = bin_mid
			end
			bin_mid = floor(bin_min + (bin_max - bin_min) / 2)
		end
		-- Use the result from this iteration as the maximum for the next.
		bin_max = bin_mid
		local start = max(1, loc - bin_mid + 1)
		local finish = min(loc + bin_mid, #text) + #pattern

		local rd = {}
		for j = start, finish do
			rd[j] = 0
		end
		rd[finish + 1] = lshift(1, d) - 1
		for j = finish, start, -1 do
			local charMatch = s[strsub(text, j - 1, j - 1)] or 0
			if (d == 0) then	-- First pass: exact match.
				rd[j] = band(bor((rd[j + 1] * 2), 1), charMatch)
			else
				-- Subsequent passes: fuzzy match.
				-- Functions instead of operators make this hella messy.
				rd[j] = bor(
								band(
									bor(
										lshift(rd[j + 1], 1),
										1
									),
									charMatch
								),
								bor(
									bor(
										lshift(bor(last_rd[j + 1], last_rd[j]), 1),
										1
									),
									last_rd[j + 1]
								)
							)
			end
			if (band(rd[j], matchmask) ~= 0) then
				local score = _match_bitapScore(d, j - 1)
				-- This match will almost certainly be better than any existing match.
				-- But check anyway.
				if (score <= score_threshold) then
					-- Told you so.
					score_threshold = score
					best_loc = j - 1
					if (best_loc > loc) then
						-- When passing loc, don't exceed our current distance from loc.
						start = max(1, loc * 2 - best_loc)
					else
						-- Already passed loc, downhill from here on in.
						break
					end
				end
			end
		end
		-- No hope for a (better) match at greater error levels.
		if (_match_bitapScore(d + 1, loc) > score_threshold) then
			break
		end
		last_rd = rd
	end
	return best_loc
end

-- -----------------------------------------------------------------------------
-- PATCH API
-- -----------------------------------------------------------------------------

local _patch_addContext,
			_patch_deepCopy,
			_patch_addPadding,
			_patch_splitMax,
			_patch_appendText,
			_new_patch_obj

--[[
* Compute a list of patches to turn text1 into text2.
* Use diffs if provided, otherwise compute it ourselves.
* There are four ways to call this function, depending on what data is
* available to the caller:
* Method 1:
* a = text1, b = text2
* Method 2:
* a = diffs
* Method 3 (optimal):
* a = text1, b = diffs
* Method 4 (deprecated, use method 3):
* a = text1, b = text2, c = diffs
*
* @param {string|Array.<Array.<number|string>>} a text1 (methods 1,3,4) or
* Array of diff tuples for text1 to text2 (method 2).
* @param {string|Array.<Array.<number|string>>} opt_b text2 (methods 1,4) or
* Array of diff tuples for text1 to text2 (method 3) or undefined (method 2).
* @param {string|Array.<Array.<number|string>>} opt_c Array of diff tuples for
* text1 to text2 (method 4) or undefined (methods 1,2,3).
* @return {Array.<_new_patch_obj>} Array of patch objects.
--]]
function patch_make(a, opt_b, opt_c)
	local text1, diffs
	local type_a, type_b, type_c = type(a), type(opt_b), type(opt_c)
	if (type_a == 'string') and (type_b == 'string') and (type_c == 'nil') then
		-- Method 1: text1, text2
		-- Compute diffs from text1 and text2.
		text1 = a
		diffs = diff_main(text1, opt_b, true)
		if (#diffs > 2) then
			diff_cleanupSemantic(diffs)
			diff_cleanupEfficiency(diffs)
		end
	elseif (type_a == 'table') and (type_b == 'nil') and (type_c == 'nil') then
		-- Method 2: diffs
		-- Compute text1 from diffs.
		diffs = a
		text1 = _diff_text1(diffs)
	elseif (type_a == 'string') and (type_b == 'table') and (type_c == 'nil') then
		-- Method 3: text1, diffs
		text1 = a
		diffs = opt_b
	elseif (type_a == 'string') and (type_b == 'string') and (type_c == 'table')
			then
		-- Method 4: text1, text2, diffs
		-- text2 is not used.
		text1 = a
		diffs = opt_c
	else
		error('Unknown call format to patch_make.')
	end

	if (diffs[1] == nil) then
		return {}	-- Get rid of the null case.
	end

	local patches = {}
	local patch = _new_patch_obj()
	local patchDiffLength = 0	-- Keeping our own length var is faster.
	local char_count1 = 0	-- Number of characters into the text1 string.
	local char_count2 = 0	-- Number of characters into the text2 string.
	-- Start with text1 (prepatch_text) and apply the diffs until we arrive at
	-- text2 (postpatch_text).	We recreate the patches one by one to determine
	-- context info.
	local prepatch_text, postpatch_text = text1, text1
	for x, diff in ipairs(diffs) do
		local diff_type, diff_text = diff[1], diff[2]

		if (patchDiffLength == 0) and (diff_type ~= DIFF_EQUAL) then
			-- A new patch starts here.
			patch.start1 = char_count1 + 1
			patch.start2 = char_count2 + 1
		end

		if (diff_type == DIFF_INSERT) then
			patchDiffLength = patchDiffLength + 1
			patch.diffs[patchDiffLength] = diff
			patch.length2 = patch.length2 + #diff_text
			postpatch_text = strsub(postpatch_text, 1, char_count2)
					.. diff_text .. strsub(postpatch_text, char_count2 + 1)
		elseif (diff_type == DIFF_DELETE) then
			patch.length1 = patch.length1 + #diff_text
			patchDiffLength = patchDiffLength + 1
			patch.diffs[patchDiffLength] = diff
			postpatch_text = strsub(postpatch_text, 1, char_count2)
					.. strsub(postpatch_text, char_count2 + #diff_text + 1)
		elseif (diff_type == DIFF_EQUAL) then
			if (#diff_text <= Patch_Margin * 2)
					and (patchDiffLength ~= 0) and (#diffs ~= x) then
				-- Small equality inside a patch.
				patchDiffLength = patchDiffLength + 1
				patch.diffs[patchDiffLength] = diff
				patch.length1 = patch.length1 + #diff_text
				patch.length2 = patch.length2 + #diff_text
			elseif (#diff_text >= Patch_Margin * 2) then
				-- Time for a new patch.
				if (patchDiffLength ~= 0) then
					_patch_addContext(patch, prepatch_text)
					patches[#patches + 1] = patch
					patch = _new_patch_obj()
					patchDiffLength = 0
					-- Unlike Unidiff, our patch lists have a rolling context.
					-- http://code.google.com/p/google-diff-match-patch/wiki/Unidiff
					-- Update prepatch text & pos to reflect the application of the
					-- just completed patch.
					prepatch_text = postpatch_text
					char_count1 = char_count2
				end
			end
		end

		-- Update the current character count.
		if (diff_type ~= DIFF_INSERT) then
			char_count1 = char_count1 + #diff_text
		end
		if (diff_type ~= DIFF_DELETE) then
			char_count2 = char_count2 + #diff_text
		end
	end

	-- Pick up the leftover patch if not empty.
	if (patchDiffLength > 0) then
		_patch_addContext(patch, prepatch_text)
		patches[#patches + 1] = patch
	end

	return patches
end

--[[
* Merge a set of patches onto the text.	Return a patched text, as well
* as a list of true/false values indicating which patches were applied.
* @param {Array.<_new_patch_obj>} patches Array of patch objects.
* @param {string} text Old text.
* @return {Array.<string|Array.<boolean>>} Two return values, the
*		 new text and an array of boolean values.
--]]
function patch_apply(patches, text)
	if patches[1] == nil then
		return text, {}
	end

	-- Deep copy the patches so that no changes are made to originals.
	patches = _patch_deepCopy(patches)

	local nullPadding = _patch_addPadding(patches)
	text = nullPadding .. text .. nullPadding

	_patch_splitMax(patches)
	-- delta keeps track of the offset between the expected and actual location
	-- of the previous patch. If there are patches expected at positions 10 and
	-- 20, but the first patch was found at 12, delta is 2 and the second patch
	-- has an effective expected position of 22.
	local delta = 0
	local results = {}
	for x, patch in ipairs(patches) do
		local expected_loc = patch.start2 + delta
		local text1 = _diff_text1(patch.diffs)
		local start_loc
		local end_loc = -1
		if #text1 > Match_MaxBits then
			-- _patch_splitMax will only provide an oversized pattern in
			-- the case of a monster delete.
			start_loc = match_main(text,
					strsub(text1, 1, Match_MaxBits), expected_loc)
			if start_loc ~= -1 then
				end_loc = match_main(text, strsub(text1, -Match_MaxBits),
						expected_loc + #text1 - Match_MaxBits)
				if end_loc == -1 or start_loc >= end_loc then
					-- Can't find valid trailing context.	Drop this patch.
					start_loc = -1
				end
			end
		else
			start_loc = match_main(text, text1, expected_loc)
		end
		if start_loc == -1 then
			-- No match found.	:(
			results[x] = false
			-- Subtract the delta for this failed patch from subsequent patches.
			delta = delta - patch.length2 - patch.length1
		else
			-- Found a match.	:)
			results[x] = true
			delta = start_loc - expected_loc
			local text2
			if end_loc == -1 then
				text2 = strsub(text, start_loc, start_loc + #text1 - 1)
			else
				text2 = strsub(text, start_loc, end_loc + Match_MaxBits - 1)
			end
			if text1 == text2 then
				-- Perfect match, just shove the replacement text in.
				text = strsub(text, 1, start_loc - 1) .. _diff_text2(patch.diffs)
						.. strsub(text, start_loc + #text1)
			else
				-- Imperfect match.	Run a diff to get a framework of equivalent
				-- indices.
				local diffs = diff_main(text1, text2, false)
				if (#text1 > Match_MaxBits)
						and (diff_levenshtein(diffs) / #text1 > Patch_DeleteThreshold) then
					-- The end points match, but the content is unacceptably bad.
					results[x] = false
				else
					_diff_cleanupSemanticLossless(diffs)
					local index1 = 1
					local index2
					for y, mod in ipairs(patch.diffs) do
						if mod[1] ~= DIFF_EQUAL then
							index2 = _diff_xIndex(diffs, index1)
						end
						if mod[1] == DIFF_INSERT then
							text = strsub(text, 1, start_loc + index2 - 2)
									.. mod[2] .. strsub(text, start_loc + index2 - 1)
						elseif mod[1] == DIFF_DELETE then
							text = strsub(text, 1, start_loc + index2 - 2) .. strsub(text,
									start_loc + _diff_xIndex(diffs, index1 + #mod[2] - 1))
						end
						if mod[1] ~= DIFF_DELETE then
							index1 = index1 + #mod[2]
						end
					end
				end
			end
		end
	end
	-- Strip the padding off.
	text = strsub(text, #nullPadding + 1, -#nullPadding - 1)
	return text, results
end

--[[
* Take a list of patches and return a textual representation.
* @param {Array.<_new_patch_obj>} patches Array of patch objects.
* @return {string} Text representation of patches.
--]]
function patch_toText(patches)
	local text = {}
	for x, patch in ipairs(patches) do
		_patch_appendText(patch, text)
	end
	return tconcat(text)
end

--[[
* Parse a textual representation of patches and return a list of patch objects.
* @param {string} textline Text representation of patches.
* @return {Array.<_new_patch_obj>} Array of patch objects.
* @throws {Error} If invalid input.
--]]
function patch_fromText(textline)
	local patches = {}
	if (#textline == 0) then
		return patches
	end
	local text = {}
	for line in gmatch(textline .. "\n", '([^\n]*)\n') do
		text[#text + 1] = line
	end
	local textPointer = 1
	while (textPointer <= #text) do
		local start1, length1, start2, length2
		 = strmatch(text[textPointer], '^@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@$')
		if (start1 == nil) then
			error('Invalid patch string: "' .. text[textPointer] .. '"')
		end
		local patch = _new_patch_obj()
		patches[#patches + 1] = patch

		start1 = tonumber(start1)
		length1 = tonumber(length1) or 1
		if (length1 == 0) then
			start1 = start1 + 1
		end
		patch.start1 = start1
		patch.length1 = length1

		start2 = tonumber(start2)
		length2 = tonumber(length2) or 1
		if (length2 == 0) then
			start2 = start2 + 1
		end
		patch.start2 = start2
		patch.length2 = length2

		textPointer = textPointer + 1

		while true do
			local line = text[textPointer]
			if (line == nil) then
				break
			end
			local sign; sign, line = strsub(line, 1, 1), strsub(line, 2)

			local invalidDecode = false
			local decoded = gsub(line, '%%(.?.?)',
					function(c)
						local n = tonumber(c, 16)
						if (#c ~= 2) or (n == nil) then
							invalidDecode = true
							return ''
						end
						return strchar(n)
					end)
			if invalidDecode then
				-- Malformed URI sequence.
				error('Illegal escape in patch_fromText: ' .. line)
			end

			line = decoded

			if (sign == '-') then
				-- Deletion.
				patch.diffs[#patch.diffs + 1] = {DIFF_DELETE, line}
			elseif (sign == '+') then
				-- Insertion.
				patch.diffs[#patch.diffs + 1] = {DIFF_INSERT, line}
			elseif (sign == ' ') then
				-- Minor equality.
				patch.diffs[#patch.diffs + 1] = {DIFF_EQUAL, line}
			elseif (sign == '@') then
				-- Start of next patch.
				break
			elseif (sign == '') then
				-- Blank line?	Whatever.
			else
				-- WTF?
				error('Invalid patch mode "' .. sign .. '" in: ' .. line)
			end
			textPointer = textPointer + 1
		end
	end
	return patches
end

-- ---------------------------------------------------------------------------
-- UNOFFICIAL/PRIVATE PATCH FUNCTIONS
-- ---------------------------------------------------------------------------

local patch_meta = {
	__tostring = function(patch)
		local buf = {}
		_patch_appendText(patch, buf)
		return tconcat(buf)
	end
}

--[[
* Class representing one patch operation.
* @constructor
--]]
function _new_patch_obj()
	return setmetatable({
		--[[ @type {Array.<Array.<number|string>>} ]]
		diffs = {};
		--[[ @type {?number} ]]
		start1 = 1;	-- nil;
		--[[ @type {?number} ]]
		start2 = 1;	-- nil;
		--[[ @type {number} ]]
		length1 = 0;
		--[[ @type {number} ]]
		length2 = 0;
	}, patch_meta)
end

--[[
* Increase the context until it is unique,
* but don't let the pattern expand beyond Match_MaxBits.
* @param {_new_patch_obj} patch The patch to grow.
* @param {string} text Source text.
* @private
--]]
function _patch_addContext(patch, text)
	if (#text == 0) then
		return
	end
	local pattern = strsub(text, patch.start2, patch.start2 + patch.length1 - 1)
	local padding = 0

	-- LUANOTE: Lua's lack of a lastIndexOf function results in slightly
	-- different logic here than in other language ports.
	-- Look for the first two matches of pattern in text.	If two are found,
	-- increase the pattern length.
	local firstMatch = indexOf(text, pattern)
	local secondMatch = nil
	if (firstMatch ~= nil) then
		secondMatch = indexOf(text, pattern, firstMatch + 1)
	end
	while (#pattern == 0 or secondMatch ~= nil)
			and (#pattern < Match_MaxBits - Patch_Margin - Patch_Margin) do
		padding = padding + Patch_Margin
		pattern = strsub(text, max(1, patch.start2 - padding),
		patch.start2 + patch.length1 - 1 + padding)
		firstMatch = indexOf(text, pattern)
		if (firstMatch ~= nil) then
			secondMatch = indexOf(text, pattern, firstMatch + 1)
		else
			secondMatch = nil
		end
	end
	-- Add one chunk for good luck.
	padding = padding + Patch_Margin

	-- Add the prefix.
	local prefix = strsub(text, max(1, patch.start2 - padding), patch.start2 - 1)
	if (#prefix > 0) then
		tinsert(patch.diffs, 1, {DIFF_EQUAL, prefix})
	end
	-- Add the suffix.
	local suffix = strsub(text, patch.start2 + patch.length1,
	patch.start2 + patch.length1 - 1 + padding)
	if (#suffix > 0) then
		patch.diffs[#patch.diffs + 1] = {DIFF_EQUAL, suffix}
	end

	-- Roll back the start points.
	patch.start1 = patch.start1 - #prefix
	patch.start2 = patch.start2 - #prefix
	-- Extend the lengths.
	patch.length1 = patch.length1 + #prefix + #suffix
	patch.length2 = patch.length2 + #prefix + #suffix
end

--[[
* Given an array of patches, return another array that is identical.
* @param {Array.<_new_patch_obj>} patches Array of patch objects.
* @return {Array.<_new_patch_obj>} Array of patch objects.
--]]
function _patch_deepCopy(patches)
	local patchesCopy = {}
	for x, patch in ipairs(patches) do
		local patchCopy = _new_patch_obj()
		local diffsCopy = {}
		for i, diff in ipairs(patch.diffs) do
			diffsCopy[i] = {diff[1], diff[2]}
		end
		patchCopy.diffs = diffsCopy
		patchCopy.start1 = patch.start1
		patchCopy.start2 = patch.start2
		patchCopy.length1 = patch.length1
		patchCopy.length2 = patch.length2
		patchesCopy[x] = patchCopy
	end
	return patchesCopy
end

--[[
* Add some padding on text start and end so that edges can match something.
* Intended to be called only from within patch_apply.
* @param {Array.<_new_patch_obj>} patches Array of patch objects.
* @return {string} The padding string added to each side.
--]]
function _patch_addPadding(patches)
	local paddingLength = Patch_Margin
	local nullPadding = ''
	for x = 1, paddingLength do
		nullPadding = nullPadding .. strchar(x)
	end

	-- Bump all the patches forward.
	for x, patch in ipairs(patches) do
		patch.start1 = patch.start1 + paddingLength
		patch.start2 = patch.start2 + paddingLength
	end

	-- Add some padding on start of first diff.
	local patch = patches[1]
	local diffs = patch.diffs
	local firstDiff = diffs[1]
	if (firstDiff == nil) or (firstDiff[1] ~= DIFF_EQUAL) then
		-- Add nullPadding equality.
		tinsert(diffs, 1, {DIFF_EQUAL, nullPadding})
		patch.start1 = patch.start1 - paddingLength	-- Should be 0.
		patch.start2 = patch.start2 - paddingLength	-- Should be 0.
		patch.length1 = patch.length1 + paddingLength
		patch.length2 = patch.length2 + paddingLength
	elseif (paddingLength > #firstDiff[2]) then
		-- Grow first equality.
		local extraLength = paddingLength - #firstDiff[2]
		firstDiff[2] = strsub(nullPadding, #firstDiff[2] + 1) .. firstDiff[2]
		patch.start1 = patch.start1 - extraLength
		patch.start2 = patch.start2 - extraLength
		patch.length1 = patch.length1 + extraLength
		patch.length2 = patch.length2 + extraLength
	end

	-- Add some padding on end of last diff.
	patch = patches[#patches]
	diffs = patch.diffs
	local lastDiff = diffs[#diffs]
	if (lastDiff == nil) or (lastDiff[1] ~= DIFF_EQUAL) then
		-- Add nullPadding equality.
		diffs[#diffs + 1] = {DIFF_EQUAL, nullPadding}
		patch.length1 = patch.length1 + paddingLength
		patch.length2 = patch.length2 + paddingLength
	elseif (paddingLength > #lastDiff[2]) then
		-- Grow last equality.
		local extraLength = paddingLength - #lastDiff[2]
		lastDiff[2] = lastDiff[2] .. strsub(nullPadding, 1, extraLength)
		patch.length1 = patch.length1 + extraLength
		patch.length2 = patch.length2 + extraLength
	end

	return nullPadding
end

--[[
* Look through the patches and break up any which are longer than the maximum
* limit of the match algorithm.
* Intended to be called only from within patch_apply.
* @param {Array.<_new_patch_obj>} patches Array of patch objects.
--]]
function _patch_splitMax(patches)
	local patch_size = Match_MaxBits
	local x = 1
	while true do
		local patch = patches[x]
		if patch == nil then
			return
		end
		if patch.length1 > patch_size then
			local bigpatch = patch
			-- Remove the big old patch.
			tremove(patches, x)
			x = x - 1
			local start1 = bigpatch.start1
			local start2 = bigpatch.start2
			local precontext = ''
			while bigpatch.diffs[1] do
				-- Create one of several smaller patches.
				local patch = _new_patch_obj()
				local empty = true
				patch.start1 = start1 - #precontext
				patch.start2 = start2 - #precontext
				if precontext ~= '' then
					patch.length1, patch.length2 = #precontext, #precontext
					patch.diffs[#patch.diffs + 1] = {DIFF_EQUAL, precontext}
				end
				while bigpatch.diffs[1] and (patch.length1 < patch_size-Patch_Margin) do
					local diff_type = bigpatch.diffs[1][1]
					local diff_text = bigpatch.diffs[1][2]
					if (diff_type == DIFF_INSERT) then
						-- Insertions are harmless.
						patch.length2 = patch.length2 + #diff_text
						start2 = start2 + #diff_text
						patch.diffs[#(patch.diffs) + 1] = bigpatch.diffs[1]
						tremove(bigpatch.diffs, 1)
						empty = false
					elseif (diff_type == DIFF_DELETE) and (#patch.diffs == 1)
					 and (patch.diffs[1][1] == DIFF_EQUAL)
					 and (#diff_text > 2 * patch_size) then
						-- This is a large deletion.	Let it pass in one chunk.
						patch.length1 = patch.length1 + #diff_text
						start1 = start1 + #diff_text
						empty = false
						patch.diffs[#patch.diffs + 1] = {diff_type, diff_text}
						tremove(bigpatch.diffs, 1)
					else
						-- Deletion or equality.
						-- Only take as much as we can stomach.
						diff_text = strsub(diff_text, 1,
						patch_size - patch.length1 - Patch_Margin)
						patch.length1 = patch.length1 + #diff_text
						start1 = start1 + #diff_text
						if (diff_type == DIFF_EQUAL) then
							patch.length2 = patch.length2 + #diff_text
							start2 = start2 + #diff_text
						else
							empty = false
						end
						patch.diffs[#patch.diffs + 1] = {diff_type, diff_text}
						if (diff_text == bigpatch.diffs[1][2]) then
							tremove(bigpatch.diffs, 1)
						else
							bigpatch.diffs[1][2]
									= strsub(bigpatch.diffs[1][2], #diff_text + 1)
						end
					end
				end
				-- Compute the head context for the next patch.
				precontext = _diff_text2(patch.diffs)
				precontext = strsub(precontext, -Patch_Margin)
				-- Append the end context for this patch.
				local postcontext = strsub(_diff_text1(bigpatch.diffs), 1, Patch_Margin)
				if postcontext ~= '' then
					patch.length1 = patch.length1 + #postcontext
					patch.length2 = patch.length2 + #postcontext
					if patch.diffs[1]
							and (patch.diffs[#patch.diffs][1] == DIFF_EQUAL) then
						patch.diffs[#patch.diffs][2] = patch.diffs[#patch.diffs][2]
								.. postcontext
					else
						patch.diffs[#patch.diffs + 1] = {DIFF_EQUAL, postcontext}
					end
				end
				if not empty then
					x = x + 1
					tinsert(patches, x, patch)
				end
			end
		end
		x = x + 1
	end
end

--[[
* Emulate GNU diff's format.
* Header: @@ -382,8 +481,9 @@
* @return {string} The GNU diff string.
--]]
function _patch_appendText(patch, text)
	local coords1, coords2
	local length1, length2 = patch.length1, patch.length2
	local start1, start2 = patch.start1, patch.start2
	local diffs = patch.diffs

	if length1 == 1 then
		coords1 = start1
	else
		coords1 = ((length1 == 0) and (start1 - 1) or start1) .. ',' .. length1
	end

	if length2 == 1 then
		coords2 = start2
	else
		coords2 = ((length2 == 0) and (start2 - 1) or start2) .. ',' .. length2
	end
	text[#text + 1] = '@@ -' .. coords1 .. ' +' .. coords2 .. ' @@\n'

	local op
	-- Escape the body of the patch with %xx notation.
	for x, diff in ipairs(patch.diffs) do
		local diff_type = diff[1]
		if diff_type == DIFF_INSERT then
			op = '+'
		elseif diff_type == DIFF_DELETE then
			op = '-'
		elseif diff_type == DIFF_EQUAL then
			op = ' '
		end
		text[#text + 1] = op
				.. gsub(diffs[x][2], percentEncode_pattern, percentEncode_replace)
				.. '\n'
	end

	return text
end

settings {
	Match_Threshold = 0.3,
}

-- Expose the API
local _M = {}

_M.DIFF_DELETE = DIFF_DELETE
_M.DIFF_INSERT = DIFF_INSERT
_M.DIFF_EQUAL = DIFF_EQUAL

_M.diff_main = diff_main
_M.diff_cleanupSemantic = diff_cleanupSemantic
_M.diff_cleanupEfficiency = diff_cleanupEfficiency
_M.diff_levenshtein = diff_levenshtein
_M.diff_prettyHtml = diff_prettyHtml

_M.match_main = match_main

_M.patch_make = patch_make
_M.patch_toText = patch_toText
_M.patch_fromText = patch_fromText
_M.patch_apply = patch_apply

-- Expose some non-API functions as well, for testing purposes etc.
_M.diff_commonPrefix = _diff_commonPrefix
_M.diff_commonSuffix = _diff_commonSuffix
_M.diff_commonOverlap = _diff_commonOverlap
_M.diff_halfMatch = _diff_halfMatch
_M.diff_bisect = _diff_bisect
_M.diff_cleanupMerge = _diff_cleanupMerge
_M.diff_cleanupSemanticLossless = _diff_cleanupSemanticLossless
_M.diff_text1 = _diff_text1
_M.diff_text2 = _diff_text2
_M.diff_toDelta = _diff_toDelta
_M.diff_fromDelta = _diff_fromDelta
_M.diff_xIndex = _diff_xIndex
_M.match_alphabet = _match_alphabet
_M.match_bitap = _match_bitap
_M.new_patch_obj = _new_patch_obj
_M.patch_addContext = _patch_addContext
_M.patch_splitMax = _patch_splitMax
_M.patch_addPadding = _patch_addPadding
_M.settings = settings

return _M

end
preload["bsrocks.lib.diff"] = function(...)
--[[
	(C) Paul Butler 2008-2012 <http://www.paulbutler.org/>
	May be used and distributed under the zlib/libpng license
	<http://www.opensource.org/licenses/zlib-license.php>

	Adaptation to Lua by Philippe Fremy <phil at freehackers dot org>
	Lua version copyright 2015
]]
local ipairs = ipairs

local function table_join(t1, t2, t3)
	-- return a table containing all elements of t1 then t2 then t3
	local t, n = {}, 0
	for i,v in ipairs(t1) do
		n = n + 1
		t[n] = v
	end

	for i,v in ipairs(t2) do
		n = n + 1
		t[n] = v
	end

	if t3 then
		for i,v in ipairs(t3) do
			n = n + 1
			t[n] = v
		end
	end

	return t
end

local function table_subtable( t, start, stop )
	-- 0 is first element, stop is last element
	local ret = {}
	if stop == nil then
		stop = #t
	end
	if start < 0 or stop < 0 or start > stop then
		error('Invalid values: '..start..' '..stop )
	end
	for i,v in ipairs(t) do
		if (i-1) >= start and (i-1) < stop then
			table.insert( ret, v )
		end
	end
	return ret
end

--[[-
	Find the differences between two lists or strings.

	Returns a list of pairs, where the first value is in ['+','-','=']
	and represents an insertion, deletion, or no change for that list.

	The second value of the pair is the list of elements.

	@tparam table old the old list of immutable, comparable values (ie. a list of strings)
	@tparam table new the new list of immutable, comparable values

	@return table A list of pairs, with the first part of the pair being one of three
		strings ('-', '+', '=') and the second part being a list of values from
		the original old and/or new lists. The first part of the pair
		corresponds to whether the list of values is a deletion, insertion, or
		unchanged, respectively.

	@example
		diff( {1,2,3,4}, {1,3,4})
		{ {'=', {1} }, {'-', {2} }, {'=', {3, 4}} }

		diff( {1,2,3,4}, {2,3,4,1} )
		{ {'-', {1}}, {'=', {2, 3, 4}}, {'+', {1}} }

		diff(
			{ 'The', 'quick', 'brown', 'fox', 'jumps', 'over', 'the', 'lazy', 'dog' },
			{ 'The', 'slow', 'blue', 'cheese', 'drips', 'over', 'the', 'lazy', 'carrot' }
		)
		{ {'=', {'The'} },
			{'-', {'quick', 'brown', 'fox', 'jumps'} },
			{'+', {'slow', 'blue', 'cheese', 'drips'} },
			{'=', {'over', 'the', 'lazy'} },
			{'-', {'dog'} },
			{'+', {'carrot'} }
		}
]]
local function diff(old, new)
	-- Create a map from old values to their indices
	local old_index_map = {}
	for i, val in ipairs(old) do
		if not old_index_map[val] then
			old_index_map[val] = {}
		end
		table.insert( old_index_map[val], i-1 )
	end

	--[[
		Find the largest substring common to old and new.
		We use a dynamic programming approach here.

		We iterate over each value in the `new` list, calling the
		index `inew`. At each iteration, `overlap[i]` is the
		length of the largest suffix of `old[:i]` equal to a suffix
		of `new[:inew]` (or unset when `old[i]` != `new[inew]`).

		At each stage of iteration, the new `overlap` (called
		`_overlap` until the original `overlap` is no longer needed)
		is built from the old one.

		If the length of overlap exceeds the largest substring
		seen so far (`sub_length`), we update the largest substring
		to the overlapping strings.

		`sub_start_old` is the index of the beginning of the largest overlapping
		substring in the old list. `sub_start_new` is the index of the beginning
		of the same substring in the new list. `sub_length` is the length that
		overlaps in both.
		These track the largest overlapping substring seen so far, so naturally
		we start with a 0-length substring.
	]]
	local overlap = {}
	local sub_start_old = 0
	local sub_start_new = 0
	local sub_length = 0

	for inewInc, val in ipairs(new) do
		local inew = inewInc-1
		local _overlap = {}
		if old_index_map[val] then
			for _,iold in ipairs(old_index_map[val]) do
				-- now we are considering all values of iold such that
				-- `old[iold] == new[inew]`.
				if iold <= 0 then
					_overlap[iold] = 1
				else
					_overlap[iold] = (overlap[iold - 1] or 0) + 1
				end
				if (_overlap[iold] > sub_length) then
					sub_length = _overlap[iold]
					sub_start_old = iold - sub_length + 1
					sub_start_new = inew - sub_length + 1
				end
			end
		end
		overlap = _overlap
	end

	if sub_length == 0 then
		-- If no common substring is found, we return an insert and delete...
		local oldRet = {}
		local newRet = {}

		if #old > 0 then
			oldRet = { {'-', old} }
		end
		if #new > 0 then
			newRet = { {'+', new} }
		end

		return table_join( oldRet, newRet )
	else
		-- ...otherwise, the common substring is unchanged and we recursively
		-- diff the text before and after that substring
		return table_join(
			diff(
				table_subtable( old, 0, sub_start_old),
				table_subtable( new, 0, sub_start_new)
			),
			{ {'=', table_subtable(new,sub_start_new,sub_start_new + sub_length) } },
			diff(
				table_subtable( old, sub_start_old + sub_length ),
				table_subtable( new, sub_start_new + sub_length )
			)
	   )
	end
end

return diff

end
preload["bsrocks.env.package"] = function(...)
--- The main package library - a pure lua reimplementation of the package library in lua
-- See: http://www.lua.org/manual/5.1/manual.html#5.3

local fileWrapper = require "bsrocks.lib.files"
local settings = require "bsrocks.lib.settings"
local utils = require "bsrocks.lib.utils"
local checkType = utils.checkType

return function(env)
	local _G = env._G

	local path = settings.libPath
	if type(path) == "table" then path = table.concat(path, ";") end
	path = path:gsub("%%{(%a+)}", settings)

	local package = {
		loaded = {},
		preload = {},
		path = path,
		config = "/\n;\n?\n!\n-",
		cpath = "",
	}
	-- Set as a global
	_G.package = package

	--- Load up the package data
	-- This by default produces an error
	function package.loadlib(libname, funcname)
		return nil, "dynamic libraries not enabled", "absent"
	end

	--- Allows the module to access the global table
	-- @tparam table module The module
	function package.seeall(module)
		checkType(module, "table")

		local meta = getmetatable(module)
		if not meta then
			meta = {}
			setmetatable(module, meta)
		end

		meta.__index = _G
	end

	package.loaders = {
		--- Preloader - checks preload table
		-- @tparam string name Package name to load
		function(name)
			checkType(name, "string")
			return package.preload[name] or ("\n\tno field package.preload['" .. name .. "']")
		end,

		function(name)
			checkType(name, "string")
			local path = package.path
			if type(path) ~= "string" then
				error("package.path is not a string", 2)
			end

			name = name:gsub("%.", "/")

			local errs = {}

			local pos, len = 1, #path
			while pos <= len do
				local start = path:find(";", pos)
				if not start then
					start = len + 1
				end

				local filePath = env.resolve(path:sub(pos, start - 1):gsub("%?", name, 1))
				pos = start + 1

				local loaded, err

				if fs.exists(filePath) then
					loaded, err = load(fileWrapper.read(filePath), filePath, "t", _G)
				elseif fs.exists(filePath .. ".lua") then
					loaded, err = load(fileWrapper.read(filePath .. ".lua"), filePath, "t", _G)
				else
					err = "File not found"
				end

				if type(loaded) == "function" then
					return loaded
				end

				errs[#errs + 1] = "'" .. filePath .. "': " .. err
			end

			return table.concat(errs, "\n\t")
		end
	}

	--- Require a module
	-- @tparam string name The name of the module
	-- Checks each loader in turn. If it finds a function then it will
	-- execute it and store the result in package.loaded[name]
	function _G.require(name)
		checkType(name, "string")

		local loaded = package.loaded
		local thisPackage = loaded[name]

		if thisPackage ~= nil then
			if thisPackage then return thisPackage end
			error("loop or previous error loading module ' " .. name .. "'", 2)
		end

		local loaders = package.loaders
		checkType(loaders, "table")

		local errs = {}
		for _, loader in ipairs(loaders) do
			thisPackage = loader(name)

			local lType = type(thisPackage)
			if lType == "string" then
				errs[#errs + 1] = thisPackage
			elseif lType == "function" then
				-- Prevent cyclic dependencies
				loaded[name] = false

				-- Execute the method
				local result = thisPackage(name)

				-- If we returned something then set the result to it
				if result ~= nil then
					loaded[name] = result
				else
					-- If set something in the package.loaded table then use that
					result = loaded[name]
					if result == false then
						-- Otherwise just set it to true
						loaded[name] = true
						result = true
					end
				end

				return result
			end
		end

		-- Can't find it - just error
		error("module '" .. name .. "' not found: " .. name .. table.concat(errs, ""))
	end

	-- Find the name of a table
	-- @tparam table table The table to look in
	-- @tparam string name The name to look up (abc.def.ghi)
	-- @return The table for that name or a new one or nil if a non table has it already
	local function findTable(table, name)
		local pos, len = 1, #name
		while pos <= len do
			local start = name:find(".", pos, true)
			if not start then
				start = len + 1
			end

			local key = name:sub(pos, start - 1)
			pos = start + 1

			local val = rawget(table, key)
			if val == nil then
				-- If it doesn't exist then create it
				val = {}
				table[key] = val
				table = val
			elseif type(val) == "table" then
				table = val
			else
				return nil
			end
		end

		return table
	end

	-- Set the current env to be a module
	-- @tparam lua
	function _G.module(name, ...)
		checkType(name, "string")

		local module = package.loaded[name]
		if type(module) ~= "table" then
			module = findTable(_G, name)
			if not module then
				error("name conflict for module '" .. name .. "'", 2)
			end

			package.loaded[name] = module
		end

		-- Init properties
		if module._NAME == nil then
			module._M = module
			module._NAME = name:gsub("([^.]+%.)", "") -- Everything afert last .
			module._PACKAGE = name:gsub("%.[^%.]+$", "") or "" -- Everything before the last .
		end

		setfenv(2, module)

		-- Applies functions. This could be package.seeall or similar
		for _, modifier in pairs({...}) do
			modifier(module)
		end
	end

	-- Populate the package.loaded table
	local loaded = package.loaded
	for k, v in pairs(_G) do
		if type(v) == "table" then
			loaded[k] = v
		end
	end

	return package
end

end
preload["bsrocks.env.os"] = function(...)
--- Pure lua implementation of the OS api
-- http://www.lua.org/manual/5.1/manual.html#5.8

local utils = require "bsrocks.lib.utils"
local date = require "bsrocks.env.date"
local checkType = utils.checkType

return function(env)
	local os, shell = os, shell
	local envVars = {}
	local temp = {}

	local clock = os.clock
	if profiler and profiler.milliTime then
		clock = function() return profiler.milliTime() * 1e-3 end
	end

	env._G.os = {
		clock = clock,
		date = function(format, time)
			format = checkType(format or "%c", "string")
			time = checkType(time or os.time(), "number")

			-- Ignore UTC/CUT
			if format:sub(1, 1) == "!" then format = format:sub(2) end

			local d = date.create(time)

			if format == "*t" then
				return d
			elseif format == "%c" then
				return date.asctime(d)
			else
				return date.strftime(format, d)
			end
		end,


		-- Returns the number of seconds from time t1 to time t2. In POSIX, Windows, and some other systems, this value is exactly t2-t1.
		difftime = function(t1, t2)
			return t2 - t1
		end,

		execute = function(command)
			if shell.run(command) then
				return 0
			else
				return 1
			end
		end,
		exit  = function(code) error("Exit code: " .. (code or 0), 0) end,
		getenv = function(name)
			-- I <3 ClamShell
			if shell.getenv then
				local val = shell.getenv(name)
				if val ~= nil then return val end
			end

			if settings and settings.get then
				local val = settings.get(name)
				if val ~= nil then return val end
			end

			return envVars[name]
		end,

		remove = function(path)
			return pcall(fs.delete, env.resolve(checkType(path, "string")))
		end,
		rename = function(oldname, newname)
			return pcall(fs.rename, env.resolve(checkType(oldname, "string")), env.resolve(checkType(newname, "string")))
		end,
		setlocale = function() end,
		-- Technically not
		time = function(tbl)
			if not tbl then return os.time() end

			checkType(tbl, "table")
			return date.timestamp(tbl)
		end,
		tmpname = function()
			local name = utils.tmpName()
			temp[name] = true
			return name
		end
	}

	-- Delete temp files
	env.cleanup[#env.cleanup + 1] = function()
		for file, _ in pairs(temp) do
			pcall(fs.delete, file)
		end
	end
end

end
preload["bsrocks.env.io"] = function(...)
--- The main io library
-- See: http://www.lua.org/manual/5.1/manual.html#5.7
-- Some elements are duplicated in /rom/apis/io but this is a more accurate representation

local utils = require "bsrocks.lib.utils"
local ansi = require "bsrocks.env.ansi"
local checkType = utils.checkType

local function isFile(file)
	return type(file) == "table" and file.close and file.flush and file.lines and file.read and file.seek and file.setvbuf and file.write
end

local function checkFile(file)
	if not isFile(file) then
		error("Not a file: Missing one of: close, flush, lines, read, seek, setvbuf, write", 3)
	end
end

local function getHandle(file)
	local t = type(file)
	if t ~= "table" or not file.__handle then
		error("FILE* expected, got " .. t)
	end

	if file.__isClosed then
		error("attempt to use closed file", 3)
	end

	return file.__handle
end

local fileMeta = {
	__index = {
		close = function(self)
			self.__handle.close()
			self.__isClosed = true
		end,
		flush = function(self)
			getHandle(self).flush()
		end,
		read = function(self, ...)
			local handle = getHandle(self)

			local returns = {}

			local data = {...}
			local n = select("#", ...)
			if n == 0 then n = 1 end
			for i = 1, n do
				local format = data[i] or "l"
				format = checkType(format, "string"):gsub("%*", ""):sub(1, 1) -- "*" is not needed after Lua 5.1 - lets be friendly

				local res, msg
				if format == "l" then
					res, msg = handle.readLine()
				elseif format == "a" then
					res, msg = handle.readAll()
				elseif format == "r" then
					res, msg = handle.read() -- Binary only
				else
					error("(invalid format", 2)
				end

				if not res then return res, msg end
				returns[#returns + 1] = res
			end

			return unpack(returns)
		end,

		seek = function(self, ...)
			error("File seek is not implemented", 2)
		end,

		setvbuf = function() end,

		write = function(self, ...)
			local handle = getHandle(self)

			local data = {...}
			local n = select("#", ...)
			for i = 1, n do
				local item = data[i]
				local t = type(item)
				if t ~= "string" and t ~= "number" then
					error("string expected, got " .. t)
				end

				handle.write(tostring(item))
			end

			return true
		end,

		lines = function(self, ...)
			return self.__handle.readLine
		end,
	}
}

return function(env)
	local io = {}
	env._G.io = io

	local function loadFile(path, mode)
		path = env.resolve(path)
		mode = (mode or "r"):gsub("%+", "")

		local ok, result = pcall(fs.open, path, mode)
		if not ok or not result then
			return nil, result or "No such file or directory"
		end
		return setmetatable({ __handle = result }, fileMeta)
	end

	do -- Setup standard outputs
		local function voidStub() end
		local function closeStub() return nil, "cannot close standard file" end
		local function readStub() return nil, "bad file descriptor" end

		env.stdout = setmetatable({
			__handle = {
				close = closeStub,
				flush = voidStub,
				read = readStub, readLine = readStub, readAll = readStub,
				write = function(arg) ansi.write(arg) end,
			}
		}, fileMeta)

		env.stderr = setmetatable({
			__handle = {
				close = closeStub,
				flush = voidStub,
				read = readStub, readLine = readStub, readAll = readStub,
				write = function(arg)
					local c = term.isColor()
					if c then term.setTextColor(colors.red) end
					ansi.write(arg)
					if c then term.setTextColor(colors.white) end
				end,
			}
		}, fileMeta)

		env.stdin = setmetatable({
			__handle = {
				close = closeStub,
				flush = voidStub,
				read = function() return string.byte(os.pullEvent("char")) end,
				readLine = read, readAll = read,
				write = function() error("cannot write to input", 3) end,
			}
		}, fileMeta)

		io.stdout = env.stdout
		io.stderr = env.stderr
		io.stdin  = env.stdin
	end

	function io.close(file)
		(file or env.stdout):close()
	end

	function io.flush(file)
		env.stdout:flush()
	end

	function io.input(file)
		local t = type(file)

		if t == "nil" then
			return env.stdin
		elseif t == "string" then
			file = assert(loadFile(file, "r"))
		elseif t ~= "table" then
			error("string expected, got " .. t, 2)
		end

		checkFile(file)

		io.stdin = file
		env.stdin = file

		return file
	end

	function io.output(file)
		local t = type(file)

		if t == "nil" then
			return env.stdin
		elseif t == "string" then
			file = assert(loadFile(file, "w"))
		elseif t ~= "table" then
			error("string expected, got " .. t, 2)
		end

		checkFile(file)

		io.stdout = file
		env.stdout = file

		return file
	end

	function io.popen(file)
		error("io.popen is not implemented", 2)
	end

	function io.read(...)
		return env.stdin:read(...)
	end

	local temp = {}
	function io.tmpfile()
		local name = utils.tmpName()
		temp[name] = true
		return loadFile(name, "w")
 	end

	io.open = loadFile

 	function io.type(file)
 		if isFile(file) then
 			if file.__isClosed then return "closed file" end
 			return "file"
		else
			return type(file)
 		end
 	end

 	function io.write(...)
 		return env.stdout:write(...)
 	end

	env._G.write = io.write
	env._G.print = ansi.print

 	-- Delete temp files
	env.cleanup[#env.cleanup + 1] = function()
		for file, _ in pairs(temp) do
			pcall(fs.delete, file)
		end
	end

	return io
end

end
preload["bsrocks.env"] = function(...)
local fileWrapper = require "bsrocks.lib.files"

local function addWithMeta(src, dest)
	for k, v in pairs(src) do
		if dest[k] == nil then
			dest[k] = v
		end
	end

	local meta = getmetatable(src)
	if type(meta) == "table" and type(meta.__index) == "table" then
		return addWithMeta(meta.__index, dest)
	end
end

return function()
	local nImplemented = function(name)
		return function()
			error(name .. " is not implemented", 2)
		end
	end

	local _G = {
		math = math,
		string = string,
		table = table,
		coroutine = coroutine,
		collectgarbage = nImplemented("collectgarbage"),
		_VERSION = _VERSION
	}
	_G._G = _G
	_G._ENV = _G

	local env = {
		_G = _G,
		dir = shell.dir(),

		stdin = false,
		stdout = false,
		strerr = false,
		cleanup = {}
	}

	function env.resolve(path)
		if path:sub(1, 1) ~= "/" then
			path = fs.combine(env.dir, path)
		end
		return path
	end

	function _G.load(func, chunk)
		local cache = {}
		while true do
			local r = func()
			if r == "" or r == nil then
				break
			end
			cache[#cache + 1] = r
		end

		return _G.loadstring(table.concat(func), chunk or "=(load)")
	end

	-- Need to set environment
	function _G.loadstring(name, chunk)
		return load(name, chunk, nil, _G)
	end

	-- Customised loadfile function to work with relative files
	function _G.loadfile(path)
		path = env.resolve(path)
		if fs.exists(path) then
			return load(fileWrapper.read(path), path, "t", _G)
		else
			return nil, "File not found"
		end
	end

	function _G.dofile(path)
		assert(_G.loadfile(path))()
	end

	function _G.print(...)
		local out = env.stdout
		local tostring = _G.tostring -- Allow overriding
		local t = {...}
		for i = 1, select('#', ...) do
			if i > 1 then
				out:write("\t")
			end
			out:write(tostring(t[i]))
		end

		out:write("\n")
	end

	local errors, nilFiller = {}, {}
	local function getError(message)
		if message == nil then return nil end

		local result = errors[message]
		errors[message] = nil
		if result == nilFiller then
			result = nil
		elseif result == nil then
			result = message
		end
		return result
	end
	env.getError = getError

	local e = {}
	if select(2, pcall(error, e)) ~= e then
		local function extractError(...)
			local success, message = ...
			if success then
				return ...
			else
				return false, getError(message)
			end
		end

		function _G.error(message, level)
			level = level or 1
			if level > 0 then level = level + 1 end

			if type(message) ~= "string" then
				local key = tostring({}) .. tostring(message)
				if message == nil then message = nilFiller end
				errors[key] = message
				error(key, 0)
			else
				error(message, level)
			end
		end

		function _G.pcall(func, ...)
			return extractError(pcall(func, ...))
		end

		function _G.xpcall(func, handler)
			return xpcall(func, function(result) return handler(getError(result)) end)
		end
	end

	-- Setup other items
	require "bsrocks.env.fixes"(env)

	require "bsrocks.env.io"(env)
	require "bsrocks.env.os"(env)

	if not debug then
		require "bsrocks.env.debug"(env)
	else
		_G.debug = debug
	end

	require "bsrocks.env.package"(env)

	-- Copy functions across
	addWithMeta(_ENV, _G)
	_G._NATIVE = _ENV

	return env
end

end
preload["bsrocks.env.fixes"] = function(...)
--- Various patches for LuaJ's

local type, pairs = type, pairs

local function copy(tbl)
	local out = {}
	for k, v in pairs(tbl) do out[k] = v end
	return out
end

local function getmeta(obj)
	local t = type(obj)
	if t == "table" then
		return getmetatable(obj)
	elseif t == "string" then
		return string
	else
		return nil
	end
end

return function(env)
	env._G.getmetatable = getmeta

	if not table.pack().n then
		local table = copy(table)
		table.pack = function( ... ) return {n=select('#',...), ... } end

		env._G.table = table
	end

end

end
preload["bsrocks.env.debug"] = function(...)
--- Tiny ammount of the debug API
-- http://www.lua.org/manual/5.1/manual.html#5.9

local traceback = require "bsrocks.lib.utils".traceback

local function err(name)
	return function() error(name .. " not implemented", 2) end
end

--- Really tacky getinfo
local function getInfo(thread, func, what)
	if type(thread) ~= "thread" then
		func = thread
	end

	local data = {
		what = "lua",
		source = "",
		short_src = "",
		linedefined = -1,
		lastlinedefined = -1,
		currentline = -1,
		nups = -1,
		name = "?",
		namewhat = "",
		activelines = {},
	}

	local t = type(func)
	if t == "number" or t == "string" then
		func = tonumber(func)

		local _, source = pcall(error, "", 2 + func)
		local name = source:gsub(":?[^:]*: *$", "", 1)
		data.source = "@" .. name
		data.short_src = name

		local line = tonumber(source:match("^[^:]+:([%d]+):") or "")
		if line then data.currentline = line end
	elseif t == "function" then
		-- We really can't do much
		data.func = func
	else
		error("function or level expected", 2)
	end

	return data
end


return function(env)
	local debug = {
		getfenv = getfenv,
		gethook = err("gethook"),
		getinfo = getInfo,
		getlocal = err("getlocal"),
		gethook = err("gethook"),
		getmetatable = env._G.getmetatable,
		getregistry = err("getregistry"),
		setfenv = setfenv,
		sethook = err("sethook"),
		setlocal = err("setlocal"),
		setmetatable = setmetatable,
		setupvalue = err("setupvalue"),
		traceback = traceback,
	}
	env._G.debug = debug
end

end
preload["bsrocks.env.date"] = function(...)
--[[
The MIT License (MIT)

Copyright (c) 2013 Daurnimator

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]

local strformat = string.format
local floor = math.floor
local function idiv(n, d)  return floor(n / d) end

local mon_lengths = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
-- Number of days in year until start of month; not corrected for leap years
local months_to_days_cumulative = { 0 }
for i = 2, 12 do
	months_to_days_cumulative [ i ] = months_to_days_cumulative [ i-1 ] + mon_lengths [ i-1 ]
end
-- For Sakamoto's Algorithm (day of week)
local sakamoto = {0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4};

local function is_leap ( y )
	if (y % 4) ~= 0 then
		return false
	elseif (y % 100) ~= 0 then
		return true
	else
		return (y % 400) == 0
	end
end

local function year_length ( y )
	return is_leap ( y ) and 366 or 365
end

local function month_length ( m, y )
	if m == 2 then
		return is_leap ( y ) and 29 or 28
	else
		return mon_lengths [ m ]
	end
end

local function leap_years_since ( year )
	return idiv ( year, 4 ) - idiv ( year, 100 ) + idiv ( year, 400 )
end

local function day_of_year ( day, month, year )
	local yday = months_to_days_cumulative [ month ]
	if month > 2 and is_leap ( year ) then
		yday = yday + 1
	end
	return yday + day
end

local function day_of_week ( day, month, year )
	if month < 3 then
		year = year - 1
	end
	return ( year + leap_years_since ( year ) + sakamoto[month] + day ) % 7 + 1
end

local function borrow ( tens, units, base )
	local frac = tens % 1
	units = units + frac * base
	tens = tens - frac
	return tens, units
end

local function carry ( tens, units, base )
	if units >= base then
		tens  = tens + idiv ( units, base )
		units = units % base
	elseif units < 0 then
		tens  = tens - 1 + idiv ( -units, base )
		units = base - ( -units % base )
	end
	return tens, units
end

-- Modify parameters so they all fit within the "normal" range
local function normalise ( year, month, day, hour, min, sec )
	-- `month` and `day` start from 1, need -1 and +1 so it works modulo
	month, day = month - 1, day - 1

	-- Convert everything (except seconds) to an integer
	-- by propagating fractional components down.
	year,  month = borrow ( year,  month, 12 )
	-- Carry from month to year first, so we get month length correct in next line around leap years
	year,  month = carry ( year, month, 12 )
	month, day   = borrow ( month, day,   month_length ( floor ( month + 1 ), year ) )
	day,   hour  = borrow ( day,   hour,  24 )
	hour,  min   = borrow ( hour,  min,   60 )
	min,   sec   = borrow ( min,   sec,   60 )

	-- Propagate out of range values up
	-- e.g. if `min` is 70, `hour` increments by 1 and `min` becomes 10
	-- This has to happen for all columns after borrowing, as lower radixes may be pushed out of range
	min,   sec   = carry ( min,   sec,   60 ) -- TODO: consider leap seconds?
	hour,  min   = carry ( hour,  min,   60 )
	day,   hour  = carry ( day,   hour,  24 )
	-- Ensure `day` is not underflowed
	-- Add a whole year of days at a time, this is later resolved by adding months
	-- TODO[OPTIMIZE]: This could be slow if `day` is far out of range
	while day < 0 do
		year = year - 1
		day  = day + year_length ( year )
	end
	year, month = carry ( year, month, 12 )

	-- TODO[OPTIMIZE]: This could potentially be slow if `day` is very large
	while true do
		local i = month_length (month + 1, year)
		if day < i then break end
		day = day - i
		month = month + 1
		if month >= 12 then
			month = 0
			year = year + 1
		end
	end

	-- Now we can place `day` and `month` back in their normal ranges
	-- e.g. month as 1-12 instead of 0-11
	month, day = month + 1, day + 1

	return year, month, day, hour, min, sec
end

local function create(ts)
	local year, month, day, hour, min, sec = normalise (1970, 1, 1, 0 , 0, ts)

	return {
		day = day,
		month = month,
		year = year,
		hour = hour,
		min = min,
		sec = sec,
		yday  = day_of_year ( day , month , year ),
		wday  = day_of_week ( day , month , year )
	}
end

local leap_years_since_1970 = leap_years_since ( 1970 )

local function timestamp(year, month, day, hour, min, sec )
	year, month, day, hour, min, sec = normalise(year, month, day, hour, min, sec)

	local days_since_epoch = day_of_year ( day, month, year )
		+ 365 * ( year - 1970 )
		-- Each leap year adds one day
		+ ( leap_years_since ( year - 1 ) - leap_years_since_1970 ) - 1

	return days_since_epoch * (60*60*24)
		+ hour  * (60*60)
		+ min   * 60
		+ sec
end

local function timestampTbl(tbl)
	return timestamp(tbl.year, tbl.month, tbl.day, tbl.hour or 0, tbl.min or 0, tbl.sec or 0)
end

local c_locale = {
	abday = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" } ;
	day = { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" } ;
	abmon = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" } ;
	mon = { "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" } ;
	am_pm = { "AM", "PM" } ;
}

--- ISO-8601 week logic
-- ISO 8601 weekday as number with Monday as 1 (1-7)
local function iso_8601_weekday ( wday )
	if wday == 1 then
		return 7
	else
		return wday - 1
	end
end
local iso_8601_week do
	-- Years that have 53 weeks according to ISO-8601
	local long_years = { }
	for _, v in ipairs {
		  4,   9,  15,  20,  26,  32,  37,  43,  48,  54,  60,  65,  71,  76,  82,
		 88,  93,  99, 105, 111, 116, 122, 128, 133, 139, 144, 150, 156, 161, 167,
		172, 178, 184, 189, 195, 201, 207, 212, 218, 224, 229, 235, 240, 246, 252,
		257, 263, 268, 274, 280, 285, 291, 296, 303, 308, 314, 320, 325, 331, 336,
		342, 348, 353, 359, 364, 370, 376, 381, 387, 392, 398
	} do
		long_years [ v ] = true
	end
	local function is_long_year ( year )
		return long_years [ year % 400 ]
	end
	function iso_8601_week ( self )
		local wday = iso_8601_weekday ( self.wday )
		local n = self.yday - wday
		local year = self.year
		if n < -3 then
			year = year - 1
			if is_long_year ( year ) then
				return year, 53, wday
			else
				return year, 52, wday
			end
		elseif n >= 361 and not is_long_year ( year ) then
			return year + 1, 1, wday
		else
			return year, idiv ( n + 10, 7 ), wday
		end
	end
end

--- Specifiers
local t = { }
function t:a ( locale )
	return "%s", locale.abday [ self.wday ]
end
function t:A ( locale )
	return "%s", locale.day [ self.wday ]
end
function t:b ( locale )
	return "%s", locale.abmon [ self.month ]
end
function t:B ( locale )
	return "%s", locale.mon [ self.month ]
end
function t:c ( locale )
	return "%.3s %.3s%3d %.2d:%.2d:%.2d %d",
		locale.abday [ self.wday ], locale.abmon [ self.month ],
		self.day, self.hour, self.min, self.sec, self.year
end
-- Century
function t:C ( )
	return "%02d", idiv ( self.year, 100 )
end
function t:d ( )
	return "%02d", self.day
end
-- Short MM/DD/YY date, equivalent to %m/%d/%y
function t:D ( )
	return "%02d/%02d/%02d", self.month, self.day, self.year % 100
end
function t:e ( )
	return "%2d", self.day
end
-- Short YYYY-MM-DD date, equivalent to %Y-%m-%d
function t:F ( )
	return "%d-%02d-%02d", self.year, self.month, self.day
end
-- Week-based year, last two digits (00-99)
function t:g ( )
	return "%02d", iso_8601_week ( self ) % 100
end
-- Week-based year
function t:G ( )
	return "%d", iso_8601_week ( self )
end
t.h = t.b
function t:H ( )
	return "%02d", self.hour
end
function t:I ( )
	return "%02d", (self.hour-1) % 12 + 1
end
function t:j ( )
	return "%03d", self.yday
end
function t:m ( )
	return "%02d", self.month
end
function t:M ( )
	return "%02d", self.min
end
-- New-line character ('\n')
function t:n ( ) -- luacheck: ignore 212
	return "\n"
end
function t:p ( locale )
	return self.hour < 12 and locale.am_pm[1] or locale.am_pm[2]
end
-- TODO: should respect locale
function t:r ( locale )
	return "%02d:%02d:%02d %s",
		(self.hour-1) % 12 + 1, self.min, self.sec,
		self.hour < 12 and locale.am_pm[1] or locale.am_pm[2]
end
-- 24-hour HH:MM time, equivalent to %H:%M
function t:R ( )
	return "%02d:%02d", self.hour, self.min
end
function t:s ( )
	return "%d", timestamp(self)
end
function t:S ( )
	return "%02d", self.sec
end
-- Horizontal-tab character ('\t')
function t:t ( ) -- luacheck: ignore 212
	return "\t"
end
-- ISO 8601 time format (HH:MM:SS), equivalent to %H:%M:%S
function t:T ( )
	return "%02d:%02d:%02d", self.hour, self.min, self.sec
end
function t:u ( )
	return "%d", iso_8601_weekday ( self.wday )
end
-- Week number with the first Sunday as the first day of week one (00-53)
function t:U ( )
	return "%02d", idiv ( self.yday - self.wday + 7, 7 )
end
-- ISO 8601 week number (00-53)
function t:V ( )
	return "%02d", select ( 2, iso_8601_week ( self ) )
end
-- Weekday as a decimal number with Sunday as 0 (0-6)
function t:w ( )
	return "%d", self.wday - 1
end
-- Week number with the first Monday as the first day of week one (00-53)
function t:W ( )
	return "%02d", idiv ( self.yday - iso_8601_weekday ( self.wday ) + 7, 7 )
end
-- TODO make t.x and t.X respect locale
t.x = t.D
t.X = t.T
function t:y ( )
	return "%02d", self.year % 100
end
function t:Y ( )
	return "%d", self.year
end
-- TODO timezones
function t:z ( ) -- luacheck: ignore 212
	return "+0000"
end
function t:Z ( ) -- luacheck: ignore 212
	return "GMT"
end
-- A literal '%' character.
t["%"] = function ( self ) -- luacheck: ignore 212
	return "%%"
end

local function strftime ( format_string, timetable )
	return ( string.gsub ( format_string, "%%([EO]?)(.)", function ( locale_modifier, specifier )
		local func = t [ specifier ]
		if func then
			return strformat ( func ( timetable, c_locale ) )
		else
			error ( "invalid conversation specifier '%"..locale_modifier..specifier.."'", 3 )
		end
	end ) )
end

local function asctime ( timetable )
	-- Equivalent to the format string "%c\n"
	return strformat ( t.c ( timetable, c_locale ) )
end

return {
	create = create,
	timestamp = timestampTbl,
	strftime = strftime,
	asctime = asctime,
}

end
preload["bsrocks.env.ansi"] = function(...)
--- ANSI Support
-- @url https://en.wikipedia.org/wiki/ANSI_escape_code

local write, term = write, term
local type = type

local defBack, defText = term.getBackgroundColour(), term.getTextColour()
local setBack, setText = term.setBackgroundColour, term.setTextColour

local function create(func, col)
	return function() func(col) end
end

local function clamp(val, min, max)
	if val > max then
		return max
	elseif val < min then
		return min
	else
		return val
	end
end

local function move(x, y)
	local cX, cY = term.getCursorPos()
	local w, h = term.getSize()

	term.setCursorPos(clamp(x + cX, 1, w), clamp(y + cY, 1, h))
end

local cols = {
	['0'] = function()
		setBack(defBack)
		setText(defText)
	end,
	['7'] = function() -- Swap colours
		local curBack = term.getBackgroundColour()
		term.setBackgroundColour(term.getTextColour())
		term.setText(curBack)
	end,
	['30'] = create(setText, colours.black),
	['31'] = create(setText, colours.red),
	['32'] = create(setText, colours.green),
	['33'] = create(setText, colours.orange),
	['34'] = create(setText, colours.blue),
	['35'] = create(setText, colours.purple),
	['36'] = create(setText, colours.cyan),
	['37'] = create(setText, colours.lightGrey),

	['40'] = create(setBack, colours.black),
	['41'] = create(setBack, colours.red),
	['42'] = create(setBack, colours.green),
	['43'] = create(setBack, colours.orange),
	['44'] = create(setBack, colours.blue),
	['45'] = create(setBack, colours.purple),
	['46'] = create(setBack, colours.cyan),
	['47'] = create(setBack, colours.lightGrey),

	['90'] = create(setText, colours.grey),
	['91'] = create(setText, colours.red),
	['92'] = create(setText, colours.lime),
	['93'] = create(setText, colours.yellow),
	['94'] = create(setText, colours.lightBlue),
	['95'] = create(setText, colours.pink),
	['96'] = create(setText, colours.cyan),
	['97'] = create(setText, colours.white),

	['100'] = create(setBack, colours.grey),
	['101'] = create(setBack, colours.red),
	['102'] = create(setBack, colours.lime),
	['103'] = create(setBack, colours.yellow),
	['104'] = create(setBack, colours.lightBlue),
	['105'] = create(setBack, colours.pink),
	['106'] = create(setBack, colours.cyan),
	['107'] = create(setBack, colours.white),
}

local savedX, savedY = 1, 1
local actions = {
	m = function(args)
		for _, colour in ipairs(args) do
			local func = cols[colour]
			if func then func() end
		end
	end,
	['A'] = function(args)
		local y = tonumber(args[1])
		if not y then return end
		move(0, -y)
	end,
	['B'] = function(args)
		local y = tonumber(args[1])
		if not y then return end
		move(0, y)
	end,
	['C'] = function(args)
		local x = tonumber(args[1])
		if not x then return end
		move(x, 0)
	end,
	['D'] = function(args)
		local x = tonumber(args[1])
		if not x then return end
		move(-x, 0)
	end,
	['H'] = function(args)
		local x, y = tonumber(args[1]), tonumber(args[2])
		if not x or not y then return end
		local w, h = term.getSize()
		term.setCursorPos(clamp(x, 1, w), clamp(y, 1, h))
	end,
	['J'] = function(args)
		-- TODO: Support other modes
		if args[1] == "2" then term.clear() end
	end,
	['s'] = function()
		savedX, savedY = term.getCursorPos()
	end,
	['u'] = function()
		term.setCursorPos(savedX, savedY)
	end
}

local function writeAnsi(str)
	if stdout and stdout.isPiped then
		return stdout.write(text)
	end

	if type(str) ~= "string" then
		error("bad argument #1 (string expected, got " .. type(ansi) .. ")", 2)
	end

	local offset = 1
	while offset <= #str do
		local start, finish = str:find("\27[", offset, true)

		if start then
			if offset < start then
				write(str:sub(offset, start - 1))
			end

			local remaining = true
			local args, n = {}, 0
			local mode
			while remaining do
				finish = finish + 1
				start = finish

				while true do
					local s = str:sub(finish, finish)
					if s == ";" then
						break
					elseif (s >= 'A' and s <= 'Z') or (s >= 'a' and s <= 'z') then
						mode = s
						remaining = false
						break
					elseif s == "" or s == nil then
						error("Invalid escape sequence at " .. s)
					else
						finish = finish + 1
					end
				end

				n = n + 1
				args[n] = str:sub(start, finish - 1)
			end

			local func = mode and actions[mode]
			if func then func(args) end

			offset = finish + 1
		elseif offset == 1 then
			write(str)
			return
		else
			write(str:sub(offset))
			return
		end
	end
end

function printAnsi(...)
	local limit = select("#", ...)
	for n = 1, limit do
		local s = tostring(select(n, ... ))
		if n < limit then
			s = s .. "\t"
		end
		writeAnsi(s)
	end
	write("\n")
end

return {
	write = writeAnsi,
	print = printAnsi,
}

end
preload["bsrocks.downloaders.tree"] = function(...)
local error = require "bsrocks.lib.utils".error

local function callback(success, path, count, total)
	if not success then
		local x, y = term.getCursorPos()
		term.setCursorPos(1, y)
		term.clearLine()
		printError("Cannot download " .. path)
	end

	local x, y = term.getCursorPos()
	term.setCursorPos(1, y)
	term.clearLine()
	write(("Downloading: %s/%s (%s%%)"):format(count, total, count / total * 100))
end

local tries = require "bsrocks.lib.settings".tries

--- Download individual files
-- @tparam string prefix The url prefix to use
-- @tparam table files The list of files to download
-- @tparam int tries Number of times to attempt to download
local function tree(prefix, files)
	local result = {}

	local count = 0
	local total = #files
	if total == 0 then
		print("No files to download")
		return {}
	end

	-- Download a file and store it in the tree
	local errored = false
	local function download(path)
		local contents

		-- Attempt to download the file
		for i = 1, tries do
			local url = (prefix .. path):gsub(' ','%%20')
			local f = http.get(url)

			if f then
				count = count + 1

				local out, n = {}, 0
				for line in f.readLine do
					n = n + 1
					out[n] = line
				end
				result[path] = out
				f.close()
				callback(true, path, count, total)
				return
			elseif errored then
				-- Just abort
				return
			end
		end

		errored = true
		callback(false, path, count, total)
	end

	local callbacks = {}

	for i, file in ipairs(files) do
		callbacks[i] = function() download(file) end
	end

	parallel.waitForAll(unpack(callbacks))
	print()
	if errored then
		error("Cannot download " .. prefix)
	end

	return result
end

return tree

end
preload["bsrocks.downloaders"] = function(...)
local error = require "bsrocks.lib.utils".error
local tree = require "bsrocks.downloaders.tree"

local downloaders = {
	-- GitHub
	function(source, files)
		local url = source.url
		if not url then return end

		local repo = url:match("git://github%.com/([^/]+/[^/]+)$") or url:match("https?://github%.com/([^/]+/[^/]+)$")
		local branch = source.branch or source.tag or "master"
		if repo then
			repo = repo:gsub("%.git$", "")
		else
			-- If we have the archive then we can also fetch from GitHub
			repo, branch = url:match("https?://github%.com/([^/]+/[^/]+)/archive/(.*).tar.gz")
			if not repo then return end
		end

		if not files then
			return true
		end

		print("Downloading " .. repo .. "@" .. branch)
		return tree('https://raw.github.com/'..repo..'/'..branch..'/', files)
	end,
	function(source, files)
		local url = source.single
		if not url then return end

		if not files then
			return true
		end

		if #files ~= 1 then error("Expected 1 file for single, got " .. #files, 0) end

		local handle, msg = http.get(url)
		if not handle then
			error(msg or "Cannot download " .. url, 0)
		end

		local contents = handle.readAll()
		handle.close()
		return { [files[1]] = contents }
	end

}

return function(source, files)
	for _, downloader in ipairs(downloaders) do
		local result = downloader(source, files)
		if result then
			return result
		end
	end

	return false
end

end
preload["bsrocks.commands.search"] = function(...)
local match = require "bsrocks.lib.match"
local rockspec = require "bsrocks.rocks.rockspec"
local manifest = require "bsrocks.rocks.manifest"

local function execute(search)
	if not search then error("Expected <name>", 0) end
	search = search:lower()

	local names, namesN = {}, 0
	local all, allN = {}, 0
	for server, manifest in pairs(manifest.fetchAll()) do
		for name, _ in pairs(manifest.repository) do
			-- First try a loose search
			local version = rockspec.latestVersion(manifest, name)
			if name:find(search, 1, true) then
				namesN = namesN + 1
				names[namesN] = { name, version }
				all = nil
			elseif namesN == 0 then
				allN = allN + 1
				all[allN] = { name, version }
			end
		end
	end

	-- Now try a fuzzy search
	if namesN == 0 then
		printError("Could not find '" .. search .. "', trying a fuzzy search")
		for _, name in ipairs(all) do
			if match(name[1], search) > 0 then
				namesN = namesN + 1
				names[namesN] = name
			end
		end
	end

	-- Print out all found items + version
	if namesN == 0 then
		error("Cannot find " .. search, 0)
	else
		for i = 1, namesN do
			local item = names[i]
			print(item[1] .. ": " .. item[2])
		end
	end
end

local description = [[
  <name>  The name of the package to search for.

If the package cannot be found, it will query for packages with similar names.
]]
return {
	name = "search",
	help = "Search for a package",
	description = description,
	syntax = "<name>",
	execute = execute,
}

end
preload["bsrocks.commands.repl"] = function(...)
local env = require "bsrocks.env"
local serialize = require "bsrocks.lib.dump"
local parse = require "bsrocks.lib.parse"

local function execute(...)
	local running = true
	local env = env()
	local thisEnv = env._G

	thisEnv.exit = setmetatable({}, {
		__tostring = function() return "Call exit() to exit" end,
		__call = function() running = false end,
	})

	-- We need to pass through a secondary function to prevent tail calls
	thisEnv._noTail = function(...) return ... end
	thisEnv.arg = { [0] = "repl", ... }

	-- As per @demhydraz's suggestion. Because the prompt uses Out[n] as well
	local output = {}
	thisEnv.Out = output

	local inputColour, outputColour, textColour = colours.green, colours.cyan, term.getTextColour()
	local codeColour, pointerColour = colours.lightGrey, colours.lightBlue
	if not term.isColour() then
		inputColour = colours.white
		outputColour = colours.white
		codeColour = colours.white
		pointerColour = colours.white
	end

	local autocomplete = nil
	if not settings or settings.get("lua.autocomplete") then
		autocomplete = function(line)
			local start = line:find("[a-zA-Z0-9_%.]+$")
			if start then
				line = line:sub(start)
			end
			if #line > 0 then
				return textutils.complete(line, thisEnv)
			end
		end
	end

	local history = {}
	local counter = 1

	--- Prints an output and sets the output variable
	local function setOutput(out, length)
		thisEnv._ = out
		thisEnv['_' .. counter] = out
		output[counter] = out

		term.setTextColour(outputColour)
		write("Out[" .. counter .. "]: ")
		term.setTextColour(textColour)

		if type(out) == "table" then
			local meta = getmetatable(out)
			if type(meta) == "table" and type(meta.__tostring) == "function" then
				print(tostring(out))
			else
				print(serialize(out, length))
			end
		else
			print(serialize(out))
		end
	end

	--- Handle the result of the function
	local function handle(forcePrint, success, ...)
		if success then
			local len = select('#', ...)
			if len == 0 then
				if forcePrint then
					setOutput(nil)
				end
			elseif len == 1 then
				setOutput(...)
			else
				setOutput({...}, len)
			end
		else
			printError(...)
		end
	end

	local function handleError(lines, line, column, message)
		local contents = lines[line]
		term.setTextColour(codeColour)
		print(" " .. contents)
		term.setTextColour(pointerColour)
		print((" "):rep(column) .. "^ ")
		printError(" " .. message)
	end

	local function execute(lines, force)
		local buffer = table.concat(lines, "\n")
		local forcePrint = false
		local func, err = load(buffer, "lua", "t", thisEnv)
		local func2, err2 = load("return " .. buffer, "lua", "t", thisEnv)
		if not func then
			if func2 then
				func = load("return _noTail(" .. buffer .. ")", "lua", "t", thisEnv)
				forcePrint = true
			else
				local success, tokens = pcall(parse.lex, buffer)
				if not success then
					local line, column, resumable, message = tokens:match("(%d+):(%d+):([01]):(.+)")
					if line then
						if line == #lines and column > #lines[line] and resumable == 1  then
							return false
						else
							handleError(lines, tonumber(line), tonumber(column), message)
							return true
						end
					else
						printError(tokens)
						return true
					end
				end

				local success, message = pcall(parse.parse, tokens)

				if not success then
					if not force and tokens.pointer >= #tokens.tokens then
						return false
					else
						local token = tokens.tokens[tokens.pointer]
						handleError(lines, token.line, token.char, message)
						return true
					end
				end
			end
		elseif func2 then
			func = load("return _noTail(" .. buffer .. ")", "lua", "t", thisEnv)
		end

		if func then
			handle(forcePrint, pcall(func))
			counter = counter + 1
		else
			printError(err)
		end

		return true
	end

	local lines = {}
	local input = "In [" .. counter .. "]: "
	local isEmpty = false
	while running do
		term.setTextColour(inputColour)
		write(input)
		term.setTextColour(textColour)

		local line = read(nil, history, autocomplete)
		if not line then break end

		if #line:gsub("%s", "") > 0 then
			for i = #history, 1, -1 do
				if history[i] == line then
					table.remove(history, i)
					break
				end
			end

			history[#history + 1] = line
			lines[#lines + 1] = line
			isEmpty = false

			if execute(lines) then
				lines = {}
				input = "In [" .. counter .. "]: "
			else
				input = (" "):rep(#tostring(counter) + 3) .. "... "
			end
		else
			execute(lines, true)
			lines = {}
			isEmpty = false
			input = "In [" .. counter .. "]: "
		end
	end

	for _, v in pairs(env.cleanup) do v() end
end

local description = [[
This is almost identical to the built in Lua program with some simple differences.

Scripts are run in an environment similar to the exec command.

The result of the previous outputs are also stored in variables of the form _idx (the last result is also stored in _). For example: if Out[1] = 123 then _1 = 123 and _ = 123
]]
return {
	name = "repl",
	help = "Run a Lua repl in an emulated environment",
	syntax = "",
	description = description,
	execute = execute,
}

end
preload["bsrocks.commands.remove"] = function(...)
local install = require "bsrocks.rocks.install"
local rockspec = require "bsrocks.rocks.rockspec"

local description = [[
  <name>    The name of the package to install

Removes a package. This does not remove its dependencies
]]
return {
	name = "remove",
	help = "Removes a package",
	syntax = "<name>",
	description = description,
	execute = function(name, version)
		if not name then error("Expected name", 0) end
		name = name:lower()

		local installed, installedPatches = install.getInstalled()
		local rock, patch = installed[name], installedPatches[name]
		if not rock then error(name .. " is not installed", 0) end

		install.remove(rock, patch)
	end
}

end
preload["bsrocks.commands.list"] = function(...)
local install = require "bsrocks.rocks.install"
local printColoured = require "bsrocks.lib.utils".printColoured

local function execute()
	for _, data in pairs(install.getInstalled()) do
		if not data.builtin then
			print(data.package .. ": " .. data.version)
			if data.description and data.description.summary then
				printColoured("  " .. data.description.summary, colours.lightGrey)
			end
		end
	end
end

return {
	name = "list",
	help = "List installed packages",
	syntax = "",
	execute = execute
}

end
preload["bsrocks.commands.install"] = function(...)
local install = require "bsrocks.rocks.install"

local description = [[
  <name>    The name of the package to install
  [version] The version of the package to install

Installs a package and all dependencies. This will also
try to upgrade a package if required.
]]
return {
	name = "install",
	help = "Install a package",
	syntax = "<name> [version]",
	description = description,
	execute = function(name, version)
		if not name then error("Expected name", 0) end
		install.install(name, version)
	end
}

end
preload["bsrocks.commands.exec"] = function(...)
local env = require "bsrocks.env"
local settings = require "bsrocks.lib.settings"

local description = [[
	<file>	The file to execute relative to the current directory.
	[args...] Arguments to pass to the program.

This will execute the program in an emulation of Lua 5.1's environment.

Please note that the environment is not a perfect emulation.
]]

return {
	name = "exec",
	help = "Execute a command in the emulated environment",
	syntax = "<file> [args...]",
	description = description,
	execute = function(file, ...)
		if not file then error("Expected file", 0) end

		if file:sub(1, 1) == "@" then
			file = file:sub(2)

			local found
			for _, path in ipairs(settings.binPath) do
				path = path:gsub("%%{(%a+)}", settings):gsub("%?", file)
				if fs.exists(path) then
					found = path
					break
				end
			end

			file = found or shell.resolveProgram(file) or file
		else
			file = shell.resolve(file)
		end

		local env = env()
		local thisEnv = env._G
		thisEnv.arg = {[-2] = "/" .. shell.getRunningProgram(), [-1] = "exec", [0] = "/" .. file, ... }

		local loaded, msg = loadfile(file, thisEnv)
		if not loaded then error(msg, 0) end

		local args = {...}
		local success, msg = xpcall(
			function() return loaded(unpack(args)) end,
			function(msg)
				msg = env.getError(msg)
				if type(msg) == "string" then
					local code = msg:match("^Exit code: (%d+)")
					if code and code == "0" then return "<nop>" end
				end

				if msg == nil then
					return "nil"
				else
					msg = tostring(msg)
				end
				return thisEnv.debug.traceback(msg, 2)
			end
		)

		for _, v in pairs(env.cleanup) do v() end

		if not success and msg ~= "<nop>" then
			if msg == "nil" then msg = nil end
			error(msg, 0)
		end
	end,
}

end
preload["bsrocks.commands.dumpsettings"] = function(...)
local fileWrapper = require "bsrocks.lib.files"
local serialize = require "bsrocks.lib.serialize"
local settings = require "bsrocks.lib.settings"
local utils = require "bsrocks.lib.utils"

return {
	name = "dump-settings",
	help = "Dump all settings",
	syntax = "",
	description = "Dump all settings to a .bsrocks file. This can be changed to load various configuration options.",
	execute = function()
		local dumped = serialize.serialize(settings)
		utils.log("Dumping to .bsrocks")
		fileWrapper.write(".bsrocks", dumped)
	end,
}

end
preload["bsrocks.commands.desc"] = function(...)
local dependencies = require "bsrocks.rocks.dependencies"
local download = require "bsrocks.downloaders"
local install = require "bsrocks.rocks.install"
local patchspec = require "bsrocks.rocks.patchspec"
local rockspec = require "bsrocks.rocks.rockspec"
local settings = require "bsrocks.lib.settings"
local utils = require "bsrocks.lib.utils"

local servers = settings.servers
local printColoured, writeColoured = utils.printColoured, utils.writeColoured

local function execute(name)
	if not name then error("Expected <name>", 0) end
	name = name:lower()

	local installed, installedPatches = install.getInstalled()

	local isInstalled = true
	local spec, patchS = installed[name], installedPatches[name]

	if not spec then
		isInstalled = false
		local manifest = rockspec.findRockspec(name)

		if not manifest then error("Cannot find '" .. name .. "'", 0) end

		local patchManifest = patchspec.findPatchspec(name)

		local version
		if patchManifest then
			version = patchManifest.patches[name]
		else
			version = rockspec.latestVersion(manifest, name, constraints)
		end

		spec = rockspec.fetchRockspec(manifest.server, name, version)
		patchS = patchManifest and patchspec.fetchPatchspec(patchManifest.server, name)
	end

	write(name .. ": " .. spec.version .. " ")
	if spec.builtin then
		writeColoured("Built In", colours.magenta)
	elseif isInstalled then
		writeColoured("Installed", colours.green)
	else
		writeColoured("Not installed", colours.red)
	end

	if patchS then
		writeColoured(" (+Patchspec)", colours.lime)
	end
	print()

	local desc = spec.description
	if desc then
		if desc.summary then printColoured(desc.summary, colours.cyan) end
		if desc.detailed then
			local detailed = desc.detailed
			local ident = detailed:match("^(%s+)")
			if ident then
				detailed = detailed:sub(#ident + 1):gsub("\n" .. ident, "\n")
			end

			-- Remove leading and trailing whitespace
			detailed = detailed:gsub("^\n+", ""):gsub("%s+$", "")
			printColoured(detailed, colours.white)
		end

		if desc.homepage then
			printColoured("URL: " .. desc.homepage, colours.lightBlue)
		end
	end

	if not isInstalled then
		local error, issues = install.findIssues(spec, patchS)
		if #issues > 0 then
			printColoured("Issues", colours.orange)
			if error then
				printColoured("This package is incompatible", colors.red)
			end

			for _, v in ipairs(issues) do
				local color = colors.yellow
				if v[2] then color = colors.red end

				printColoured(" " .. v[1], color)
			end
		end
	end

	local deps = spec.dependencies
	if patchS and patchS.dependencies then
		deps = patchS.dependencies
	end
	if deps and #deps > 0 then
		printColoured("Dependencies", colours.orange)
		local len = 0
		for _, deps in ipairs(deps) do len = math.max(len, #deps) end

		len = len + 1
		for _, deps in ipairs(deps) do
			local dependency = dependencies.parseDependency(deps)
			local name = dependency.name
			local current = installed[name]

			write(" " .. deps .. (" "):rep(len - #deps))

			if current then
				local version = dependencies.parseVersion(current.version)
				if not dependencies.matchConstraints(version, dependency.constraints) then
					printColoured("Wrong version", colours.yellow)
				elseif current.builtin then
					printColoured("Built In", colours.magenta)
				else
					printColoured("Installed", colours.green)
				end
			else
				printColoured("Not installed", colours.red)
			end
		end
	end
end

local description = [[
  <name>  The name of the package to search for.

Prints a description about the package, listing its description, dependencies and other useful information.
]]
return {
	name = "desc",
	help = "Print a description about a package",
	description = description,
	syntax = "<name>",
	execute = execute,
}

end
preload["bsrocks.commands.admin.make"] = function(...)
local fileWrapper = require "bsrocks.lib.files"
local log = require "bsrocks.lib.utils".log
local patchDirectory = require "bsrocks.lib.settings".patchDirectory
local patchspec = require "bsrocks.rocks.patchspec"
local serialize = require "bsrocks.lib.serialize"

local function execute(...)
	local patched, force
	if select("#", ...) == 0 then
		force = false
		patched = patchspec.getAll()
	else
		force = true
		patched = {}
		for _, name in pairs({...}) do
			name = name:lower()
			local file = fs.combine(patchDirectory, "rocks/" .. name .. ".patchspec")
			if not fs.exists(file) then error("No such patchspec " .. name, 0) end

			patched[name] = serialize.unserialize(fileWrapper.read(file))
		end
	end

	for name, data in pairs(patched) do
		local original = fs.combine(patchDirectory, "rocks-original/" .. name)
		local changed = fs.combine(patchDirectory, "rocks-changes/" .. name)
		local patch = fs.combine(patchDirectory, "rocks/" .. name)
		local info = patch .. ".patchspec"

		log("Making " .. name)

		fileWrapper.assertExists(original, "original sources for " .. name, 0)
		fileWrapper.assertExists(changed, "changed sources for " .. name, 0)
		fileWrapper.assertExists(info, "patchspec for " .. name, 0)

		local data = serialize.unserialize(fileWrapper.read(info))
		local originalSources = fileWrapper.readDir(original, fileWrapper.readLines)
		local changedSources = fileWrapper.readDir(changed, fileWrapper.readLines)

		local files, patches, added, removed = patchspec.makePatches(originalSources, changedSources)
		data.patches = patches
		data.added = added
		data.removed = removed

		fileWrapper.writeDir(patch, files, fileWrapper.writeLines)
		fileWrapper.write(info, serialize.serialize(data))
	end
end

local description = [[
  [name] The name of the package to create patches for. Otherwise all packages will make their patches.
]]

return {
	name = "make-patches",
	help = "Make patches for a package",
	syntax = "[name]...",
	description = description,
	execute = execute
}

end
preload["bsrocks.commands.admin.fetch"] = function(...)
local download = require "bsrocks.downloaders"
local fileWrapper = require "bsrocks.lib.files"
local log = require "bsrocks.lib.utils".log
local patchspec = require "bsrocks.rocks.patchspec"
local rockspec = require "bsrocks.rocks.rockspec"
local serialize = require "bsrocks.lib.serialize"
local patchDirectory = require "bsrocks.lib.settings".patchDirectory

local function execute(...)
	local patched, force
	if select("#", ...) == 0 then
		force = false
		patched = patchspec.getAll()
	else
		force = true
		patched = {}
		for _, name in pairs({...}) do
			name = name:lower()
			local file = fs.combine(patchDirectory, "rocks/" .. name .. ".patchspec")
			if not fs.exists(file) then error("No such patchspec " .. name, 0) end

			patched[name] = serialize.unserialize(fileWrapper.read(file))
		end
	end

	local hasChanged = false
	for name, patchS in pairs(patched) do
		local dir = fs.combine(patchDirectory, "rocks-original/" .. name)
		if force or not fs.isDir(dir) then
			hasChanged = true
			log("Fetching " .. name)

			fs.delete(dir)

			local version = patchS.version
			if not patchS.version then
				error("Patchspec" .. name .. " has no version", 0)
			end

			local manifest = rockspec.findRockspec(name)
			if not manifest then
				error("Cannot find '" .. name .. "'", 0)
			end

			local rock = rockspec.fetchRockspec(manifest.server, name, patchS.version)

			local files = rockspec.extractFiles(rock)
			if #files == 0 then error("No files for " .. name .. "-" .. version, 0) end

			local downloaded = download(patchspec.extractSource(rock, patchS), files)

			if not downloaded then error("Cannot find downloader for " .. rock.source.url, 0) end

			for name, contents in pairs(downloaded) do
				fileWrapper.writeLines(fs.combine(dir, name), contents)
			end

			fs.delete(fs.combine(patchDirectory, "rocks-changes/" .. name))
		end
	end

	if not hasChanged then
		error("No packages to fetch", 0)
	end

	print("Run 'apply-patches' to apply")
end

local description = [[
  [name] The name of the package to fetch. Otherwise all un-fetched packages will be fetched.
]]
return {
	name = "fetch",
	help = "Fetch a package for patching",
	syntax = "[name]...",
	description = description,
	execute = execute,
}

end
preload["bsrocks.commands.admin.apply"] = function(...)
local fileWrapper = require "bsrocks.lib.files"
local log = require "bsrocks.lib.utils".log
local patchDirectory = require "bsrocks.lib.settings".patchDirectory
local patchspec = require "bsrocks.rocks.patchspec"
local serialize = require "bsrocks.lib.serialize"

local function execute(...)
	local patched, force
	if select("#", ...) == 0 then
		force = false
		patched = patchspec.getAll()
	elseif select("#", ...) == 1 and (... == "-f"  or ... == "--force") then
		force = true
		patched = patchspec.getAll()
	else
		force = true
		patched = {}
		for _, name in pairs({...}) do
			name = name:lower()
			local file = fs.combine(patchDirectory, "rocks/" .. name .. ".patchspec")
			if not fs.exists(file) then error("No such patchspec " .. name, 0) end

			patched[name] = serialize.unserialize(fileWrapper.read(file))
		end
	end

	local hasChanged = false
	for name, data in pairs(patched) do
		local original = fs.combine(patchDirectory, "rocks-original/" .. name)
		local patch = fs.combine(patchDirectory, "rocks/" .. name)
		local changed = fs.combine(patchDirectory, "rocks-changes/" .. name)

		if force or not fs.isDir(changed) then
			hasChanged = true
			log("Applying " .. name)

			fileWrapper.assertExists(original, "original sources for " .. name, 0)
			fs.delete(changed)

			local originalSources = fileWrapper.readDir(original, fileWrapper.readLines)
			local replaceSources = {}
			if fs.exists(patch) then replaceSources = fileWrapper.readDir(patch, fileWrapper.readLines) end

			local changedSources = patchspec.applyPatches(
				originalSources, replaceSources,
				data.patches or {}, data.added or {}, data.removed or {}
			)

			fileWrapper.writeDir(changed, changedSources, fileWrapper.writeLines)
		end
	end

	if not hasChanged then
		error("No packages to patch", 0)
	end
end

local description = [[
  [name] The name of the package to apply. Otherwise all un-applied packages will have their patches applied.
]]

return {
	name = "apply-patches",
	help = "Apply patches for a package",
	syntax = "[name]...",
	description = description,
	execute = execute,
}

end
preload["bsrocks.commands.admin.addrockspec"] = function(...)
local fileWrapper = require "bsrocks.lib.files"
local manifest = require "bsrocks.rocks.manifest"
local patchDirectory = require "bsrocks.lib.settings".patchDirectory
local rockspec = require "bsrocks.rocks.rockspec"
local serialize = require "bsrocks.lib.serialize"

local function execute(name, version)
	if not name then error("Expected name", 0) end
	name = name:lower()

	local rock = rockspec.findRockspec(name)
	if not rock then
		error("Cannot find '" .. name .. "'", 0)
	end

	if not version then
		version = rockspec.latestVersion(rock, name)
	end

	local data = {}
	local info = fs.combine(patchDirectory, "rocks/" .. name .. "-" .. version .. ".rockspec")
	if fs.exists(info) then
		data = serialize.unserialize(fileWrapper.read(info))

		if data.version == version then
			error("Already at version " .. version, 0)
		end
	else
		data = rockspec.fetchRockspec(rock.server, name, version)
	end

	data.version = version
	fileWrapper.write(info, serialize.serialize(data))

	local locManifest, locPath = manifest.loadLocal()
	local versions = locManifest.repository[name]
	if not versions then
		versions = {}
		locManifest.repository[name] = versions
	end
	versions[version] = { { arch = "rockspec"  } }
	fileWrapper.write(locPath, serialize.serialize(locManifest))

	print("Added rockspec. Feel free to edit away!")
end

local description = [[
  <name>    The name of the package
  [version] The version to use

Refreshes a rockspec file to the original.
]]

return {
	name = "add-rockspec",
	help = "Add or update a rockspec",
	syntax = "<name> [version]",
	description = description,
	execute = execute,
}

end
preload["bsrocks.commands.admin.addpatchspec"] = function(...)
local fileWrapper = require "bsrocks.lib.files"
local manifest = require "bsrocks.rocks.manifest"
local patchDirectory = require "bsrocks.lib.settings".patchDirectory
local rockspec = require "bsrocks.rocks.rockspec"
local serialize = require "bsrocks.lib.serialize"

local function execute(name, version)
	if not name then error("Expected name", 0) end
	name = name:lower()

	local rock = rockspec.findRockspec(name)
	if not rock then
		error("Cannot find '" .. name .. "'", 0)
	end

	if not version then
		version = rockspec.latestVersion(rock, name)
	end

	local data = {}
	local info = fs.combine(patchDirectory, "rocks/" .. name .. ".patchspec")
	if fs.exists(info) then
		data = serialize.unserialize(fileWrapper.read(info))
	end

	if data.version == version then
		error("Already at version " .. version, 0)
	end

	data.version = version
	fileWrapper.write(info, serialize.serialize(data))
	fs.delete(fs.combine(patchDirectory, "rocks-original/" .. name))

	local locManifest, locPath = manifest.loadLocal()
	locManifest.patches[name] = version
	fileWrapper.write(locPath, serialize.serialize(locManifest))

	print("Run 'fetch " .. name .. "' to download files")
end

local description = [[
  <name>    The name of the package
  [version] The version to use

Adds a patchspec file, or sets the version of an existing one.
]]

return {
	name = "add-patchspec",
	help = "Add or update a package for patching",
	syntax = "<name> [version]",
	description = description,
	execute = execute,
}

end
preload["bsrocks.bin.bsrocks"] = function(...)
local commands = { }

local function addCommand(command)
	commands[command.name] = command
	if command.alias then
		for _, v in ipairs(command.alias) do
			commands[v] = command
		end
	end
end

local utils = require "bsrocks.lib.utils"
local printColoured, printIndent = utils.printColoured, utils.printIndent
local patchDirectory = require "bsrocks.lib.settings".patchDirectory

-- Primary packages
addCommand(require "bsrocks.commands.desc")
addCommand(require "bsrocks.commands.dumpsettings")
addCommand(require "bsrocks.commands.exec")
addCommand(require "bsrocks.commands.install")
addCommand(require "bsrocks.commands.list")
addCommand(require "bsrocks.commands.remove")
addCommand(require "bsrocks.commands.repl")
addCommand(require "bsrocks.commands.search")

-- Install admin packages if we have a patch directory
if fs.exists(patchDirectory) then
	addCommand(require "bsrocks.commands.admin.addpatchspec")
	addCommand(require "bsrocks.commands.admin.addrockspec")
	addCommand(require "bsrocks.commands.admin.apply")
	addCommand(require "bsrocks.commands.admin.fetch")
	addCommand(require "bsrocks.commands.admin.make")
end

local function getCommand(command)
	local foundCommand = commands[command]

	if not foundCommand then
		-- No such command, print a list of suggestions
		printError("Cannot find '" .. command .. "'.")
		local match = require "bsrocks.lib.match"

		local printDid = false
		for cmd, _ in pairs(commands) do
			if match(cmd, command) > 0 then
				if not printDid then
					printColoured("Did you mean: ", colours.yellow)
					printDid = true
				end

				printColoured("  " .. cmd, colours.orange)
			end
		end
		error("No such command", 0)
	else
		return foundCommand
	end
end

addCommand({
	name = "help",
	help = "Provide help for a command",
	syntax = "[command]",
	description = "  [command]  The command to get help for. Leave blank to get some basic help for all commands.",
	execute = function(cmd)
		if cmd then
			local command = getCommand(cmd)
			print(command.help)

			if command.syntax ~= "" then
				printColoured("Synopsis", colours.orange)
				printColoured("  " .. command.name .. " " .. command.syntax, colours.lightGrey)
			end

			if command.description then
				printColoured("Description", colours.orange)
				local description = command.description:gsub("^\n+", ""):gsub("\n+$", "")

				if term.isColor() then term.setTextColour(colours.lightGrey) end
				for line in (description .. "\n"):gmatch("([^\n]*)\n") do
					local _, indent = line:find("^(%s*)")
					printIndent(line:sub(indent + 1), indent)
				end
				if term.isColor() then term.setTextColour(colours.white) end
			end
		else
			printColoured("bsrocks <command> [args]", colours.cyan)
			printColoured("Available commands", colours.lightGrey)
			for _, command in pairs(commands) do
				print("  " .. command.name .. " " .. command.syntax)
				printColoured("    " .. command.help, colours.lightGrey)
			end
		end
	end
})

-- Default to printing help messages
local cmd = ...
if not cmd or cmd == "-h" or cmd == "--help" then
	cmd = "help"
elseif select(2, ...) == "-h" or select(2, ...) == "--help" then
	return getCommand("help").execute(cmd)
end

local foundCommand = getCommand(cmd)
local args = {...}
return foundCommand.execute(select(2, unpack(args)))

end
if not shell or type(... or nil) == 'table' then
local tbl = ... or {}
tbl.require = require tbl.preload = preload
return tbl
else
return preload["bsrocks.bin.bsrocks"](...)
end
