-- Drawing recognition for runes
-- A drawing is a list of strokes, a stroke is a list of points {x, y} in pad coordinates:
-- the pad center is 0, 0 and the rune zone is a circle of radius 1, marks are drawn in the ring outside it
-- The rune zone is matched against every rune glyph with the $P point cloud recognizer
-- (Vatavu, Anthony, Wobbrock 2012), the marks are handed to the recognized rune to read
local Strokes = {}

local CLOUD_POINTS = 64         -- Points every drawing and template is resampled to
local MARK_POINTS = 32          -- Fewer points for the small mark shapes
local MARK_ROTATIONS = 16       -- Marks can point any way around the ring, they are tried at this many angles
local TOUCH_DISTANCE = 0.12     -- Strokes closer than this(pad units) count as touching, so they form one piece
-- Runes are also compared turned by these angles(degrees) so a slightly tilted drawing still matches well,
-- bigger turns still count as a different shape(Speed and a turned rune stay apart)
local RUNE_ROTATIONS = {-20, -10, 0, 10, 20}

-- Shapes marks are compared against, same format as rune glyphs(-1 to 1 box)
Strokes.MARK_SHAPES = {
    arrow = {{"line", -0.8, 0, 0.8, 0}, {"line", 0.35, -0.4, 0.8, 0, 0.35, 0.4}},
    dot = {{"dot", 0, 0, 0.2}},
    line = {{"line", -0.8, 0, 0.8, 0}},
    -- A line crossed by two short bars at its thirds, a bolt passing through
    pierce = {{"line", 0, -0.8, 0, 0.8}, {"line", -0.35, -0.27, 0.35, -0.27}, {"line", -0.35, 0.27, 0.35, 0.27}},
}


-- Geometry Helpers
local function distance(a, b)
    local dx, dy = a[1] - b[1], a[2] - b[2]
    return math.sqrt(dx * dx + dy * dy)
end


function Strokes.center(strokes)
    -- Middle of the bounding box of a group of strokes
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    for i, stroke in ipairs(strokes) do
        for j, p in ipairs(stroke) do
            minX, minY = math.min(minX, p[1]), math.min(minY, p[2])
            maxX, maxY = math.max(maxX, p[1]), math.max(maxY, p[2])
        end
    end
    return (minX + maxX) / 2, (minY + maxY) / 2
end


-- Glyphs To Strokes
local function arcPoints(cx, cy, r, a1, a2, count)
    local points = {}
    for i = 0, count do
        local a = a1 + (a2 - a1) * i / count
        table.insert(points, {cx + math.cos(a) * r, cy + math.sin(a) * r})
    end
    return points
end


function Strokes.fromGlyph(glyph)
    -- Turns glyph shapes into strokes the way someone would draw them
    local strokes = {}
    for i, shape in ipairs(glyph) do
        local kind = shape[1]
        if kind == "line" or kind == "polygon" or kind == "fill" then
            local points = {}
            for j = 2, #shape, 2 do
                table.insert(points, {shape[j], shape[j + 1]})
            end
            -- Closed shapes come back to their first point
            if kind ~= "line" then
                table.insert(points, {shape[2], shape[3]})
            end
            table.insert(strokes, points)
        elseif kind == "circle" then
            table.insert(strokes, arcPoints(shape[2], shape[3], shape[4], 0, 2 * math.pi, 16))
        elseif kind == "dot" then
            -- People draw a dot as a tiny scribble, so it becomes a small circle
            table.insert(strokes, arcPoints(shape[2], shape[3], math.max(shape[4], 0.06), 0, 2 * math.pi, 8))
        elseif kind == "arc" then
            table.insert(strokes, arcPoints(shape[2], shape[3], shape[4], shape[5], shape[6], 12))
        end
    end
    return strokes
end


function Strokes.rotate(strokes, angle)
    -- Copy of strokes turned around 0, 0(rotating before normalizing keeps each tilt sized to its own box)
    local c, s = math.cos(angle), math.sin(angle)
    local result = {}
    for i, stroke in ipairs(strokes) do
        local turned = {}
        for j, p in ipairs(stroke) do
            turned[j] = {p[1] * c - p[2] * s, p[1] * s + p[2] * c}
        end
        result[i] = turned
    end
    return result
end


-- Point Clouds($P)
local function pathLength(strokes)
    local length = 0
    for i, stroke in ipairs(strokes) do
        for j = 2, #stroke do
            length = length + distance(stroke[j - 1], stroke[j])
        end
    end
    return length
end


local function resample(strokes, n)
    -- n points spread evenly along all the strokes, without bridging the gaps between strokes
    local interval = pathLength(strokes) / (n - 1)
    local points = {}
    if interval <= 0 then
        -- A drawing with no length(single clicks) is just its first point n times
        local p = strokes[1] and strokes[1][1] or {0, 0}
        for i = 1, n do points[i] = {p[1], p[2]} end
        return points
    end

    local carried = 0
    for i, stroke in ipairs(strokes) do
        local prev = stroke[1]
        if #points == 0 then
            table.insert(points, {prev[1], prev[2]})
        end
        local j = 2
        while j <= #stroke do
            local p = stroke[j]
            local d = distance(prev, p)
            if carried + d >= interval and d > 0 then
                local t = (interval - carried) / d
                local q = {prev[1] + t * (p[1] - prev[1]), prev[2] + t * (p[2] - prev[2])}
                table.insert(points, q)
                prev = q
                carried = 0
            else
                carried = carried + d
                prev = p
                j = j + 1
            end
        end
    end
    -- Rounding can leave the last point out
    while #points < n do
        local last = strokes[#strokes][#strokes[#strokes]]
        table.insert(points, {last[1], last[2]})
    end
    while #points > n do
        table.remove(points)
    end
    return points
end


local function normalize(points)
    -- Scales to fit a unit box(keeping the proportions) and moves the centroid to 0, 0
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    for i, p in ipairs(points) do
        minX, minY = math.min(minX, p[1]), math.min(minY, p[2])
        maxX, maxY = math.max(maxX, p[1]), math.max(maxY, p[2])
    end
    local size = math.max(maxX - minX, maxY - minY)
    if size <= 0 then size = 1 end
    local cx, cy = 0, 0
    local scaled = {}
    for i, p in ipairs(points) do
        local q = {(p[1] - minX) / size, (p[2] - minY) / size}
        scaled[i] = q
        cx, cy = cx + q[1], cy + q[2]
    end
    cx, cy = cx / #scaled, cy / #scaled
    for i, q in ipairs(scaled) do
        q[1], q[2] = q[1] - cx, q[2] - cy
    end
    return scaled
end


function Strokes.cloud(strokes, n)
    -- Point cloud ready for matching
    return normalize(resample(strokes, n or CLOUD_POINTS))
end


local function cloudDistance(a, b, start)
    -- Matches every point of a to its closest unused point of b, earlier matches weigh more
    local n = #a
    local matched = {}
    local sum = 0
    local i = start
    repeat
        local best, bestIndex = math.huge, nil
        for j = 1, n do
            if not matched[j] then
                local d = distance(a[i], b[j])
                if d < best then
                    best, bestIndex = d, j
                end
            end
        end
        matched[bestIndex] = true
        local weight = 1 - ((i - start + n) % n) / n
        sum = sum + weight * best
        i = i % n + 1
    until i == start
    return sum
end


function Strokes.match(a, b)
    -- $P greedy cloud match, smaller is closer(both clouds need the same number of points)
    local n = #a
    local step = math.floor(n ^ 0.5)
    local best = math.huge
    for start = 1, n, step do
        best = math.min(best, cloudDistance(a, b, start), cloudDistance(b, a, start))
    end
    return best
end


-- Zones And Pieces
function Strokes.splitZones(strokes, runeRadius)
    -- Strokes with most of their points inside the rune zone belong to the rune, the rest are marks
    runeRadius = runeRadius or 1
    local runeStrokes, markStrokes = {}, {}
    for i, stroke in ipairs(strokes) do
        local inside = 0
        for j, p in ipairs(stroke) do
            if p[1] * p[1] + p[2] * p[2] <= runeRadius * runeRadius then
                inside = inside + 1
            end
        end
        if inside * 2 >= #stroke then
            table.insert(runeStrokes, stroke)
        else
            table.insert(markStrokes, stroke)
        end
    end
    return runeStrokes, markStrokes
end


local function strokesTouch(a, b, tolerance)
    for i, p in ipairs(a) do
        for j, q in ipairs(b) do
            if distance(p, q) <= tolerance then
                return true
            end
        end
    end
    return false
end


function Strokes.pieces(strokes, tolerance)
    -- Groups strokes that touch each other into pieces, each piece is one mark
    tolerance = tolerance or TOUCH_DISTANCE
    local group = {}
    local function find(i)
        while group[i] ~= i do i = group[i] end
        return i
    end
    for i = 1, #strokes do group[i] = i end
    for i = 1, #strokes do
        for j = i + 1, #strokes do
            if strokesTouch(strokes[i], strokes[j], tolerance) then
                group[find(i)] = find(j)
            end
        end
    end
    local byRoot, pieces = {}, {}
    for i = 1, #strokes do
        local root = find(i)
        if byRoot[root] == nil then
            byRoot[root] = {}
            table.insert(pieces, byRoot[root])
        end
        table.insert(byRoot[root], strokes[i])
    end
    return pieces
end


-- Quality
-- Measured on generated drawings(tilted up to 25 degrees, with the rotation tolerance): careful ones match
-- at a distance around 0.6, messy ones around 1.4, random scribbles around 3.2(the lowest about 2.1)
Strokes.QUALITY_BEST = 0.7      -- Distance that counts as a perfect drawing
Strokes.QUALITY_WORST = 3.2     -- Distance that counts as no resemblance
Strokes.MIN_QUALITY = 0.25      -- Below this the drawing is not recognized as any rune

function Strokes.quality(matchDistance)
    -- 1 for a near perfect drawing, 0 for one that hardly looks like the shape
    local q = 1 - (matchDistance - Strokes.QUALITY_BEST) / (Strokes.QUALITY_WORST - Strokes.QUALITY_BEST)
    return math.max(0, math.min(1, q))
end


-- Recognizing
function Strokes.recognize(strokes, candidates)
    -- Best matching rune for the strokes, candidates is a list of {name, glyph}
    -- Returns name, quality, distance, and the runner up name so callers can reject close calls
    if #strokes == 0 then
        return nil, 0
    end
    local cloud = Strokes.cloud(strokes)
    local bestName, bestDistance, secondName, secondDistance = nil, math.huge, nil, math.huge
    for i, candidate in ipairs(candidates) do
        -- Clouds of the rune at every tilt in RUNE_ROTATIONS, built once and kept on the candidate
        if candidate.clouds == nil then
            candidate.clouds = {}
            local glyphStrokes = Strokes.fromGlyph(candidate.glyph)
            for r, degrees in ipairs(RUNE_ROTATIONS) do
                candidate.clouds[r] = Strokes.cloud(Strokes.rotate(glyphStrokes, math.rad(degrees)))
            end
        end
        -- The closest tilt counts
        local d = math.huge
        for r, template in ipairs(candidate.clouds) do
            d = math.min(d, Strokes.match(cloud, template))
        end
        if d < bestDistance then
            secondName, secondDistance = bestName, bestDistance
            bestName, bestDistance = candidate.name, d
        elseif d < secondDistance then
            secondName, secondDistance = candidate.name, d
        end
    end
    local quality = Strokes.quality(bestDistance)
    if quality < Strokes.MIN_QUALITY then
        -- Too far from every rune, callers show it as unrecognized
        return nil, quality, bestDistance, bestName, bestDistance
    end
    return bestName, quality, bestDistance, secondName, secondDistance
end


local markClouds = {}

local function rotated(cloud, angle)
    local c, s = math.cos(angle), math.sin(angle)
    local result = {}
    for i, p in ipairs(cloud) do
        result[i] = {p[1] * c - p[2] * s, p[1] * s + p[2] * c}
    end
    return result
end


function Strokes.readMark(piece, kinds)
    -- Which mark shape a piece is(any rotation), kinds limits the shapes to try(defaults to all)
    -- Returns kind and quality
    local cloud = Strokes.cloud(piece, MARK_POINTS)
    local bestKind, bestDistance = nil, math.huge
    for kind, glyph in pairs(Strokes.MARK_SHAPES) do
        if kinds == nil or kinds[kind] then
            if markClouds[kind] == nil then
                markClouds[kind] = {}
                local base = Strokes.cloud(Strokes.fromGlyph(glyph), MARK_POINTS)
                for r = 0, MARK_ROTATIONS - 1 do
                    markClouds[kind][r + 1] = rotated(base, r * 2 * math.pi / MARK_ROTATIONS)
                end
            end
            for r, template in ipairs(markClouds[kind]) do
                local d = Strokes.match(cloud, template)
                if d < bestDistance then
                    bestKind, bestDistance = kind, d
                end
            end
        end
    end
    return bestKind, Strokes.quality(bestDistance * CLOUD_POINTS / MARK_POINTS)
end


-- Helpers For readMarks
function Strokes.angleAround(piece, cx, cy)
    -- Angle of a piece around a point(radians, 0 is to the right, going clockwise on screen)
    local x, y = Strokes.center(piece)
    return math.atan2(y - (cy or 0), x - (cx or 0))
end


function Strokes.pointsOutward(piece, cx, cy)
    -- True when an arrow piece points away from the point, the head adds ink at the tip end
    -- so the average of its points sits past the middle of the shaft on that side
    local x, y = Strokes.center(piece)
    local ax, ay = x - (cx or 0), y - (cy or 0)
    local length = math.sqrt(ax * ax + ay * ay)
    if length == 0 then
        return true
    end
    ax, ay = ax / length, ay / length
    local sum, count, near, far = 0, 0, math.huge, -math.huge
    for i, stroke in ipairs(piece) do
        for j, p in ipairs(stroke) do
            -- Distance along the line from the point through the piece
            local along = (p[1] - (cx or 0)) * ax + (p[2] - (cy or 0)) * ay
            sum, count = sum + along, count + 1
            near, far = math.min(near, along), math.max(far, along)
        end
    end
    return sum / count > (near + far) / 2
end


function Strokes.arrowDirection(piece)
    -- Angle an arrow piece points(radians, 0 is to the right), read from the arrow itself so it works anywhere around the rune
    -- The shaft is the longest line in the piece, the end the head sits on has more ink around it
    local points = {}
    for i, stroke in ipairs(piece) do
        for j, p in ipairs(stroke) do
            table.insert(points, p)
        end
    end
    local a, b, longest = points[1], points[1], -1
    for i = 1, #points do
        for j = i + 1, #points do
            local d = distance(points[i], points[j])
            if d > longest then
                a, b, longest = points[i], points[j], d
            end
        end
    end
    if longest <= 0 then
        return 0
    end
    local ax, ay = (b[1] - a[1]) / longest, (b[2] - a[2]) / longest
    local sum = 0
    for i, p in ipairs(points) do
        sum = sum + (p[1] - a[1]) * ax + (p[2] - a[2]) * ay
    end
    -- Average past the middle of the shaft means the head is at b
    if sum / #points > longest / 2 then
        return math.atan2(ay, ax)
    end
    return math.atan2(-ay, -ax)
end


function Strokes.readMarks(markStrokes, cx, cy)
    -- Every mark piece with what it looks like and where it sits, this list is what runes read their marks from:
    -- {kind, quality, angle(around the center), outward and direction(arrows only), strokes}
    local marks = {}
    for i, piece in ipairs(Strokes.pieces(markStrokes)) do
        local kind, quality = Strokes.readMark(piece)
        local mark = {kind = kind, quality = quality, angle = Strokes.angleAround(piece, cx, cy), strokes = piece}
        if kind == "arrow" then
            mark.outward = Strokes.pointsOutward(piece, cx, cy)
            mark.direction = Strokes.arrowDirection(piece)
        end
        table.insert(marks, mark)
    end
    return marks
end


function Strokes.angleSpan(marks)
    -- Smallest angle around the center that covers every mark(the spread of a fan of marks), marks from readMarks
    if #marks < 2 then
        return 0
    end
    local angles = {}
    for i, mark in ipairs(marks) do
        table.insert(angles, mark.angle % (2 * math.pi))
    end
    table.sort(angles)
    -- The span is the full circle minus the biggest empty gap between neighbouring marks
    local biggestGap = angles[1] + 2 * math.pi - angles[#angles]
    for i = 2, #angles do
        biggestGap = math.max(biggestGap, angles[i] - angles[i - 1])
    end
    return 2 * math.pi - biggestGap
end

return Strokes
